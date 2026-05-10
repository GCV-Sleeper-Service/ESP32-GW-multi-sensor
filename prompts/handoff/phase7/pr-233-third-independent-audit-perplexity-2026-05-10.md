# PR #233 Third-Party Audit — Perplexity AI (Claude Sonnet 4.6) — 2026-05-10

## §1 — Verdict

**CONDITIONAL PASS**

Zero HIGH-severity findings. Three MEDIUM and four LOW findings are documented below. The implementation prompts v7.7.1.2 / v7.7.1.3 / v7.7.1.4 may be dispatched. All findings are suitable for post-merge tracking under issue #228 §C or future batches.

---

## §2 — Summary Table

### §2.A — Doctrinal Compliance

| Check | Result | Note |
|-------|--------|------|
| A1 — v7.7.1.3 §6 Task Group 3 has both C3 .189 AND WROOM-32D .170 blocks | ✅ PASS | Both blocks present with correct IPs |
| A2 — v7.7.1.4 §6 boot-path Task Group has both production satellites + cross-SoC-family note | ✅ PASS | "C3 SuperMini (.189) — required" and "WROOM-32D (.170) — required" blocks present; cross-SoC note explicit |
| A3 — `bump-version.sh` is Step 0 in §6 of v7.7.1.3 AND v7.7.1.4, before first `esphome compile` | ✅ PASS | Both prompts show "### Step 0: Version bump (FIRST — before any code changes or compile)" |
| A4 — Every embedded call to `find_partition_size_bytes_()` in v7.7.1.4 uses the 3-arg form; §2 verification gate re-greps live header | ✅ PASS | Call uses `find_partition_size_bytes_(HISTORY_PARTITION_LABEL, ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_NVS)`; §2 gate includes `grep -A2 'find_partition_size_bytes_'` with 3-arg expected form |
| A5 — All three `static_assert` lines in v7.7.1.2 are in commented-out 2-phase form; 6-step procedure; Phase 1/Phase 2 labels; cross-board ABI note at step 5 | ✅ PASS | All three `static_assert` lines are `// static_assert(sizeof(X) == <N_MEASURED>, …)`. 6 ordered steps. "Phase 1 (initial compile, sizing only): leave commented out." Step 5 contains cross-board ABI note. |
| A6 — v7.7.1.4 §3 contains full inlined whitelist; matches canonical "Scope-guard whitelist" byte-for-byte (6 source + 6 regenerated-artifact bullets) | ✅ PASS (see §C.N3 for byte-for-byte verification) | Full list inlined; cross-reference "see v7.7.1.2 §3" removed |
| A7 — `session-handoff-v7.7.1.3.md` has ≥ 8 top-level `##` sections; Risk Profile present with ≥ 3 risks | ✅ PASS | Sections present: Workflow, v7.7.1.3 Scope (×2 subsections), Architecture References, Critical Rules in Force, Risk Profile, Pre-merge Checklist (pre-existing). Risk Profile lists 3 risks with mitigations. |
| A8 — Checkpoint A grep in v7.7.1.2 uses `^static constexpr` to count definitions only | ✅ PASS | `grep -cE '^static constexpr.*(DEV_HIST_MAGIC\|DEV_HIST_VERSION\|MAX_PERSIST_METRICS)'` |
| A9 — PERFORMANCE-ACK in v7.7.1.4 lists concrete call sites by function name; warns helper "MUST remain off the HTTP request path"; no unverified timing numbers | ✅ PASS | ACK lists `restore_device_history_v2_()` and `persist_device_segment_()` by name; explicit "MUST remain off the HTTP request path"; timing guidance says "Do NOT justify this choice with guessed timing numbers … measure the real device" |
| A10 — v7.7.1.3-claude-two-step.md cites `vTaskDelay(pdMS_TO_TICKS(5))` (NOT `(1)`); references BUG-043 rev2 / `firmware/core/nvs-persistence.h:248` | ✅ PASS | "Omitting the `vTaskDelay(pdMS_TO_TICKS(5))` yield … (BUG-043 rev2 — 1ms proved insufficient; verified against `firmware/core/nvs-persistence.h:248`)" |
| A11 — Reviewer checklist includes `bash scripts/provision.sh status` pre-flash verification step | ✅ PASS | "Confirm `bash scripts/provision.sh status` returned the expected role … BEFORE the upload step." added to v7.7.1.3-claude-two-step.md |
| B9.1 — `CURRENT-STATE.md` footer no longer contains `post-merge deliverable` | ✅ PASS | Footer now reads "mandatory in-PR deliverable … per Docs/development-process-guide.md §2.5" |
| B9.2 — `prompts/prompt-index-and-workflow.md` line ~71 reframed to in-PR; remaining `post-merge` hits are intentional | ✅ PASS | Line ~71 changed from "post-merge" to "execute the device testing as a §6 (in-PR) acceptance criterion". Per audit prompt, L347 and L432 hits are accepted as-is. |
| B9.3 — `consolidated-audit-template-phase7.md` device-results section reframed as in-PR; WROOM IP shows `.170` not `.190` | ✅ PASS | Template updated to "in-PR §6 acceptance criteria BEFORE marking the PR ready"; `.190` replaced with `.170` in both table rows |
| B9.4 — `phase7-review-prompts-perplexity.md` has a HISTORICAL banner | ✅ PASS | HISTORICAL banner added at top of file |

