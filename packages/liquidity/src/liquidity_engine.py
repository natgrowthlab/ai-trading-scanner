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
    volume: float


class LiquidityType(StrEnum):
    EQUAL_HIGHS = "EQUAL_HIGHS"
    EQUAL_LOWS = "EQUAL_LOWS"


class SweepDirection(StrEnum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"


@dataclass(frozen=True)
class LiquidityPool:
    type: LiquidityType
    price: float
    touches: int
    first_timestamp: datetime
    last_timestamp: datetime
    strength: float


@dataclass(frozen=True)
class LiquiditySweep:
    direction: SweepDirection
    pool_price: float
    timestamp: datetime
    sweep_size: float
    atr_ratio: float
    volume_spike: float


@dataclass(frozen=True)
class LiquidityConfig:
    equal_level_atr_factor: float = 0.15
    atr_period: int = 14


def detect_liquidity(
    candles: list[CandleLike], config: LiquidityConfig = LiquidityConfig()
) -> tuple[list[LiquidityPool], list[LiquiditySweep]]:
    pools = _equal_pools(candles, config)
    return pools, _sweeps(candles, pools, config)


def _equal_pools(candles: list[CandleLike], config: LiquidityConfig) -> list[LiquidityPool]:
    pools: list[LiquidityPool] = []
    for kind, attribute in ((LiquidityType.EQUAL_HIGHS, "high"), (LiquidityType.EQUAL_LOWS, "low")):
        for index, candle in enumerate(candles):
            price = getattr(candle, attribute)
            tolerance = _atr(candles, index, config.atr_period) * config.equal_level_atr_factor
            matches = [
                candidate
                for candidate in candles[: index + 1]
                if abs(getattr(candidate, attribute) - price) <= tolerance
            ]
            if len(matches) < 2:
                continue
            first = matches[0]
            pool = LiquidityPool(
                kind,
                sum(getattr(item, attribute) for item in matches) / len(matches),
                len(matches),
                first.timestamp,
                candle.timestamp,
                min(1.0, len(matches) / 4),
            )
            if not any(
                existing.type == pool.type and abs(existing.price - pool.price) <= tolerance
                for existing in pools
            ):
                pools.append(pool)
    return pools


def _sweeps(
    candles: list[CandleLike], pools: list[LiquidityPool], config: LiquidityConfig
) -> list[LiquiditySweep]:
    sweeps: list[LiquiditySweep] = []
    for index, candle in enumerate(candles):
        atr = max(_atr(candles, index, config.atr_period), 1e-12)
        average_volume = sum(
            item.volume for item in candles[max(0, index - config.atr_period) : index + 1]
        ) / min(index + 1, config.atr_period)
        for pool in pools:
            if candle.timestamp <= pool.last_timestamp:
                continue
            if pool.type == LiquidityType.EQUAL_LOWS and candle.low < pool.price < candle.close:
                sweeps.append(
                    LiquiditySweep(
                        SweepDirection.BULLISH,
                        pool.price,
                        candle.timestamp,
                        pool.price - candle.low,
                        (pool.price - candle.low) / atr,
                        candle.volume / max(average_volume, 1e-12),
                    )
                )
            if pool.type == LiquidityType.EQUAL_HIGHS and candle.high > pool.price > candle.close:
                sweeps.append(
                    LiquiditySweep(
                        SweepDirection.BEARISH,
                        pool.price,
                        candle.timestamp,
                        candle.high - pool.price,
                        (candle.high - pool.price) / atr,
                        candle.volume / max(average_volume, 1e-12),
                    )
                )
    return sweeps


def _atr(candles: list[CandleLike], index: int, period: int) -> float:
    start = max(0, index - period + 1)
    subset = candles[start : index + 1]
    return sum(candle.high - candle.low for candle in subset) / len(subset)
