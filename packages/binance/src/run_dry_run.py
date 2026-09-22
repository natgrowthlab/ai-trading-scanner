"""Run one public Binance analysis cycle without sending an order.

Usage: PYTHONPATH=packages/binance python -m src.run_dry_run
"""

from __future__ import annotations

import json
import os

from .bot import BinanceScalpingBot
from .client import BinancePublicClient


def main() -> None:
    symbol = os.getenv("BINANCE_SYMBOL", "BTCUSDT")
    interval = os.getenv("BINANCE_INTERVAL", "1m")
    client = BinancePublicClient()
    bot = BinanceScalpingBot()
    try:
        entry = client.get_closed_klines(symbol, interval)
        trend = client.get_closed_klines(symbol, "15m")
    except RuntimeError as error:
        print(json.dumps({"mode": "DRY_RUN", "symbol": symbol, "status": "CONNECTION_ERROR", "message": str(error)}))
        return
    event = bot.on_closed_candles(entry, trend)
    print(json.dumps({"mode": "DRY_RUN", "symbol": symbol, "interval": interval, "state": bot.state, "event": event.kind, "message": event.message, "price": event.price}, default=str))


if __name__ == "__main__":
    main()
