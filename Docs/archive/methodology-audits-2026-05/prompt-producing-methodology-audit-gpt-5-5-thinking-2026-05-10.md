# Prompt-Producing Methodology Audit — GPT-5.5 Thinking — 2026-05-10

_Auditor: GPT-5.5 Thinking_  
_Date: 2026-05-10_  
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Status: Methodology audit and recommended process extension; not yet a replacement for `Docs/development-process-guide.md` or `Docs/writing-guide/methodology.md` until incorporated by a follow-up methodology PR._

---

## 1. Executive Summary

The Phase 7 Batch 1 and Batch 2 prompt-production cycle exposed a process gap that sits **between phase planning and implementation-agent execution**.

The current workflow assumes that a prompt producer can reliably transform:

- phase plans such as `Docs/phase-7-review-and-rewrite.md`,
- planning-session records such as `Docs/multi-phase-planning-session-summary.md`,
- methodology rules such as `Docs/development-process-guide.md`, `Docs/writing-guide/methodology.md`, and `prompts/prompt-index-and-workflow.md`,

into accurate, executable prompt bundles.

That assumption is not safe. Prompt bundles are themselves implementation artifacts. They can contain:

- stale board identities or YAML names,
- wrong process doctrine,
- invalid test delegation,
- incorrect function signatures,
- compile-breaking embedded code,
- false checkpoints,
- incomplete scope whitelists,
- sequencing mistakes that create false device evidence,
- audit/report templates that preserve old doctrine.

The corrective principle is:

> **Prompt production is not complete when the prompt producer finishes. Prompt production is complete only after independent prompt-bundle audits confirm that the prompts are executable, self-contained, methodology-compliant, and free of HIGH-severity defects.**

The audit cannot be a one-off manual rescue. It must become a standard stage in the methodology.

---

## 2. Problem Statement

### 2.1 What happened

The Phase 7 v7.7.1.0 / v7.7.1.1 prompt bundle demonstrated that prompts can fail even when they look complete. The failures were not only implementation errors by coding agents. Several defects existed **inside the prompts** before the implementation agent started:

| Defect class | Example failure mode | Why it matters |
|---|---|---|
| Process-doctrine drift | Documentation and audit deliverables treated as post-merge work instead of in-PR merge gates | Creates missing deliverables and later clean-up PRs |
| Device-testing delegation drift | Agent-run compile/upload/curl testing punted to operator | Defers automatable evidence and weakens PR readiness |
| Stale environment facts | Wrong WROOM IP/YAML filename | Produces invalid device-test commands |
| Scope guard incompleteness | `bump-version.sh` effects treated as scope violations | Causes agents to stop on expected pipeline artifacts |
| Pipeline ordering mistakes | `assemble --check` before `--write` | Creates false checkpoint failures |
| Prompt-authored code defects | Wrong signatures, struct-size claims, declaration-order blockers | Causes avoidable compile failures or runtime risk |

Batch 2 corrections improved the process but also showed that independent audits are still necessary. PR #233 fixed the known A-series and B9 defects, yet subsequent audit still found a new HIGH prompt-code coherence defect in the v7.7.1.4 prompt.

### 2.2 Why relying on the producer alone is unsafe

The prompt producer is performing a translation task across many documents and assumptions. It must simultaneously preserve:

- phase plan intent,
- current repo reality,
- project critical rules,
- methodology doctrine,
- file paths,
- board fleet facts,
- test commands,
- device commands,
- prompt anatomy,
- executable code snippets,
- follow-up documentation rules.

This is too many constraints to trust a single session blindly. The risk is not that the producer is low quality; the risk is that the task is cross-disciplinary and error-prone. Prompt bundles need the same adversarial review discipline as production code.

---

## 3. Proposed New Methodology Layer: Prompt-Bundle Audit Gate

Add a formal gate between prompt production and implementation dispatch:

```text
Phase planning
  → Prompt-production prompt
  → Prompt producer creates prompt bundle
  → Prompt-bundle audit gate — NEW, mandatory
      → independent audits from multiple sources
      → prompt fixes
      → methodology/lint/template fixes
      → final zero-HIGH verification
  → Dispatch prompt to implementation agent
```

### 3.1 Gate rule

A newly produced prompt bundle **must not be dispatched** to a coding agent until:

