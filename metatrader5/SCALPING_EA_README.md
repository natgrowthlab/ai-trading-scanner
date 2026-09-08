# AMD Scalping EA for MetaTrader 5

AMD_Scalping_EA.mq5 is an Expert Advisor that can place and manage live orders. It starts with InpEnableTrading=false. Keep it disabled until it has compiled and passed Strategy Tester and demo-account testing.

## What it does

- Evaluates new closed 1m or 5m bars only.
- Uses the same broad filters as the TradingView scalping strategy: H1 EMA trend, broker-server session (default 07:00–17:00), relative ATR, swing break, FVG/liquidity sweep, and optional AMD 4H shorts.
- Calculates lot size from InpRiskPercent (default 0.25% of equity) and the actual stop distance.
- Sends a broker-side stop loss and TP3 with each trade.
- On TP1 and TP2, attempts a 33% partial close and moves the stop to break-even.

## Installation and testing

1. Copy the source to MQL5/Experts/.
2. Compile in MetaEditor with F7.
3. Run it first in View → Strategy Tester with the same symbol, 1m/5m data, and realistic spread/commission.
4. Attach it to a demo chart, confirm Algo Trading is enabled, but leave InpEnableTrading=false while observing it.
5. Only after validating the broker's symbol suffix, contract size, sessions, spread, and fills should you explicitly set InpEnableTrading=true.

Partial closes depend on the broker account mode. The EA always submits broker-side SL and TP3; on account modes that do not support partial close, it will retain the remaining position through TP3 after moving its stop.
