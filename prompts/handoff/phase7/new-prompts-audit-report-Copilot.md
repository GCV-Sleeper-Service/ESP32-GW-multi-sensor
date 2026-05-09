# Phase 7 Batch 2 — New Prompts Audit Report

_Auditor: Copilot (GitHub)_
_Date: 2026-05-09_
_Scope: 10 documents produced after Batch 1 post-mortem + updated meta-prompt_

---

## 1. Executive Summary

- **Overall verdict: CONDITIONAL PASS — corrections required before use.** The producer correctly identified all six root causes and addressed all 10 operator concerns at the process layer. However, Batch 2 contains independently-confirmed code-level defects (function-signature drift, struct byte-size inaccuracies, version-bump ordering) that must be corrected before the prompts are given to an implementation agent.
- **E-1 fixed (§9 title bug).** All three agent prompts rename §9 to "Post-Merge Bookkeeping (tag and close only)" and explicitly state "No documentation work here." (`prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` §9 line 557).
- **E-3 partially fixed.** Board IPs are now correct (.170 for WROOM, .189 for C3) in all three handoffs, but the YAML filename for WROOM is not mentioned explicitly in any prompt — only the C3 YAML is referenced. The Board Info Extraction Gate was added to the meta-prompt but its output was not captured/verified in a gate table within the produced prompts.
- **v7.7.1.3 session handoff is significantly thinner** than v7.7.1.2 and v7.7.1.4 — it omits the Critical Rules table, Architecture references section, and Risk section that the other handoffs contain.
- **v7.7.1.4 §3 scope boundary is not self-contained** — it says "see v7.7.1.2 prompt §3 for full list" for bump-version.sh artifacts, requiring the agent to cross-reference another prompt at runtime.
- **No `Docs/development-process-guide.md` §2.5 in-PR-deliverables conformance failures.** All three agent prompts mandate the in-PR deliverables (session log, consolidated audit, CURRENT-STATE.md, changelog) in §6/§7. Methodology gaps in v7.7.1.3 artifacts are detailed in §4 and §6.
- **Must-fix items:** (a) v7.7.1.3 handoff missing Critical Rules table + Risk section; (b) v7.7.1.4 §3 self-containedness; (c) code-level defects in embedded C++ (struct sizes, function-signature drift, version-bump ordering) — see §7 for full list. The meta-prompt's Deliverables Per Step header at l.155 already reads `(§1-§10)` — the numbered-sections inconsistency has been corrected; no gap there.
- **CI trigger issue self-analysis is correct.** PR#226 triggered CI because it contained `firmware/core/` and `dashboard/` changes from `bump-version.sh`, not because of the prompts file placement.

---

## 2. Operator Concerns Coverage Matrix

