# TradingView webhooks

POST JSON to /api/v1/webhooks/tradingview with symbol, timeframe, SIGNAL event, direction, price, and secret. The endpoint checks the configured TRADINGVIEW_WEBHOOK_SECRET using constant-time comparison and returns 202 only when valid. It accepts data for later validation; it never submits an order or creates a signal from a webhook alone.
