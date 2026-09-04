from dataclasses import dataclass
from decimal import ROUND_DOWN, Decimal


@dataclass(frozen=True)
class AssetRiskMetadata:
    contract_size: Decimal
    minimum_size: Decimal
    size_increment: Decimal
    margin_rate: Decimal = Decimal("0")


@dataclass(frozen=True)
class PositionSize:
    maximum_loss: Decimal
    units: Decimal
    contracts: Decimal
    margin_estimate: Decimal
    risk_percent: Decimal


@dataclass(frozen=True)
class DailyRiskConfig:
    max_daily_loss_pct: Decimal = Decimal("2")
    max_open_risk_pct: Decimal = Decimal("1.5")
    max_trades_per_day: int = 5
    max_consecutive_losses: int = 3


def calculate_position_size(
    balance: Decimal,
    risk_percent: Decimal,
    entry: Decimal,
    stop_loss: Decimal,
    metadata: AssetRiskMetadata,
    allow_high_risk: bool = False,
) -> PositionSize:
    if balance <= 0 or entry <= 0 or metadata.contract_size <= 0:
        raise ValueError("balance, entry, and contract size must be positive")
    if risk_percent <= 0 or (risk_percent > 2 and not allow_high_risk):
        raise ValueError("risk percentage must be greater than zero and no more than 2 by default")
    distance = abs(entry - stop_loss)
    if distance == 0:
        raise ValueError("entry and stop loss must differ")
    maximum_loss = balance * risk_percent / Decimal("100")
    raw_units = maximum_loss / distance
    raw_contracts = raw_units / metadata.contract_size
    contracts = (raw_contracts / metadata.size_increment).to_integral_value(
        rounding=ROUND_DOWN
    ) * metadata.size_increment
    if contracts < metadata.minimum_size:
        contracts = Decimal("0")
    units = contracts * metadata.contract_size
    return PositionSize(
        maximum_loss, units, contracts, units * entry * metadata.margin_rate, risk_percent
    )


def daily_risk_allows_trade(
    balance: Decimal,
    realized_loss: Decimal,
    open_risk: Decimal,
    trade_count: int,
    consecutive_losses: int,
    config: DailyRiskConfig = DailyRiskConfig(),
) -> bool:
    return (
        realized_loss < balance * config.max_daily_loss_pct / Decimal("100")
        and open_risk < balance * config.max_open_risk_pct / Decimal("100")
        and trade_count < config.max_trades_per_day
        and consecutive_losses < config.max_consecutive_losses
    )
