# Edición de footage existente y B-roll

## Modificar video sin regrabar
Con modelos de edición de video se toma un clip real y se reescribe: fondo/entorno, iluminación, vestuario, objetos (añadir o quitar). Muy útil para pymes: grabas algo simple con el celular y lo conviertes en una escena producida.

### Método A — Solo prompt
```
Modifica este video: [cambio 1], [cambio 2]. Mantén idénticos el rostro, el movimiento, el ángulo de cámara y el audio.
```

### Método B — First frame editado como guía (más control)
1. Extrae el primer cuadro del video (`ffmpeg -i in.mp4 -frames:v 1 frame0.png`).
2. Edita esa imagen con un modelo de imagen hasta que se vea como quieres.
3. Sube video original + imagen editada:
```
Transforma este video siguiendo la imagen de referencia: [nuevo entorno/vestuario/luz]. Conserva idénticos rostro, peinado, accesorios y ángulo de cámara. Fotorrealista, cinematográfico, sin apariencia CGI.
```
4. Ajusta en la misma conversación si el modelo lo permite.

### VFX con acciones simples
Graba una mímica (un control en la mano) → edita el first frame (varita mágica, otro vestuario, otro mundo) → prompt de video que aplica ese estilo al clip. Descarta las variantes que se vean saturadas o con look CGI: tu criterio decide qué es "AI slop" para el contexto.

## B-roll
B-roll = planos de apoyo que muestran lo que el audio describe. Antes requería camarógrafo, locación o stock; ahora se genera a la medida.

### Del guion al B-roll
1. Recorre el guion frase por frase: ¿qué imagen implícita carga cada frase? ¿qué emoción?
2. Decide por frase:
   - **Transformar al presentador** (cambia el escenario pero conserva a la persona y el audio) cuando la frase necesita su presencia.
   - **Imagen animada** para el gancho (p. ej. la cámara se aleja desde la persona hasta mostrar la escala de lo que dice).
   - **B-roll puro** cuando la voz ya cuenta la historia: planos sin presentador.
3. Detalles que elevan: un leve temblor de cámara cuando el guion habla de vibración, un alejamiento cuando habla de distancia. El movimiento de cámara debe "dibujar" la idea.

Para B-roll sin personajes específicos (paisajes, procesos, animales, ambientes) casi cualquier modelo funciona: prioriza costo y velocidad.

### Ejemplo para pyme
Guion de ferretería: "¿Cansado de que la broca se parta a la mitad del trabajo?" → B-roll: plano detalle de broca barata partiéndose en cámara lenta, luz lateral dura. "Con esta, perforas concreto sin esfuerzo" → producto real (first frame de foto del cliente) perforando, dolly in al mandril.
