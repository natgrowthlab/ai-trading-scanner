from datetime import UTC, datetime, timedelta
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from volume_engine import VolumeConfig, analyze_volume


@dataclass
class Candle:
    timestamp: datetime
    high: float
    low: float
    close: float
    volume: float


def test_marks_relative_volume_spike():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    candles = [Candle(start + timedelta(minutes=i), 11, 9, 10 + i, volume) for i, volume in enumerate([10, 10, 30])]
    result = analyze_volume(candles, VolumeConfig(period=3, spike_threshold=1.5))
    assert result[-1].is_spike
    assert result[-1].obv > 0
