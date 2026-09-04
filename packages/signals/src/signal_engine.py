from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import datetime
from decimal import Decimal
from enum import StrEnum


class SignalDirection(StrEnum):
    LONG = "LONG"
    SHORT = "SHORT"
    NO_TRADE = "NO_TRADE"


class SignalState(StrEnum):
    DETECTED = "DETECTED"
    VALIDATED = "VALIDATED"
    PENDING = "PENDING"
    ACTIVE = "ACTIVE"
    TP1_HIT = "TP1_HIT"
    TP2_HIT = "TP2_HIT"
    TP3_HIT = "TP3_HIT"
    STOPPED = "STOPPED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"
    INVALIDATED = "INVALIDATED"


TERMINAL_STATES = {
    SignalState.TP3_HIT,
    SignalState.STOPPED,
    SignalState.EXPIRED,
    SignalState.CANCELLED,
    SignalState.INVALIDATED,
}

ALLOWED_TRANSITIONS = {
    SignalState.DETECTED: {SignalState.VALIDATED, SignalState.CANCELLED, SignalState.INVALIDATED},
    SignalState.VALIDATED: {SignalState.PENDING, SignalState.CANCELLED, SignalState.INVALIDATED},
    SignalState.PENDING: {
        SignalState.ACTIVE,
        SignalState.EXPIRED,
        SignalState.CANCELLED,
        SignalState.INVALIDATED,
    },
    SignalState.ACTIVE: {SignalState.TP1_HIT, SignalState.STOPPED, SignalState.INVALIDATED},
    SignalState.TP1_HIT: {SignalState.TP2_HIT, SignalState.STOPPED, SignalState.INVALIDATED},
    SignalState.TP2_HIT: {SignalState.TP3_HIT, SignalState.STOPPED, SignalState.INVALIDATED},
}


@dataclass(frozen=True)
class TradePlan:
    entry: Decimal
    stop_loss: Decimal
    take_profit_1: Decimal
    take_profit_2: Decimal
    take_profit_3: Decimal

    def risk_reward(self, direction: SignalDirection, target: Decimal) -> Decimal:
        if direction not in (SignalDirection.LONG, SignalDirection.SHORT):
            raise ValueError("risk reward requires a directional signal")
        risk = abs(self.entry - self.stop_loss)
        if risk == 0:
            raise ValueError("entry and stop loss must differ")
        reward = (
            (target - self.entry) if direction is SignalDirection.LONG else (self.entry - target)
        )
        return reward / risk


@dataclass(frozen=True)
class Signal:
    symbol: str
    timeframe: str
    direction: SignalDirection
    score: int
    plan: TradePlan
    created_at: datetime
    expires_at: datetime
    state: SignalState = SignalState.DETECTED

    def transition(self, target: SignalState, at: datetime) -> "Signal":
        if target not in ALLOWED_TRANSITIONS.get(self.state, set()):
            raise ValueError(f"invalid transition from {self.state} to {target}")
        if target is SignalState.ACTIVE and at > self.expires_at:
            raise ValueError("expired signal cannot be activated")
        return replace(self, state=target)

    def is_expired(self, at: datetime) -> bool:
        return self.state not in TERMINAL_STATES and at >= self.expires_at


def build_signal(
    symbol: str,
    timeframe: str,
    direction: SignalDirection,
    score: int,
    plan: TradePlan,
    created_at: datetime,
    expires_at: datetime,
    min_score: int = 65,
) -> Signal:
    if direction is SignalDirection.NO_TRADE:
        raise ValueError("NO_TRADE does not create a persisted signal")
    if score < min_score:
        raise ValueError("signal score is below strategy minimum")
    if expires_at <= created_at:
        raise ValueError("signal expiry must be after creation")
    _validate_plan(direction, plan)
    return Signal(symbol, timeframe, direction, score, plan, created_at, expires_at)


def _validate_plan(direction: SignalDirection, plan: TradePlan) -> None:
    if direction is SignalDirection.LONG:
        valid = (
            plan.stop_loss
            < plan.entry
            < plan.take_profit_1
            <= plan.take_profit_2
            <= plan.take_profit_3
        )
    else:
        valid = (
            plan.stop_loss
            > plan.entry
            > plan.take_profit_1
            >= plan.take_profit_2
            >= plan.take_profit_3
        )
    if not valid:
        raise ValueError("trade plan prices are inconsistent with direction")
