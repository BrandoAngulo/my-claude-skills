---
name: iniciar-hu
description: Pasos para arrancar el desarrollo de una HU del ecosistema listo (proyectos IDR / LIS de Jira) antes de escribir código - leer la HU completa, revisar dependencias y ramas, analizar contra el código real y dejar los documentos de inicio en docs/hu-XXXX-plan. Actívala SIEMPRE que Brando diga "lee la HU IDR-XXXX", "analiza la HU", "vamos a iniciar la HU", "arranquemos con LIS-XXXX", "haz los docs para iniciar la implementación" o pase un código de HU para empezar a trabajarla.
---

# Iniciar una HU

Objetivo: que al terminar Brando tenga en `docs/hu-XXXX-plan/` todo lo necesario para crear la rama y empezar, sin reproceso. **No se escribe código del proyecto en este paso** (modo profesor: la guía con código viene después, cuando Brando cierre las decisiones).

## Pasos

1. **Cargar contexto del ecosistema**
   - Skill `listo-ecosystem`.
   - Memoria: leer ENTEROS `feedback_checklist_analisis_hu.md`, `feedback_hu_puntos_para_po.md`, `feedback_no_inventar_proponer_desde_codigo.md` y cualquier `project_*` de la HU o de las HU de las que depende.

2. **Leer la HU, sin saltarse nada**
   - Primero lo que ya existe: `docs/hu-XXXX-plan/`, las revisiones de sprint en `docs/` (`grep -rl "XXXX" docs`). Si ya está, no se consulta Jira.
   - Si no hay doc o está desactualizado: API de Jira con `JIRA_BASE`, `JIRA_EMAIL`, `JIRA_TOKEN` (ver `reference_jira_api_access.md`), con `expand=renderedFields` y los campos `subtasks`, `issuelinks`, `attachment`, `comment`, `updated`.
   - Guardar el texto completo en `docs/hu-XXXX-plan/HU_original.txt` con la fecha de `updated`.
   - Leer también: las subtareas (estimación y descripción) y las HU enlazadas (Blocks / Relates), por lo menos su contexto y notas técnicas.

3. **Revisar ramas y dependencias antes de la rama nueva**
   - `git fetch` en cada repo que toca la HU.
   - ¿La rama del sprint ya tiene las HU de las que depende? (`git log origin/<sprint>` y `git branch -r --contains <commit>`). Si no, decirlo en la sección 0 del análisis con las opciones de rama base.
   - Ramas de compañeros de las HU enlazadas (`git branch -r | grep <código>`): qué tocan y si van a chocar (por ejemplo, getters de Lombok, mismos métodos, mismos códigos de error).

4. **Analizar contra el código real** (checklist de análisis completo)
   - Cada criterio (CF / CNEG) con el archivo:línea donde vive hoy, o «no existe».
   - Recorrer el flujo actual de punta a punta y decir qué pasaría hoy con el caso nuevo.
   - Buscar lo que ya existe para reutilizar antes de proponer algo nuevo.
   - Quién más llama a cada pieza que se modifica (regla «solo afecta a X»).
   - Errores contra `ControllerAdvice`; validaciones del front contra el componente real.
   - Lo no verificable es «por confirmar», nunca base de una recomendación.

5. **Escribir `docs/hu-XXXX-plan/<HU>-analisis.md`** con estas secciones:
   0. Antes de crear la rama (rama base, ramas de compañeros que chocan).
   1. Criterio → qué se hace → dónde vive hoy (tabla).
   2. Cómo funciona hoy (diagrama corto del flujo).
   3. Hallazgos: # / hallazgo / evidencia archivo:línea / qué se propone / **Qué hacer (Brando)**. La última columna va vacía: ahí Brando escribe su decisión. Va también en las decisiones (sección 6) y los pendientes (sección 7).
   4. Diseño propuesto (métodos, tablas, endpoints, errores).
   5. Subtareas: tabla con la subtarea de Jira, la estimación de Jira, la propuesta y qué incluye. Solo en el documento; nunca se escribe en Jira sin pedirlo.
   6. Decisiones para Brando (formato «Hoy: … / Se propone: …»).
   7. Pendientes con otros (PO, compañeros, infraestructura).

6. **Memoria**: guardar un `project_<hu>_*.md` con el estado (qué se decidió, qué falta, de qué depende) y agregarlo a `MEMORY.md`.

7. **Entregar a Brando**: resumen corto en el chat (rama base, hallazgos que bloquean, decisiones pendientes) y los enlaces a los documentos. Cuando cierre las decisiones, sigue la guía de implementación con `feedback_checklist_guia_implementacion.md` (compilar en copia antes de entregar).

## Qué NO hacer

- No escribir en Jira (subtareas, comentarios, worklogs) sin que Brando lo pida.
- No crear la rama ni hacer commits.
- No llevar a la PO lo que el código responde; primero se le pregunta a Brando lo que solo sabe el equipo.
- No repetir aquí las lecciones de los checklists: viven en la memoria y se leen cada vez.
