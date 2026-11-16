# Prompt-Producing Methodology Audit - Codex - 2026-05-10

_Auditor: Codex_
_Date: 2026-05-10_
_Repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_
_Status: Recommended methodology extension. This document is not itself a replacement for `Docs/development-process-guide.md`, `Docs/writing-guide/methodology.md`, or the active prompt-production templates until those files are updated in a follow-up PR._

---

## 1. Executive Summary

The Phase 7 prompt-production workflow has treated the prompt producer as the final compiler from planning documents into executable agent instructions. The v7.7.1.0, v7.7.1.1, and PR #233 follow-up sequence shows that this is not safe.

Prompt bundles are executable project artifacts. A coding agent will follow their commands, code snippets, file paths, device-test plans, and evidence requirements. If a prompt is wrong, the implementation can fail even when the coding agent follows instructions literally.

The methodology should therefore add a mandatory prompt-bundle audit gate:

```text
Plan -> produce prompts -> independently audit prompts -> fix prompts and methodology -> verify zero HIGH -> dispatch
```

The key requirement is not only to fix defective prompts. Every confirmed prompt defect must also be routed to a recurrence-prevention action: producer-prompt update, methodology-doc update, lint/tooling rule, template update, or an explicit no-change rationale.

---

## 2. Why The Current Methodology Failed

The intended production chain is:

```text
Phase planning docs
  -> prompt-production prompt
  -> producer session
  -> handoff / agent / two-step prompts
  -> implementation agent
```

The failure mode is that the producer session must preserve too many independently moving facts:

- current code reality from `CURRENT-STATE.md` and live source files,
- planning intent from documents such as `Docs/phase-7-review-and-rewrite.md`,
- implementation doctrine from `Docs/development-process-guide.md`,
- prompt anatomy from `Docs/writing-guide/methodology.md`,
- project critical rules from `prompts/prompt-index-and-workflow.md`,
- board fleet facts, generated YAML names, and device IPs,
- generated-file boundaries and pipeline order,
- exact command semantics,
- embedded C++/YAML/JS/shell code correctness,
- PR evidence and in-PR deliverable requirements.

Blindly trusting one producer session converts any missed constraint into an implementation defect. In Phase 7 this produced a costly audit-and-correction chain across issues and PRs instead of a single controlled pre-dispatch gate.

---

## 3. Observed Defect Classes

| Defect class | Concrete symptom | Process implication |
|---|---|---|
| Doctrine drift | Session logs, audits, or CURRENT-STATE updates framed as post-merge work | Prompt producer must be checked against `development-process-guide.md` section 2.5, not memory |
| Device-test delegation drift | Agent-capable compile/upload/curl work assigned to operator | Prompt audit must verify agent-performed device evidence in section 6 |
| Stale environment facts | Old WROOM IP `.190` or wrong WROOM YAML filename | Producer and auditor must extract facts from live repo state |
| Scope-whitelist omissions | `bump-version.sh` side effects treated as scope violations | Prompt scope must include canonical version-bump and pipeline artifact whitelist |
| Pipeline sequencing errors | `assemble-sensor-history.sh --check` before `--write` | Audit must trace command order, not just command presence |
| Embedded-code defects | Wrong signatures, static-assert blockers, declaration-order errors | Prompt code blocks must be reviewed as code |
| Evidence mismatch | PR-body template mentions less evidence than section 6 requires | Audit must compare implementation steps, acceptance criteria, and PR templates |
| Historical-file false positives | Repo-wide grep catches immutable old prompts or audit reports | Lint and audit prompts must define active-file scope explicitly |

---

## 4. Methodology Decision

Prompt production must become a gated process with three hard rules.

1. A prompt bundle is not dispatchable when the producer finishes it.
2. A prompt bundle is dispatchable only after independent audit confirms zero HIGH or CRITICAL defects.
3. Defects found in prompt audits require both local prompt fixes and recurrence-prevention disposition.

This rule should apply to every non-trivial firmware or dashboard prompt batch. It should be mandatory for boot-path, NVS, persistence, authentication, partition, OTA, dashboard data-path, and multi-board validation work.

---

## 5. Proposed Prompt-Bundle Audit Gate

### 5.1 Gate Entry Conditions

Before audits start, the prompt producer must provide:

- the exact prompt-production prompt used,
- the phase plan and planning-summary sources,
- every produced handoff prompt,
- every produced implementation-agent prompt,
- every two-step/reviewer prompt,
- any research, closure, or audit templates produced in the same batch,
- the branch or commit being audited,
- the intended dispatch order.

If any item is missing, the audit is BLOCKED rather than inferred.

### 5.2 Required Independent Audits

