# Assets de consistencia: fichas de personaje, objeto y entorno

La consistencia es el problema número uno del video con IA: si el personaje cambia entre tomas, el resultado deja de verse profesional. La solución es crear las referencias como imágenes **antes** de tocar el video.

## Los 3 métodos de generación (de menos a más control)
1. **Texto → video:** el modelo decide todo. Solo para explorar ideas.
2. **Imagen → video:** la imagen es el primer cuadro (first frame); controlas qué aparece.
3. **Referencias → video:** subes fichas (personaje, objeto, entorno) a un modelo omni/multireferencia y genera escenas con distintos ángulos manteniendo coherencia. El más poderoso.

## Personaje
1. Imagen base, de pies a cabeza, fondo blanco neutro, luz de estudio, terminando en "fotorrealista":
```
[Descripción física: edad, rasgos, cabello, complexión], vistiendo [vestuario detallado], de pie, vista de pies a cabeza, fondo blanco neutro, iluminación de estudio suave, fotorrealista.
```
2. Genera varias versiones y elige la más fiel a la visión.
3. **Character sheet** a partir de la elegida:
```
Usando esta imagen como referencia exacta, crea un character sheet del mismo personaje sobre fondo blanco: vista frontal de cuerpo completo, perfil izquierdo, perfil derecho, vista de espalda, y un primer plano del rostro y otro del detalle del vestuario. Mantén idénticos rostro, proporciones, peinado, vestuario y colores. Fotorrealista, luz de estudio uniforme.
```
Tip: dictar la descripción por voz es más rápido que escribirla.

## Objeto / producto
- Si existen fotos reales del producto, son la referencia principal: no lo inventes. El cliente necesita ver **su** producto.
- Si no existe (concepto), genéralo sobre fondo blanco, fotorrealista, y conviértelo en **object sheet** (frente, laterales, detalle de materiales) con el mismo prompt adaptado.

## Imagen madre: producto con texto en el set
Cuando el producto tiene etiqueta, logo o nombre, no generes cada toma por separado: cada generación nueva es una oportunidad de que la IA cambie letras. Genera **una** imagen del producto ya colocado en el set, apruébala y deriva de ella todo lo demás.

1. **Genera** con referencias: la foto real del producto + la imagen del entorno, en un modelo de imagen con buena fidelidad (p. ej. Nano Banana Pro). Prompt base:
```
Coloca exactamente este frasco (primera imagen) sobre [superficie] en esta escena (segunda imagen). Vista frontal, cámara a la altura de la etiqueta, el frasco ocupa cerca del 45 % del ancho del cuadro, centrado. La etiqueta y todo su texto se mantienen idénticos a la foto original, nítidos y legibles. Espacio libre arriba para texto. [Luz y ambiente de la dirección visual]. Fotorrealista.
```
2. **Encuadre que protege el texto:** de frente, a la altura de la etiqueta, grande (~40–50 % del ancho). Tres cuartos o picado deforman las letras; producto pequeño se emborrona a 720p.
3. **Pide 2 o más variantes** y revisa cada una **al tamaño original** (el que recibe el modelo de video, p. ej. 1K), no la versión reescalada, que puede corregir o inventar letras distintas. Compara letra por letra contra la foto real, incluidos apóstrofes, tildes y signos.
4. **Deriva por edición** sobre la imagen madre aprobada, cambiando solo una cosa: versión oscura (para transiciones de luz), plano de detalle, versión con humo. Repite el QA de texto en **cada** derivada: una edición de luz puede borrar un apóstrofe ("BADE'E" → "BADEE").
5. **Guarda las versiones aprobadas** donde la plataforma de video pueda usarlas como cuadros (en Flow: seleccionar la versión correcta y "Guardar en Proyectos"; guarda la versión seleccionada, no la que tienes bajo el cursor).

## Fotos reales dentro de un set generado
- Logos pequeños, grabados o en relieve (tapas, sellos): la IA no los reproduce bien. Usa la foto real con zoom lento en postproducción.
- La foto real debe compartir fondo y luz con el set: si el set es oscuro, fotografía el producto sobre tela negra con una sola luz lateral. Un fondo blanco junto a tomas oscuras rompe la pieza.

## Entorno
Describe lugar, hora del día, luz, clima y elementos de fondo. Es el ingrediente que más suele necesitar ajustes.

## Componer una escena
Sube las **fichas** (no las imágenes sueltas) + la imagen del entorno y describe la escena: acción, plano y luz. Itera si el personaje sale haciendo otra acción o demasiado lejos para reconocer el rostro.

## Personas reales y menores
- Para un adulto (con su consentimiento), las fotos reales sirven como referencia para fichas, muñecos, versiones animadas, etc.
- Google (Flow, Nano Banana, Veo) bloquea por política transformar fotos reales de menores, también en estilo muñeco o animado, y no cobra el intento. TikTok elimina contenido sintético con la imagen de menores. Alternativas: la foto real sin transformar dentro del montaje (p. ej. al inicio y al cierre) o un personaje inventado que la represente sin ser su retrato (p. ej. una conejita de juguete "La Jefa").
- Revisa en cada imagen generada detalles inventados que no están en la referencia (tatuajes, lunares, accesorios) y corrígelos con una edición antes de animar.

## Personaje recurrente de marca
Para una vocera o mascota que aparece en muchos videos: guarda su character sheet aprobado y su descripción textual canónica como asset fijo y reutilízalo en cada producción. Cambiarla entre videos destruye el reconocimiento de marca.
