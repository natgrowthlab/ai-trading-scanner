"""Deterministic, closed-candle pullback strategy used by the Binance dry-run bot.

This module deliberately contains no exchange credentials or order placement.  It is
kept pure so every change can be tested against historical candles before it is used
with a testnet or a live exchange adapter.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class Direction(StrEnum):
    LONG = "LONG"
    SHORT = "SHORT"
    FLAT = "FLAT"


@dataclass(frozen=True)
class Candle:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float


@dataclass(frozen=True)
class PullbackConfig:
    ema_period: int = 20
    trend_ema_period: int = 50
    atr_period: int = 14
    minimum_impulse_atr: float = 0.30
    minimum_rejection_ratio: float = 0.20
    ema_touch_atr_tolerance: float = 0.10
    stop_atr_buffer: float = 0.15


@dataclass(frozen=True)
class StrategyDecision:
    direction: Direction
    reason: str
    entry_price: float | None = None
    stop_loss: float | None = None
    signal_time: datetime | None = None

    @property
    def is_entry(self) -> bool:
        return self.direction in (Direction.LONG, Direction.SHORT)


class PullbackStrategy:
    """Trend + impulse + EMA-rejection strategy for closed 1m/5m candles.

    ``entry_candles`` is the trading timeframe and ``trend_candles`` is normally
    15m.  A signal needs a directional higher-timeframe trend, a preceding impulse,
    and a rejection that revisits the entry EMA.  This is a setup detector, not a
    profitability guarantee.
    """

    def __init__(self, config: PullbackConfig | None = None) -> None:
        self.config = config or PullbackConfig()

    def evaluate(
        self, entry_candles: list[Candle], trend_candles: list[Candle]
    ) -> StrategyDecision:
        minimum_entry = max(self.config.ema_period + 2, self.config.atr_period + 2)
        if len(entry_candles) < minimum_entry:
            return StrategyDecision(Direction.FLAT, "waiting for entry candle history")
        if len(trend_candles) < self.config.trend_ema_period:
            return StrategyDecision(Direction.FLAT, "waiting for trend candle history")

        trend_ema = _ema([c.close for c in trend_candles], self.config.trend_ema_period)[-1]
        trend_close = trend_candles[-1].close
        trend = Direction.LONG if trend_close > trend_ema else Direction.SHORT if trend_close < trend_ema else Direction.FLAT
        if trend is Direction.FLAT:
            return StrategyDecision(Direction.FLAT, "neutral higher-timeframe trend")

        signal = entry_candles[-1]
        impulse = entry_candles[-2]
        atr = _atr(entry_candles, self.config.atr_period)
        entry_ema = _ema([c.close for c in entry_candles], self.config.ema_period)[-1]
        if atr <= 0:
            return StrategyDecision(Direction.FLAT, "invalid ATR")

        body = abs(signal.close - signal.open)
        tolerance = atr * self.config.ema_touch_atr_tolerance
        if trend is Direction.LONG:
            impulse_ok = impulse.close > impulse.open and (impulse.close - impulse.open) >= atr * self.config.minimum_impulse_atr
            lower_wick = min(signal.open, signal.close) - signal.low
            rejection_ok = signal.close > signal.open and lower_wick >= body * self.config.minimum_rejection_ratio
            touched_ema = signal.low <= entry_ema + tolerance
            if not impulse_ok:
                return StrategyDecision(Direction.FLAT, "no bullish impulse")
            if not touched_ema or not rejection_ok:
                return StrategyDecision(Direction.FLAT, "no confirmed bullish pullback")
            return StrategyDecision(
                Direction.LONG,
                "bullish trend pullback confirmed",
                signal.close,
                signal.low - atr * self.config.stop_atr_buffer,
                signal.timestamp,
            )

        impulse_ok = impulse.close < impulse.open and (impulse.open - impulse.close) >= atr * self.config.minimum_impulse_atr
        upper_wick = signal.high - max(signal.open, signal.close)
        rejection_ok = signal.close < signal.open and upper_wick >= body * self.config.minimum_rejection_ratio
        touched_ema = signal.high >= entry_ema - tolerance
        if not impulse_ok:
            return StrategyDecision(Direction.FLAT, "no bearish impulse")
        if not touched_ema or not rejection_ok:
            return StrategyDecision(Direction.FLAT, "no confirmed bearish pullback")
        return StrategyDecision(
            Direction.SHORT,
            "bearish trend pullback confirmed",
            signal.close,
            signal.high + atr * self.config.stop_atr_buffer,
            signal.timestamp,
        )


def _ema(values: list[float], period: int) -> list[float]:
    if len(values) < period:
        raise ValueError("not enough values for EMA")
    multiplier = 2 / (period + 1)
    current = sum(values[:period]) / period
    result = [current] * period
    for value in values[period:]:
        current = (value - current) * multiplier + current
        result.append(current)
    return result


def _atr(candles: list[Candle], period: int) -> float:
    if len(candles) < period + 1:
        raise ValueError("not enough candles for ATR")
    ranges = [
        max(candle.high - candle.low, abs(candle.high - prior.close), abs(candle.low - prior.close))
        for prior, candle in zip(candles[-period - 1 : -1], candles[-period:])
    ]
    return sum(ranges) / len(ranges)
