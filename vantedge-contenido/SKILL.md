---
name: vantedge-contenido
description: Crea estados de WhatsApp, posts y reels de Vantedge con su marca, voz, formato y reglas de publicación. Úsala siempre que Brando pida estados, contenido o videos para Vantedge.
---

# Contenido de Vantedge (estados, posts y reels)

Vantedge Technologies es la agencia de Brando en Cali: automatiza el trabajo manual de pymes (atención por WhatsApp, Instagram y Messenger con aprobación humana, pedidos que entran solos al Excel/Sheets/CRM, cobros, reportes, agenda, publicaciones) y hace desarrollos a la medida (nunca se vende como "software").

## Fuente de la marca

- Kit de marca (design system): https://claude.ai/artifact/AkghJ1dqGCDcQRn1w7DQQv — en claude.ai, léelo (`project/README.md` y `project/tokens.json`) antes de diseñar. Si algo de aquí lo contradice, manda el kit.
- Lienzo de estados: https://claude.ai/artifact/LQTF61fHqLhnAo4GhT7KoQ — las semanas nuevas se agregan como una fila nueva en este mismo lienzo (tipo Design), no en un lienzo nuevo, salvo que Brando lo pida.
- Logos: grupo "Logos" del kit (vertical, horizontal, símbolo). En un lienzo nuevo, cópialos como assets desde el kit. En Claude Code, pide a Brando la ruta local de los PNG.

## Voz

- Lema fijo: **Automatiza lo que te quita el día.**
- Gancho del producto estrella: **Ni un cliente en visto.**
- Cierre (CTA): Escríbenos y te decimos qué se puede dejar en automático.
- Español colombiano neutro, de tú. Nada de voseo ni caleñismos ("mirá ve", "oís").
- La primera línea es SIEMPRE el dolor del dueño con sus palabras ("¿precio?", "en visto", "pasar los pedidos al Excel", "copiar y pegar", "pegado al celular"). La marca va al cierre.
- El trabajo manual de hoy NO es el papel ni el cuaderno: es copiar del chat al sistema (Excel, Google Sheets, app de facturación, CRM). Nunca se le pide al cliente cambiar de herramienta: lo que llega al chat entra solo a su sistema.
- Una sola herramienta por pieza (Excel en una, CRM en otra), nunca la lista completa.
- Prohibido: impulsa, transforma, potencia, revoluciona, conecta soluciones, soluciones, innovación, transformación digital, "el futuro que imaginas", "vende mientras duermes", "lleva tu negocio al siguiente nivel", "IA" o "software" como gancho, cualquier cosa que suene a reemplazar empleados.
- Sin cifras inventadas: usa [TOTAL], [N], [PRODUCTO] o datos reales de Brando. Nombres, facturas y montos ilustrativos llevan la etiqueta "Ejemplo".

## Sistema visual

- Fondo `#050A18` con retícula de puntos (`radial-gradient(rgba(255,255,255,0.09) 2px, transparent 2.5px)`, paso 48 px).
- Texto `#F2F5F9`; secundario `#9AA4B5`; superficies `#0D1628`; vidrio `rgba(255,255,255,0.06)` con borde `rgba(255,255,255,0.14)`.
- Azul `#0094F5` = la solución. UN solo resaltado azul por pieza (palabra clave, lema o botón). Cian `#00D0F8` y azul profundo `#0062F5` solo para detalles y el degradado del logo.
- Naranja `#FF7A45` = el problema (el "antes", la parte dolorosa del gancho). Nunca para el lema ni la solución.
- Tipografía: Space Grotesk 700 para ganchos y cierres; Inter para apoyo. Etiquetas en mayúsculas, 26 px, espaciado 0.08em.
- Esquinas: tarjetas 32 px, botones 16 px, etiquetas 8 px.
- Sin laptops con código, nubes, engranajes, robots, degradados morados ni emojis. Íconos de línea simples, solo si aclaran el caso.
- El logo SIEMPRE dice "VANTEDGE" completo junto al símbolo; nunca el símbolo haciendo de "V". Foto de perfil = solo el símbolo.

## Estado de WhatsApp (imagen)

