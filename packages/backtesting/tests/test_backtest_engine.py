from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parents[1] / "src"))
from backtest_engine import BacktestOrder, Direction, ExitReason, calculate_metrics, execute_order


@dataclass
class Candle:
    timestamp: datetime
    high: float
    low: float
    close: float


def test_stop_has_priority_when_candle_hits_stop_and_target():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    candles = [Candle(start + timedelta(minutes=1), 103, 97, 100)]
    trade = execute_order(
        candles, BacktestOrder(Direction.LONG, 100, 98, 102, start, start + timedelta(minutes=5))
    )
    assert trade.reason is ExitReason.STOP
    assert trade.r_multiple == -1


def test_metrics_are_deterministic():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    winner = execute_order(
        [Candle(start + timedelta(minutes=1), 102, 99.5, 101)],
        BacktestOrder(Direction.LONG, 100, 99, 102, start, start + timedelta(minutes=5)),
    )
    loser = execute_order(
        [Candle(start + timedelta(minutes=1), 101, 99, 100)],
        BacktestOrder(Direction.LONG, 100, 99, 102, start, start + timedelta(minutes=5)),
    )
    metrics = calculate_metrics([winner, loser])
    assert metrics.net_r == 1
    assert metrics.win_rate == 50
