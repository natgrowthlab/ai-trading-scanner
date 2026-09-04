"""add persistent signal history"""

import sqlalchemy as sa
from alembic import op

revision = "0002_signal_history"
down_revision = "0001_phase_one"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "signals",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("strategy_id", sa.Integer(), sa.ForeignKey("strategies.id"), nullable=False),
        sa.Column("asset_id", sa.Integer(), sa.ForeignKey("assets.id"), nullable=False),
        sa.Column("timeframe", sa.String(8), nullable=False),
        sa.Column("direction", sa.String(8), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("classification", sa.String(16), nullable=False),
        sa.Column("entry", sa.Numeric(20, 8), nullable=False),
        sa.Column("stop_loss", sa.Numeric(20, 8), nullable=False),
        sa.Column("tp1", sa.Numeric(20, 8), nullable=False),
        sa.Column("tp2", sa.Numeric(20, 8), nullable=False),
        sa.Column("tp3", sa.Numeric(20, 8), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("metadata", sa.JSON(), nullable=False),
    )
    op.create_index("ix_signals_strategy_id", "signals", ["strategy_id"])
    op.create_index("ix_signals_asset_id", "signals", ["asset_id"])
    op.create_table(
        "signal_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("signal_id", sa.Integer(), sa.ForeignKey("signals.id"), nullable=False),
        sa.Column("event_type", sa.String(32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("metadata", sa.JSON(), nullable=False),
    )
    op.create_index("ix_signal_events_signal_id", "signal_events", ["signal_id"])


def downgrade():
    op.drop_index("ix_signal_events_signal_id", table_name="signal_events")
    op.drop_table("signal_events")
    op.drop_index("ix_signals_asset_id", table_name="signals")
    op.drop_index("ix_signals_strategy_id", table_name="signals")
    op.drop_table("signals")
