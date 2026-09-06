# Market Intelligence implementation report

## Implemented

- Provider-neutral intelligence orchestration consuming normalized candles.
- Supported futures universe: NQ, ES, YM, RTY and GC; timeframes 1m through 1W.
- Session levels: Asia, London, overnight, previous day and previous week.
- Liquidity map with session, swing and equal-high levels; deterministic sweep detection.
- Confirmed-pivot market structure, BOS detection, FVG detection, displacement score and transparent daily bias/confidence components.
- Confluence-only setup gate: a setup requires matching sweep, structure event, FVG and confidence threshold.
- Risk model for $10,000 / 1% default and futures tick metadata.
- Prop-firm safety evaluation with automatic risk reduction states.
- New API routes and a scanner-table frontend.

## Files added or modified

- `apps/api/app/services/intelligence.py`
- `apps/api/app/api/v1/intelligence.py`
- `apps/api/app/api/v1/router.py`
- `apps/api/app/db/seed.py`
- `apps/api/tests/test_intelligence.py`
- `apps/web/app/scanner/page.tsx`
- `.env.example`, `README.md`, `IMPLEMENTATION_AUDIT.md`

## Environment and deployment

`MARKET_DATA_PROVIDER=mock` is documented for development. A real provider adapter must be added with its server-side environment key and deployed with the Docker/FastAPI API service. The current Hostinger frontend-only Web App does not host this FastAPI intelligence API.

## Known limitations

- Macro/calendar data and SMT require configured external/correlation data and deliberately return unavailable rather than guessed values.
- Intelligence results are computed from the configured provider and are not persisted as journal/backtest records in this increment.
- Automated order execution is explicitly out of scope.
