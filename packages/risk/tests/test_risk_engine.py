from decimal import Decimal
import sys
from pathlib import Path

import pytest

sys.path.append(str(Path(__file__).parents[1] / "src"))
from risk_engine import AssetRiskMetadata, calculate_position_size


def test_calculates_position_size_from_structural_stop():
    position = calculate_position_size(
        Decimal("10000"),
        Decimal("1"),
        Decimal("100"),
        Decimal("98"),
        AssetRiskMetadata(Decimal("1"), Decimal("0.01"), Decimal("0.01")),
    )
    assert position.maximum_loss == Decimal("100")
    assert position.units == Decimal("50")


def test_blocks_high_risk_by_default():
    with pytest.raises(ValueError):
        calculate_position_size(
            Decimal("10000"),
            Decimal("3"),
            Decimal("100"),
            Decimal("98"),
            AssetRiskMetadata(Decimal("1"), Decimal("0.01"), Decimal("0.01")),
        )