| # | Operator Concern (`operator-notes.txt`) | Addressed In | Coverage | Evidence |
|---|---|---|---|---|
| 1 | Post-merge doc deliverables recurred in new prompts (audit, CURRENT-STATE.md, session log listed as §9) | `phase7-batch-production-prompt-update.md` Errata E-1; all three agent prompts §6/§9 | **Fully** | `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` §9: "No documentation work here." |
| 2 | Device testing (compile, upload, curl) punted entirely to operator | Errata E-2; `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` §6 Task Group 3; `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` §6 | **Fully** | v7.7.1.3 §6: `esphome upload ... --device=192.168.120.189`, curl commands agent-run |
| 3 | Stale WROOM IP (.190) | Errata E-3; Board Info Extraction Gate in meta-prompt; all handoffs | **Fully** | `session-handoff-v7.7.1.2.md` Board Fleet table: WROOM-32D at 192.168.120.170 |
| 4 | Stale WROOM YAML filename (`esp32-wroom-32d-multi-sensor.yaml`) | Errata E-3 (stale board info); meta-prompt Board Info Extraction Gate | **Partially** | Gate in meta-prompt verifies from `scripts/provision.sh`. Correct YAML name not explicitly stated in any produced prompt |
| 5 | Agent stopped on `bump-version.sh` scope gate | Errata E-4; scope whitelist in §3 of all agent prompts | **Fully** | `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` §3: full 6-file + 6-artifact whitelist |
| 6 | Assembly `--check` before `--write` false failure | Errata E-5; all agent prompts and meta-prompt constraint | **Fully** | All prompts preamble: "`assemble-sensor-history.sh --write` BEFORE `--check`" |
| 7 | CI triggered by prompt file (why?) | `new-session-analysis-conclusion.txt` Issue 6 | **Fully** | Self-analysis: CI triggered by bump-version.sh `firmware/`+`dashboard/` artifacts in PR#226, not the prompts file |
| 8 | Agent should do device testing, not operator | Errata E-2; agent prompts §6 Task Group 3 | **Fully** | v7.7.1.3, v7.7.1.4: full flash+curl sequence in §6; operator only verifies serial log / visual dashboard |
| 9 | `development-process-guide.md` §4.1 Assumption Audit Gate was bypassed | Meta-prompt updated: explicit §4.1 cited in mandatory reading list | **Fully** | `phase7-batch-production-prompt-update.md` l.69: "§4.1 (Assumption Audit Gate)". Note: the meta-prompt cites §4.1, but the produced agent/handoff prompts do not propagate the §4.1 reference forward in their own Required Reading sections (see §6 P5). |
| 10 | `prompts/prompt-index-and-workflow.md` missed in planning | Meta-prompt line 71 mandatory reading item 6 | **Fully** | Both old and new meta-prompt include Critical Rules table in mandatory reading |

---

## 3. Updated Meta-Prompt Assessment

| Area | Original (`phase7-batch-production-prompt.md`) | Updated (`phase7-batch-production-prompt-update.md`) | Gap Still Present? |
|---|---|---|---|
| **§9 title / in-PR vs post-merge** | Missing; "post-merge deliverables" inherited pre-PhaseVY language | Errata E-1 added; §9 renamed to "Post-Merge Bookkeeping (tag and close only)" | No |
| **Mandatory reading for dev-process-guide** | "§2-3 (execution workflow, prompt structure)" — did not name §2.5 explicitly | Updated to list §2.3, §2.5, §3.2, §3.3, §4.1 explicitly (ll. 64-70) | No |
| **Board Info Extraction Gate** | Not present | Added (ll. 116-138): greps CURRENT-STATE.md, provision.sh, board profiles | No |
| **Spec File Path Gate** | Not present | Added (ll. 140-148): `find tests -name "*.spec.js" | sort` | No |
| **bump-version.sh scope whitelist** | Not present | Added (ll. 213-233): 6 source files + 6 regenerated artifacts listed | No |
| **HARD vs SOFT scope distinction** | Not present | Added (ll. 235-241) | No |
| **Assembly ordering constraint** | Not present | Added (ll. 243-250) | No |
| **Batch-Specific Context placeholders** | `[paste here]` at bottom | Same template structure with `[paste here]` — not pre-filled | No gap; placeholders are by design |
| **"Board Info Gate" output table** | N/A | Gate defined but no instruction to embed the extracted table into the produced prompts as a verification artifact | Gap — extraction happens in producer session, results are not made visible in the produced prompts |
| **Playwright spec file paths** | Old paths from pre-v7.6.5.7 could be used | Spec File Path Gate requires live `find` result | No |

**Will the updated meta-prompt prevent recurrence?** Mostly yes. The five documented defects (E-1 through E-5) are all structurally prevented. The remaining gap is that the Board Info Gate output is not required to appear as a table in the produced prompts — if the gate runs and finds correct values, there is no audit trail in the prompts themselves.

---

## 4. Conformance to Standards

