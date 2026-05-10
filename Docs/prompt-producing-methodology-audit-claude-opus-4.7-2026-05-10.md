# Prompt-Producing Methodology Audit — Claude Opus 4.7 — 2026-05-10

_Auditor: Claude Opus 4.7_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Trigger: v7.7.1.x batch fix-cycle (PRs #225 → #233; issues #228 §A / §B9 / §C / §D / §E)_
_Output type: standalone proposal + appendix of suggested-but-not-applied diffs (no other files modified by this document)._

---

## 1. Why this document exists

Phase 7 Batch 2 produced three coding-agent prompts (`v7.7.1.2`, `v7.7.1.3`, `v7.7.1.4`) plus three session handoffs. Five independent audits subsequently ran against those prompts. They surfaced — between them — at least one HIGH-severity dispatch blocker (`RetentionBudget` declaration-order compile error in v7.7.1.4), three MEDIUM defects (hard-coded byte counts in changelog template; fragile `:248` line-number reference; O(N²) caveat without N upper bound), and a longer tail of LOW findings. Issue #228 was opened to track the fixes; PR #233 closed §A and §B9 only, leaving §C / §D / §E open.

The blocker was not implementation-agent error. The blocker existed in the prompt as written. A coding agent executing the prompt verbatim would have produced a board-bricking compile failure on the boot path. The producer-session methodology — driven by [phase7-batch-production-prompt-update.md](../prompts/handoff/phase7-batch-production-prompt-update.md) (v2.0, post-Batch-1 errata applied) — did not catch it, the producer's self-analysis did not catch it, and the first reviewer's automated lint did not catch it. Two of three independent third-party auditors caught it; one missed it. **A single auditor — even a careful one — is not sufficient gate.**

This document proposes:

1. A canonical **multi-auditor prompt audit methodology** to be invoked after every prompt-producer session before any prompt is dispatched to a coding agent.
2. **Updates to the producer methodology** itself, addressed at the eight failure modes catalogued in §5, so future producer sessions stop reintroducing the same defect classes.
3. An **appendix of suggested-but-not-applied diffs** to `Docs/development-process-guide.md`, `Docs/writing-guide/methodology.md`, `prompts/handoff/phase7-batch-production-prompt-update.md`, and `scripts/lint-prompts.sh`. The operator decides whether and when to apply them; this document does not modify those files.

This document supersedes nothing. It is additive, and proposes integration points into existing methodology files that the operator can weave in at their pace.

---

## 2. Scope and audience

**In scope:**
- Audit of any prompt set produced by a producer session — agent prompts, session handoffs, two-step prompts, audit prompts, planning supplements.
- Audit of the producer methodology files themselves (the prompts that produce prompts).

**Out of scope (separate concerns):**
- Audit of the phase planning sessions (those have their own assumption-audit gate per `Docs/development-process-guide.md` §4.1).
- Audit of coding-agent execution itself (that is what the existing review pipeline covers).
- Operator infrastructure (status-check deadlocks, branch-protection bypass, etc.).

**Audience:** the operator dispatching producer sessions; any auditor invoked under §6 of this document; future authors of `phase<N>-batch-production-prompt.md` updates.

---

## 3. Doctrinal anchors

This methodology subordinates itself to the existing source-of-truth hierarchy. In conflict, the order is:

1. Live code on `main` and live measurements/telemetry.
2. [Docs/development-process-guide.md](development-process-guide.md) — especially §2.5 (in-PR mandatory deliverables, merge gate), §3.2 (checkpoint authoring rules — _queries_ not _assertions_), §3.3 (self-containedness), §4.1 (assumption audit gate).
3. [Docs/writing-guide/methodology.md](writing-guide/methodology.md) §3.10 / §4.3 (device-testing all boards; required-reading specificity).
4. [Docs/llm-assisted-development-guide.md](llm-assisted-development-guide.md) §1.3 / §1.4 / §2.2 / §2.5 (truth-seeking discipline; assumption audit; source-of-truth hierarchy).
5. The current phase-batch production prompt (e.g. [phase7-batch-production-prompt-update.md](../prompts/handoff/phase7-batch-production-prompt-update.md)).

This document adds nothing that contradicts the above. Where it appears to add a new gate, it is operationalising an existing rule that producer sessions have demonstrably bypassed.

---

## 4. The producer methodology in one paragraph

Operator runs a phase planning session against the project's working `main`, producing a phase plan (e.g. [Docs/phase-7-review-and-rewrite.md](phase-7-review-and-rewrite.md)). The plan feeds into a phase-batch-production prompt (e.g. [phase7-batch-production-prompt-update.md](../prompts/handoff/phase7-batch-production-prompt-update.md), v2.0) which is run in a producer session (typically Claude Opus). The producer reads doctrinal sources (`development-process-guide.md`, `writing-guide/methodology.md`, `prompt-index-and-workflow.md`, the previous batch's session-handoff and consolidated-audit), runs an Assumption Audit gate and a Board Info Extraction gate, and emits a triple of deliverables per batch step: agent prompt + session handoff + two-step prompt. The operator then dispatches the agent prompt to a coding agent. The coding agent opens a PR. Reviewers (human + automated bots) review. Issues close. Phase advances.

