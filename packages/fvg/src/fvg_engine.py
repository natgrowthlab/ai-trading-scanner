from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from typing import Protocol


class CandleLike(Protocol):
    timestamp: datetime
    high: float
    low: float


class FVGDirection(StrEnum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"


@dataclass(frozen=True)
class FairValueGap:
    direction: FVGDirection
    top: float
    bottom: float
    midpoint: float
    size: float
    atr_ratio: float
    created_at: datetime
    mitigated: bool = False
    mitigation_percent: float = 0.0


@dataclass(frozen=True)
class FVGConfig:
    min_size_atr: float = 0.25
    atr_period: int = 14
    archive_fully_mitigated: bool = False


def detect_fair_value_gaps(
    candles: list[CandleLike], config: FVGConfig = FVGConfig()
) -> list[FairValueGap]:
    """Detect three-candle gaps and calculate subsequent mitigation without future leakage."""
    if config.min_size_atr < 0:
        raise ValueError("min_size_atr must be non-negative")
    gaps: list[FairValueGap] = []
    for index in range(2, len(candles)):
        first, _, third = candles[index - 2 : index + 1]
        atr = max(_atr(candles, index, config.atr_period), 1e-12)
        if third.low > first.high:
            gap = _gap(FVGDirection.BULLISH, third.low, first.high, atr, third.timestamp)
        elif third.high < first.low:
            gap = _gap(FVGDirection.BEARISH, first.low, third.high, atr, third.timestamp)
        else:
            continue
        if gap.atr_ratio < config.min_size_atr:
            continue
        gaps.append(_mitigate(gap, candles[index + 1 :]))
    return [gap for gap in gaps if not (config.archive_fully_mitigated and gap.mitigated)]


def _gap(
    direction: FVGDirection, top: float, bottom: float, atr: float, created_at: datetime
) -> FairValueGap:
    size = top - bottom
    return FairValueGap(direction, top, bottom, (top + bottom) / 2, size, size / atr, created_at)


def _mitigate(gap: FairValueGap, later: list[CandleLike]) -> FairValueGap:
    deepest = gap.top if gap.direction == FVGDirection.BULLISH else gap.bottom
    for candle in later:
        deepest = (
            min(deepest, candle.low)
            if gap.direction == FVGDirection.BULLISH
            else max(deepest, candle.high)
        )
    penetration = (
        gap.top - deepest if gap.direction == FVGDirection.BULLISH else deepest - gap.bottom
    )
    percentage = min(100.0, max(0.0, penetration / gap.size * 100))
    return FairValueGap(
        **{**gap.__dict__, "mitigated": percentage >= 100.0, "mitigation_percent": percentage}
    )


def _atr(candles: list[CandleLike], index: int, period: int) -> float:
    start = max(0, index - period + 1)
    return sum(c.high - c.low for c in candles[start : index + 1]) / (index - start + 1)
