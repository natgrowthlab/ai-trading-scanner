from datetime import UTC, datetime, timedelta
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from momentum_engine import MomentumState, analyze_momentum


@dataclass
class Candle:
    timestamp: datetime
    high: float
    low: float
    close: float


def test_rising_prices_produce_bullish_momentum():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    candles = [Candle(start + timedelta(minutes=i), 101 + i, 99 + i, 100 + i) for i in range(20)]
    result = analyze_momentum(candles)
    assert result[-1].state in (MomentumState.BULLISH, MomentumState.VERY_BULLISH)
