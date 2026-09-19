"""
Konverter rumus Equation Editor Word (OMML) menjadi LaTeX.

Latar: python-docx `Paragraph.text` TIDAK membaca isi `m:oMath` /
`m:oMathPara`, sehingga rumus hilang diam-diam saat import .docx.
Modul ini mengubah node OMML menjadi string LaTeX yang kemudian
di-emit sebagai <span class="ql-formula" data-value="..."> (inline)
atau <div class="math-display-block" data-latex="..."> (display) —
konvensi yang sudah dimengerti frontend (prepareMathHtml) dan
lolos backend sanitize_html.

Tidak pernah melempar: node tak dikenal → fallback teks mentah.
"""

M_NS = "http://schemas.openxmlformats.org/officeDocument/2006/math"


def _local(tag: str) -> str:
    if not isinstance(tag, str):
        return ""
    return tag.split("}")[-1] if "}" in tag else tag


def _children(el):
    try:
        return list(el)
    except Exception:
        return []


def _find(el, *names):
    """Anak langsung dengan localname salah satu dari names."""
    out = []
    for ch in _children(el):
        if _local(ch.tag) in names:
            out.append(ch)
    return out


def _first(el, *names):
    found = _find(el, *names)
    return found[0] if found else None


def _run_text(r_el) -> str:
    """Teks dari sebuah m:r (run matematika)."""
    parts = []
    for node in r_el.iter():
        if _local(getattr(node, "tag", "")) == "t" and node.text:
            parts.append(node.text)
    return "".join(parts)


def _text_of(el) -> str:
    """Gabungan teks semua m:r di bawah el (untuk fallback)."""
    parts = []
    for node in el.iter():
        if _local(getattr(node, "tag", "")) == "r":
            parts.append(_run_text(node))
    return "".join(parts)


def _convert(el) -> str:
    """Konversi rekursif satu node OMML → LaTeX. Tidak pernah throw."""
    try:
        return _convert_inner(el)
    except Exception:
        try:
            return _text_of(el)
        except Exception:
            return ""


