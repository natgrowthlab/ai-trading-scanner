import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1]))

from src.bot import BinanceScalpingBot, BotConfig
from src.strategy import Candle, Direction, PullbackConfig, PullbackStrategy


def candle(index: int, open_price: float, high: float, low: float, close: float) -> Candle:
    return Candle(datetime(2026, 1, 1, tzinfo=UTC) + timedelta(minutes=index), open_price, high, low, close)


def test_bullish_pullback_generates_long():
    trend = [candle(i, 100 + i, 101 + i, 99 + i, 100.5 + i) for i in range(60)]
    entry = [candle(i, 100 + i * 0.1, 100.3 + i * 0.1, 99.8 + i * 0.1, 100.1 + i * 0.1) for i in range(30)]
    entry[-2] = candle(28, 103.0, 104.2, 102.9, 104.0)
    entry[-1] = candle(29, 103.9, 104.1, 102.2, 104.05)
    decision = PullbackStrategy().evaluate(entry, trend)
    assert decision.direction is Direction.LONG
    assert decision.stop_loss < decision.entry_price


def test_fast_profit_closes_dry_run_position():
    trend = [candle(i, 100 + i, 101 + i, 99 + i, 100.5 + i) for i in range(60)]
    entry = [candle(i, 100 + i * 0.1, 100.3 + i * 0.1, 99.8 + i * 0.1, 100.1 + i * 0.1) for i in range(30)]
    entry[-2] = candle(28, 103.0, 104.2, 102.9, 104.0)
    entry[-1] = candle(29, 103.9, 104.1, 102.2, 104.05)
    bot = BinanceScalpingBot(config=BotConfig(quantity=1, quick_profit_quote=0.5))
    opened = bot.on_closed_candles(entry, trend)
    assert opened.kind == "OPEN"
    closed = bot.on_price(opened.price + 0.6)
    assert closed is not None
    assert closed.kind == "FAST_PROFIT"
