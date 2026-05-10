# Phase 7 Batch 2 — Quality Review & External Audit Incorporation

_Session type: Claude Opus advisory — no code changes, no PRs_
_Date: 2026-05-09_
_Prerequisite: Batch 2 prompts committed to repo (v7.7.1.2, v7.7.1.3, v7.7.1.4)_

---

## Purpose

This session has two goals:

1. **Independent quality review** of the Phase 7 Batch 2 prompt bundle (3 agent prompts, 3 two-step prompts, 3 session handoffs, 1 batch production prompt) against the project's prompt-writing methodology and development process guide.

2. **Incorporate external audit findings** — review documents produced by external reviewers (Perplexity, GPT, Codex, Kiro, or other LLMs) that audited these prompts or the underlying methodology since the prompts were created. Assess findings, classify by severity, and produce an actionable fix list.

---

## Operator: Provide These Inputs

Before the session begins, paste or upload the following. The session cannot proceed without items marked **REQUIRED**.

### REQUIRED

1. **External audit document(s)** — paste or upload the full text of any reviews, audits, or analyses of the Batch 2 prompts or methodology conducted by external LLMs since 2026-05-08. If multiple documents, number them (Audit-1, Audit-2, etc.).

2. **Current repo state** — confirm:
   - Are the Batch 2 prompt files committed to `main`? (If not, which branch?)
   - Current `VERSION` value
   - Any steps from v7.7.1.2–v7.7.1.4 already executed? If yes, which, and were there any checkpoint failures or agent deviations?

3. **Scope of review** — select one:
   - **A) Full review** — all 10 files, all external audits, produce full fix list
   - **B) Targeted review** — specify which files or which audit findings to focus on
   - **C) Delta review** — only review changes made since the production session's internal audit (which fixed defects D1–D7; see §Background below)

### OPTIONAL

4. **New lessons or critical rules** added since v7.7.1.1 that the prompts should reference
5. **Changes to the codebase** since v7.7.1.1 (new PRs, hotfixes, struct changes) that might invalidate prompt assumptions
6. **Changes to methodology documents** (`Docs/writing-guide/methodology.md`, `Docs/development-process-guide.md`) since 2026-05-08

---

## Background: What Was Produced and Already Audited

### The Batch 2 Bundle (10 files)

