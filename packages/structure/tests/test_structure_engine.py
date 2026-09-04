from datetime import UTC, datetime, timedelta
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from structure_engine import Candle, Direction, StructureLabel, SwingConfig, analyze_market_structure


def candles(values):
    start = datetime(2025, 1, 1, tzinfo=UTC)
    return [Candle(start + timedelta(minutes=i), value, value + 0.2, value - 0.2, value) for i, value in enumerate(values)]


def test_identifies_higher_high_and_higher_low():
    analysis = analyze_market_structure(candles([10, 12, 10, 11, 10.5, 14, 11, 12, 11.5, 16, 13, 14]), SwingConfig(left_bars=1, right_bars=1, atr_multiplier=0))
    labels = [s.label for s in analysis.swings]
    assert StructureLabel.HH in labels
    assert StructureLabel.HL in labels
    assert analysis.trend is Direction.BULLISH


def test_requires_closed_candle_for_bos():
    data = candles([10, 12, 10, 11, 10, 13, 11, 12])
    data[5] = Candle(data[5].timestamp, 11, 13, 10, 11)  # wick only above prior high
    analysis = analyze_market_structure(data, SwingConfig(left_bars=1, right_bars=1, atr_multiplier=0))
    assert not analysis.bos


def test_rejects_unordered_input():
    data = candles([10, 11, 10])
    try:
        analyze_market_structure([data[1], data[0], data[2]])
    except ValueError as error:
        assert "ascending" in str(error)
    else:
        raise AssertionError("expected timestamp validation")
