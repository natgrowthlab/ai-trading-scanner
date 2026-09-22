from datetime import UTC, datetime, timedelta
from decimal import Decimal
import sys
from pathlib import Path

import pytest

sys.path.append(str(Path(__file__).parents[1] / "src"))
from signal_engine import SignalDirection, SignalState, TradePlan, build_signal


def test_signal_enforces_lifecycle_and_expiry():
    created = datetime(2025, 1, 1, tzinfo=UTC)
    signal = build_signal(
        "BTCUSDT",
        "5m",
        SignalDirection.LONG,
        75,
        TradePlan(Decimal("100"), Decimal("98"), Decimal("102"), Decimal("104"), Decimal("106")),
        created,
        created + timedelta(minutes=60),
    )
    active = (
        signal.transition(SignalState.VALIDATED, created)
        .transition(SignalState.PENDING, created)
        .transition(SignalState.ACTIVE, created)
    )
    assert active.plan.risk_reward(SignalDirection.LONG, active.plan.take_profit_3) == Decimal("3")


def test_signal_rejects_invalid_price_plan():
    created = datetime(2025, 1, 1, tzinfo=UTC)
    with pytest.raises(ValueError):
        build_signal(
            "BTCUSDT",
            "5m",
            SignalDirection.LONG,
            75,
            TradePlan(
                Decimal("100"), Decimal("101"), Decimal("102"), Decimal("104"), Decimal("106")
            ),
            created,
            created + timedelta(minutes=60),
        )
