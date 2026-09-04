from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.market import Asset, Candle
from app.schemas.market import AssetRead, CandleRead

router = APIRouter(tags=["market"])


@router.get("/assets", response_model=list[AssetRead])
def list_assets(db: Session = Depends(get_db)) -> list[Asset]:
    return list(db.scalars(select(Asset).where(Asset.active.is_(True)).order_by(Asset.symbol)))


@router.get("/candles", response_model=list[CandleRead])
def list_candles(
    symbol: str,
    timeframe: str,
    limit: int = Query(200, ge=1, le=1000),
    db: Session = Depends(get_db),
) -> list[CandleRead]:
    asset = db.scalar(select(Asset).where(Asset.symbol == symbol.upper()))
    if asset is None:
        raise HTTPException(status_code=404, detail="Asset not found")
    rows = db.scalars(
        select(Candle)
        .where(Candle.asset_id == asset.id, Candle.timeframe == timeframe)
        .order_by(Candle.timestamp.desc())
        .limit(limit)
    )
    candles = list(rows)
    return [
        CandleRead(
            symbol=asset.symbol,
            timeframe=c.timeframe,
            timestamp=c.timestamp,
            open=c.open,
            high=c.high,
            low=c.low,
            close=c.close,
            volume=c.volume,
        )
        for c in reversed(candles)
    ]
