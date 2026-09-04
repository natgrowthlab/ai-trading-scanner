from datetime import UTC, datetime, timedelta
from hashlib import sha256


class WebhookDeduplicator:
    """In-memory fallback. Replace with Redis SET NX in multi-instance production."""

    def __init__(self, bucket_minutes: int = 5):
        self.bucket_minutes = bucket_minutes
        self._seen: dict[str, datetime] = {}

    def accept(
        self, symbol: str, timeframe: str, direction: str, at: datetime | None = None
    ) -> bool:
        current = at or datetime.now(UTC)
        bucket = int(current.timestamp() // (self.bucket_minutes * 60))
        key = sha256(f"{symbol}:{timeframe}:{direction}:{bucket}".encode()).hexdigest()
        self._seen = {item: expiry for item, expiry in self._seen.items() if expiry > current}
        if key in self._seen:
            return False
        self._seen[key] = current + timedelta(minutes=self.bucket_minutes)
        return True


webhook_deduplicator = WebhookDeduplicator()
