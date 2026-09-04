from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from typing import Protocol


class CandleLike(Protocol):
    timestamp: datetime
    high: float
    low: float
    close: float


class MomentumState(StrEnum):
    VERY_BEARISH = "VERY_BEARISH"
    BEARISH = "BEARISH"
    NEUTRAL = "NEUTRAL"
    BULLISH = "BULLISH"
    VERY_BULLISH = "VERY_BULLISH"


@dataclass(frozen=True)
class MomentumSnapshot:
    timestamp: datetime
    rsi: float
    roc: float
    atr: float
    ema_slope: float
    score: int
    state: MomentumState


@dataclass(frozen=True)
class MomentumConfig:
    rsi_period: int = 14
    ema_period: int = 20
    roc_period: int = 10
    atr_period: int = 14


def analyze_momentum(
    candles: list[CandleLike], config: MomentumConfig = MomentumConfig()
) -> list[MomentumSnapshot]:
    snapshots: list[MomentumSnapshot] = []
    closes = [c.close for c in candles]
    for index, candle in enumerate(candles):
        rsi = _rsi(closes, index, config.rsi_period)
        roc_index = max(0, index - config.roc_period)
        roc = (candle.close - closes[roc_index]) / max(abs(closes[roc_index]), 1e-12) * 100
        ema_now = _ema(closes[: index + 1], config.ema_period)
        ema_before = _ema(closes[:index], config.ema_period) if index else ema_now
        slope = (ema_now - ema_before) / max(abs(ema_before), 1e-12) * 100
        atr = _atr(candles, index, config.atr_period)
        score = max(0, min(100, round(50 + (rsi - 50) * 0.8 + roc * 2 + slope * 10)))
        snapshots.append(
            MomentumSnapshot(candle.timestamp, rsi, roc, atr, slope, score, _state(score))
        )
    return snapshots


def _rsi(values: list[float], index: int, period: int) -> float:
    if index == 0:
        return 50.0
    sample = values[max(1, index - period + 1) : index + 1]
    changes = [sample[i] - sample[i - 1] for i in range(1, len(sample))]
    gains = sum(max(change, 0) for change in changes)
    losses = sum(max(-change, 0) for change in changes)
    if losses == 0:
        return 100.0 if gains else 50.0
    relative_strength = gains / losses
    return 100 - 100 / (1 + relative_strength)


def _ema(values: list[float], period: int) -> float:
    if not values:
        return 0.0
    alpha = 2 / (period + 1)
    result = values[0]
    for value in values[1:]:
        result = value * alpha + result * (1 - alpha)
    return result


def _atr(candles: list[CandleLike], index: int, period: int) -> float:
    start = max(0, index - period + 1)
    subset = candles[start : index + 1]
    return sum(candle.high - candle.low for candle in subset) / len(subset)


def _state(score: int) -> MomentumState:
    if score >= 75:
        return MomentumState.VERY_BULLISH
    if score >= 60:
        return MomentumState.BULLISH
    if score <= 25:
        return MomentumState.VERY_BEARISH
    if score <= 40:
        return MomentumState.BEARISH
    return MomentumState.NEUTRAL
