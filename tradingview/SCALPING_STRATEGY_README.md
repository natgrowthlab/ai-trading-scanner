# AMD Scalping Strategy

scalping_strategy.pine is a TradingView Pine v6 strategy, not an indicator. Add it to a 1m or 5m chart and review the Strategy Tester.

The defaults model a $10,000 account, 5% position sizing, 0.05% commission, and two ticks of slippage. Change the Properties tab to match the broker and instrument. It uses:

- a 1H directional EMA filter;
- New York session filter (07:00–17:00);
- relative-ATR volatility filter;
- confirmed break of structure plus FVG or liquidity sweep;
- an AMD 4H wickless-candle target for qualified shorts;
- partial exits at 1R, 1.5R, and 2R.

Evaluate at least 100 trades, across in-sample and out-of-sample date ranges. Do not optimise settings on one symbol or one period and assume the result will persist.
