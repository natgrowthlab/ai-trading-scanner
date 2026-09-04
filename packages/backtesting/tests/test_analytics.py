import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1]))
from src.analytics import MarketRegime, classify_regime, performance_metrics


class Candle:
    def __init__(self, timestamp, high, low, close):
        self.timestamp, self.high, self.low, self.close = timestamp, high, low, close


def test_classifies_trending_and_high_volatility():
    assert classify_regime([100, 101, 102, 103], [1, 1, 1, 1]) is MarketRegime.TRENDING
    assert classify_regime([100, 101, 102], [1, 1, 3]) is MarketRegime.HIGH_VOLATILITY


def test_metrics_exposes_no_performance_claim_without_trades():
    metrics = performance_metrics([])
    assert metrics.trades == 0
    assert metrics.net_r == 0
