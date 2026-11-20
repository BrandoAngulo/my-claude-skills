# Reglas de decisión de pc-optimizer

Este archivo es el criterio. Los scripts recolectan datos; las decisiones salen de aquí.
Cada regla viene de un caso real: si se agrega una, anotar de dónde salió.

## Principio general

Un ítem solo es **seguro** si cumple las dos condiciones: (1) se regenera solo o se vuelve a descargar, y (2) no contiene trabajo del usuario.
Si falta cualquiera de las dos, es **revisar**. Si borrarlo rompe algo que no se puede recuperar, es **no tocar**.

Que algo "no aparezca" en la búsqueda de proyectos NO lo vuelve seguro: la búsqueda tiene límite de tiempo y de carpetas.

## Hardware: interpretar antes de limpiar

| Señal | Lectura |
|---|---|
| `C:` en HDD | El cuello de botella es el disco. Ninguna limpieza lo arregla. Va primero en el reporte. |
| Un solo módulo de RAM y ranura libre | Single channel. Con GPU integrada (Iris Xe, UHD, Radeon Vega) baja también el rendimiento gráfico: explica lag en emuladores y en la interfaz. |
| Memoria comprometida ≥ 85 % del límite | El equipo ya está paginando. Buscar en `software.json > procesos.top_reservada` y `memoria.sin_atribuir_gb` quién la ocupa. Vale aunque el equipo tenga 16 GB o más. |
| `vmmemWSL` | VM de WSL 2 / Docker. Se limita con `%USERPROFILE%\.wslconfig` (`[wsl2]` + `memory=6GB`) y `wsl --shutdown`. |
| `vmmem` (sin WSL) | Otra VM de Hyper-V: Windows Sandbox, una VM de Hyper-V o **la VM de la app de Claude** mientras hay una sesión conectada al PC. Avisar al usuario si es la de Claude: se libera al cerrar la sesión. |
| GPU dedicada en un equipo que "se siente lento" | La GPU no influye en la fluidez general de Windows. Revisar disco y RAM primero. |
| Virtualización "firmware deshabilitada" con hipervisor activo | Falso negativo conocido: con Hyper-V/WSL 2 activos, Windows reporta el firmware como deshabilitado. Usar `virtualizacion.efectiva`. |

Emulación Android: con ≤ 8 GB de RAM, o con memoria comprometida alta, recomendar dispositivo físico + scrcpy en vez de emulador.

## Docker

- `docker builder prune -a -f` → **seguro**. Solo capas de build.
- `docker image prune -a` → **seguro**. Solo borra imágenes que no usa ningún contenedor, ni siquiera uno detenido.
- `docker container prune` → **revisar**. Un contenedor detenido puede tener datos en su capa escribible y se pierde la configuración con la que se creó.
- `docker volume prune` y `docker system prune --volumes` → **nunca**. Los volúmenes huérfanos suelen ser bases de datos de proyectos viejos (caso real: `mongodataold`, `listo_proyects_pgdata`). Se revisan uno por uno con el usuario.
- El `.vhdx` **no se encoge solo**. Después de los prune: cerrar Docker Desktop (Quit), `wsl --shutdown`, y en `diskpart` como admin: `select vdisk file="..."`, `attach vdisk readonly`, `compact vdisk`, `detach vdisk`. Caso real: 65 GB → 33 GB.
- Compactar detiene los contenedores. Avisar si hay bases de datos corriendo (p. ej. `postgres-dev`, `mysql-dev`).

## WSL

- `ext4.vhdx` de una distro → **no tocar**. Borrarlo elimina la distro completa. Si ya no se usa: `wsl --unregister <distro>`, con confirmación explícita.
- Se compacta igual que el disco de Docker.

## Ollama

