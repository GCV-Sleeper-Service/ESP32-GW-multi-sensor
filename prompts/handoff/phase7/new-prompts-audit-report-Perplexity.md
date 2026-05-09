# Phase 7 Batch 2 Prompts — Audit Report (Perplexity)

_Date: 2026-05-09_
_Auditor: Perplexity AI_
_Scope: Batch 2 prompt bundle — v7.7.1.2, v7.7.1.3, v7.7.1.4 and the updated batch production prompt_
_Reference documents read:_
- `prompts/handoff/phase7/operator-notes.txt`
- `prompts/handoff/phase7/new-session-analysis-conclusion.txt`
- `prompts/handoff/phase7-batch-production-prompt-update.md`
- `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md`
- `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md`
- `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`
- `prompts/phase7/v7.7.1.2-claude-two-step.md`
- `prompts/phase7/v7.7.1.3-claude-two-step.md` _(note: listed as `v7.7.1.3-claude-two-step.md-` in audit-session.txt — correct filename confirmed as `v7.7.1.3-claude-two-step.md`)_
- `prompts/phase7/v7.7.1.4-claude-two-step.md`
- `prompts/handoff/phase7/session-handoff-v7.7.1.2.md`
- `prompts/handoff/phase7/session-handoff-v7.7.1.3.md`
- `prompts/handoff/phase7/session-handoff-v7.7.1.4.md`
- `Docs/development-process-guide.md`
- `Docs/writing-guide/methodology.md`
- `Docs/multi-phase-session-run-instructions.md`

---

## 1. Operator Concerns — Resolution Check

| # | Operator Concern | Addressed in Batch 2? | Evidence |
|---|---|---|---|
| E-1 | Post-merge deliverable confusion (audit, session log, CURRENT-STATE.md listed in §9) | ✅ YES | All three agent prompts list docs in §6; §9 explicitly says "tag and close only" |
| E-2 | Device testing punted to operator | ✅ YES | v7.7.1.3 §6 Task Group 3 and v7.7.1.4 §6 Task Group 5 are full agent-run compile/upload/curl sequences |
| E-3 | Stale board info (IP .190 → .170, wrong YAML name) | ✅ YES | All three prompts use C3 IP 192.168.120.189 and WROOM 192.168.120.170. Board Info Extraction Gate added to batch-production-prompt-update.md |
| E-4 | `bump-version.sh` scope violations (6+ source files not whitelisted) | ✅ YES | §3 of each agent prompt explicitly lists all bump-version.sh artifacts as "NOT scope violations" |
| E-5 | Assembly `--check` before `--write` ordering | ✅ YES | All checkpoints in all three prompts correctly order `--write` then `--check` |
| E-6 | CI trigger misunderstanding (CI ran due to code changes, not doc files) | ✅ YES (analysis only) | Correctly explained in `new-session-analysis-conclusion.txt` §Issue 6; no prompt change needed |
| Scope gate too broad → agent stop | ✅ YES | HARD/SOFT scope distinction implemented in all three agent prompts |
| Agent stop on bump-version.sh gate | ✅ YES | bump-version.sh artifacts explicitly whitelisted in §3 of each prompt |

**Verdict: All operator concerns from `operator-notes.txt` are addressed in the new prompts.**

---

## 2. Updated Batch Production Prompt — Sufficiency Assessment

| Area | Assessment | Notes |
|---|---|---|
| Errata table (E-1 through E-5) | ✅ Complete | All five defects documented with root cause and fix applied |
| Board Info Extraction Gate | ✅ New, correctly placed | Added as mandatory pre-production step before writing any device commands |
| Spec File Path Gate | ✅ New | Forces `find tests -name "*.spec.js"` before referencing Playwright paths |
| Scope boundary (HARD/SOFT) | ✅ New | Clearly defined with examples and rationale |
| Assembly checkpoint ordering | ✅ New | `--write` before `--check` constraint is now a top-level rule |
| Device testing delegation | ✅ New | Agent vs. operator division of labor explicitly documented |
| §9 rename to "Post-Merge Bookkeeping (tag and close only)" | ✅ Done | All three agent prompts comply |
| Mandatory reading order | ✅ Expanded | Includes `development-process-guide.md` FULL document requirement |
| Batch-specific context section | ⚠️ PARTIALLY COMPLETE | Template placeholders (`[paste here]`, `[from CURRENT-STATE.md]`) are left unfilled in the current document. This is the prompt **template** — operator must fill before pasting into session. This is by design but warrants a prominent ⛔ warning block above the placeholders. If passed to the prompt producer unfilled, it will produce prompts with placeholder values. **Recommendation: add a ⛔ warning block above each unfilled placeholder.** |
| Assumption Audit Gate (§4.1 of dev-process-guide) | ⚠️ NOT EXPLICITLY REFERENCED | The batch-production-prompt-update.md mandatory reading list says "READ THE FULL DOCUMENT" for `development-process-guide.md`, which technically covers §4.1. However, given that §4.1 was identified as a missed section in the Batch 1 failure, it warrants an explicit callout matching the other sections (§2.3, §2.5, §3.2, §3.3, §4.1, §4.3). |

