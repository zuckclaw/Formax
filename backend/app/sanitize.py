"""Sanitasi HTML untuk konten rich-text (judul, deskripsi, label soal & opsi).

Judul/label dibuat via editor rich-text (Quill/html) sehingga sah berisi markup
presentasional (<b>, <i>, <span style>, dll). Sanitizer ini:

  1. mengunci tag berbahaya (script/iframe/object/svg + atribut on* & javascript:)
     agar tidak pernah masuk database,
  2. mempertahankan markup presentasional yang dibutuhkan rendering di web & mobile.

Dipakai lewat Pydantic `field_validator` pada skema input create/update
(forms, templates, questions & options) sehingga terjamin untuk semua endpoint.
"""

import html as _html
import re as _re
from html.parser import HTMLParser

_ALLOWED_TAGS = {
    "p", "br", "strong", "b", "em", "i", "u", "s", "strike", "del",
    "span", "ul", "ol", "li", "h1", "h2", "h3", "h4", "blockquote",
    "a", "sub", "sup", "font", "div", "pre", "img", "hr",
    # audio/video untuk RichTextEditor dcb894e — harus di-allow agar tidak di-strip
    "audio", "video", "source",
    # KaTeX / math — harus di-allow agar rumus tidak hilang (fix \frac tampil sebagai teks)
    "math", "semantics", "annotation", "mrow", "mfrac", "mn", "mo", "mi",
    "msup", "msub", "msubsup", "munder", "mover", "munderover",
    "mtable", "mtr", "mtd", "annotation",
}

_DROP_TAGS = {
    "script", "style", "iframe", "object", "embed", "form", "link",
    "meta", "base", "noscript", "svg",
}

_VOID_TAGS = {"br", "hr", "img", "wbr", "source"}

# class & data-* harus di-allow untuk KaTeX (katex, katex-html, mfrac, frac-line, ql-formula, math-display-block)
_ALLOWED_ATTRS = {
    "a": {"href", "title", "target", "rel", "class", "style"},
    "img": {"src", "alt", "title", "width", "height", "class", "style"},
    "span": {"style", "title", "class", "data-value", "data-latex", "aria-hidden"},
    "font": {"color", "face", "size", "class", "style"},
    "ol": {"start", "class", "style"},
    "audio": {"src", "controls", "style", "preload", "title", "class"},
    "video": {"src", "controls", "style", "width", "height", "preload", "class"},
    "source": {"src", "type", "class"},
    "div": {"style", "class", "data-value", "data-latex", "aria-hidden"},
    "p": {"style", "class"},
    "pre": {"style", "class"},
    "blockquote": {"style", "class"},
    "h1": {"style", "class"}, "h2": {"style", "class"}, "h3": {"style", "class"}, "h4": {"style", "class"},
    "ul": {"style", "class"}, "li": {"style", "class"},
    # KaTeX MathML
    "math": {"xmlns", "class", "style"},
    "semantics": {"class", "style"},
    "annotation": {"encoding", "class", "style"},
    "mrow": {"class", "style"}, "mfrac": {"class", "style"}, "mn": {"class", "style"},
    "mo": {"class", "style"}, "mi": {"class", "style"}, "msup": {"class", "style"},
    "msub": {"class", "style"}, "msubsup": {"class", "style"}, "munder": {"class", "style"},
    "mover": {"class", "style"}, "munderover": {"class", "style"},
    "mtable": {"class", "style"}, "mtr": {"class", "style"}, "mtd": {"class", "style"},
}

# Pola berbahaya yang tidak boleh ada di dalam nilai atribut style/href/src.
_UNSAFE_STYLE = _re.compile(
    r"(url\s*\(|expression\s*\(|javascript:|@import|behavior\s*:|-moz-binding)"
)
# Hanya izinkan data: untuk gambar raster & audio/video — TOLAK svg+xml (bisa bawa <script>).
_SAFE_PREFIXES = ("http://", "https://", "mailto:", "tel:", "/", "#")
_SAFE_DATA_PREFIXES = (
    "data:image/png;", "data:image/jpeg;", "data:image/jpg;",
    "data:image/gif;", "data:image/webp;",
    "data:audio/", "data:video/",
)


