from worker.health import health


def test_processing_stays_disabled_until_a_later_phase() -> None:
    assert health() == {"status": "ok", "processing": "disabled"}
