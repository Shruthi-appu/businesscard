"""Structured card fields. A value is kept only when it appears in the OCR text."""

from __future__ import annotations

import io
import re

from PIL import Image, ImageEnhance, ImageOps

EMAIL = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
PHONE = re.compile(r"^\+[1-9]\d{7,14}$")


def extract_grounded(raw_text: str) -> dict[str, str | None]:
    lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
    used: set[str] = set()

    def take(predicate) -> str | None:
        for line in lines:
            if line in used or not predicate(line):
                continue
            used.add(line)
            return line if line in raw_text else None
        return None

    return {
        "email": take(lambda line: EMAIL.match(line) is not None),
        "phone": take(lambda line: PHONE.match(re.sub(r"[\s()-]", "", line)) is not None),
        "website": take(lambda line: line.lower().startswith(("http://", "https://"))),
        "name": take(lambda _line: True),
        "company": take(lambda _line: True),
    }


def render_card(original: bytes) -> dict[str, object]:
    """Orient, record a full-frame quad, raise contrast, and write a thumbnail.

    The original byte string is not modified.
    """

    before = original
    image = ImageOps.exif_transpose(Image.open(io.BytesIO(original)))
    quad = {"left": 0, "top": 0, "right": image.width, "bottom": image.height}
    enhanced = ImageEnhance.Contrast(image).enhance(1.2)
    thumbnail = enhanced.copy()
    thumbnail.thumbnail((160, 160))
    encoded = io.BytesIO()
    thumbnail.save(encoded, format="PNG")
    return {
        "original_unchanged": original == before,
        "quad": quad,
        "thumbnail": encoded.getvalue(),
    }
