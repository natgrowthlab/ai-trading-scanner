# Plan de implementación incremental

## Phase 1 — completada en este cambio

- Base monorepo, Docker Compose, FastAPI, Next.js y Celery.
- Esquema Asset, Candle y Strategy, migración inicial y datos semilla.
- Contrato extensible de datos de mercado y provider mock determinista.
- API de activos y velas, health/readiness.
- Motor de swings, HH/HL/LH/LL, BOS/CHoCH y pruebas unitarias.

## Gate antes de Phase 2

Validar con datos históricos y pruebas adicionales los swings y eventos de estructura para los tres activos. La Phase 2 no se inicia hasta que esa validación sea aceptada.

## Siguientes fases

2. Liquidez, FVG, order blocks, volumen y momentum.
3. MTF, scoring, señales y riesgo.
4. Backtesting determinista y analítica.
5. Dashboard funcional y gráficos.
