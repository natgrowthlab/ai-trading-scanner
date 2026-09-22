"""State machine for safe Binance USDT-M Futures dry-run execution."""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

from .strategy import Candle, Direction, PullbackStrategy, StrategyDecision


class BotState(StrEnum):
    READY = "READY"
    IN_POSITION = "IN_POSITION"


@dataclass(frozen=True)
class BotConfig:
    quantity: float = 0.001
    quick_profit_quote: float = 1.0
    break_even_profit_quote: float = 0.50
    break_even_lock_quote: float = 0.10


@dataclass(frozen=True)
class BotEvent:
    kind: str
    message: str
    price: float
    realized_pnl_quote: float = 0.0


@dataclass
class _Position:
    direction: Direction
    entry_price: float
    stop_loss: float
    quantity: float
    break_even_active: bool = False

    def pnl(self, price: float) -> float:
        movement = price - self.entry_price
        return movement * self.quantity if self.direction is Direction.LONG else -movement * self.quantity


class BinanceFuturesScalpingBot:
    """One-position dry-run manager.

    The bot never sends orders.  It turns strategy decisions and subsequent prices
    into auditable events, including stop, break-even and fast-profit exits.
    """

    def __init__(self, strategy: PullbackStrategy | None = None, config: BotConfig | None = None) -> None:
        self.strategy = strategy or PullbackStrategy()
        self.config = config or BotConfig()
        self.position: _Position | None = None
        self.realized_pnl_quote = 0.0

    @property
    def state(self) -> BotState:
        return BotState.IN_POSITION if self.position else BotState.READY

    def on_price(self, price: float) -> BotEvent | None:
        position = self.position
        if position is None:
            return None
        pnl = position.pnl(price)
        if pnl >= self.config.quick_profit_quote:
            return self._close(price, "FAST_PROFIT", "quick-profit exit")
        if pnl >= self.config.break_even_profit_quote and not position.break_even_active:
            lock = self.config.break_even_lock_quote / position.quantity
            position.stop_loss = position.entry_price + lock if position.direction is Direction.LONG else position.entry_price - lock
            position.break_even_active = True
            return BotEvent("BREAK_EVEN", "stop moved to protected break-even", price)
        hit_stop = price <= position.stop_loss if position.direction is Direction.LONG else price >= position.stop_loss
        if hit_stop:
            return self._close(price, "STOP", "protective stop exit")
        return None

    def on_closed_candles(self, entry_candles: list[Candle], trend_candles: list[Candle]) -> BotEvent:
        if self.position:
            return BotEvent("HOLD", "position already open", entry_candles[-1].close)
        decision = self.strategy.evaluate(entry_candles, trend_candles)
        if not decision.is_entry:
            return BotEvent("NO_SETUP", decision.reason, entry_candles[-1].close)
        assert decision.entry_price is not None and decision.stop_loss is not None
        self.position = _Position(decision.direction, decision.entry_price, decision.stop_loss, self.config.quantity)
        return BotEvent("OPEN", f"{decision.direction}: {decision.reason}", decision.entry_price)

    def _close(self, price: float, kind: str, message: str) -> BotEvent:
        assert self.position is not None
        pnl = self.position.pnl(price)
        self.realized_pnl_quote += pnl
        self.position = None
        return BotEvent(kind, message, price, pnl)