| Document | `development-process-guide.md` | `writing-guide/methodology.md` | `multi-phase-session-run-instructions.md` §5 | `multi-phase-planning-session-summary.md` decisions honored |
|---|---|---|---|---|
| `phase7-batch-production-prompt-update.md` | ✓ §2.5 explicitly cited; in-PR deliverables enforced | ✓ 10-section anatomy followed; callouts included | ✓ Board Info Gate + Spec Gate address "stale analysis" scenario | ✓ PLAN-002 (EventLog for binary sensors) referenced |
| `session-handoff-v7.7.1.2.md` | ✓ Pre-merge checklist has "In-PR deliverables" block | ✓ Board fleet table, carries-forward, risk level present | ✓ Correct board IPs; measurements from v7.7.1.1 provided | ✓ ARCH-001, ARCH-002, PLAN-002 in design decisions table |
| `session-handoff-v7.7.1.3.md` | ✗ Pre-merge checklist minimal; **no Critical Rules table, no Architecture section, no Risk section** | ✗ Missing sections: risk quantification, architecture references, key design decisions | ✗ Shorter than predecessor — increases stale analysis risk for next session | ✓ Dual-write pattern, provisional slot limit correctly described |
| `session-handoff-v7.7.1.4.md` | ✓ Pre-merge checklist full; Critical Rules table present; Risk section complete | ✓ Architecture references, device testing plan, carries-forward all present | ✓ Board fleet verified; functions from prior steps listed | ✓ PLAN-001, PLAN-003, PLAN-005, ARCH-001 explicitly listed |
| `prompts/phase7/v7.7.1.2-claude-two-step.md` | ✓ In-PR deliverables checklist; post-merge tag-only explicit | ✓ External reviewer focus areas with specifics | N/A (execution prompt, not planning) | ✓ Struct sizes match architecture doc §5 |
| `prompts/phase7/v7.7.1.3-claude-two-step.md` | ✓ In-PR deliverables checklist; post-merge tag-only | ✗ External reviewer focus area #6 ("Yield compliance") lacks explanation of _why_ Rule 61 matters here | N/A | ✓ Dedup guard, ring buffer, NVS handle lifecycle covered |
| `prompts/phase7/v7.7.1.4-claude-two-step.md` | ✓ In-PR deliverables; post-merge tag-only | ✓ External reviewer focus: boot safety, budget math, metric mapping, memory safety, hash collision, power loss | N/A | ✓ 30% reserve, priority tiers (70/20/10), slot cap 999 from planning session Point 1 |
| `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` | ✓ §2.5 cited in §1 required reading; §6 has all 5 deliverables; §9 = tag only | ✓ §1-§10 present; code examples match architecture doc; checkpoints use grep counts not line numbers | ✓ Preflight pass stated; stale analysis prevented by verification gate §2 | ✓ PLAN-002 (EventLog), ARCH-002 (FNV-1a, 15-char NVS limit) |
| `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` | ✓ All in-PR deliverables in §6/§7; §9 tag-only | ✓ Code blocks provided; stop-don't-fix checkpoints | ✓ Agent runs device testing; §2 gate before changes | ✓ DEV_PERSIST_PROVISIONAL_SLOTS = 360 pending budget (PLAN-003 deferred to v7.7.1.4) |
| `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | ✗ §3 scope boundary says "see v7.7.1.2 prompt §3 for full list" — **not self-contained** (dev-process-guide §3.3 requires scope be in the prompt) | ✓ §1-§10 present; memory safety and collision detection addressed | ✓ Agent performs mandatory device test before marking PR ready | ✓ All PLAN-00x decisions from planning session cited in key design table |

---

## 5. Accuracy of Producer's Self-Analysis (`new-session-analysis-conclusion.txt`)

**Claims that are correct:**
- Issue 1 (§9 title caused confusion): Accurate. The pre-PhaseVY prompt anatomy named §9 "Post-Merge Deliverables" — agents follow section titles literally.
- Issue 2 (device testing delegated): Accurate. The Batch 1 prompts had a separate "§10 Operator Device Testing" which agents cannot execute.
- Issue 3 (stale board info from memory): Accurate. The v7.7.1.1 session handoff `operator-notes.txt` line 112 confirms WROOM IP was .190 instead of .170.
- Issue 4 (bump-version.sh touches 6+ files): Accurate and complete — the 6-file list matches `scripts/bump-version.sh` actual behavior.
- Issue 5 (--check before --write): Accurate.
- Issue 6 (CI triggered by code changes, not prompts file): Accurate — `firmware/core/` and `dashboard/` paths in PR#226 match CI filter in `.github/workflows/ci.yml`.

**Claims that are wrong or overstated:**
- Self-analysis says fix for Issue 3 is "read CURRENT-STATE.md" — but the producer's own Batch 1 instructions already said "CURRENT-STATE.md wins" (original meta-prompt l.45). The fix was not just re-reading; it required an _extraction gate_ that mechanically verifies specific values. The self-analysis understates the root cause.

**Things the self-analysis missed:**
- The WROOM YAML filename error (mentioned in operator-notes.txt l.110-111) is not identified as a distinct root cause — it's folded into Issue 3 but was a separate artifact (wrong filename vs wrong IP).
- The self-analysis does not mention the filename typo in prompts/handoff/phase7/new-prompts-audit-session.txt line 25: `prompts/phase7/v7.7.1.3-claude-two-step.md-` (trailing dash). The file was produced with the correct name but operator listed it with a dash — this should have been flagged.
- No mention of `development-process-guide.md` §2.5 item 5 (next-step handoff updates must be in-PR) — the handoffs for v7.7.1.2/1.3/1.4 were produced as a batch simultaneously, which is correct; but the self-analysis doesn't acknowledge this as a positive pattern.

---

## 6. Quality vs. Previous Batch

| Quality Dimension | v7.7.1.0/1.1 (Batch 1) | v7.7.1.2/1.3/1.4 (Batch 2) | Change |
|---|---|---|---|
| **In-PR deliverables enforcement** | Listed in §9 (post-merge) | Listed in §6 task groups + §7 acceptance criteria | ⬆ Significant improvement |
| **Scope boundary self-containedness** | Full lists per prompt | v7.7.1.2: full list; v7.7.1.3: full list; v7.7.1.4: cross-reference to v7.7.1.2 | ⬇ Minor degradation in v7.7.1.4 |
| **Board info accuracy** | Wrong WROOM IP (.190), wrong YAML filename | Correct IPs in all three handoffs; YAML filename not stated | ⬆ Improvement (partial) |
| **Device testing** | §10 "Operator Device Testing" (operator-only) | §6 Task Group 3 with agent-run commands in v7.7.1.3/1.4; v7.7.1.2 correctly skips (additive only) | ⬆ Significant improvement |
| **Handoff consistency** | v7.7.1.1 handoff: complete (risk, critical rules, workflow) | v7.7.1.2: complete; v7.7.1.3: thin (no critical rules table, no risk section); v7.7.1.4: complete | ⬇ **Degradation in v7.7.1.3 handoff** |
| **Checkpoint quality** | Used grep counts, not line numbers | Same pattern maintained | = No change |
| **Playwright gate commands** | Old spec paths (`tests/mixed.spec.js`) | Correct spec paths (`tests/browser/*.spec.js`) with FIXTURE_SET matrix | ⬆ Improvement |
| **Process lessons preamble** | Not present | E-1 through E-5 + LESSON-OPS-NEW-B/C in all agent prompts | ⬆ New pattern; effective |
| **Architecture references in handoffs** | v7.7.1.1: full references | v7.7.1.2: full; v7.7.1.3: minimal; v7.7.1.4: full | ⬇ v7.7.1.3 regression |
| **§4.1 Assumption Audit Gate cited in §1 Required Reading of produced prompts (P5)** | Not present | Not present (only meta-prompt cites it; none of the three agent prompts or handoffs carry the §4.1 reference in their own §1 Required Reading sections) | = No improvement at the produced-prompt layer; meta-prompt is the only enforcement point |

---

## 7. Required Fixes — Produced Documents

| File | Section/Line | Problem | Recommended Fix | Why |
|---|---|---|---|---|
| `session-handoff-v7.7.1.3.md` | Missing sections | No Critical Rules table, no Architecture references section, no Risk section, no Workflow section | Add Critical Rules table (Rules 2, 11, 40, 58, 61, 62, 63, 64, 67 with Why column), add Risk: MEDIUM block, add Architecture references citing `Docs/v7.7-v7.8-persistence-architecture.md §10` | v7.7.1.2 and v7.7.1.4 handoffs are complete; v7.7.1.3 is an outlier that will make the next session incomplete |
| `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | §3, l.97-98 | Scope boundary references "v7.7.1.2 prompt §3 for full list" — agent prompt must be self-contained per `Docs/development-process-guide.md` §3.3 | Inline the complete bump-version.sh whitelist (6 source files + 6 artifacts) into §3, same as v7.7.1.2 §3 ll.98-111 | If agent cannot access v7.7.1.2 prompt (different session), scope boundary is undefined |
| `prompts/phase7/v7.7.1.3-claude-two-step.md` | Step 2, reviewer item 6 | "Yield compliance (Rule 61): Is `maybe_yield_nvs_scan_()` called correctly between device persists?" — no explanation of _why_ | Add: "(Omitting this causes watchdog resets under multi-device NVS iteration — see `Docs/lessons/firmware.md`)" | `Docs/writing-guide/methodology.md` §3.2: good prompts state the "trap" not just the item |
| `session-handoff-v7.7.1.3.md` | Pre-merge checklist | Missing `NI-001`, `NI-002`-style open-item tracking from v7.7.1.1 | Add any open issues discovered during v7.7.1.2 (BUG-084 is noted in issues table but not in pre-merge checklist) | Checklist is the operator's gate; gaps lead to missed items |
| `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` and `v7.7.1.4-agent-prompt-gpt-codex.md` | §6 task ordering (R1) | **Version-bump ordering:** `bash scripts/bump-version.sh` runs in Task Group 4 / Task Group 6, AFTER the full compile-upload-curl device test sequence in Task Group 3 / Task Group 5 respectively. `/api/status` will report the previous version during the device-evidence step (`v7.7.1.3-agent-prompt-gpt-codex.md` §6 l.390: `# Expected: version shows 7.7.1.3`; `v7.7.1.4-agent-prompt-gpt-codex.md` §6 l.477: `# Expected: version 7.7.1.4, no crash`). | Move `bash scripts/bump-version.sh <version>` to run as Step 1 of §6 — before any compile, upload, curl, or device test. Re-run the compile after the bump so the resulting binary reports the correct version. | Device evidence must come from firmware reporting the target version; flashing pre-bump firmware and checking `/api/status` version is false evidence. |
| `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | §6 Task Group 1, l.162 (R2) | **Function-signature drift:** embedded code calls `find_partition_size_bytes_(HISTORY_PARTITION_LABEL, &partition_bytes)` (2 args, output-pointer convention). Live signature (`firmware/core/nvs-persistence.h:44`) is `static uint32_t find_partition_size_bytes_(const char *label, esp_partition_type_t type, esp_partition_subtype_t subtype)` — 3 args, return-value convention. The prompt call will not compile. | Replace the embedded call with: `uint32_t partition_bytes = find_partition_size_bytes_(HISTORY_PARTITION_LABEL, ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_ANY);` — or replace embedded code block with a `grep`-then-implement instruction citing the live signature. | Compile failure on first agent run; writing guide §(Phase 6 lessons) requires prompt-provided code to match current repo signatures. Additionally, the §2 Pre-Implementation Verification Gate checks that `find_partition_size_bytes_` exists (`grep -c 'find_partition_size_bytes_' firmware/core/nvs-persistence.h`, expected: 1) but does not validate the parameter list or return type; the agent will encounter the signature mismatch at compile time, not at the pre-implementation gate. Add an explicit signature check (e.g., `grep -A2 'find_partition_size_bytes_' firmware/core/nvs-persistence.h`) to §2. |
| `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` | §6 Task Group 1 struct comments (R3) | **Struct byte-size comments incorrect due to C++ padding.** Independent arithmetic: `DeviceHistoryMeta` has 2 bytes of implicit padding before `last_persist_epoch` → 40 bytes (comment says 36). `DeviceSegmentHeader` has 2 bytes padding before `saved_at_epoch` → 24 bytes (comment says 22). `DeviceSegment` = 24+12+192 = 228 bytes (comment says 226). Retention budget math in v7.7.1.4 depends on `sizeof(DeviceSegment)`. | Replace narrative `// sizeof(X) = N bytes` comments with `static_assert(sizeof(DeviceHistoryMeta) == 40, "size mismatch");` etc., letting the compiler prove the sizes. Correct the architecture doc's byte counts if they repeat the same values. | Inaccurate struct sizes affect NVS space estimates and retention budget calculations; a 2-byte undercount per segment accumulates across thousands of segments. |
| `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` | §6 Task Group 1, CHECKPOINT A, l.298-299 (R4) | **Checkpoint grep counts usages, not definitions.** `grep -c 'DEV_HIST_MAGIC\|DEV_HIST_VERSION\|MAX_PERSIST_METRICS' firmware/core/data-model.h` returns a count of all lines containing any constant name — definitions AND field-initializer usages (e.g., `uint32_t magic = DEV_HIST_MAGIC;`). Actual count will be significantly higher than 3; comment `# Expected: 3` will produce a false checkpoint failure even when code is correct. | Tighten to: `grep -cE '^static constexpr.*(DEV_HIST_MAGIC|DEV_HIST_VERSION|MAX_PERSIST_METRICS)' firmware/core/data-model.h` (expected: 3, counts definition lines only). | Checkpoint will fail on correct code, causing the agent to stop needlessly; or the agent will "explain away" the mismatch, violating the stop-don't-fix rule. |
| `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | §6 Task Group 3 (P1) | **Budget calculator invoked per-persist.** `calculate_retention_budgets_()` is called inside the `persist_device_segment_()` edit block on every write (line ~393: `calculate_retention_budgets_(budgets, NUM_DEVICES);`), allocating a stack array and iterating all devices to find the budget for one device — O(NUM_DEVICES²) per persist cycle. No caching or staleness guard is present. | Cache the result at boot and recompute only when device count or partition size changes; OR add a DO-NOT note in §5 explicitly accepting the cost: "Do NOT refactor budget caching — deferred optimization." | NVS persists are on the hourly hot-path. Recomputing partition geometry on every write wastes CPU and may worsen yield-budget compliance (Rule 61). Without a DO-NOT note a reviewer will flag it as a defect and an agent may attempt an unauthorized caching change. |
| `prompts/phase7/v7.7.1.3-claude-two-step.md` | Step 2, reviewer checklist (P3) | **Provisioning state not verified before flash.** The reviewer checklist verifies NVS write correctness but does not include a check that `bash scripts/provision.sh satellite` was run and status returned `c3-default` before the device was flashed. | Add a reviewer item: "Confirm `bash scripts/provision.sh status` returned `c3-default` before flash; otherwise the device test ran against the wrong configuration." | Flashing a non-satellite-provisioned device gives invalid measurements. The v7.7.1.2 agent prompt already includes `bash scripts/provision.sh satellite` in its §8 pipeline — the v7.7.1.3 reviewer checklist should not regress. |


---

## 8. Required Fixes — Upstream Documents

| Document | Section | Problem | Recommended Fix | Why |
|---|---|---|---|---|
| `Docs/development-process-guide.md` | §2.5, item 4 | "Consolidated audit file — for non-trivial steps" does not define what "non-trivial" means, nor what the minimum audit file must contain | Add: "All Batch 2+ implementation steps are non-trivial. The audit file must contain: (1) review findings by severity, (2) agent autonomous decisions classified as helpful/harmful/neutral, (3) prompt quality score." | Without this, producers must guess — and Batch 1 session logs were omitted precisely because the criterion was unclear |
| `Docs/development-process-guide.md` | §3.3 | Scope guard section says prompts must list files; does not say prompts must be self-contained (no cross-references to other prompts) | Add: "Agent prompts must not cross-reference other prompts for scope or constraint information. Every prompt must be executable standalone." | Prevents the v7.7.1.4 §3 self-containedness defect from recurring in Batch 3+ |
| `Docs/multi-phase-session-run-instructions.md` | §5 | Troubleshooting section covers planning session; there is no analogous troubleshooting guide for the prompt production session | Add §6 "Prompt Production Session Troubleshooting" covering: stale board info, wrong spec paths, §9 title drift, bump-version.sh scope violations | These are the four failure modes from Batch 1; documenting them here closes the process loop |
| `Docs/writing-guide/methodology.md` | §3.10 | Device Testing section says "step-by-step verification the human performs after merge" — still uses "human performs" language | Update to: "Agent performs compile, upload, and curl verification. Human (operator) performs only: visual dashboard rendering, serial log capture when agent lacks TTY access." | The "human performs" language was the proximate cause of E-2 in Batch 1 |
| `prompts/handoff/phase7-batch-production-prompt-update.md` | Board Info Extraction Gate (ll.116-138) | Gate verifies board info but does not require the extraction results to be embedded as a table in each produced prompt | Add instruction: "After running Board Info Extraction Gate, embed the populated table into each produced handoff's 'Codebase state entering vX.Y.Z.W' section and note which grep confirmed it." | Without an artifact, the gate can be skipped silently in future sessions |
| `Docs/writing-guide/methodology.md` vs `Docs/development-process-guide.md` | Doctrinal precedence | `Docs/writing-guide/methodology.md` §3 still describes §9 anatomy in terms that can be read as "post-merge deliverables"; `Docs/development-process-guide.md` §2.5 says those deliverables are in-PR. The producer can be tripped by the older doc when both are in the mandatory reading list, because there is no explicit hierarchy statement. | Add a one-sentence precedence rule to **both** docs and to the meta-prompt: "Where `Docs/writing-guide/methodology.md` and `Docs/development-process-guide.md` conflict, `Docs/development-process-guide.md` governs." | Batch 1 failed precisely because the producer followed the older anatomy habit; without an explicit hierarchy this will recur in any future prompt-production session that reads both documents. |
| `prompts/handoff/phase7-prompt-production-instructions.md` | Whole file (P4) | **Possibly-stale predecessor instructions still in the repo.** The file exists and carries Batch-1-era anatomy: l.147 reads "10. Post-merge deliverables (CURRENT-STATE.md, changelog, session log)" — placing those items as post-merge, which is the same doctrinal error that caused Batch 1 failures. It is not marked as superseded. | Either delete the file (superseded by `prompts/handoff/phase7-batch-production-prompt-update.md`) or prepend a banner: "⛔ SUPERSEDED — see `prompts/handoff/phase7-batch-production-prompt-update.md`. Do not use this file for Batch 2+ sessions." | A future prompt producer who discovers this file will follow its §9-as-post-merge anatomy, recreating the Batch 1 failure mode. The Batch-1 failure root cause was doctrinal drift; leaving stale instruction docs without supersession notices invites recurrence. |

---

## 9. Process Recommendations to Prevent Recurrence

- **Pre-flight diff against `development-process-guide.md` §2.5.** Before finalizing any prompt batch, the producer must run: `grep -n 'post.merge\|Post.Merge\|Post-Merge' <agent-prompt>` and verify that only "tag and close" language appears in §9. This is an explicit gate, not a judgment call. Evidence: Batch 1 bypassed §2.5 because the prompt listed "§2-3" not "§2.5" — a one-character omission with large consequences.

- **Board Info Extraction Gate output must be committed, not just run.** Add a requirement that the producer creates a `prompts/handoff/phase7/batch2-board-info-verified.md` (or equivalent) file showing the extraction output. Commit it alongside the prompts. This creates an audit trail.

- **Mandatory self-containedness assertion in meta-prompt.** Add to the Constraints list: "Every agent prompt must be independently executable. If §3 references another prompt for scope info, that is a blocking defect." This directly prevents the v7.7.1.4 cross-reference pattern.

- **Add a "Prompt Anatomy §9 audit" step to the operator's Post-Production Checklist.** Currently the checklist (meta-prompt ll.282-300) asks "File paths verified, checkpoint grep counts mechanically correct..." — add: `[ ] §9 of each agent prompt contains ONLY: git tag command + issue close. No documentation tasks.`

- **Consistent handoff depth policy.** Define a minimum required section set for all handoffs: (1) Project State Summary, (2) Progress Table, (3) Scope (does/does not), (4) Files modified, (5) Critical Rules table, (6) Risk assessment, (7) Pre-merge checklist with In-PR deliverables block, (8) Context That Carries Forward. v7.7.1.3 violates items 5, 6, and the carries-forward depth compared to v7.7.1.2. Add this list to the meta-prompt §Deliverables Per Step.

- **Playwright fixture matrix must appear in every agent prompt §6 or §8, not just v7.7.1.2.** v7.7.1.3 and v7.7.1.4 have the fixture matrix in §6 Task Group 4 — good. Verify each future batch prompt includes the matrix rather than inheriting it by reference.

- **Document the "agent stops on gates" pattern in `Docs/development-process-guide.md`.** The Batch 1 agent stopped because `bump-version.sh` crossed stated scope boundaries. The fix (whitelist) is now in prompts — but it belongs in the process guide as a permanent policy, not just in individual prompts.

- **Mandatory Prompt Code Quality Gate.** Before publishing any prompt that embeds C++/YAML/JS/Shell code, the producer must: (a) `grep` the live repo for every called function/symbol and confirm the signature matches the embedded call site (`firmware/core/nvs-persistence.h:44` as a model); (b) for C++ structs, replace narrative `// sizeof(X) = N bytes` comments with `static_assert(sizeof(X) == N, "...");` lines so the compiler — not the prompt author — proves the size; and (c) ensure `bump-version.sh` runs before any device-evidence step so the reported version matches the target. This gate would have caught all three independently-confirmed defects (R1, R2, R3) and is the single biggest gap in both Batch 1 and Batch 2 prompt production.

---

### Cross-audit reconciliation (Copilot / GPT / Perplexity)

Three independent audits were run on Batch 2: this report (Copilot), `prompts/handoff/phase7/phase7-batch2-prompt-audit-report-GPT.md`, and `prompts/handoff/phase7/new-prompts-audit-report-Perplexity.md`. They agree on all process-layer findings (§9 title fix, board IPs, bump-version.sh whitelist, `--write` before `--check`, CI trigger explanation). They disagree on the verdict: GPT says "do not use as-is", this report says **CONDITIONAL PASS**, Perplexity says "ready for execution". The CONDITIONAL PASS verdict is retained because the **union of findings includes 4 HIGH/MEDIUM code-level defects** (function-signature drift, struct byte-size accuracy, version-bump ordering, per-persist budget recomputation) that must be corrected before execution. Perplexity's claim that `Docs/writing-guide/methodology.md` did not contribute to Batch 1 failures is rejected; the doctrinal-precedence row in §8 stands.

---

_End of audit report. All citations verified against files in the repository as of 2026-05-09._

_Line numbers verified against commit `5804564`; section anchors are stable, line numbers may shift after later edits._
