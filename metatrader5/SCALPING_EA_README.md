# AMD Scalping EA for MetaTrader 5

`AMD_Scalping_EA.mq5` is a closed-candle, trend-pullback Expert Advisor. It is paused by default (`InpEnableTrading=false`) so a newly compiled copy cannot begin trading until you explicitly enable it after testing.

## Entry logic

The EA runs only on M1 or M5 and evaluates the last closed candle. A BUY requires price above the M15 trend EMA, a rising entry EMA, and a confirmed bullish pullback, EMA cross, or one-bar momentum break. A SELL uses the exact mirrored conditions below the M15 trend EMA. It does not trade simply because the current candle changes colour.

This balanced approach intentionally avoids arbitrary tick entries but is less restrictive than the first pullback-only version. A `Waiting — no confirmed trend setup` message is normal when neither direction is confirmed.

## Default safety limits

- One position and one order per signal.
- Maximum 20 entries per broker-server day.
- Spread filter enabled at 200 points. Spread, commission and slippage remain real trading costs.
- Calculated risk cap: US$1.50 per trade and US$4 open risk. The stop is based on the completed signal candle plus a small ATR buffer, not a distant historical swing.
- Daily realised-loss limit: US$10.
- Broker-side stop loss and target on every order; default cash target is approximately US$3, subject to the broker's tick value and costs.
- Break-even is attempted after US$1 floating profit. Minimum stop-distance rules set by the broker can delay that move.

Those values are conservative starting values, not a promise of profitability. They need to be validated for the exact symbol, broker, account currency, commission and lot size.

## Position management

The EA can close an open trade on the 15-minute maximum hold time or an EMA micro-reversal. It never raises the lot after a loss and it does not re-enter to recover a losing trade. The fixed broker SL remains the hard loss boundary.

## Required test process

1. Compile with F7 in MetaEditor.
2. In MT5 Strategy Tester, run M1 or M5 data for the same broker symbol with realistic commission and spread.
3. Check net profit, profit factor, maximum drawdown, number of trades and the BUY/SELL distribution over multiple market periods.
4. Use a demo account before enabling `InpEnableTrading=true`.
5. Use the on-chart **PAUSE BOT** button whenever you need to block new entries; existing broker-side SL/TP remain in place.

The EA is not suitable for a live account until this process shows stable behaviour. Automated trading can lose money, including more quickly during volatile markets or poor fills.
