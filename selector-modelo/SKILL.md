---
name: selector-modelo
description: Decide qué modelo de Claude usar para cada tarea o fase (Haiku, Sonnet, Opus o Fable) según riesgo, costo y el cupo del plan, y lo aplica delegando en subagentes con el modelo adecuado o avisando cuándo cambiar el modelo principal. Úsala al empezar un trabajo de varias fases, antes de lanzar subagentes, cuando una tarea falla dos veces, cuando el usuario pregunte qué modelo usar o hable de límites o de ahorrar uso, y siempre que director-video-ia, auditor-video-ia u otra skill necesite repartir trabajo entre modelos — en video y en desarrollo de software.
---

# Selector de modelo de Claude

Elige el modelo más barato que haga bien la tarea, y reserva el más capaz para donde un error cuesta dinero, créditos o tiempo de producción.

## Qué puede hacer y qué no
- **No puede cambiar el modelo de la conversación actual.** Eso lo hace el usuario (`/model` en Claude Code, el selector en el chat). Cuando la fase lo pida, avísale en una línea: "Esta fase conviene en Fable 5.2: cámbialo con /model".
- **Sí puede delegar:** al lanzar un subagente se elige su modelo (`haiku`, `sonnet`, `opus`, `fable`). Esa es la forma de repartir el trabajo automáticamente.
- **No puede leer cuánto cupo queda.** Antes de un bloque grande en Fable, pregunta al usuario cuánto lleva usado (lo ve en Configuración → Uso) o si tiene un reinicio disponible.

## Los modelos (snapshot noviembre 2026)
| Modelo | Perfil | Úsalo para |
|---|---|---|
| **Haiku 5.5** | Rápido y barato | Trabajo mecánico con receta clara: inventarios, renombrar, formatear, ordenar datos, ejecutar herramientas y reportar su salida |
| **Sonnet 5.5** | Equilibrado | Tareas acotadas bien definidas: código de una o pocas piezas, scripts, ejecutar un plan ya decidido, resúmenes, juntar investigación |
| **Opus 5.5** | El de todos los días (recomendación de Anthropic) | Planear, decidir, escribir, la mayoría del código, análisis, revisión normal |
| **Fable 5.2** | El más capaz; razonamiento visual, 3D, código difícil, uso del computador y orquestación muy superiores | Donde equivocarse sale caro o Opus no alcanza: ver tablas por área |

Si hay búsqueda web y el snapshot tiene más de 30 días, verifica nombres, capacidades y límites en anthropic.com antes de recomendar.

## Reglas de decisión
1. **Riesgo primero:** si un error se paga (créditos de video, producción, seguridad, datos de clientes, horas de trabajo perdidas), sube un nivel.
2. **Empieza barato y escala:** si un modelo falla dos veces la misma tarea, pasa al siguiente con un resumen de lo intentado; no repitas el mismo intento.
3. **Baja en lo repetitivo:** cuando una tarea ya tiene receta (prompt, script, checklist que funciona), pásala a un modelo más barato.
4. **Separa pensar de ejecutar:** el plan y la revisión en el modelo capaz; la ejecución mecánica del plan en subagentes baratos.
5. **Independencia:** las auditorías corren en un subagente distinto del que creó el trabajo, y con un modelo igual o más capaz que el creador.
6. **Cupo de Fable:** úsalo solo en tareas de riesgo alto o cuando Opus falló. Con plan Pro, Fable puede gastar como máximo el 50 % del límite semanal (noviembre 2026); agrupa el trabajo de Fable en un bloque en vez de repartirlo. El cupo es uno solo para todos los equipos y usos de la cuenta (PC personal, PC de la empresa, video y desarrollo): reparte Fable por prioridad y, si una semana hay un bloque grande planeado (p. ej. construir el módulo 3D), reserva el cupo para ese bloque.

## Tablas por área
- Producción de video con IA: `references/video.md`
- Desarrollo de software (día a día): `references/desarrollo.md`
Para otra área, aplica las reglas de decisión y, si se repite, agrega su tabla.

## Formato de respuesta
Una línea por tarea o fase: **Modelo** · por qué (riesgo o costo) · cómo (subagente o cambiar el modelo principal). Ejemplo:
- Revisión B del comercial final · **Fable 5.2** · se va a publicar y lo visual es su fuerte · subagente `fable`.
- Extraer cuadros cada 0.5 s · **Haiku 5.5** · mecánico · subagente `haiku`.
