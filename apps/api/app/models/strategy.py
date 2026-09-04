from datetime import UTC, datetime

from sqlalchemy import JSON, Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Strategy(Base):
    __tablename__ = "strategies"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), unique=True)
    version: Mapped[str] = mapped_column(String(32))
    asset_id: Mapped[int] = mapped_column(ForeignKey("assets.id"))
    timeframe: Mapped[str] = mapped_column(String(8))
    parameters: Mapped[dict] = mapped_column(JSON, default=dict)
    score_weights: Mapped[dict] = mapped_column(JSON, default=dict)
    risk_config: Mapped[dict] = mapped_column(JSON, default=dict)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
