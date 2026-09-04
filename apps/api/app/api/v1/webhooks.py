import hmac
from decimal import Decimal
from enum import StrEnum

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.services.webhook_deduplication import webhook_deduplicator

router = APIRouter(tags=["webhooks"])


class TradingViewEvent(StrEnum):
    SIGNAL = "SIGNAL"


class TradingViewWebhook(BaseModel):
    secret: str = Field(min_length=1)
    symbol: str = Field(min_length=3, max_length=32)
    timeframe: str = Field(pattern=r"^(1m|3m|5m|15m|30m|1h|4h|1D)$")
    event: TradingViewEvent
    direction: str = Field(pattern=r"^(LONG|SHORT)$")
    price: Decimal = Field(gt=0)


@router.post("/webhooks/tradingview", status_code=202)
def ingest_tradingview(
    payload: TradingViewWebhook, x_webhook_signature: str | None = Header(default=None)
) -> dict[str, str]:
    expected = get_settings().tradingview_webhook_secret
    supplied = x_webhook_signature or payload.secret
    if not expected or not hmac.compare_digest(supplied, expected):
        raise HTTPException(status_code=401, detail="Invalid webhook signature")
    if not webhook_deduplicator.accept(payload.symbol, payload.timeframe, payload.direction):
        return {"status": "duplicate"}
    return {"status": "accepted"}
