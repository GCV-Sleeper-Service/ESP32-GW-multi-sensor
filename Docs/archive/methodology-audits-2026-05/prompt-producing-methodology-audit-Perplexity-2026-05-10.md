# Prompt-Producing Methodology Audit — Perplexity — 2026-05-10

_Auditor: Perplexity (Sonnet 4.6)_  
_Date: 2026-05-10_  
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Status: Methodology audit and recommended process extension. This document does not replace `Docs/development-process-guide.md` or `Docs/writing-guide/methodology.md` until incorporated by a follow-up methodology PR. It is intended as a third independent perspective alongside `Docs/prompt-producing-methodology-audit-Codex-2026-05-10.md` and `Docs/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md`._

---

## 1. Executive Summary

Two prior methodology audits (Codex and GPT-5.5 Thinking, both 2026-05-10) correctly identify the core gap: prompt bundles are executable artifacts that require independent audit before dispatch. Both prescribe a three-audit gate, a severity model, a feedback loop, and changes to `development-process-guide.md`, `writing-guide/methodology.md`, and the production prompt template.

This audit does not repeat those recommendations. It addresses four areas neither prior audit covers in depth:

1. **Where in the pipeline information degrades** — a structural model of how facts become stale during planning→production, and which pipeline positions produce the highest defect density.
2. **What "independent" actually means** — the prior audits require "independent" audits without defining the independence criteria that make auditor diversity meaningful.
3. **The audit prompt as a first-class artifact** — the audit prompt skeleton itself is a prompt and will go stale; it needs a versioning and maintenance lifecycle.
4. **The upstream feedback loop** — both prior audits describe feeding findings back into producer templates and lint rules. Neither addresses feeding findings back into _planning documents_, where some errors originate.

A fifth area, **adversarial scenario classes that checklists structurally miss**, is covered in Section 6.

**Bottom line:** The three-auditor gate is necessary but not sufficient. The gate also needs defined independence criteria, an audit-prompt versioning discipline, and a planning-level feedback arc that prevents the same planning errors from seeding future producer sessions.

---

## 2. The Information-Attenuation Pipeline

### 2.1 Where facts degrade

Prompt defects do not originate only in the producer session. They originate at multiple points in the pipeline, each of which introduces a category of error:

```
Stage 1: Phase planning session
  ↓  [planning docs: phase-7-review-and-rewrite.md, multi-phase-planning-session-summary.md]
  ↓  ATTENUATION POINT A — planning intent vs. repo reality at planning time

Stage 2: Prompt-production prompt creation
  ↓  [batch-production-prompt-update.md]
  ↓  ATTENUATION POINT B — planning doc intent vs. what the production prompt captures

Stage 3: Producer session execution
  ↓  [producer creates handoff / agent / two-step prompts]
  ↓  ATTENUATION POINT C — production prompt intent vs. what the producer outputs
  ↓  ATTENUATION POINT D — current repo state vs. what the producer believes it to be

Stage 4: Dispatch to implementation agent
  ↓  [agent executes prompt]
  ↓  ATTENUATION POINT E — prompt intent vs. what the agent infers from ambiguity
```

The Phase 7 defect inventory maps to these points as follows:

| Defect class observed in Phase 7 | Attenuation point | Why current audit gate does not catch it |
|---|---|---|
| Doctrine drift (§9 post-merge deliverables) | B or C | Producer followed an implicit rule that was never written; lint rule was absent |
| Stale WROOM IP / YAML filename | D | Producer reconstructed facts from memory or planning docs rather than live repo state |
| Device-test delegation drift | B or C | Production prompt did not explicitly enumerate agent-capable vs. operator-only evidence |
| Pipeline sequencing errors (`--check` before `--write`) | C | Producer omitted sequencing from a procedure it otherwise stated correctly |
| Prompt-code coherence defects (wrong signatures, declaration order) | C | Producer produced code that was syntactically plausible but semantically wrong for the live codebase |
| False checkpoint expectations | C or D | Expected counts were derived from planning-time state, not dispatch-time state |

### 2.2 The staleness horizon

A "staleness horizon" is the maximum elapsed time between when a planning document captures a fact and when a downstream consumer (producer, auditor, or agent) acts on it. When the staleness horizon is exceeded, facts from planning docs should be treated as unverified claims requiring live-repo confirmation before use.

For this project, the following fact categories have short staleness horizons and must always be extracted from live repo state, not from any planning document regardless of how recent:

- Board IP addresses
- Generated YAML filenames (product of `scripts/provision.sh` and board profiles)
- Function signatures (product of ongoing implementation)
- `VERSION` value
- Fragment counts
- Open issue and unimplemented-recommendation lists

Planning documents are authoritative for: phase intent, acceptance criteria rationale, architectural decisions, and sequence intent. They are not authoritative for any runtime-derivable fact.

**Recommended methodology addition:** The production prompt template and the audit prompt skeleton should both include a mandatory "live-extract" block — a set of grep/find commands that the producer or auditor must run against the current repo state to populate fact slots before writing any prompt section that references those facts.

### 2.3 Planning-level errors

Both prior audits recommend feeding findings back into the production prompt template and into methodology docs. Neither recommends feeding findings back into planning documents.

However, some defects originate at Stage 1 or Stage 2. If a planning document captures incorrect intent — or if the production prompt template structurally omits a class of information from being conveyed from planning docs to producer — fixing the producer template alone does not prevent the error from re-entering through the next planning session.

The recommended feedback arc is:

```
Audit finding
  → Is it a producer error given correct input?          → fix producer template / methodology doc
  → Is it a production-prompt structural omission?       → fix production prompt template
  → Does the planning doc itself contain stale/wrong facts?  → annotate or correct planning doc
  → Does the planning doc omit a category needed by producer? → add that category to planning doc template
```

At a minimum, confirmed planning-level errors should be noted in `Docs/development-process-guide.md` as "planning document requirements" — categories of fact that every phase plan must capture before a production prompt can safely be run.

---

## 3. Auditor Independence: What It Actually Means

Both prior audits require "at least three independent audits." Neither defines what independence means in practice for AI-assisted auditing. This matters because it is possible to run three "independent" audits that are not meaningfully independent.

### 3.1 What makes audits non-independent

- **Same model family, same context window**: Two audits using GPT-4o with the same system prompt share the same inductive biases and will tend to miss the same classes of defect.
- **Sequential context contamination**: If Auditor B reads Auditor A's report before completing its own inspection, Auditor B's findings will be anchored to Auditor A's frame. This is the "peer review anchoring" problem: the second reviewer does not independently detect errors but validates or disputes the first reviewer's list.
- **Shared prompt ancestry**: If both auditors receive the same audit prompt skeleton without modification, they will apply the same checklist in the same order and share the same checklist blind spots.

### 3.2 Required independence criteria

For an audit to count as independent, it must meet all of the following:

| Criterion | Requirement |
|---|---|
| Context isolation | The auditor must complete its own inspection before reading any prior audit report for the same bundle |
| Architectural diversity | At least one auditor must use a substantially different model architecture or training family than the others |
| Checklist variation | At least one auditor must be instructed to run a free-form adversarial inspection before consulting the standard checklist |
| Scope isolation | Each auditor must independently identify the files it considers in scope; the operator must not pre-select the scope list |

### 3.3 Recommended sequencing for multi-auditor workflows

1. Dispatch all auditors simultaneously with instructions to produce an independent report _before_ reading others' reports.
2. After all independent reports are committed, distribute them to all auditors for cross-audit reconciliation.
3. Reconciliation is a separate step with a separate deliverable; it is not part of the original audit report.

The cross-audit reconciliation deliverable must explicitly address:
- Findings present in one report but absent from others, and why (genuine miss vs. out-of-scope vs. resolved differently)
- Findings where auditors disagree on severity
- Any defect class where all auditors agreed but the agreement itself is suspicious (all used the same checklist)

### 3.4 The "adversarial-first" auditor role

The checklist-based auditors (doctrine, code-coherence, device-coverage) will find defects that violate explicit rules. They will not find defects that comply with all rules while still producing wrong behavior. At least one auditor in every gate must be assigned the adversarial-first role:

- Receive only the produced prompts, the phase plan, and the live repo state.
- Do _not_ receive the audit checklist or prior findings.
- Answer only: "What happens if a capable agent follows these prompts exactly? What evidence would it produce that looks valid but proves something wrong?"

This role should rotate across auditors across batches so that no single model's failure modes dominate the adversarial lane.

---

## 4. The Audit Prompt as a Versioned Artifact

### 4.1 The self-referential maintenance problem

Both prior audits propose an audit prompt skeleton. The PR #233 audit prompt is cited as a "strong pattern" by both. However, neither audit addresses what happens when the audit prompt itself becomes stale.

