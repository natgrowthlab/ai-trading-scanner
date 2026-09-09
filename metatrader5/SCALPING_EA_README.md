# AMD Scalping EA for MetaTrader 5

AMD_Scalping_EA.mq5 is an Expert Advisor that can place and manage live orders. Its current defaults enable trading, tick evaluation, activation entries, fixed lot sizing, and volatility-filter bypass. Test it in Strategy Tester and a demo account before relying on it.

## What it does

- Evaluates the forming 1m or 5m candle on every tick by default, so it can enter without waiting for a candle close.
- Uses the same broad filters as the TradingView scalping strategy: H1 EMA trend, broker-server session (default 07:00–17:00), relative ATR, swing break, FVG/liquidity sweep, and optional AMD 4H shorts.
- Calculates lot size from InpRiskPercent (default 0.25% of equity) and the actual stop distance.
- Sends a broker-side stop loss and TP3 with each trade.
- On TP1 and TP2, attempts a 33% partial close and moves the stop to break-even.

## Micro-target mode

The default cash settings use `InpUseCashRisk=true`, `InpMaxLossUSD=4.00`, and `InpUseCashTakeProfit=true`, `InpTakeProfitUSD=3.00`. The EA calculates the target from the symbol's tick size/value and the actual order volume, so the desired gross target is approximately US$3 in a USD-denominated account. Broker commissions, spread, swaps, slippage, minimum-volume rules, and fill price mean neither a US$3 net profit nor any profit can be guaranteed.

The defaults ignore the spread *entry filter* (`InpIgnoreSpreadFilter=true`), enable both `InpEnableLongs` and `InpEnableShorts`, allow five maximum open positions per symbol, submit two orders per valid signal, use a US$200 maximum global open risk, a US$4 hard cap for the calculated risk of one trade, and a US$100 realized-loss limit for the current broker-server day. `InpMaxTradesPerDay=0` means there is no daily count limit; it does not disable loss or open-risk limits. Spread, commission and slippage still affect realised P/L; removing the filter does not remove those costs. Global risk and daily loss aggregate every symbol traded by the same EA magic number.

Set `InpOpenOnActivation=true` only in demo testing if you want it to take the first eligible trade based on the higher-timeframe trend instead of waiting for a complete structure setup. It still enforces session, spread, volatility, stop-distance and risk checks.

## Aggressive stacking mode

For an aggressive configuration, enable `InpUseFixedLot` and set `InpFixedLot`, then configure `InpMaxOpenPositions`, `InpOrdersPerSignal`, `InpCooldownBars`, `InpMaxTradesPerDay`, and `InpMaxTotalRiskUSD`. The EA will never exceed those exposure limits. Use a hedging account for separate simultaneous positions; netting accounts aggregate positions by symbol and the EA intentionally limits them to one open position. The source is symbol-agnostic: attach it to each Forex pair you want it to trade; the shared magic number keeps its open-risk and daily-loss limits global across those charts.

When more than one position is allowed, every position retains its own broker-side SL and TP3. Automatic partial exits are intentionally skipped in stacked mode to avoid applying a partial close to the wrong position.

## Tick-entry mode

Set `InpEvaluateEveryTick=true` to evaluate the current, still-forming M1/M5 candle on every price tick rather than waiting for its close. `InpMinimumSecondsBetweenEntries` limits repeated intrabar entries. This mode can enter within seconds when a price crosses a qualifying level, but intrabar conditions can disappear before candle close and are materially less reliable than closed-bar confirmation.

When `InpOpenOnActivation=true`, `InpUseFastDirectionFallback=true` allows an immediate intrabar fallback when the M15 trend is neutral: price must be above a rising entry EMA for a BUY or below a falling entry EMA for a SELL. It is symmetric for both directions and produces more entries, but is less selective than the higher-timeframe setup.

`InpUseCandleDirectionEntries=true` and `InpCandleDirectionOverridesBias=true` are enabled by default for rapid scalping. On every tick, a live green candle sends the EA to the BUY path and a live red candle sends it to the SELL path, even when the higher-timeframe bias is opposite. This is an override, not merely a fallback, so a persistent higher-timeframe BUY bias cannot suppress a SELL. The chart status identifies these orders as `live candle direction`.

## Rapid exit and re-entry mode

Each position is managed independently, including stacked hedging positions. The default rapid controls are: `InpMaxHoldSeconds=120`, `InpFastLossExitUSD=1.50`, `InpBreakEvenTriggerUSD=0.01`, and `InpReentryCooldownSeconds=3`. The EA closes a position when it reaches its maximum hold time, reaches the fast-loss amount, reverses through the entry EMA while the EMA is turning against it, or becomes losing while the live candle flips against its direction (`InpExitOnLosingCandleFlip=true`). As soon as floating profit is positive, it repeatedly attempts to move the broker-side stop to the entry price; the broker's minimum stop-distance rules can delay that change. It then evaluates another signal after the re-entry cooldown.

This is not loss recovery and it never raises the lot after a loss. Re-entering quickly can increase trading costs and losses in choppy markets; keep the daily, per-trade and total-risk limits enabled and validate the settings in the Strategy Tester and a demo account before real trading.

## Status panel and troubleshooting

Set `InpShowStatusPanel=true` to display the EA's current decision directly on the chart. It reports whether trading is disabled, a session/spread/volatility filter is blocking, position or risk limits are reached, history is loading, no setup qualifies, a rapid exit occurred, or a broker request is rejected. It also displays daily realised profit, daily realised loss, completed winner/loser counts, current equity drawdown, and maximum daily equity drawdown for the EA magic number. Drawdown is persisted per account, magic number, and broker-server day. `InpBypassVolatilityFilter=true` removes only the relative-ATR gate for aggressive demo testing; it does not bypass session, stop-distance, position or risk limits.

## On-chart controls

The upper-right chart buttons **PAUSE BOT** and **RESUME BOT** control new entries without removing the EA. Pausing preserves any existing broker-side SL and TP; it simply prevents new orders. Resume requires that MT5 Algo Trading and `InpEnableTrading` remain enabled.

## Installation and testing

1. Copy the source to MQL5/Experts/.
2. Compile in MetaEditor with F7.
3. Run it first in View → Strategy Tester with the same symbol, 1m/5m data, and realistic spread/commission.
4. Attach it to a demo chart and confirm Algo Trading is enabled.
5. Validate the broker's symbol suffix, contract size, sessions, spread, and fills before relying on automated execution.

Partial closes depend on the broker account mode. The EA always submits broker-side SL and TP3; on account modes that do not support partial close, it will retain the remaining position through TP3 after moving its stop.
