"""
Parser import soal pilihan ganda dari file Word (.docx).

Aturan format yang didukung:
- Soal   : "1. Teks soal" / "1) Teks soal" / "Soal 1: Teks soal" / "Pertanyaan 1:" / "No. 1."
- Opsi   : "A. teks" / "a) teks" / "(B) teks" / "*C. teks" (tanda * = kunci)
- Kunci  : tanda * di depan opsi ATAU baris "Jawaban: B" / "Kunci: B"
- Kode   : paragraf font monospace (Consolas/Courier/dll) → blok <pre><code>;
           monospace inline → <code>. Fence ``` juga didukung via frontend.
- Rumus  : Equation Editor Word (OMML) → LaTeX; teks biasa (x^2, \\frac)
           dirender otomatis oleh frontend.
- Opsi multi-baris & gambar di dalam opsi didukung (ditempel ke opsi terakhir).
"""
import html
import io
import os
import re
import uuid
from typing import BinaryIO

from .omml_to_latex import iter_math_nodes

try:
    from docx import Document
except ImportError:
    Document = None

QUESTION_RE = re.compile(r"^\s*(?:soal\s*|pertanyaan\s*|nomor\s*|no\.?\s*)?(\d{1,3})\s*[.)\]:\-]\s+(.+)$", re.IGNORECASE)
OPTION_RE = re.compile(r"^\s*\*?\s*\(?\s*([A-Ha-h])\s*[).\]:\-]\s+(.+)$")
ANSWER_RE = re.compile(
    r"^\s*(?:(?:kunci\s+)?jawaban|kunci|answer)\s*[:=\-]\s*\(?([A-Ha-h])\)?\s*(?:\(.*\))?\s*$",
    re.IGNORECASE,
)

# Paragraf yang sepenuhnya catatan dalam kurung → abaikan (jangan ditempel ke opsi).
PAREN_NOTE_RE = re.compile(r"^\(.*\)$")

# Gaya paragraf yang selalu dilewati (judul, heading, kutipan, footer).
SKIP_STYLE_NAMES = {"title", "subtitle", "quote", "intense quote", "toc heading"}


def _para_style_name(para) -> str:
    try:
        return getattr(para.style, "name", "") or ""
    except Exception:
        return ""


def _is_heading_para(para) -> bool:
    n = _para_style_name(para).strip().lower()
    return n in SKIP_STYLE_NAMES or n.startswith("heading")


def _num_fmt_of(para):
    """Format auto-list paragraf: 'bullet' | 'decimal' | ... | None.

    Resolve numId → abstractNum → level numFmt via numbering.xml.
    Gagal resolve → None (fallback perilaku lama).
    """
    try:
        from docx.oxml.ns import qn
        pPr = para._p.pPr
        if pPr is None:
            return None
        numPr = pPr.numPr
        if numPr is None:
            return None
        numId = numPr.numId.val
        ilvl = numPr.ilvl.val if numPr.ilvl is not None else 0
        pkg = para.part.package
        numbering = None
        for part in pkg.iter_parts():
            try:
                if "numbering" in str(getattr(part, "partname", "")):
                    numbering = part._element
                    break
            except Exception:
                continue
        if numbering is None:
            return None
        abs_id = None
        for num in numbering.findall(qn("w:num")):
            try:
                if num.get(qn("w:numId")) is not None and int(num.get(qn("w:numId"))) == int(numId):
                    abs_el = num.find(qn("w:abstractNumId"))
                    if abs_el is not None:
                        abs_id = abs_el.get(qn("w:val"))
                    break
            except Exception:
                continue
        if abs_id is None:
            return None
        for absnum in numbering.findall(qn("w:abstractNum")):
            try:
                if str(absnum.get(qn("w:abstractNumId"))) != str(abs_id):
                    continue
                for lvl in absnum.findall(qn("w:lvl")):
                    try:
                        if lvl.get(qn("w:ilvl")) is not None and int(lvl.get(qn("w:ilvl"))) != int(ilvl):
                            continue
                    except Exception:
                        pass
                    fmt_el = lvl.find(qn("w:numFmt"))
                    if fmt_el is not None:
                        return (fmt_el.get(qn("w:val")) or "").strip().lower() or None
            except Exception:
                continue
    except Exception:
        return None
    return None


def _para_list_kind(para):
    """'bullet' | 'decimal' | 'list' | None — jenis auto-list paragraf."""
    try:
        style = (_para_style_name(para) or "").lower()
    except Exception:
        style = ""
    if "bullet" in style:
        return "bullet"
    fmt = _num_fmt_of(para)
    if fmt:
        if fmt == "bullet":
            return "bullet"
        return "decimal"
    if "list" in style or "number" in style:
        return "list"
    return None


