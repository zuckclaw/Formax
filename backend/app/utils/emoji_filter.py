"""Utility module for detecting and stripping emojis from text in Python."""

import re
import unicodedata

_EMOJI_PATTERN = re.compile(
    r"["
    r"\U0001F600-\U0001F64F"  # Emoticons
    r"\U0001F300-\U0001F5FF"  # Misc Symbols and Pictographs
    r"\U0001F680-\U0001F6FF"  # Transport and Map Symbols
    r"\U0001F1E0-\U0001F1FF"  # Flags
    r"\U0001F900-\U0001F9FF"  # Supplemental Symbols and Pictographs
    r"\U0001FA70-\U0001FAFF"  # Symbols and Pictographs Extended-A
    r"\U00002702-\U000027B0"  # Dingbats
    r"\U000024C2-\U0001F251"  # Enclosed Alphanumerics
    r"\U00002600-\U000026FF"  # Misc Symbols
    r"\U00002300-\U000023FF"  # Misc Technical
    r"\U00002B00-\U00002BFF"  # Misc Symbols and Arrows
    r"\U0000FE00-\U0000FE0F"  # Variation Selectors
    r"\u200D"                 # Zero Width Joiner
    r"]+",
    flags=re.UNICODE,
)


def contains_emoji(text: str) -> bool:
    """Return True if text contains any emoji character."""
    if not text:
        return False
    if _EMOJI_PATTERN.search(text):
        return True
    for ch in text:
        cat = unicodedata.category(ch)
        if cat in ("So", "Cn") and ord(ch) > 0x2000:
            return True
    return False


def remove_emojis(text: str) -> str:
    """Remove all emojis from text and return cleaned string."""
    if not text:
        return text
    clean = _EMOJI_PATTERN.sub("", text)
    result = []
    for ch in clean:
        cat = unicodedata.category(ch)
        if cat in ("So", "Cn") and ord(ch) > 0x2000:
            continue
        result.append(ch)
    return "".join(result).strip()
