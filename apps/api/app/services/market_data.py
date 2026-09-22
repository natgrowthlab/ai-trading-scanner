from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from pydantic import BaseModel, model_validator


class CandleData(BaseModel):
    symbol: str
    timeframe: str
    timestamp: datetime
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal
    volume: Decimal = Decimal("0")
    quote_volume: Decimal | None = None
    trades: int | None = None
    buy_volume: Decimal | None = None
    sell_volume: Decimal | None = None
    open_interest: Decimal | None = None
    funding_rate: Decimal | None = None

    @model_validator(mode="after")
    def validate_ohlc(self) -> "CandleData":
        if self.low > min(self.open, self.close) or self.high < max(self.open, self.close):
            raise ValueError("OHLC values are inconsistent")
        if self.timestamp.tzinfo is None:
            raise ValueError("timestamp must be timezone-aware")
        return self


class Quote(BaseModel):
    symbol: str
    bid: Decimal
    ask: Decimal
    timestamp: datetime


class MarketDataProvider(ABC):
    @abstractmethod
    async def get_candles(self, symbol: str, timeframe: str, limit: int) -> list[CandleData]: ...
    @abstractmethod
    async def get_quote(self, symbol: str) -> Quote: ...
    @abstractmethod
    async def get_orderbook(self, symbol: str) -> dict: ...
    @abstractmethod
    async def get_trades(self, symbol: str) -> list[dict]: ...
    @abstractmethod
    async def stream_quotes(self, symbols: list[str]) -> AsyncIterator[Quote]: ...


class MockMarketDataProvider(MarketDataProvider):
    """Deterministic provider for tests and local development only."""

    async def get_candles(self, symbol: str, timeframe: str, limit: int) -> list[CandleData]:
        interval = {
            "1m": 1,
            "3m": 3,
            "5m": 5,
            "15m": 15,
            "30m": 30,
            "1h": 60,
            "4h": 240,
            "1D": 1440,
        }[timeframe]
        start = datetime(2025, 1, 1, tzinfo=UTC)
        base = Decimal("60000") if symbol == "BTCUSDT" else Decimal("3000")
        return [
            CandleData(
                symbol=symbol,
                timeframe=timeframe,
                timestamp=start + timedelta(minutes=interval * i),
                open=base + i,
                high=base + i + 2,
                low=base + i - 1,
                close=base + i + 1,
                volume=Decimal("1000") + i,
            )
            for i in range(limit)
        ]

    async def get_quote(self, symbol: str) -> Quote:
        return Quote(
            symbol=symbol, bid=Decimal("100"), ask=Decimal("100.1"), timestamp=datetime.now(UTC)
        )

    async def get_orderbook(self, symbol: str) -> dict:
        return {"symbol": symbol, "bids": [], "asks": []}

    async def get_trades(self, symbol: str) -> list[dict]:
        return []

    async def stream_quotes(self, symbols: list[str]) -> AsyncIterator[Quote]:
        for symbol in symbols:
            yield await self.get_quote(symbol)
