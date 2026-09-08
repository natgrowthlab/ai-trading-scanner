# AMD Scalping EA for MetaTrader 5

AMD_Scalping_EA.mq5 is an Expert Advisor that can place and manage live orders. Its current defaults enable trading, tick evaluation, activation entries, fixed lot sizing, and volatility-filter bypass. Test it in Strategy Tester and a demo account before relying on it.

## What it does

- Evaluates new closed 1m or 5m bars only.
- Uses the same broad filters as the TradingView scalping strategy: H1 EMA trend, broker-server session (default 07:00–17:00), relative ATR, swing break, FVG/liquidity sweep, and optional AMD 4H shorts.
- Calculates lot size from InpRiskPercent (default 0.25% of equity) and the actual stop distance.
- Sends a broker-side stop loss and TP3 with each trade.
- On TP1 and TP2, attempts a 33% partial close and moves the stop to break-even.

## Micro-target mode

The default cash settings use `InpUseCashRisk=true`, `InpMaxLossUSD=4.00`, and `InpUseCashTakeProfit=true`, `InpTakeProfitUSD=3.00`. The EA calculates the target from the symbol's tick size/value and the actual order volume, so the desired gross target is approximately US$3 in a USD-denominated account. Broker commissions, spread, swaps, slippage, minimum-volume rules, and fill price mean neither a US$3 net profit nor any profit can be guaranteed.

The defaults use a 200-point spread cap, five maximum open positions per symbol, two orders per valid signal, US$200 maximum global open risk, US$4 hard cap for the calculated risk of one trade, and a US$100 realized-loss limit for the current broker-server day. Global risk and daily loss aggregate every symbol traded by the same EA magic number.

Set `InpOpenOnActivation=true` only in demo testing if you want it to take the first eligible trade based on the higher-timeframe trend instead of waiting for a complete structure setup. It still enforces session, spread, volatility, stop-distance and risk checks.

## Aggressive stacking mode

For an aggressive configuration, enable `InpUseFixedLot` and set `InpFixedLot`, then configure `InpMaxOpenPositions`, `InpOrdersPerSignal`, `InpCooldownBars`, `InpMaxTradesPerDay`, and `InpMaxTotalRiskUSD`. The EA will never exceed those exposure limits. Use a hedging account for separate simultaneous positions; netting accounts aggregate positions by symbol and the EA intentionally limits them to one open position. The source is symbol-agnostic: attach it to each Forex pair you want it to trade; the shared magic number keeps its open-risk and daily-loss limits global across those charts.

When more than one position is allowed, every position retains its own broker-side SL and TP3. Automatic partial exits are intentionally skipped in stacked mode to avoid applying a partial close to the wrong position.

## Tick-entry mode

Set `InpEvaluateEveryTick=true` to evaluate the current, still-forming M1/M5 candle on every price tick rather than waiting for its close. `InpMinimumSecondsBetweenEntries` limits repeated intrabar entries. This mode can enter within seconds when a price crosses a qualifying level, but intrabar conditions can disappear before candle close and are materially less reliable than closed-bar confirmation.

## Status panel and troubleshooting

Set `InpShowStatusPanel=true` to display the EA's current decision directly on the chart. It reports whether trading is disabled, a session/spread/volatility filter is blocking, position or risk limits are reached, history is loading, no setup qualifies, or a broker request is rejected. `InpBypassVolatilityFilter=true` removes only the relative-ATR gate for aggressive demo testing; it does not bypass session, spread, stop-distance, position or risk limits.

## Installation and testing

1. Copy the source to MQL5/Experts/.
2. Compile in MetaEditor with F7.
3. Run it first in View → Strategy Tester with the same symbol, 1m/5m data, and realistic spread/commission.
4. Attach it to a demo chart and confirm Algo Trading is enabled.
5. Validate the broker's symbol suffix, contract size, sessions, spread, and fills before relying on automated execution.

Partial closes depend on the broker account mode. The EA always submits broker-side SL and TP3; on account modes that do not support partial close, it will retain the remaining position through TP3 after moving its stop.