The defect surface this document targets: between **producer emits the prompt** and **coding agent dispatches**, there is currently no enforced audit gate. PRs #232 / #233 / Issue #228 demonstrate that this gap costs ≥4 fix-cycle PRs per batch.

---

## 5. Failure modes the producer has demonstrated (catalogue)

The following eight patterns are observed across Batch 1 (v7.7.1.0 / v7.7.1.1) and Batch 2 (v7.7.1.2 / v7.7.1.3 / v7.7.1.4). Each is cited with the auditor that surfaced it. They are the classes any new audit must cover and any producer-methodology update must defuse.

### F-1. Cross-prompt scope reference defeats self-containedness

When prompts are produced in series, the producer instinctively deduplicates by cross-reference (`"see v7.7.1.2 §3 for full whitelist"`). Coding agents execute prompts one at a time without context bleed; the cross-reference creates a silent scope hole.

- Doctrinal conflict: [`Docs/development-process-guide.md` §3.3](development-process-guide.md): _"Every agent prompt must be independently executable. If a prompt's §3 (Scope) references another prompt for scope or constraint information, that is a blocking defect."_
- Caught by: lint rule **L3** (post-fix); originally caught by Copilot/Opus reviewers in Batch 2.
- Defused by: existing lint rule + new producer checklist item (§7.A below).

### F-2. Numeric constants embedded without verification gate

The producer copies values that appear stable — board IPs (`.189`, `.170`, `.191`), delay constants (`pdMS_TO_TICKS(5)`), partition sizes, struct byte counts (`36`, `226`, `168`) — from doctrinal sources or memory, without an embedded grep-back checkpoint. The same prompt that forbids hard-coding `static_assert` byte values pre-fills its own changelog template with hard-coded byte values.