1. At least three independent audits have been completed.
2. Every HIGH or CRITICAL finding is fixed.
3. A follow-up audit confirms zero remaining HIGH/CRITICAL findings.
4. Each confirmed defect has a methodology disposition:
   - producer prompt update,
   - methodology doc update,
   - lint/tooling guardrail,
   - explicit no-methodology-change rationale.

### 3.2 Independence rule

The prompt producer’s self-check is useful but does **not** count as an independent audit.

Independent audits should use separate reasoning contexts and, where practical, different tools or models. Recommended minimum:

| Audit | Primary focus | Expected output |
|---|---|---|
| Audit A — Process/doctrine | `development-process-guide`, §2.5, §3.3, §4.1, §9 bookkeeping, recommendation routing | Process compliance verdict |
| Audit B — Prompt-code coherence | Embedded C++/YAML/JS/Shell snippets, signatures, declarations, order, compile feasibility | Code-level prompt defect list |
| Audit C — Runtime/device coverage | Board fleet, device commands, curl evidence, runtime-path coverage, boot-path risk | Device-test coverage verdict |
| Optional Audit D — Adversarial/stale-fact | Grep for stale IPs, old filenames, cross-prompt references, old prompt anatomy | Drift and stale-reference report |

One audit may cover multiple areas, but the final audit package must show all four focus areas were explicitly checked.

---

## 4. Audit Deliverables

Every prompt-bundle audit must produce a committed Markdown report.

### 4.1 Naming convention

Use:

```text
prompts/handoff/<phase>/prompt-bundle-audit-<phase>-batch<N>-<auditor>-<date>.md
```

For special gates tied to a PR, use:

```text
prompts/handoff/<phase>/pr-<PR#>-prompt-bundle-audit-<auditor>-<date>.md
```

### 4.2 Required report sections

Each report must include:

1. **Executive verdict** — PASS / CONDITIONAL PASS / FAIL / BLOCKED.
2. **Scope audited** — exact files, PR, branch, commit SHA, issue(s), and prompt bundle version.
3. **Methodology sources read** — at minimum:
   - `Docs/development-process-guide.md`
   - `Docs/writing-guide/methodology.md`
   - `prompts/prompt-index-and-workflow.md`
   - active prompt-production prompt
   - relevant phase plan and planning summary
4. **Mechanical checks run** — commands or connector queries used.
5. **Produced-prompt checklist** — handoff / agent / two-step / template coverage.
6. **Finding table by severity** — CRITICAL / HIGH / MEDIUM / LOW.
7. **Methodology feedback table** — what rule/template/lint change prevents recurrence.
8. **Dispatch recommendation** — whether prompts can be used as-is.
9. **Confidence statement** — including what was not verified.
10. **Cross-audit reconciliation** — for later audits, compare to prior same-topic reports.

### 4.3 Verdict meanings

| Verdict | Meaning | Dispatch allowed? |
|---|---|---|
| PASS | No HIGH/CRITICAL findings; only optional LOW/MEDIUM improvements | Yes |
| CONDITIONAL PASS | No HIGH/CRITICAL findings; specific MEDIUM fixes recommended before or during dispatch | Usually yes, operator decision |
| FAIL | One or more HIGH findings | No |
| BLOCKED | Audit could not be completed because required facts/files/tools were missing | No |

---

## 5. Required Audit Checks

### 5.1 Doctrine and merge-gate checks

Every agent prompt must be checked for:

- §9 contains only mechanical post-merge bookkeeping: tag, issue auto-close, milestone bookkeeping.
- CURRENT-STATE update is in §6 or equivalent implementation section.
- Changelog entry is in-PR.
- Session log is in-PR.
- Consolidated audit is in-PR for non-trivial steps.
- Recommendation routing is explicit: GitHub issue or CURRENT-STATE, no third option.
- No active prompt says documentation deliverables happen after merge.
- If `Docs/writing-guide/methodology.md` and `Docs/development-process-guide.md` differ, the development-process guide governs.

### 5.2 Self-containedness and scope checks

Every agent prompt must be checked for:

- Scope boundary lists all directly editable files.
- Scope boundary whitelists all version-bump source files and regenerated pipeline artifacts when a version bump is in scope.
- Scope does not reference another prompt for constraints.
- HARD vs SOFT boundaries are clear.
- Generated artifacts are never manually edited except through pipeline scripts.
- `bump-version.sh` effects are treated as expected artifacts, not scope violations.

### 5.3 Current-repo reality checks

Prompt claims must be checked against live repo state, not plan text:

- Current `VERSION` and previous-step status.
- Current board fleet and IPs from `CURRENT-STATE.md`.
- YAML filenames generated by `scripts/provision.sh` and board profiles.
- Current function signatures via grep.
- Current fragment count.
- Current test/spec paths via `find tests -name "*.spec.js"`.
- Current Critical Rules table.
- Current open issues and unimplemented recommendations if the prompt references them.

### 5.4 Prompt-code quality checks

Any copy-ready code block in a prompt is an artifact and must be reviewed as code.

For C++ firmware snippets, auditors must check:

- Function signatures match live headers.
- Types are declared before use.
- Helper functions are declared before use.
- Stack allocation is plausible for target boards.
- Struct size claims are measured or statically asserted, not guessed.
- NVS key lengths are within constraints.
- `maybe_yield_nvs_scan_()` or equivalent required helper appears in long NVS loops.
- Boot-path code has explicit crash/rollback/device-test gates.
- Comments match actual behavior.

For YAML snippets, auditors must check:

- Correct generated YAML filenames.
- Correct provision mode before compile/upload.
- Correct `timeout 300 esphome upload` pattern.
- No `esphome run`.
- `esphome clean` before and after when required.

For shell snippets, auditors must check:

- Commands are copyable.
- No bare destructive commands without confirmation/guard.
- Grep expectations count definitions, not usages, when definitions are intended.
- Checkpoint commands produce stable output.

For JavaScript snippets, auditors must check:

- Generated-file/source-file boundary is respected.
- Fixture matrix commands match CI.
- User-facing strings and manifest-derived values are escaped where relevant.

### 5.5 Sequencing checks

Auditors must trace procedure order, not just command presence.

Required order patterns:

- Version bump before compile/upload/curl for versioned implementation steps.
- Fragment edit → `assemble-sensor-history.sh --write` → `--check` → greps.
- Generate dashboard/source artifacts before compile when needed.
- Device evidence after version bump and compile, not before.
- Temporary measurement scaffolds removed before commit.
- Provision mode restored before push.

### 5.6 Device coverage checks

For every step that exercises a runtime path:

- Device-test commands must cover every relevant production board from `CURRENT-STATE.md` unless the prompt explicitly justifies an omission.
- Boot-path code must be tested on cross-architecture boards when present, not only on the easiest board.
- The PR-body template must mention the same device coverage required by §6.
- Curl commands must include timeouts.
- Device evidence must be posted in-PR, not left as an operator post-merge task.
- If serial/UART evidence is impossible for the agent, the prompt must say the PR must record that limitation and obtain operator acceptance before ready-for-review.

---

## 6. Severity Model

### CRITICAL

A defect that can cause destructive data loss, unsafe credential exposure, or a bricked production device with no normal recovery path.

Examples:

- Prompt instructs deleting NVS/flash without confirmation or backup.
- Boot-path code is dispatched without any device-test gate.
- Management endpoint is added without authentication.

### HIGH

A defect that can cause compile failure, false device evidence, runtime crash, missing required deliverables, or a major scope/process violation.

Examples:

- Embedded code uses a non-existent function signature.
- Type or helper is used before declaration in C++.
- Version bump occurs after device evidence, so `/api/status` proves the wrong binary.
- WROOM device testing omitted for a boot-path prompt that must cover WROOM.
- Consolidated audit/session log moved to post-merge.

### MEDIUM

A defect that creates likely confusion, stale documentation, weak evidence, or a non-blocking process gap.

Examples:

- Changelog template hard-codes unmeasured struct byte sizes.
- PR-body template under-reports one required board.
- Reviewer checklist omits a useful but non-blocking check.

### LOW

A minor quality or maintainability concern.

Examples:

- Fragile line references where function anchors would be better.
- Historical audit prompt has overly broad grep wording.

---

## 7. Methodology Feedback Loop

A prompt-bundle audit is incomplete if it only says “fix the prompt.” Every confirmed defect must be routed to a recurrence-prevention action.

### 7.1 Defect routing table

Every finding must have this table:

| Finding | Prompt fix required? | Methodology update required? | Lint/tooling update required? | Issue/CURRENT-STATE routing |
|---|---|---|---|---|
| H1 | Yes | Yes/No with reason | Yes/No with reason | Issue # or CURRENT-STATE entry |

### 7.2 When methodology must be updated

A methodology update is required when:

