# AI Trading Scanner

Private Binance USDT-M Futures research and dry-run bot platform. It includes live public futures market data, candle analysis, and testable risk logic.

It is an educational and analytical tool. It does not provide investment advice, execute live orders, or make performance guarantees.

## Quick start

```bash
cp .env.example .env
docker compose up --build
```

Open `http://localhost:3000`, `http://localhost:8000/docs`, and `http://localhost:8000/health`.

For a Hostinger VPS or Docker Manager deployment, follow [the deployment guide](docs/HOSTINGER_DEPLOYMENT.md).

For local API tests:

```bash
cd apps/api
python -m pip install -e '.[dev]'
pytest
```

## Binance Futures candle analysis (dry-run)

The repository also includes a separate public Binance USDT-M Futures candle analyzer. It is
dry-run only and does not accept exchange credentials or place orders. See
[the Binance dry-run guide](docs/BINANCE_DRY_RUN.md) to analyze `BTCUSDT` on 1m/5m
with the tested trend-pullback logic.

## Included endpoints

- `GET /api/v1/assets`
- `GET /api/v1/candles?symbol=BTCUSDT&timeframe=5m`
- `GET /health`
- `GET /ready`

## Binance Futures bot

The platform focuses on Binance USDT-M perpetual contracts: BTCUSDT, ETHUSDT,
SOLUSDT, BNBUSDT and XRPUSDT. The web dashboard reads live ticker, order-book and
closed-candle data through a server-side route, while the Python bot remains
dry-run/Testnet-first.

- `GET /api/v1/scanner?timeframe=5m`
- `GET /api/v1/markets/BTCUSDT?timeframe=5m`
- `GET /api/v1/markets/BTCUSDT/liquidity?timeframe=5m`
- `POST /api/v1/prop-accounts/evaluate`

No live order execution is implemented. Validate strategy behavior in dry-run and
Testnet before considering any exchange execution.
