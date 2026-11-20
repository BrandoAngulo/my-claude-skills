# QA y postproducción

Casi ningún video sale bien a la primera. El trabajo es probar, mirar con criterio, ajustar y repetir. Esta guía hace ese criterio explícito y repetible.

## Checklist por toma (revisar cuadro a cuadro)
- [ ] **Manos:** número de dedos, forma, agarre del producto.
- [ ] **Rostro:** sin deformaciones, ojos coherentes, consistente con el character sheet.
- [ ] **Bordes y fondo:** sin objetos que aparecen/desaparecen, sin derretimientos.
- [ ] **Texto fantasma:** letras inventadas en carteles, empaques o pantallas.
- [ ] **Integridad de objetos en contacto:** en cada momento en que dos objetos se tocan (utensilio y recipiente, mano y objeto, líquido y vaso) extrae cuadros cada 0.5 s desde un segundo antes hasta un segundo después. Busca recipientes que se funden con su contenido, objetos que desaparecen de la mano y bordes que quedan "mordidos" el resto de la toma. Si el defecto sigue hasta el final, recortar no sirve: regenera con primer y último cuadro.
- [ ] **Texto del producto al 100 %:** antes de animar, revisa cada imagen de entrada (madre y derivadas) al tamaño original, letra por letra contra la foto real, incluidos apóstrofes y tildes. Después, extrae cuadros del video donde la etiqueta se ve más grande y repite la comparación.
- [ ] **Producto:** fiel al real (forma, color, proporciones). Si el cliente no lo reconoce, la toma no sirve.
- [ ] **Acción:** hace lo que pide el `STORYLINE`, en orden.
- [ ] **Cámara:** el movimiento pedido, sin saltos raros.
- [ ] **Voz (si aplica):** pronunciación correcta, sin palabras deformadas, energía acorde al tono, labios sincronizados.
- [ ] **Estética:** encaja con el moodboard y la paleta; no se ve saturado ni CGI.

## Qué cambiar según el defecto
| Defecto | Primera corrección | Si persiste |
|---|---|---|
| Personaje distinto entre tomas | Usar character sheet como referencia (ref→video) | Modelo omni/multireferencia |
| Acción equivocada | Hacer `STORYLINE` más concreto y secuencial | Partir la toma en dos |
| Cámara rara | Especificar movimiento, dirección y velocidad | First frame con el encuadre final deseado |
| Manos deformes | Sacar manos del plano o `NEGATIVE` | Encuadre que no las muestre |
| Texto basura | `NEGATIVE: no text`; quitar superficies con letras | Limpiar en post o recortar |
| Pronunciación | Simplificar la frase, evitar nombres raros | Otro modelo o voz en off en post |
| Look genérico | Volver a dirección visual: paleta hex, luz, referencias | Style extractor |
| Producto no fiel | Usar foto real como first frame | Plano más corto o más lejano |

Regla de costos: corrige en la imagen si el problema ya está en el first frame; solo regenera video cuando la imagen esté aprobada. Prueba en 720p.

## Postproducción
1. **Montaje:** ordena las tomas de lo general al detalle; cierra con producto + CTA.
2. **Música:** instrumental generada (género, instrumentos y mood derivados del moodboard; sin voces si hay diálogo). Genera varias, no te quedes con la primera.
3. **Ritmo:** escucha la pista antes de cortar; corta en golpes de tambor, cambios de acorde o pausas. Ahí el corte "se siente bien". En pipeline: mide los golpes (energía/onsets y tempo), lista sus segundos y ajusta la duración de cada toma para que la suma acumulada caiga en ellos. Comprueba el resultado con detección de cortes: los cortes deben coincidir con los golpes a ±1 cuadro.
4. **SFX y micro-movimiento:** sonidos de producto, zooms sutiles.
5. **Capa de texto (siempre en post, nunca generada):** logo, nombre del negocio, precio, oferta, subtítulos, CTA, datos de contacto/WhatsApp. Ubícala después de mirar cuadros de cada toma: nunca encima de la etiqueta del producto. Si el producto ocupa el centro, apila nombre y CTA en la zona libre (p. ej. ambos arriba, el CTA debajo del nombre).
6. **Color:** LUT o corrección de color por marca/vertical para unificar tomas de distintos modelos.
7. **Exportar:** 1080p mínimo, en la relación de aspecto de la plataforma. Para redes, entrega **dos versiones**: sin audio (la música se pone dentro de la app) y con música licenciada.

En pipeline, los pasos 3–7 son automatizables (FFmpeg: concatenación, overlay de texto/logo, LUT, mezcla de audio); el criterio de los pasos de QA sigue siendo humano. Con el MCP `video-post`: `inventario` → `extraer_cuadros` (QA) → `zoom_foto` → `montar` → `texto_y_logo` → `audio` → `render`, encadenando siempre la ruta de salida que devuelve cada herramienta (si el nombre ya existe crea una versión -2, -3…).

## Licencias de música
Verifica la licencia vigente antes de publicar; esto es orientación, no asesoría legal.
| Fuente | Uso comercial | Cuidado |
|---|---|---|
| Pixabay Music | Sí, sin atribución | Algunas pistas generan reclamos de Content ID; descarga el certificado de licencia de la pista por si hay que disputarlos |
| YouTube Audio Library | Depende de cada pista | Revisa si pide atribución |
| Sonidos dentro de TikTok / Instagram | Solo dentro de la app | Cuentas personales: biblioteca general. Cuentas de empresa: solo Commercial Sounds (TikTok) o Meta Sound Collection. Para anuncios pagados se necesita licencia comercial |
| Suno (plan gratis) | No | Para uso comercial se necesita plan de pago |

Por eso las dos versiones: la versión sin audio deja usar los sonidos de la app (respetando el tipo de cuenta) y la versión con música lleva una pista con licencia comercial clara.
