# Catálogo de riesgos (revisión A)

Cada riesgo: **señal** en el plan, **pregunta** al creador y **mitigaciones aceptables**. Riesgo alto sin mitigación aceptable → CORREGIR o NO GENERAR.

| # | Riesgo | Nivel | Señal en el plan | Pregunta al creador | Mitigaciones aceptables |
|---|---|---|---|---|---|
| 1 | Contacto entre objetos | Alto | Un utensilio entra a un recipiente, una mano agarra o suelta algo, se sirve un líquido, algo se muerde | ¿Por qué hay contacto si es donde más falla el modelo (vasos que se funden, objetos que desaparecen)? | Rediseñar la acción sin contacto; primer **y** último cuadro con el estado final limpio; el objeto en la mano desde el primer cuadro hasta el último; base real |
| 2 | Texto o logo del producto | Alto | Etiqueta visible, nombre, precio, empaque | ¿Revisaste cada cuadro de entrada al 100 % letra por letra? ¿Por qué se mueve la cámara alrededor del texto? | QA de texto en cada imagen de entrada; cámara fija o casi fija; texto en postproducción; foto real con zoom |
| 3 | Último cuadro distinto al final de la cámara | Alto | Prompt con push-in, paneo o dolly y último cuadro con otro encuadre | ¿Por qué el último cuadro está más abierto (o cerrado) que donde termina la cámara? | Cámara fija; último cuadro generado ya con el encuadre final; recorte planeado del último segundo |
| 4 | Duración o modo no soportado | Alto | Veo con duración distinta de 4/6/8 s; varios planos en un modelo de toma única; referencias en un modo que no las usa | ¿Comprobaste el límite del modelo para este modo? | Ajustar duración o modo; partir en dos tomas |
| 5 | Persona real menor de edad | Alto | Foto real de un menor como referencia o cuadro | ¿Sabes que Google bloquea transformar fotos reales de menores y TikTok elimina contenido sintético con su imagen? | Foto real sin transformar en el montaje; personaje inventado que no sea su retrato |
| 6 | Identidad entre tomas | Medio | El mismo personaje en varias tomas sin ficha o referencias | ¿Con qué ficha o referencia se mantiene la cara y la ropa? | Character sheet; mismas referencias en cada toma; modelo omni/multirreferencia |
| 7 | Detalles inventados en la referencia | Medio | Imagen generada a partir de una foto | ¿Comparaste la imagen generada con la foto real (tatuajes, lunares, accesorios, ropa con marcas)? | Edición para quitarlos antes de animar |
| 8 | Tamaño o escala sin definir | Medio | Algo cae, se sirve, aparece o crece | ¿De qué tamaño debe ser respecto al personaje? | Tamaño explícito en el prompt ("del tamaño de su cabeza") o en el último cuadro |
| 9 | Demasiadas acciones por toma | Medio | Más de un evento cada ~2 s o más de un movimiento de cámara cada dos golpes | ¿Por qué tantas acciones en 8 s? | Un evento por golpe; partir la toma |
| 10 | Negativos mal escritos para el modelo | Medio | "no hands", "don't…" en Veo; negativos en Runway | ¿El formato de negativos es el que pide este modelo? | Veo: sustantivos; Runway: solo lo que debe aparecer; Kling: artefactos concretos |
| 11 | Audio no especificado | Medio | Prompt sin línea de audio en un modelo con audio nativo | ¿Qué debe sonar? | Línea de audio explícita; "no music" si la música va en post |
| 12 | Física imposible sin intención | Medio | Objetos que atraviesan, cambios de escala, gravedad rara no buscados | ¿Es un efecto buscado o un hueco del prompt? | Describir la física en una frase; recortar; base real |
| 13 | Toma que la IA no necesita | Bajo | Texto animado, gráficos, contador, logo, foto de producto | ¿Por qué gastar créditos en algo que se hace por código o con la foto real? | Motion graphics por código; `zoom_foto`; `texto_y_logo` |
| 14 | Unión con la toma vecina | Bajo | Cambio de luz, escala, ropa o dirección de mirada entre tomas | ¿Cómo empalma con la anterior y la siguiente? | Mismo último/primer cuadro; misma luz y paleta; corte en golpe de música |
| 15 | Resolución final sin prueba barata | Medio | La primera generación de una toma nueva va directo en 1080p o 4K | ¿Por qué no probar primero en la resolución más baja si cuesta varias veces menos? | Prueba en 480p/720p; la resolución final solo para la toma aprobada (p. ej. Seedance 2.5: 30 créditos a 480p contra 120 a 1080p por 10 s) |

Si aparece un riesgo que no está aquí, agrégalo a la tabla al cerrar la auditoría (con aprobación del usuario).
