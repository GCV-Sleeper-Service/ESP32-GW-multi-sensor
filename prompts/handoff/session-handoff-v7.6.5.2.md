# Session Handoff — v7.6.5.2: Create dashboard.tmpl.html and build-dashboard.sh (Phase X Level 2)

_Date: 2026-04-05_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.5.1 COMPLETE. Bundle sync wired into CI and preflight. Level 1 gate passed. Entering Level 2._

---

## Project State Summary

**v7.6.5.1 is complete.** Level 1 is fully operational: 21 source modules, bundle script, CI integration, preflight check. `main` is green, 402/0 tests.

### What Level 1 delivered (v7.6.5.0–v7.6.5.1)

- `dashboard/src/` with 21 ordered module files
- `scripts/bundle-dashboard.sh` with `--write` and `--check` modes
- CI workflow runs `bundle-dashboard.sh --check` before Playwright
- `dashboard_js_bundle_sync` preflight check
- Identity gate confirmed
- Pipeline documentation updated

### What Level 1 did NOT solve

- `dashboard.html` is still manually maintained — LESSON-OPS-043 (mirror problem) still active
- Every JS change still requires a manual mirror to `dashboard.html`
- **Level 2 solves this permanently.**

---

## Phase X Progress Table

| Version | Scope | Level | Status |
|---------|-------|-------|--------|
| v7.6.4.0 | Documentation restructuring | Pre-step | ✅ Complete |
| v7.6.5.0 | Module split | Level 1 | ✅ Complete |
| v7.6.5.1 | CI + preflight wiring | Level 1 | ✅ Complete |
| **v7.6.5.2** | **Create dashboard.tmpl.html and build-dashboard.sh** | **Level 2** | **⬅️ Next** |
| v7.6.5.3 | Retire manual mirror | Level 2 | Pending |
| v7.6.5.4–v7.6.5.6 | Component model (Level 3) | Level 3 | Pending |
| v7.6.5.7–v7.6.5.8 | Test split + closure | Test/Closure | Pending |

---

## v7.6.5.2 Scope

This step proves that `dashboard.html` can be generated from a template + JS, without actually making it the canonical source yet. That transition happens at v7.6.5.3.

### What this step does

1. **Create `dashboard/dashboard.tmpl.html`** — a copy of `dashboard.html` with the entire `<script>...</script>` block replaced by `<script>\n{{JS_PLACEHOLDER}}\n</script>`.
2. **Create `scripts/build-dashboard.sh`** — Python-based exact text substitution. Injects `dashboard.js` content at `{{JS_PLACEHOLDER}}`. Supports `--write` and `--check` modes.
3. **Prove bit-for-bit equivalence** — the generated `dashboard.html` must be byte-for-byte identical to the hand-maintained version.
4. **Add `dashboard_tmpl_has_placeholder` preflight check** — verifies the template contains `{{JS_PLACEHOLDER}}`.

### The key constraint

The `<script>` block replacement must be exact. No whitespace changes. The `<script>` and `</script>` tags from the template must sit at exactly the same positions as in the original. Python's `str.replace()` with count=1 handles this correctly — no regex, no prettification.

### Key file references

- `dashboard/dashboard.html` — 4,900 lines. The `<script>` tag opens around line 936 and `</script>` closes around line 4898. Verify at HEAD before extracting.
- `dashboard/dashboard.js` — 3,955 lines (the JS being injected).

### Bit-for-bit gate

```bash
cp dashboard/dashboard.html dashboard/dashboard.html.orig
bash scripts/bundle-dashboard.sh --write
python3 scripts/render_sensor_config.py --write
bash scripts/build-dashboard.sh --write
diff dashboard/dashboard.html dashboard/dashboard.html.orig
# Must exit 0
```

If the diff shows any differences, the template extraction has a whitespace or encoding problem that must be fixed before proceeding to v7.6.5.3.

### Acceptance criteria