- Antes de sugerir `ollama rm`, buscar el nombre exacto del modelo en los proyectos. Caso real: se iba a borrar `qwen2.5vl:3b` y era el modelo de producción del proyecto del escáner.
- Las etiquetas de qwen3 / qwen3-vl **sin sufijo** son la variante *thinking*, distinta de `-instruct`. No son duplicados. La búsqueda usa límite de palabra para no confundirlas.
- Revisar `OLLAMA_MODELS`. Si apunta a una carpeta vacía mientras los modelos están en `~\.ollama\models`, al reiniciar Ollama `ollama list` sale vacío y los modelos se vuelven a descargar (espacio duplicado). Caso real: `C:\ollama-models` vacía.
- Los modelos sin referencias siempre son **revisar**, nunca seguros: pueden usarse desde scripts fuera de las carpetas revisadas.
- Manifests internos con nombre `llamacpp:<64 hex>`: no salen en `ollama list` y no se borran con `ollama rm`. El tag es el SHA-256 del propio manifest y apunta a otros pesos (formato llama.cpp). Lo observado en un caso real, no documentado por Ollama:
  - Si un modelo con nombre incluye como capa el blob `sha256-<tag>`, el interno es **parte de ese modelo**: no tocar, aunque ocupe espacio propio (caso real: ~3 GB extra de `qwen2.5vl:3b`).
  - Si ningún modelo con nombre lo referencia, es un **resto** de un modelo ya borrado que sigue reteniendo sus blobs (caso real: los de `qwen3-vl:2b` y `qwen3-vl:2b-instruct` después de `ollama rm`). Nivel: revisar. Se quita borrando ese manifest con Ollama cerrado.
  - Primera versión de la regla (equivocada): se asumía que un interno con el mismo ID que un modelo era un alias sin espacio extra. No lo es.
- La búsqueda de referencias excluye `_resultados`, la carpeta de salida y la carpeta de la propia skill: sus JSON y este archivo mencionan modelos y versiones como ejemplos y daban referencias falsas (caso real: una versión de Gradle "referenciada" por `dev-caches.json` y luego por este mismo archivo).
- En CPU sin GPU compatible, los modelos de 7–8B son lentos: dato útil para que el usuario decida, no razón para borrar.

## JetBrains

- `%LOCALAPPDATA%\JetBrains\<Producto><versión>` de versiones viejas → **seguro** si existe una versión más nueva del mismo producto. Son cachés e índices.
- `%APPDATA%\JetBrains` → **no tocar** (configuración, plugins, keymaps).
- `java_error_in_*.hprof` y `java_error_in_*.log` / `replay_pid*.log` en el perfil → **seguro**. Son volcados de crasheos (caso real: 3,5 GB).

## Gradle, Maven y paquetes

- `.gradle\caches` → **seguro** con los IDEs cerrados. El primer build siguiente tarda.
- `.gradle\wrapper\dists\gradle-X` → **seguro** solo si ningún `gradle-wrapper.properties` de los proyectos la pide.
- `.m2\repository` → **revisar**: puede tener artefactos propios instalados con `mvn install`.
- npm, Yarn, pnpm, pip, NuGet → **seguro** con su comando (`npm cache clean --force`, `pip cache purge`, etc.).
- Pub (Flutter) → **revisar**: `flutter pub cache clean` borra también los paquetes activados con `dart pub global`.
- FVM y `.jdks` → **revisar**: cada proyecto fija su versión.
- `node_modules` de proyectos sin cambios en 90 días → **seguro** (se regeneran con `npm install`). La fecha es la de la carpeta del proyecto, que es aproximada: mostrar la lista al usuario.

## Android SDK

- Una system-image que ningún AVD usa (se lee `image.sysdir.1` en `config.ini`) → **revisar**.
- build-tools y NDK: se conservan las 2 versiones más nuevas; las demás → **revisar** (un proyecto puede fijar `buildToolsVersion` o `ndkVersion`).
- NDK con Flutter instalado: Flutter usa por defecto un NDK fijo (`flutter.ndkVersion`), que no tiene por qué ser el más nuevo. Que haya versiones más nuevas no lo vuelve prescindible. Caso real: NDK 27.0.12077973 marcado como "viejo" era el que usan los proyectos Flutter.
- Un AVD grande → **revisar**: Wipe Data lo limpia sin borrarlo.

