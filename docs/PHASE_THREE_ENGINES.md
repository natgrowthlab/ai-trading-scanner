# Motores de Phase 3

MTF combina tres análisis ya calculados; solo considera alineación cuando los sesgos direccionales no se contradicen. El score combina componentes con pesos configurables y conserva cada contribución individual.

Signal Engine solo persiste señales que alcanzan el mínimo cuantitativo y tienen un plan de precios coherente. La máquina de estados prohíbe saltos, reactivaciones y activaciones posteriores a expiry.

Risk Engine calcula pérdida máxima y tamaño usando balance, porcentaje, distancia entry/stop y metadatos del activo. Por defecto bloquea riesgo mayor a 2 %. Los límites diarios se mantienen independientes del cálculo de tamaño.

Estos módulos no dependen de IA, proveedores externos ni brokers; la IA no puede modificar un score o trade plan calculado.
