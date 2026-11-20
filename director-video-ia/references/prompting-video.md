# Prompts de video por etiquetas

Un prompt corto deja huecos y el modelo los llena a su criterio (cámara rara, acción plana, ambiente equivocado). Un prompt ordenado en bloques le habla de una cosa a la vez y reduce la improvisación.

## Las etiquetas
| Etiqueta | Qué describe | Errores comunes |
|---|---|---|
| `CHARACTER` | Quién está, cómo se ve, cómo se mueve, estado emocional (emocionado, tranquilo, asustado; camina despacio, corre) | Solo el nombre, sin comportamiento |
| `ENVIRONMENT` | Lugar, hora del día, luz, clima, sensación | Tratarlo como decorado |
| `STORYLINE` | Acción concreta y su progresión (corre → salta al borde → golpe) | Una acción vaga ("corre") |
| `AESTHETIC` | Look (cinematográfico, natural, saturado o no), paleta hex, lente, movimiento y velocidad de cámara | Olvidar la cámara |
| `ACTION SEQUENCE` | Solo modelos multishot: planos en orden dentro de una generación | Usarlo en modelos de un solo plano |
| `NEGATIVE` | Lo que no debe aparecer. Formato por modelo: **Veo** sustantivos sin "no" (`text, logos, extra fingers`); **Runway** no admite negativos, describe solo lo que debe aparecer; **Kling** artefactos concretos (`sliding feet, morphing`) | No ponerlo y que salga texto o manos deformes; escribir "no hands" en un modelo que lee la palabra y la dibuja |

Si hay first frame o fichas de referencia, `CHARACTER` y `ENVIRONMENT` pueden ser más cortos (la imagen ya los define) y el peso pasa a `STORYLINE` y `AESTHETIC`. Si el storyboard ya está en la imagen de referencia, basta un prompt breve que pida seguir los paneles y mantener consistencia con las fichas.

## Plantilla en texto
```
[CHARACTER]
…
[ENVIRONMENT]
…
[STORYLINE]
…
[AESTHETIC]
… Cámara: … Paleta: #…, #…
[NEGATIVE]
no text, no watermark, no logos, no subtitles, [no people / no hands si es solo producto], no music
```

## Plantilla en JSON (modelos que aprovechan prompts estructurados)
```json
{
  "character": "…",
  "environment": "…",
  "storyline": "…",
  "aesthetic": {"look": "…", "palette": ["#…", "#…"], "camera": "…", "lens": "…"},
  "action_sequence": [
    {"shot": "plano general", "action": "…"},
    {"shot": "primer plano", "action": "…"}
  ],
  "audio": {"dialogue": "…", "sfx": "…", "music": false},
  "negative": ["text", "watermark", "logos"]
}
```

## Ejemplo — producto (ferretería, imagen→video)
```
[STORYLINE] El taladro inalámbrico reposa sobre el banco; la luz se intensifica sobre el mandril mientras partículas de aserrín flotan en el haz. El mandril gira dos vueltas y se detiene.
[AESTHETIC] Comercial cinematográfico, contraste alto, colores sobrios. Dolly in lento desde plano medio a detalle del mandril, 5 s. Luz lateral dura de ventana, tarde. Paleta #1C1C1C, #E8A33D, #C9C2B6.
[NEGATIVE] text, logos, watermark, hands, people, music
```

## Ejemplo — UGC con diálogo (imagen→video)
```
[CHARACTER] La mujer de la imagen, emocionada pero natural, habla a la cámara del celular que sostiene con el brazo derecho, gesticula con la mano libre.
[ENVIRONMENT] Su sala, tarde, luz de ventana.
[STORYLINE] Dice en español colombiano, con energía: "Les juro que no sabía que esto existía. Mírenlo." y gira levemente el teléfono hacia el producto en la mesa.
[AESTHETIC] Video vertical grabado con celular, leve movimiento de mano, sin look de estudio.
[NEGATIVE] text, subtitles, logos, music, distorted hands
```

## Productos con texto: patrones de primer y último cuadro
Cuando el modelo admite primer y último cuadro (p. ej. Veo en Flow, "Fotogramas"), úsalos para que el producto no tenga que ser reinventado. Probado con Veo 3.1 Fast: si las imágenes de entrada tenían la etiqueta correcta, el video la conservó.