def _split_para_lines(segments):
    """Pecah segmen paragraf menjadi baris-baris (sel tabel berisi \\n).

    Return list (match_text, html, is_all_mono, line_segments).
    Baris kosong dilewati. Display-math menempati baris sendiri.
    """
    lines = []
    cur = []

    def flush():
        if not cur:
            return
        txt = _segments_to_text(cur)
        has_math = any(s[0] == "math" for s in cur)
        if not txt and not has_math:
            cur.clear()
            return
        h = _segments_to_html(cur)
        has_text = any(s[0] == "text" and s[1] for s in cur)
        allm = has_text and all(s[2] for s in cur if s[0] == "text" and s[1])
        lines.append((txt, h, allm, list(cur)))
        cur.clear()

    for seg in segments:
        if seg[0] == "math" and seg[2]:
            flush()
            lines.append((
                _segments_to_text([seg]),
                _segments_to_html([seg]),
                False,
                [seg],
            ))
            continue
        if seg[0] == "text":
            parts = seg[1].split("\n")
            for i, part in enumerate(parts):
                if i > 0:
                    flush()
                if part:
                    cur.append(("text", part, seg[2]))
            continue
        cur.append(seg)
    flush()
    return lines

# Font yang dianggap sebagai kode program.
MONO_FONTS = {
    "consolas", "courier new", "courier", "fira code", "fira mono",
    "source code pro", "jetbrains mono", "lucida console", "menlo",
    "monaco", "cascadia code", "cascadia mono", "roboto mono", "ubuntu mono",
}

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

MAX_LABEL_CHARS = 8000
MAX_OPTION_CHARS = 2000


def _extract_images_from_paragraph(para, base_url: str = "") -> list[str]:
    """Ekstrak gambar yang tertanam pada paragraph Word (.docx), simpan ke static/uploads, return daftar URL gambar."""
    img_urls = []
    if not hasattr(para, "_element") or not hasattr(para, "part"):
        return img_urls

    part = para.part
    if not hasattr(part, "related_parts"):
        return img_urls

    r_ids = []
    element = para._element

    for node in element.iter():
        for k, v in node.attrib.items():
            if v and isinstance(v, str) and (k.endswith("embed") or k.endswith("id") or k.endswith("link")):
                if v in part.related_parts and v not in r_ids:
                    r_ids.append(v)

    if not r_ids:
        return img_urls

    _base = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "static", "uploads"))
    os.makedirs(_base, exist_ok=True)

    # Batas agar preview .docx jahat (zip-bomb / ratusan gambar) tidak penuhi disk.
    MAX_IMAGES_PER_DOC = 30
    MAX_IMAGE_BYTES = 5 * 1024 * 1024

    for r_id in r_ids[:MAX_IMAGES_PER_DOC]:
        try:
            rel_part = part.related_parts[r_id]
            blob = getattr(rel_part, "blob", None)
            if not blob:
                continue
            if len(blob) > MAX_IMAGE_BYTES or len(blob) < 16:
                continue
            c_type = str(getattr(rel_part, "content_type", "")).lower()
            ext = ".png"
            if "jpeg" in c_type or "jpg" in c_type:
                # Validasi magic JPEG agar blob HTML tidak disimpan sebagai gambar.
                if blob[:3] != b"\xff\xd8\xff":
                    continue
                ext = ".jpg"
            elif "png" in c_type:
                if blob[:8] != b"\x89PNG\r\n\x1a\n":
                    continue
                ext = ".png"
            elif "gif" in c_type:
                if blob[:6] not in (b"GIF87a", b"GIF89a"):
                    continue
                ext = ".gif"
            elif "webp" in c_type:
                if not (blob[:4] == b"RIFF" and blob[8:12] == b"WEBP"):
                    continue
                ext = ".webp"
            else:
                # Tolak bmp/tiff/svg/dll — hanya raster aman yang diizinkan.
                continue

            filename = f"docx_{uuid.uuid4().hex[:12]}{ext}"
            filepath = os.path.abspath(os.path.join(_base, filename))
            if os.path.commonpath([filepath, _base]) != _base:
                continue

            with open(filepath, "wb") as f:
                f.write(blob)

                if base_url:
                    img_url = f"{base_url.rstrip('/')}/static/uploads/{filename}"
                else:
                    img_url = f"/static/uploads/{filename}"

                img_urls.append(img_url)
        except Exception as e:
            print(f"[docx_import] Error extracting image rId={r_id}: {e}")

    return img_urls


