"""Binance USDT-M Futures candle analysis and dry-run trading components."""

from .bot import BinanceFuturesScalpingBot, BotConfig, BotEvent, BotState
from .client import BinanceFuturesPublicClient
from .strategy import Candle, Direction, PullbackConfig, PullbackStrategy, StrategyDecision

__all__ = [
    "BinanceFuturesPublicClient",
    "BinanceFuturesScalpingBot",
    "BotConfig",
    "BotEvent",
    "BotState",
    "Candle",
    "Direction",
    "PullbackConfig",
    "PullbackStrategy",
    "StrategyDecision",
]
