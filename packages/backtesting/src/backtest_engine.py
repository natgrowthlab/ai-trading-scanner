from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from typing import Protocol


class CandleLike(Protocol):
    timestamp: datetime
    high: float
    low: float
    close: float


class Direction(StrEnum):
    LONG = "LONG"
    SHORT = "SHORT"


class ExitReason(StrEnum):
    TARGET = "TARGET"
    STOP = "STOP"
    EXPIRED = "EXPIRED"


@dataclass(frozen=True)
class BacktestOrder:
    direction: Direction
    entry: float
    stop_loss: float
    take_profit: float
    created_at: datetime
    expires_at: datetime


@dataclass(frozen=True)
class BacktestTrade:
    entry_at: datetime | None
    exit_at: datetime
    exit_price: float
    r_multiple: float
    reason: ExitReason
    mae_r: float
    mfe_r: float


@dataclass(frozen=True)
class BacktestMetrics:
    total_trades: int
    wins: int
    losses: int
    win_rate: float
    profit_factor: float
    expectancy_r: float
    net_r: float
    maximum_drawdown_r: float


def execute_order(candles: list[CandleLike], order: BacktestOrder) -> BacktestTrade:
    """Process candles in timestamp order; adverse fills win when a candle crosses both levels."""
    if order.stop_loss == order.entry:
        raise ValueError("entry and stop loss must differ")
    entry_at: datetime | None = None
    mae_r = 0.0
    mfe_r = 0.0
    risk = abs(order.entry - order.stop_loss)
    for candle in candles:
        if candle.timestamp <= order.created_at:
            continue
        if candle.timestamp > order.expires_at:
            return _close(
                entry_at, candle.timestamp, candle.close, ExitReason.EXPIRED, order, mae_r, mfe_r
            )
        if entry_at is None:
            if _entry_touched(candle, order.entry):
                entry_at = candle.timestamp
            else:
                continue
        adverse, favorable = _excursions(candle, order)
        mae_r = min(mae_r, adverse / risk)
        mfe_r = max(mfe_r, favorable / risk)
        if _stop_touched(candle, order):
            return _close(
                entry_at, candle.timestamp, order.stop_loss, ExitReason.STOP, order, mae_r, mfe_r
            )
        if _target_touched(candle, order):
            return _close(
                entry_at,
                candle.timestamp,
                order.take_profit,
                ExitReason.TARGET,
                order,
                mae_r,
                mfe_r,
            )
    last = candles[-1] if candles else None
    if last is None:
        raise ValueError("candles cannot be empty")
    return _close(entry_at, last.timestamp, last.close, ExitReason.EXPIRED, order, mae_r, mfe_r)


def calculate_metrics(trades: list[BacktestTrade]) -> BacktestMetrics:
    values = [trade.r_multiple for trade in trades]
    wins = sum(value > 0 for value in values)
    losses = sum(value <= 0 for value in values)
    gross_profit = sum(value for value in values if value > 0)
    gross_loss = abs(sum(value for value in values if value < 0))
    equity = 0.0
    peak = 0.0
    maximum_drawdown = 0.0
    for value in values:
        equity += value
        peak = max(peak, equity)
        maximum_drawdown = max(maximum_drawdown, peak - equity)
    return BacktestMetrics(
        len(trades),
        wins,
        losses,
        wins / len(trades) * 100 if trades else 0,
        gross_profit / gross_loss if gross_loss else float("inf") if gross_profit else 0,
        sum(values) / len(values) if values else 0,
        sum(values),
        maximum_drawdown,
    )


def _close(
    entry_at: datetime | None,
    at: datetime,
    price: float,
    reason: ExitReason,
    order: BacktestOrder,
    mae_r: float,
    mfe_r: float,
) -> BacktestTrade:
    risk = abs(order.entry - order.stop_loss)
    reward = (price - order.entry) if order.direction is Direction.LONG else (order.entry - price)
    return BacktestTrade(
        entry_at, at, price, reward / risk if entry_at else 0, reason, mae_r, mfe_r
    )


def _entry_touched(candle: CandleLike, entry: float) -> bool:
    return candle.low <= entry <= candle.high


def _stop_touched(candle: CandleLike, order: BacktestOrder) -> bool:
    return (
        candle.low <= order.stop_loss
        if order.direction is Direction.LONG
        else candle.high >= order.stop_loss
    )


def _target_touched(candle: CandleLike, order: BacktestOrder) -> bool:
    return (
        candle.high >= order.take_profit
        if order.direction is Direction.LONG
        else candle.low <= order.take_profit
    )


def _excursions(candle: CandleLike, order: BacktestOrder) -> tuple[float, float]:
    if order.direction is Direction.LONG:
        return candle.low - order.entry, candle.high - order.entry
    return order.entry - candle.high, order.entry - candle.low
