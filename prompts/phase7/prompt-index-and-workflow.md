# Phase 7 — Prompt Index and Workflow

_Prompt management for v7.7.x per-device persistence implementation_

---

## Step Index

| Step | Status | Prompt file | Risk | Sessions |
|---|---|---|---|---|
| v7.7.0.0 | ⏳ | `v7.7.0.0-implementation-instructions-for-coding-agent.md` | Low | 1–2 |
| v7.7.0.1 | ⏳ | `v7.7.0.1-implementation-instructions-for-coding-agent.md` | Medium | 2–3 |
| v7.7.0.2 | ⏳ | To be created from template (restore engine + budget) | High | 3–4 |
| v7.7.0.3 | ⏳ | To be created from template (wire engine + storage stats) | Medium-High | 2–3 |
| v7.7.1.0 | ⏳ | `v7.7.1.0-implementation-instructions-for-coding-agent.md` | High | 2–3 |
| v7.7.1.1 | ⏳ | To be created from template (per-device delete) | Medium | 1–2 |
| v7.7.1.2 | ⏳ | To be created from template (dashboard storage UI) | Low-Medium | 1–2 |
| v7.7.2.0 | ⏳ | To be created from template (per-device export) | Low | 1 |
| v7.7.2.1 | ⏳ | To be created from template (per-device import merge) | Medium | 2–3 |
| v7.7.2.2 | ⏳ | To be created from template (multi-device bundle) | Medium | 2 |
| v7.7.2.3 | ⏳ | To be created from template (regression + closure) | Low | 1 |

**Detailed prompts completed for highest-risk steps:** v7.7.0.0, v7.7.0.1, v7.7.1.0

**Remaining prompts** should be created from the template below before each step begins, following the methodology in `Docs/writing-prompts-for-coding-agents-guide.md`. Key rule: read the actual implementation code line by line before writing the prompt. The prompts above were written against the v7.5.4.0 codebase; by the time you reach v7.7.0.2, the codebase will have changed (new functions added in v7.7.0.0 and v7.7.0.1). Update the Required Reading sections to reference the new functions.

---

## Workflow Per Step

1. **Create prompt** — if not already created, write from template. Include Required Reading that references actual line numbers and function names from the current codebase.
2. **Run pre-condition checks** — verify baseline is green before starting
3. **Execute** — hand prompt to coding agent
4. **Review** — verify all acceptance criteria before creating PR
5. **Device test** — if marked required in the prompt
6. **Merge and tag** — per post-merge instructions
7. **Update this index** — mark step complete with date

---

## Prompt Template for Remaining Steps

```markdown
# v7.7.X.Y — [Step Title] — Coding Agent Prompt

_Full self-contained implementation instructions for the coding agent_
_Date: <DATE>_

[If high risk: **⚠️ HIGH RISK — [reason]**]

---

## 1. Repository & Setup

\```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
\```

---

## 2. Required Reading (MUST complete before any changes)

[List specific files with SPECIFIC FUNCTION NAMES and LINE NUMBERS.
Reference the actual codebase at the time this prompt is written.
Call out TRAPS in the code — functions that look like they do one thing
but actually do another, or have hidden assumptions.]

---

## 3. Current Status

[What the previous step delivered. What was device-tested and confirmed.
What Playwright tests are passing. Current date placeholder.]

---

## 4. Pre-condition Checks

\```bash
npx playwright test --project=chromium
npx playwright test --project=firefox
bash scripts/preflight.sh
\```

---

## 5. Exact Scope

[Step-by-step with code examples. Trace the COMPLETE data path:
source → transform → persist/read → output.
Every function that needs to be written or modified, with
parameter types and return types.

For firmware changes: show the struct layout, the NVS key format,
the error handling pattern.

For dashboard changes: show the HTML structure, the JS function
signature, the API call and response handling.

For test changes: show the test structure, the assertion pattern,
the fixture data format.]

---

## 6. Do NOT

[Explicit scope boundaries. What the agent must NOT touch.
Reference by function name, not just concept.]

---

## 7. Critical Rules

[Numbered list. Include ALL applicable rules from previous steps plus
any new rules specific to this step. Reference BUG-XXX and LESSON-OPS-XXX.]

---

## 8. Documentation Updates (mandatory)

[changelog.md entry, bugs-and-lessons-learned.md entries]

---

## 9. Review Checklist

[Checkbox list. Every acceptance criterion from the implementation plan
plus any additional verifications discovered during prompt writing.]

---

## 10. Device Testing

[If required: exact curl commands and expected output.
If not required: state why (e.g., "test-only step, no firmware changes")]

---

## 11. Post-merge tag

\```bash
git pull origin main
git tag -a v7.7.X.Y -m "Phase 7 Step N: [description]"
git push origin v7.7.X.Y
\```
```

---

## NVS Persistence Guardrails (include in EVERY prompt)

These rules apply to ALL Phase 7 prompts. Include them in every prompt's Critical Rules section:

1. `sizeof(DeviceSegment)` MUST remain 226 bytes — add `static_assert` if not present
2. `sizeof(DeviceHistoryMeta)` MUST remain 36 bytes
3. `DEV_HIST_MAGIC` (0x44485632) MUST differ from `HISTORY_META_MAGIC` (0x48535636)
4. NVS key lengths: meta key ≤ 11 chars, segment key ≤ 15 chars — HARD LIMIT
5. NVS handles MUST be closed on every code path, especially error paths
6. `nvs_commit()` MUST be called after all writes before closing
7. `maybe_yield_nvs_scan_()` MUST be called between device iterations (BUG-043)
8. Never alias `NUM_SENSORS = NUM_DEVICES` (BUG-045)
9. Old v7.x keys MUST NOT be deleted (rollback safety until v7.7.2.3)
10. EventSource callbacks must be nulled before `.close()` (BUG-049)
11. Mirror all `dashboard.js` changes to `dashboard.html` (LESSON-OPS-043)
12. Regenerate `dashboard.h` via `scripts/generate-header.sh` after any HTML change (LESSON-OPS-055)
```