The audit prompt skeleton references:
- Specific section numbers (`§6`, `§9`) that are defined in the production prompt template and may change across versions
- Specific file paths (`CURRENT-STATE.md`, `scripts/provision.sh`, `scripts/lint-prompts.sh`) that may be renamed, moved, or superseded
- Specific defect classes (stale WROOM IP `.190`, `esphome run`) that are project-specific and will change as the project evolves
- Specific evidence requirements (board fleet, fragment count) that reflect Phase 7 reality and may not apply in later phases

If the audit prompt is used unchanged for Phase 8 or Phase 9 work, it will contain stale references that either cause false positives (audit flags `.190` in a prompt that correctly uses `.191`) or missed classes (new defect categories introduced in later phases are not in the checklist).

### 4.2 Recommended audit prompt versioning discipline

The audit prompt skeleton should be treated as a versioned project artifact:

```
prompts/audit/prompt-bundle-audit-skeleton-v<N>.md
```

Version increments are required when:
- The production prompt template changes its section numbering
- A new mandatory deliverable class is added to `development-process-guide.md`
- A new board, YAML filename, or IP range is added to the fleet
- A new defect class is identified that requires a new mandatory check
- A prior audit prompt version produced a false positive or missed a confirmed defect

Version increments are not required for:
- Clarifications that do not change the checklist
- Auditor-specific customizations (use a separate fork, not a new version)

Each audit report must record which skeleton version was used. When a new skeleton version is created, the changelog entry must list what changed and why.

### 4.3 Skeleton freshness check

Before using an audit prompt skeleton, the auditor (or operator) should confirm:

- [ ] All `§N` references match the current production prompt template's section numbering
- [ ] All file paths are present in the repo at the current commit
- [ ] The board fleet table in the skeleton matches `CURRENT-STATE.md`
- [ ] The defect class list covers all HIGH/CRITICAL classes confirmed in prior audits for this project

If any check fails, the skeleton must be updated before the audit begins.

---

## 5. Triage Heuristics Under Time Pressure

Neither prior audit addresses the practical question: if the operator cannot run all four audit lanes in full before a deadline, which lanes should be prioritized?

Based on the Phase 7 defect inventory, the distribution of HIGH and CRITICAL findings by audit lane is:

| Audit lane | HIGH/CRITICAL findings in Phase 7 evidence | Time cost (relative) | Priority under pressure |
|---|---|---|---|
| Prompt-code coherence (C++ signatures, declaration order, compile feasibility) | Highest — multiple HIGH findings across v7.7.1.0, v7.7.1.1, and remaining in v7.7.1.4 after corrections | High (requires reading live headers) | **First** |
| Doctrine/merge-gate (§9 boundary, in-PR deliverables) | High — E-1 class found in first audit, recurred | Low (checklist-based, fast) | **Second** |
| Sequencing (command order, pipeline flow) | Medium — `--check` before `--write` class | Medium | **Third** |
| Device/evidence coverage (board coverage, curl timeouts, PR-body wording) | Low-medium — evidence wording mismatches rather than blocking defects | Medium | **Fourth** |
| Stale-fact drift (IPs, YAML names, cross-prompt references) | Low in Phase 7 after initial fixes; high risk in fresh batches | Low (grep-based, fast) | **Parallel with Second** |

**Recommended minimum viable audit** when time is constrained to a single pass:
1. Run the stale-fact grep suite (fast, objective, high-precision)
2. Run the §9 doctrine checklist (fast, objective)
3. Inspect all embedded C++ code blocks against live headers (slow but highest defect yield)
4. Verify command sequencing for any multi-step procedure involving `assemble`, `provision`, or version bump

This minimum viable audit will not catch all classes but will catch the classes most likely to produce blocking failures at implementation time.

---

## 6. Adversarial Scenario Classes That Checklists Structurally Miss

Checklists verify that rules are followed. They do not verify that rule-following produces correct behavior. The following scenario classes are structurally invisible to checklist-based audits and require adversarial inspection.

### 6.1 The "compliant but wrong" class

A prompt can comply with all checklist items while still producing incorrect implementation because:

- The prompt correctly names a function but applies it in a context where its preconditions are not met
- The prompt correctly lists all required deliverables but sequences them so that Deliverable B depends on evidence that Deliverable A was supposed to produce first
- The prompt correctly states the scope boundary but defines it so broadly that a corner-case file falls inside scope and gets incorrectly modified

