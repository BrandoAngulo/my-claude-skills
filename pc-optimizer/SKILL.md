---
name: pc-optimizer
description: Diagnostica y optimiza cualquier PC Windows. Detecta cuellos de botella de hardware (Windows en HDD, RAM en un canal, memoria comprometida, throttling, plan de energía), software que sobra (inicio, bloatware, servicios) y espacio recuperable (cachés de desarrollo, Docker, WSL, Ollama, ISOs). Entrega un plan por niveles de riesgo y solo ejecuta con aprobación. Usar cuando el usuario pida optimizar, acelerar, limpiar o diagnosticar un PC, o pregunte por qué un equipo está lento o sin espacio.
---

# PC Optimizer (Windows)

## Principios (no negociables)

1. **El diagnóstico es solo lectura.** Los 4 scripts no modifican nada: solo escriben su JSON.
2. **Nada se borra ni se cambia sin aprobación ítem por ítem.** Mostrar el comando exacto antes de ejecutarlo.
3. **Detectar, no asumir.** Cada script mide solo las herramientas que encuentra. Rutas siempre desde `$env:USERPROFILE`, `$env:LOCALAPPDATA`, `$env:APPDATA`.
4. **Primero hardware, después limpieza.** Un cuello de botella de hardware va primero en el reporte.
5. **Contexto antes de borrar.** Un artefacto de desarrollo (modelo, imagen, SDK, volumen) no es basura hasta confirmar que ningún proyecto lo usa. Lo que "no aparece" en la búsqueda sigue siendo **revisar**, nunca seguro.
6. **Funcionar sin admin.** Lo que necesita admin se lista en `requiere_admin`.

El criterio completo de qué es seguro, qué revisar y qué nunca tocar está en `references/reglas.md`. Leerlo antes de la Fase 5.

## Archivos

```
pc-optimizer/
├── SKILL.md
├── scripts/
│   ├── diagnostico.bat   ← corre los 4 scripts y guarda todo en ..\_resultados\
│   ├── hardware.ps1      ← Fase 1
│   ├── software.ps1      ← Fase 2
│   ├── disco.ps1         ← Fase 3a
│   └── dev-caches.ps1    ← Fase 3b + Fase 4 (referencias en proyectos)
└── references/
    ├── reglas.md         ← criterio de decisión (seguro / revisar / no tocar)
    └── bloatware.md      ← patrones de software marcado
```

Cada script devuelve un JSON con la misma estructura base: `hallazgos` (severidad, código, detalle, recomendación), `errores`, y según el caso `items` (con `nivel` y `accion`) y `requiere_admin`.

## Cómo ejecutar

- **Claude Code en el mismo PC (recomendado):** ejecutar cada script con `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\<script>.ps1 -OutFile <ruta>.json` y leer el JSON. Usar `powershell` (5.1), no `pwsh`: es lo que tiene cualquier PC.
- **Sin shell de Windows** (por ejemplo, una sesión conectada solo a carpetas): pedir al usuario que haga doble clic en `scripts\diagnostico.bat` y leer `_resultados\*.json` y `*.log`. Si un script falla, su `.log` trae la línea exacta.

Tiempos aproximados: hardware 5–10 s, software 5–10 s, disco hasta 2 min, dev-caches hasta 3 min.

## Flujo

### Fase 0: Preparación
- **Si existe `_resultados/<NOMBRE-DEL-EQUIPO>-decisiones.md`, leerlo primero** (`$env:COMPUTERNAME`). Lo que ya está decidido ahí no se vuelve a preguntar ni a sugerir: modelos y volúmenes que se conservan, software de TI, cambios ya aplicados. Solo se repregunta si el diagnóstico nuevo contradice algo del archivo (por ejemplo, un modelo marcado "se conserva" que ya no existe).
- Preguntar el **uso principal** del PC (desarrollo, ofimática, gaming, edición) y la **queja concreta** ("lento al abrir apps", "sin espacio", "emulador con lag").
- Si es un PC de empresa, preguntar qué software es de TI (antivirus, VPN, agentes): se marca como no tocar.

### Fase 1: Hardware (`hardware.ps1`)
CPU (y si rinde por debajo de su base bajo carga), RAM (módulos, ranuras, velocidad, uso, **memoria comprometida**), discos (SSD/HDD, NVMe/SATA, salud, cuál tiene C:), GPU (VRAM real, driver), plan y modo de energía, virtualización, batería, uptime.

Hallazgos que genera, por severidad:
- **Crítica:** `WINDOWS_EN_HDD`, `DISCO_SALUD`, `DISCO_DESGASTE`
- **Alta:** `RAM_SATURADA` (≤ 8 GB y ≥ 80 %), `RAM_UN_CANAL`, `MEMORIA_COMPROMETIDA` (≥ 85 % del límite)
- **Media:** `RAM_JUSTA`, `RAM_ALTA`, `ENERGIA_AHORRO`, `CPU_FRENADO`, `DISCO_LLENO`, `VIRTUALIZACION_OFF`, `GPU_SIN_DRIVER`
- **Baja:** `GPU_DRIVER_VIEJO`, `RAM_DISPAREJA`, `RAM_BAJO_SU_VELOCIDAD`, `BATERIA_DESGASTADA`, `UPTIME_ALTO`

Límite: Windows no expone la temperatura del CPU de forma confiable. Si hace falta, sugerir LibreHardwareMonitor; no inventar lecturas.

