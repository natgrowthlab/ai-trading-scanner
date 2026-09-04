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
