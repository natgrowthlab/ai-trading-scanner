# Market Intelligence implementation audit

## Existing architecture reused

- **API:** FastAPI + Pydantic + SQLAlchemy under `apps/api`.
- **Web:** Next.js App Router under `apps/web`.
- **Persistence:** SQLAlchemy candles/assets/signals with PostgreSQL/TimescaleDB in Docker and SQLite for tests.
- **Market data:** normalized `MarketDataProvider` and deterministic `MockMarketDataProvider` in `app.services.market_data`.
- **Existing engines:** structure, liquidity, FVG, scoring, signals, risk, backtesting, order blocks, MTF, paper and alerts are isolated Python packages.
- **Deployment:** Docker Compose is the complete API deployment; the current Hostinger Web App deployment is frontend-only and cannot run the FastAPI scanning service by itself.

## Implementation approach

The new intelligence orchestrator will remain deterministic and provider-neutral. It will consume normalized candles, expose explicit data status, and compose session, liquidity, structure, sweep, displacement, FVG, bias, confidence, setup, risk and prop-firm calculations. It does not submit orders or fabricate macro data.

## Constraints retained

- No API credentials are committed.
- Mock data is labelled `MOCK`, not live.
- Pivot events are confirmed only after their right-side window.
- Trade setups require multiple confirmations; an indicator alone cannot create one.
- Authentication does not yet exist in the current project, so writable user configuration remains API-scoped and is not represented as multi-user persisted state in this increment.