**Verdict: Sufficient for Batch 2 production. Two improvements recommended above for Batch 3+.**

---

## 3. Compliance with `Docs/development-process-guide.md` and `Docs/writing-guide/methodology.md`

### 3.1 Development Process Guide

| §Section | Requirement | v7.7.1.2 | v7.7.1.3 | v7.7.1.4 |
|---|---|---|---|---|
| §2.5 In-PR deliverables | Code, CURRENT-STATE.md, changelog, audit, session log | ✅ | ✅ | ✅ |
| §2.5 Post-merge = tag only | §9 contains ONLY tag command | ✅ | ✅ | ✅ |
| §2.3 Device testing | Agent runs compile/upload/curl | N/A (no runtime change) | ✅ | ✅ |
| §3.2 Checkpoint authoring | Queries, not assertions; stop-don't-fix | ✅ | ✅ | ✅ |
| §3.3 Scope guards | Named files, HARD/SOFT distinction | ✅ | ✅ | ✅ |
| §4.1 Assumption Audit Gate | Pre-production assumption verification | Implicit (via verification gates) | Implicit | Implicit |

### 3.2 Writing Guide / Methodology (`Docs/writing-guide/methodology.md`)

| Requirement | v7.7.1.2 | v7.7.1.3 | v7.7.1.4 |
|---|---|---|---|
| 10-section prompt anatomy | ✅ §1–§10 present | ✅ | ✅ |
| Required reading with specific callouts (§3.2) | ✅ functions and structs named | ✅ | ✅ |
| Exact CI commands matching matrix (§3.4b) | ✅ All FIXTURE_SET variants | ✅ | ✅ |
| Stop-don't-fix checkpoint semantics | ✅ "STOP and post actual vs expected" | ✅ | ✅ |
| `--write` before `--check` (§4.4 checkpoint pattern) | ✅ | ✅ | ✅ |
| Universal execution preamble | ✅ | ✅ | ✅ |

**Verdict: All three agent prompts comply with both documents.**

---

## 4. Session Analysis Accuracy (`new-session-analysis-conclusion.txt`)

The prompt producer's self-analysis identified six issues (Issues 1–6). Assessment:

| Issue | Analysis Accuracy | Assessment |
|---|---|---|
| Issue 1 — §9 title drove post-merge confusion | ✅ Accurate | The inherited "§9 — Post-Merge Deliverables" title was the structural cause. The fix (rename + move docs to §6) is the correct remediation. |
| Issue 2 — Device testing punted to operator | ✅ Accurate | Root cause correctly identified: separate "Operator Device Testing" section trained agents to treat it as operator-only. |
| Issue 3 — Stale board info (.190, wrong YAML) | ✅ Accurate | Root cause: batch production prompt said "read CURRENT-STATE.md" but did not require extracting specific values before writing prompts. Board Info Extraction Gate is the correct fix. |
| Issue 4 — Scope + bump-version.sh gate | ✅ Accurate | The 4-file scope list vs 12+ files modified by bump-version.sh was the correct cause. |
| Issue 5 — Assembly `--check` before `--write` | ✅ Accurate | Checkpoint ordering was the structural cause. |
| Issue 6 — CI trigger explanation | ✅ Accurate | CI ran due to code changes from bump-version.sh, not doc files. Correctly exonerates the prompt-generated consolidated audit file. |

**Verdict: The analysis is factually accurate, on-point, and correctly diagnoses all six root causes. No invented or unverifiable claims.**

---

