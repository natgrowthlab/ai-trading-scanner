from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Protocol


class CandleLike(Protocol):
    timestamp: datetime
    high: float
    low: float
    close: float
    volume: float


@dataclass(frozen=True)
class VolumeSnapshot:
    timestamp: datetime
    volume: float
    sma: float
    ema: float
    relative_volume: float
    is_spike: bool
    obv: float
    vwap: float


@dataclass(frozen=True)
class VolumeConfig:
    period: int = 20
    spike_threshold: float = 1.3


def analyze_volume(
    candles: list[CandleLike], config: VolumeConfig = VolumeConfig()
) -> list[VolumeSnapshot]:
    if config.period < 1:
        raise ValueError("period must be positive")
    snapshots: list[VolumeSnapshot] = []
    ema = 0.0
    obv = 0.0
    cumulative_price_volume = 0.0
    cumulative_volume = 0.0
    multiplier = 2 / (config.period + 1)
    for index, candle in enumerate(candles):
        sample = candles[max(0, index - config.period + 1) : index + 1]
        sma = sum(item.volume for item in sample) / len(sample)
        ema = candle.volume if index == 0 else candle.volume * multiplier + ema * (1 - multiplier)
        if index:
            obv += (
                candle.volume
                if candle.close > candles[index - 1].close
                else -candle.volume
                if candle.close < candles[index - 1].close
                else 0
            )
        cumulative_price_volume += ((candle.high + candle.low + candle.close) / 3) * candle.volume
        cumulative_volume += candle.volume
        snapshots.append(
            VolumeSnapshot(
                candle.timestamp,
                candle.volume,
                sma,
                ema,
                candle.volume / max(sma, 1e-12),
                candle.volume / max(sma, 1e-12) >= config.spike_threshold,
                obv,
                cumulative_price_volume / max(cumulative_volume, 1e-12),
            )
        )
    return snapshots
