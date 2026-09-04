from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from typing import Protocol


class CandleLike(Protocol):
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float


class BreakLike(Protocol):
    kind: str
    direction: str
    timestamp: datetime


class FVGLike(Protocol):
    top: float
    bottom: float


class OrderBlockDirection(StrEnum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"


@dataclass(frozen=True)
class OrderBlock:
    direction: OrderBlockDirection
    top: float
    bottom: float
    created_at: datetime
    score: int
    bos_confirmed: bool
    fvg_confirmed: bool
    displacement_ratio: float
    relative_volume: float


@dataclass(frozen=True)
class OrderBlockConfig:
    displacement_atr: float = 1.2
    relative_volume: float = 1.3
    atr_period: int = 14


def detect_order_blocks(
    candles: list[CandleLike],
    breaks: list[BreakLike],
    gaps: list[FVGLike],
    config: OrderBlockConfig = OrderBlockConfig(),
) -> list[OrderBlock]:
    """Find the last opposing candle before a BOS displacement."""
    blocks: list[OrderBlock] = []
    for event in breaks:
        if event.kind != "BOS":
            continue
        direction = OrderBlockDirection(event.direction)
        break_index = next(
            (i for i, candle in enumerate(candles) if candle.timestamp == event.timestamp), None
        )
        if break_index is None or break_index == 0:
            continue
        candidate = _last_opposing(candles[:break_index], direction)
        if candidate is None:
            continue
        atr = max(_atr(candles, break_index, config.atr_period), 1e-12)
        displacement = abs(candles[break_index].close - candles[break_index].open) / atr
        average_volume = sum(
            c.volume for c in candles[max(0, break_index - config.atr_period) : break_index]
        ) / min(break_index, config.atr_period)
        relative_volume = candles[break_index].volume / max(average_volume, 1e-12)
        if displacement < config.displacement_atr or relative_volume < config.relative_volume:
            continue
        top, bottom = candidate.high, candidate.low
        fvg_confirmed = any(gap.bottom <= top and gap.top >= bottom for gap in gaps)
        score = min(
            100,
            round(
                50
                + min(25, displacement * 10)
                + min(15, relative_volume * 5)
                + (10 if fvg_confirmed else 0)
            ),
        )
        blocks.append(
            OrderBlock(
                direction,
                top,
                bottom,
                candidate.timestamp,
                score,
                True,
                fvg_confirmed,
                displacement,
                relative_volume,
            )
        )
    return blocks


def _last_opposing(candles: list[CandleLike], direction: OrderBlockDirection) -> CandleLike | None:
    for candle in reversed(candles):
        if (direction == OrderBlockDirection.BULLISH and candle.close < candle.open) or (
            direction == OrderBlockDirection.BEARISH and candle.close > candle.open
        ):
            return candle
    return None


def _atr(candles: list[CandleLike], index: int, period: int) -> float:
    start = max(0, index - period + 1)
    subset = candles[start : index + 1]
    return sum(candle.high - candle.low for candle in subset) / len(subset)
