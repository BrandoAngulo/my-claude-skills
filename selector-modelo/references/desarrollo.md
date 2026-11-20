# Desarrollo de software (día a día)

Stack habitual: Java 21 / Spring Boot 3.4 (y Java 8 legado), Angular, Flutter, PHP, Python / FastAPI, PostgreSQL, Supabase, MongoDB, Docker, n8n.

| Tarea | Modelo | Por qué |
|---|---|---|
| Correr tests, lint, formateo, buscar en logs, operaciones git, renombrar | Haiku 5.5 | Mecánico, con salida verificable |
| Boilerplate (DTO, mappers, endpoints CRUD siguiendo un patrón existente), migraciones simples | Sonnet 5.5 | Patrón claro en el código |
| Tests unitarios de código existente, refactor local en un archivo | Sonnet 5.5 | Acotado y verificable con los tests |
| Funcionalidad que toca varias capas o archivos, depurar un bug normal, revisar un PR, planear el sprint (`jira-sprint-review`), documentar | Opus 5.5 | El día a día |
| Explicar en "modo profesor" dónde va el código y por qué | Opus 5.5 | Claridad y criterio |
| **Bugs difíciles** (concurrencia, transacciones, cache, fugas de datos entre tenants, errores intermitentes) | **Fable 5.2** | Razonamiento profundo; el error cuesta horas |
| **Arquitectura y migraciones grandes** (cambio de modelo de datos, Java 8 → 21, partir un monolito, multi-tenant) | **Fable 5.2** | Decisiones caras de revertir |
| **Revisión de seguridad** (auth, JWT, RLS de Supabase, secretos, permisos) | **Fable 5.2** | Un fallo llega a producción y a datos de clientes |
| Rendimiento (consultas lentas, memoria, N+1) cuando la primera mirada no lo encontró | Fable 5.2 | Escalado tras dos intentos |
| Refactor grande en muchos archivos | Plan en Fable 5.2; ejecución por partes en Sonnet 5.5; revisión final en Opus 5.5 | Separar pensar de ejecutar |

**Código de terceros o del trabajo:** el modelo no cambia las reglas del repo (CLAUDE.md, convenciones, no commitear sin permiso). Aplica igual en cualquier modelo.