- [ ] `dashboard.tmpl.html` exists with exactly one `{{JS_PLACEHOLDER}}`
- [ ] `build-dashboard.sh` produces byte-for-byte identical output vs. hand-maintained version
- [ ] `diff` exits 0
- [ ] `generate-header.sh` produces identical `dashboard.h`
- [ ] All 402 tests pass across all four fixture sets
- [ ] Preflight passes (including new template placeholder check)

---

## Pre-merge Checklist for v7.6.5.2

- [ ] Read the coding agent prompt completely
- [ ] Read this handoff completely
- [ ] Verify `<script>` block boundaries in `dashboard.html` before extraction
- [ ] Run the bit-for-bit gate: diff must exit 0
- [ ] Verify `build-dashboard.sh --check` passes
- [ ] Run CI-exact Playwright across all fixture sets
- [ ] Confirm `dashboard.html` content is identical (diff shows nothing)
- [ ] Confirm no source modules were modified

---

## Critical Rules Relevant to v7.6.5.2

| # | Rule | Why Relevant |
|---|------|-------------|
| 4 | Preflight must pass | New placeholder check |
| 5 | CI-exact `FIXTURE_SET=` runs | Full acceptance gate |
| 6 | Mirror JS ↔ HTML | Still active — `dashboard.html` is still hand-maintained at this step |
| 20 | Session log mandatory | Closure evidence |
| 21 | Instruction Compliance Output | PR deliverable |
| 37 | Full regeneration pipeline | Pipeline grows with `build-dashboard.sh` |

---

## Workflow for v7.6.5.2

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Read the coding agent prompt and this handoff completely
2. Ask human if PR for this step. If PR has not been open, **open a NEW coding agent session outside of this chat** and paste the prompt
3. Agent creates template and build script, proves equivalence
4. Review the PR — the critical review point is the diff gate output, check automatically posted reviews and additional external reviews that might be posted
5. Merge, tag `v7.6.5.2`
6. Produce consolidated audit and lessons file (see Post-PR Closure section below)
7. Check and update session handoff for v7.6.5.3 if necessary (see Post-PR Closure section below)
8. Check and update agent's prompt for v7.6.5.3 if necessary (see Post-PR Closure section below)

---

## Post-PR Closure Deliverables for v7.6.5.2

### 1. Consolidated Audit

**File:** `prompts/phaseX/v7.6.5.2-PR<NN>-consolidated-audit-and-lessons.md`
**Use template file:** `prompts/phaseX/pr-audit-question-template.md`
**Format:** Same structure as `prompts/phaseX/v7.6.4.0-PR131-consolidated-audit-and-lessons.md`

Use stable core questions from `prompts/phaseX/pr-audit-question-template.md`  plus Level-Specific Supplements for Level 2. Key question: did the bit-for-bit gate pass?

- Did the bit-for-bit diff gate pass (generated HTML = original HTML)?
- Was whitespace handling exact (no prettification, no encoding changes)?
- Does `bump-version.sh` now use the pipeline instead of `sed` on `dashboard.html`?
- Did the `<!-- GENERATED -->` header get added to `dashboard.html` output?

### 2. Readiness for v7.6.5.3

v7.6.5.3 makes the generated HTML canonical. Before proceeding, confirm:
- `build-dashboard.sh --check` passes consistently
- The template injection is exact (no whitespace drift)
- The pipeline `bundle → generator → build-html → minify → header` produces clean output

### 3. Session Handoff for v7.6.5.3

**File:** `prompts/handoff/session-handoff-v7.6.5.3.md` is already produced,  if this or previous steps reveals something unexpected, provide a patch for this and future step handoff files if necessary.  

### 4. Check Agent's prompt for v7.6.5.3

**File:** `prompts/phaseX/v7.6.5.3-implementation-instructions-for-coding-agent.md` is already produced, provide a patch for this and future step prompts files if necessary.  

---

## Device Testing

**Not applicable at v7.6.5.2.** The template and build script are created but `dashboard.html` is not yet generated — it's still hand-maintained. Device testing becomes mandatory at v7.6.5.3 when the generated version becomes canonical.

---

_End of session handoff document._
