import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from mtf_engine import Bias, TimeframeBias, analyze_mtf


def test_aligns_bullish_timeframes():
    result = analyze_mtf(
        TimeframeBias("4h", Bias.BULLISH, 90),
        TimeframeBias("1h", Bias.BULLISH, 80),
        TimeframeBias("5m", Bias.BULLISH, 70),
    )
    assert result.aligned
    assert result.alignment_score == 82


def test_rejects_conflicting_biases():
    result = analyze_mtf(
        TimeframeBias("4h", Bias.BULLISH, 90),
        TimeframeBias("1h", Bias.BEARISH, 90),
        TimeframeBias("5m", Bias.BULLISH, 90),
    )
    assert not result.aligned
