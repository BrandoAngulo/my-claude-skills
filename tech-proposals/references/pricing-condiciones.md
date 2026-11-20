# Pricing, moneda y condiciones

## Modelos de cobro

| Modelo | Cuándo usarlo | Riesgo a controlar |
|---|---|---|
| **Proyecto cerrado** | Alcance claro y acotado (lo normal en pymes) | Scope creep → sección "No incluido" + cambios cotizados aparte |
| **Por fases** | Proyecto grande o cliente con presupuesto limitado | Cada fase con precio y entregable propio; el cliente puede parar entre fases sin drama |
| **Retainer mensual** | Mantenimiento, mejoras continuas, soporte | Definir qué incluye el mes (horas/alcance) y qué no; renovación automática salvo aviso |
| **Por hora** | EVITAR con clientes nuevos | Solo para trabajos exploratorios cortos; invita a regatear y a auditar el reloj |

## Las 3 opciones (good / better / best)

- **Esencial**: el mínimo que resuelve el dolor principal. Precio de entrada.
- **Recomendado** ⭐: lo que realmente le conviene — aquí va el esfuerzo de
  venta. Precio ~1.5-1.8x el esencial.
- **Completo**: todo, incluida la fase aspiracional. Precio ~2.5x. Pocas veces
  se vende, pero hace ver razonable el Recomendado (ancla).

Regla: las tres opciones deben ser honestas — si el Esencial no resuelve nada
real, es un señuelo y el cliente lo nota.

## Hitos de pago

- **Anticipo 40-50% para iniciar** — innegociable: filtra clientes no serios
  y financia el arranque.
- Resto contra hitos verificables ("Fase 1 funcionando"), no contra fechas.
- Último pago contra entrega final — nunca dejar >25% al final (riesgo de
  cliente que desaparece con el sistema andando).
- Entrega de código/accesos definitivos: con el pago completo.

---

## Manejo de moneda — COP vs USD

### Cuándo cotizar en cada una

| Situación | Moneda |
|---|---|
| Cliente colombiano, proyecto local | **COP** — siempre. Cotizar en USD a una pyme colombiana genera fricción, desconfianza ("¿me va a cobrar según el dólar?") y fricción contable para ellos |
| Cliente extranjero o que factura en USD | **USD** — natural para ellos y te protege de la devaluación |
| Proyecto local LARGO (>4 meses) o retainer extendido | COP con **cláusula de ajuste** (ver abajo) — nunca trasladar el riesgo cambiario al cliente local de forma visible |

### Presentación a clientes colombianos sin fricción

- Precios en COP **redondeados a cifras limpias**: $8.500.000, no $8.473.250
  (la cifra exacta huele a cálculo de horas y abre el regateo).
- Formato colombiano: puntos de miles, "COP" o "$" pesos explícito —
  nunca mezclar símbolos que dejen duda de la moneda.
- Si el costo interno depende de servicios en USD (hosting, APIs, WhatsApp
  Business), **absorber el cálculo y mostrar solo COP**: "los costos de
  plataforma se estiman en $80.000 COP/mes". La conversión es problema
  nuestro, no del cliente.
- IVA/retenciones: indicar si los valores incluyen o no impuestos
  ("Valores antes de IVA" o "No responsable de IVA", según tu régimen) —
  la sorpresa tributaria mata más cierres que el precio.

### Indexación y protección cambiaria (proyectos largos / retainers)

- **Proyecto cerrado ≤3 meses en COP**: precio fijo, sin indexación. El
  riesgo cambiario corto es nuestro y es pequeño.
- **Retainer en COP**: cláusula de ajuste ANUAL simple y estándar:
  *"El valor mensual se ajusta cada 12 meses según el IPC publicado por el
  DANE."* — el IPC es familiar y nadie lo discute; la TRM en un contrato
  local asusta.
- **Costos de terceros en USD** (APIs, hosting): dejarlos FUERA del precio
  cerrado, pagados directamente por el cliente a su nombre:
  *"Los costos de plataformas de terceros (~$25 USD/mes ≈ $100.000 COP/mes
  a la tasa actual) son asumidos directamente por el cliente."*
  Así la TRM nunca toca nuestros números.
- **Contratos en USD** (cliente extranjero): facturar en USD y especificar
  *"pagos a la TRM del día de la factura"* solo si el cliente paga en COP
  por algún motivo.

---

## Condiciones estándar (las que evitan problemas)

| Condición | Texto base |
|---|---|
| Revisiones | "Cada fase incluye 2 rondas de ajustes sobre lo entregado" |
| Cambio de alcance | "Funcionalidades no descritas en Entregables se cotizan por separado ANTES de ejecutarse" |
| Dependencia del cliente | "Los tiempos asumen respuesta a solicitudes de información en máximo 3 días hábiles; demoras extienden el cronograma" |
| Propiedad | "Código y accesos quedan a nombre del cliente al completar el pago" |
| Soporte post-entrega | "N días de acompañamiento incluidos; después, plan de mantenimiento opcional" |
| Pausa por no pago | "Hitos de pago vencidos >10 días hábiles pausan el desarrollo" |
| Vigencia | "Propuesta válida por 15 días calendario" |

## Ajustes según el tipo de cliente

| Tipo | Precio | Condiciones |
|---|---|---|
| **Familiar o amigo** | Precio de lista + descuento visible (10-20%) con contraprestación. Nunca bajar la lista en silencio: se vuelve el piso de todo lo que venga. | Contrato, anticipo e hitos iguales a cualquier cliente. Presentar las condiciones en persona antes de enviar el documento. |
| **Detallista / exigente** | No bajar el precio: las revisiones consumen más horas. | Un solo interlocutor que aprueba; observaciones en una lista consolidada por ronda; boceto aprobado antes de construir; acta de entrega por fase; reporte semanal corto. |
| **Estratégico** (caso de éxito, referidos, recurrencia) | Descuento "cliente fundador" solo en la opción Recomendada y la Completa, para empujar la que conviene. | A cambio: firma dentro de la vigencia, pagos a tiempo, permiso para publicar el caso (sin datos sensibles), testimonio y referidos. El mantenimiento va a precio normal: es el ingreso recurrente. |

Los tipos se combinan (familiar + detallista + estratégico): se aplica el
descuento de uno y las condiciones de todos.

## Señales de alerta (clientes que salen caros)

- Regatea el anticipo o propone "pagar todo al final" → no iniciar.
- "Es algo muy sencillo, no debería costar tanto" antes de ver la propuesta
  → no valora el trabajo; el proyecto entero será así.
- Tercer cambio de alcance ANTES de firmar → multiplicará por 3 después.
- No puede nombrar quién decide → la propuesta morirá en un comité fantasma.
- Pide el desglose por horas → quiere auditar el reloj, no el resultado;
  responder con el valor de negocio, no con la tabla de horas.
- "Mi sobrino sabe de sistemas y lo va a revisar" → habrá un segundo
  decisor técnico invisible; pedir incluirlo en la reunión de inicio.

Una señal = precaución (subir anticipo, cerrar más el alcance).
Dos o más = declinar con elegancia: "no somos el proveedor adecuado para
este proyecto".
