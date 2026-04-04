# Coding Agent Prompt Index and Workflow

_Single source of truth for implementation-prompt status._
_Last updated: 2026-04-04 — v7.6.0.5 complete (PR #129); Phase D CLOSED. Next: v7.7.0.0 (Phase 7)._

---

## Current status snapshot

### Phase D — Runtime Satellite Management (v7.6.0.x) ✅ COMPLETE

| Version | Scope | Primary Prompt | Status | Notes |
|---------|-------|---------------|--------|-------|
| v7.6.0.0 | NVS satellite persistence layer | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.1 | `POST /api/aggregator/add-satellite` | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.2 | `DELETE /api/aggregator/satellite/{id}` | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.3 | `POST /api/aggregator/test-satellite` | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.4 | Dashboard add/remove/test UI | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md` | ✅ Complete | shipped as PR #126 + PR #128; canonical audit below |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` | ✅ Complete | shipped as PR #129; canonical audit below |

**Phase D is fully closed. All six steps merged to `main`. Final HEAD: `188aa40`.**

---

## Phase D closure artifacts

| Artifact | File |
|----------|------|
| v7.6.0.4 canonical audit (PR #126 + PR #128) | `prompts/phaseD/v7.6.0.4-PR126-PR128-consolidated-audit-and-lessons.md` |
| v7.6.0.5 canonical audit (PR #129) | `prompts/phaseD/v7.6.0.5-PR129-consolidated-audit-and-lessons.md` |
| v7.6.0.5 session handoff (pre-PR) | `prompts/handoff/session-handoff-v7.6.0.5.md` |
| Phase 7 session handoff | `prompts/handoff/session-handoff-v7.7.0.0.md` |

> **Note:** `session-handoff-v7.7.0.0.md` is the Task 3 deliverable — see post-Phase D
> completion context in `prompts/handoff/session-prompt-post-phaseD-completion.md`.

---

## v7.6.0.4 closure note

Do not treat PR #126 alone as the final closure state.

The final v7.6.0.4 shipped state is:
- feature delivery in PR #126
- post-merge regression correction in PR #128

The canonical closure audit for continuing work is:
- `prompts/phaseD/v7.6.0.4-PR126-PR128-consolidated-audit-and-lessons.md`

---

## Required files for the next step (v7.7.0.0 — Phase 7)

Read these together before starting any Phase 7 session:

1. `prompts/handoff/session-handoff-v7.7.0.0.md` — primary handoff for Phase 7 baseline
2. `prompts/phaseD/v7.6.0.5-PR129-consolidated-audit-and-lessons.md` — Phase D final closure audit, lessons 112–114, open item OI-001
3. `prompts/phaseD/v7.6.0.4-PR126-PR128-consolidated-audit-and-lessons.md` — v7.6.0.4 canonical audit (LESSON-OPS-111, BUG-080, BUG-081)
4. `prompts/handoff/session-prompt-post-phaseD-completion.md` — post-Phase D context and Phase 7 scope framing

---

## Workflow reminder

For each implementation step:

1. Read the primary prompt fully
2. Read all required-reading files listed in that prompt
3. Read the current session handoff
4. Implement only the scoped step
5. Run required validation (all fixture sets)
6. Update the session log and this index

---

## Next action

Execute **v7.7.0.0** (Phase 7 baseline step) against the final shipped Phase D state.
Phase D is complete. `main` is green. 402 Playwright tests pass across all 4 fixture sets.

Before starting v7.7.0.0, resolve **OI-001** from the v7.6.0.5 audit:
update the `managedSatellites` parallelism comment in `tests/mock-server/server.js`
to accurately reflect that all workers share a single server instance (port 3737).