def _convert_inner(el) -> str:
    name = _local(el.tag)

    if name in ("oMath", "oMathPara"):
        return "".join(_convert(ch) for ch in _children(el))

    if name == "r":
        return _run_text(el)

    if name in ("t",):
        return el.text or ""

    if name == "f":  # fraction: num / den
        num = _first(el, "num")
        den = _first(el, "den")
        n = "".join(_convert(ch) for ch in _children(num)) if num is not None else ""
        d = "".join(_convert(ch) for ch in _children(den)) if den is not None else ""
        return "\\frac{%s}{%s}" % (n, d)

    if name == "sSup":  # base^{sup}
        base = _first(el, "e")
        sup = _first(el, "sup")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        s = "".join(_convert(ch) for ch in _children(sup)) if sup is not None else ""
        return "%s^{%s}" % (b, s)

    if name == "sSub":  # base_{sub}
        base = _first(el, "e")
        sub = _first(el, "sub")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        s = "".join(_convert(ch) for ch in _children(sub)) if sub is not None else ""
        return "%s_{%s}" % (b, s)

    if name == "sSubSup":  # base_{sub}^{sup}
        base = _first(el, "e")
        sub = _first(el, "sub")
        sup = _first(el, "sup")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        s1 = "".join(_convert(ch) for ch in _children(sub)) if sub is not None else ""
        s2 = "".join(_convert(ch) for ch in _children(sup)) if sup is not None else ""
        return "%s_{%s}^{%s}" % (b, s1, s2)

    if name == "rad":  # akar: deg + e
        deg = _first(el, "deg")
        base = _first(el, "e")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        d = "".join(_convert(ch) for ch in _children(deg)) if deg is not None else ""
        d = d.strip()
        if d:
            return "\\sqrt[%s]{%s}" % (d, b)
        return "\\sqrt{%s}" % b

    if name == "d":  # delimiter: begChr / endChr
        beg, end = "(", ")"
        dpr = _first(el, "dPr")
        if dpr is not None:
            b = _first(dpr, "begChr")
            e = _first(dpr, "endChr")
            if b is not None:
                beg = (b.get("{%s}val" % M_NS) or b.get("val") or "(").strip() or "("
            if e is not None:
                end = (e.get("{%s}val" % M_NS) or e.get("val") or ")").strip() or ")"
        inner = "".join(_convert(ch) for ch in _children(el) if _local(ch.tag) == "e")
        left = "\\left%s" % beg if beg != "|" else "\\left|"
        right = "\\right%s" % end if end != "|" else "\\right|"
        if beg == "" or beg is None:
            left = "\\left."
        if end == "" or end is None:
            right = "\\right."
        return "%s%s%s" % (left, inner, right)

    if name == "nary":  # sum / integral / prod + sub/sup
        chr_val = "∑"
        narypr = _first(el, "naryPr")
        if narypr is not None:
            c = _first(narypr, "chr")
            if c is not None:
                chr_val = (c.get("{%s}val" % M_NS) or c.get("val") or "∑").strip() or "∑"
        mapping = {"∑": "\\sum", "∏": "\\prod", "∫": "\\int", "∬": "\\iint", "∮": "\\oint", "⋃": "\\bigcup", "⋂": "\\bigcap"}
        op = mapping.get(chr_val, chr_val)
        sub = _first(el, "sub")
        sup = _first(el, "sup")
        base = _first(el, "e")
        s1 = "".join(_convert(ch) for ch in _children(sub)) if sub is not None else ""
        s2 = "".join(_convert(ch) for ch in _children(sup)) if sup is not None else ""
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        out = op
        if s1.strip():
            out += "_{%s}" % s1
        if s2.strip():
            out += "^{%s}" % s2
        return "%s{%s}" % (out, b) if b else out

    if name == "limLow":  # undeset{lim}{e}
        base = _first(el, "e")
        lim = _first(el, "lim")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        l = "".join(_convert(ch) for ch in _children(lim)) if lim is not None else ""
        return "\\underset{%s}{%s}" % (l, b)

    if name == "limUpp":  # overset{lim}{e}
        base = _first(el, "e")
        lim = _first(el, "lim")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        l = "".join(_convert(ch) for ch in _children(lim)) if lim is not None else ""
        return "\\overset{%s}{%s}" % (l, b)

    if name == "bar":  # overline / underline
        base = _first(el, "e")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        pos = "top"
        barpr = _first(el, "barPr")
        if barpr is not None:
            p = _first(barpr, "pos")
            if p is not None:
                pos = (p.get("{%s}val" % M_NS) or p.get("val") or "top").strip()
        if pos == "bot":
            return "\\underline{%s}" % b
        return "\\overline{%s}" % b

    if name == "acc":  # aksen: ^ ~ dst → fallback hat/bar
        base = _first(el, "e")
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        return "\\hat{%s}" % b if b else b

    if name == "func":  # sin/cos/log + argumen
        fname = _first(el, "fName")
        base = _first(el, "e")
        fn = "".join(_convert(ch) for ch in _children(fname)) if fname is not None else ""
        b = "".join(_convert(ch) for ch in _children(base)) if base is not None else ""
        fn = fn.strip().lstrip("\\")
        known = {"sin", "cos", "tan", "log", "ln", "lim", "exp", "min", "max"}
        if fn in known:
            return "\\%s{%s}" % (fn, b) if b else "\\%s" % fn
        return "%s%s" % (fn, ("{%s}" % b) if b else "")

    if name == "eqArr":  # baris-baris persamaan
        rows = []
        for ch in _children(el):
            if _local(ch.tag) == "e":
                rows.append("".join(_convert(g) for g in _children(ch)))
        return " \\\\ ".join(rows)

    if name in ("box", "groupChr", "borderBox", "phantom"):
        return "".join(_convert(ch) for ch in _children(el) if _local(ch.tag) == "e") or "".join(
            _convert(ch) for ch in _children(el)
        )

    if name in ("e", "num", "den", "deg", "sub", "sup", "lim", "dPr", "naryPr", "barPr", "fName"):
        return "".join(_convert(ch) for ch in _children(el))

    # Elemen struktur lain (mPr,_ctrlPr,dll): lewati, tapi render anak yang relevan
    if name in ("mPr", "ctrlPr", "rPr", "t"):
        return "".join(_convert(ch) for ch in _children(el))

    # Fallback umum: gabung anak; kalau kosong, teks mentah
    kids = "".join(_convert(ch) for ch in _children(el))
    if kids:
        return kids
    return _text_of(el)


def _is_omath(el) -> bool:
    return _local(getattr(el, "tag", "")) == "oMath"


def _is_omath_para(el) -> bool:
    return _local(getattr(el, "tag", "")) == "oMathPara"


def iter_math_nodes(paragraph_element):
    """Yield (latex, display) untuk tiap blok matematika di elemen paragraf.

    display=True untuk m:oMathPara (rata tengah), False untuk m:oMath inline.
    oMath di dalam oMathPara tidak dihitung ganda.
    """
    try:
        children = list(paragraph_element)
    except Exception:
        return
    for ch in children:
        try:
            if _is_omath_para(ch):
                parts = []
                for node in ch.iter():
                    if _is_omath(node):
                        latex = _convert(node).strip()
                        if latex:
                            parts.append(latex)
                if parts:
                    yield (" \\\\ ".join(parts), True)
            elif _is_omath(ch):
                latex = _convert(ch).strip()
                if latex:
                    yield (latex, False)
        except Exception:
            continue