### §2.B — Cross-Cutting Integrity Checks

| Check | Result | Note |
|-------|--------|------|
| C1 — All `pdMS_TO_TICKS(N)` in prompts use N=5; zero hits of `pdMS_TO_TICKS(1)` | ✅ PASS | Only occurrence is `pdMS_TO_TICKS(5)` in v7.7.1.3-claude-two-step.md and session-handoff-v7.7.1.3.md |
| C2 — Zero `192.168.120.190` references | ✅ PASS | Diff confirms `.190` removed from consolidated-audit-template; no other `.190` in modified files |
| C3 — Zero `esp32-wroom-32d-multi-sensor.yaml` references | ✅ PASS | All WROOM-32D YAML references use `esp32-wroom-32d-gw.yaml` |
| C4 — Zero `assemble-sensor-history.sh --check` before `--write` | ✅ PASS | All checkpoints show `--write` then `--check` in correct order |
| C5 — Zero `esphome run` references; all use `timeout 300 esphome upload <yaml> --device=<ip>` | ✅ PASS | All upload commands use `timeout 300 esphome upload` form |
| C6 — All `curl -s` lines targeting board IPs include `--connect-timeout 5 --max-time 10` | ✅ PASS | Every curl in v7.7.1.3 §6 and v7.7.1.4 §6 includes both flags |
| C7 — No cross-prompt scope references like "see v7.7.1.2 §3" | ✅ PASS | The cross-reference was replaced by the inlined whitelist in v7.7.1.4 §3 |
| C8 — No narrative `// sizeof(X) = N bytes` comments in v7.7.1.2 | ✅ PASS | All `// sizeof(X) = N bytes` comments replaced by `// static_assert(…)` commented-out form |
| C9 — `bash scripts/lint-prompts.sh --baseline main` exits 0 | ⚠️ UNABLE TO VERIFY | Auditor does not have shell execution access to run the lint script. Recommend operator verify manually before merge. This does not block the verdict (see §7). |

### §2.C — Hot-Take Quality Concerns (Independent Inspection)

| Check | Result | Note |
|-------|--------|------|
| C-Q1 — Coherence: step renumbering consistent after bump moved to Step 0 | ✅ PASS (with MEDIUM finding) | See M-1 below — v7.7.1.3 Task Group 4 sub-steps renumber from 4.1/4.2/4.3 → 4.1/4.2 but correctly drop the "Version bump" sub-step. Minor coherence detail. |
| C-Q2 — No unverified factual claims (sizes, timing, counts, line numbers) | ✅ PASS | Sizes now use `<N_MEASURED>` with 2-phase procedure; timing language replaced by "measure the real device"; line numbers for `nvs-persistence.h:248` are verifiable and match the live file |
| C-Q3 — Cross-prompt consistency (v7.7.1.2 and v7.7.1.4 share nvs-persistence.h) | ✅ PASS | v7.7.1.4 correctly depends on v7.7.1.2 structs and v7.7.1.3 persist functions; assumptions are explicit |
| C-Q4 — Non-idempotent procedures (SIZING log line removal) | ✅ PASS (with LOW finding) | See L-1 below — procedure is clear and idempotency handled, but single-pass assumption exists |
| C-Q5 — Doctrinal drift not caught by lint | ✅ PASS (with LOW finding) | See L-2 below |
| C-Q6 — Rule 61 lint gap (no automated check for `pdMS_TO_TICKS(N)` drift) | ⚠️ NOTE | Intentionally out of scope per §5 of audit prompt. Absence of lint rule L8 noted here. Operator should track as §C13 follow-up. |
| C-Q7 — N3: inlined whitelist in v7.7.1.4 §3 matches canonical source byte-for-byte | ✅ PASS | See detailed comparison in §5 below |

