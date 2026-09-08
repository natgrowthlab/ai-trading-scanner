# AMD Trade Plan for MetaTrader 5

`AMD_Trade_Plan.mq5` is a custom visual indicator; it never opens, closes, or modifies orders.

## Installation

1. In MT5 choose **File → Open Data Folder**.
2. Copy `AMD_Trade_Plan.mq5` to `MQL5/Indicators/`.
3. Open MetaEditor, compile the file, then attach **AMD Trade Plan MT5** to a 1m, 5m, or 1h chart.

The indicator always displays a status panel in the upper-left corner. It detects the 4H wickless-candle AMD target, uses lower-timeframe confirmation, and draws BUY/SELL, ENTRY, SL, TP1, TP2, and TP3. On first load it also draws the six most recent structural plans, so the chart does not remain blank while waiting for a new AMD confirmation.

## Update an existing installation

Replace the old file in `MQL5/Indicators/`, compile it again in MetaEditor with **F7**, then remove and re-add the indicator to the chart. Confirm that **AMD Trade Plan MT5** appears in the upper-left corner of the chart.