Use at least three independent audits. They may be produced by different models, tools, or sessions, but they must not reuse the prompt producer's context as the sole evidence source.

| Audit lane | Required focus |
|---|---|
| Doctrine audit | In-PR deliverables, section 9 bookkeeping boundary, recommendation routing, self-containedness, prompt anatomy |
| Code-coherence audit | Embedded C++/YAML/JS/shell snippets, function signatures, declaration order, helper placement, compile feasibility |
| Device/evidence audit | Board coverage, generated YAML names, provisioning mode, upload/curl commands, PR-body evidence, operator-only exceptions |
| Drift/lint audit | Stale IPs, stale filenames, old prompt references, `esphome run`, missing curl timeouts, generated-file violations |

An individual audit report may cover more than one lane, but the consolidated audit package must prove that all lanes were checked.

### 5.3 Exit Conditions

The prompt bundle may be dispatched only when:

- all HIGH and CRITICAL findings are fixed,
- a final audit or re-audit confirms zero HIGH and CRITICAL findings,
- every MEDIUM finding is fixed, accepted by operator, or routed to an issue,
- every confirmed defect has a methodology/lint/template disposition,
- the dispatch recommendation names the first prompt that may be used and any prerequisites.

---

## 6. Standard Prompt-Bundle Audit Report

Each independent audit report should be committed as Markdown.

Recommended path:

```text
prompts/handoff/<phase>/prompt-bundle-audit-<phase>-batch<N>-<auditor>-<date>.md
```

If the audit is tied to a PR:

```text
prompts/handoff/<phase>/pr-<PR#>-prompt-bundle-audit-<auditor>-<date>.md
```

Required sections:

1. Verdict: PASS, CONDITIONAL PASS, FAIL, or BLOCKED.
2. Audited scope: files, branch, commit, PR, issue, and prompt bundle version.
3. Sources read: methodology docs, prompt-production prompt, planning docs, current repo state.
4. Commands and mechanical checks run.
5. Summary table: one row per required check.
6. Findings by severity.
7. Methodology feedback table.
8. Cross-audit reconciliation if other reports exist.
9. Dispatch recommendation.
10. Confidence statement and unverified items.

---

## 7. Required Checks For Future Audits

### 7.1 Doctrine Checks

Auditors must verify:

- `CURRENT-STATE.md` updates are in-PR deliverables.
- Changelog entries are in-PR deliverables.
- Session logs are in-PR deliverables.
- Consolidated audits are in-PR deliverables for non-trivial steps.
- section 9 contains only mechanical post-merge bookkeeping.
- Recommendation routing has no third path beyond GitHub issue, `CURRENT-STATE.md`, or explicit wontfix rationale.
- The prompt does not rely on another prompt for scope, constraints, or acceptance criteria.
- If methodology docs conflict, `Docs/development-process-guide.md` governs.

### 7.2 Current-Reality Checks

Auditors must verify against live files, not planning memory:

- `CURRENT-STATE.md` current version and board fleet.
- Generated YAML filenames from provisioning scripts and board profiles.
- Function signatures from live firmware headers.
- Actual fragment count.
- Actual Playwright spec paths.
- Active Critical Rules table.
- Open issues and unimplemented recommendations referenced by the prompt.

### 7.3 Embedded-Code Checks

Every copy-ready code block in a prompt is audited as code.

For C++:

- Types are declared before use.
- Helpers are declared before use.
- Function signatures match live code.
- Stack allocations are plausible for target boards.
- Struct sizes are measured or asserted, not guessed.
- Long NVS loops include required yields.
- Boot-path code has explicit device-test and recovery gates.

For YAML/device commands:

- Correct provisioning role precedes compile/upload.
- Correct generated YAML filename is used.
- Uploads use `timeout 300 esphome upload <yaml> --device=<ip>`.
- `esphome run` is not used.
- Clean commands are included where required.

For shell/checkpoints:

- Commands are copyable.
- Grep checks count definitions when definitions are intended.
- Expected counts are mechanically derived from the same prompt block or live code.
- Regeneration happens before check commands.
- Destructive commands are absent or guarded.

For dashboard/JS prompts:

- Source files, not generated bundles, are edited.
- `authFetch()` and public-fetch boundaries are preserved.
- Fixture matrix commands match CI.
- User-visible/selector-derived strings are safely handled.

### 7.4 Evidence Checks

Auditors must compare:

- implementation steps,
- acceptance criteria,
- pre-PR gate,
- PR body template,
- reviewer checklist,
- session handoff.

These sections must require the same evidence. If section 6 requires C3 and WROOM testing but the PR-body template mentions only C3, that is a defect even if the device commands are present.

---

## 8. Severity Model

