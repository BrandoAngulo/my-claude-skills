---
name: jira-worklog-horarios
description: >
  Auditar y corregir los worklogs (registros de tiempo) de Brando en Jira
  (grupo-playtechla.atlassian.net): descripciones vacías, registros en fin de
  semana, horario fuera de 7:30am-5:00pm hora Colombia, y bloques que no
  respetan el almuerzo de 13:00-14:00. También cubre copiar el registro de un
  compañero para un día puntual. Actívala SIEMPRE que Brando diga cosas como:
  "revisa mis horarios/worklogs de jira", "cuadra mis horas", "falta
  descripción en mis registros de tiempo", "revisa si registré en sábado",
  "corrige mis horarios para que respeten el almuerzo", "copia lo mismo que
  hizo [compañero] hoy/el día X en jira".
---

# Auditoría y corrección de worklogs en Jira

Brando reporta sus horas en varias HU/subtareas de Jira (`grupo-playtechla.atlassian.net`,
proyectos `LIS-*` e `IDR-*`). Periódicamente hay que revisar un rango de fechas y
corregir tres clases de problemas: descripciones vacías, registros fuera del
horario laboral, y registros que no respetan el almuerzo. Este skill encapsula
esa auditoría + la corrección, usando un único helper de Python.

## Reglas de negocio (fijas, no preguntar cada vez)

- **Horario laboral:** 7:30am–5:00pm, hora Colombia (`America/Bogota`, offset
  fijo `-05:00` todo el año — Colombia no usa horario de verano).
- **Almuerzo:** 1:00pm–2:00pm. Ningún worklog puede tener tiempo registrado
  dentro de esa franja. Si un bloque la cruza, se **divide en dos** (mañana
  hasta las 13:00, tarde desde las 14:00) conservando la misma duración total
  y la misma descripción en ambas mitades.
- **"Daily" (issue `IDR-98`):** siempre debe arrancar a las **7:30am**, sin
  excepción — es la convención que Brando usa para esa subtarea recurrente.
- **Fin de semana:** no debe haber ningún registro en sábado/domingo. Si
  aparece uno, es una alerta a reportar, no se corrige sola — preguntar antes.
- **Días sin registrar:** si hoy (o un día laboral dentro del rango) no tiene
  ningún worklog, es una alerta informativa, no un "error" a corregir.

## Prerrequisitos

Variables de entorno ya configuradas en esta máquina (mismas que usa el skill
`jira-sprint-review`): `JIRA_BASE`, `JIRA_EMAIL`, `JIRA_TOKEN`.

El intérprete `python3`/`python` del PATH es un stub roto en esta máquina
(abre la Microsoft Store). Usa siempre la ruta completa:

```
/c/Users/Desarrollo/AppData/Local/Programs/Python/Python313/python.exe
```