| File | Lines | Purpose |
|------|-------|---------|
| `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md` | 581 | Per-device structs, key scheme, FNV-1a hash (LOW risk) |
| `prompts/phase7/v7.7.1.2-claude-two-step.md` | 78 | Agent setup + reviewer checklist |
| `prompts/handoff/phase7/session-handoff-v7.7.1.2.md` | ~175 | Full context handoff |
| `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` | 530 | Per-device persist engine write path (MEDIUM risk) |
| `prompts/phase7/v7.7.1.3-claude-two-step.md` | 73 | Agent setup + reviewer checklist |
| `prompts/handoff/phase7/session-handoff-v7.7.1.3.md` | ~100 | Full context handoff |
| `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | ~590 | Per-device restore engine + retention budget (HIGH risk) |
| `prompts/phase7/v7.7.1.4-claude-two-step.md` | ~70 | Agent setup + reviewer checklist |
| `prompts/handoff/phase7/session-handoff-v7.7.1.4.md` | 208 | Full context handoff |
| `prompts/handoff/phase7-batch-production-prompt.md` | ~600 | Batch production template v2.0 with errata |

### Defects Already Found and Fixed (D1–D7)

The production session performed an internal audit and fixed these before delivery:

| # | Sev | File | Issue | Fix Applied |
|---|-----|------|-------|-------------|
| D1 | MED | v7.7.1.3 CHECKPOINT B | "fix syntax errors and retry" — violated stop-don't-fix semantics | Replaced with standard STOP directive |
| D2 | MED | v7.7.1.4 CHECKPOINT A | Missing stop directive | Added STOP + post template |
| D3 | MED | v7.7.1.4 CHECKPOINT B | Missing stop directive | Added STOP + post template |
| D4 | LOW | v7.7.1.4 Task Group 6 | Session log lacked content spec | Expanded to match v7.7.1.2 detail |
| D5 | MED | v7.7.1.4 §8 Pre-PR Gate | Missing expected file list, negative scope checks, full test suite | Expanded to match v7.7.1.2 |
| D6 | LOW | v7.7.1.4 two-step | Review checklist missing normal=20% tier | Added all three tiers |
| D7 | — | session-handoff-v7.7.1.4 | Didn't exist | Created (208 lines) |

### What Passed the Internal Audit

- 10-section structure (§1–§10) present in all three agent prompts
- E-1 through E-5 compliance verified (Batch 1 errata fixes applied)
- Board IPs match CURRENT-STATE.md (.189/.170/.191)
- Code references verified against live codebase: `category_id`, `HISTORY_PARTITION_LABEL`, `find_partition_size_bytes_()`, `maybe_yield_nvs_scan_()` all exist
- Struct sizes match architecture doc §5 (DeviceHistoryMeta=36B, DeviceSegment=226B)
- Budget percentages match architecture doc §7.2 (70/20/10)
- FNV-1a constants correct (0x811c9dc5, 0x01000193)
- Version chain correct (7.7.1.1→7.7.1.2→7.7.1.3)

### Batch 1 Errata (root causes that informed Batch 2)

| ID | Root Cause | Fix in Batch 2 |
|----|-----------|-----------------|
| E-1 | §9 titled "Post-Merge Deliverables" but listed in-PR docs | §9 renamed "Post-Merge Bookkeeping (tag and close only)"; all docs moved to §6 |
| E-2 | Device testing punted to operator when agent can do compile/upload/curl | Agent does all device testing; operator only does visual dashboard checks |
| E-3 | Stale board IPs (memorized, not verified) | Board Info Extraction Gate in batch production prompt |
| E-4 | bump-version.sh artifacts not in scope whitelist → false checkpoint failures | Explicit whitelist of all bump-version.sh artifacts in §3 |
| E-5 | Assembly --check before --write → stale artifact failures | Always --write then --check |

---

## Session Instructions

### Step 0 — Clone and verify

```bash
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
cat VERSION
# Confirm with operator's stated version
```

### Step 1 — Read reference standards (mandatory, in this order)

1. `Docs/development-process-guide.md` — especially §2.5 (step deliverables), §3.1–3.3 (prompt bundle structure, checkpoint rules, scope guards)
2. `Docs/writing-guide/methodology.md` — especially §3 (prompt anatomy), §4.1 (10-section structure), §4.4 (checkpoint pattern), §4.5 (multi-LLM strategy)
3. `Docs/writing-guide/review-prompt-quality-rule.md` — quality criteria for review/two-step prompts
4. `Docs/writing-guide/gap-catalog.md` — known gap categories to check for
5. `prompts/handoff/methodology-audit-findings-for-planning.md` — process requirements for all future prompts
6. `Docs/v7.7-v7.8-persistence-architecture.md` — §5 (structs), §6 (NVS keys), §7 (retention budgets), §9 (boot restore) — the source designs the prompts implement

### Step 2 — Read the Batch 2 prompts (all 10 files)

Read each file completely. For each agent prompt, verify:

#### 2a. Structural compliance (methodology §4.1)

- [ ] All 10 sections present (§1–§10) with correct content in each
- [ ] Universal execution preamble with 5 rules
- [ ] Process lessons section citing relevant errata
- [ ] ⛔ CHECKPOINT between every task group with stop-don't-fix directive
- [ ] §9 contains ONLY tag + close (E-1)

#### 2b. Checkpoint quality (methodology §4.4)

- [ ] Every checkpoint uses `grep -c` queries, not line-number assertions
- [ ] Every checkpoint has explicit "If ANY check fails, STOP" directive
- [ ] Expected values are mechanically derivable from the code blocks (Rule 64)
- [ ] Assembly always `--write` before `--check` (E-5)

#### 2c. Scope boundary quality (dev guide §3.3)

- [ ] Named files and functions, not descriptions
- [ ] bump-version.sh artifacts explicitly whitelisted (E-4)
- [ ] Negative scope checks in §8 Pre-PR Gate (git diff verification)
- [ ] HARD vs SOFT scope distinction where applicable

#### 2d. Code block quality (methodology §3.13)

- [ ] All code references use real identifiers from the codebase (verify with `grep`)
- [ ] Constants defined before use
- [ ] No dangling references to functions/structs that don't exist yet at that step
- [ ] Code blocks match architecture doc specs (struct sizes, field names, algorithm)

#### 2e. Device testing (E-2)

- [ ] Steps with firmware changes include agent-performed device testing (compile/upload/curl)
- [ ] Device test commands use correct IPs from CURRENT-STATE.md
- [ ] Upload wrapped in `timeout 300`
- [ ] `esphome clean` before compile, `provision.sh satellite` before push

#### 2f. In-PR deliverables (dev guide §2.5)

- [ ] CURRENT-STATE.md, changelog, session log, consolidated audit — all in §6
- [ ] Session log content spec includes: ESPHome output, Playwright table, evidence summary
- [ ] Consolidated audit references template file

#### 2g. Two-step quality (review-prompt-quality-rule.md)

- [ ] Review checklist has 10+ concrete verification items per step
- [ ] Step-specific focus areas (not generic "check code quality")
- [ ] Cross-references to acceptance criteria in §7
- [ ] External reviewer workflow with risk-appropriate reviewer count

#### 2h. Handoff quality

- [ ] Project state summary with prior step validation snapshot
- [ ] Open issues table current
- [ ] Phase progress table with correct statuses
- [ ] Board fleet table with IPs from CURRENT-STATE.md
- [ ] "What this step does / does NOT do" sections
- [ ] Critical rules table relevant to this step
- [ ] Risk assessment with primary/secondary/tertiary risks
- [ ] "Context that carries forward" section

#### 2i. Cross-prompt consistency

- [ ] Version chain: v7.7.1.2 expects 7.7.1.1, v7.7.1.3 expects 7.7.1.2, v7.7.1.4 expects 7.7.1.3
- [ ] Fragment count consistently 9 across all three
- [ ] Pre-impl gate checks are additive (each step checks for functions added by prior steps)
- [ ] Scope boundaries don't overlap (each step modifies only its declared files)
- [ ] Risk escalation matches content (LOW → MEDIUM → HIGH)

### Step 3 — Read and assess external audit documents

For each external audit document provided by the operator:

1. **Classify each finding** by severity: Critical / High / Medium / Low / Informational
2. **Assess validity** — is the finding correct? Verify against the codebase and standards.
3. **Check for duplicates** — was this already caught by the D1–D7 internal audit?
4. **Determine scope** — does the finding affect one prompt or all three?
5. **Propose fix** — for each valid finding, describe the specific edit needed

### Step 4 — Produce deliverables

---

## Deliverables

### Deliverable 1: Quality Scorecard

For each of the 10 files, produce a pass/fail table against the checklist items from Step 2. Format:

```
### v7.7.1.2-agent-prompt-gpt-codex.md