| Severity | Meaning | Examples |
|---|---|---|
| CRITICAL | Can cause destructive data loss, unsafe credential exposure, or unrecoverable production-device risk | Unauthenticated management endpoint, unguarded NVS erase, boot-path flash change with no recovery/test gate |
| HIGH | Blocks dispatch because it can cause compile failure, false evidence, missing merge-gate deliverables, runtime crash, or major scope violation | Wrong function signature, type used before declaration, version bump after device evidence, missing required board coverage |
| MEDIUM | Does not immediately block dispatch but weakens evidence, documentation, maintainability, or future execution | Hard-coded unmeasured byte counts, fragile line-number anchors, incomplete PR-body wording |
| LOW | Minor clarity or maintainability issue | Cosmetic naming drift, historical banner missing provenance |

Dispatch is blocked on any HIGH or CRITICAL finding.

---

## 9. Methodology Feedback Loop

Every audit finding must be routed through this disposition table:

| Finding | Prompt fix | Producer-prompt update | Methodology-doc update | Lint/tooling update | Tracking |
|---|---|---|---|---|---|
| H1 example | Required | Required/Not required with reason | Required/Not required with reason | Required/Not required with reason | Issue, CURRENT-STATE, or wontfix rationale |

### 9.1 When Methodology Must Change

Update methodology when:

- the same defect class has recurred,
- the producer followed existing instructions but still produced a bad prompt,
- the rule was implicit rather than explicit,
- multiple auditors found the same class,
- the defect affects future prompt batches,
- the defect was caused by conflict between planning docs and current repo doctrine.

### 9.2 When Lint Or Tooling Must Change

Add or update lint/tooling when the defect is objective and detectable:

- stale WROOM IP or YAML filename,
- forbidden `esphome run`,
- active section 9 documentation deliverables,
- cross-prompt scope references,
- missing curl timeouts,
- `assemble-sensor-history.sh --check` before `--write`,
- active Rule 61 contexts containing stale `pdMS_TO_TICKS(1)`.

Do not force semantic judgment into grep-only lint. Declaration-order problems, cross-prompt implementation coherence, and stack-risk analysis belong in human/model code audits unless a robust parser-based tool exists.

---

## 10. Audit Prompt Skeleton

The PR #233 audit prompt is a strong pattern. Future prompt-bundle audits should use this skeleton:

```markdown
You are an independent prompt-bundle auditor.

Goal:
Confirm whether the produced prompt bundle can be dispatched to implementation agents.
If any HIGH or CRITICAL defect exists, dispatch is blocked.

Inputs:
1. Prompt-production prompt used to create the bundle.
2. Phase plan and planning-session summary.
3. Governing methodology docs.
4. Every produced handoff, agent, two-step, reviewer, research, and closure prompt.
5. Current repo source-of-truth files referenced by the prompts.
6. Related issue/PR acceptance criteria.
7. Prior audit reports, but only after completing your own independent inspection.

Required checks:
1. Doctrine compliance.
2. Self-containedness and scope boundaries.
3. Current-repo fact verification.
4. Embedded-code coherence.
5. Pipeline and device-test sequencing.
6. Evidence consistency across section 6, section 7, section 8, PR body, and reviewer checklist.
7. Lint/drift scan.
8. Independent hot-take inspection for defects not listed above.

Output:
1. Verdict.
2. Summary table.
3. HIGH/CRITICAL findings.
4. MEDIUM/LOW findings.
5. Methodology feedback table.
6. Cross-audit reconciliation.
7. Dispatch recommendation.
8. Confidence statement.
```

Mandatory adversarial questions:

- What fails if the implementation agent follows this prompt literally?
- What evidence could look valid while proving the wrong binary, board, or version?
- Which snippets depend on declarations or helpers not yet visible at the point of insertion?
- Which instructions conflict with the scope boundary?
- Which required deliverables are hidden outside the PR or in section 9?
- Which facts were copied from memory instead of extracted from current repo state?
- Which defect class should become a producer rule or lint rule?

---

## 11. Producer-Prompt Changes Recommended

Update `prompts/handoff/phase7-batch-production-prompt-update.md` or its phase-agnostic successor with a mandatory final section:

```markdown
## Mandatory Post-Production Audit Gate

After producing the prompt bundle, STOP.
Do not dispatch any implementation prompt.
Open the prompt-bundle audit gate:
1. Run prompt lint.
2. Start at least three independent audits.
3. Fix all HIGH/CRITICAL findings.
4. Route every confirmed finding to prompt fix, methodology update, lint/tooling update, or explicit no-change rationale.
5. Run a final zero-HIGH verification.
6. Only then mark the bundle dispatch-ready.
```

Also add a producer self-report table:

| Check | Evidence |
|---|---|
| Board facts extracted from `CURRENT-STATE.md` | pasted table |
| YAML names extracted from provisioning scripts/profiles | pasted commands/output |
| Function signatures verified | grep outputs |
| Version-bump whitelist included | yes/no |
| Device coverage by board | table |
| section 9 contains only mechanical bookkeeping | yes/no |
| Prompt-code snippets reviewed for declaration order | yes/no and notes |

The producer self-report is not an independent audit, but it gives auditors a clear surface to verify.

---

## 12. Development-Process Changes Recommended

Add a new subsection to `Docs/development-process-guide.md` under Prompt Production:

```markdown
### Prompt-Bundle Audit Gate

Prompt bundles are executable artifacts. A prompt bundle is not dispatch-ready when the producer finishes it. It is dispatch-ready only after independent prompt-bundle audits confirm zero HIGH/CRITICAL defects. Every confirmed prompt defect must be routed to a prompt fix and to a recurrence-prevention disposition: methodology update, producer-template update, lint/tooling update, tracked issue, or explicit no-change rationale.
```

For PRs that produce prompt bundles, add mandatory deliverables:

- prompt-bundle audit reports,
- cross-audit reconciliation,
- methodology feedback table,
- final zero-HIGH dispatch recommendation.

---

## 13. Writing-Guide Changes Recommended

Extend `Docs/writing-guide/methodology.md` with prompt-code-specific requirements:

- Placement directives are part of the code and must be checked.
- Code inserted into an existing function must only reference types/helpers already visible above that function, unless the prompt also instructs adding valid declarations first.
- Any numeric claim about size, timing, count, stack use, partition use, or retention must have a measurement step or live-source citation.
- PR body templates must mirror the required evidence in section 6.
- Historical prompt examples must not be reused without doctrine refresh.

---

## 14. Lint And Tooling Backlog

Candidate guardrails:

| Rule | Purpose | Notes |
|---|---|---|
| Active Rule 61 stale-delay check | Prevent `pdMS_TO_TICKS(1)` recurrence in active prompts | Must exclude historical/audit artifacts or scope by changed files |
| PR-body evidence coverage check | Flag C3-only wording when section 6 requires multiple boards | May need semantic/manual review |
| Curl timeout check | Prevent hung device-test prompts | Scope to board-IP curl lines |
| Version-bump order check | Ensure bump precedes first compile/upload/curl | Could be scriptable for active agent prompts |
| Scope whitelist check | Ensure version-bump prompts include 6 source + 6 artifact bullets | Scriptable bullet comparison |
| Generated-file edit warning | Detect prompts instructing direct edits to generated artifacts | Scriptable with generated-file table |
| Cross-prompt scope reference check | Preserve self-containedness | Existing lint class should be kept and expanded |

---

## 15. Recommended PR Topology

Use this topology for future prompt batches:

1. Producer opens a draft prompt-bundle PR.
2. Auditors add independent reports to the same PR or to linked audit PRs.
3. Prompt fixes land before dispatch.
4. Methodology/lint updates land in the same PR if they are small and directly preventive.
5. Larger methodology/lint changes are tracked in a follow-up issue and referenced in the dispatch decision.
6. The final PR body includes cross-audit reconciliation and a dispatch-ready statement.

If prompts already merged before audit, create a correction PR and mark the affected batch blocked until zero-HIGH verification is committed.

---

## 16. Acceptance Criteria For A Dispatch-Ready Prompt Bundle

- [ ] All produced prompts are present.
- [ ] Prompt lint passes or all warnings are accepted and documented.
- [ ] Board facts are extracted from current repo state.
- [ ] YAML names are verified from provisioning scripts or board profiles.
- [ ] Function signatures referenced by snippets are verified against live code.
- [ ] Scope boundaries include version-bump and pipeline artifacts where applicable.
- [ ] section 6, section 7, section 8, PR-body, reviewer checklist, and handoff require consistent evidence.
- [ ] Device tests cover all required boards or explicitly justify omissions.
- [ ] At least three independent audits are committed.
- [ ] All HIGH/CRITICAL findings are fixed and re-verified.
- [ ] Every finding has methodology/lint/template disposition.
- [ ] Cross-audit reconciliation is committed.
- [ ] Dispatch order and prerequisites are explicit.

---

## 17. Bottom Line

The prompt producer should be treated as a compiler, not an oracle. Its output is executable instruction code for another agent. That output needs independent verification before use.

The durable rule is:

```text
No non-trivial prompt bundle dispatch without independent zero-HIGH audit.
```

This would have caught the v7.7.1.0/v7.7.1.1 process drift before implementation and would have reduced the PR #233 correction loop by forcing prompt defects and methodology defects through the same controlled gate.

---

_End of Codex methodology audit._
