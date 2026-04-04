# Coding Agent Prompt Index and Workflow

_Single source of truth for implementation-prompt status._
_Last updated: 2026-04-03 — v7.6.0.4 closed via PR #126 + PR #128 follow-up; v7.6.0.5 next._

---

## Current status snapshot

### Phase D — Runtime Satellite Management (v7.6.0.x)

| Version | Scope | Primary Prompt | Status | Notes |
|---|---|---|---|---|
| v7.6.0.0 | NVS satellite persistence layer | `prompts/phaseD/v7.6.0.0-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.1 | `POST /api/aggregator/add-satellite` | `prompts/phaseD/v7.6.0.1-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.2 | `DELETE /api/aggregator/satellite/{id}` | `prompts/phaseD/v7.6.0.2-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.3 | `POST /api/aggregator/test-satellite` | `prompts/phaseD/v7.6.0.3-implementation-instructions-for-coding-agent.md` | ✅ Complete | merged |
| v7.6.0.4 | Dashboard add/remove/test UI | `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md` | ✅ Complete | shipped as PR #126 + PR #128 follow-up |
| v7.6.0.5 | Playwright tests + Phase D closure | `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md` | ▶ Next | use GP addendum + v7.6.0.5 handoff |

### Required companion files for the next Phase D step

For v7.6.0.5, use these together:

- `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent.md`
- `prompts/phaseD/v7.6.0.5-implementation-instructions-for-coding-agent-GP.md`
- `prompts/handoff/session-handoff-v7.6.0.5.md`

### Closure note for v7.6.0.4

Do not treat PR #126 alone as the final closure state.

The final v7.6.0.4 shipped state is:
- feature delivery in PR #126,
- post-merge regression correction in PR #128.

The corrected closure audit for continuing work is:
- `prompts/phaseD/v7.6.0.4-PR126-consolidated-audit-and-lessons-GP.md`

---

## Workflow reminder

For each implementation step:

1. read the primary prompt fully,
2. read all required-reading files listed there,
3. apply any newer GP addenda or handoff corrections,
4. implement only the scoped step,
5. run required validation,
6. update the session log and workflow status.

---

## Next action

The next coding-agent session should execute **v7.6.0.5** against the final shipped v7.6.0.4 baseline and close Phase D.

---
