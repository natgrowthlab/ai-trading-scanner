# AMD Trade Plan for MetaTrader 5

`AMD_Trade_Plan.mq5` is a custom visual indicator; it never opens, closes, or modifies orders.

## Installation

1. In MT5 choose **File → Open Data Folder**.
2. Copy `AMD_Trade_Plan.mq5` to `MQL5/Indicators/`.
3. Open MetaEditor, compile the file, then attach **AI Trading Scanner · AMD** to a 1m, 5m, 1h, or 1D chart.

## TradingView parity

This version mirrors the active TradingView script's inputs and behaviour: 4H wickless-candle AMD target, swing break, liquidity-sweep and bearish-FVG confirmation score, ATR stop floor, cooldown, optional session high/low, and the active BUY/SELL risk-reward plan. The active plan uses the same green target zone, red risk zone, blue entry line, TP1/TP2/TP3, SL, and outcome labels.

It always displays an AMD status panel in the upper-left corner, the latest swing high/low, and (by default) the three most recent structural plans, so it remains visually useful before the next live signal. MT5 terminal alerts can be enabled with `InpTerminalAlerts`; direct Telegram webhooks remain a TradingView-alert feature.

## Update an existing installation

Replace the old file in `MQL5/Indicators/`, compile it again in MetaEditor with **F7**, then remove and re-add the indicator to the chart. Confirm that **AMD Trade Plan MT5** appears in the upper-left corner of the chart.
