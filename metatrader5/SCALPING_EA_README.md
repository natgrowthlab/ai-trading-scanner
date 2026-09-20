# AMD Scalping EA for MetaTrader 5

`AMD_Scalping_EA.mq5` is a closed-candle, trend-pullback Expert Advisor. Its demo defaults are active and the on-chart **PAUSE BOT** / **RESUME BOT** buttons are the only controls needed to stop or resume new entries.

## Entry logic

The EA runs only on M1 or M5 and evaluates the last closed candle. A BUY requires price above the M15 trend EMA, a rising entry EMA, and a confirmed bullish pullback, EMA cross, or one-bar momentum break. A SELL uses the exact mirrored conditions below the M15 trend EMA. It does not trade simply because the current candle changes colour.

This balanced approach intentionally avoids arbitrary tick entries but is less restrictive than the first pullback-only version. A `Waiting — no confirmed trend setup` message is normal when neither direction is confirmed.

## Demo mode defaults

- `InpTradeAllHours=true`: no EA session restriction, 24 hours a day.
- `InpIgnoreSpreadFilter=true`: spread does not block an entry.
- `InpMaxOpenPositions=0`, `InpMaxTradesPerDay=0`, `InpMaxTotalRiskUSD=0`, `InpMaxPerTradeRiskUSD=0`, and `InpMaxDailyLossUSD=0`: no EA entry, position, open-risk, per-trade-risk, or daily-loss caps.
- One order is submitted for each confirmed signal. A hedging account can hold simultaneous positions; a netting account is inherently limited by the broker to one net position per symbol.
- Broker-side stop loss and target on every order; default cash target is approximately US$3, subject to the broker's tick value and costs.
- Break-even is attempted after US$1 floating profit. Minimum stop-distance rules set by the broker can delay that move.

## Broker “invalid stops” errors

The EA now validates BUY stops from Bid and SELL stops from Ask, then moves SL/TP outside the broker's `StopsLevel` / `FreezeLevel` plus `InpStopSafetyBufferPoints` (default 50 points). This avoids an order being rejected just because the requested entry quote and executable quote differ. If a broker still rejects a fast-moving order, increase that buffer in Inputs and compile the updated EA.

## Broker “requote” errors

When price changes during an order request, the EA now refreshes the quote, re-normalizes SL/TP and retries up to `InpMaxRequoteRetries=3` times. The permitted deviation begins at `InpDeviationPoints=100` and expands by `InpRequoteDeviationStepPoints=50` on each retry. If every retry fails, the EA skips that signal instead of sending an order at an unknown price.

The EA is symbol-agnostic. To trade an OTC instrument, attach it to the exact OTC symbol supplied by the broker (for example, a symbol with an `OTC` suffix). The EA cannot make a closed broker market tradeable; broker availability, margin and execution rules still apply.

## Position management

There is no time-based exit by default. The EA can close an open trade on an EMA micro-reversal. It never raises the lot after a loss and it does not re-enter to recover a losing trade. The broker-side SL remains the hard loss boundary.

## Required test process

1. Compile with F7 in MetaEditor.
2. In MT5 Strategy Tester, run M1 or M5 data for the same broker symbol with realistic commission and spread.
3. Check net profit, profit factor, maximum drawdown, number of trades and the BUY/SELL distribution over multiple market periods.
4. Use the on-chart **PAUSE BOT** button whenever you need to block new entries; existing broker-side SL/TP remain in place.

The EA is not suitable for a live account until this process shows stable behaviour. Automated trading can lose money, including more quickly during volatile markets or poor fills.
