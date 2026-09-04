# Backtesting

The Phase 4 engine processes one candle at a time after an order is created. It never uses a later candle to decide an earlier outcome. If one OHLC candle reaches both stop and target, it exits at the stop: a conservative policy that avoids optimistic intrabar assumptions.

Each trade records R multiple, MAE and MFE. Aggregate metrics include trade count, wins/losses, win rate, profit factor, expectancy, net R, and maximum drawdown in R. Slippage, spread, fees, strategies, and historical data ingestion are separate integration work and are not fabricated in reports.

Analytics additionally calculates Sharpe/Sortino from R returns, weekday segmentation, and a deterministic regime label. A zero-trade result remains zero and is never displayed as a performance claim.
