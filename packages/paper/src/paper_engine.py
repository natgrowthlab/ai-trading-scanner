from __future__ import annotations

from dataclasses import dataclass, replace
from decimal import Decimal
from enum import StrEnum


class Side(StrEnum):
    LONG = "LONG"
    SHORT = "SHORT"


class PositionStatus(StrEnum):
    OPEN = "OPEN"
    CLOSED = "CLOSED"


@dataclass(frozen=True)
class PaperPosition:
    id: str
    symbol: str
    side: Side
    quantity: Decimal
    entry_price: Decimal
    status: PositionStatus = PositionStatus.OPEN
    exit_price: Decimal | None = None
    realized_pnl: Decimal = Decimal("0")

    def unrealized_pnl(self, mark_price: Decimal) -> Decimal:
        return (
            (mark_price - self.entry_price) * self.quantity
            if self.side is Side.LONG
            else (self.entry_price - mark_price) * self.quantity
        )


@dataclass(frozen=True)
class PaperAccount:
    balance: Decimal
    positions: tuple[PaperPosition, ...] = ()
    history: tuple[PaperPosition, ...] = ()

    def open_position(
        self, position_id: str, symbol: str, side: Side, quantity: Decimal, price: Decimal
    ) -> "PaperAccount":
        if quantity <= 0 or price <= 0:
            raise ValueError("quantity and price must be positive")
        if any(item.id == position_id for item in (*self.positions, *self.history)):
            raise ValueError("position id must be unique")
        position = PaperPosition(position_id, symbol, side, quantity, price)
        return replace(self, positions=(*self.positions, position))

    def close_position(self, position_id: str, price: Decimal) -> "PaperAccount":
        if price <= 0:
            raise ValueError("price must be positive")
        position = next((item for item in self.positions if item.id == position_id), None)
        if position is None:
            raise ValueError("open position not found")
        pnl = position.unrealized_pnl(price)
        closed = replace(position, status=PositionStatus.CLOSED, exit_price=price, realized_pnl=pnl)
        remaining = tuple(item for item in self.positions if item.id != position_id)
        return replace(
            self, balance=self.balance + pnl, positions=remaining, history=(*self.history, closed)
        )
