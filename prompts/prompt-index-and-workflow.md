# Coding Agent Prompt Index and Workflow

_Single source of truth for implementation-prompt status._
_Last updated: 2026-04-04 — v7.6.0.4 closure complete (PR #126 + PR #128); v7.6.0.5 next._

---

## Current status snapshot

### Phase D — Runtime Satellite Management (v7.6.0.x)

| Version | Scope | Primary Prompt | Status | Notes |
|---------|-------|---------------|--------|-------|
| v7.6.0.0 | NVS satellite persistence layer | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.1 | `POST /api/aggregator/add-satellite` | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.2 | `DELETE /api/aggregator/satellite/{id}` | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.3 | `POST /api/aggregator/test-satellite` | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.4 | Dashboard add/remove/test UI | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md` | ✅ Complete | shipped as PR #126 + PR #128; see canonical audit below |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` | ▶ Next | see session handoff and two-session workflow below |

---

## Required files for the next step (v7.6.0.5)

Read these together before starting any session:

1. `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` — primary prompt
2. `prompts/handoff/session-handoff-v7.6.0.5.md` — canonical handoff with pre-merge checklist and device testing audit
3. `prompts/phaseD/v7.6.0.4-PR126-PR128-consolidated-audit-and-lessons.md` — canonical v7.6.0.4 closure audit (PR #126 + PR #128 together)

---

## v7.6.0.4 closure note

Do not treat PR #126 alone as the final closure state.

The final v7.6.0.4 shipped state is:
- feature delivery in PR #126
- post-merge regression correction in PR #128

The canonical closure audit for continuing work is:
- `prompts/phaseD/v7.6.0.4-PR126-PR128-consolidated-audit-and-lessons.md`

---

## Two-session workflow for v7.6.0.5

v7.6.0.5 introduces stateful mock-server routes and a new Playwright test group. The two-session
review pattern used for v7.6.0.4 applies here as well. See session-handoff-v7.6.0.5.md §Workflow
for the exact framing prompts.

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

Execute **v7.6.0.5** against the final shipped v7.6.0.4 baseline to add Playwright test coverage
for satellite management and close Phase D.
