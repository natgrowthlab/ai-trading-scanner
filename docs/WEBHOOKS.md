# TradingView webhooks

POST JSON to /api/v1/webhooks/tradingview with symbol, timeframe, SIGNAL event, direction, price, and secret. The endpoint checks the configured TRADINGVIEW_WEBHOOK_SECRET using constant-time comparison and returns 202 only when valid. It accepts data for later validation; it never submits an order or creates a signal from a webhook alone.

Duplicate symbol/timeframe/direction events are suppressed inside a five-minute bucket. The local fallback is in-memory; production horizontal scaling must replace it with an atomic Redis key.

TradingView sends intervals such as 5, 60, 240, and D; the API normalizes those to 5m, 1h, 4h, and 1D.