---

## §3 — HIGH Findings

**None.**

---

## §4 — MEDIUM / LOW Findings

### MEDIUM Findings

#### M-1 — Sub-step numbering gap in v7.7.1.3 §6 Task Group 4

**File:** `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md`, Task Group 4  
**Offending content:**
```
### Task Group 4: Tests and in-PR documentation

**Step 4.1 — Preflight + Playwright**
…
**Step 4.2 — Changelog, CURRENT-STATE.md, session log, consolidated audit (ALL in-PR)**
```
**Issue:** Before the PR, Task Group 4 had steps 4.1 (version bump), 4.2 (preflight), 4.3 (docs). Moving bump to Step 0 removed 4.1 and renumbered, leaving 4.1 and 4.2. However, §7 Acceptance Criteria and §8 Pre-PR Gate still refer to acceptance criteria generically, so there is no downstream mis-reference. The step numbering internally is consistent but the section now omits a note confirming to a reader that there are only 2 sub-steps (the reader could expect 3 if they recall the old structure).  
**Severity:** MEDIUM — no execution hazard, but could confuse a reviewer doing a line-count of steps.  
**Proposed fix:** Add a parenthetical note after the Task Group 4 heading: `(Step 4.0 — version bump — was moved to Step 0 above; sub-steps below begin at 4.1.)` or renumber to 4.2/4.3 with a new 4.1 placeholder.

#### M-2 — `session-handoff-v7.7.1.3.md` Rule 61 line number reference is fragile

**File:** `prompts/handoff/phase7/session-handoff-v7.7.1.3.md`, Critical Rules in Force table  
**Offending content:**
```
| 61 | Use `maybe_yield_nvs_scan_()` … Verified: `firmware/core/nvs-persistence.h:248`. |
```
**Issue:** Hard-coding line number `:248` creates a forward-maintenance risk. If `nvs-persistence.h` gains or loses lines upstream, the reference silently becomes stale and could mislead a future auditor who spot-checks it. The live file confirms line ~248 is currently correct, but this reference will rot. The audit prompt itself (§2.A check A10) uses the same line reference — if both the handoff and the audit prompt use `:248`, a future edit to the header could pass a textual grep-check while the actual delay is at a different line.  
**Severity:** MEDIUM — not an execution hazard today, but a maintenance trap.  
**Proposed fix:** Replace `:248` with a grep-verified anchor: the searchable string `"vTaskDelay(pdMS_TO_TICKS(5))"` or add "as of v7.7.1.1; re-verify with `grep -n 'maybe_yield_nvs_scan_' firmware/core/nvs-persistence.h`".

#### M-3 — v7.7.1.4 PERFORMANCE-ACK O(N²) complexity note lacks a size-class caveat

