# Phase 7 Batch-2 Prompts — Independent Audit Report

**Auditor:** Claude Opus 4.7 (GitHub Copilot, Agent mode) | **Date:** 2026-05-09
**Branch:** `copilot/create-audit-report-phase7-prompts` | **Scope:** 10 documents produced by the prompt-producer session after operator feedback.
**Method:** Read all listed source/guideline docs, mechanically grep-verified every cited line. Every claim below is `path:line` cited. No invention.

> **Note:** Two prior audit reports already exist on this branch (`new-prompts-audit-report-Copilot.md`, `phase7-batch2-prompt-audit-report-GPT.md`). This report was produced independently and used **mechanical re-verification** of citations, which surfaces several corrections to claims found elsewhere (see §10).

---

## 1. Operator concerns — coverage matrix

Source: [operator-notes.txt](prompts/handoff/phase7/operator-notes.txt) — concerns enumerated below by line.

| # | Operator concern | Line | New-batch fix | Status |
|---|---|---|---|---|
| 1 | Pre-merge vs post-merge confusion (consolidated audit / session log / CURRENT-STATE were tagged post-merge) | [L91-105](prompts/handoff/phase7/operator-notes.txt#L91) | E-1 lesson banner at top of every agent prompt; §9 retitled "Post-Merge Bookkeeping (tag and close only)"; docs moved to §6 | ✅ FULLY |
| 2 | Device testing punted to operator instead of agent | [L107](prompts/handoff/phase7/operator-notes.txt#L107) | v7.7.1.3 §6 Task Group 3 [L372-406](prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md#L372); v7.7.1.4 §6 Task Group 5 [L461-482](prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md#L461); v7.7.1.2 correctly omits (no runtime change) | ⚠️ PARTIALLY — see #3 |
| 3 | "flash WROOM AND C3, verify no crash on history serve" | [L49](prompts/handoff/phase7/operator-notes.txt#L49) | v7.7.1.3 and v7.7.1.4 device-testing blocks reference **only** `192.168.120.189` (C3). No WROOM upload/curl. Verified by `grep -i wroom` returning zero matches in either file. | ❌ NOT addressed |
| 4 | Stale board IPs/YAMLs (WROOM .190 wrong; YAML filename wrong) | [L109-113](prompts/handoff/phase7/operator-notes.txt#L109) | "Board Info Extraction Gate" added [phase7-batch-production-prompt-update.md:184-208](prompts/handoff/phase7-batch-production-prompt-update.md#L184); handoff v7.7.1.2 lists correct `.170` and `esp32-wroom-32d-gw.yaml` [L46-53](prompts/handoff/phase7/session-handoff-v7.7.1.2.md#L46) | ✅ FULLY (data accuracy), but see #3 (no WROOM cmd uses it) |
| 5 | Scope guard tripped by `bump-version.sh` pipeline side effects | [L115](prompts/handoff/phase7/operator-notes.txt#L115) | Explicit whitelist [v7.7.1.2:71-96](prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md#L71); HARD vs SOFT separation introduced | ✅ FULLY |
| 6 | Gates "too broad" — agent stopped on benign work | [L115](prompts/handoff/phase7/operator-notes.txt#L115) | Pre-gate uses `grep -c` count assertions, not pattern bans; whitelist for canonical pipeline | ✅ FULLY |
| 7 | "Why did CI trigger on a doc-only PR?" | (implicit context) | Answered in [new-session-analysis-conclusion.txt:13](prompts/handoff/phase7/new-session-analysis-conclusion.txt#L13): PR also contained `bump-version.sh` source/dashboard edits matching the CI path filter | ✅ FULLY (explanation only; no preventive change) |
| 8 | Interpret session logs/PRs to find what triggered stops, prevent recurrence | [L137](prompts/handoff/phase7/operator-notes.txt#L137) | E-1…E-5 errata table [phase7-batch-production-prompt-update.md:111-134](prompts/handoff/phase7-batch-production-prompt-update.md#L111) | ✅ FULLY |

**Net:** 6/8 fully, 1/8 partially, **1/8 not addressed (concern #3 — missing WROOM device testing)**.

---

## 2. Is `phase7-batch-production-prompt-update.md` sufficient?

| Improvement | Where | Verdict |
|---|---|---|
| E-1…E-5 errata block with root-cause + fix per defect | [L111-134](prompts/handoff/phase7-batch-production-prompt-update.md#L111) | Strong |
| "Board Info Extraction Gate" forcing IP/YAML extraction from `CURRENT-STATE.md` | [L184-208](prompts/handoff/phase7-batch-production-prompt-update.md#L184) | Strong |
| Mandatory reading order made explicit; "READ THE FULL DOCUMENT" emphasis on dev-process-guide | [L156-170](prompts/handoff/phase7-batch-production-prompt-update.md#L156) | Adequate |
| Scope-guard whitelist for `bump-version.sh` pipeline | [L307-322](prompts/handoff/phase7-batch-production-prompt-update.md#L307) | Strong |
| HARD vs SOFT scope-boundary separation | [L367-379](prompts/handoff/phase7-batch-production-prompt-update.md#L367) | Strong |

**Remaining gaps:**

| Gap | Severity | Why it matters |
|---|---|---|
| No mandate that agent prompts include **all boards listed in CURRENT-STATE fleet** in device-testing tasks. The Extraction Gate gathers data but does not require it to be **used** for every applicable board. | HIGH | Direct cause of operator concern #3 still being open. |
| §4.1 of `development-process-guide.md` ("Assumption Audit Gate") is referenced as reading [L156-170] but not enforced as a pre-batch deliverable (no required output template). | MEDIUM | Same root cause that produced the v7.7.1.1 failure: a section was "read" but not internalized. |
| The original problem description in operator-notes ("§2.5 was buried, prompt producer skimmed") is acknowledged in self-analysis but no structural change is proposed to make §2.5 unmissable — only a "READ THE FULL DOCUMENT" admonition. | MEDIUM | Admonitions repeatedly fail in this codebase per operator-notes [L107-115]. |

---

## 3. Compliance with `Docs/development-process-guide.md`

| Section | Requirement | Compliance | Evidence |
|---|---|---|---|
| §2.3 Agent device testing | Agent runs compile/upload/curl; operator only does what agent can't | Partial | v7.7.1.3 [L372-406] and v7.7.1.4 [L461-482] include compile/upload/curl — for **C3 only**. WROOM omitted. |
| §2.5 In-PR mandatory deliverables (CURRENT-STATE, changelog, audit, session log, handoff updates) | All committed before "ready for review" | Full | Agent prompts §6 list all 6 in-PR; §9 retitled "Post-Merge Bookkeeping (tag and close only)" e.g. [v7.7.1.2:557](prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md#L557) |
| §3 Checkpoint discipline (queries not assertions; stop-don't-fix) | `grep -c` counts; "STOP and post the actual output" | Full | e.g. [v7.7.1.2:88-110](prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md#L88) |
| §4.1 Assumption Audit Gate (planning-time) | Run before producing batches | **Not enforced** | No section in `phase7-batch-production-prompt-update.md` requires producing audit answers as an artifact. |

---

## 4. Compliance with `Docs/writing-guide/methodology.md`

| Section | Requirement | Compliance | Evidence |
|---|---|---|---|
| §3.2 Required Reading — Specific Callouts | Name structs/functions, not just files | Full | e.g. [v7.7.1.2:27-42] names `DeviceHistoryMeta`, `DeviceSegment`, `EventLog`, `persist_hourly_segment_()` |
| §3.4 Pre-condition checks | Concrete commands | Full | 8 checks v7.7.1.2; 9 checks v7.7.1.3 / v7.7.1.4 |
| §3.6 DO-NOT list | Explicit scope boundaries | Full | Present in all three agent prompts (e.g. [v7.7.1.2:135-144]) |
| §3.7 Critical Rules | Step-specific subset of repo rules | Full | §4 Critical Rules Checklist in each |
| §3.10 "Device Testing (**for Human**)" | (Doc still labels this as human-only) | **CONFLICT** | The methodology section title contradicts the new fix in dev-process-guide §2.3. See §8 below for upstream-doc fix. [methodology.md:139](Docs/writing-guide/methodology.md#L139) |
| §3.11 Test Group Guardrails | Required when prompt adds test groups | N/A | None of v7.7.1.2/3/4 add new test groups. |

---

## 5. Accuracy of `new-session-analysis-conclusion.txt`

| Issue analyzed | Accuracy | Note |
|---|---|---|
| #1 §9 title inherited pre-Phase-VY language | ✅ Accurate | Confirmed against renamed §9 in all three new prompts. |
| #2 Device testing punted | ✅ Accurate | Matches operator-notes [L107]. |
| #3 Stale IPs/YAMLs (memorized) | ✅ Accurate | Matches operator-notes [L109-113]. |
| #4 `bump-version.sh` scope explosion | ✅ Accurate | Matches operator-notes [L115]. |
| #5 `--check` before `--write` ordering | ✅ Accurate | E-5 banner now mandates order. |
| #6 CI trigger explanation | ✅ Plausible | Repo CI filter targets `firmware/**`, `dashboard/**`, `scripts/**`; PR contained those. |

**Blind spot:** the analysis identifies five issues but does **not** acknowledge that operator concern #3 (test BOTH boards) requires more than the Board Info Extraction Gate. It treats the gate as sufficient. It is not — see §1.

---

## 6. Section 5 of `Docs/multi-phase-session-run-instructions.md`

⚠️ **Important correction.** Section 5 is titled **"Troubleshooting"** ([L242](Docs/multi-phase-session-run-instructions.md#L242)), not "Knowledge Architecture". Some prior analyses (including a deep-research subagent run for this audit) misquoted it. The actual §5 lists 5 failure symptoms; here is the new batch checked against each:

| §5 Symptom | Pattern | New batch behaviour | Verdict |
|---|---|---|---|
| Advisor produces stale analysis (refs pre-Phase-V structures, missing `authFetch`, etc.) | "fix: ask advisor to re-clone and re-grep" | New prompts mandate fresh `git clone`, then `grep -c` pre-gate against current repo | ✅ Avoided |
| Advisor hits output limit mid-deliverable | Resume instructions | Each prompt is self-contained, single-deliverable per agent invocation | ✅ Avoided |
| Context window saturation | Layer-budget guidance | New prompts read `CURRENT-STATE.md` + handoff + 1 architecture doc — well within budget | ✅ Avoided |
| Measurement data wrong | "re-read board-measurement-log" | New handoff [v7.7.1.2:7-20] cites measurements from `CURRENT-STATE.md` directly | ✅ Avoided |
| Recommendation contradicts decision log | Quote rule, ask revision | E-1…E-5 errata explicitly enumerate prior failures | ✅ Avoided |

No §5 troubleshooting symptom is reproduced by the new batch.

---

## 7. Quality vs prior batch (v7.7.1.0 / v7.7.1.1)

Mechanical line-counts and feature presence (verified):

| Metric | v7.7.1.0 | v7.7.1.1 | v7.7.1.2 | v7.7.1.3 | v7.7.1.4 | Trend |
|---|---|---|---|---|---|---|
| Agent-prompt LOC | (not measured) | (not measured) | 581 | 530 | 618 | Comparable / slightly larger |
| Claude two-step LOC | — | — | 78 | 73 | 67 | Two-step preserved |
| Pre-gate `grep`/`ls`/`cat` checks | (≈6 from prior reports) | (≈11) | 8 | 9 | 9 | Consistent / improved |
| §9 mislabeling ("Post-Merge Deliverables") | present | present | **fixed** | **fixed** | **fixed** | Regression eliminated |
| E-N lessons banner at top of agent prompt | absent | absent | present | present | present | New, positive |
| Device-testing block included where applicable | (absent / operator) | (absent / operator) | N/A — additive only | C3 only | C3 only | Improvement, but incomplete (see §1#3) |
| Multi-board device testing | N/A | N/A | N/A | **No** | **No** | **Regression vs operator instruction** |

**No content/density regression detected.** Structural quality is **higher** than v7.7.1.1. The single quality regression is the missing WROOM device-testing on prompts that touch boot-path code (v7.7.1.4 restore) and chunked-CSV (v7.7.1.3).

---

## 8. Required fixes

### 8a. Fixes to the 10 produced documents

| File | Where | Fix | Severity |
|---|---|---|---|
| [v7.7.1.3-agent-prompt-gpt-codex.md](prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md#L372) | §6 Task Group 3 (L372-406) | Add a parallel block: `timeout 300 esphome upload firmware/esp32-wroom-32d-gw.yaml --device=192.168.120.170` plus matching curl smoke tests. Use exact YAML filename — verify via `ls firmware/*.yaml` first. | **HIGH** |
| [v7.7.1.4-agent-prompt-gpt-codex.md](prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md#L461) | §6 Task Group 5 (L461-482) | Same — add WROOM block. Restore is boot-path code; cross-board validation is mandated by operator-notes L49. | **HIGH** |
| [phase7-batch-production-prompt-update.md](prompts/handoff/phase7-batch-production-prompt-update.md#L184) | After Board Info Extraction Gate | Add a "Board Coverage Rule": *for every step that exercises a runtime path (compile/persist/restore/serve), the agent prompt MUST include device-testing commands for **every** board listed in the extracted fleet, unless explicitly justified otherwise in the prompt body.* | **HIGH** |
| [phase7-batch-production-prompt-update.md](prompts/handoff/phase7-batch-production-prompt-update.md#L156) | Mandatory Reading | Replace "§2-3 (execution workflow, prompt structure)" with "§2.5 (in-PR mandatory deliverables — CRITICAL section that caused the failure) and §4.1 (Assumption Audit Gate)". | MEDIUM |
| [phase7-batch-production-prompt-update.md](prompts/handoff/phase7-batch-production-prompt-update.md#L111) | After Errata table | Add a "Pre-Batch Audit Output" section requiring the prompt producer to write 4 lines of audit answers (per dev-process-guide §4.1) as a visible artifact before the prompt set is accepted. | MEDIUM |
| [new-session-analysis-conclusion.txt](prompts/handoff/phase7/new-session-analysis-conclusion.txt#L1) | append | Add Issue #7: "Multi-board testing not yet enforced; Board Info Extraction Gate gathers data but does not require its use across the fleet." | LOW |

### 8b. Fixes to upstream guideline docs (these contributed to the failure)

| File | Where | Why it contributed | Fix |
|---|---|---|---|
| [Docs/writing-guide/methodology.md](Docs/writing-guide/methodology.md#L139) | §3.10 title: *"Device Testing (for Human)"* | Directly contradicts dev-process-guide §2.3 (agent-performed). A prompt producer reading methodology.md alone will keep punting device testing to the operator. | Rename §3.10 to "Device Testing — Agent-Performed by Default; Operator Items Listed Separately" and rewrite body to match dev-process-guide §2.3. **Severity: HIGH.** |
| [Docs/development-process-guide.md](Docs/development-process-guide.md) | §2.5 location/visibility | Buried inside §2 with no visual marker; prompt producer skimmed. | Add `⚠️ MERGE GATE` callout marker at §2.5; add an explicit Table-of-Contents flag. **Severity: MEDIUM.** |
| [Docs/development-process-guide.md](Docs/development-process-guide.md) | §4.1 Assumption Audit Gate | Listed as a planning gate but never required to produce a written artifact, so it is invisible after the fact. | Add an output template (4 short answers) the prompt producer must include in every batch. **Severity: MEDIUM.** |
| [prompts/handoff/phase7-batch-production-prompt.md](prompts/handoff/phase7-batch-production-prompt.md) | Mandatory Reading list | Pointed to "§2-3" of dev-process-guide; encouraged skimming. | Already being superseded by `*-update.md`; deprecate explicitly with a top-of-file pointer. **Severity: LOW.** |

---

## 9. Process recommendations — preventing recurrence

The development-process-guide was authored to prevent exactly this failure mode, yet was bypassed. Root causes and proposed structural changes:

| # | Root cause | Structural fix |
|---|---|---|
| 1 | §2.5 is discoverable only via a TOC line in a 287-line doc | Visual `⚠️ MERGE GATE` marker + dedicated TOC callout |
| 2 | §4.1 is a *gate* but produces no *artifact* | Mandatory written audit answers (4 short Q/A) attached to every batch |
| 3 | §3.10 of methodology.md still says "for Human" — directly contradicting §2.3 of dev-process-guide | Rename and rewrite (see §8b) — single source of truth |
| 4 | Prompt-producer never demonstrated comprehension of §2.5 before producing prompts | Add a self-check recital ("name the 6 in-PR deliverables") to `phase7-batch-production-prompt-update.md`; refusal to recite = stop |
| 5 | "Read CURRENT-STATE.md" was guidance; "extract specific values into a YAML and use them in every device command" is now the rule — but the *use* leg is not enforced | Add the Board Coverage Rule (see §8a) |
| 6 | No mechanism to detect that a "fix" was applied without addressing all sub-cases (e.g., concern #3 — test both boards) | Operator review checklist: cross-walk operator-notes line-by-line against the new prompts before sign-off |

---

## 10. Citation hygiene note (this audit vs prior runs)

During this audit, mechanical re-verification surfaced two factual errors that occurred in earlier deep-research output and should not propagate:

1. **§5 of `multi-phase-session-run-instructions.md` is "Troubleshooting"** — not "Knowledge Architecture / Document Layers". Verified: [L242](Docs/multi-phase-session-run-instructions.md#L242).
2. **`v7.7.1.4-agent-prompt-gpt-codex.md` DOES include device testing** ([L461-482](prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md#L461)) — earlier framing of this as a HIGH "missing entirely" gap was incorrect. The real gap is narrower: testing is C3-only, not WROOM. Confirmed by `grep -i wroom prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` returning zero matches.

Future audits should mechanically re-verify each citation against the file before publication.

---

## 11. Top-10 fixes by impact

| Rank | Fix | File | Severity |
|---|---|---|---|
| 1 | Add WROOM device-testing block to v7.7.1.3 §6 Task Group 3 | [v7.7.1.3-agent-prompt-gpt-codex.md:372](prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md#L372) | HIGH |
| 2 | Add WROOM device-testing block to v7.7.1.4 §6 Task Group 5 (boot-path code) | [v7.7.1.4-agent-prompt-gpt-codex.md:461](prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md#L461) | HIGH |
| 3 | Rename methodology §3.10 and rewrite body to match dev-process-guide §2.3 | [Docs/writing-guide/methodology.md:139](Docs/writing-guide/methodology.md#L139) | HIGH |
| 4 | Add "Board Coverage Rule" to batch-production-prompt-update | [phase7-batch-production-prompt-update.md:184](prompts/handoff/phase7-batch-production-prompt-update.md#L184) | HIGH |
| 5 | Make §2.5 of dev-process-guide visually unmissable (`⚠️ MERGE GATE` marker + TOC flag) | Docs/development-process-guide.md | MEDIUM |
| 6 | Mandate Pre-Batch Audit written artifact (§4.1) | [phase7-batch-production-prompt-update.md:111](prompts/handoff/phase7-batch-production-prompt-update.md#L111) | MEDIUM |
| 7 | Replace vague "§2-3" reading reference with explicit §2.5 + §4.1 callouts | [phase7-batch-production-prompt-update.md:156](prompts/handoff/phase7-batch-production-prompt-update.md#L156) | MEDIUM |
| 8 | Operator review checklist: line-by-line cross-walk of operator-notes vs new prompts before sign-off | new doc | MEDIUM |
| 9 | Append missing-board-coverage issue to new-session-analysis-conclusion.txt | [new-session-analysis-conclusion.txt](prompts/handoff/phase7/new-session-analysis-conclusion.txt) | LOW |
| 10 | Deprecation pointer at top of original `phase7-batch-production-prompt.md` to its `-update.md` successor | [phase7-batch-production-prompt.md](prompts/handoff/phase7-batch-production-prompt.md) | LOW |

---

## Executive summary

- **Operator concerns:** 6/8 fully fixed, 1/8 partial, **1/8 unaddressed** (multi-board testing — concern #3).
- **`phase7-batch-production-prompt-update.md`:** materially improved; 3 structural gaps remain (board-coverage rule, §4.1 artifact, §2.5 visibility).
- **Compliance:** dev-process-guide §2.5 ✅, §3 ✅, §2.3 ⚠️ partial; methodology §3.x ✅ except §3.10 (upstream conflict); planning-summary decisions ✅; multi-phase-instructions §5 ✅.
- **Self-analysis (`new-session-analysis-conclusion.txt`)** is accurate on the 5 issues it identifies; misses concern #3.
- **Quality vs prior batch:** higher density, eliminates §9 mislabel, adds E-N banners. **One regression:** missing WROOM testing in v7.7.1.3/v7.7.1.4.
- **Upstream documents requiring fixes:** `methodology.md` §3.10 (HIGH — direct contradiction with dev-process-guide §2.3), `dev-process-guide.md` §2.5 visibility (MEDIUM), `dev-process-guide.md` §4.1 artifact requirement (MEDIUM).
- **Top action:** add WROOM device-testing blocks to v7.7.1.3 and v7.7.1.4 BEFORE either prompt is dispatched to an agent; add a Board Coverage Rule to the batch-production-prompt so this class of error cannot recur.

_End of report._