### Fase 2: Software y memoria (`software.ps1`)
Programas de inicio (con su estado real habilitado/deshabilitado), tareas programadas al iniciar sesión, servicios automáticos de terceros, top de procesos por RAM, por **memoria reservada** y por CPU, memoria sin atribuir (VMs), límite de WSL en `.wslconfig`, antivirus activos, software marcado según `references/bloatware.md`, apps promocionales de la Store.

Si la memoria comprometida es alta, `procesos.top_reservada` y `memoria.sin_atribuir_gb` dicen quién la ocupa (la RAM en uso no lo explica).

### Fase 3a: Espacio del sistema y del usuario (`disco.ps1`)
Volúmenes, hibernación, paginación, papelera, temporales, Windows Update, Windows.old, volcados de memoria, cachés de navegadores, instaladores viejos en Descargas, y archivos ≥ 1 GB en el perfil (recorrido por niveles con límite de tiempo, saltando las cachés que mide dev-caches).

### Fase 3b: Herramientas de desarrollo (`dev-caches.ps1`)
Docker (build cache, imágenes sin uso, contenedores detenidos, volúmenes huérfanos, espacio compactable del `.vhdx`), WSL, Ollama (tamaño real por modelo, blobs huérfanos, ubicación según `OLLAMA_MODELS`), Android SDK (imágenes sin AVD, build-tools y NDK viejos), JetBrains, Gradle, Maven, npm, Yarn, pnpm, pip, Pub, FVM, NuGet, JDKs, VS Code, Cursor y `node_modules`.

### Fase 4: Contexto
`dev-caches.ps1` busca en las carpetas de proyectos (por defecto Documentos y Escritorio; cambiar con `-Proyectos`) referencias a cada modelo de Ollama y cada versión de Gradle, con límite de palabra (`qwen3-vl:2b` no coincide con `qwen3-vl:2b-instruct`).

Además, Claude:
- Pregunta dónde están los proyectos si no están en Documentos/Escritorio.
- Para contenedores detenidos y volúmenes con datos, pregunta si el proyecto sigue vivo. Nunca lo deduce por la fecha.
- Si un modelo o una imagen tiene referencias, lo trata como **no tocar**.

### Fase 5: Reporte y plan
1. **Diagnóstico principal** en 1 a 3 líneas: el cuello de botella real (hardware primero).
2. **Tabla de hallazgos**: qué, tamaño o impacto, nivel (🟢 seguro / 🟡 revisar / 🔴 no tocar), acción.
3. **Plan ordenado por impacto**: hardware → memoria y arranque → espacio seguro → espacio por decidir.
4. Si la sesión usa una VM (la app de Claude), aclarar cuánto de la memoria es de esa VM.

### Fase 6: Ejecución
- Un paso a la vez: mostrar el comando, esperar aprobación, ejecutar, mostrar el resultado.
- Orden en Docker: primero los prune y después compactar el `.vhdx`.
- Cerrar los IDEs antes de borrar cachés de JetBrains o Gradle.

### Fase 7: Verificación y registro
- Volver a correr el diagnóstico y comparar con el JSON inicial (espacio libre, memoria comprometida, programas de inicio). Para la memoria, medir en condiciones comparables: con las apps de trabajo abiertas, no recién encendido.
- **Escribir o actualizar `_resultados/<NOMBRE-DEL-EQUIPO>-decisiones.md`** con este formato:

```markdown
# Decisiones de optimización: <NOMBRE-DEL-EQUIPO>
Equipo: <fabricante y modelo>, <CPU>, <RAM>, <disco>. Uso: <uso principal>.

## Se conserva (no volver a sugerir)
- <ítem>: <motivo, p. ej. "lo usa el proyecto X (ruta)">

## No tocar (de TI o datos)
- <ítem>: <motivo>

## Cambios aplicados
- <AAAA-MM-DD>: <qué se hizo> (<GB liberados o efecto>)

## Pendiente / decidido no hacer
- <ítem>: <decisión del usuario y por qué>

## Mediciones
| Fecha | C: libre | Memoria comprometida | Programas de inicio |
|---|---|---|---|
```

- Se agregan líneas; no se borran las anteriores salvo que el usuario lo pida. Es el historial del equipo.
- `_resultados/` está en `.gitignore`: tiene datos personales del PC y no se sube al repositorio.

## 🔴 Nunca tocar (resumen; detalle en `references/reglas.md`)

- `WinSxS` y los "duplicados" que son hardlinks; `System Volume Information`; `pagefile.sys`.
- Volúmenes Docker con datos: **nunca** `docker volume prune` ni `docker system prune --volumes`.
- Archivos de bases de datos (`postgres_data`, `pgdata`, `mysql_data`, `mongodata`, `.mdf`, `.ibd`, `.sqlite`).
- Discos de distros WSL y de VMs de aplicaciones (`Claude\vm_bundles`).
- `AppData\Local\Packages`, `AppData\Roaming\JetBrains`, carpetas de proyectos y repos `.git`.
- Software de TI en equipos corporativos.

## Mantenimiento de los scripts

Corren en **Windows PowerShell 5.1**. Antes de editar, leer "Detalles técnicos" al final de `references/reglas.md` (errores reales de 5.1). Guardar en UTF-8 con BOM y validar la sintaxis antes de entregar.
