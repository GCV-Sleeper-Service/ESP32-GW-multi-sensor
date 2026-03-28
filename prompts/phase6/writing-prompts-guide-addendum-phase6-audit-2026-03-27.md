# Addendum to `Docs/writing-prompts-for-coding-agents-guide.md`
## Phase 6 Prompt-Audit Derived Improvements

_Date: 2026-03-27_
_Based on: Phase 6 consolidated audits for PR #78/#82/#83/#84/#87 and current guide content._

---

## Purpose

This addendum defines concrete updates that should be merged into the guide so future prompts avoid the recurring failure modes seen in Phase 6.

---

## A) New Section to Add: “Prompt-Provided Code Must Be Production-Quality”

### Why

Phase 6 audits repeatedly show that agents implemented prompt snippets accurately, including defects. A large share of review findings were prompt-authored bugs propagated into code.

### Add to guide

Add a section (suggested placement after current §3.2) with this rule:

> Any code block provided in a prompt is normative implementation guidance and must pass the same quality bar as production code before prompt publication.

Include minimum checks by language:

- **Python:** imports at module scope, context managers for network/file handles, docstrings match behavior.
- **Shell:** locale-stable parsing (`LC_ALL=C`), input sanitization before URL interpolation.
- **JavaScript:** `escHtml()` for config/manifest text sinks, explicit null checks, `isFinite()` for numeric-to-CSS transforms.

---

## B) Expand Gap Taxonomy with Five New/Clarified Gaps

## Gap 14 — Inconsistent Guard Style in Prompt Snippets

### Why

v7.5.6.2 surfaced mixed guard styles (`truthy` vs explicit null/undefined) causing logic bugs.

### Add to guide

- Ban mixed presence-check idioms in a function body.
- Preferred standard for optional numeric/time fields: `value !== undefined && value !== null`.

## Gap 15 — Prompt-Seeded Security Sink

### Why

v7.5.6.2 had unescaped manifest-derived text in generated HTML path.

### Add to guide

- Any untrusted/config-derived string inserted into HTML must be escaped at sink.
- Prompt must list each sink in scope and expected sanitizer.

## Gap 16 — Numeric-to-CSS Without Finite Guard

### Why

v7.5.6.2 allowed NaN to propagate into style width (`"NaN%"`).

### Add to guide

- Any function mapping numeric input to CSS/DOM geometry must early-return unless `isFinite(value)`.

## Gap 17 — Under-Specified Contract Mocks

### Why

v7.5.6.4 mock endpoint initially validated only device existence, not full contract branches.

### Add to guide

- Mock prompts must include contract-lock checklist:
  1. source firmware handler to mirror,
  2. all positive/negative branches,
  3. exact success/error JSON shapes,
  4. one test per branch,
  5. explicit “no stub simplification” rule.

## Gap 18 — Fixture Composition Ripple Omissions

### Why

v7.5.6.4 changed fixture composition but left stale skip rationale text/comments.

### Add to guide

- Any fixture cardinality/composition change requires downstream text audit:
  - `test.skip()` reasons,
  - group headers/comments,
  - helper expectations/hardcoded counts.

---

## C) Additions to the Prompt Author Pre-Flight Checklist (§9)

Add the following checks:

1. **Snippet lint pass:** Run lint/static checks on prompt-provided snippets before prompt release.
2. **Contract-fidelity pass for mocked endpoints:** Verify branch parity against firmware handler.
3. **Sanitization pass:** Confirm all config/manifest-to-HTML insertions are escaped.
4. **Finite-number pass:** Confirm `isFinite` (or equivalent) exists for numeric-to-style/UI code.
5. **Locale pass for shell parsing:** Confirm `LC_ALL=C` on locale-sensitive commands.
6. **Interpolation sanitization pass:** Strip non-numeric characters before metric URL query injection.
7. **Resource-lifecycle pass:** Confirm network/file handles are explicitly closed or context-managed.
8. **Fixture ripple pass:** After fixture changes, update dependent reason strings/comments.
9. **Playwright fixture hygiene pass:** Remove unused `{ page, request, ... }` destructured fixtures.

---

## D) Additions to Test Group Guardrails (§3.11)

Add two mandatory bullets:

1. After fixture composition changes, search all skip reasons/comments for stale counts and update them.
2. Require destructured Playwright fixtures to be minimal and used.

---

## E) Additions to “Common Anti-Patterns” (§10)

Add these anti-patterns:

- “Prompt snippet compiles, therefore prompt is good” (false confidence).
- “Mock only happy-path + unknown device” for contract endpoints.
- “Copy reference code without re-auditing latent bugs.”
- “Use truthy checks for numeric/time values.”
- “Interpolate parsed shell output into URLs without sanitization.”

---

## F) Proposed Compact Template Block for Future Prompts

Add reusable template text:

```md
### Contract-Lock (Mandatory for endpoint mocks)
- Read firmware handler: <file:function>
- Implement all branches: success + each validation failure
- Match JSON response shape exactly
- Add one test per branch
- Do NOT implement a stub (e.g., device-exists-only)

### Snippet Quality Gates (Mandatory when prompt includes code)
- [ ] JS: escHtml sinks audited
- [ ] JS: null/undefined guards consistent
- [ ] JS: isFinite guard for numeric->CSS
- [ ] Shell: LC_ALL=C + metric sanitization
- [ ] Python: module-level imports + context managers
- [ ] Docs/comments aligned with actual behavior
```

---

## G) Priority Order for Updating the Guide

1. Add **Contract-Lock** and **Snippet Quality Gates** sections (highest ROI).
2. Add Gap 17 and Gap 18 taxonomy entries.
3. Add checklist items to §9 and §3.11.
4. Add anti-pattern bullets for quick reviewer scanning.

---

## H) Expected Outcome if Applied

If these updates are integrated, prompt quality should shift from “structurally strong but occasionally under-specified” to “structurally strong and execution-robust,” reducing multi-round review churn and lowering prompt-seeded defect injection in future phases (especially Phase D runtime management work).