**File:** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`, `calculate_retention_budgets_()` PERFORMANCE-ACK  
**Offending content:**
```cpp
// Complexity notes:
//   - Boot path: O(device_count) NVS/array scan work.
//   - Persist path: O(device_count) per call × N devices per cycle ⇒ O(N²) per persist cycle.
```
**Issue:** The O(N²) note is accurate but does not bound N. With `NUM_DEVICES` currently ≤ 6 (per CURRENT-STATE.md), the actual cost is O(36) per persist cycle — trivially cheap. The comment's framing could induce an implementation agent to prematurely optimize in a later phase when N is still small. The comment instructs "do NOT justify this choice with guessed timing numbers … measure the real device", which is good, but a concrete upper bound would make the note self-contained.  
**Severity:** MEDIUM — clarity concern, not a correctness defect.  
**Proposed fix:** Add: `O(N²) per persist cycle (bounded: N ≤ 20 per architecture §6, so ≤ 400 operations/cycle — measure before optimizing)`.

### LOW Findings

#### L-1 — SIZING log line removal in v7.7.1.2 is non-idempotent but undocumented

**File:** `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md`, §2 measurement procedure step 6  
**Issue:** Step 6 says "Remove the temporary `ESP_LOGI("SIZING", …)` line from `restore_from_nvs()` before committing." If an agent re-runs the procedure from step 1 (e.g., after a struct field change), step 2 asks it to add the log line again. If the agent runs step 2 on top of a previous run where step 6 was already completed, the result is a duplicate log line insertion. The procedure lacks an idempotency guard.  
**Severity:** LOW — single-pass execution is the intended path; re-runs are edge cases.  
**Proposed fix:** Add before step 2: "Confirm the SIZING line is not already present (`grep -c 'SIZING' firmware/core/nvs-persistence.h` → Expected: 0) before inserting."

#### L-2 — `consolidated-audit-template-phase7.md` Test Matrix task group reference is vague across steps

**File:** `prompts/phase7/consolidated-audit-template-phase7.md`, §6 Test Matrix  
**Offending content:**
```
| [from agent prompt §6 Task Group device testing] | …
```
**Issue:** Task group numbering varies by step (v7.7.1.2 has no device testing, v7.7.1.3 is Task Group 3, v7.7.1.4 is Task Group 5). The template placeholder is vague. Adding "see §6 for the applicable task group" would be clearer.  
**Severity:** LOW — cosmetic.

#### L-3 — `session-handoff-v7.7.1.3.md` Workflow section does not mention `last_written_slot = 0xFFFF` default in chain-inspection

**File:** `prompts/handoff/phase7/session-handoff-v7.7.1.3.md`, Workflow section  
**Offending content:**
```
the agent must confirm `DeviceHistoryMeta` initialisation uses `DEV_HIST_MAGIC` + `DEV_HIST_VERSION` constants
```
**Issue:** `DeviceHistoryMeta` has `last_written_slot = 0xFFFF` as a non-zero default. The handoff does not mention this field, which a restore validation check might trip on if the agent zero-initialises the struct. Not a defect in PR #233 itself (the struct definition in v7.7.1.2 is correct), but a gap in the chain-inspection guidance.  
**Severity:** LOW — informational gap, not a correctness defect.

#### L-4 — `phase7-review-prompts-perplexity.md` HISTORICAL banner does not name the Perplexity session that last applied it

**File:** `prompts/phase7/phase7-review-prompts-perplexity.md`, top banner  
**Issue:** The banner correctly names the two files that reference it. It does not specify which Perplexity session applied it — a future reader may not know if this was the same session that produced prior audits or a different one.  
**Severity:** LOW — cosmetic; no execution impact.

---

## §5 — Cross-Audit Reconciliation

### N3 — Byte-for-byte whitelist comparison (§2.C check C-Q7)

**Canonical source** (`prompts/handoff/phase7-batch-production-prompt-update.md`, "Scope Boundary Must Whitelist Pipeline Artifacts" section):

Source files modified by `bump-version.sh`:
1. `VERSION`
2. `scripts/render_sensor_config.py` (VERSION constant)
3. `tests/fixtures/generate-fixtures.js` (VERSION constant)
4. `dashboard/core/app-shell.js` (App.version)
5. `firmware/core/config.h` (version comment)
6. `firmware/core/data-model.h` (version comment)

Regenerated artifacts (from pipeline scripts triggered by bump-version.sh):
1. `dashboard/dashboard.js`, `dashboard/dashboard.html` (bundle)
2. `dashboard/dashboard.h` (gzip header)
3. `dashboard/sensor_history_multi.h` (assembly)
4. `src/gateway_manifest.h` (manifest)
5. `tests/fixtures/manifest.json`, `tests/fixtures/api-status.json` (fixtures)
6. `tests/fixtures/variants/*/` (variant fixtures)

**v7.7.1.4 §3 inlined whitelist** (from PR #233 diff):

Source files directly modified by `bump-version.sh`:
1. `VERSION`
2. `scripts/render_sensor_config.py` (VERSION constant)
3. `tests/fixtures/generate-fixtures.js` (VERSION constant)
4. `dashboard/core/app-shell.js` (App.version)
5. `firmware/core/config.h` (version comment)
6. `firmware/core/data-model.h` (version comment)

Regenerated artifacts from pipeline scripts triggered by bump-version.sh:
1. `dashboard/dashboard.js`, `dashboard/dashboard.html` (bundle)
2. `dashboard/dashboard.h` (gzip header)
3. `dashboard/sensor_history_multi.h` (assembly)
4. `src/gateway_manifest.h` (manifest)
5. `tests/fixtures/manifest.json`, `tests/fixtures/api-status.json` (fixtures)
6. `tests/fixtures/variants/*/` (variant fixtures)

**Verdict:** The two lists match on all 12 bullet items. The only difference is the section heading phrasing: canonical uses "Source files modified by" while v7.7.1.4 uses "Source files **directly** modified by" (one extra word "directly"). This is not a substantive difference. **✅ PASS — byte-for-byte match on content.**

### Reconciliation with prior auditor reports

The prior reports (Copilot, Opus 4.7, GPT) identified the defects fixed by PR #233. This third independent audit confirms all findings from those reports are resolved in the final commit (`2692e74`). No disagreements with prior auditors on substantive checks.

New findings in this audit not flagged by prior auditors:
- M-1 (step-numbering gap in v7.7.1.3 Task Group 4)
- M-2 (fragile `:248` line-number reference in session handoff)
- M-3 (O(N²) note lacks size-class caveat)

---

## §6 — Disposition Recommendation

| Finding | Severity | Disposition |
|---------|----------|-------------|
| M-1 — Task Group 4 sub-step numbering gap in v7.7.1.3 | MEDIUM | (b) Merge and track as follow-up under #228 §C |
| M-2 — Fragile line-number reference `:248` in session handoff | MEDIUM | (b) Merge and track as follow-up under #228 §C |
| M-3 — O(N²) note lacks size-class caveat in v7.7.1.4 | MEDIUM | (b) Merge and track as follow-up under #228 §C |
| L-1 — SIZING log line non-idempotency | LOW | (c) Merge and accept as-is |
| L-2 — Template task group reference vagueness | LOW | (c) Merge and accept as-is |
| L-3 — Handoff `last_written_slot` field gap | LOW | (c) Merge and accept as-is |
| L-4 — HISTORICAL banner missing session provenance | LOW | (c) Merge and accept as-is |
| C9 — `lint-prompts.sh` unverifiable by auditor | N/A | Operator must run `bash scripts/lint-prompts.sh --baseline main` manually before merge |

---

## §7 — Confidence Statement

**Confidence level: HIGH** that implementation agents dispatched for v7.7.1.2 / v7.7.1.3 / v7.7.1.4 can execute these prompts to merge without re-discovering any of the defects covered by issue #228 §A and §B9.

All nine original defect classes (missing WROOM device test block, wrong `find_partition_size_bytes_` signature, `esphome run` vs `esphome upload`, missing `--connect-timeout` flags, `bump-version.sh` not Step 0, narrative sizeof comments instead of static_assert, inlined whitelist absent, session handoff depth insufficient, `post-merge deliverable` language) are resolved cleanly in the final commit.

The one unverifiable item (C9 — lint script) does not affect execution confidence for the coding agent prompts themselves; it is an administrative gate the operator should run before pushing the merge button.

The MEDIUM findings (M-1, M-2, M-3) are clarity issues that could, in a worst case, cause a reviewer to ask a clarifying question or a future maintainer to add an unnecessary optimization. They will not cause the coding agent to produce incorrect code or miss a deliverable.

**Caveat:** The Rule 61 lint rule (L8) does not yet exist as an automated check. The next Rule 61 drift (if any) will only be caught by human review or by a future §C13 lint rule addition. The operator should confirm that adding L8 is tracked as a follow-up issue.

---

_Audit conducted by Perplexity AI (Claude Sonnet 4.6), 2026-05-10._  
_Repo: GCV-Sleeper-Service/ESP32-GW-multi-sensor, PR #233, final commit 2692e74._
