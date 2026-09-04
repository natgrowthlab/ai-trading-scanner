# AI Engine

The AI provider contract is intentionally optional and provider-neutral. It receives calculated signal context and returns a schema-validated explanation with verdict, confidence, reasons, warnings, and context. It cannot generate a signal or modify its entry, stop, targets, direction, state, or quant score.

# Economic news filter

EconomicCalendarProvider implementations supply timestamped events. The default filter blocks HIGH-impact windows from 15 minutes before to 15 minutes after the event. Missing calendar data does not silently claim safety; callers must explicitly decide whether to suspend scanning.
