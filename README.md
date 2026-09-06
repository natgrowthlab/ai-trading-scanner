# AI Trading Scanner

Private, analytical market-scanning platform. The first verified milestone includes service infrastructure, canonical candle data, pluggable market-data contracts, assets/candles API, and deterministic market-structure analysis.

It is an educational and analytical tool. It does not provide investment advice, execute orders, or make performance guarantees.

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

## Included endpoints

- `GET /api/v1/assets`
- `GET /api/v1/candles?symbol=XAUUSD&timeframe=5m`
- `GET /health`
- `GET /ready`

## Market intelligence

The scanner adds deterministic futures analysis for NQ, ES, YM, RTY and GC:

- `GET /api/v1/scanner?timeframe=5m`
- `GET /api/v1/markets/NQ?timeframe=5m`
- `GET /api/v1/markets/NQ/liquidity?timeframe=5m`
- `POST /api/v1/prop-accounts/evaluate`

The configured provider is currently deterministic mock data, always returned as `dataStatus: MOCK`. Configure and deploy a real provider adapter before using the scanner as a live data surface. No order execution is implemented.