**Detection method:** Run the prompt mentally as a capable but literal implementation agent. At each instruction, ask: "What would I do if I had not read any prior context and only had this instruction?" Instructions that require implicit knowledge to execute correctly are defects.

### 6.2 The "evidence theater" class

A prompt can require evidence that is technically collectible but does not prove what the prompt claims it proves:

- A curl check to `/api/status` returns a version string, but the version string is not tied to the binary that was just flashed — it reflects a cached value
- A grep confirming that a function is called in N places does not confirm it is called correctly or in the right order
- A serial log confirming device boot does not confirm the new code path was reached if the old code path remains the default

**Detection method:** For each evidence step, ask: "What is the minimal implementation that produces this evidence without actually achieving the goal?" If that implementation is easy to produce accidentally, the evidence is theater.

### 6.3 The "scope boundary leakage" class

Scope boundaries specify what an agent may modify. Leakage occurs when:

- A required modification in File A necessarily produces a side effect in File B, which is not in scope — the agent is then blocked
- A scope-whitelisted file (e.g., `bump-version.sh` artifacts) is whitelisted incompletely, causing the agent to stop at a legitimate change
- A scope guard uses a pattern-match that excludes a file by name but the file has been renamed since the guard was written

**Detection method:** For every file listed in scope, verify that all necessary side effects of editing it are also in scope. For every file excluded from scope, verify that no implementation step requires touching it.

### 6.4 The "deferred ambiguity" class

A prompt can appear clear at the level of individual instructions while containing ambiguity that only becomes visible when two instructions are combined:

- Step 3 says "use the current slot pointer" and Step 7 says "reset the slot pointer" — the prompt does not specify whether Step 7 runs before or after the slot-pointer-dependent evidence collection in Step 5
- Step 2 says "compile with provisioning mode WROOM" and Step 6 says "restore provisioning mode" — the prompt does not specify which provisioning mode to restore to if the pre-session mode was not WROOM

**Detection method:** Identify all stateful resources (pointers, mode flags, version strings, NVS state). For each one, trace every instruction that reads or writes it. Confirm the ordering is unambiguous.

---

## 7. Cross-Audit Reconciliation as a First-Class Methodology Step

Both prior audits mention cross-audit reconciliation. Neither defines it as a distinct step with its own deliverable format, ownership, and exit criteria.

### 7.1 Why reconciliation must be a distinct step

If reconciliation is left to each auditor to perform informally, the following failure modes occur:

- An auditor reports a finding as MEDIUM; another reports the same class as HIGH. Without reconciliation, the severity used for dispatch decisions is undefined.
- An auditor reports a finding that a second auditor already marked "not a defect." Without reconciliation, the finding remains open and the operator must arbitrate without structure.
- All three auditors miss the same defect. Without reconciliation, the shared miss is invisible. With reconciliation, the operator can note that the miss was systematic and trigger a fourth audit or an adversarial-first pass.

### 7.2 Recommended reconciliation deliverable

The cross-audit reconciliation report is a separate Markdown file committed to the same path as the individual audit reports:

```
prompts/handoff/<phase>/prompt-bundle-audit-reconciliation-<phase>-batch<N>-<date>.md
```

Required sections:

1. **Finding matrix** — one row per unique finding across all audits; columns for each auditor's severity rating or "not found"
2. **Agreed findings** — findings where all auditors agree on presence and severity; these are resolved directly
3. **Severity disagreements** — findings where auditors disagree on severity; resolved by the operator using the highest severity until evidence to reduce is produced
4. **Presence disagreements** — findings where one auditor flagged and another did not; requires a tie-break inspection or explicit "accepted as not a defect" rationale from the operator
5. **Systematic misses** — defect classes present in the final implementation outcome but not caught by any auditor; root-cause analysis and checklist update required
6. **Dispatch decision** — explicit go/no-go with rationale

### 7.3 Reconciliation ownership

The reconciliation report may be authored by any of the original auditors, by a separate reconciliation agent, or by the operator. If authored by an AI agent, it must be reviewed by the operator before the dispatch decision is recorded. The operator's explicit acceptance signature (a commit authored by the operator or a comment on the PR) is the dispatch gate, not the reconciliation report itself.

---

## 8. Recommended Additions to Existing Documents

### 8.1 `Docs/development-process-guide.md`

In addition to the prompt-bundle audit gate described by prior audits, add:

