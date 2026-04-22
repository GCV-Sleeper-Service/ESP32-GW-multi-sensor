# Phase V Pre-Closure Cleanup — Agent Prompt

_Documentation-only PR. No firmware, dashboard, or test changes._
_Branch: `docs/phaseV-pre-closure-cleanup`_
_Target: `main`_
_Date: 2026-04-22_

---

## Context

Phase V (v7.6.7.0–v7.6.9.5) is closing. The pre-closure readiness assessment identified 5 BLOCKING and 5 SHOULD-FIX documentation gaps that must be resolved before the closure analysis can run. This PR fixes all 10 items in a single commit.

**No code changes. No pipeline regeneration. No Playwright runs needed.** This is a documentation/metadata cleanup only.

---

## §1 — Required Reading

Before making any edits, read these files:

1. `prompts/handoff/phaseV/phaseV-pre-closure-readiness-assessment.md` — the assessment that produced this task list
2. `prompts/prompt-index-and-workflow.md` — lines 1–4, 130–170, 214–283 (header, phase summaries, critical rules)
3. `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — lines 66–79 (RV-03 section)
4. `Docs/phase-V-implementation-plan.md` — lines 1233–1244 (version table)
5. `Docs/lessons/index.md` — lines 210–218 (tail of index)
6. `prompts/handoff/phaseV/phaseV-results.md` — lines 148–160 (Critical Rules and Lessons tables)
7. `Docs/esp32-board-selection-guide.md` — lines 85–103 (C3 memory table)
8. `Docs/session-log-2026-04-20-v7.6.9.5.md` — device verification table (source data for S3)
9. `Docs/session-log-2026-04-17-v7.6.9.4.md` — full file (source data for consolidated audit)

---

## §2 — Pre-Implementation Verification

```bash
git checkout main && git pull
cat VERSION
# Must read: 7.6.9.5
```

⛔ CHECKPOINT: If VERSION is not 7.6.9.5, STOP.

```bash
git checkout -b docs/phaseV-pre-closure-cleanup
```

---

## §3 — Implementation Tasks

### BLOCKING Items (B1–B5)

#### B1. Update `prompts/prompt-index-and-workflow.md`

**B1a.** Replace line 4 (the header line):

FROM:
```
_Last updated: 2026-04-12 — Phase Y closure (v7.6.6.8). Phase Y complete. Critical Rules 58–63 added. Current Phase: **Phase V** (pending)._
```

TO:
```
_Last updated: 2026-04-22 — Phase V closure (v7.6.9.5). Phase V complete. Critical Rule 64 added. Current Phase: **Phase VX** (pending)._
```

**B1b.** Insert a new Phase V section AFTER the Phase Y section (after line 169, before line 171 "### Phase 7"). Insert these lines:

```markdown

### Phase V — Bug Fixing, Optimization & Security Hardening (v7.6.7.0–v7.6.9.5) ✅ COMPLETE

