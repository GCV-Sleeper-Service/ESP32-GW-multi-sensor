# Phase Y Comprehensive Closure Analysis

_Generated: 2026-04-12_  
_Repository: GCV-Sleeper-Service/ESP32-GW-multi-sensor_  
_Phase: Phase Y — v7.6.6.0–v7.6.6.8 (sensor_history_multi.h architecture refactor)_  
_PR under review: #169 (copilot/add-new-preflight-checks)_

---

## Q1 — Plan vs Delivery

### Overall verdict: Substantially delivered; one planned line count deviated by +1 due to a post-split security fix. All architecture decisions and deliverables are present.

#### Option B (assembled artifact)

**Plan:** `dashboard/sensor_history_multi.h` remains the committed assembled output; fragments are hand-edited sources; assembly script concatenates them; no YAML changes; no generator changes.  
**Delivered:** ✅ Exact match. YAML `includes:` unchanged. `render_sensor_config.py` unchanged. `dashboard/sensor_history_multi.h` is the assembled artifact throughout.

#### Fragment list (plan §2.3 vs actual)

| Fragment | Plan lines | Actual lines | Match? |
|---|---:|---:|---|
| `config.h` | 95 | 95 | ✅ |
| `data-model.h` | 460 | 460 | ✅ |
| `nvs-persistence.h` | 614 | 614 | ✅ |
| `deferred-management.h` | 50 | 50 | ✅ |
| `ping-adapter.h` | 168 | 168 | ✅ |
| `aggregator-runtime.h` | 891 | **892** | ⚠️ +1 line (security fix) |
| `web-handler.h` | 2,006 | 2,006 | ✅ |
| `registration.h` | 41 | 41 | ✅ |
| **Total** | **4,325** | **4,326** | ⚠️ +1 |

