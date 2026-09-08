# AMD Scalping EA for MetaTrader 5

AMD_Scalping_EA.mq5 is an Expert Advisor that can place and manage live orders. It starts with InpEnableTrading=false. Keep it disabled until it has compiled and passed Strategy Tester and demo-account testing.

## What it does

- Evaluates new closed 1m or 5m bars only.
- Uses the same broad filters as the TradingView scalping strategy: H1 EMA trend, broker-server session (default 07:00–17:00), relative ATR, swing break, FVG/liquidity sweep, and optional AMD 4H shorts.
- Calculates lot size from InpRiskPercent (default 0.25% of equity) and the actual stop distance.
- Sends a broker-side stop loss and TP3 with each trade.
- On TP1 and TP2, attempts a 33% partial close and moves the stop to break-even.

## Micro-target mode

The default micro-target settings use `InpUseCashRisk=true`, `InpMaxLossUSD=0.50`, and `InpUseCashTakeProfit=true`, `InpTakeProfitUSD=1.00`. The EA calculates the target from the symbol's tick size/value and the actual order volume, so the desired gross target is approximately US$1 in a USD-denominated account. Broker commissions, spread, swaps, slippage, minimum-volume rules, and fill price mean neither a US$1 net profit nor any profit can be guaranteed.

Set `InpOpenOnActivation=true` only in demo testing if you want it to take the first eligible trade based on the higher-timeframe trend instead of waiting for a complete structure setup. It still enforces session, spread, volatility, stop-distance and risk checks.

## Aggressive stacking mode

For an aggressive configuration, enable `InpUseFixedLot` and set `InpFixedLot`, then configure `InpMaxOpenPositions`, `InpOrdersPerSignal`, `InpCooldownBars`, `InpMaxTradesPerDay`, and `InpMaxTotalRiskUSD`. The EA will never exceed those exposure limits. Use a hedging account for separate simultaneous positions; netting accounts aggregate positions by symbol and the EA intentionally limits them to one open position.

When more than one position is allowed, every position retains its own broker-side SL and TP3. Automatic partial exits are intentionally skipped in stacked mode to avoid applying a partial close to the wrong position.

## Tick-entry mode

Set `InpEvaluateEveryTick=true` to evaluate the current, still-forming M1/M5 candle on every price tick rather than waiting for its close. `InpMinimumSecondsBetweenEntries` limits repeated intrabar entries. This mode can enter within seconds when a price crosses a qualifying level, but intrabar conditions can disappear before candle close and are materially less reliable than closed-bar confirmation.

## Installation and testing

1. Copy the source to MQL5/Experts/.
2. Compile in MetaEditor with F7.
3. Run it first in View → Strategy Tester with the same symbol, 1m/5m data, and realistic spread/commission.
4. Attach it to a demo chart, confirm Algo Trading is enabled, but leave InpEnableTrading=false while observing it.
5. Only after validating the broker's symbol suffix, contract size, sessions, spread, and fills should you explicitly set InpEnableTrading=true.

Partial closes depend on the broker account mode. The EA always submits broker-side SL and TP3; on account modes that do not support partial close, it will retain the remaining position through TP3 after moving its stop.
