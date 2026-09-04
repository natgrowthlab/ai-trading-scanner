from datetime import UTC, datetime, timedelta
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).parents[1] / "src"))
from economic_calendar import EconomicEvent, Impact, blocks_signal


def test_high_impact_event_blocks_15_minute_window():
    event = EconomicEvent("CPI", datetime(2025, 1, 1, 13, 30, tzinfo=UTC), Impact.HIGH)
    assert blocks_signal(event.timestamp - timedelta(minutes=15), [event])
    assert not blocks_signal(event.timestamp - timedelta(minutes=16), [event])
