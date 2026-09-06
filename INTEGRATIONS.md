# External integrations

## Polymarket BTC 5-minute reference

This repository tracks [Novals83/5min-btc-polymarket](https://github.com/Novals83/5min-btc-polymarket) as a Git submodule at `integrations/5min-btc-polymarket`.

The hosted scanner treats it as a strategy and operational reference only. It does not execute orders, read wallets, store Polymarket credentials, or invoke its `--execute` workflow.

The upstream project requires a separate Polymarket execution stack and credentials. Any future execution integration must remain opt-in, use dry-run validation first, and have dedicated risk limits.