## 5. Section 5 Gate Check (`Docs/multi-phase-session-run-instructions.md`)

Section 5 of `multi-phase-session-run-instructions.md` is the **Troubleshooting** section for the multi-phase planning session. The check here is whether the Batch 2 prompts prevent the failure modes described there.

| Troubleshooting Scenario | Mitigated in Batch 2 Prompts? |
|---|---|
| Advisor produces stale analysis (wrong version, wrong files) | ✅ Pre-implementation verification gate in §2 of each prompt catches this at execution time |
| Measurement data wrong | ✅ Board Info Extraction Gate forces fresh read of CURRENT-STATE.md before writing device commands |
| Recommendation contradicts decision log | ✅ Stop-don't-fix checkpoints; agent must flag discrepancies rather than silently correct them |
| Output hits context limit mid-step | ✅ Universal preamble Rule 5: "If you run out of context, STOP at the last completed checkpoint and report what remains" |

**Verdict: All four §5 troubleshooting scenarios are mitigated by the Batch 2 prompt structure.**

---

## 6. Prompt Quality and Regression Check

### 6.1 Content Density vs. Previous Steps

| Dimension | v7.7.1.0/v7.7.1.1 (Batch 1) | v7.7.1.2–v7.7.1.4 (Batch 2) | Delta |
|---|---|---|---|
| Checkpoint count per prompt | 1–2 | 2–3 | ✅ Improved |
| Explicit in-PR deliverable callouts | Missing from §9 | Correctly in §6 | ✅ Fixed |
| Board info in device testing sections | Stale (.190) | Correct (.189 C3, .170 WROOM) | ✅ Fixed |
| Scope whitelist for bump-version.sh | Absent | Explicit in §3 | ✅ Fixed |
| HARD/SOFT scope distinction | Absent | Present in all three | ✅ Added |
| Process lessons section ("⚠️ Lessons") | Absent | Present in all three | ✅ Added |
| Critical Rules subset | Present | Present + expanded (Rule 67 added) | ✅ Maintained |
| Device testing (v7.7.1.3+) | N/A | Full compile/upload/curl in §6 | ✅ Added |
| Two-step reviewer checklists | Thin | Step-specific NVS/ring-buffer focus | ✅ Improved |

### 6.2 Quality Findings

| Prompt | Finding | Severity | Details |
|---|---|---|---|
| `v7.7.1.4-agent-prompt-gpt-codex.md` | Budget calculator called per-persist | **MEDIUM** | In Task Group 3, `persist_device_segment_()` is updated to call `calculate_retention_budgets_()` on every hourly persist, iterating all devices to find the budget for one device. This is O(NUM_DEVICES²) per persist cycle. For current fleet size this is harmless, but without an explicit note, a reviewer will flag it as a defect and an agent may "fix" it with an unauthorized caching change. **Recommended fix before v7.7.1.4 execution:** add a comment in the code block and a DO-NOT entry: "Do NOT cache the budget calculation result — deferred optimization. Call `calculate_retention_budgets_()` as shown." |
| `v7.7.1.4-agent-prompt-gpt-codex.md` | `find_partition_size_bytes_()` assumed to exist | **MEDIUM** | §2 verification gate checks for this function. The prompt does not state when or where it was added. If it does not exist in nvs-persistence.h when v7.7.1.4 runs, the gate will STOP the agent correctly — but operator will need to know which step should have added it. **Recommended:** operator should grep for `find_partition_size_bytes_` in nvs-persistence.h on main before v7.7.1.4 starts and confirm it is present. |
| `v7.7.1.3-claude-two-step.md` | Reviewer checklist missing provision restore check | **LOW** | The checklist verifies NVS write correctness but does not include a check that `bash scripts/provision.sh satellite` was run after device testing — which is a mandatory runtime step in the agent prompt (Task Group 3) but absent from the reviewer's verification list. |
| `v7.7.1.3-agent-prompt-gpt-codex.md` | EventLog persist path deferred | **LOW-INFO** | §5 DO-NOT correctly states "No EventLog persist path yet (binary sensors not in current manifest)." Factually correct. Flagged for awareness: if the manifest changes before v7.7.1.3 executes, this deferral should be revisited. Not a defect. |
| `session-handoff-v7.7.1.3.md` | Less detailed than v7.7.1.2 handoff | **LOW** | The v7.7.1.2 handoff includes: board fleet table, logger level note, fragment count note, key design decisions table, and critical rules table. The v7.7.1.3 handoff has the board fleet table but is missing the critical rules table and key design decisions table. Not blocking but reduces operator self-sufficiency. |