**Transición de luz** (revelación): primer cuadro = versión oscura de la imagen madre; último cuadro = imagen madre iluminada.
```
La luz cálida de un farol entra lentamente desde la izquierda y recorre el frasco hasta iluminar por completo la etiqueta. El frasco y su etiqueta permanecen inmóviles y sin cambios. Cámara fija. Partículas de polvo en el haz de luz. Comercial de lujo, contraste alto.
NEGATIVE: text changes, camera rotation, new objects, music
```

**Producto inmóvil** (plano héroe): la misma imagen como primer **y** último cuadro.
```
Humo denso sube lentamente desde la base y envuelve el frasco sin cubrir la etiqueta. Un destello suave recorre el vidrio. El frasco y su etiqueta permanecen inmóviles y sin cambios. Cámara fija con un leve dolly in.
```

Reglas:
- Escribe siempre "el producto y su etiqueta permanecen inmóviles y sin cambios".
- El movimiento lo dan la luz, el humo, las partículas y el foco. Evita órbitas, giros del producto o paneos amplios: cada ángulo nuevo obliga a inventar la etiqueta.
- Si una toma sin cuadros sale casi estática, pide el movimiento de forma explícita y medible ("dolly in lento de plano medio a detalle", "la llama crece").

## Transición por logo u objeto (dos tomas en un solo movimiento)
Une dos tomas distintas con un movimiento continuo de cámara a través de un objeto (logo, emblema, rueda, letra). Visto en reels de Keanu Visuals con Seedance 2.5 (nov 2026); funciona con cualquier modelo que acepte primer y último cuadro (Veo en Flow, Seedance, Kling).
- **Primer cuadro:** el final de la toma A (captura del video o foto). **Último cuadro:** el inicio de la toma B.
- **Prompt:** describe el recorrido de la cámara (p. ej. retrocede atravesando el emblema), qué hace el objeto (entra al cuadro, gira y encaja en su lugar), un giro de cámara (roll) suave y una aceleración (speed ramp) en el medio.
```
The camera pulls backward through the chrome emblem as it flies into frame, rotates a half turn and snaps into place on the car grille, revealing the second shot. Smooth camera roll, speed ramp: fast in the middle, slow at the end. One continuous movement. Audio: whoosh at the speed ramp, no music.
```
- Mismo formato (relación de aspecto) y calidad que el material original para que el empalme no se note.
- El auditor revisa el cuadro de unión: el objeto no debe deformarse ni cambiar de forma al llegar.

## Parámetros por toma
- Relación de aspecto: 9:16 (Reels/TikTok) o 16:9.
- Duración: 3–6 s para comerciales cortos; el límite real depende del modelo.
- Resolución: 720p para pruebas; 1080p/4K solo en la versión aprobada (el costo en créditos puede triplicarse).
- Audio: actívalo solo si la toma lleva voz/SFX del modelo; si la música va en post, pide `no music`.

## Acciones con contacto entre objetos
Los modelos de video confunden los límites entre objetos que se tocan: un vaso se funde con el helado cuando entra la cuchara, un objeto desaparece de la mano al morderlo, un borde queda deformado el resto de la toma. Probado con Veo 3.1 Fast (muñeco comiendo helado con cuchara, nov 2026).
- **Evita el contacto en el diseño:** en lugar de "mete la cuchara al vaso y come", "la cuchara deja caer una bola de helado sobre la mesa y él se lanza a comerla". Nada entra al recipiente y el personaje no sostiene nada.
- **Fija el final:** usa primer y último cuadro, con el último mostrando el resultado limpio (vaso intacto, personaje con el helado en la cara). El modelo ya no tiene que inventar cómo quedan los objetos.
- **Escríbelo explícito:** "el vaso de vidrio es sólido y permanece intacto y sin cambios", "no aparecen ni desaparecen objetos".
- Si un objeto tiene que ir en la mano, que lo tenga desde el primer cuadro y lo conserve hasta el último.
- **El último cuadro debe coincidir con el encuadre final.** Si el prompt pide un acercamiento (push-in) pero el último cuadro está más abierto, el modelo acerca y al final "salta" hacia atrás para llegar a ese cuadro. Usa cámara fija, genera el último cuadro ya con el encuadre cerrado, o recorta el último segundo en postproducción.
- **Da el tamaño de lo que cae o se sirve** ("una bola del tamaño de su cabeza"): sin eso el modelo puede hacerla gigante.

## Cómo iterar el prompt
Cambia una variable a la vez y di exactamente qué falló ("salta en vez de correr", "el rostro queda muy lejos") en lugar de reescribir todo.
