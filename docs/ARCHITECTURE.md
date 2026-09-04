# Arquitectura

## Estado del milestone 1

El monorepo separa la interfaz (apps/web), API y worker (apps/api, apps/worker), y motores de dominio bajo packages. Docker Compose ejecuta TimescaleDB/PostgreSQL, Redis, API, worker y web. La API usa FastAPI, Pydantic y SQLAlchemy 2; las migraciones iniciales quedan bajo Alembic.

## Flujo de datos

Un MarketDataProvider entrega velas normalizadas e inmutables. La persistencia asocia cada vela a un activo y usa una identidad única (asset_id, timeframe, timestamp). Los cálculos de estructura aceptan una lista ordenada de velas, sin acceso a base de datos ni proveedor externo. Esta separación permitirá reutilizar la misma lógica en ingesta en vivo y backtests.

## Decisiones

- Las horas son timezone-aware y se normalizan en UTC.
- El mock es determinista y solo sirve desarrollo/pruebas; no presenta datos ni rendimiento reales.
- Un BOS exige cierre, nunca solo mecha.
- Un swing se confirma tras right_bars, evitando anticipar información futura.
- La ejecución automática no forma parte de esta fase.
