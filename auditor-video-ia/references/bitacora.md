# Bitácora de hallazgos

Una línea por hallazgo. Sirve para ver patrones por modelo y para justificar reglas nuevas. No borrar líneas; si una corrección deja de funcionar, agregar una línea nueva.

| Fecha | Modelo | Tipo de toma | Defecto | Causa | Corrección que funcionó |
|---|---|---|---|---|---|
| 2026-11-07 | Nano Banana Pro → Veo 3.1 Fast | Producto con etiqueta, transición de luz | Letras cambiadas ("GLORY" → "CLURY", "BADE'E" → "BADEE") que el video heredó | Imagen de entrada aprobada mirando la etiqueta en miniatura; derivada no revisada | QA de texto al 100 % en la imagen madre y en cada derivada antes de animar |
| 2026-11-08 | Nano Banana Pro | Muñeco a partir de foto real | Tatuajes inventados en los brazos | El modelo agregó detalles que no estaban en la referencia | Edición de imagen para quitarlos antes de animar |
| 2026-11-08 | Nano Banana Pro | Muñeco a partir de foto real de una menor | Bloqueado por política (sin cobro) | Google no transforma fotos reales de menores | Foto real sin transformar en el montaje; personaje inventado ("La Jefa") |
| 2026-11-08 | Veo 3.1 Fast | Muñeco sale de su empaque | Atraviesa el plástico en lugar de abrirlo | Acción de contacto (abrir blíster) sin último cuadro | Aceptado como menor en tono de humor; para producto real: último cuadro con el blíster abierto |
| 2026-11-08 | Veo 3.1 Fast | Miniatura con cuchara y vaso de helado | El vaso se funde con el helado al entrar la cuchara; la cuchara desaparece de la mano; borde del vaso "mordido" hasta el final | Contacto utensilio–recipiente y objeto en la mano sin último cuadro | Acción rediseñada (la cuchara deja caer la bola en la mesa) + primer y último cuadro con el vaso intacto |
| 2026-11-08 | Veo 3.1 Fast | Primer y último cuadro con push-in | Salto de cámara hacia atrás en el último medio segundo | Último cuadro más abierto que el acercamiento pedido | Recorte del último medio segundo; regla: el último cuadro debe tener el encuadre final |
| 2026-11-08 | Veo 3.1 Fast | Objeto que cae | La bola de helado salió casi del tamaño del vaso | Tamaño no especificado | Indicar el tamaño relativo en el prompt o en el último cuadro |
| 2026-11-08 | Revisión propia | QA cada 1.5 s | Defectos de 0.5 s no detectados | Muestreo demasiado espaciado y el creador se revisó a sí mismo | Muestreo cada 0.5 s (0.25 s en eventos) y auditor independiente |
