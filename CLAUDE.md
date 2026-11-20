# CLAUDE.md — Global (Brando)

> Archivo global y **portable**. Vive en `~/.claude/CLAUDE.md` (enlace al repo `my-claude-skills`).
> **No incluir rutas absolutas de máquina** (usar `~/` o `%USERPROFILE%`) para que sincronice igual en cualquier equipo.
> Reglas para TODOS los proyectos. El CLAUDE.md de cada proyecto tiene prioridad si hay conflicto.

## Quién soy
Brando — desarrollador full-stack en Cali, Colombia. Trabajo solo en la mayoría de proyectos; en buigo_server somos un equipo de 2 devs con Gitflow.

## Idiomas
- **Respuestas y explicaciones:** siempre en español.
- **Código (identificadores, métodos, clases, variables, servicios, endpoints):** en inglés. Si un proyecto existente ya usa español en sus identificadores, lo define el CLAUDE.md de ese proyecto.
- **Ramas:** inglés, formato `<type>/kebab-case`.
- **Commits:** Conventional Commits con descripción en español (`fix:`, `feat:`, `chore:`…). Nunca agregar líneas de atribución a Claude.
- **Comentarios:** en español. Incluye la documentación de métodos, servicios y clases (Javadoc, docstrings, JSDoc/TSDoc, comentarios de Dart) que explica qué hacen, y los comentarios en línea, que solo van cuando expliquen el "por qué".
- **Mensajes de error visibles al usuario final:** español.

## Stack
- **Backend:** Java 21 / Spring Boot 3.4 (Maven) · Java 8 (sistemas legacy) · Python / FastAPI · PHP
- **Frontend:** Angular · React · Next.js (App Router) · Flutter (FVM en algunos proyectos)
- **Datos:** PostgreSQL · Supabase · MongoDB
- **Infra:** Docker · n8n · GitHub · Cloudinary (imágenes)
- **SO:** Windows 11 con PowerShell. Los comandos deben funcionar en Windows (rutas con `\`, `.\mvnw`, `.\venv\Scripts\activate`).

## Flujo de trabajo (innegociable)
1. **Leer antes de escribir.** Detectar stack, arquitectura y convenciones del proyecto ANTES de proponer o escribir código. Nunca asumir.
2. **Aprobación previa.** Ante cualquier cambio no trivial, mostrar el plan o el contenido y esperar aprobación explícita antes de crear o modificar archivos, salvo que diga "hazlo directo".
3. **Respetar lo existente.** No imponer librerías, patrones o arquitecturas que el proyecto no usa. No mezclar patrones de estado o de capas.
4. **Un paso a la vez.** No encadenar tareas sin confirmación intermedia.
5. **Git:** nunca ejecutar `git add` / `commit` / `push` sin que lo pida explícitamente.
6. **Acciones destructivas** (borrar, sobrescribir, mover): confirmar antes de ejecutar.
7. **No inventar.** Si falta contexto, decir "por confirmar" en vez de asumir.
8. **Git multi-cuenta:** varias cuentas de GitHub según el repo. Cada repo fija su identidad con `git config --local`; **verificar `user.email` antes de commitear**. Los proyectos y cuentas viven en el `CONTEXT_MEMORY.md` de cada máquina.

## Convenciones universales
- **Git:** seguir la skill `git-best-practices` (ramas `<type>/kebab-case`, squash merge para features, nunca commitear secretos ni `.env`). En buigo_server aplica Gitflow (develop/main).
- **Errores:** manejo explícito siempre: nunca `catch` vacío ni excepciones genéricas silenciadas; status HTTP correctos.
- **Secretos:** jamás hardcodeados. Variables de entorno y `.env.example` actualizado.
- **Listas/endpoints:** paginación por defecto en todo lo que retorne colecciones.
- **Tests:** la lógica de negocio crítica se entrega con tests. Sugerir el test correspondiente después de cada fix.
- **Naming:** `verbo + sustantivo` sin preposiciones intermedias (in, of, for, by, to, with). Ej.: `updateClientReady`, no `updateInReadyClient`.
- **Código nuevo al final:** métodos nuevos al final de la clase; variables/campos nuevos al final de su grupo o bloque, nunca intercalados.
- Las convenciones detalladas por lenguaje o proyecto viven en el `CLAUDE.md` de **cada proyecto**.

## Calidad vs velocidad
- Prefiero calidad: código mantenible, seguro y consistente con el proyecto antes que soluciones rápidas.
- PERO sin sobreingeniería: nada de capas, abstracciones o patrones "por si acaso". La solución más simple que respete la arquitectura.
- Si hay un atajo con deuda técnica, señalarlo explícitamente y dejar que yo decida.

## Herramientas y skills
- Las skills globales viven en `~/.claude/skills/` (enlaces al repo `my-claude-skills`). Usarlas cuando apliquen, sin pedir permiso.
- `selector-modelo`: decide qué modelo usar por tarea (Haiku, Sonnet, Opus, Fable) en desarrollo y en video; consultarlo al empezar trabajos de varias fases y antes de lanzar subagentes. Plan Pro: Fable solo para lo de riesgo alto.
- `jira-sprint-review`: cruza issues de Jira contra el código y arma el plan del sprint. Acceso a Jira por **API token (Basic auth)**, preferido sobre el MCP de Atlassian (OAuth/SSE inestable). Setup en `jira-sprint-review/references/jira-rest.md`.
- **n8n** para automatizaciones e integraciones: si una tarea encaja mejor como workflow de n8n que como código, proponerlo.
- **Supabase** como BaaS preferido en proyectos personales (auth + DB + storage); PostgreSQL puro en buigo.

## Estado del ecosistema
- Al iniciar una sesión, **leer `~/.claude/CONTEXT_MEMORY.md`**: estado de los proyectos, rutas de cada máquina y cómo se comunican entre sí. (Si la versión de Claude Code soporta imports, equivale a `@CONTEXT_MEMORY.md`.)
