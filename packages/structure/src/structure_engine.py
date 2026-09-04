from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import StrEnum
from statistics import mean


class SwingType(StrEnum):
    HIGH = "SWING_HIGH"
    LOW = "SWING_LOW"


class StructureLabel(StrEnum):
    HH = "HH"
    HL = "HL"
    LH = "LH"
    LL = "LL"


class Direction(StrEnum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"
    NEUTRAL = "NEUTRAL"


@dataclass(frozen=True)
class Candle:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float = 0.0


@dataclass(frozen=True)
class Swing:
    type: SwingType
    price: float
    timestamp: datetime
    strength: float
    confirmed: bool
    confirmation_timestamp: datetime
    label: StructureLabel | None = None


@dataclass(frozen=True)
class StructureEvent:
    kind: str
    direction: Direction
    price: float
    timestamp: datetime
    confidence: float


@dataclass(frozen=True)
class MarketStructureAnalysis:
    swings: list[Swing]
    trend: Direction
    bos: list[StructureEvent] = field(default_factory=list)
    choch: list[StructureEvent] = field(default_factory=list)


@dataclass(frozen=True)
class SwingConfig:
    left_bars: int = 3
    right_bars: int = 3
    atr_multiplier: float = 0.5
    atr_period: int = 14


def _atr(candles: list[Candle], index: int, period: int) -> float:
    start = max(1, index - period + 1)
    ranges = [
        max(
            candles[i].high - candles[i].low,
            abs(candles[i].high - candles[i - 1].close),
            abs(candles[i].low - candles[i - 1].close),
        )
        for i in range(start, index + 1)
    ]
    return mean(ranges) if ranges else candles[index].high - candles[index].low


def analyze_market_structure(
    candles: list[Candle], config: SwingConfig = SwingConfig()
) -> MarketStructureAnalysis:
    """Return confirmed swings and close-confirmed BOS/CHoCH events without lookahead."""
    if config.left_bars < 1 or config.right_bars < 1:
        raise ValueError("left_bars and right_bars must be positive")
    if any(candles[i].timestamp >= candles[i + 1].timestamp for i in range(len(candles) - 1)):
        raise ValueError("candles must be in strictly ascending timestamp order")
    if len(candles) < config.left_bars + config.right_bars + 1:
        return MarketStructureAnalysis(swings=[], trend=Direction.NEUTRAL)

    swings: list[Swing] = []
    previous_by_type: dict[SwingType, Swing] = {}
    for index in range(config.left_bars, len(candles) - config.right_bars):
        current = candles[index]
        window = candles[index - config.left_bars : index + config.right_bars + 1]
        candidates = (
            (
                SwingType.HIGH,
                current.high,
                current.high == max(c.high for c in window)
                and sum(c.high == current.high for c in window) == 1,
            ),
            (
                SwingType.LOW,
                current.low,
                current.low == min(c.low for c in window)
                and sum(c.low == current.low for c in window) == 1,
            ),
        )
        atr = max(_atr(candles, index, config.atr_period), 1e-12)
        for swing_type, price, is_candidate in candidates:
            if not is_candidate:
                continue
            previous = previous_by_type.get(swing_type)
            if previous and abs(price - previous.price) < atr * config.atr_multiplier:
                continue
            label = None
            if previous:
                if swing_type == SwingType.HIGH:
                    label = StructureLabel.HH if price > previous.price else StructureLabel.LH
                else:
                    label = StructureLabel.HL if price > previous.price else StructureLabel.LL
            strength = min(1.0, abs(price - (previous.price if previous else current.close)) / atr)
            swing = Swing(
                swing_type,
                price,
                current.timestamp,
                strength,
                True,
                candles[index + config.right_bars].timestamp,
                label,
            )
            swings.append(swing)
            previous_by_type[swing_type] = swing

    bos, choch = _detect_breaks(candles, swings)
    return MarketStructureAnalysis(swings=swings, trend=_trend(swings), bos=bos, choch=choch)


def _trend(swings: list[Swing]) -> Direction:
    labels = [s.label for s in swings if s.label]
    if len(labels) < 2:
        return Direction.NEUTRAL
    recent = labels[-4:]
    bullish = sum(label in (StructureLabel.HH, StructureLabel.HL) for label in recent)
    bearish = sum(label in (StructureLabel.LH, StructureLabel.LL) for label in recent)
    return (
        Direction.BULLISH
        if bullish > bearish
        else Direction.BEARISH
        if bearish > bullish
        else Direction.NEUTRAL
    )


def _detect_breaks(
    candles: list[Candle], swings: list[Swing]
) -> tuple[list[StructureEvent], list[StructureEvent]]:
    bos: list[StructureEvent] = []
    choch: list[StructureEvent] = []
    last_high: Swing | None = None
    last_low: Swing | None = None
    bias = Direction.NEUTRAL
    swing_index = 0
    for candle in candles:
        while (
            swing_index < len(swings)
            and swings[swing_index].confirmation_timestamp <= candle.timestamp
        ):
            swing = swings[swing_index]
            if swing.type == SwingType.HIGH:
                last_high = swing
            else:
                last_low = swing
            swing_index += 1
        if last_high and candle.close > last_high.price:
            event = StructureEvent(
                "BOS", Direction.BULLISH, last_high.price, candle.timestamp, last_high.strength
            )
            (choch if bias == Direction.BEARISH else bos).append(event)
            bias = Direction.BULLISH
            last_high = None
        elif last_low and candle.close < last_low.price:
            event = StructureEvent(
                "BOS", Direction.BEARISH, last_low.price, candle.timestamp, last_low.strength
            )
            (choch if bias == Direction.BULLISH else bos).append(event)
            bias = Direction.BEARISH
            last_low = None
    return bos, choch
