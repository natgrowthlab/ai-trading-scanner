from datetime import UTC, datetime, timedelta
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from fvg_engine import FVGConfig, FVGDirection, detect_fair_value_gaps


@dataclass
class Candle:
    timestamp: datetime
    high: float
    low: float


def test_detects_and_marks_bullish_gap_as_mitigated():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    candles = [Candle(start + timedelta(minutes=i), high, low) for i, (high, low) in enumerate([(10, 8), (12, 9), (14, 11), (13, 9)])]
    gap = detect_fair_value_gaps(candles, FVGConfig(min_size_atr=0))[0]
    assert gap.direction is FVGDirection.BULLISH
    assert gap.bottom == 10
    assert gap.top == 11
    assert gap.mitigated
