# Optimizer

Grid and seeded random search call the same supplied evaluator used by backtesting. Walk-forward windows always put validation after training. Monte Carlo randomizes trade order with a seed and reports P5/P50/P95 net R.

Optimization is not evidence of profitability. Any result with fewer than 100 trades must be labeled low-sample; evaluation policy remains the caller's responsibility.
