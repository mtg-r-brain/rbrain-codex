"""Smoke test for the /health endpoint."""

from app.main import CONTEXT_NAME, health


def test_health_returns_ok() -> None:
    result = health()
    assert result == {"status": "ok", "context": CONTEXT_NAME}