## Archivos de sistema

| Archivo / carpeta | Nivel | Nota |
|---|---|---|
| `pagefile.sys` | no tocar | Solo se ajusta el tamaño. Con RAM justa, dejarlo administrado por Windows. |
| `hiberfil.sys` | revisar | `powercfg /h off` (admin). También desactiva el Inicio rápido. En portátiles que se guardan días cerrados, conviene mantenerlo. |
| `swapfile.sys` | no tocar | |
| `C:\Windows\WinSxS` | no tocar | Los "duplicados" que muestra WizTree son hardlinks: el Asignado entre paréntesis indica que no ocupan espacio extra. |
| `System Volume Information` | no tocar | Puntos de restauración. Solo reducir con `vssadmin` y aprobación. |
| `Windows.old` | revisar | Permite volver a la versión anterior de Windows. Se borra sola a los 10 días. |
| Temporales, caché de Windows Update, minidumps | seguro | Desde Configuración > Sistema > Almacenamiento > Archivos temporales. |

## Datos del usuario y de aplicaciones

- Archivos de bases de datos (`postgres_data`, `pgdata`, `mysql_data`, `mongodata`, `base\<n>\<n>`, `.mdf`, `.ibd`, `.sqlite`, `.db`) → **no tocar**. Caso real: `Desktop\dockerComposeMysql\postgres\postgres_data`.
- `AppData\Roaming\Claude\vm_bundles` → **no tocar** (VM de la app de Claude).
- `AppData\Local\Packages` → **no tocar** (datos de apps de la Store).
- Cualquier cosa dentro de OneDrive → **revisar**: borrarla aquí la borra en la nube.
- ISOs, instaladores, videos, papelera → **revisar**: decisión del usuario. Las ISO y los instaladores de licencias pagas se mueven a un disco externo, no se borran.
- `.ost` de Outlook → **revisar**: se reduce bajando el período sin conexión en Outlook, nunca borrando el archivo.

## Equipos corporativos

Antivirus, VPN (p. ej. OpenVPN), agentes de inventario, TeamViewer administrado y herramientas de monitoreo pueden ser de TI. Se reportan, pero se marcan **no tocar** salvo que el usuario confirme que son suyos.

## Detalles técnicos de los scripts (Windows PowerShell 5.1)

La mayoría de los PCs con Windows corren los scripts en Windows PowerShell 5.1, no en PowerShell 7. Errores reales que hay que evitar:

- `@($ListaGenerica)` dentro de un literal `@{}` / `[ordered]@{}` lanza "Los tipos de argumentos no coinciden". Usar `.ToArray()` antes de armar el literal.
- `[byte] -band [int]` lanza el mismo error. Convertir: `([int]$b) -band 1`.
- Un `if` que devuelve un arreglo de un solo elemento lo convierte en escalar. Envolver con `@(if (...) { ... })`.
- `Get-Item C:\pagefile.sys` falla sin admin (archivo en uso). Listar la raíz con `DirectoryInfo.GetFiles('*.sys')` sí devuelve el tamaño.
- `HibernateEnabled` no siempre existe en el registro: usar `HibernateEnabledDefault` o la existencia de `hiberfil.sys`.
- Los nombres de contadores de rendimiento cambian con el idioma de Windows: usar clases CIM (`Win32_PerfFormattedData_*`).
- `AdapterRAM` de WMI tope 4 GB: la VRAM real se lee de `HardwareInformation.qwMemorySize` en el registro.
- Guardar los `.ps1` en UTF-8 **con BOM**, o PowerShell 5.1 rompe las tildes.
- Todo script lleva `trap` que reporta la línea exacta del fallo.