- A "planning document requirements" section listing the categories every phase plan must capture before a production prompt can be run (board fleet facts, YAML names, function signature snapshots, current VERSION, open issues to be referenced)
- A requirement that the production prompt template include a "live-extract" block of commands to be run before any prompt section is written
- A definition of auditor independence criteria (Section 3.2 of this document)
- A requirement that cross-audit reconciliation is a distinct deliverable with its own commit

### 8.2 `Docs/writing-guide/methodology.md`

Add a section on the "adversarial scenario" audit classes (Section 6 of this document) with examples from Phase 7. The writing guide should include explicit guidance that prompts must not require implicit knowledge to execute correctly — every instruction must be self-sufficient given only the prompt text and the live repo state at the time of dispatch.

### 8.3 `prompts/audit/` (new directory)

Create a dedicated directory for audit-related artifacts:

```
prompts/audit/
  prompt-bundle-audit-skeleton-v1.md     ← versioned skeleton (from prior audits' proposals)
  prompt-bundle-audit-skeleton-CHANGELOG.md  ← version history
  prompt-bundle-audit-reconciliation-template.md  ← reconciliation report template
```

This separates audit infrastructure from phase-specific prompt content and makes the skeleton easier to locate and version independently of phase work.

### 8.4 Production prompt template (`prompts/handoff/phase7-batch-production-prompt-update.md` or successor)

In addition to the post-production audit gate block recommended by prior audits, add a mandatory "live-extract block" at the start of the production session:

```markdown
## Live-Extract Block (run before writing any prompt section)

Run the following before drafting any prompt content. Paste outputs into your working context.
Do not use any board, YAML, IP, signature, or version fact from planning documents without
confirming it against these outputs first.

```bash
# Board fleet and IPs
grep -A 40 "Board Fleet" docs/CURRENT-STATE.md

# Current VERSION
cat VERSION

# Generated YAML names
ls -1 generated/

# Function signatures for sections you will reference
grep -n "^[a-zA-Z].*(" src/sensor_history.cpp src/nvs_manager.cpp | head -80

# Open issues flagged for this phase
gh issue list --label phase-7 --state open
```
```

The producer must confirm each output is populated before proceeding. If any command fails or returns unexpected results, the production session must stop and the operator must be notified.

---

## 9. Severity Model (Addendum)

The severity models in both prior audits are consistent and well-formed. This audit adds one clarification not present in either:

**The "compliant but incomplete evidence" case:** A prompt that requires evidence that is technically collectible but structurally insufficient to prove the claimed outcome should be rated MEDIUM (not LOW) when the insufficiency is likely to produce a false pass in the PR review. It should be rated HIGH when the insufficiency could mask a runtime defect that would reach production.

Example: a PR-body template that requires only a `curl` response but not a `grep` of the log for the new code path's distinctive log line — this is MEDIUM if the code path is a non-critical utility, HIGH if the code path is on the boot path or NVS write path.

---

## 10. Acceptance Criteria for This Methodology Audit to Be Considered Complete

This audit is advisory. It becomes incorporated into the project methodology only when the following are done in a follow-up PR:

- [ ] `Docs/development-process-guide.md` is updated with the planning document requirements section and auditor independence criteria
- [ ] `Docs/writing-guide/methodology.md` is extended with adversarial scenario classes and implicit-knowledge prohibition
- [ ] `prompts/audit/` directory is created with a versioned skeleton and reconciliation template
- [ ] Production prompt template is updated with the live-extract block
- [ ] Cross-audit reconciliation is added as a required deliverable in `development-process-guide.md` §2.5 (or equivalent)
- [ ] This document is referenced in `Docs/development-process-guide.md` alongside the Codex and GPT-5.5 Thinking audits

---

## 11. What This Audit Does Not Cover

In the interest of not duplicating prior work, this audit intentionally does not re-examine:

- The specific defects found in v7.7.1.0 / v7.7.1.1 / PR #233 (covered by Codex and GPT-5.5 Thinking audits and by the PR #233 audit report)
- The full audit lane checklist structure (well-defined in both prior audits)
- The severity model in full (reproduced only where addendum is needed)
- Lint rule candidates for `scripts/lint-prompts.sh` (comprehensively listed in both prior audits)
- The PR topology recommendation (agreed upon by both prior audits)

Readers should treat all three methodology audit documents as a set. No single document is sufficient on its own.

---

_End of Perplexity methodology audit._
