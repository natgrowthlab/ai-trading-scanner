def test_assets_are_seeded(client):
    response = client.get("/api/v1/assets")
    assert response.status_code == 200
    assert [asset["symbol"] for asset in response.json()] == [
        "BTCUSDT", "ES", "GC", "NAS100", "NQ", "RTY", "XAUUSD", "YM"
    ]


def test_unknown_candle_asset_returns_not_found(client):
    response = client.get("/api/v1/candles", params={"symbol": "UNKNOWN", "timeframe": "5m"})
    assert response.status_code == 404


def test_signals_start_empty_without_synthetic_data(client):
    response = client.get("/api/v1/signals")
    assert response.status_code == 200
    assert response.json() == []


def test_tradingview_webhook_rejects_invalid_secret(client):
    response = client.post(
        "/api/v1/webhooks/tradingview",
        json={
            "secret": "wrong",
            "symbol": "XAUUSD",
            "timeframe": "5m",
            "event": "SIGNAL",
            "direction": "LONG",
            "price": "2000",
        },
    )
    assert response.status_code == 401


def test_tradingview_webhook_normalizes_native_interval(client):
    from app.api.v1.webhooks import TradingViewWebhook

    payload = TradingViewWebhook(
        secret="test",
        symbol="XAUUSD",
        timeframe="60",
        event="SIGNAL",
        direction="LONG",
        price="2000",
    )
    assert payload.timeframe == "1h"
