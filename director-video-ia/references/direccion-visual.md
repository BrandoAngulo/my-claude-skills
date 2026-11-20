# Dirección visual: moodboard y estilo

## Por qué importa
Sin dirección, el modelo entrega su "promedio": la estética que todos reconocen como generada por IA. El moodboard le da una dirección específica en un idioma que entiende mejor que los adjetivos vagos ("elegante", "premium").

## Moodboard en 4 pasos
1. **Sensación primero, producto después.** Antes de buscar imágenes, define 3–5 palabras de lo que debe sentir quien ve el video. Ej. reloj: precisión, calma, naturaleza, elegancia.
2. **Referencias que respiren esa sensación** (mínimo 6). No tienen que mostrar el producto: texturas, materiales, paisajes, interiores, iluminación, paletas. Fuentes: Pinterest (paletas, texturas), Behance/Dribbble (diseño profesional), Instagram/YouTube (tendencias, estética real).
3. **Prueba de encaje:** imagina el producto al lado de las referencias. Si encaja natural en color, textura y sensación, el moodboard es coherente. Si desentona, ajusta.
4. **Extraer a prompts:** con el moodboard como imagen, extrae elementos, texturas, emociones y paleta, y genera 8–10 prompts distintos del producto en ese universo. Elige los 2–3 mejores e itera sobre ellos pidiendo cambios concretos ("más textura en la correa"), no regenerando a ciegas.

### Plantilla de extracción
```
Analiza este moodboard. Extrae: (1) paleta con códigos hex, (2) texturas y materiales, (3) tipo de luz, (4) emociones que transmite.
Con eso, genera 10 prompts distintos de imagen para [producto] con [rasgos del producto], sobre fondo simple coherente con la estética. Fotorrealista. Varía composición, ángulo y fondo entre prompts.
```

## Estilo visual
El estilo es parte del mensaje: el mismo personaje en pixel art se siente nostálgico; en fotorrealismo, serio; en acuarela, poético. Opciones: fotorrealista, cinematográfico, 3D, cine clásico, anime, stop motion, pixel art, concept art, ilustración plana, acuarela.

Para comerciales de pymes el default razonable es fotorrealista/cinematográfico, salvo que la marca ya tenga un estilo gráfico propio.

## Style extractor
Sirve para llevar el estilo de cualquier imagen a otra (o a una descripción nueva) con consistencia.
```
Analiza el estilo visual de esta imagen y descríbelo como un prompt reutilizable: tipo de ilustración/render, paleta (hex), saturación, contraste, texturas (grano, trazo), tipo de luz, nivel de detalle. No describas el contenido, solo el estilo.
Termina con: "Aplica exactamente este estilo a: [SUJETO]".
```
- Con referencia: sube la imagen + este prompt; luego usa el resultado junto a tu personaje/objeto.
- Sin referencia: reemplaza solo `[SUJETO]` manteniendo el bloque de estilo — así generas imágenes distintas con estética coherente.
- No copies un estilo tal cual: úsalo como base y modifícalo hasta que sea propio.

## Salida de la fase
```
Sensación: …
Paleta: #…, #…, #…
Texturas/materiales: …
Luz: …
Estilo: …
Referencias: [lista o descripción]
```
