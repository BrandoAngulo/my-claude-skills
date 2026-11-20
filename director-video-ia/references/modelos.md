# Selección de modelo

> **Snapshot: noviembre 2026.** Los modelos cambian cada pocas semanas. Si hay búsqueda web disponible, verifica antes de recomendar: versión vigente, nuevas capacidades, precio y si el modelo sigue disponible en las plataformas del usuario. Actualiza este archivo cuando cambie algo importante.

## Plataforma ≠ modelo
Las plataformas (Higgsfield, Runway, apps de Google, etc.) son el supermercado; los modelos son los productos. El mismo modelo suele estar en varias plataformas y por API. Recomienda **modelos**, y luego dónde usarlos según lo que el usuario ya tiene. Para pipelines, prefiere acceso por API.

## Elige por necesidad, no por fama
| Necesidad de la toma | Qué buscar en el modelo |
|---|---|
| Diálogo en español | Audio nativo con buena pronunciación y energía; probar 2–3 y comparar |
| Consistencia con varias referencias | Modelo omni / multireferencia |
| Varios planos en una generación | Multishot / soporte de action sequence |
| Editar footage existente | Modelo de edición de video (cambio de entorno, ropa, objetos) |
| B-roll sin personajes | Cualquiera decente; prioriza costo y velocidad |
| Pruebas baratas | Variantes "fast" o 720p |
| Imágenes (fichas, first frames) | Modelos de imagen con buena fidelidad a referencias y texto mínimo |

## Observaciones del snapshot (pruebas reportadas en el curso de Platzi, 2026)
- **Veo 3.1 (Google):** el mejor resultado en UGC hablando español: pronunciación correcta, energía, sin artefactos en cara ni bordes al revisar cuadro a cuadro. Acceso por AI Studio / API.
- **Kling 3.0:** buena pronunciación en español pero energía plana en diálogo. Tiene *Multishot* (varios planos en una generación) pero en pruebas desde storyboard metió el storyboard completo como primer cuadro y dejó artefactos de continuidad. Su variante **Omni Edit** sirve para transformar footage manteniendo a la persona (cambio de escenario/ropa).
- **Seedance 2.0 (ByteDance):** omni/multireferencia; desde storyboard + character sheets logró la secuencia más consistente. Hasta ~15 s por generación. Fallos de pronunciación en palabras poco comunes en español. Variante **Fast** a 720p para gastar menos.
- **Gemini Omni (Google):** edición de video por prompt o con imagen de referencia, dentro de la app de Gemini (requiere suscripción). Permite seguir ajustando en la misma conversación.
- **Imagen:** GPT Image 2 y Nano Banana Pro para fichas, first frames, edición del primer cuadro y storyboards.
- **Música:** Suno (generaciones gratuitas limitadas), modo instrumental.

## Cambios de disponibilidad (noviembre 2026)
- **API de Gemini:** los modelos preview de Veo 3.1 se apagaron el 22 oct 2026; el reemplazo es **Gemini Omni Flash** (Interactions API). Para pipelines nuevos, no construyas sobre Veo 3.1 por API.
- **Flow:** Veo 3.1 Fast, Veo 3.1 Quality y Omni 1.1 Flash salen el **5 dic 2026**; quedan Veo 3.1 Lite y **Omni 1.2 Flash** (nuevo).
- **Costos en Flow (plan Google AI Pro, 1000 créditos/mes, no se acumulan):** Veo 3.1 Fast ≈ 20 créditos por 8 s a 720p (1 resultado); Omni 1.2 Flash ≈ 24 créditos a 720p; imágenes con Nano Banana / Nano Banana Pro: 0 créditos. Por eso conviene iterar en imagen.

## Observación de producción propia (comercial de perfume, nov 2026)
- **Veo 3.1 Fast con primer y último cuadro** conservó la etiqueta del frasco cuando las imágenes de entrada estaban correctas: los errores de texto venían de las imágenes, no del video. 15 s de comercial (6 tomas, 2 regeneradas) costaron 180 créditos.
- **Nano Banana Pro** para la imagen madre y sus derivadas: buena fidelidad, pero cambió letras en algunas variantes ("GLORY" → "CLURY", apóstrofe perdido). Revisar al 100 %.

Nota: transcripciones del curso escriben "Seance", "Sidance", "Zidance" o "Ziyans"; todas se refieren a Seedance.

## Seedance 2.5 en Higgsfield (blog de Higgsfield, ago 2026)
- Hasta **30 s** en una sola toma continua; 480p, 720p o 1080p (reescalado a 4K aparte).
- Hasta **50 referencias** (imágenes o clips) por generación; audio (ambiente, efectos, música) en la misma pasada.
- Control de movimiento (trayectoria de cámara y sujeto), elección de cámara y lente, y constructor de escena 3D para ubicar cámara y luz.
- Funciones de transición entre dos clips y de extender un clip.
- **Costo por 10 s:** 480p = 30 créditos (US$1.50) · 720p = 70 (US$3.50) · 1080p = 120 (US$6.00). **Probar siempre en 480p** y subir a la resolución final solo con la toma aprobada: la prueba cuesta 4 veces menos.
- Se usa también para reestilizar video real (video→video) con texto animado y barridos de cámara: base del modo "base real".

## Motion graphics por código: HyperFrames (decisión nov 2026)
- Motor elegido para textos animados, contadores, logos, tercios inferiores, mapas, gráficos y animaciones 3D que siguen un movimiento: **HyperFrames** (HeyGen, licencia Apache 2.0, HTML/CSS/JS → MP4 o capa con transparencia). Requiere Node 22+ y FFmpeg; comandos `npx hyperframes init | preview | render`.
- Se prefirió a Remotion porque Remotion es de código visible con licencia de pago a partir de cierto tamaño de empresa.
- No gasta créditos de video: lo que se pueda hacer así no se genera con IA (riesgo 13 del auditor).

## Cómo recomendar
Por toma: `Modelo principal — razón en una línea · Alternativa — cuándo usarla`.
Ejemplo:
- Toma 3 (Valeria habla a cámara, 6 s): **Veo 3.1** — mejor pronunciación y energía en español · Alternativa **Kling 3.0** si Veo falla en el gesto, con voz revisada.
- Tomas 5–7 (B-roll de producto): **el más barato disponible en 720p** — no hay personaje que mantener.

Si el usuario no tiene acceso al modelo ideal, recomienda el mejor de lo que tiene y di qué se pierde.