- the defect came from ambiguous or conflicting guidance,
- the defect recurred from an earlier phase,
- the defect was caught only by human review but can be described as a repeatable rule,
- the prompt producer followed an existing rule but still produced a bad prompt,
- multiple auditors found the same class of defect,
- the defect affects all future batches, not only one prompt.

### 7.3 When lint/tooling must be updated

A lint/tooling update is required when:

- a simple grep or AST check can reliably catch the class,
- the defect is high-severity and likely to recur,
- the class is objective: stale IP, stale YAML, forbidden `esphome run`, cross-prompt reference, §9 post-merge documentation, missing curl timeout.

A lint update is optional or inappropriate when:

- the rule needs semantic judgment,
- the check would create many historical false positives,
- the defect is best caught by prompt-code review rather than text scanning.

---

## 8. Proposed Standard Audit Prompt Skeleton

The PR #233 audit prompt is a good pattern. Future prompt-bundle audits should use a reusable skeleton like this:

```markdown
Repo: <repo>
Prompt bundle / PR: <PR or file list>

Goal: Audit the newly produced prompt bundle before dispatch to an implementation agent.

Required behavior:
1. Read the prompt-production prompt and understand intended deliverables.
2. Read the governing methodology docs.
3. Read the phase plan and planning summary that produced the prompts.
4. Read every produced handoff, agent prompt, and two-step/reviewer prompt.
5. Check the prompts against current repo reality, not memory or plan text.
6. Run mechanical searches for stale facts and forbidden patterns.
7. Inspect embedded code as production code.
8. Produce a Markdown audit report with PASS/FAIL verdict.
9. If any HIGH/CRITICAL finding exists, dispatch is blocked.
10. For every finding, propose both a prompt fix and a recurrence-prevention methodology/lint action.

Audit sections required:
- Executive verdict
- Files audited
- Methodology sources read
- Mechanical checks run
- A-series / known-issue checklist
- Cross-cutting integrity checklist
- Independent prompt-code coherence inspection
- Findings by severity
- Methodology feedback table
- Dispatch recommendation
- Confidence statement
```

### 8.1 Mandatory adversarial questions

Every audit should answer:

1. What would make this prompt fail even if the coding agent follows it literally?
2. What evidence could this prompt collect that looks valid but proves the wrong thing?
3. Which commands rely on stale board names, stale IPs, stale paths, or stale signatures?
4. Which instructions create a contradiction between scope and required implementation?
5. Which code snippets require declarations, includes, or helper placement not shown in the prompt?
6. Which required deliverables are outside the PR or hidden in §9?
7. Which findings from the previous audit are supposedly fixed but not mechanically proven?
8. Which defect class should become a lint rule or methodology rule?

---

## 9. Recommended Process Topology

### 9.1 Preferred PR topology

To reduce the “four PRs to fix audits” problem, prompt production should use a staged PR topology:

1. Prompt producer opens a **draft prompt-bundle PR**.
2. Independent auditors add reports to the same PR branch or to a clearly linked audit PR.
3. Prompt producer/agent fixes prompt defects in the same prompt-bundle PR where practical.
4. Auditors re-run only changed-gate checks.
5. Prompt-bundle PR is marked ready only after zero HIGH/CRITICAL findings.
6. After merge, implementation-agent dispatch may begin.

### 9.2 If prompts are already merged

If the prompt bundle has already merged before the audit:

1. Mark the batch as blocked in the tracking issue or CURRENT-STATE if applicable.
2. Create a correction PR containing both prompt fixes and methodology/lint updates.
3. Run the same independent audit gate against the corrected merged state.
4. Dispatch only after zero HIGH/CRITICAL findings.

### 9.3 Dispatch rule

No implementation agent should receive an un-audited prompt bundle unless the operator explicitly accepts the risk in writing.

For high-risk firmware steps, especially boot-path, NVS, authentication, OTA/partition, or dashboard data-path work, audit is mandatory with no exception.

---

## 10. What Should Be Added to Existing Methodology Docs

This document recommends the following follow-up changes.

### 10.1 `Docs/development-process-guide.md`

Add a new section under Prompt Production:

```markdown
### 3.4 Prompt-Bundle Audit Gate

A prompt bundle is not ready for dispatch when the producer finishes. It is ready only after independent prompt-bundle audits confirm zero HIGH/CRITICAL findings. Every finding must be routed to prompt fix, methodology update, lint/tooling update, or explicit no-change rationale.
```

Add to §2.5 deliverables when a PR produces prompts:

- prompt-bundle audit reports,
- methodology feedback table,
- zero-HIGH confirmation.