def _iter_block_paragraphs(document):
    """Yield paragraphs in document order, including those inside tables.
    Preserves order between normal paragraphs and tables."""
    body = document.element.body
    for child in body.iterchildren():
        # w:p = paragraph, w:tbl = table
        if child.tag.endswith('}p'):
            # find the Paragraph object matching this element
            for para in document.paragraphs:
                if para._p is child:
                    yield para
                    break
            else:
                # fallback: create temp paragraph wrapper
                from docx.text.paragraph import Paragraph
                yield Paragraph(child, document)
        elif child.tag.endswith('}tbl'):
            # find matching Table
            for table in document.tables:
                if table._tbl is child:
                    for row in table.rows:
                        for cell in row.cells:
                            for para in cell.paragraphs:
                                yield para
                    break

def _is_list_paragraph(para):
    """Detect if paragraph is part of a Word auto-numbered/bulleted list (A., B.)"""
    try:
        pPr = para._p.pPr
        if pPr is not None and pPr.numPr is not None:
            return True
    except Exception:
        pass
    style = getattr(para.style, 'name', '') or ''
    if 'list' in style.lower():
        return True
    return False

def _normalize_line(text: str) -> str:
    if not text:
        return ''
    # hapus zero-width, NBSP, dan normalisasi spasi
    text = text.replace('\xa0', ' ').replace('\u200b', '').replace('\ufeff', '').replace('\r', ' ')
    # ganti tab dengan spasi
    text = text.replace('\t', ' ')
    text = text.strip()
    # kupas bold markdown "**...**" ala Google Docs agar regex nomor/huruf cocok,
    # tapi "**B. ..." = opsi benar yang di-bold → pertahankan satu * sebagai kunci.
    if text.startswith('**'):
        rest = text[2:].lstrip()
        if re.match(r'\(?\s*[A-Ha-h]\s*[).\]:\-]', rest):
            text = '*' + rest
        else:
            text = rest
    if text.endswith('**') and len(text) > 2:
        text = text[:-2].rstrip()
    return text


def _run_is_mono(r_el) -> bool:
    """True bila run memakai font monospace (kode program)."""
    try:
        for node in r_el.iter():
            tag = node.tag if isinstance(getattr(node, 'tag', ''), str) else ''
            if tag.endswith('}rFonts'):
                for attr_key in (
                    '{%s}ascii' % W_NS, '{%s}hAnsi' % W_NS, '{%s}cs' % W_NS,
                    'ascii', 'hAnsi', 'hansi', 'cs',
                ):
                    try:
                        val = node.get(attr_key)
                    except Exception:
                        val = None
                    if val and str(val).strip().lower() in MONO_FONTS:
                        return True
    except Exception:
        pass
    return False


def _run_text_of(r_el) -> str:
    parts = []
    try:
        for node in r_el.iter():
            tag = node.tag if isinstance(getattr(node, 'tag', ''), str) else ''
            if tag.endswith('}t') and node.text:
                parts.append(node.text)
    except Exception:
        pass
    return ''.join(parts)


def _latex_attr(latex: str) -> str:
    """Escape LaTeX untuk atribut data-value/data-latex (tanpa quote mentah)."""
    return html.escape(latex, quote=True)


def _iter_rich_segments(p_element):
    """Yield segmen paragraf sesuai urutan dokumen.

    ('text', str, mono_bool) | ('math', latex, display_bool)
    Tidak pernah melempar.
    """
    try:
        children = list(p_element)
    except Exception:
        return
    for ch in children:
        try:
            tag = ch.tag if isinstance(getattr(ch, 'tag', ''), str) else ''
            if tag.endswith('}r'):
                yield ('text', _run_text_of(ch), _run_is_mono(ch))
            elif tag.endswith('}oMath'):
                from .omml_to_latex import _convert as _omml_convert
                latex = _omml_convert(ch).strip()
                if latex:
                    yield ('math', latex, False)
            elif tag.endswith('}oMathPara'):
                parts = []
                for node in ch.iter():
                    ntag = node.tag if isinstance(getattr(node, 'tag', ''), str) else ''
                    if ntag.endswith('}oMath'):
                        from .omml_to_latex import _convert as _omml_convert
                        lx = _omml_convert(node).strip()
                        if lx:
                            parts.append(lx)
                if parts:
                    yield ('math', ' \\\\ '.join(parts), True)
            else:
                # hyperlink / smartTag / wadah lain: gali w:r di dalamnya
                try:
                    nested = [n for n in ch.iter() if isinstance(getattr(n, 'tag', ''), str) and n.tag.endswith('}r')]
                except Exception:
                    nested = []
                for r_el in nested:
                    yield ('text', _run_text_of(r_el), _run_is_mono(r_el))
        except Exception:
            continue


