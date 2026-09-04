from datetime import UTC, datetime, timedelta
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.append(str(Path(__file__).parents[1] / "src"))
from order_block_engine import OrderBlockDirection, detect_order_blocks


@dataclass
class Candle:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float


@dataclass
class Break:
    kind: str
    direction: str
    timestamp: datetime


def test_finds_last_bearish_candle_before_bullish_bos_displacement():
    start = datetime(2025, 1, 1, tzinfo=UTC)
    candles = [
        Candle(start, 10, 11, 9, 10.5, 10),
        Candle(start + timedelta(minutes=1), 10.5, 10.6, 9.5, 9.8, 10),
        Candle(start + timedelta(minutes=2), 10, 14, 10, 13.5, 40),
    ]
    blocks = detect_order_blocks(candles, [Break("BOS", "BULLISH", candles[-1].timestamp)], [])
    assert len(blocks) == 1
    assert blocks[0].direction is OrderBlockDirection.BULLISH
    assert blocks[0].bottom == 9.5
