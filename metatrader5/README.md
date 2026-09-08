# AMD Trade Plan for MetaTrader 5

`AMD_Trade_Plan.mq5` is a custom visual indicator; it never opens, closes, or modifies orders.

## Installation

1. In MT5 choose **File → Open Data Folder**.
2. Copy `AMD_Trade_Plan.mq5` to `MQL5/Indicators/`.
3. Open MetaEditor, compile the file, then attach **AMD Trade Plan MT5** to a 1m, 5m, or 1h chart.

The indicator detects the 4H wickless-candle AMD target, uses lower-timeframe confirmation, and draws BUY/SELL, ENTRY, SL, TP1, TP2, and TP3. It also supports structural fallback plans so the chart remains informative when an AMD target is not active.