- Lienzo 1080×1920. Márgenes: 260 px arriba y abajo libres (ahí WhatsApp pone el nombre, la barra y la caja de respuesta), 96 px a los lados.
- Estructura de tres bloques:
  1. **Gancho** (96–112 px, máx. 8–10 palabras), con la parte dolorosa en naranja.
  2. **Cómo se resuelve**: una maqueta concreta (chat, ficha de CRM, notificación, antes/ahora) o lista corta.
  3. **Cierre**: línea divisoria, frase de cierre (60–64 px) con el resaltado azul, logo horizontal (72 px de alto) y botón visual "Escríbenos".
- Cada estado lleva un **texto al publicar** con una palabra clave para responder (VISTO, EXCEL, CRM, COBROS, REPORTE…). Esa palabra mide qué gancho funciona. Ponlo como nota debajo del artboard.

## Mezcla semanal (7 estados, uno por día)

- 40 % servicio (un caso concreto de automatización), 30 % prueba real (grabación de pantalla del agente o capturas de trabajos reales, sin datos de clientes), 20 % dolor o tip, 10 % persona (Brando en cámara o Valeria).
- Incluye al menos una pieza de interacción (encuesta numerada, pregunta) y cierra la semana con el lema.
- Temas para rotar: clientes en visto, pedidos al Excel, chat al CRM, cobros, reporte de ventas, cotizaciones, agenda de citas, publicaciones en redes, documentos y facturas.
- Público amplio, sin nicho fijo: el gancho habla del dolor universal y los ejemplos rotan de sector (ferretería, droguería, consultorio, taller, tienda de ropa, restaurante, construcción…) para que cada contacto se vea en alguno. Nunca dos estados seguidos del mismo sector. Si un ejemplo no necesita sector, usa uno genérico ("¿tienen disponible? ¿cuánto vale?").
- No repitas un gancho ya publicado; revisa las filas anteriores del lienzo.
- Si no hay material de prueba real, no lo inventes: deja el hueco y pídeselo a Brando.

## Reels y videos cortos

- 9:16, 1080×1920, H.264, 30 fps, ~4 Mbps. 15–30 s (WhatsApp permite hasta 90 s por estado).
- Estructura: 0–3 s gancho en pantalla (texto grande), demostración, cierre con lema + logo + palabra clave.
- Subtítulos grandes quemados siempre: la mayoría mira sin sonido.
- Prioriza grabaciones reales de pantalla del agente sobre video generado.
- Herramientas: Remotion o FFmpeg (NVENC en la PC con GPU) para armar; HeyGen + voz colombiana de ElevenLabs para Valeria cuando haya plan pago; creative-architect + Higgsfield para generación. Valeria se presenta como "la asistente IA de Vantedge", nunca como persona real.
- Nunca auto-aprobar herramientas que gastan créditos; antes de generar, di cuántas generaciones vas a hacer.

## Publicación

- Los estados se publican a mano desde el celular: no existe API oficial para Estados. Nunca uses APIs no oficiales (Baileys, Evolution, WAHA, Whapi), porque arriesgan el número.
- El estado de WhatsApp se reenvía solo a historias de Facebook e Instagram desde el Centro de cuentas de Meta. Los reels se suben además como Reels nativos.

## Flujo de trabajo

1. Confirma tema y cantidad (el público es amplio: pymes de cualquier sector en Cali). Si Brando no lo dice, propón la semana según la mezcla y la rotación de sectores.
2. Muestra primero los ganchos y el texto al publicar de cada pieza y espera su aprobación antes de diseñar.
3. Diseña con el sistema visual de arriba, en el lienzo de estados (o en HTML 1080×1920 renderizado a PNG en Claude Code).
4. Revisa antes de entregar: el gancho empieza por el dolor, hay un solo resaltado azul, ninguna palabra prohibida, márgenes de 260 px libres, logo con "VANTEDGE" completo, cifras como placeholder o "Ejemplo", palabra clave en el texto al publicar.
5. Entrega con una tabla corta día → gancho → palabra clave, y di qué falta (datos reales, grabaciones).
6. Después de una semana publicada, pregunta cuántas respuestas trajo cada palabra y usa la ganadora para orientar la semana siguiente.
