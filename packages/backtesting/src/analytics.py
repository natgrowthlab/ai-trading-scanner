from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from enum import StrEnum
from math import sqrt

from .backtest_engine import BacktestTrade


class MarketRegime(StrEnum):
    TRENDING = "TRENDING"
    RANGING = "RANGING"
    HIGH_VOLATILITY = "HIGH_VOLATILITY"
    LOW_VOLATILITY = "LOW_VOLATILITY"


@dataclass(frozen=True)
class PerformanceMetrics:
    trades: int
    win_rate: float
    net_r: float
    profit_factor: float
    expectancy_r: float
    sharpe_ratio: float
    sortino_ratio: float


def performance_metrics(trades: list[BacktestTrade]) -> PerformanceMetrics:
    returns = [trade.r_multiple for trade in trades]
    trades_count = len(returns)
    wins = sum(value > 0 for value in returns)
    gross_profit = sum(value for value in returns if value > 0)
    gross_loss = abs(sum(value for value in returns if value < 0))
    expectancy = sum(returns) / trades_count if trades_count else 0
    deviation = _standard_deviation(returns)
    downside = _standard_deviation([min(value, 0) for value in returns])
    scale = sqrt(trades_count)
    return PerformanceMetrics(
        trades_count,
        wins / trades_count * 100 if trades_count else 0,
        sum(returns),
        gross_profit / gross_loss if gross_loss else float("inf") if gross_profit else 0,
        expectancy,
        expectancy / deviation * scale if deviation else 0,
        expectancy / downside * scale if downside else 0,
    )


def segment_by_weekday(
    trades: list[BacktestTrade],
) -> dict[str, PerformanceMetrics]:
    groups: dict[str, list[BacktestTrade]] = defaultdict(list)
    for trade in trades:
        groups[trade.exit_at.strftime("%A")].append(trade)
    return {weekday: performance_metrics(items) for weekday, items in groups.items()}


def classify_regime(closes: list[float], atr_values: list[float]) -> MarketRegime:
    if len(closes) < 2 or not atr_values:
        return MarketRegime.RANGING
    normalized_volatility = atr_values[-1] / max(abs(closes[-1]), 1e-12)
    average_volatility = (
        sum(atr_values) / len(atr_values) / max(abs(sum(closes) / len(closes)), 1e-12)
    )
    if normalized_volatility > average_volatility * 1.5:
        return MarketRegime.HIGH_VOLATILITY
    if normalized_volatility < average_volatility * 0.65:
        return MarketRegime.LOW_VOLATILITY
    total_move = abs(closes[-1] - closes[0])
    path = sum(abs(closes[index] - closes[index - 1]) for index in range(1, len(closes)))
    return MarketRegime.TRENDING if path and total_move / path >= 0.6 else MarketRegime.RANGING


def _standard_deviation(values: list[float]) -> float:
    if len(values) < 2:
        return 0
    average = sum(values) / len(values)
    return sqrt(sum((value - average) ** 2 for value in values) / (len(values) - 1))
