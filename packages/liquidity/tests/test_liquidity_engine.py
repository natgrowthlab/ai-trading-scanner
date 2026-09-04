from datetime import UTC, datetime, timedelta
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from liquidity_engine import LiquidityConfig, LiquidityType, SweepDirection, detect_liquidity


@dataclass
class Candle:
    timestamp: datetime
    high: float
    low: float
    close: float
    volume: float = 10


def test_detects_equal_lows_and_bullish_sweep():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    rows = [(11, 10, 10.5), (12, 10.05, 11), (12, 9.5, 10.5)]
    candles = [Candle(start + timedelta(minutes=i), *row) for i, row in enumerate(rows)]
    pools, sweeps = detect_liquidity(candles, LiquidityConfig(equal_level_atr_factor=0.1))
    assert any(pool.type is LiquidityType.EQUAL_LOWS for pool in pools)
    assert any(sweep.direction is SweepDirection.BULLISH for sweep in sweeps)
