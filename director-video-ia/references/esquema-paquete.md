# Esquema del paquete de producción (modo pipeline)

Entrega un solo objeto JSON válido. Los campos vacíos van como `null` o `[]`, nunca se omiten, para que el flujo de n8n no rompa. El ejemplo completo está en `assets/ejemplo-paquete.json`.

```json
{
  "version": "1.0",
  "proyecto": {
    "cliente": "string",
    "vertical": "string",
    "objetivo": "string — acción que debe tomar quien ve el video",
    "dolor": "string",
    "plataforma": "reels|tiktok|youtube|otro",
    "aspect_ratio": "9:16|16:9|1:1",
    "duracion_total_s": 0,
    "idioma": "es-CO"
  },
  "direccion_visual": {
    "sensacion": ["string"],
    "paleta_hex": ["#000000"],
    "texturas": ["string"],
    "luz": "string",
    "estilo": "string"
  },
  "guion": {
    "narrativo": "string",
    "dialogos": [{"personaje": "string", "texto": "string"}]
  },
  "assets": [
    {
      "id": "char_01",
      "tipo": "personaje|objeto|entorno",
      "nombre": "string",
      "fuente": "generar|foto_real",
      "prompt_imagen": "string|null",
      "prompt_sheet": "string|null"
    }
  ],
  "tomas": [
    {
      "n": 1,
      "duracion_s": 4,
      "plano": "string",
      "angulo": "string",
      "camara": "string",
      "accion": "string",
      "metodo": "txt2video|img2video|ref2video|edicion|broll",
      "referencias": ["char_01"],
      "prompt_first_frame": "string|null",
      "modelo": {"principal": "string", "alternativa": "string", "razon": "string"},
      "prompt_video": {
        "character": "string|null",
        "environment": "string|null",
        "storyline": "string",
        "aesthetic": "string",
        "action_sequence": [],
        "negative": ["string"]
      },
      "audio": {"dialogo": "string|null", "sfx": "string|null", "musica_del_modelo": false},
      "resolucion_prueba": "720p",
      "resolucion_final": "1080p",
      "qa_puntos_criticos": ["string"]
    }
  ],
  "postproduccion": {
    "orden_montaje": [1],
    "musica_prompt": "string|null",
    "capa_texto": [{"toma": 1, "texto": "string", "tipo": "logo|precio|cta|subtitulo|otro"}],
    "lut_o_color": "string|null"
  },
  "supuestos": ["string — decisión tomada sin preguntar"],
  "pendientes_aprobacion": ["string — lo que un humano valida antes de gastar créditos"]
}
```

## Reglas
- `tomas[].referencias` apunta a `assets[].id`.
- `capa_texto` contiene **todo** texto visible del video; ningún `prompt_*` debe pedir texto en pantalla.
- `pendientes_aprobacion` siempre incluye como mínimo: aprobación de assets y de first frames antes de generar video.