### 10.2 `Docs/writing-guide/methodology.md`

Extend §3.13 Prompt-Provided Code Quality Gates with:

- declaration order checks,
- helper placement checks,
- compile feasibility checks for code inserted into earlier functions,
- warning that code placement directives are part of the code and must be audited.

### 10.3 `prompts/handoff/phase7-batch-production-prompt-update.md`

Add a mandatory post-production block:

```markdown
After producing this batch, STOP. Do not dispatch any produced prompt. Open/run the prompt-bundle audit gate using at least three independent auditors. Apply prompt fixes and methodology/lint updates before dispatch.
```

### 10.4 `scripts/lint-prompts.sh`

Candidate future lint rules:

| Rule | Purpose | Risk of false positive |
|---|---|---|
| Flag active prompts with documentation deliverables under §9 | Prevent E-1 recurrence | Low |
| Flag `esphome run` in active prompt files | Prevent hanging device-test commands | Low |
| Flag stale WROOM `.190` and stale WROOM YAML | Prevent stale board commands | Low |
| Flag active prompt curl commands without timeouts | Prevent hung audits/tests | Medium |
| Flag cross-prompt scope references | Prevent self-containedness failures | Low |
| Flag active Rule 61 contexts containing `pdMS_TO_TICKS(1)` | Prevent Rule 61 delay regression | Medium; must exclude historical/audit files |

---

## 11. Practical Checklist for the Operator

After a prompt producer finishes a batch, the operator should not dispatch it. Instead:

1. Confirm all expected prompt files exist:
   - handoff(s),
   - agent prompt(s),
   - two-step/reviewer prompt(s),
   - research prompt(s), if applicable,
   - closure prompt, if final batch.
2. Open or identify the prompt-bundle PR/commit.
3. Run prompt lint.
4. Launch at least three independent audit sessions using the audit prompt skeleton.
5. Require each auditor to produce a committed report.
6. Create a consolidated action list from findings.
7. Fix prompts and methodology/lint guardrails.
8. Run a final zero-HIGH audit against the corrected bundle.
9. Only then dispatch the first implementation prompt.

---

## 12. Lessons from PR #233 Applied to Future Audits

| Lesson | Future rule |
|---|---|
| A prompt can fix all known audit items and still contain a new HIGH defect | Audits must include independent fresh inspection, not only checklist verification. |
| Device-test presence is not enough | Verify device-test ordering, board coverage, curl timeout, and PR-body evidence wording. |
| Function signature fixes are not enough | Verify surrounding declaration order and placement of new helpers. |
| Static_assert pattern can be correct while docs are stale | Audit templates/changelog snippets as carefully as code snippets. |
| Repo-wide greps can fail on historical/audit files | Lint and audit prompts must distinguish active prompts from immutable historical records. |
| Multiple auditors may disagree | Cross-audit reconciliation is required before claiming a pass. |

---

## 13. Recommended Acceptance Criteria for Prompt-Bundle PRs

A prompt-bundle PR should not merge or be marked dispatch-ready until:

- [ ] All produced prompts are present and named correctly.
- [ ] All prompts are self-contained.
- [ ] All board/device facts are extracted from current repo state.
- [ ] `bash scripts/lint-prompts.sh --baseline main` exits 0 or has only accepted warnings.
- [ ] Three independent prompt-bundle audits are committed.
- [ ] No HIGH/CRITICAL audit findings remain.
- [ ] Every MEDIUM finding is fixed, deferred to a tracked issue, or explicitly accepted by the operator.
- [ ] Each confirmed finding has a methodology/lint disposition.
- [ ] Final audit reconciliation table is committed.
- [ ] Dispatch recommendation is explicit: which prompt may be sent first, and what prerequisites must be true.

---

## 14. Bottom Line

The project has already built strong implementation-agent methodology. The missing piece is equivalent rigor for the artifacts that drive those agents.

The prompt producer is not the final quality gate. The prompt producer is a compiler from plans and methodology into executable instructions. Its output must be audited like code, because agents will execute it like code.

The durable process should be:

```text
Plan → Produce prompts → Audit prompts → Fix prompts and methodology → Verify zero HIGH → Dispatch
```

Skipping the audit step converts prompt defects into implementation defects. The cost of catching a prompt defect before dispatch is one report and one prompt patch; the cost of catching it after dispatch is broken builds, misleading evidence, correction PRs, and degraded confidence in the development pipeline.

---

_End of methodology audit._