def _build_para_parts(para):
    """Bangun (match_text, html, is_all_mono, segments) dari satu paragraf.

    match_text: teks polos (+LaTeX mentah) untuk pencocokan regex struktur.
    html:       teks ter-escape + span rumus + tag kode, siap disimpan.
    """
    try:
        segments = list(_iter_rich_segments(para._element))
    except Exception:
        segments = []
    if not segments:
        # fallback: teks polos (paragraf biasa / compat)
        try:
            t = para.text or ''
        except Exception:
            t = ''
        t = _normalize_line(t)
        return t, html.escape(t, quote=False), False, [('text', t, False)]

    match_chunks = []
    html_chunks = []
    has_text = False
    all_mono = True
    for seg in segments:
        if seg[0] == 'math':
            _, latex, display = seg
            match_chunks.append(' %s ' % latex)
            if display:
                html_chunks.append('<div class="math-display-block" data-latex="%s"></div>' % _latex_attr(latex))
            else:
                html_chunks.append('<span class="ql-formula" data-value="%s"></span>' % _latex_attr(latex))
            all_mono = False
        else:
            _, text, mono = seg
            if text:
                has_text = True
                match_chunks.append(text)
                esc = html.escape(text, quote=False)
                if mono:
                    html_chunks.append('<code>%s</code>' % esc)
                else:
                    html_chunks.append(esc)
                    all_mono = False
            # segmen teks kosong tidak memengaruhi all_mono
    match_text = _normalize_line(''.join(match_chunks))
    is_all_mono = has_text and all_mono
    return match_text, ''.join(html_chunks), is_all_mono, segments

def _segments_to_text(segments) -> str:
    """Teks polos dari segmen (untuk value / pencocokan lanjutan)."""
    out = []
    for seg in segments:
        if seg[0] == 'math':
            out.append(seg[1])
        else:
            out.append(seg[1])
    return _normalize_line(''.join(out))


def _segments_to_html(segments, with_code: bool = True) -> str:
    """HTML dari segmen: teks ter-escape (+<code> bila mono), span rumus."""
    out = []
    for seg in segments:
        if seg[0] == 'math':
            _, latex, display = seg
            if display:
                out.append('<div class="math-display-block" data-latex="%s"></div>' % _latex_attr(latex))
            else:
                out.append('<span class="ql-formula" data-value="%s"></span>' % _latex_attr(latex))
        else:
            _, text, mono = seg
            if not text:
                continue
            esc = html.escape(text, quote=False)
            if mono and with_code:
                out.append('<code>%s</code>' % esc)
            else:
                out.append(esc)
    return ''.join(out)


def _strip_prefix_segments(segments, kind: str):
    """Buang prefix '1.' / 'A.' dari segmen pertama (format sisanya dipertahankan)."""
    if kind == 'question':
        pat = r'^\s*(?:soal\s*|pertanyaan\s*|nomor\s*|no\.?\s*)?\d{1,3}\s*[.)\]:\-]\s+'
    else:
        pat = r'^\s*\*?\s*\(?\s*[A-Ha-h]\s*[).\]:\-]\s+'
    out = []
    stripped = False
    for seg in segments:
        if not stripped and seg[0] == 'text':
            m = re.match(pat, seg[1], re.IGNORECASE)
            if m:
                rest = seg[1][m.end():]
                stripped = True
                if rest:
                    out.append(('text', rest, seg[2]))
                continue
        out.append(seg)
    return out


