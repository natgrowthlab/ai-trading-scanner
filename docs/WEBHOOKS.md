# TradingView webhooks

POST JSON (`Content-Type: application/json`) of at most 8 KB to `/api/v1/webhooks/tradingview` with symbol, timeframe, SIGNAL event, direction, price, and secret. The endpoint checks the configured `TRADINGVIEW_WEBHOOK_SECRET` using constant-time comparison and returns 202 only when valid. It accepts data for later validation; it never submits an order or creates a signal from a webhook alone.

Duplicate symbol/timeframe/direction events are suppressed for one minute. The local fallback is in-memory; production horizontal scaling must replace it with an atomic Redis key.

TradingView sends intervals such as 5, 60, 240, and D; the API normalizes those to 5m, 1h, 4h, and 1D.

## Direct Telegram setup (recommended)

The Pine script now sends its formatted BUY/SELL plan straight from TradingView to Telegram. It does not depend on `scanner.natgrowthlab.com` for live delivery.

1. Open the indicator settings and enter your **Telegram chat ID** under **Telegram direct**.
2. Create one TradingView alert with **Condition:** `AI Trading Scanner` → `Any alert() function call` and **Frequency:** once per bar close.
3. In **Webhook URL**, enter `https://api.telegram.org/botYOUR_BOT_TOKEN/sendMessage` using your private bot token. Do not put the token in the Pine source or alert message.
4. Leave the TradingView alert message field empty: the script generates the Telegram JSON with BUY/SELL, entry, TP1/TP2/TP3, SL, timeframe, tier, score, and reasons.

TradingView and Telegram are still separate services: Pine can generate a message but cannot create the alert or set its webhook URL automatically. Keep the bot token private because anyone with it can control the bot.
