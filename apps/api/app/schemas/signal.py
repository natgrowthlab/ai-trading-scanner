from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class SignalRead(BaseModel):
    id: int
    symbol: str
    timeframe: str
    direction: str
    score: int
    classification: str
    entry: Decimal
    stop_loss: Decimal
    tp1: Decimal
    tp2: Decimal
    tp3: Decimal
    status: str
    created_at: datetime
    expires_at: datetime
