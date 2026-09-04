.DEFAULT_GOAL := help

help:
	@echo "Targets: dev test lint migrate seed backtest worker"

dev:
	docker compose up --build

test:
	cd apps/api && python3 -m pytest tests ../../packages/structure/tests ../../packages/fvg/tests ../../packages/liquidity/tests ../../packages/volume/tests ../../packages/momentum/tests ../../packages/orderblocks/tests

lint:
	cd apps/api && python3 -m ruff check app tests ../../packages/structure/src ../../packages/fvg/src ../../packages/liquidity/src ../../packages/volume/src ../../packages/momentum/src ../../packages/orderblocks/src

migrate:
	docker compose run --rm api alembic upgrade head

seed:
	docker compose run --rm api python -m app.db.seed

backtest:
	@echo "Backtesting is scheduled after Phase 3 signal-engine completion."

worker:
	docker compose up worker
