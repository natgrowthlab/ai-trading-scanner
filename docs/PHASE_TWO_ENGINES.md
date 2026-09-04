# Motores de Phase 2

## Liquidity

Entrada: velas OHLCV ordenadas y configuración ATR. Salida: pools de equal highs/equal lows y sweeps confirmados por cierre. Los niveles usan una tolerancia dinámica, nunca igualdad exacta. Un sweep alcista exige mínimo por debajo del pool y cierre por encima; el bajista es el inverso.

## Fair Value Gaps

Entrada: velas ordenadas. Salida: gaps alcistas o bajistas de tres velas, con tamaño, ratio ATR, midpoint y mitigación. Un FVG solo se crea al cierre de la tercera vela; la mitigación se calcula únicamente con velas posteriores.

## Order Blocks

Entrada: velas, eventos BOS y FVG existentes. Salida: la última vela opuesta antes de un BOS, validada por displacement ATR y volumen relativo. El score refleja displacement, volumen y proximidad FVG. No marca todas las velas como bloque.

## Volume y momentum

Volume produce SMA/EMA, volumen relativo, spike, OBV y VWAP acumulado. Momentum produce RSI, ROC, ATR, pendiente EMA, score 0–100 y estado direccional. Ambos son cálculos puros sin provider ni acceso a base de datos.

## Límites actuales

Session/anchored VWAP, CVD, funding, open interest y volumen comprador/vendedor requieren datos que el proveedor debe exponer; no se fabrican cuando faltan. Estos módulos no generan señales ni operaciones.