El helper vive en `scripts/jira_worklog.py` (dentro de este skill, en
`D:\Desarrollo\my-claude-skills\jira-worklog-horarios\scripts\`).

**Gotcha de la API ya resuelto en el script — no lo redescubras:** Jira Cloud
exige el offset de zona horaria **sin los dos puntos** (`-0500`), no `-05:00`.
Con colon responde `400 Bad Request` / "Formato de fecha no válido". El
helper ya lo maneja (constante `TZ = "-0500"`); si escribes una llamada cruda
a la API fuera del helper, recuérdalo.

## Flujo A — Auditoría + corrección de un rango de fechas

1. **Correr la auditoría:**

   ```
   python jira_worklog.py audit --start YYYY-MM-DD --end YYYY-MM-DD \
       --out audit_cache.json
   ```

   Esto imprime: descripciones vacías, registros en fin de semana, y registros
   fuera de 7:30-17:00 o que cruzan el almuerzo. También guarda un cache JSON
   (`audit_cache.json`) con todos los worklogs del rango — lo vas a necesitar
   para los pasos de corrección (`split --keep-comment` lo lee para copiar la
   descripción original a la mitad de la tarde).

2. **Reportar a Brando antes de tocar nada:** una tabla con los hallazgos
   (igual que en las sesiones previas) — qué días, qué HU, qué falta o qué
   horario hay que mover. Las descripciones vacías normalmente se completan
   con un texto corto (máx. 4 líneas) sobre la tecnología que corresponda al
   contexto (GCP, SQL, Spring Boot, Angular, etc.) — pedir confirmación del
   texto si no es obvio del contexto de la conversación.

3. **Esperar el "sí, aplica" de Brando** antes de escribir nada — estos son
   registros de horas reales, no se tocan sin confirmación explícita.

4. **Aplicar las correcciones** con `update` (ajuste simple de horario) o
   `split` (cuando el bloque cruza el almuerzo):

   ```
   # Ajuste simple: mover el inicio, sin tocar duración
   python jira_worklog.py update --key IDR-98 --id 53405 --start 2026-09-07T07:30

   # Ajuste simple + duración + nueva descripción
   python jira_worklog.py update --key LIS-7066 --id 54580 \
       --start 2026-09-22T07:30 --comment "Investigacion sobre ..."

   # Dividir un bloque que cruza el almuerzo (mañana hasta 13:00, tarde desde 14:00)
   python jira_worklog.py split --key LIS-7066 --id 54067 \
       --morning 2026-09-16T08:15 --morning-duration "4h 45m" \
       --afternoon 2026-09-16T14:00 --afternoon-duration "3h" \
       --keep-comment --cache audit_cache.json
   ```

   Regla para calcular la división cuando el bloque original **ya estaba
   fuera de horario** (por eso se está corrigiendo el horario Y el almuerzo a
   la vez): repartir con la tarde "anclada" al final del día (máx. 3h,
   terminando a las 17:00) y la mañana absorbiendo el resto hasta las 13:00.
   Si el bloque **ya estaba dentro de 7:30-17:00** y solo cruza el almuerzo,
   usar el inicio original como ancla de la mañana (hasta 13:00) y mandar el
   resto a la tarde desde las 14:00 — ver el análisis de sept-oct 2026 en el
   historial de la conversación para los números exactos ya validados.

5. **Verificar en caliente** volviendo a correr `audit` sobre el mismo rango:
   debe reportar 0 en las tres categorías y el total de horas debe ser
   idéntico al de antes de corregir (solo se reparte/mueve tiempo, nunca se
   gana ni se pierde). Si el `audit` inmediatamente después de aplicar muestra
   resultados viejos, es casi seguro un timeout de red transitorio en el
   fetch, no un fallo real de la escritura — repetir el `audit` una vez más
   antes de alarmar a Brando.

## Flujo B — Copiar el registro de un compañero para un día puntual

Brando a veces pide replicar en su cuenta lo que otro colaborador registró el
mismo día en una o varias HU (por ejemplo, ceremonias compartidas como un
Daily o un análisis de requerimientos hecho en conjunto).

**Esto es sensible — nunca lo ejecutes sin esta confirmación explícita
primero**, porque equivale a crear un registro de horas que no es
automáticamente evidencia de trabajo propio:

> Antes de registrar esto: ¿hoy trabajaste efectivamente en lo mismo que
> [colaborador] y quieres reflejar horas equivalentes con tu propia
> descripción, o literalmente quieres duplicar sus mismos registros (horario
> y texto) en tu cuenta?

Si Brando confirma la copia literal (total o parcial, con texto propio en
alguna HU puntual):

1. **Encontrar el `accountId` del compañero** si no se conoce ya (queda fijo,
   vale la pena recordarlo): usar `worklogs-of` apuntando a una HU donde se
   sabe que ambos registran, mirar el campo `author.accountId` en la
   respuesta cruda, o preguntarle a Brando el nombre para buscarlo.
   `cristian pazu` ya está identificado: `619b9710c510bc006b76a024`.

2. **Traer lo que registró ese día en las HU indicadas:**

   ```
   python jira_worklog.py worklogs-of --account <accountId> \
       --date YYYY-MM-DD --keys HU1,HU2,HU3
   ```

3. **Crear cada entrada en la cuenta de Brando** con `create`, usando el
   mismo `started`/`timeSpent` que salió en el paso anterior, y el mismo
   `comment` salvo que Brando haya pedido una descripción distinta para
   alguna HU en particular:

   ```
   python jira_worklog.py create --key LIS-7090 \
       --start 2026-10-08T07:30 --duration "30m" \
       --comment "Se realizo el daily"
   ```

4. Confirmar que el total del día sigue dentro de 7:30-17:00 y sin cruzar el
   almuerzo (normalmente ya lo está, porque se copia de alguien que también
   sigue esa convención) — si no, aplicar el Flujo A sobre esas entradas
   nuevas antes de darlas por cerradas.

## Flujo C — Registrar los tiempos de un día de trabajo

Se activa cuando Brando dice cosas como **"registra tiempos"**, "registra mis
horas de hoy", "registra lo que hice hoy/ayer en jira". A diferencia de los
Flujos A y B (que corrigen o copian registros que ya existen), este flujo
**crea desde cero** los worklogs de un día basándose en lo que realmente se
trabajó.

1. **Determinar qué se trabajó y cuánto tiempo por HU:**
   - Si la sesión actual de conversación ya deja claro en qué HU(s) se trabajó
     (por ejemplo, Brando estuvo pidiendo cambios de código, investigación o
     análisis sobre una HU puntual durante este mismo chat), usar eso como
     base y proponerlo.
   - Si no es evidente o hay varias HU candidatas, **preguntar explícitamente**:
     qué HU(s), y aproximadamente cuánto tiempo le dedicó a cada una (no
     inventar la distribución de horas sin confirmación — eso es él quien lo
     sabe, no se infiere del código).
   - Si Brando solo da el total del día sin desglose por HU, repartirlo en los
     bloques que él indique; si no indica nada más, usar la HU de "trabajo
     general" que corresponda al contexto (p.ej. `LIS-7066` para
     investigación/desarrollo) salvo que la conversación sugiera otra.

2. **Ubicar los bloques dentro del día respetando las reglas fijas:**
   horario 7:30am-5:00pm, almuerzo 13:00-14:00 libre, "Daily" (`IDR-98`) sí
   aplica y siempre arranca a las 7:30am si ese día hubo daily. Si el total
   del día es ~8h, el patrón típico ya usado es: bloque de mañana empezando a
   las 7:30-8:15 (dejando espacio para el Daily si aplica) hasta las 13:00, y
   bloque de tarde de 14:00 a 17:00 — ver los ejemplos ya aplicados en
   sept-oct 2026 como referencia de proporciones.

3. **Redactar una descripción corta (máx. 4 líneas) por bloque**, mencionando
   la tecnología/tema real tratado (GCP, SQL, Spring Boot, Angular, Flutter,
   etc.) cuando aplique — mismo estilo que se usó para completar las
   descripciones vacías de LIS-7066.

4. **Mostrarle a Brando la propuesta completa (HU, horario, duración,
   descripción) y esperar confirmación explícita antes de crear nada** —
   igual regla que en los Flujos A y B, esto son horas reales de trabajo.

5. **Crear cada bloque confirmado** con `create`:

   ```
   python jira_worklog.py create --key LIS-7066 \
       --start 2026-10-08T08:00 --duration "5h" \
       --comment "Investigacion sobre ..."
   ```

6. **Verificar con `audit`** sobre ese día para confirmar que no quedó nada
   fuera de horario ni cruzando el almuerzo, y que el total coincide con lo
   que Brando dijo que trabajó.

## Qué NO hacer

- No corregir ni crear nada sin que Brando haya visto la tabla de cambios
  propuestos y haya dicho que sí explícitamente.
- No asumir "días sin registro" como algo a rellenar automáticamente — eso es
  decisión de Brando, no una corrección de formato.
- No usar el offset `-05:00` con colon en ninguna llamada manual a la API —
  usa siempre el helper o el formato `-0500`.
