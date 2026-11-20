# Mis Claude Skills

Fuente de verdad de mis skills personales de Claude Code. Los directorios en
`C:\Users\stivn\.claude\skills\` son enlaces (symlink/junction) a este repo.

## Skills

| Skill | Propósito |
|---|---|
| code-quality | Revisión de código, refactorización, seguridad, reporte por prioridad |
| spring-boot-expert | Desarrollo Java 21 / Spring Boot (Flyway, MapStruct, Security, JPA) |
| fastapi-expert | Desarrollo Python / FastAPI (Supabase, auth, IA, n8n) |
| nextjs-expert | Next.js App Router (Server Components, Supabase SSR, SEO, UI premium) |
| flutter-expert | Desarrollo Flutter (estado, HTTP, Supabase, performance) |
| supabase-expert | Plataforma Supabase (RLS, Edge Functions, Realtime, Storage, Auth) |
| n8n-expert | Workflows n8n (webhooks, HTTP, WhatsApp Business, patrones robustos) |
| git-best-practices | Ramas, Conventional Commits, PRs, Gitflow |
| project-onboarding | Entender y configurar cualquier proyecto desde cero |
| app-security | Revisión de seguridad defensiva por stack: detectar y corregir |
| product-owner | Roadmaps, backlog SCRUM, specs técnicas, ADRs |
| tech-proposals | Propuestas comerciales B2B, pricing COP/USD, Word/PDF |
| content-automation | Contenido con IA + distribución n8n (embudo WhatsApp de Vantedge) |
| director-video-ia | Producción de video con IA: brief, guion técnico, prompts por etiquetas, modelo por toma, QA de texto y postproducción |
| pc-optimizer | Diagnóstico y optimización de PCs Windows (hardware, memoria, disco, cachés de desarrollo) |
| selector-modelo | Decide qué modelo de Claude usar por tarea (Haiku, Sonnet, Opus, Fable) en desarrollo y video, según riesgo y cupo del plan |
| auditor-video-ia | Auditoría independiente de video con IA: riesgos antes de gastar créditos, revisión cuadro a cuadro después y bitácora de aprendizaje |
| vantedge-contenido | Estados de WhatsApp, posts y reels de Vantedge: marca, voz, formato 1080×1920 y reglas de publicación |

## Plugins (no se duplican en este repo)

| Plugin | Por qué plugin y no skill propio |
|---|---|
| `ui-ux-pro-max` v2.5.0 | Versión más completa (7 sub-skills, 531 líneas el principal) que la copia Gemini de `vantedge/.gemini/skills/` — duplicarla generaría drift y conflicto de triggers |
| `frontend-design` (claude-plugins-official) | Skill oficial de Anthropic para interfaces de alta calidad; se mantiene actualizado vía marketplace |

## Convenciones

- Cada skill: `SKILL.md` con frontmatter YAML (`name`, `description` con
  triggers) + `references/` para material extenso.
- Idioma: español; identificadores y comandos en su forma original.
- Commits: Conventional Commits en español, sin firma de Claude.
- `git-hooks/commit-msg` quita la firma de IA de los commits; instalar con `git-hooks/instalar-hook-commit.ps1`.