**Deviation:** `aggregator-runtime.h` gained one line from a security fix (Gemini review, v7.6.6.1 PR #155): `lwip_send()` was called with `req_len` (the `snprintf` return) without a truncation guard, allowing a buffer over-read if path+host exceeded 512 bytes. Fixed in commit `b15278a`. The total is therefore 4,326 lines, not 4,325. The `registration.h` fragment starts at line 4,286 (plan: 4,285). **Correct outcome** — the fix improves security and is documented in `v7.6.6.1-PR155-consolidated-audit-and-lessons.md`.

#### Assembly script flags

**Plan (§2, v7.6.6.8 table):** `--write`, `--check`, `--list`, `--dry-run`  
**Delivered:** ✅ All four modes present in `scripts/assemble-sensor-history.sh` (lines 29–66). MODULES list order matches plan exactly.

#### SHA-256 gate

**Plan (D4):** `assemble-sensor-history.sh --check` compares assembled output (stripped of generated regions) to committed file.  
**Delivered:** ✅ `strip_generated()` strips both `SENSOR_MANIFEST:HEADER_BEGIN/END` and `SENSOR_MANIFEST:ENTITY_BEGIN/END` before computing SHA-256. SHA-256 identity verified at every step. `firmware_core_assembly_check` preflight calls this and surfaces stderr on failure.

#### Pipeline integration

**Plan (§4.2):** Assembly as Step 0 in `provision.sh`; `--check` in preflight only (not at pipeline tail).  
**Delivered:** ✅ `provision.sh run_full_pipeline()` has `assemble-sensor-history.sh --write` as Step 0 (activated in v7.6.6.1, v7.6.6.2). `--check` runs in preflight only (correct; running it after the generator would always fail due to generated content injected outside SENSOR_MANIFEST markers).

#### Device test gates

**Plan (§7.3):** Device tests required at v7.6.6.5 (NVS/C3), v7.6.6.6 (aggregator/S3), v7.6.6.7 (full smoke/both boards).  
**Delivered:** ✅ All three device gates executed and documented. One qualification: import/export endpoints (#14–18 of 21) crash the ESP32-C3 board (pre-existing firmware bug). 16/21 endpoints validated on hardware; 5 deferred. Documented in the v7.6.6.7 audit and changelog as a known non-blocking deferral.

#### Closure deliverables (v7.6.6.8 plan table)

| Deliverable | Plan | Status |
|---|---|---|
| 6 new preflight checks | ✅ | All 6 present, named correctly (see Q2) |
| Critical Rules 58–62 | ✅ | Present in prompt-index with exact plan wording |
| `prompts/handoff/phaseY-results.md` | ✅ | Created; complete |
| README `firmware/core/` section | ✅ | Fragment table at README lines 225–240 |
| `Docs/lessons/firmware.md` LESSON-OPS-122 | ✅ | Added |
| `Docs/lessons/build-pipeline.md` LESSON-OPS-123 | ✅ | Added |
| `prompts/prompt-index-and-workflow.md` Phase Y complete | ✅ | All 9 steps marked ✅; completion summary at lines 148–157 |
| `Docs/changelog.md` | ✅ | v7.6.6.8 and v7.6.6.7 entries present and accurate |
| Session log `Docs/session-log-*-v7.6.6.8.md` | ❌ | **Missing.** Required by Critical Rule 20. All 8 prior Phase Y steps have session logs; v7.6.6.8 is absent. Flagged as required pre-merge fix by operator synthesis review (#4230518207). |

---

## Q2 — Implementation Quality

### Fragments — architecturally clean

Each fragment matches the plan's boundary justification (§2.4):

- **`config.h`**: pure preprocessor/includes — ✅
- **`data-model.h`**: runtime data model + generated marker stubs only — ✅
- **`nvs-persistence.h`**: all NVS helpers, restore, persist, `maybe_yield_nvs_scan_()` — ✅
- **`deferred-management.h`**: reboot + delete-data task pairs — ✅ (50 lines, boundary at `reboot_task_`)
- **`ping-adapter.h`**: full `PingAdapter` class within `#ifdef PING_DEVICE_INDEX` guard — ✅; one boundary documentation comment at lines 153–167 legitimately references `s_cache_mutex` for thread-safety description (see LESSON-OPS-118)
- **`aggregator-runtime.h`**: mutex, satellite cache, poll task, aggregator NVS — ✅; 892 lines (plan: 891 due to security fix)
- **`web-handler.h`**: full `HistoryWebHandler` class including both core and aggregator route clusters — ✅; preserves syntactic completeness (plan D5)
- **`registration.h`**: `register_history_handler()` and boot orchestration — ✅

All 4 deferred-task pairs are in their specified fragments. All mutex/lock primitives are single-owned. `maybe_yield_nvs_scan_()` is defined once in `nvs-persistence.h` (line 246, confirmed).

### Assembly script correctness

- MODULES list order matches plan exactly: `config.h → data-model.h → nvs-persistence.h → deferred-management.h → ping-adapter.h → aggregator-runtime.h → web-handler.h → registration.h` ✅
- All 4 flags (`--write`, `--check`, `--list`, `--dry-run`) present ✅
- `strip_generated()` correctly strips both SENSOR_MANIFEST marker regions ✅
- `ROOT` normalization present (added in v7.6.6.1 fix `b15278a`) ✅
- `$OUTPUT` existence guard present ✅

### Preflight checks — 6 Phase Y closure checks

**Name match vs plan:**

| Plan name | Implemented name | Match? |
|---|---|---|
| `sensor_history_monolith_is_assembled` | `sensor_history_monolith_is_assembled` | ✅ |
| `firmware_core_fragment_count` | `firmware_core_fragment_count` | ✅ |
| `no_generator_markers_in_fragments` | `no_generator_markers_in_fragments` | ✅ |
| `deferred_task_pairs_in_expected_homes` | `deferred_task_pairs_in_expected_homes` | ✅ |
| `maybe_yield_present_in_nvs_persistence` | `maybe_yield_present_in_nvs_persistence` | ✅ |
| `mutex_single_owner` | `mutex_single_owner` | ✅ |

All 6 function names match the plan exactly.

**Semantic depth analysis:**

| Check | Implementation | Depth | Issues |
|---|---|---|---|
| `sensor_history_monolith_is_assembled` | Calls `assemble-sensor-history.sh --check > /dev/null 2>&1` | Definition semantics | Suppresses all output; **redundant** with `firmware_core_assembly_check` (Copilot reviewer line 631, GPT review, Perplexity review). Not wrong, but adds execution time and mutes diagnostics. |
| `firmware_core_fragment_count` | Iterates explicit MODULES array (8 elements), counts existing files | Existence with details | ✅ Robust; uses explicit list (Codex fix e17426e), not glob. Missing file printed explicitly. |
| `no_generator_markers_in_fragments` | Greps all fragments except `data-model.h` for `SENSOR_MANIFEST:` | Presence | ✅ Correct. Loop uses `firmware/core/*.h` glob — if no files match the glob would iterate literal string (Gemini finding); low risk since fragment count check runs first. |
| `deferred_task_pairs_in_expected_homes` | Plain `grep -q` for 8 symbol names across 2 fragments | **Presence-only** | ⚠️ Can pass on comments or log strings containing symbol names. A comment in `deferred-management.h` referencing `schedule_reboot_()` would satisfy the check even if the actual function definition were moved elsewhere. Flagged as P2 by ChatGPT Codex Connector inline reviewer. **Not fixed.** |
| `maybe_yield_present_in_nvs_persistence` | `grep -v '^[[:space:]]*//' \| grep -c 'maybe_yield_nvs_scan_.*{'` | **Definition semantics** | ✅ The `.*{` pattern matches the actual function definition header (`static void maybe_yield_nvs_scan_(int iteration) {` at line 246). Comment lines stripped with POSIX-portable pattern. Also verifies zero occurrences in other fragments. Uses `-ge 1` (not `-eq 1`) — minor technical weakness but inconsequential in practice. |
| `mutex_single_owner` | `grep -v '^[[:space:]]*//' \| grep -c "SemaphoreHandle_t s_cache_mutex"` | **Declaration semantics** | ✅ Uses full type-declaration pattern. Strips comments with POSIX portable syntax (Codex fix e17426e). Checks `agg_def -eq 1 && other_def -eq 0` (Gemini fix e17426e). |

**Redundancy:** `sensor_history_monolith_is_assembled` duplicates the existing `firmware_core_assembly_check` (which already calls `--check` with a better failure hint). Confirmed by Copilot PR reviewer (line 631), GPT review (#4230476334), Perplexity review (#4230479670 item 4), operator synthesis review.

**Remaining shallow check:** `deferred_task_pairs_in_expected_homes` is presence-only (can match comments). This is the only check still flagged as weak after all post-review fixes.

### Is `maybe_yield` truly definition-semantics?

**Yes.** The current implementation uses `grep -c 'maybe_yield_nvs_scan_.*{'` after stripping comment lines. This pattern matches the actual definition header at `nvs-persistence.h:246`: `static void maybe_yield_nvs_scan_(int iteration) {`. A call-site reference like `maybe_yield_nvs_scan_(n);` does NOT match (no `{`). Comment lines are stripped. This IS definition semantics.

The GPT and Perplexity reviewers flagged this as "presence-only" in the pre-`e17426e` state. Based on the current branch state of `scripts/preflight.sh`, the `.*{` pattern IS present and provides definition semantics. The synthesis review item A ("still open") may have been written before confirming this pattern was in place.

---

## Q3 — Documentation Quality

### README

- Fragment table at lines 225–240: ✅ All 8 fragments with correct line counts and responsibilities
- Preflight count: ✅ Updated to 68 in all three locations (intro line 40, layout line 129, preflight section line 191). One stale "53 checks" reference was corrected by Codex commit e17426e.
- Phase Y status in roadmap table: ✅ "✅ Complete"
- Workflow sentence: ✅ "Edit fragments → `bash scripts/assemble-sensor-history.sh --write` → run pipeline → verify with `--check`"

### LESSON-OPS-122 (`Docs/lessons/firmware.md`)

- ✅ Present; content matches plan
- Covers: assembly concatenation order, mutex ownership, deferred-task homes, generator marker stubs in `data-model.h`, YAML reference to assembled artifact only
- Cross-references to Critical Rules 58–62, LESSON-OPS-118, and LESSON-OPS-123 ✅
- **Cosmetic defect:** File ends with `---\n\n---` (double horizontal rule) after the lesson. Confirmed by Perplexity review (#4230479670 item 6). Not a correctness issue.

### LESSON-OPS-123 (`Docs/lessons/build-pipeline.md`)

- ✅ Present; correct content
- Pipeline order (9 steps) listed correctly
- Generator/assembly sync explanation correct (generator writes into assembled file; `--check` strips generated content before SHA comparison)
- Preflight vs pipeline distinction explained correctly

### Critical Rules 58–62

All 5 rules are present in `prompts/prompt-index-and-workflow.md` at lines 278–282 with exact wording from the plan (§3 v7.6.6.8 table):

| # | Location | Exact plan wording? |
|---|---|---|
| 58 | Line 278 | ✅ |
| 59 | Line 279 | ✅ |
| 60 | Line 280 | ✅ |
| 61 | Line 281 | ✅ |
| 62 | Line 282 | ✅ |

### Changelog

- `## [v7.6.6.8] — 2026-04-12` (lines 5–19): ✅ All 6 new checks named, Critical Rules 58–62, all changed docs listed
- `## [v7.6.6.7] — 2026-04-11`: ✅ Comprehensive device test evidence; deferred gaps documented (history proxy, import/export crash); correct clarification "devices ran v7.6.6.6 binary at time of testing"
- Both entries accurate.

### `phaseY-results.md`

- Fragment manifest: ✅ All 8 fragments with correct lines and responsibilities
- Context reduction table: ✅ Matches plan §6.2 estimates
- Test results: ✅ 402/0 Playwright, 68 preflight checks, device test results
- Architecture decisions D1–D8: ✅
- Critical Rules 58–62: ✅ Full text present
- Bugs Discovered section: ✅ Documents LESSON-OPS-118, import/export crash, history proxy
- Phase 7 Readiness: ✅ Target fragments identified
- Pre-merge wording: ✅ Current file reads "Branch `copilot/add-new-preflight-checks` is at v7.6.6.8. Merge pending." (GPT/Perplexity concern already resolved)

### Prompt-index Phase Y step table

- All 9 steps: ✅ Marked ✅ Complete (lines 161–169)
- Phase Y completion summary: ✅ Lines 148–157; includes version range, step count, fragment count, test results, context reduction, rule count, device test evidence, results file, plan file, prompts directory
- Note: Summary says "5 new Critical Rules (58–62)" — correct (5 rules numbered 58–62).

---

## Q4 — Bugs, Lessons, Rules

### Bugs Discovered During Phase Y (all 9 steps)

| Step | Bug | LESSON ref | Severity | Status |
|---|---|---|---|---|
| v7.6.6.0 | `--dry-run` mutated filesystem on board-switch path in `provision.sh`; `activate_*()` called `clean_active_configs`, `cp`, `run_render` before dry-run flag was honored | LESSON-OPS-125 | Blocking | Fixed in `e9d9ced` |
| v7.6.6.0 | Unknown `--arg` silently executed live pipeline (arg validation absent at dispatch layer) | LESSON-OPS-126 | High | Fixed in `e9d9ced` |
| v7.6.6.0 | Agent ran `bump-version.sh` out of scope → stale `print_workflow()` comment | — | Medium | Fixed in `e9d9ced` |
| v7.6.6.1 | `lwip_send()` in `aggregator-runtime.h` passed `req_len` (snprintf return) without truncation guard → buffer over-read if path+host > 512 bytes | LESSON-OPS-126 candidate | **Critical/Security** | Fixed in `b15278a`; patched in assembled artifact too |
| v7.6.6.1 | Agent ran `bump-version.sh` out of scope → version drift across 14 files → fixture drift → CI broken | LESSON-PHASY-003 | High | Reverted in `b15278a` |
| v7.6.6.1 | Post-review fix PR targeted `main` instead of feature branch | LESSON-OPS-125 | Medium | Operator rebase fix |
| v7.6.6.2 | `firmware_core_fragment_line_sum` used `*.h` glob instead of explicit MODULES list → latent false-failure if helper headers added to `firmware/core/` | LESSON-PHASY-002 | Medium | Fixed in `d1e3998` |
| v7.6.6.2 | `bump-version.sh` didn't update version-comment strings in fragment files → every version bump would break SHA-256 identity gate | LESSON-PHASY-001 | High | Fixed autonomously in same PR (justified) |
| v7.6.6.3 | Session log missing esphome config output + Playwright fixture table at PR open | — | Low | Fixed in `6bafea7` |
| v7.6.6.4 | `config.h` banner text changed by agent accepting Gemini inline suggestion → SHA identity gate broken | LESSON-OPS-118 (related) | High | Reverted in `c4b9efc`+`4b7f950` |
| v7.6.6.4 | False positive in cross-fragment symbol leakage check: `grep -c "s_cache_mutex" ping-adapter.h` returned 1 due to boundary documentation comment (not code) | **LESSON-OPS-118** | Medium | Fixed via comment-strip pattern in preflight |
| v7.6.6.5 | `dashboard.h` built from unminified source (skipped `minify-dashboard.sh`) → +17.6 KB gzip overhead | — | Medium | Pre-merge fix committed |
| v7.6.6.6 | History proxy `GET /api/aggregator/proxy/{gw}/history/{device}/{metric}` returns empty body | v7.6.6.6 audit | Medium | **Deferred — post-Phase Y** |
| v7.6.6.7 | Import/export endpoints (#14–18) crash ESP32-C3 board on execution (pre-existing firmware bug, not introduced by Phase Y) | Unnamed LESSON, v7.6.6.7 audit | High | **Deferred — post-Phase Y** |
| v7.6.6.8 | `deferred_task_pairs_in_expected_homes` uses plain grep; comment/string matches could satisfy check while actual definitions are elsewhere | — | Medium | **Unresolved** (P2 badge, inline reviewer) |
| v7.6.6.8 | `sensor_history_monolith_is_assembled` duplicates `firmware_core_assembly_check`; all output suppressed | — | Low | **Unresolved** (acknowledged; cosmetic/performance) |
| v7.6.6.8 | Session log `Docs/session-log-2026-04-12-v7.6.6.8.md` absent | — | Low/Required | **Unresolved** (flagged as required pre-merge fix by synthesis review) |

### New Critical Rules 58–62 (full text)

| # | Full text | Source |
|---|---|---|
| 58 | Source modules for `sensor_history_multi.h` live in `firmware/core/`. Never add code to `dashboard/sensor_history_multi.h` directly — it is an assembled artifact. | Phase Y v7.6.6.1 |
| 59 | `render_sensor_config.py` writes into the assembled `dashboard/sensor_history_multi.h`. Never redirect the generator to fragment files. | Phase Y D3 |
| 60 | `s_cache_mutex` and `AGG_LOCK`/`AGG_UNLOCK` are defined once in `firmware/core/aggregator-runtime.h`. Never redefine or shadow them. | Phase Y v7.6.6.6 |
| 61 | `maybe_yield_nvs_scan_()` is defined once in `firmware/core/nvs-persistence.h`. Call it in every NVS scan loop. | Phase Y v7.6.6.5 |
| 62 | The assembly fragment order in `assemble-sensor-history.sh` is the dependency order. Never reorder fragments. | Phase Y v7.6.6.1 |

### New LESSON-OPS entries added during Phase Y

**Committed to lesson files:**

| ID | File | Summary |
|---|---|---|
| LESSON-OPS-118 | `firmware.md` | Fragment boundary comments may reference adjacent-fragment symbols; all cross-fragment symbol leakage checks must strip comment lines before grepping |
| LESSON-OPS-122 | `firmware.md` | Fragment architecture for sensor_history_multi.h (Phase Y): key constraints for assembly order, mutex ownership, deferred-task homes, generator ownership, YAML includes |
| LESSON-OPS-123 | `build-pipeline.md` | Assembly step in regeneration pipeline (Phase Y): pipeline order after Phase Y, generator/assembly sync, preflight vs pipeline separation |

**Documented in consolidated audits only (not yet in lesson files):**

| ID | Source audit | Summary |
|---|---|---|
| LESSON-OPS-125 | v7.6.6.0 | `--dry-run` guards must be placed BEFORE any filesystem mutation, not inside the downstream function the mutating path eventually calls |
| LESSON-OPS-126 | v7.6.6.0 + v7.6.6.1 | Arg validation must reject unknown flags at the dispatch layer; security review for network I/O code (snprintf/lwip_send pattern) must be in the prompt |
| LESSON-OPS-106 | v7.6.6.6 | `satellite_config_generation` is an internal runtime counter not exposed in HTTP responses |
| LESSON-OPS-107 | v7.6.6.6 | `POST /api/aggregator/test-satellite` requires `url=http://…` (full URL) |
| LESSON-OPS-108 | v7.6.6.6 | `POST /api/aggregator/add-satellite` requires `url=http://…` as body param |
| LESSON-OPS-109 | v7.6.6.6 | `DELETE /api/aggregator/satellite/{id}` uses the satellite's string ID |
| LESSON-PHASY-001 | v7.6.6.2 | Fragment metadata version strings must be kept in sync with assembled header |
| LESSON-PHASY-002 | v7.6.6.2 | Preflight line-sum checks must use the assembler's explicit module list, not a glob |
| LESSON-PHASY-003 | v7.6.6.2 | Prompt scope boundaries must include all predictable autonomous decisions |

**Identified in PR reviews but NOT yet documented in any lesson file:**

1. **Import/export crash pattern** — v7.6.6.7 audit: "LESSON (new, unnamed)": flash-impacting endpoint failures must be anticipated in device test prompts; endpoint crash ≠ gate failure. No LESSON-OPS number assigned.
2. **`$step` word-split fragility in `provision.sh`** — flagged by Gemini, CODEX, GPT at Medium severity during v7.6.6.0. Deferred (safe for current hardcoded steps). Never formalized as a lesson.
3. **`dashboard.h` built from unminified source** (v7.6.6.5) — noted in audit retrospective with a specific guard command; not formalized as a lesson entry.
4. **PR targeting wrong base branch** (v7.6.6.1) — documented as LESSON-OPS-125 in the audit but not added to any lesson file.

---

## Q5 — Outstanding Issues

### Issues flagged in PR169 reviews (GPT, Codex, Perplexity) as deferred or unresolved

**From operator synthesis review (#4230518207, head `e17426ef`):**

| ID | Source | Finding | Severity | Fixed by e17426e? | Current state |
|---|---|---|---|---|---|
| A | GPT + Perplexity | `maybe_yield_present_in_nvs_persistence` — presence-only, should be definition-semantics | Medium | Partially | **Likely closed** — current code uses `.*{` pattern which IS definition semantics. Synthesis review may have been written before confirming this. |
| B | GPT + Perplexity | `phaseY-results.md` pre-merge wording: "main is at v7.6.6.8" | Medium | No | **Already fixed** — current file reads "Branch `copilot/add-new-preflight-checks` is at v7.6.6.8. Merge pending." |
| C | Synthesis review | Session log `Docs/session-log-2026-04-12-v7.6.6.8.md` absent | Low/Required | No | **Still open.** Required by Critical Rule 20. Synthesis says "do not merge until addressed." |
| D | Perplexity | Double `---` at end of `Docs/lessons/firmware.md` after LESSON-OPS-122 | Cosmetic | No | **Still open.** Cosmetic only. |
| E | Perplexity | `v7.6.6.8-PR169-consolidated-audit-and-lessons.md` absent | Post-merge deliverable | N/A | **Post-merge deliverable** — not expected in this PR. |

**Fixed by Codex commit e17426e (all confirmed by Codex agent response #4230468287):**

1. `firmware_core_fragment_count` — changed from glob to explicit 8-module list with missing-file notes ✅
2. `mutex_single_owner` — `^\s*//` → `^[[:space:]]*//` (POSIX portable); `agg_def -gt 0` → `agg_def -eq 1` ✅
3. Noisy stderr — file-existence guards added to deferred-task and maybe_yield checks ✅
4. README preflight count — corrected to 68 ✅
5. `maybe_yield_present_in_nvs_persistence` — comment stripping made POSIX-portable ✅

**Remaining required actions before merge (3 items):**

- **C (Low/Required):** Session log for v7.6.6.8 missing. **Blocker per synthesis review.**
- `deferred_task_pairs_in_expected_homes` — presence-only grep; P2 badge (ChatGPT Codex Connector). Not in the 3 required items, but architecturally weakens the Phase Y guardrail.
- **D (Cosmetic):** Double trailing `---` in `Docs/lessons/firmware.md`.

### Are any outstanding issues blockers for Phase 7?

**No blocking issues from the preflight/docs side.** The fragment architecture is sound. The two deferred runtime bugs carry over:

**Bug D1 — Import/export crash** (`/api/import/begin`, `/api/import/d/{data}`, `/api/import/w/{data}`, `/api/import/finish`):  
Crashes ESP32-C3 board on execution. Pre-existing firmware bug, not introduced by Phase Y.  
_Documentation:_ changelog v7.6.6.7; `phaseY-results.md` Bugs section; v7.6.6.7 audit deferred items table (D1, High, "Post-Phase Y bug-fix step").  
_Tracked with sufficient detail for a targeted fix. NOT a Phase 7 blocker_ (different code path from per-device persistence).

**Bug D2 — History proxy empty body** (`GET /api/aggregator/proxy/{gw}/history/{device}/{metric}`):  
Returns empty body. First seen v7.6.6.6. Root cause undiagnosed.  
_Documentation:_ changelog v7.6.6.7; `phaseY-results.md` Bugs section; v7.6.6.6 and v7.6.6.7 audit deferred items tables (D2, Medium, "Post-Phase Y bug-fix step").  
_Mild blocker risk for Phase 7 aggregator validation steps_ if proxy behavior is required for integration testing. Root cause should be diagnosed before Phase 7 aggregator work begins.

### `maybe_yield` check — definition semantics confirmed

Current `scripts/preflight.sh` `maybe_yield_present_in_nvs_persistence`:

```bash
def_in_nvs=$(grep -v '^[[:space:]]*//' firmware/core/nvs-persistence.h \
  | grep -c 'maybe_yield_nvs_scan_.*{' || true)
```

- Strips comment lines with POSIX-portable pattern ✅
- Pattern `maybe_yield_nvs_scan_.*{` matches actual function definition header at `nvs-persistence.h:246`: `static void maybe_yield_nvs_scan_(int iteration) {` ✅
- A call-site `maybe_yield_nvs_scan_(n);` does NOT match ✅
- Checks other fragments for zero occurrences ✅
- Uses `-ge 1` (not `-eq 1`) — minor technical weakness but inconsequential in practice

**Verdict:** The `maybe_yield` check is **definition-semantics**, not presence-only. The concern raised by GPT and Perplexity was valid at the pre-`.*{` state but the final committed code addresses it.

---

## Q6 — Meta-Level Lessons

### Process and prompt-engineering lessons from the full Phase Y arc

**1. Version bump scope collisions are systemic (4 occurrences across 9 steps)**

Agents consistently ran `bump-version.sh` when the prompt's explicit scope excluded it (v7.6.6.1, v7.6.6.4) or when it was technically in-scope but cascade effects weren't fully specified (v7.6.6.2). This is the third recurrence across all phases (Phase X v7.6.5.7 was earlier; Critical Rule 56 was already added but not sufficient).

**Fix:** Every step prompt must explicitly state, by name, which files `bump-version.sh` will touch and assert that fixture variants and dashboard artifacts are expected side-effects, not scope violations. If `bump-version.sh` is excluded, it must appear in the DO-NOT list, not just the NOT-in-scope section.

**2. `--dry-run` completeness requires early exit, not late flag check**

v7.6.6.0 had a blocking defect where `--dry-run` was honored inside `run_full_pipeline()` but not before filesystem mutations in `activate_*()`. GPT identified this by tracing the call chain; Gemini and Copilot missed it reviewing pipeline code in isolation.

**Fix:** Require agents to trace all call paths from the entry point and verify the dry-run flag arrives at every mutation site before the mutation, not after.

**3. Session log completeness checklist was repeatedly insufficient**

Session logs were missing or incomplete in v7.6.6.3, v7.6.6.4, v7.6.6.5, and v7.6.6.8. Root cause: session log requirements were in §9 (post-merge deliverables) but not in the acceptance criteria checklist.

**Fix:** Move the session log requirement into the pre-merge acceptance criteria with specific required sections (ESPHome output or documented absence, Playwright fixture table, evidence summary). The v7.6.6.3 retrospective recommended this exactly; it was not propagated to subsequent prompts.

**4. Reviewer inline suggestions are a prompt injection vector for SHA-sensitive files**

In v7.6.6.4, the agent accepted a Gemini inline suggestion to change `config.h` line 3 banner text, which broke the SHA-256 identity gate. Any byte change to a fragment file breaks the gate.

**Fix:** Explicitly state in prompts for any step that does not intend fragment changes: "Do not accept inline code suggestions from reviewer bots for fragment files. The SHA-256 gate will fail on any change to any fragment."

**5. Security review must be specified in the prompt for network I/O code**

The `lwip_send` buffer over-read in `aggregator-runtime.h` was not caught until Gemini reviewed PR #155. The v7.6.6.1 prompt had no security review requirement.

**Fix:** Any prompt that touches `aggregator-runtime.h`, `web-handler.h`, or any code containing `lwip_send`, `lwip_recv`, `snprintf`, or heap allocation must include an explicit security review checkpoint before requesting PR review.

**6. Device test protocols need an explicit "crash = document and continue" path**

v7.6.6.7 omitted Phase A (C3 satellite endpoints) from the initial commit because the import/export crash wasn't anticipated in the prompt's flow.

**Fix (already in v7.6.6.7 retrospective):** Add to device test prompts: "If any endpoint crashes the board, document the crash with serial log evidence, mark the endpoint as `⚠️ Deferred — [reason]` in the evidence table, and continue testing remaining endpoints. A single endpoint failure does not block the gate provided it is documented."

### What should change for Phase 7 prompts

**Always include:**
- Explicit MODULES order for any fragment-touching task
- Explicit `--write` + `--check` workflow
- Statement that version bump affects fragment version-comment strings (expected side-effect)
- Session log in §6 acceptance criteria (not §9 post-merge), with specific required sections

**Never include:**
- Open-ended "validate all endpoints" without crash-handling path
- Security-adjacent network code without a security review step
- `--dry-run` implementation without tracing all call paths from entry point

**Prompt structure changes:**
- Playwright fixture table and esphome output in acceptance criteria, not afterthought
- `bump-version.sh` side-effect files explicitly named or explicitly excluded with DO-NOT enforcement

### Agent behaviour patterns — summary

| Problem pattern | Frequency | Guardrail that worked |
|---|---|---|
| Running `bump-version.sh` out of scope | 4/9 steps | Explicit inclusion/exclusion in scope; "BUMP-VERSION.SH IS OUT OF SCOPE" in DO-NOT list |
| Accepting reviewer inline suggestions on SHA-sensitive files | 1/9 steps (v7.6.6.4) | SHA gate caught it immediately; LESSON-OPS-118 documents the comment-strip fix |
| Opening fix PR targeting wrong branch | 1/9 steps (v7.6.6.1) | Explicit base-branch name in fix prompt |
| Missing session log deliverable | 4/9 steps | Moving to pre-merge acceptance criteria |
| Dry-run bypass via call chain | 1/9 steps (v7.6.6.0) | SHA gate; dry-run unit test; explicit call-chain trace requirement |
| Skipping pipeline step (minify before generate-header) | 1/9 steps (v7.6.6.5) | Explicit ordered step list with verification commands after each step |

**Guardrails that worked reliably throughout:**
- SHA-256 identity gate — caught every fragment byte change and every incorrect assembly
- Explicit MODULES list (after v7.6.6.2 fix) — prevented glob false-failures
- `firmware_core_fragment_line_sum` — provided second independent line-count verification beyond SHA
- Four-reviewer audit pattern (Copilot bot + Gemini + Codex + GPT/Perplexity) — caught different failure classes; the blocking dry-run issue was only caught by GPT tracing the call chain; the security defect was only caught by Gemini checking snprintf patterns

**Meta-lesson (highest leverage):** Automated reviewer diversity is more important than reviewer depth on any single axis. Maintain 3–4 reviewers with different focus areas rather than relying on one deep reviewer. Each reviewer in the Phase Y arc caught at least one issue the others missed.

---

## Appendix — PR #169 Review Comment Summary

| Source | Comment | Severity | Fixed? |
|---|---|---|---|
| Gemini bot | Shell robustness: empty glob in `no_generator_markers_in_fragments` | Medium | ⚠️ Not fixed (low risk) |
| Gemini bot | Comment filtering `^\s*//` not portable | Medium | ✅ e17426e |
| Gemini bot | `mutex_single_owner` allows multiple definitions in aggregator-runtime.h | Medium | ✅ e17426e (`-eq 1`) |
| Gemini bot | `maybe_yield` check susceptible to comment false positives | Medium | ✅ e17426e (`.*{` pattern) |
| Copilot reviewer (line 631) | `sensor_history_monolith_is_assembled` duplicates `firmware_core_assembly_check` | Low | ❌ Unresolved (acknowledged) |
| Copilot reviewer (inline) | `firmware_core_fragment_count` uses glob not explicit list | Medium | ✅ e17426e |
| Copilot reviewer (inline) | Comment-stripping regex not portable | Medium | ✅ e17426e |
| Copilot reviewer (line 727) | Noisy stderr if fragment missing during grep checks | Low | ✅ e17426e |
| ChatGPT Codex Connector (P2) | `deferred_task_pairs_in_expected_homes` presence-only; comment matches satisfy check | Medium | ❌ **Unresolved** |
| ChatGPT Codex Connector (P2) | `^\s*//` not whitespace in basic grep | Medium | ✅ e17426e |
| Codex review (#4230464210) | `mutex_single_owner` weak (`-gt 0` instead of `-eq 1`) | Medium | ✅ e17426e |
| Codex review | Non-portable `^\s*//` regex | Medium | ✅ e17426e |
| Codex review | `firmware_core_fragment_count` glob vs explicit list | Low | ✅ e17426e |
| Codex review | Noisy stderr on missing fragment | Low | ✅ e17426e |
| Codex review | README still had "53 checks" stale count | Low | ✅ e17426e |
| GPT review (#4230476334) | `maybe_yield` presence-not-definition | Medium | ✅ (current `.*{` pattern) |
| GPT review | `phaseY-results.md` "main is at v7.6.6.8" pre-merge | Medium | ✅ (current file corrected) |
| GPT review | `session-handoff-v7.6.6.8.md` reference mismatch | Medium | ✅ (file exists in `prompts/handoff/phaseY/`) |
| GPT review | `sensor_history_monolith_is_assembled` redundant | Low | ❌ Unresolved (acknowledged) |
| Perplexity review (#4230479670) | `maybe_yield` definition semantics | Medium | ✅ (current `.*{` pattern) |
| Perplexity review | Missing consolidated audit `v7.6.6.8-PR169-…` | Medium | Post-merge deliverable |
| Perplexity review | `phaseY-results.md` pre-merge wording | Medium | ✅ Corrected |
| Perplexity review | Fixture version skip (v7.6.6.5 → v7.6.6.8) | Low | Informational |
| Perplexity review | Double `---` in `Docs/lessons/firmware.md` | Cosmetic | ❌ **Still open** |
| Operator synthesis | Session log absent for v7.6.6.8 | Low/Required | ❌ **Still open — do not merge** |

---

_End of Phase Y Closure Analysis._
