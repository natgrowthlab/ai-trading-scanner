# Binance USDT-M Futures dry-run bot

This module analyzes public Binance USDT-M perpetual candles for `BTCUSDT` (or another
supported perpetual contract) with the same closed-candle trend-pullback logic used by the project. It is
intentionally **dry-run only**: it has no API-key support and cannot send an order.
Every candidate is first evaluated locally so the setup can be tested without placing
capital at risk.

## Run one analysis cycle

```bash
cd /Users/n/Documents/NATION/Scanner
BINANCE_SYMBOL=BTCUSDT BINANCE_INTERVAL=1m \
PYTHONPATH=packages/binance python -m src.run_dry_run
```

The JSON result is either `OPEN` (a simulated setup), `NO_SETUP`, or `HOLD`. A
`NO_SETUP` result is expected most of the time; it means the last closed candle did
not meet the strategy rules, not that connectivity failed.

## Safety boundary

- Only closed candles are evaluated; the live, still-forming candle is excluded.
- Fast-profit, protective stop, and break-even state are simulated and auditable.
- The module does not promise returns and is not investment advice.
- Do not use a Binance API key with withdrawal permissions. Add a separate Testnet
  Testnet order adapter only after backtesting and paper results are acceptable.

## Test

```bash
PYTHONPATH=packages/binance pytest -q packages/binance/tests
```