def parse_docx_questions(file: BinaryIO, base_url: str = "") -> dict:
    """Parse file .docx menjadi daftar soal pilihan ganda, termasuk mendeteksi & mengekstrak gambar dalam soal.

    Return:
        {
          "questions": [
            {
              "number": 1,
              "label": "...",
              "options": [{"label": ..., "value": ..., "order_index": 0, "is_correct": bool}],
              "errors": ["..."],   # kosong berarti soal valid
            }, ...
          ],
          "total": int,
          "valid_count": int,
        }
    """
    if Document is None:
        raise ValueError("python-docx tidak terpasang di server")
    document = Document(file)

    questions = []
    current = None
    seen_numbers = set()
    # auto-letter untuk list tanpa huruf (Word auto-numbering)
    next_auto_letter_ord = None
    # baris kode monospace tertunda (digabung jadi satu blok <pre>)
    pending_code = []
    # blok yang dilewati karena rusak (dilaporkan di akhir)
    skipped_blocks = 0

    # gunakan iterator yang mencakup table
    try:
        paragraphs = list(_iter_block_paragraphs(document))
        # fallback jika iterator kosong (compat)
        if not paragraphs:
            paragraphs = document.paragraphs
    except Exception:
        paragraphs = document.paragraphs

    for para in paragraphs:
        # Isolasi per-paragraf: 1 blok rusak tidak boleh menggagalkan seluruh preview.
        try:
            extracted_imgs = _extract_images_from_paragraph(para, base_url=base_url)
        except Exception:
            extracted_imgs = []
        img_html = ""
        if extracted_imgs:
            img_html = "".join([
                f'<p><img src="{url}" alt="Gambar Soal" style="max-width: 100%; height: auto; margin: 8px 0; border-radius: 8px;" /></p>'
                for url in extracted_imgs
            ])
        # Judul / heading / kutipan = instruksi dokumen, bukan soal → lewati total.
        try:
            if _is_heading_para(para):
                continue
        except Exception:
            pass
        try:
            para_kind = _para_list_kind(para)
        except Exception:
            para_kind = None
        try:
            match_text0, _html0, is_all_mono0, segments0 = _build_para_parts(para)
        except Exception:
            skipped_blocks += 1
            continue
        try:
            line_items = _split_para_lines(segments0)
        except Exception:
            line_items = [(match_text0, _html0, is_all_mono0, segments0)]

        def _attach_html(snippet: str) -> bool:
            """Tempel HTML ke label soal (bila opsi belum ada) atau opsi terakhir."""
            if current is None or not snippet:
                return False
            if current["options"]:
                last = current["options"][-1]
                last["label"] = (last["label"] + " " + snippet).strip()[:4000]
            else:
                current["label"] = (current["label"] + " " + snippet).strip()[:12000]
            return True

        def _flush_code() -> str:
            """Gabung baris kode monospace tertunda menjadi satu blok <pre>."""
            if not pending_code:
                return ""
            block = "<pre><code class=\"language-plaintext\">%s</code></pre>" % "\n".join(
                html.escape(l, quote=False) for l in pending_code
            )
            pending_code.clear()
            return block

        # Paragraf tanpa baris teks (murni gambar/kosong): tempel gambar lalu lanjut
        if not line_items:
            if img_html:
                code_html = _flush_code()
                if code_html:
                    _attach_html(code_html)
                _attach_html(img_html)
            continue

        for li, (match_text, _html, is_all_mono, segments) in enumerate(line_items):
            # Gambar milik paragraf ini hanya ditempel sekali (baris pertama)
            if li > 0:
                img_html = ""

            answer_match = ANSWER_RE.match(match_text)
            if answer_match and current is not None:
                code_html = _flush_code()
                if code_html:
                    _attach_html(code_html)
                letter = answer_match.group(1).upper()
                matched = [o for o in current["options"] if o["letter"] == letter]
                if matched:
                    for o in current["options"]:
                        o["is_correct"] = o["letter"] == letter
                else:
                    current["errors"].append(
                        f"Kunci jawaban '{letter}' tidak ada di daftar opsi (soal {current['number']})"
                    )
                continue

            question_match = QUESTION_RE.match(match_text)
            option_match = OPTION_RE.match(match_text) if not question_match else None

            # Paragraf full-monospace yang BUKAN struktur → kumpulkan jadi blok kode
            if is_all_mono and not question_match and not option_match and not answer_match:
                if len(match_text) <= MAX_OPTION_CHARS:
                    pending_code.append(match_text)
                if img_html:
                    code_html = _flush_code()
                    if code_html:
                        _attach_html(code_html)
                    _attach_html(img_html)
                continue

            # List ber-bullet (catatan/aturan, bukan opsi) → abaikan total.
            # Opsi eksplisit "A." sudah ditangani di atas; ini hanya untuk baris
            # tanpa pola struktur.
            if para_kind == "bullet":
                continue

            if question_match:
                # Kode tertunda milik soal SEBELUMnya → tempel dulu sebelum buat soal baru
                code_html = _flush_code()
                if code_html:
                    _attach_html(code_html)
                number = int(question_match.group(1))
                inner_segs = _strip_prefix_segments(segments, 'question')
                q_html = _segments_to_html(inner_segs, with_code=False)
                if img_html:
                    q_html = f"{q_html} {img_html}".strip()
                    img_html = ""

                current = {
                    "number": number,
                    "label": q_html,
                    "options": [],
                    "errors": [],
                }
                questions.append(current)
                if number in seen_numbers:
                    current["errors"].append(f"Nomor soal {number} duplikat")
                seen_numbers.add(number)
                next_auto_letter_ord = ord('A')
                continue

            if option_match and current is not None:
                code_html = _flush_code()
                if code_html:
                    _attach_html(code_html)
                # Jika ada gambar di nomor soal yang belum dipasang sebelum opsi A/B/C
                if img_html:
                    current["label"] = f"{current['label']} {img_html}".strip()
                    img_html = ""

                letter = option_match.group(1).upper()
                inner_segs = _strip_prefix_segments(segments, 'option')
                opt_html = _segments_to_html(inner_segs, with_code=False)
                opt_text = _segments_to_text(inner_segs)
                is_correct = match_text.lstrip().startswith("*")
                existing = next((o for o in current["options"] if o["letter"] == letter), None)
                if existing is None:
                    current["options"].append({
                        "letter": letter,
                        "label": opt_html,
                        "value": opt_text,
                        "order_index": len(current["options"]),
                        "is_correct": is_correct,
                    })
                else:
                    existing.update({"label": opt_html, "value": opt_text})
                    if is_correct:
                        existing["is_correct"] = True
                # sync auto-letter ke huruf berikutnya
                try:
                    next_auto_letter_ord = ord(letter) + 1
                except Exception:
                    pass
                continue

            # Fallback: opsi tanpa huruf karena Word auto-numbering desimal
            # (list A. tidak ada di text). Bullet sudah dilewati di atas.
            if current is not None and _is_list_paragraph(para) and match_text and not question_match and not answer_match:
                code_html = _flush_code()
                if code_html:
                    _attach_html(code_html)
                if img_html:
                    current["label"] = f"{current['label']} {img_html}".strip()
                    img_html = ""

                is_correct_fallback = match_text.lstrip().startswith("*")
                clean_text = match_text.lstrip().lstrip("*").strip()
                if clean_text and len(clean_text) < 180:
                    if next_auto_letter_ord is None:
                        next_auto_letter_ord = ord('A') + len(current["options"])
                    letter = chr(next_auto_letter_ord)
                    if not any(o["letter"] == letter for o in current["options"]):
                        current["options"].append({
                            "letter": letter,
                            "label": html.escape(clean_text, quote=False),
                            "value": clean_text,
                            "order_index": len(current["options"]),
                            "is_correct": is_correct_fallback,
                        })
                        next_auto_letter_ord += 1
                        continue

            # Garis pemisah (───, ***, •••) → abaikan, jangan ditempel ke opsi.
            if match_text and not re.search(r"\w", match_text, re.UNICODE):
                continue

            # Catatan dalam kurung penuh "(...)" → abaikan, jangan ditempel ke opsi.
            if PAREN_NOTE_RE.match(match_text):
                continue

            # Baris lain: lanjutan teks soal (belum ada opsi) ATAU lanjutan opsi terakhir
            if current is not None:
                label_part = _html
                if img_html:
                    label_part = f"{label_part} {img_html}"
                    img_html = ""
                _attach_html(label_part)

    # Sisa kode tertunda di akhir dokumen
    try:
        if pending_code:
            block = "<pre><code class=\"language-plaintext\">%s</code></pre>" % "\n".join(
                html.escape(l, quote=False) for l in pending_code
            )
            pending_code.clear()
            if current is not None:
                _attach_html(block)
    except Exception:
        pass

    if skipped_blocks and current is not None:
        current["errors"].append(f"{skipped_blocks} bagian tidak terbaca dan dilewati")

    result = []
    for q in questions:
        options = [{k: v for k, v in o.items() if k != "letter"} for o in q["options"]]
        errors = list(q["errors"])

        if len(options) < 2:
            errors.append("Opsi jawaban kurang dari 2")
        if not any(o["is_correct"] for o in options):
            errors.append("Kunci jawaban tidak ditemukan")

        result.append({
            "number": q["number"],
            "label": q["label"],
            "options": options,
            "errors": errors,
        })

    return {
        "questions": result,
        "total": len(result),
        "valid_count": sum(1 for q in result if not q["errors"]),
    }


