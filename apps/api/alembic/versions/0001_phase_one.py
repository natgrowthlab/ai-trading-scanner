"""phase one market foundation"""

import sqlalchemy as sa
from alembic import op

revision = "0001_phase_one"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "assets",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("symbol", sa.String(32), nullable=False, unique=True),
        sa.Column("display_name", sa.String(128), nullable=False),
        sa.Column("asset_class", sa.String(16), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_assets_symbol", "assets", ["symbol"])
    op.create_table(
        "candles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("asset_id", sa.Integer(), sa.ForeignKey("assets.id"), nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("open", sa.Numeric(20, 8), nullable=False),
        sa.Column("high", sa.Numeric(20, 8), nullable=False),
        sa.Column("low", sa.Numeric(20, 8), nullable=False),
        sa.Column("close", sa.Numeric(20, 8), nullable=False),
        sa.Column("volume", sa.Numeric(24, 8), nullable=False),
        sa.Column("quote_volume", sa.Numeric(24, 8), nullable=True),
        sa.Column("trades", sa.Integer(), nullable=True),
        sa.UniqueConstraint("asset_id", "timeframe", "timestamp", name="uq_candle_identity"),
    )
    op.create_index(
        "ix_candles_asset_timeframe_timestamp", "candles", ["asset_id", "timeframe", "timestamp"]
    )
    op.create_table(
        "strategies",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(128), nullable=False, unique=True),
        sa.Column("version", sa.String(32), nullable=False),
        sa.Column("asset_id", sa.Integer(), sa.ForeignKey("assets.id"), nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False),
        sa.Column("parameters", sa.JSON(), nullable=False),
        sa.Column("score_weights", sa.JSON(), nullable=False),
        sa.Column("risk_config", sa.JSON(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade():
    op.drop_table("strategies")
    op.drop_index("ix_candles_asset_timeframe_timestamp", table_name="candles")
    op.drop_table("candles")
    op.drop_index("ix_assets_symbol", table_name="assets")
    op.drop_table("assets")