| Check | Result | Notes |
|-------|--------|-------|
| 10-section structure | ✅ | |
| Checkpoint stop directives | ✅ | |
| Code block correctness | ⚠️ | [specific issue] |
...
```

### Deliverable 2: External Audit Findings Assessment

For each external audit document, produce:

```
### Audit-1: [title/source]

| # | Finding | Severity | Valid? | Already Fixed? | Scope | Proposed Fix |
|---|---------|----------|--------|----------------|-------|-------------|
| 1 | [summary] | [H/M/L] | [Y/N/Partial] | [D1-D7 ref or N] | [which files] | [edit description] |
```

### Deliverable 3: Consolidated Fix List

Merge all valid, unfixed findings from the quality scorecard AND external audits into a single prioritized fix list:

```
### Priority 1 — Must fix before execution

| # | File | Finding | Fix |
|---|------|---------|-----|
...

### Priority 2 — Should fix, low risk if deferred

| # | File | Finding | Fix |
...

### Priority 3 — Informational, no action needed

| # | File | Finding | Notes |
...
```

### Deliverable 4: Methodology Gap Assessment

Based on this review, answer:

1. **Are there new gap categories** that should be added to `Docs/writing-guide/gap-catalog.md`?
2. **Are there new critical rules** that should be added to `prompts/prompt-index-and-workflow.md`?
3. **Are there batch production prompt improvements** that should be added to `prompts/handoff/phase7-batch-production-prompt.md`?
4. **Does the methodology document itself need updates** based on what the external audits revealed?

For each "yes", provide the specific addition with proposed text.

### Deliverable 5: Updated Files (if Priority 1 fixes exist)

If any Priority 1 fixes are identified, produce the corrected files as structured edit documents (find/replace blocks) that can be applied to the repo. Do NOT produce full file rewrites for minor fixes.

---

## What NOT To Do

- Do NOT execute any prompts or create PRs — this is a review session
- Do NOT modify the codebase
- Do NOT produce "LLM-optimized" prompt variants (Critical Rule: original prompts only)
- Do NOT downgrade safety constraints even if they seem redundant
- Do NOT assume external audit findings are correct — verify each one against the codebase
- Do NOT skip reading the methodology documents — they define the standards you're reviewing against

---

## Session Output Format

Structure your response as:
1. Codebase verification summary (VERSION, fragment count, key function existence)
2. Deliverable 1 (quality scorecard)
3. Deliverable 2 (external audit assessment)
4. Deliverable 3 (consolidated fix list)
5. Deliverable 4 (methodology gaps)
6. Deliverable 5 (fix files, if needed)

---

_End of session prompt._
