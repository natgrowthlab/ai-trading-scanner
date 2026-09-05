from decimal import Decimal
from pathlib import Path
import sys

import pytest

sys.path.append(str(Path(__file__).parents[1] / "src"))
from paper_engine import PaperAccount, PositionStatus, Side


def test_paper_account_tracks_realized_profit_without_broker():
    account = PaperAccount(Decimal("10000"))
    opened = account.open_position("p1", "XAUUSD", Side.LONG, Decimal("2"), Decimal("2000"))
    closed = opened.close_position("p1", Decimal("2010"))
    assert closed.balance == Decimal("10020")
    assert closed.history[0].status is PositionStatus.CLOSED


def test_paper_account_rejects_duplicate_ids():
    account = PaperAccount(Decimal("100")).open_position(
        "p1", "BTCUSDT", Side.LONG, Decimal("1"), Decimal("10")
    )
    with pytest.raises(ValueError):
        account.open_position("p1", "BTCUSDT", Side.LONG, Decimal("1"), Decimal("10"))
