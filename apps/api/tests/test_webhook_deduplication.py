from datetime import UTC, datetime

from app.services.webhook_deduplication import WebhookDeduplicator


def test_rejects_duplicate_inside_same_bucket():
    deduplicator = WebhookDeduplicator()
    now = datetime(2025, 1, 1, tzinfo=UTC)
    assert deduplicator.accept("XAUUSD", "5m", "LONG", now)
    assert not deduplicator.accept("XAUUSD", "5m", "LONG", now)
    assert deduplicator.accept("XAUUSD", "5m", "SHORT", now)