Phase V complete (v7.6.7.0–v7.6.9.5, 2026-04-13 to 2026-04-20). Security hardening (auth guards on all write endpoints, SEC-ADR-001), dashboard enhancements (device cards, CSV export, manifest), heap-adaptive history cap (#139 partial), C3 stack override fix (BUG-083). 2 bugs fixed (BUG-082, BUG-083), 3 new LESSON-OPS entries (126–128), 1 LESSON-SEC entry (LESSON-SEC-001), Critical Rule 64 added. Results: `prompts/handoff/phaseV/phaseV-results.md`. Plan: `Docs/phase-V-implementation-plan.md`. Prompts: `prompts/phaseV/`.

Phase V used a different prompt methodology from Phases D/X/Y: Claude advisory sessions producing agent prompts (two-step pattern), Kiro/GPT/Codex executing those prompts, Perplexity three-turn PR review. Prompts follow the naming pattern `v7.6.X.Y-agent-prompt-gpt-codex.md` and `v7.6.X.Y-claude-two-step.md` rather than the standard `implementation-instructions-for-coding-agent.md` convention.

**Version range:** v7.6.7.0–v7.6.9.5 (13 version-step PRs: #176–#184, #191–#193, #195; plus #194 docs, #197 issue sweep)
**Plan:** `Docs/phase-V-implementation-plan.md`
**Addendum:** `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md`
**Capacity study:** `Docs/phase-V-capacity-study.md`
**Audit Template:** `prompts/phaseV/consolidated-audit-template-phaseV.md`

| Version | Scope | Prompt File | Handoff | Status |
|---------|-------|-------------|---------|--------|
| v7.6.7.0 | V1-A/B/C: Proxy fix, NAS history disable, logger level | `prompts/phaseV/v7.6.7.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.7.0.md` | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix (Rule 40) | `prompts/phaseV/v7.6.7.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.7.1.md` | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Version badge, dead code, import comment | `prompts/phaseV/v7.6.7.2-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.7.2.md` | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | _(operator-directed, no formal prompt)_ | _(no handoff — V1 measurement protocol)_ | ✅ Complete |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status field split | `prompts/phaseV/v7.6.8.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.8.0.md` | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + heap cap + DoS cooldown + SEC-ADR | `prompts/phaseV/v7.6.8.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.8.1.md` | ✅ Complete |
| v7.6.8.2 | V2-H: Socket reduction (V2-I/J blocked) | `prompts/phaseV/v7.6.8.2-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.8.2.md` | ✅ Complete |
| v7.6.9.0 | V3-A: Dashboard device card cleanup | `prompts/phaseV/v7.6.9.0-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.0.md` | ✅ Complete |
| v7.6.9.1 | V3-B/C: Satellite hostname/IP + CSV role column | `prompts/phaseV/v7.6.9.1-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.1.md` | ✅ Complete |
| v7.6.9.2 | V3-D/E: Manifest-driven export + AGG-ADR | `prompts/phaseV/v7.6.9.2-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.2.md` | ✅ Complete |
| v7.6.9.3 | V3-F: Struct audit / Phase V preliminary closure | `prompts/phaseV/v7.6.9.3-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.3.md` | ✅ Complete |
| v7.6.9.4 | V4: Heap-adaptive history cap + boot sequencing | `prompts/phaseV/v7.6.9.4-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.4.md` | ✅ Complete |
| v7.6.9.5 | V5: C3 httpd stack override fix (BUG-083) | `prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md` | `prompts/handoff/phaseV/session-handoff-v7.6.9.5.md` | ✅ Complete |
```

**B1c.** Update line 173 of the Phase 7 section:

FROM:
```
**`main` is at v7.6.5.8. Phase 7 starts at v7.7.0.0.**
```

TO:
```
**`main` is at v7.6.9.5. Phase VX (v7.6.10.x) runs first, then Phase VY planning, then Phase 7 starts at v7.7.0.0.**
```

**B1d.** Add Critical Rule 64 to the Critical Rules table. Insert after line 283 (Rule 63):

```
| 64 | Checkpoint grep assertions in agent prompts must be mechanically derived from the replacement block in the same prompt — never estimated from memory or a prior session. Mismatched counts cause agents to loop on phantom failures or silently accept wrong state. | LESSON-OPS-126 / v7.6.9.4 |
```

⛔ CHECKPOINT B1: Verify all four sub-edits:
```bash
grep -c "2026-04-22" prompts/prompt-index-and-workflow.md
# Expected: >= 1
grep -c "Phase V — Bug Fixing" prompts/prompt-index-and-workflow.md
# Expected: 1
grep -c "v7.6.9.5" prompts/prompt-index-and-workflow.md
# Expected: >= 2
grep "^| 64 " prompts/prompt-index-and-workflow.md
# Expected: | 64 | Checkpoint grep...
```

---

#### B2. Amend SEC-ADR-001 RV-03 section

In `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`, append the following AFTER line 78 (after the "Residual exposure" paragraph for RV-03, before the `---` separator at line 80):

```markdown

**Post-Phase V update (2026-04-20):**
BUG-078 (v7.6.0.1) fixed the `init_response_()` HTTP status code mapping that was returning 500 instead of 401 for unauthenticated requests. The browser now receives a proper 401 and shows its native Basic Auth dialog. Dashboard successfully polls all auth-gated endpoints through Cloudflare Tunnel after the user enters credentials. The remaining issue — random mid-session auth re-prompt dialogs — is a UX enhancement, not a security vulnerability. It is tracked as #196 and deferred to Phase VX (v7.6.10.4). The originally planned v7.6.9.6 (narrow `/api/status` un-strip + SEC-ADR amendment) was dropped because the issue self-resolved.
```

⛔ CHECKPOINT B2:
```bash
grep -c "BUG-078" Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md
# Expected: >= 1
grep -c "Phase VX" Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md
# Expected: >= 1
```

---

#### B3. Add V5 and V6 rows to implementation plan version table

In `Docs/phase-V-implementation-plan.md`, insert two rows AFTER line 1242 (the V4 row), BEFORE the Phase 7 row:

```
| **Phase V — V5** | **v7.6.9.5** | **C3 httpd stack override fix (BUG-083) — C3 template missing `external_components`** |
| ~~Phase V — V6~~ | ~~v7.6.9.6~~ | ~~Dropped — Cloudflare polling issue self-resolved (BUG-078 fixed 401→500 in v7.6.0.1); auth UX deferred to Phase VX~~ |
```

⛔ CHECKPOINT B3:
```bash
grep -c "V5.*v7.6.9.5" Docs/phase-V-implementation-plan.md
# Expected: 1
grep -c "V6.*Dropped" Docs/phase-V-implementation-plan.md
# Expected: 1
```

---

#### B4. Add LESSON-SEC-001 to lessons index

In `Docs/lessons/index.md`, append after line 217 (the LESSON-OPS-128 row):

```
| LESSON-SEC-001 | build-pipeline.md |
```

Also update line 3 of the file:

FROM:
```
_Last updated: 2026-04-08 — Documentation reorganization (Issue #140)._
```

TO:
```
_Last updated: 2026-04-22 — Phase V closure cleanup._
```

⛔ CHECKPOINT B4:
```bash
grep -c "LESSON-SEC-001" Docs/lessons/index.md
# Expected: 1
```

---

#### B5. Complete the "New Lessons" and "New Critical Rules" tables in `phaseV-results.md`

In `prompts/handoff/phaseV/phaseV-results.md`:

**B5a.** Replace the Critical Rules table (lines 150–152):

FROM:
```
| # | Rule | Source |
|---|---|---|
| Rule | Checkpoint grep counts must be mechanically derived from the replacement block in the same prompt, not estimated from memory. | v7.6.9.4 |
```

TO:
```
| # | Rule | Source |
|---|---|---|
| 64 | Checkpoint grep assertions in agent prompts must be mechanically derived from the replacement block in the same prompt — never estimated from memory or a prior session. | LESSON-OPS-126 / v7.6.9.4 |
```

**B5b.** Replace the Lessons table (lines 156–159):

FROM:
```
| # | Lesson | Source |
|---|---|---|
| LESSON-SEC-001 | All write endpoints require auth | v7.6.8.0 |
| LESSON-OPS-126 | Checkpoint grep assertions must be validated against the actual replacement block in the same prompt | v7.6.9.4 |
```

TO:
```
| # | Lesson | Source |
|---|---|---|
| LESSON-SEC-001 | All write endpoints require auth | v7.6.8.0 |
| LESSON-OPS-126 | Checkpoint grep assertions must be validated against the actual replacement block in the same prompt | v7.6.9.4 |
| LESSON-OPS-127 | `std::string::reserve()` is an allocation hint, not a size constraint — does not prevent unbounded `.append()` growth | v7.6.9.4 / BUG-082 |
| LESSON-OPS-128 | Verify configuration equivalence before theorizing about measurement discrepancies | v7.6.9.5 / BUG-083 |
```

⛔ CHECKPOINT B5:
```bash
grep -c "LESSON-OPS-127" prompts/handoff/phaseV/phaseV-results.md
# Expected: 1
grep -c "LESSON-OPS-128" prompts/handoff/phaseV/phaseV-results.md
# Expected: 1
grep "^| 64 " prompts/handoff/phaseV/phaseV-results.md
# Expected: one line with Rule 64
```

---

### SHOULD-FIX Items (S1–S5)

#### S1. Add v7.6.9.5 uniform stack note to board selection guide

In `Docs/esp32-board-selection-guide.md`, insert AFTER line 103 (after the "Mitigation on C3" paragraph, before "### ESP32-S3"):

```markdown

**httpd stack sizing (v7.6.9.5 finding):** Peak httpd stack usage is ~3,400 B across all tested architectures — RISC-V (C3) and Xtensa (WROOM/S3). The 16 KB httpd stack override (`firmware/local_components/web_server_idf/`) is uniform across all boards. No architecture-dependent sizing is needed. See `Docs/phase-V-capacity-study.md` for the full task stack table.
```

⛔ CHECKPOINT S1:
```bash
grep -c "v7.6.9.5 finding" Docs/esp32-board-selection-guide.md
# Expected: 1
```

---

#### S2. Create consolidated audits for v7.6.9.4 and v7.6.9.5

Create two files from the template at `prompts/phaseV/consolidated-audit-template-phaseV.md`.

**File 1:** `prompts/phaseV/v7.6.9.4-PR193-consolidated-audit-and-lessons.md`

Contents:

```markdown
# Consolidated Audit — v7.6.9.4: Heap-Adaptive History Cap + Boot Sequencing

_Phase V Step V4. Completed 2026-04-17._
_PR #193 (`codex/v7.6.9.4-adaptive-cap-boot-gate-20260417`)._
_Also: PR #194 (docs: BUG-082 + LESSON-OPS-127 post-merge documentation)._

---

## Internal Audit (Architectural Advisor)

### 1. Did the PR match the scope defined in the step prompt? Any deviations?

Scope match: YES. The PR delivered:
- Server-side: adaptive cap `clamp(free_heap/3, 12000, 60000)` replacing fixed 60 KB cap at both history handler sites
- Client-side: `_v7_9_4_kickHistoryOnce()` status-gated history boot with 15 s fallback timer

Deviation: The `Promise.resolve(loadHistory()).catch(...)` wrapper was a bug fix discovered during Playwright testing — `loadHistory()` returns `undefined` on the happy path, so bare `.catch()` would throw. Classified: harmless / necessary.

### 2. Did the codebase state match the prompt's assumptions?

YES. Line numbers and function signatures matched. The `csv.reserve(std::min(est_bytes, (size_t)60000))` pattern was at both expected sites.

### 3. Autonomous decisions not specified in the prompt?

The `_v7_9_4_` prefix on `kickHistoryOnce` and `historyKicked` was an agent decision to namespace the variables. Classified: harmless — prevents collision with future code.

### 4. New lessons or Critical Rules?

- **BUG-082:** `csv.reserve()` does not truncate — documented post-merge in PR #194
- **LESSON-OPS-127:** `std::string::reserve()` is an allocation hint, not a size constraint
- **LESSON-OPS-126:** Checkpoint grep assertions must be validated against the actual replacement block (Critical Rule 64 candidate — assigned during Phase V closure)

### 5. Context that carries forward to next step

- BUG-082 deliberately deferred to Phase 7 (chunked streaming eliminates single-response CSV)
- WROOM history export crash persists for large NVS — raw partition dump extracted offline via `esptool read_flash 0x370000 0x80000`
- Device flashing/testing was skipped by operator request — device gate incomplete

## Acceptance Criteria Verification

| Criterion | Result |
|---|---|
| WROOM `/history/office/temp` returns 200 with truncated CSV | NOT VERIFIED (device test skipped) |
| C3 history response sized to ~22 KB | NOT VERIFIED (device test skipped) |
| S3 history response capped at 60 KB | NOT VERIFIED (device test skipped) |
| Dashboard history loads within 15 s | NOT VERIFIED (device test skipped) |
| Playwright all fixtures pass | PASS (102+102+8+9+11 = 232 pass, 0 fail) |
| Preflight passes | PASS |

## PR Review Summary

Reviewed by GitHub Copilot and OpenAI Codex automated reviewers. Both independently identified BUG-082 (`reserve()` ≠ truncation). Decision: merge as-is, defer fix to Phase 7.
```

**File 2:** `prompts/phaseV/v7.6.9.5-PR195-consolidated-audit-and-lessons.md`

Contents:

```markdown
# Consolidated Audit — v7.6.9.5: C3 httpd Stack Override Fix

_Phase V Step V5. Completed 2026-04-20._
_PR #195 (`v7.6.9.5-c3-httpd-stack-fix`)._

---

## Internal Audit (Architectural Advisor)

### 1. Did the PR match the scope defined in the step prompt? Any deviations?

Scope match: YES. The PR delivered:
- Added missing `external_components` block to C3 template YAML (`firmware/esp32-c3-multi-sensor.yaml`)
- Added `external_components` preflight check to `scripts/preflight.sh`
- Created `scripts/stress-test-httpd-stack.sh` for automated httpd stack watermark measurement

No deviations. Scope was narrow and well-defined after BUG-083 root cause was confirmed.

### 2. Did the codebase state match the prompt's assumptions?

YES. The C3 template was confirmed missing `external_components` while WROOM and S3 board profiles had it. Root cause: `render_sensor_config.py` passes `external_components` through from board profiles, but the C3 template is the committed source YAML, not a generated artifact — it was never updated when the local component override was created in v7.6.8.0.

### 3. Autonomous decisions not specified in the prompt?

None. PR #195 was a rework after the first attempt failed the device gate.

### 4. New lessons or Critical Rules?

- **BUG-083:** C3 template YAML missing `external_components` — httpd stack override inactive since v7.6.8.0
- **LESSON-OPS-128:** Verify configuration equivalence before theorizing about measurement discrepancies

### 5. Context that carries forward to next step

- v7.6.9.5 is the actual Phase V closure version (v7.6.9.6 dropped)
- Uniform httpd stack watermark ~12.8 KB across all architectures — no per-SoC tuning needed
- `scripts/stress-test-httpd-stack.sh` available for future stack measurements

## Acceptance Criteria Verification

| Criterion | Result |
|---|---|
| C3 `external_components` in generated YAML | PASS |
| C3 httpd_stack_watermark_bytes >= 10000 | PASS (12,768 B) |
| WROOM httpd_stack_watermark_bytes >= 10000 | PASS (12,964 B) |
| S3 httpd_stack_watermark_bytes >= 10000 | PASS (12,944 B) |
| Stress test minimum watermark >= 10000 | PASS (12,768 B on C3) |
| `/api/status` shape unchanged | PASS (all boards) |
| Playwright all fixtures pass | PASS (232 pass, 0 fail) |
| Preflight passes | PASS |
```

---

#### S3. Update device test results in `phaseV-results.md`

In `prompts/handoff/phaseV/phaseV-results.md`, replace the entire "Device Test Results" section (lines 67–88) with:

```markdown
## Device Test Results

### v7.6.9.4 Device Tests — SKIPPED

Hardware flashing and device testing were skipped by operator request during the v7.6.9.4 session. OTA flashing was attempted but interrupted. See `Docs/session-log-2026-04-17-v7.6.9.4.md` for details.

### v7.6.9.5 Final Device State (Phase V closure baseline)

| Board | httpd_stack_watermark_bytes | free_heap | external_components | /api/status shape |
|---|---|---|---|---|
| C3 (192.168.120.189) | 12,768 | 57,144 | PASS (added to template) | PASS |
| WROOM (192.168.120.190) | 12,964 | 36,244 | PASS (existing) | PASS |
| S3 (192.168.120.191) | 12,944 | 54,420 | PASS (existing) | PASS |

Stress test minimum watermark (C3, 5-wave): 12,768 B (threshold: >= 10,000 B) — PASS.

All boards running with 16 KB httpd stack override. Uniform peak usage ~3,400 B across RISC-V and Xtensa architectures.
```

⛔ CHECKPOINT S3:
```bash
grep -c "12768" prompts/handoff/phaseV/phaseV-results.md
# Expected: >= 1
grep -c "12964" prompts/handoff/phaseV/phaseV-results.md
# Expected: 1
```

---

#### S4. Add document reference to GitHub issue #196

Using the GitHub API, add a comment to issue #196:

```
Design document: `prompts/handoff/dashboard-auth-refactor-issue.md`
```

If GitHub API access is not available, document this as a manual operator action in the session log.

---

#### S5. (Covered by B5a — Rule 64 number assignment)

No additional action needed. B5a assigns Rule 64.

---

## §4 — Post-Implementation Verification

```bash
# Verify no code files changed (documentation only)
git diff --name-only | grep -v '\.md$'
# Expected: empty (no non-markdown files)

# Verify all BLOCKING checkpoints
grep -c "2026-04-22" prompts/prompt-index-and-workflow.md          # >= 1
grep -c "Phase V — Bug Fixing" prompts/prompt-index-and-workflow.md # 1
grep "^| 64 " prompts/prompt-index-and-workflow.md                 # Rule 64 row
grep -c "BUG-078" Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md  # >= 1
grep -c "V5.*v7.6.9.5" Docs/phase-V-implementation-plan.md        # 1
grep -c "LESSON-SEC-001" Docs/lessons/index.md                     # 1
grep -c "LESSON-OPS-127" prompts/handoff/phaseV/phaseV-results.md  # 1
grep -c "LESSON-OPS-128" prompts/handoff/phaseV/phaseV-results.md  # 1

# Verify SHOULD-FIX checkpoints
grep -c "v7.6.9.5 finding" Docs/esp32-board-selection-guide.md     # 1
grep -c "12768" prompts/handoff/phaseV/phaseV-results.md           # >= 1
ls prompts/phaseV/v7.6.9.4-PR193-consolidated-audit-and-lessons.md # exists
ls prompts/phaseV/v7.6.9.5-PR195-consolidated-audit-and-lessons.md # exists
```

---

## §5 — Commit and PR

```bash
git add -A
git commit -m "docs: Phase V pre-closure cleanup (10 items from readiness assessment)

BLOCKING fixes:
- B1: prompt-index-and-workflow.md updated with Phase V summary, Rule 64
- B2: SEC-ADR-001 RV-03 amended with BUG-078 resolution + Phase VX deferral
- B3: Implementation plan version table — V5 and V6 (dropped) rows added
- B4: LESSON-SEC-001 added to lessons index
- B5: phaseV-results.md lessons/rules tables completed (LESSON-OPS-127, -128)

SHOULD-FIX:
- S1: Board selection guide — uniform stack sizing note (v7.6.9.5)
- S2: Consolidated audits for v7.6.9.4 (PR#193) and v7.6.9.5 (PR#195)
- S3: Device test results updated with v7.6.9.5 final measurements
- S4: Issue #196 document reference (manual action if API unavailable)

No code changes. No pipeline regeneration. Documentation only."

git push origin docs/phaseV-pre-closure-cleanup
# Create PR targeting main
```

---

## §6 — Session Log

Record the following in your session output:

| Check | Result |
|---|---|
| All B1–B5 checkpoints pass | |
| All S1–S3 checkpoints pass | |
| S4 GitHub comment posted (or flagged for operator) | |
| Consolidated audit files created (2 files) | |
| No non-markdown files modified | |
| `git diff --stat` line count | |

---

## ⛔ Anti-Patterns — Do NOT

1. Do NOT run any pipeline scripts (`render_sensor_config.py`, `generate-fixtures.js`, etc.)
2. Do NOT modify any `.js`, `.h`, `.yaml`, `.html`, `.json`, or `.sh` files (exception: none in this PR)
3. Do NOT change the VERSION file
4. Do NOT edit generated artifacts (`dashboard.js`, `dashboard.html`, `dashboard.h`, board YAMLs)
5. Do NOT reformat or restructure existing content beyond what is specified — surgical insertions only

---

_End of Phase V pre-closure cleanup agent prompt._
