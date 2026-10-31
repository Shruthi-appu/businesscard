import io

from PIL import Image

from worker.extract import extract_grounded, render_card


def test_ungrounded_email_is_null() -> None:
    draft = extract_grounded("Ada Lovelace\nAnalytical Engines")
    assert draft["email"] is None
    assert draft["name"] == "Ada Lovelace"
    assert draft["company"] == "Analytical Engines"


def test_original_bytes_survive_thumbnailing() -> None:
    buffer = io.BytesIO()
    Image.new("RGB", (40, 24), (20, 80, 60)).save(buffer, format="JPEG")
    original = buffer.getvalue()
    rendered = render_card(original)
    assert rendered["original_unchanged"] is True
    assert original.startswith(b"\xff\xd8")
    thumbnail = rendered["thumbnail"]
    assert isinstance(thumbnail, bytes)
    assert thumbnail.startswith(b"\x89PNG")
    assert rendered["quad"] == {"left": 0, "top": 0, "right": 40, "bottom": 24}