- Caught by: GPT (Batch 2 audit) and GPT-5.5 Thinking + Opus 4.7 (PR #233 audit). Missed by Perplexity.
- Defused by: existing lint rules **L1, L4, L5** (post-fix for IP/YAML/title drift); planned **L8** for `pdMS_TO_TICKS(N)`; new "doctrinal-value pinning" producer rule (§7.B).

### F-3. Missing board coverage in device-test sections

The Board Info Extraction Gate verifies the IPs but does not enforce that every board listed in `CURRENT-STATE.md` Board Fleet appears in the produced device-test blocks. Batch 2 v7.7.1.3 / v7.7.1.4 originally tested only C3 (`.189`); WROOM-32D (`.170`) was missing. This is the same defect class as Batch 1's BUG-076 (single-board flash leaving a fleet board unverified).

- Caught by: Copilot (operator concern #3); Opus 4.7 (gap analysis: _"No mandate that agent prompts include all boards listed in CURRENT-STATE fleet"_).
- Defused by: new producer rule "extract → enumerate → enforce" (§7.C).

### F-4. Function signatures embedded without per-batch re-grep

The producer reads a header file once at producer-session start and embeds function calls assuming the signature is stable for the duration of the batch. v7.7.1.4 originally embedded a 4-arg `find_partition_size_bytes_(label, type, subtype, found_size)` against a live 3-arg signature. Two prompts in the same batch can be authored hours apart; intervening commits to firmware can shift signatures.

- Caught by: GPT (Batch 2 pre-merge audit). The §2 verification gate was added post-fix to re-grep the live header at coding-agent execution time.
- Defused by: §2 verification gate (already in v7.7.1.4); new producer rule "any embedded code referencing a live symbol MUST be paired with a §2 grep checkpoint" (§7.D).

### F-5. Line numbers as anchors instead of names

Producers cite `firmware/core/nvs-persistence.h:248` because it reads cleanly to a human. The reference rots silently as soon as anyone adds a function above line 248. The audit prompt itself, the handoff, and the two-step prompt all share the same fragile `:248`.

- Caught by: Perplexity (PR #233 M-2) and Opus 4.7 (independent M-2). Missed by GPT-5.5.
- Defused by: new producer rule "use named anchors, not line numbers" (§7.E). No automated lint rule because false-positives are too high.

### F-6. Declaration-order coherence not modelled

The producer composes new struct + helper definitions logically (struct first, helper second, call site third) but places them in the file in section-order — and sometimes the call site is in an _earlier_ function than the new types. C++ at file scope requires forward declaration or pre-declaration order. Producers are not running a mental compile; only a coding agent or a real compile catches this.

- Caught by: Opus 4.7 + GPT-5.5 Thinking (PR #233 audit, the H-1 finding). Missed by all four prior reviewers (Copilot, Opus, GPT, Perplexity).
- Defused by: new auditor rule "any prompt that injects code MUST be coherence-traced through declaration order" (§6.C); no automated check possible without a real compile.

### F-7. Gate-runs ≠ gate-enforces

The producer's Board Info Extraction Gate is a meta-gate: producer runs it, confirms values, no artifact captured. The coding agent reading the produced prompt has no audit trail. If the agent later disputes a board IP, there is no extractable evidence of the producer's work. This is the same shape as F-3 but applies to all extraction-style gates, not only board info.

- Caught by: Opus 4.7 (Batch 2 gap analysis).
- Defused by: new producer rule "every extraction-gate output is captured as a verification table in the produced session-handoff" (§7.F).

### F-8. Self-analysis misattributes root cause

The Batch 1 producer's `new-session-analysis-conclusion.txt` correctly identified that stale IPs were used, but attributed the cause to "didn't read `CURRENT-STATE.md`." The Batch 1 producer prompt _already said_ "`CURRENT-STATE.md` wins." The actual cause was that the rule was acknowledged but skipped — a discipline gap, not a knowledge gap. The fix added a procedural Extraction Gate, which is the right fix; but it works only if the producer mechanically runs it. If the same producer in Batch 3+ skips the gate the same way, the same defect class returns.

- Caught by: Opus 4.7 (Batch 2 gap analysis: _"The fix was not just re-reading; it required an extraction gate that mechanically verifies specific values."_)
- Defused by: producer self-analysis must be reviewed by the operator before being treated as authoritative (§7.G).

---

## 6. The audit methodology

### 6.A When it runs

Mandatory after every prompt-producer session, before the first agent prompt in the batch is dispatched. Specifically: after the producer commits the bundle (agent prompts + session handoffs + two-step prompts + audit-prompt updates) to a feature branch and opens a PR titled `prompts: ...`. The audit gate is a merge-block on that PR.

It also runs after fix-cycle PRs against an already-merged batch (PR #233 was a fix-cycle audit against PR #232's batch). The trigger is the same: producer commits, audit fires, dispatch waits.

### 6.B Multi-auditor convergence (canonical)

A single auditor is **not** sufficient. The audit gate requires:

- **At least two independent auditors**, run in parallel against the same produced bundle.
- **Independent context**: each auditor receives the same audit-prompt input but runs in a separate session with no shared scratch state. Cross-pollination of findings is permitted only through the public PR review thread, not through prompt-level coordination.
- **Different model families** when feasible: e.g. one Anthropic (Claude Opus / Sonnet), one OpenAI/GPT (GPT-5.5 Thinking / GPT-4.5), one Perplexity / Gemini / Codex when available. The PR #233 audit demonstrated empirically that different model families catch different defect classes; one missed the H-1 declaration-order finding that two others caught independently.
- **A reconciliation step** after both auditors emit reports. The reconciliation writer (the third or one of the existing two) produces a §8 reconciliation section quoting both reports' verdicts and listing per-finding agreement / disagreement / unique-to-one. The reconciliation writer must explicitly attribute each accepted finding to the source auditor.

Escalation: if either auditor reports verdict `FAIL`, the gate is **FAIL** for the bundle. CONDITIONAL PASS from one auditor combined with FAIL from another is **FAIL**. Two CONDITIONAL PASS verdicts with non-overlapping findings escalate to a third auditor.

### 6.C Required inputs to the audit prompt

The audit prompt template — modelled on [pr-233-third-independent-audit-prompt.md](../prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md) — must enumerate, in §1:

1. The bundle PR file diff (or merged-state if post-merge audit).
2. The originating issue's acceptance criteria, with §-level scoping (e.g. "this audit covers §A and §B9; §C-§E are separate").
3. All prior audit reports the bundle was meant to address (named explicitly).
4. The list of files the bundle modified, segregated by purpose (which files address which acceptance §).
5. **Live source-of-truth files** the bundle's claims must verify against (live header signatures, `CURRENT-STATE.md` Board Fleet table, canonical whitelists). The auditor is required to grep these live, not trust the bundle's quoted snippets.
6. Doctrinal sources (`development-process-guide.md` §2.5, `writing-guide/methodology.md` §3.10/§4.3).
7. The PR review thread (all rounds + inline comments) including coding-agent self-summary comments at the end.

### 6.D Check class structure

The audit prompt's §2 is partitioned into three check classes. This split is empirically sound — it scales without redundancy and exposes complementary defect surfaces.

#### §2.A — Doctrinal compliance

One row per acceptance-criteria item, mechanically verifiable. Pass condition is a literal grep or a live-file read. Example check shape:

> A4 — Every embedded call to `find_partition_size_bytes_()` in v7.7.1.4 uses the **3-arg** form `(label, type, subtype)`. The §2 verification gate has a checkpoint that re-greps the live header.

This class is what the producer's Errata fixes target (E-1 through E-5 of the post-Batch-1 errata list).

#### §2.B — Cross-cutting integrity

Properties that must hold across all bundle files. Example check shape:

> C2 — Zero `192.168.120.190` references in any modified file. All WROOM references use `.170`.

This class is where lint rules live. A bundle that passes lint will pass §2.B mechanically. Audit's role here is to catch lint-rule blind spots (the planned L8 / Rule 61 delay-value drift that no rule currently catches; F-2's broader pattern).

#### §2.C — Hot-take quality concerns (independent inspection)

Open-ended human-equivalent quality review. The auditor reads each prompt end-to-end. The check class is _explicitly not mechanical_; it is where coherence, declaration order (F-6), unverified factual claims (F-2's softer cases), cross-prompt consistency (F-1's softer cases), non-idempotent procedures, and doctrinal drift not caught by lint surface.

The PR #233 H-1 finding (declaration-order compile blocker) lived in §2.C. No lint rule and no §2.A check would have surfaced it; only an auditor reading the prompt as a coherent whole could.

The §2.C check list must include, at minimum:

1. Coherence after sub-step renumberings.
2. Unverified factual claims (numbers without measurement procedures or live-file citations).
3. Cross-prompt consistency (when two prompts in the batch share a file or symbol).
4. Non-idempotent procedures (insert-then-remove patterns; SIZING-log insertion that lacks a guard against double insert).
5. Doctrinal drift not caught by lint.
6. Lint-rule blind-spots the auditor noticed (and how the operator should track them — the planned §C13 / L8 process).
7. Byte-for-byte verification of any inlined whitelist against the canonical source.
8. **Declaration-order trace** for any prompt that inserts new types/functions and modifies existing call sites — _new_ check, lifted from F-6.
9. **Searchable-anchor check** for any prompt that cites a line number in a live source file — _new_, lifted from F-5.

### 6.E Output format

Every audit report must contain:

1. **Verdict** — `PASS` / `CONDITIONAL PASS` / `FAIL` with explicit thresholds (zero HIGH = PASS or CONDITIONAL PASS; ≥1 HIGH = FAIL).
2. **Summary table** — one row per check from §2.A / §2.B / §2.C with PASS / FAIL / N/A and a one-sentence note.
3. **HIGH findings** — file path, line, verbatim quote, why HIGH, concrete fix proposal.
4. **MEDIUM / LOW findings** — same structure, lower bar.
5. **Cross-audit reconciliation** — once at least one peer report exists. Quote the peer's verdict and per-finding agreement / disagreement / unique-to-one.
6. **Disposition recommendation per finding** — `fix-in-PR` / `track-as-followup` / `accept-as-is`.
7. **Confidence statement** — explicit numeric confidence on (a) each HIGH finding's reality, (b) probability of additional HIGH defects missed, (c) any mechanical check the auditor was unable to run.
8. **Attribution table** — when the report is the reconciliation writer's, attribute each finding to its originating auditor.

### 6.F Constraints (binding for every auditor)

1. **No invented file contents, function signatures, or line numbers.** If the auditor's tooling cannot retrieve a file, the related check is `unable to verify`, not `PASS`.
2. **No proposed new functionality.** The audit is whether the bundle correctly fixes the stated acceptance criteria, not whether the bundle could do more.
3. **Quote verbatim** when claiming a defect. Paraphrasing a defect is a methodology violation.
4. **If a verdict swing depends on an unverifiable check, say so** and recommend the operator manually verify that one check before merging.
5. **The auditor must read the bundle PR's body before writing the report** to avoid duplicating findings the producer self-disclosed.
6. **The auditor must read prior audit reports for the same bundle** when they exist, to avoid redundant work, but only after independently completing §2 — to preserve independence (this constraint is from the GPT-5.5 Thinking PR #233 report's §"Audit Method" and is empirically sound).

### 6.G Reconciliation step

The reconciliation writer reads all peer reports after submission, then writes a single §8 (or appended-section) update to one of the peer reports — or a separate reconciliation document — that:

1. Quotes each peer's verdict.
2. For every finding raised by any peer: marks _agreement_ (this report also raised it), _accept_ (peer raised it, this report didn't, on review accept), _decline_ (peer raised it, this report didn't, declined with reason), or _disagreement-on-severity_ (raised at different severity).
3. Lists which findings are unique to which auditor.
4. Updates the verdict if reconciliation reveals additional HIGH findings.
5. Writes a final attribution table mapping each finding in the reconciled report to its source auditor.

PR #233 audit demonstrated a working reconciliation pattern: see [pr-233-third-independent-audit-report-claude-opus-4.7-2026-05-10.md §8](../prompts/handoff/phase7/pr-233-third-independent-audit-report-claude-opus-4.7-2026-05-10.md).

---

## 7. Producer-methodology updates (proposed)

These are the "if defects found, the methodology must update so the producer doesn't stumble again" half of the user request. Each subsection is a producer-rule addition that defuses one or more of the F-1 … F-8 failure modes.

### 7.A Self-containedness as a hard producer-side gate

Add to the producer prompt's §"Pre-Output Gate" checklist:

- _Producer must grep its own output for `see v\d`, `see other prompt`, `as defined in <prompt-name>`. Zero matches required before any prompt may be emitted._

Defuses: F-1. Backstopped by lint rule **L3**.

### 7.B Doctrinal-value pinning rule

Any numeric constant in a produced prompt — IP, port, partition size, delay value, byte count, retention slot count, struct member count — must:

1. Be cited with a live-source reference (file:symbol, not file:line; see 7.E).
2. Be re-verified at coding-agent execution time via a §2 grep checkpoint embedded in the produced prompt.

Specifically forbidden: hard-coding measured values (struct sizes, retention budgets) into changelog templates or PR-body templates. The §6 in-PR deliverables that consume measured values must be filled in by the agent _after_ the §2 measurement step, not pre-filled by the producer.

Defuses: F-2. Backstopped by lint rules **L4, L5**, and (planned) **L8**.

### 7.C Extract → enumerate → enforce

The Board Info Extraction Gate (and any analogous gate that reads `CURRENT-STATE.md` or another live source) must produce three outputs, not one:

1. **Extract**: read the source.
2. **Enumerate**: emit the extracted values as a verification table in the session handoff (visible to the coding agent).
3. **Enforce**: every produced prompt's §6 device-test block must list every board from the enumeration. The producer must grep its own output for each board IP from the enumeration; missing boards are a producer-side hard fail.

Defuses: F-3, F-7. The "verification table in handoff" requirement is what currently is missing — Batch 2 produced the extraction but did not pin the output anywhere a coding agent could consult.

### 7.D Live-symbol re-grep mandate

Any embedded code in a produced prompt that calls or references a live source-file symbol (function, struct, constant, macro) must be paired with a §2 verification-gate checkpoint that re-greps the live source. The §2 checkpoint must be authored as a _query_ (`grep -A2 'find_partition_size_bytes_' firmware/core/nvs-persistence.h` and verify the agent-readable expected-shape comment), not an assertion.

Defuses: F-4. Already in v7.7.1.4 §2 post-fix; needs to be a producer-prompt rule, not an ad-hoc Errata.

### 7.E Searchable anchors not line numbers

When a produced prompt cites a location in a live source file, the citation must use a name-anchored form:

- Good: `firmware/core/nvs-persistence.h: maybe_yield_nvs_scan_()` or `firmware/core/nvs-persistence.h: search 'vTaskDelay(pdMS_TO_TICKS' for the canonical value`.
- Bad: `firmware/core/nvs-persistence.h:248`.

Line numbers are acceptable as a courtesy ("currently L248 — re-verify with `grep -n …`") but never as the sole anchor.

Defuses: F-5.

### 7.F Declaration-order coherence trace

When a produced prompt introduces a new type or new function _and_ modifies an existing function body to use it, the producer must walk the file in linear order and confirm the new symbol's declaration precedes every use. The walk is a producer-side checklist item:

- _Producer trace: for each new symbol introduced, `grep -n` the symbol in every modified file and confirm the smallest line number is the declaration._

If the prompt also modifies callers in a different fragment file, the trace expands to all files in the assembled translation unit.

Defuses: F-6. No automated check possible until the audit gate compiles the bundle (which is currently out of scope for prompt-producer sessions but could be added).

### 7.G Self-analysis must be operator-reviewed

Producer self-analysis (`new-session-analysis-conclusion.txt` and the post-batch errata sections in `phase<N>-batch-production-prompt.md`) is treated by default as authoritative. PR #233 demonstrated that producer self-analysis can misattribute root cause. The producer's self-analysis is now _input_ to the operator-led post-batch review, not authoritative output.

The post-batch review confirms or rejects each producer-claimed root cause and may add additional root causes the producer missed. Only the operator-confirmed errata text is allowed to be merged into the next batch's producer prompt.

Defuses: F-8.

### 7.H Pre-dispatch audit gate is mandatory

The producer prompt must explicitly instruct the producer that **the bundle is not dispatch-ready until at least two independent auditors have reported, the verdict is not FAIL, and the reconciliation §8 is committed.** This belongs in the producer prompt's §"Output" / closing section, mirroring the merge gate in `Docs/development-process-guide.md` §2.5.

Defuses: the meta-failure that PR #233 was needed at all. A bundle without an audit gate is a bundle with deferred discovery.

---

## 8. Integration with existing CI / lint

### 8.A Existing rules and their shape

`scripts/lint-prompts.sh` currently enforces L1 (forbidden "Post-Merge Deliverables" title), L2 (forbidden "(for Human)" markers), L3 (cross-prompt scope references), L4 (stale WROOM IP `.190`), L5 (wrong WROOM YAML filename), L6 (assembly write-then-check ordering — WARN not ERROR), L7 (§9 compound post-merge pattern). All are belt-and-braces enforcement of producer rules that the producer was already supposed to follow.

`.github/workflows/prompt-lint.yml` runs the lint with a `--baseline main` mode that surfaces only NEW violations. Existing pre-commit violations are reported informationally.

### 8.B Gaps the audit methodology must continue to cover until lint catches up

| Gap | Why lint can't currently catch it | Audit role |
|---|---|---|
| Rule 61 `pdMS_TO_TICKS(N)` value drift | No live-source comparison rule yet (planned L8) | §2.B C1 verifies via live-file grep |
| Hard-coded byte counts in changelog | No structural rule for "templates must not pre-fill measured values" | §2.C unverified-factual-claims check |
| Declaration-order compile errors | Requires real compile of assembled fragments | §2.C declaration-order trace |
| Fragile `:NNN` line-number anchors | False-positive rate too high for a hard rule (line numbers do appear legitimately) | §2.C searchable-anchor check |
| Missing board coverage | Requires structured comparison with `CURRENT-STATE.md` Board Fleet | Producer rule 7.C "extract → enumerate → enforce" + §2.A device-test check |

### 8.C Lint-rule additions tracked but out of scope here

- **L8** — `pdMS_TO_TICKS(N)` value drift detection. Tracked as #228 §C13.
- **L9** — Forbid hard-coded `\b\d+ bytes?\b` in changelog templates outside `## Measurements` sections. (proposal)
- **L10** — Forbid `:` followed by 1-4 digits as a sole anchor in produced prompts (allow when accompanied by a `re-verify with grep` follow-on). (proposal)

Each of these is a new producer-side guardrail that, when implemented, removes the corresponding §2.C check from the auditor's burden.

---

## 9. Disposition for current state

| Item | Status | Action |
|---|---|---|
| §6 audit methodology | proposed | Operator decides whether to weave into `Docs/development-process-guide.md` §5 (new section) or keep as a standalone reference. |
| §7.A–§7.H producer-rule additions | proposed | Operator decides whether to weave into `prompts/handoff/phase<N>-batch-production-prompt-update.md` Errata sections or pull forward into v3.0 of the producer prompt. |
| Lint-rule additions L8 / L9 / L10 | proposed | Tracked under #228 §C / §C13. |
| PR #233 reconciliation pattern | empirical reference | Already lives in [pr-233-third-independent-audit-report-claude-opus-4.7-2026-05-10.md §8](../prompts/handoff/phase7/pr-233-third-independent-audit-report-claude-opus-4.7-2026-05-10.md). Future batches can reuse it directly. |
| H-1 declaration-order defect (PR #233) | open | Must be fixed before v7.7.1.4 dispatch per the audit verdict. |

---

## 10. Confidence and caveats

**Confidence the methodology in §6 is sufficient to catch a v7.7.1.4-class defect:** ≈ 0.85. The H-1 was caught by 2 of 3 PR #233 auditors but missed by the fourth (Perplexity, CONDITIONAL PASS). The two-auditor minimum in §6.B is the empirical floor; three is safer when model families are correlated.

**Confidence the producer rules in §7 prevent recurrence:** ≈ 0.65. Rules are necessary but not sufficient. F-8 (self-analysis misattribution) is a discipline failure, not a knowledge failure; rules don't fix discipline. The audit gate is the backstop.

**What this document does not solve:**
- The producer occasionally reads a stale architecture doc that has been superseded between phase planning and prompt production. The Phase 7 rewrite caught one such case; future phases will recur. A doc-staleness gate at producer-session start is a separate proposal.
- The audit gate adds latency. Operator must decide the cost-vs-correctness tradeoff per phase.
- A coding agent that ignores the §2 verification-gate checkpoints can still ship defects. The audit gate confirms the prompt is correct; it does not confirm the agent followed the prompt. That is the existing review-pipeline's job.

**Open questions for operator review:**

1. Should multi-auditor convergence be canonical for _every_ producer session, or only for sessions producing multi-step batches and/or boot-path code? (This document recommends the former; cost may justify the latter.)
2. Is reconciliation a new auditor's role or one of the existing auditors'? (PR #233 used the third auditor; can be either, but should be policy.)
3. When should the producer prompt itself be audited (this document's recommendation)? On every producer-prompt update? Only when the previous batch's audit found a HIGH-severity defect?

---

## Appendix A — Suggested-but-not-applied diffs

These diffs are illustrative. They are not applied by this document. The operator decides whether and when to apply them.

### A.1 `Docs/development-process-guide.md` — new §5 "Prompt Audit Gate"

Suggested insertion after the existing §4.1 "Assumption Audit Gate":

```markdown
## §5 — Prompt Audit Gate (post-producer, pre-dispatch)

Every prompt-producer session that emits a coding-agent prompt set must be
followed by a multi-auditor audit before any prompt in the set is dispatched
to a coding agent. The audit is a merge-block on the producer's PR.

Requirements (binding):

1. ≥ 2 independent auditors, run in parallel, ideally from different model
   families. ≥ 3 if both auditors return CONDITIONAL PASS with non-overlapping
   findings.
2. The audit prompt template lives at
   `Docs/templates/prompt-audit-template.md` (to be created from
   `prompts/handoff/phase7/pr-233-third-independent-audit-prompt.md` as the
   canonical example).
3. Verdict thresholds: zero HIGH = PASS or CONDITIONAL PASS; ≥ 1 HIGH = FAIL;
   any FAIL among the auditors = bundle FAIL.
4. A reconciliation §8 (or separate reconciliation report) is committed
   alongside the audit reports before dispatch.
5. The audit gate covers prompts and handoffs only. Implementation
   correctness of any agent prompt's §6 procedure is out of scope (covered
   by the existing review pipeline once the agent runs).

See `Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md`
for the full methodology.
```

### A.2 `Docs/writing-guide/methodology.md` — append to §3.10

Suggested addition at the end of §3.10:

```markdown
### §3.10.1 — Doctrinal-value pinning (added 2026-05-10)

Any numeric constant in a produced prompt — IP, port, delay value, byte
count, retention slot count, partition size — must be cited with a live-
source reference (file:symbol form, not file:line) and re-verified at
coding-agent execution time via a §2 grep checkpoint embedded in the
prompt.

Specifically forbidden: pre-filling measured values into changelog or
PR-body templates. The §6 in-PR deliverables that consume measured
values must be filled in by the agent after the §2 measurement step,
not pre-filled by the producer.

Backstopped by `scripts/lint-prompts.sh` rules L4 (IP), L5 (YAML name),
and (planned) L8 (delay values), L9 (template byte counts).
```

### A.3 `prompts/handoff/phase7-batch-production-prompt-update.md` — new Errata entries E-6 through E-9

Suggested addition to the Errata section (currently E-1 … E-5):

```markdown
### E-6 — Declaration-order coherence (post-PR-#233)

When a prompt introduces a new type or new function and modifies an
existing function body to use it, walk the file in linear order and
confirm the new symbol's declaration precedes every use. Producer
checklist:

  for each new symbol S introduced:
    grep -n 'S' <every modified file>
    confirm smallest line number is the declaration

Backstop: §2.C declaration-order trace in the audit gate.

### E-7 — Searchable anchors, not line numbers

Cite live-source locations by symbol name, not line number. Acceptable:
`firmware/core/nvs-persistence.h: maybe_yield_nvs_scan_()`. Unacceptable
as sole anchor: `firmware/core/nvs-persistence.h:248`.

### E-8 — Extraction-gate output as verification artifact

Every gate that reads a live source (Board Info Extraction, Assumption
Audit, etc.) must emit its output as a visible verification table in
the session handoff. Coding agents must be able to read the gate's
output without re-running the gate.

### E-9 — Self-analysis is input, not output

Producer self-analysis (`new-session-analysis-conclusion.txt`, post-
batch errata) is treated as input to the operator-led post-batch review,
not authoritative output. Only operator-confirmed errata may be merged
into the next batch's producer prompt.
```

### A.4 `scripts/lint-prompts.sh` — sketches for L8, L9, L10

```bash
# L8 — pdMS_TO_TICKS(N) value drift
# Reads the canonical value from firmware/core/nvs-persistence.h
# and verifies every Rule 61 reference in prompts/** matches.
canonical=$(grep -oE 'pdMS_TO_TICKS\([0-9]+\)' \
  firmware/core/nvs-persistence.h | head -1)
violations=$(grep -rEn 'pdMS_TO_TICKS\([0-9]+\)' prompts/ \
  | grep -v "$canonical" | grep -i 'rule 61\|maybe_yield_nvs_scan_')
[[ -z "$violations" ]] || error "L8: Rule 61 delay value drift"

# L9 — hard-coded byte counts in changelog templates
# Forbid '\b\d+ bytes?\b' in changelog blocks unless under
# a '## Measurements' heading.
# (sketch only; needs structural Markdown parser)

# L10 — bare line-number anchors without re-verify follow-on
# Forbid '<file>:[0-9]+' alone; require a follow-on '(re-verify with grep ...)'.
# (sketch only; needs context-aware regex)
```

---

## Appendix B — Worked example: PR #233 audit traced through this methodology

| Step | What happened | Methodology mapping |
|---|---|---|
| Producer session emitted bundle | 9 files modified for #228 §A + §B9 | §4 producer methodology |
| Audit triggered on bundle PR | 3 auditors dispatched in parallel | §6.A trigger + §6.B multi-auditor convergence |
| Auditor inputs | Each read `pr-233-third-independent-audit-prompt.md` §1 | §6.C required inputs |
| Auditor 1 (Perplexity, Claude Sonnet 4.6) | Verdict CONDITIONAL PASS; missed H-1 | §2.C declaration-order trace not run |
| Auditor 2 (GPT-5.5 Thinking) | Verdict FAIL; H-1 + M-1 + L-1 | §2.C trace caught H-1 |
| Auditor 3 (Claude Opus 4.7 / this report) | Verdict FAIL; H-1 + M-1 + M-2 + L-1 + L-2 | §2.C trace caught H-1 + extra M-2 |
| Reconciliation | Opus 4.7 wrote §8 reconciliation; accepted Perplexity M-3 / GPT-5.5 L-2 / Perplexity L-1 (renumbered to L-4) / Perplexity L-3 (renumbered to L-5); declined Perplexity L-4 + L-2 | §6.G reconciliation step |
| Final verdict | FAIL — H-1 must fix before dispatch | §6.B escalation rule (one FAIL = bundle FAIL) |

The methodology produced the correct outcome with one auditor mis-call (Perplexity missed H-1). A single-auditor regime that happened to dispatch to Perplexity alone would have green-lit a board-bricking compile error. This is the empirical case for §6.B.

---

_End of methodology audit document._