def generate_template_docx() -> bytes:
    """Buat file .docx contoh template untuk di-download guru."""
    from docx.shared import Pt, Inches, RGBColor, Cm
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.enum.table import WD_TABLE_ALIGNMENT
    from docx.oxml.ns import qn, nsdecls
    from docx.oxml import parse_xml

    document = Document()

    style = document.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)
    style.paragraph_format.space_after = Pt(4)
    style.paragraph_format.line_spacing = 1.15

    for section in document.sections:
        section.top_margin = Cm(2)
        section.bottom_margin = Cm(2)
        section.left_margin = Cm(2.5)
        section.right_margin = Cm(2.5)

    def set_cell_shading(cell, color_hex):
        shading_elm = parse_xml(
            f'<w:shd {nsdecls("w")} w:fill="{color_hex}" w:val="clear"/>'
        )
        cell._tc.get_or_add_tcPr().append(shading_elm)

    def add_colored_heading(text, level=1, color=None):
        h = document.add_heading(text, level=level)
        if color:
            for run in h.runs:
                run.font.color.rgb = color
        return h

    BLUE = RGBColor(0x25, 0x63, 0xEB)
    DARK = RGBColor(0x1E, 0x29, 0x3B)
    GRAY = RGBColor(0x64, 0x74, 0x8B)
    GREEN = RGBColor(0x16, 0xA3, 0x4A)
    RED = RGBColor(0xDC, 0x26, 0x26)

    title = document.add_heading("Template Import Soal Pilihan Ganda", level=0)
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in title.runs:
        run.font.color.rgb = BLUE
        run.font.size = Pt(22)

    subtitle = document.add_paragraph("Formax — Sistem Ujian Digital")
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in subtitle.runs:
        run.font.size = Pt(10)
        run.font.color.rgb = GRAY
        run.font.italic = True
    subtitle.paragraph_format.space_after = Pt(16)

    doc_title = document.add_paragraph()
    doc_title.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run_line = doc_title.add_run("─" * 60)
    run_line.font.color.rgb = RGBColor(0xCB, 0xD5, 0xE1)
    run_line.font.size = Pt(8)

    add_colored_heading("Petunjuk Penggunaan", level=1, color=DARK)

    petunjuk_items = [
        ("Buka form di Formax, klik tombol ", '"Import Word"', " yang ada di toolbar atas."),
        ("Download template ini lalu buka menggunakan ", "Microsoft Word", " atau ", "Google Docs", "."),
        ("Isi soal sesuai format yang sudah ditentukan di bawah ini."),
        ("Simpan file sebagai ", ".docx", " (bukan .doc lama)."),
        ("Upload file ke Formax, lalu preview dan import soal."),
    ]
    for parts in petunjuk_items:
        p = document.add_paragraph(style="List Number")
        for i, part in enumerate(parts):
            run = p.add_run(part)
            if i % 2 == 1:
                run.bold = True
                run.font.color.rgb = BLUE

    document.add_paragraph("")

    add_colored_heading("Format Penulisan Soal", level=1, color=DARK)

    format_table = document.add_table(rows=5, cols=2, style="Table Grid")
    format_table.alignment = WD_TABLE_ALIGNMENT.CENTER

    headers = ["Komponen", "Format & Contoh"]
    for i, header in enumerate(headers):
        cell = format_table.rows[0].cells[i]
        cell.text = ""
        run = cell.paragraphs[0].add_run(header)
        run.bold = True
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        run.font.size = Pt(11)
        set_cell_shading(cell, "2563EB")

    rows_data = [
        ("Nomor Soal", "Tulis nomor + titik lalu teks soal (contoh pola: «1.» Ibu kota Indonesia adalah ...)"),
        ("Opsi Jawaban", "Tulis huruf + titik (pola: «A.» Bandung «B.» Jakarta «C.» Surabaya «D.» Medan)"),
        ("Kunci Jawaban\n(Opsi 1)", "Awali opsi yang benar dengan bintang (pola: «*B.» Jakarta)"),
        ("Kunci Jawaban\n(Opsi 2)", "Atau tulis di baris tersendiri setelah semua opsi (pola: «Jawaban: B»)"),
    ]

    for row_idx, (komponen, contoh) in enumerate(rows_data, start=1):
        cell_komponen = format_table.rows[row_idx].cells[0]
        cell_komponen.text = ""
        run_k = cell_komponen.paragraphs[0].add_run(komponen)
        run_k.bold = True
        run_k.font.size = Pt(10)

        cell_contoh = format_table.rows[row_idx].cells[1]
        cell_contoh.text = ""
        run_c = cell_contoh.paragraphs[0].add_run(contoh)
        run_c.font.size = Pt(10)
        run_c.font.name = "Consolas"

        if row_idx % 2 == 0:
            set_cell_shading(cell_komponen, "F0F4FF")
            set_cell_shading(cell_contoh, "F0F4FF")

    for row in format_table.rows:
        for cell in row.cells:
            cell.paragraphs[0].paragraph_format.space_before = Pt(4)
            cell.paragraphs[0].paragraph_format.space_after = Pt(4)

    document.add_paragraph("")

    add_colored_heading("Contoh Soal yang Benar", level=1, color=DARK)

    p_del = document.add_paragraph()
    run_del = p_del.add_run("Hapus contoh di bawah ini lalu tulis soal Anda sendiri dengan format yang sama.")
    run_del.bold = True
    run_del.font.size = Pt(11)

    p_note = add_colored_heading("Cara 1: Tandai kunci dengan tanda bintang (*) di depan opsi", level=3, color=GREEN)

    samples_star = [
        ("Ibu kota Indonesia adalah ...", [
            ("A. Bandung", False), ("*B. Jakarta", True), ("C. Surabaya", False), ("D. Medan", False)
        ]),
    ]
    for qtext, opts in samples_star:
        p_q = document.add_paragraph()
        run_q = p_q.add_run(f"1. {qtext}")
        run_q.bold = True
        run_q.font.size = Pt(11)
        for opt_text, is_correct in opts:
            p_opt = document.add_paragraph()
            p_opt.paragraph_format.left_indent = Cm(1)
            run_opt = p_opt.add_run(opt_text)
            run_opt.font.size = Pt(11)
            if is_correct:
                run_opt.bold = True
                run_opt.font.color.rgb = GREEN

    document.add_paragraph("")

    p_note2 = add_colored_heading("Cara 2: Tulis jawaban di baris tersendiri setelah opsi", level=3, color=GREEN)

    samples_keyword = [
        ("Hasil dari 12 x 12 adalah ...", [
            ("A. 124", False), ("B. 132", False), ("C. 144", False), ("D. 154", False)
        ], "Jawaban: C"),
    ]
    for qtext, opts, answer_line in samples_keyword:
        p_q = document.add_paragraph()
        run_q = p_q.add_run(f"2. {qtext}")
        run_q.bold = True
        run_q.font.size = Pt(11)
        for opt_text, _ in opts:
            p_opt = document.add_paragraph()
            p_opt.paragraph_format.left_indent = Cm(1)
            run_opt = p_opt.add_run(opt_text)
            run_opt.font.size = Pt(11)
        p_ans = document.add_paragraph()
        p_ans.paragraph_format.left_indent = Cm(1)
        run_ans = p_ans.add_run(answer_line)
        run_ans.bold = True
        run_ans.font.color.rgb = GREEN
        run_ans.font.size = Pt(11)

    document.add_paragraph("")

    p_note3 = add_colored_heading("Cara 3: Gabungan (opsional)", level=3, color=GREEN)

    samples_mixed = [
        ("Planet yang dikenal sebagai planet merah adalah ...", [
            ("A. Venus", False), ("B. Bumi", False), ("C. Yupiter", False), ("*D. Mars", True)
        ], None),
    ]
    for qtext, opts, answer_line in samples_mixed:
        p_q = document.add_paragraph()
        run_q = p_q.add_run(f"3. {qtext}")
        run_q.bold = True
        run_q.font.size = Pt(11)
        for opt_text, is_correct in opts:
            p_opt = document.add_paragraph()
            p_opt.paragraph_format.left_indent = Cm(1)
            run_opt = p_opt.add_run(opt_text)
            run_opt.font.size = Pt(11)
            if is_correct:
                run_opt.bold = True
                run_opt.font.color.rgb = GREEN

    document.add_paragraph("")

    add_colored_heading("Penting!", level=2, color=RED)

    rules = [
        "Hapus contoh soal di file ini lalu tulis soal Anda sendiri",
        "Setiap soal HARUS menggunakan nomor (1. 2. 3. dst.)",
        "Opsi jawaban HARUS menggunakan huruf (A. B. C. D. dst.)",
        "Kunci jawaban WAJIB ditandai dengan salah satu cara di atas",
        "Hanya soal PILIHAN GANDA yang bisa diimport (maksimal 8 opsi)",
        "Rumus Equation Editor Word & teks (x^2, \\frac) otomatis jadi rumus",
        "Blok kode: tulis dengan font Consolas/Courier agar tampil sebagai kode",
        "Opsi boleh multi-baris & berisi gambar — otomatis ditempel ke opsi",
        "Jangan gunakan format .doc lama — simpan sebagai .docx",
    ]
    for rule in rules:
        p = document.add_paragraph(style="List Bullet")
        run = p.add_run(rule)
        run.font.size = Pt(10)

    document.add_paragraph("")

    footer_line = doc_title.add_run if False else document.add_paragraph(style="Quote")
    footer_line.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_footer = footer_line.add_run("Dibuat dengan ❤ oleh Formax — formax.com")
    run_footer.font.size = Pt(9)
    run_footer.font.color.rgb = GRAY
    run_footer.font.italic = True

    buffer = io.BytesIO()
    document.save(buffer)
    return buffer.getvalue()
