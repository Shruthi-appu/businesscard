"""Process presence check. This phase does not read images or call a queue."""


def health() -> dict[str, str]:
    return {"status": "ok", "processing": "disabled"}
