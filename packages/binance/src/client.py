"""Public Binance USDT-M Futures candle client. No API key is used or accepted here."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import urlopen

from .strategy import Candle


class BinanceFuturesPublicClient:
    base_url = "https://fapi.binance.com"

    def get_closed_klines(self, symbol: str, interval: str, limit: int = 250) -> list[Candle]:
        if not symbol.isalnum() or symbol.upper() != symbol:
            raise ValueError("symbol must be uppercase alphanumeric, for example BTCUSDT")
        if limit < 2 or limit > 1000:
            raise ValueError("limit must be between 2 and 1000")
        query = urlencode({"symbol": symbol, "interval": interval, "limit": limit})
        try:
            with urlopen(f"{self.base_url}/fapi/v1/klines?{query}", timeout=10) as response:  # noqa: S310 public fixed host
                payload = json.load(response)
        except HTTPError as error:
            raise RuntimeError(f"Binance rejected the candle request ({error.code})") from error
        except URLError as error:
            raise RuntimeError(
                "Unable to reach Binance. Check network access, regional availability, and local TLS certificates."
            ) from error
        if not isinstance(payload, list):
            raise RuntimeError("unexpected Binance kline response")
        # Binance includes the in-progress candle as the final item; omit it.
        rows = payload[:-1]
        return [
            Candle(
                timestamp=datetime.fromtimestamp(row[0] / 1000, tz=UTC),
                open=float(row[1]),
                high=float(row[2]),
                low=float(row[3]),
                close=float(row[4]),
            )
            for row in rows
        ]
