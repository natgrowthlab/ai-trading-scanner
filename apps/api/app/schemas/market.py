from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class AssetRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    symbol: str
    display_name: str
    asset_class: str
    active: bool


class CandleRead(BaseModel):
    symbol: str
    timeframe: str
    timestamp: datetime
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal
    volume: Decimal
