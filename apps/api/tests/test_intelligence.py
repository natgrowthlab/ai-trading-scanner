from datetime import UTC, datetime, timedelta
from decimal import Decimal

from app.services.intelligence import analyze_market, evaluate_prop_firm, session_levels
from app.services.market_data import CandleData


def candles(count: int = 320) -> list[CandleData]:
    start = datetime(2025, 1, 1, tzinfo=UTC)
    return [
        CandleData(symbol="BTCUSDT", timeframe="5m", timestamp=start + timedelta(minutes=5 * i), open=Decimal(60000 + i), high=Decimal(60002 + i), low=Decimal(59999 + i), close=Decimal(60001 + i), volume=Decimal(1000))
        for i in range(count)
    ]


def test_session_levels_include_previous_day_when_available():
    levels = session_levels(candles())
    assert {"PDH", "PDL", "PDC"}.issubset({level.type for level in levels})


def test_market_analysis_is_explicitly_mock_and_confluence_based():
    analysis = analyze_market("BTCUSDT", "5m", candles())
    assert analysis["dataStatus"] == "MOCK"
    assert "liquidity" in analysis and "confidence" in analysis
    assert analysis["setup"] is None or analysis["setup"]["confidence"] >= 65


def test_prop_risk_reduces_risk_in_danger_zone():
    result = evaluate_prop_firm(10_000, 9_100, 500, 1_000, 450, 900)
    assert result["status"] == "DANGER"
    assert result["riskMultiplier"] == .25


def test_scanner_api_returns_only_explicitly_mock_market_data(client):
    response = client.get("/api/v1/scanner?timeframe=5m")
    assert response.status_code == 200
    assert [row["symbol"] for row in response.json()] == ["BTCUSDT", "ETHUSDT", "SOLUSDT", "BNBUSDT", "XRPUSDT"]
    assert all(row["dataStatus"] == "MOCK" for row in response.json())
