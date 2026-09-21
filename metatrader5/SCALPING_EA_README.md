# AMD Scalping EA for MetaTrader 5

`AMD_Scalping_EA.mq5` is a confirmed trend-pullback Expert Advisor for demo use. Its defaults are active and the on-chart **PAUSE BOT** / **RESUME BOT** buttons are the controls needed to stop or resume new entries.

## Entry logic

The EA runs only on M1 or M5 and evaluates the completed candle. A BUY requires price above the M15 fast EMA, a bullish impulse candle of at least `InpImpulseATRMultiple` ATR, then a bullish rejection candle that returns near and closes back above EMA 20. SELL uses the exact mirrored conditions. `InpRejectionWickBodyRatio` controls the required rejection wick relative to the signal body and `InpRetracementBufferPoints` permits a small EMA-touch tolerance.

`InpMaxEntriesPerCandle=0` removes the EA limit on entries in one M1/M5 candle for demo mode. Set a positive value such as `3` if you later want to cap successful entries in each candle.

`InpOneActiveTradeAtATime=true` prevents the EA from stacking positions while one trade is still active. It can make a new sequential trade after the quick-profit exit or after price invalidates the EMA pullback.

## Demo mode defaults

- `InpTradeAllHours=true`: no EA session restriction, 24 hours a day.
- `InpIgnoreSpreadFilter=true`: spread does not block an entry.
- `InpMaxOpenPositions=0`, `InpMaxTradesPerDay=0`, `InpMaxTotalRiskUSD=0`, `InpMaxPerTradeRiskUSD=0`, and `InpMaxDailyLossUSD=0`: no EA entry, position, open-risk, per-trade-risk, or daily-loss caps.
- One order is submitted for each confirmed signal. A hedging account can hold simultaneous positions; a netting account is inherently limited by the broker to one net position per symbol.
- No broker TP is placed by default (`InpUseCashTakeProfit=false`).
- A broker-side SL remains on every order.
- At US$0.50 floating profit, the EA moves SL to protected break-even: entry plus/minus an estimated US$0.10 lock (`InpBreakEvenLockUSD`). It retries on later ticks until the broker's minimum stop-distance allows the move.
- At US$1 floating profit (`InpQuickProfitCloseUSD`), it closes the position at market and can evaluate another entry after the one-second cooldown.

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
