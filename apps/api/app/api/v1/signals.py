from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.market import Asset
from app.models.signal import SignalRecord
from app.schemas.signal import SignalRead

router = APIRouter(tags=["signals"])


def _read(row: SignalRecord, asset: Asset) -> SignalRead:
    return SignalRead(
        id=row.id,
        symbol=asset.symbol,
        timeframe=row.timeframe,
        direction=row.direction,
        score=row.score,
        classification=row.classification,
        entry=row.entry,
        stop_loss=row.stop_loss,
        tp1=row.tp1,
        tp2=row.tp2,
        tp3=row.tp3,
        status=row.status,
        created_at=row.created_at,
        expires_at=row.expires_at,
    )


@router.get("/signals", response_model=list[SignalRead])
def list_signals(
    symbol: str | None = None,
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
) -> list[SignalRead]:
    statement = select(SignalRecord, Asset).join(Asset, SignalRecord.asset_id == Asset.id)
    if symbol:
        statement = statement.where(Asset.symbol == symbol.upper())
    rows = db.execute(statement.order_by(SignalRecord.created_at.desc()).limit(limit))
    return [_read(signal, asset) for signal, asset in rows]


@router.get("/signals/{signal_id}", response_model=SignalRead)
def get_signal(signal_id: int, db: Session = Depends(get_db)) -> SignalRead:
    row = db.execute(
        select(SignalRecord, Asset)
        .join(Asset, SignalRecord.asset_id == Asset.id)
        .where(SignalRecord.id == signal_id)
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Signal not found")
    return _read(*row)
