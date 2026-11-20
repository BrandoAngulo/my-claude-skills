# Producción de video con IA

| Paso | Modelo | Por qué |
|---|---|---|
| Brief, dirección visual, guion y guion técnico (`director-video-ia` fases 0–2) | Opus 5.5 | Creatividad y criterio; error barato de corregir en texto |
| Fichas, first frames y prompts de video (fases 3–6) | Opus 5.5 | Escritura técnica con reglas claras |
| **Revisión A del auditor** cuando se gastarán créditos caros (Higgsfield, varias tomas, pieza para cliente) | **Fable 5.2** | Un fallo no detectado se paga en créditos; mejor razonamiento visual sobre los cuadros de entrada |
| Revisión A en pruebas baratas (Flow, una toma de prueba) | Opus 5.5 | El riesgo es bajo |
| **Revisión B cuadro a cuadro** de piezas finales o para cliente | **Fable 5.2** | Detectar defectos de medio segundo es razonamiento visual fino |
| Revisión B de pruebas internas | Opus 5.5 | Suficiente para descartar |
| Extraer cuadros, inventario, descargar y ordenar archivos | Haiku 5.5 | Mecánico |
| Montaje, textos, audio y render con el MCP `video-post` según un plan ya aprobado | Sonnet 5.5 | Ejecutar un plan definido |
| Motion graphics por código (Remotion, textos animados, tarjetas) | Opus 5.5 | Código normal de interfaz |
| **3D** (three.js, escenas, objetos anclados con MediaPipe) | **Fable 5.2** | Su punto más fuerte frente a Opus |
| Manejar interfaces web complejas (Flow, Higgsfield) con el navegador | Opus 5.5; Fable 5.2 si falla dos veces | Uso del computador |
| Investigación semanal de novedades | Opus 5.5 | Buscar, verificar y resumir |

**Lote para una prueba gratis por tiempo limitado (p. ej. 72 h de Higgsfield):** todo el plan y la revisión A en Fable **antes** de activar la prueba; durante la prueba, la generación la conduce Opus y la revisión B de lo que se va a quedar la hace Fable.