### 6.3 Alignment with `Docs/multi-phase-planning-session-summary.md`

| Planning Session Point | Reflected in Batch 2 Prompts? |
|---|---|
| Point 1 — retention numbers for 640 KB partition | ✅ v7.7.1.4 §1 mandatory reading explicitly lists `Docs/multi-phase-planning-session-summary.md` Point 1 |
| Point 3 — binary sensor dedup with EventLog | ✅ Rule 67 is in all critical rules checklists; v7.7.1.2 implements EventLog; §5 DO-NOT in v7.7.1.3 correctly defers EventLog persist |
| Point 6 — recommendation → issue routing | ✅ Consolidated audit instructions in all prompts include "route to GitHub issue or CURRENT-STATE.md — no third option" |

---

## 7. Documents That Contributed to Batch 1 Failures

| Document | Contribution to Batch 1 Failures | Fix Status |
|---|---|---|
| `prompts/handoff/phase7-batch-production-prompt.md` (original) | §9 title "Post-Merge Deliverables" trained prompt producer to treat docs as post-merge; no Board Info Gate; no HARD/SOFT scope | ✅ Replaced by `phase7-batch-production-prompt-update.md` |
| `Docs/development-process-guide.md` | Did not contribute as a document; the problem was that the prompt producer was told to read only §2–3, not the full document | ✅ Batch 2 production prompt now says "READ THE FULL DOCUMENT" |
| `Docs/writing-guide/methodology.md` | Did not contribute — was not the source of failures | N/A |
| `prompts/handoff/phase7-prompt-production-instructions.md` | Not reviewed in this audit — if this file still exists and is referenced, it may carry Batch 1 assumptions | ⚠️ Operator should confirm this file is superseded or removed |

---

## 8. Preventing Recurrence

| Recommendation | Priority | Target |
|---|---|---|
| Add ⛔ prominent warning block above unfilled template placeholders in batch-production-prompt-update.md | HIGH | Before Batch 3 production |
| Add `§4.1 Assumption Audit Gate` as explicit callout in mandatory reading item 4 of batch-production-prompt-update.md | HIGH | Before Batch 3 production |
| Add DO-NOT note for budget calculator caching in v7.7.1.4 §5 and inline code comment | MEDIUM | Before v7.7.1.4 execution |
| Confirm `find_partition_size_bytes_()` exists in nvs-persistence.h on main before v7.7.1.4 starts | MEDIUM | Before v7.7.1.4 execution |
| Add `bash scripts/provision.sh satellite` check to reviewer checklist in v7.7.1.3-claude-two-step.md | LOW | Before v7.7.1.3 execution |
| Confirm `prompts/handoff/phase7-prompt-production-instructions.md` is superseded/removed | LOW | Cleanup |
| Expand v7.7.1.3 handoff to match v7.7.1.2 detail level (add critical rules table, key design decisions) | LOW | Nice-to-have |

---

## 9. Overall Verdict

| Dimension | Grade | Notes |
|---|---|---|
| Operator concerns addressed | ✅ PASS | All concerns from operator-notes.txt resolved |
| Updated batch production prompt | ✅ PASS with 2 gaps | §4.1 callout missing; placeholder warning needed |
| Compliance: development-process-guide.md | ✅ PASS | All sections followed |
| Compliance: writing-guide/methodology.md | ✅ PASS | All anatomy requirements met |
| Session analysis accuracy | ✅ PASS | All 6 root causes correctly identified |
| §5 troubleshooting scenarios mitigated | ✅ PASS | All 4 scenarios covered |
| Prompt quality vs Batch 1 | ✅ IMPROVED | Significant structural improvements; 4 findings (2 MEDIUM, 2 LOW) |
| Planning session summary alignment | ✅ PASS | Points 1, 3, 6 explicitly referenced |

**The Batch 2 prompt bundle is ready for execution.** The two MEDIUM items in §8 should be addressed before v7.7.1.4 starts. The two HIGH items should be addressed before Batch 3 production. None of the findings are blocking for Batch 2 execution.

---

_End of Perplexity Audit Report — Phase 7 Batch 2 Prompts_
