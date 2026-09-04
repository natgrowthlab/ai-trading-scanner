from datetime import UTC, datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import JSON, DateTime, Enum, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class SignalDirection(StrEnum):
    LONG = "LONG"
    SHORT = "SHORT"


class SignalStatus(StrEnum):
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


class SignalRecord(Base):
    __tablename__ = "signals"
    id: Mapped[int] = mapped_column(primary_key=True)
    strategy_id: Mapped[int] = mapped_column(ForeignKey("strategies.id"), index=True)
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"), index=True)
    timeframe: Mapped[str] = mapped_column(String(8))
    direction: Mapped[SignalDirection] = mapped_column(Enum(SignalDirection))
    score: Mapped[int]
    classification: Mapped[str] = mapped_column(String(16))
    entry: Mapped[Decimal] = mapped_column(Numeric(20, 8))
    stop_loss: Mapped[Decimal] = mapped_column(Numeric(20, 8))
    tp1: Mapped[Decimal] = mapped_column(Numeric(20, 8))
    tp2: Mapped[Decimal] = mapped_column(Numeric(20, 8))
    tp3: Mapped[Decimal] = mapped_column(Numeric(20, 8))
    status: Mapped[SignalStatus] = mapped_column(Enum(SignalStatus), default=SignalStatus.DETECTED)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    metadata_json: Mapped[dict] = mapped_column("metadata", JSON, default=dict)


class SignalEvent(Base):
    __tablename__ = "signal_events"
    id: Mapped[int] = mapped_column(primary_key=True)
    signal_id: Mapped[int] = mapped_column(ForeignKey("signals.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    metadata_json: Mapped[dict] = mapped_column("metadata", JSON, default=dict)