def _is_safe_url(value: str) -> bool:
    test = value.strip().lower()
    if test.startswith(_SAFE_PREFIXES):
        return True
    if test.startswith("data:"):
        # data URL harus base64 + tipe yang diizinkan; tolak svg & html.
        if "svg" in test.split(";")[0] or "html" in test.split(";")[0]:
            return False
        return test.startswith(_SAFE_DATA_PREFIXES)
    return False

_STRIP_TAG_RE = _re.compile(r"<[^>]+>")


class _Sanitizer(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self._skipping = 0

    def _attrs(self, tag, attrs):
        rendered = []
        allowed = _ALLOWED_ATTRS.get(tag)
        for key, value in attrs:
            kl = key.lower()
            if kl.startswith("on"):
                continue
            value = "" if value is None else str(value)
            # allow data-* and aria-* explicitly for KaTeX / formula
            is_data = kl.startswith("data-") or kl.startswith("aria-")
            if kl == "style":
                if not _UNSAFE_STYLE.search(value.lower()):
                    rendered.append((kl, value[:2000]))
            elif kl in ("href", "src"):
                if _is_safe_url(value):
                    rendered.append((kl, value[:5000]))
            elif kl == "class":
                # allow class but strip unsafe chars
                if not _UNSAFE_STYLE.search(value.lower()):
                    # hanya izinkan huruf, angka, -, _, spasi
                    safe = _re.sub(r"[^a-zA-Z0-9\-_ ]", "", value)[:500]
                    if safe.strip():
                        rendered.append((kl, safe.strip()))
            elif is_data:
                # data-value, data-latex, aria-hidden untuk ql-formula / displayMath / katex
                if not _UNSAFE_STYLE.search(value.lower()) and "javascript:" not in value.lower():
                    rendered.append((kl, value[:2000]))
            elif allowed is not None and kl in allowed:
                rendered.append((kl, value[:2000]))
        return "".join(f' {k}="{_html.escape(v, quote=True)}"' for k, v in rendered)

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag in _DROP_TAGS:
            self._skipping += 1
            return
        if tag in _VOID_TAGS:
            # Void tag tetap harus ada di allowlist — cegah <img> lolos tanpa izin.
            if tag not in _ALLOWED_TAGS:
                return
            self.out.append(f"<{tag}{self._attrs(tag, attrs)} />")
            return
        if tag in _ALLOWED_TAGS:
            self.out.append(f"<{tag}{self._attrs(tag, attrs)}>")

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in _DROP_TAGS:
            if self._skipping > 0:
                self._skipping -= 1
            return
        if tag in _VOID_TAGS or tag not in _ALLOWED_TAGS:
            return
        if self._skipping == 0:
            self.out.append(f"</{tag}>")

    def handle_data(self, data):
        if self._skipping == 0:
            # Escape teks agar <script> yang lolos via entity tidak jadi tag aktif.
            self.out.append(_html.escape(data, quote=False))

    def handle_entityref(self, name):
        if self._skipping == 0:
            # Pertahankan sebagai entity ter-escape, jangan unescape jadi markup aktif.
            self.out.append(f"&amp;{name};")

    def handle_charref(self, name):
        if self._skipping == 0:
            self.out.append(f"&amp;#{name};")


def sanitize_html(value, max_len=100000):
    """Bersihkan HTML. Tanpa tag di dalamnya → dikembalikan apa adanya."""
    if value is None:
        return None
    s = str(value)
    if "<" not in s:
        return s if len(s) <= max_len else s[:max_len]
    parser = _Sanitizer()
    try:
        parser.feed(s)
        parser.close()
    except Exception:
        return _strip_all_tags(s)[:max_len]
    result = "".join(parser.out).strip()
    return result[:max_len]


def _strip_all_tags(s):
    text = _STRIP_TAG_RE.sub(" ", s)
    text = _html.unescape(text)
    return _re.sub(r"\s+", " ", text).strip()


def plain_text(value):
    """Sanitasi sekaligus ubah menjadi teks polos (buang markup)."""
    if value is None:
        return None
    return _strip_all_tags(str(value))