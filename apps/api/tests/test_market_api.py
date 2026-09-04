def test_assets_are_seeded(client):
    response = client.get("/api/v1/assets")
    assert response.status_code == 200
    assert [asset["symbol"] for asset in response.json()] == ["BTCUSDT", "NAS100", "XAUUSD"]


def test_unknown_candle_asset_returns_not_found(client):
    response = client.get("/api/v1/candles", params={"symbol": "UNKNOWN", "timeframe": "5m"})
    assert response.status_code == 404
