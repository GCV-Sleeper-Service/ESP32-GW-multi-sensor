# Plan of Record into the Repository — Consolidated Audit

_PR #236; documentation-only step; VERSION 7.7.1.1; no deployment._

## §1 Why

The restart plan lived outside the repository, so only one vendor's session could plan from it. PLAN-021 asked for a repository plan of record, entry points by role and an inventory-based archive. This PR records the operator's decisions and applies the supplied, verbatim edits. The current reviewer table remains in force until the review-runner PR merges.

## §2 Edit list

The §2 pre-implementation gate printed `§2 PASS`. CHECKPOINT A through G printed PASS. The queries below were evaluated by those unchanged checkpoint blocks or the supplemental read-only verification; the output column gives the verified result. No line of a moved file is quoted. The five supplied files were copied with the prescribed block, which produced no output.

| Item | Verify command | Observed output |
|---|---|---|
| 1.1 | `git diff --cached -M100% --name-status "$(git merge-base origin/main HEAD)"` and the per-move blob comparisons in CHECKPOINT A | 43 R100 moves; 43 identical blob IDs; `moved 43 files`; `CHECKPOINT A PASS` |
| 2.1a | `grep -cF -- 'Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md' README.md` | 1 |
| 2.1b | `grep -oF -- 'Docs/archive/completed-phases/phase-d-implementation-plan.md' README.md \| wc -l` | 2 |
| 2.1c | `grep -oF -- 'Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md' README.md \| wc -l` | 2 |
| 2.2a | `grep -oF -- 'Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md' Docs/architecture-overview.md \| wc -l` | 2 |
| 2.2b | `grep -cF -- 'Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/architecture-overview.md` | 1 |
| 2.2c | `grep -cF -- 'Docs/archive/completed-phases/phase-Y-current-state-inventory-sensor-history-v2.md' Docs/architecture-overview.md` | 1 |
| 2.2d | `grep -cF -- 'Docs/archive/completed-phases/phase-d-implementation-plan.md' Docs/architecture-overview.md` | 1 |
| 2.2e | `grep -cF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/architecture-overview.md` | 1 |
| 2.3 | `grep -oF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/decisions/AGG-ADR-001-satellite-history-storage.md \| wc -l` | 2 |
| 2.4 | `grep -cF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` | 1 |
| 2.5a | `grep -cF -- 'Docs/archive/completed-phases/phase-V-implementation-plan-addendum-v7.6.9.4.md' Docs/decisions/decision-log.md` | 1 |
| 2.5b | `grep -cF -- 'Docs/archive/session-logs/session-log-2026-05-06-v7.6.10.4.md' Docs/decisions/decision-log.md` | 1 |
| 2.6 | `grep -oF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/phase-7-review-and-rewrite.md \| wc -l` | 2 |
| 2.7 | `grep -oF -- '[Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md)' Docs/templates/prompt-audit-template.md \| wc -l` | 2 |
| 2.8 | `grep -cF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/v7.7-v7.8-persistence-architecture.md` | 1 |
| 2.9 | `grep -cF -- 'Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md` | 1 |
| 3.1 | `grep -cF -- '_Next action: R5, the tooling PR' CURRENT-STATE.md` | 1 |
| 3.2a | `grep -cF -- 'The order, the scope and the status of every step are in' CURRENT-STATE.md` | 1 |
| 3.2b | `grep -cF -- '1. **R5, R5r, R5a, R5b**' CURRENT-STATE.md` | 1 |
| 3.2c | `grep -cF -- '2. **Phase 7 Steps v7.7.1.2 to v7.7.1.4**' CURRENT-STATE.md` | 1 |
| 3.2d | `grep -cxF -- '3. **v7.7.1.5** — new board secrets (SEC-003).' CURRENT-STATE.md` | 1 |
| 3.2e | `grep -cF -- '4. **Phase 7 Steps v7.7.2.1 to v7.7.3.3**' CURRENT-STATE.md` | 1 |
| 3.2f | `grep -cF -- '5. **After v1.0**' CURRENT-STATE.md` | 1 |
| 3.3a | `grep -cF -- 'Docs/v7.7-implementation-plan.md' CURRENT-STATE.md` | 0 |
| 3.3b | `grep -cF -- 'Docs/feature-roadmap.md' CURRENT-STATE.md` | 0 |
| 3.3c | `grep -cF -- '_Documents that are history only are in' CURRENT-STATE.md` | 1 |
| 3.4a | `grep -cxF -- '## Planning Documents' CURRENT-STATE.md` | 1 |
| 3.4b | ``grep -cF -- 'supersedes `Docs/archive/planning-2026-05/v7.7-implementation-plan.md`' CURRENT-STATE.md`` | 1; the plan-of-record and planner entry rows are present |
| 3.4c | `grep -cF -- 'Docs/multi-phase-planning-session-summary.md' CURRENT-STATE.md` | 0 |
| 4.1a | `grep -cF -- '_Planning and prompt-producing sessions do not start here.' AGENTS.md` | 1 |
| 4.1b | `grep -cF -- '### Template Sensor Updates' AGENTS.md` | 1 |
| 4.1c | `grep -cxF -- 'timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' AGENTS.md` | 1 |
| 4.1d | `grep -cxF -- '- **Blocking:** Generated file edited, NVS on httpd stack, missing external_components, data corruption risk, a credential in the diff, the PR body or a comment' AGENTS.md` | 1 |
| 4.1e | `wc -l < AGENTS.md` | 195; replacement wording and absence of old wording verified by CHECKPOINT D |
| 4.2a | `sed -n 3p CLAUDE.md` | `@AGENTS.md` |
| 4.2b | `grep -cF -- 'The role of a Claude session in this repository follows its task (PLAN-026).' CLAUDE.md` | 1 |
| 4.3 | `wc -l < .github/copilot-instructions.md` | 5; pointer present and old rules absent |
| 4.4 | `grep -cF -- '- Never build a full CSV response in RAM:' .github/instructions/firmware.instructions.md` | 1 |
| 5.1a | ``grep -cF -- '11) After `gh pr ready`: post the comment `/gemini review` on the PR' Docs/development-process-guide.md`` | 1; both setup items inserted |
| 5.1b | `grep -cF -- 'Items 11 and 12 hold from R3c on (PLAN-027):' Docs/development-process-guide.md` | 1 |
| 5.2 | `grep -cxF -- 'timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' Docs/development-process-guide.md` | 1 |
| 5.3a | `grep -cF -- 'After the inline reviews the agent addresses the findings by itself' Docs/development-process-guide.md` | 1 |
| 5.3b | `grep -cF -- 'Claude Code is the fallback coding agent (PLAN-026).' Docs/development-process-guide.md` | 1 |
| 5.4 | ``grep -cF -- 'Mark the step'"'"'s row in the ladder of `Docs/plan-of-record.md`' Docs/development-process-guide.md`` | 1 |
| 5.5 | `grep -cF -- '2 — Plan of Record' Docs/development-process-guide.md` | 1 |
| 5.6 | ``grep -cF -- '`AGENTS.md` is the one source of rules for coding agents and reviewers.' Docs/development-process-guide.md`` | 1; old three-line list absent; current §2.4 reviewer table preserved |
| 5.7 | ``grep -cF -- 'The reviewers of today are in `Docs/development-process-guide.md` §2.4 (PLAN-019)' Docs/writing-guide/methodology.md`` | 1 |
| 6.1 | `grep -cxF -- '_Updated: 2026-11-16_' Docs/decisions/decision-log.md` | 1 |
| 6.2 | Unchanged CHECKPOINT F: nine PLAN-022–PLAN-030 rows, 54 table rows, original final line | `CHECKPOINT F PASS` |
| 7.1 | Prescribed five `cp`/`cmp` pairs from the agent prompt §6, Task Group 7 | No output; all five files byte-identical |

## §3 Review findings by severity

The PR was marked ready and `/gemini review` was posted at 2026-11-16 06:46:34 UTC. All three reviewers posted by 06:52:11 UTC, within the 30-minute limit. The reviewed implementation head is `81d01d309e79fc605e2cd7130f9def5f123cc345`.

| Reviewer | Evidence | Assessment and outcome |
|---|---|---|
| Gemini | [Implementation review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/236#pullrequestreview-5916033054), submitted 06:48:09 UTC | No findings and no inline comments. Its earlier prompt-only review is not used as implementation evidence. No fix warranted. |
| Codex | [Completed code-review summary](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/236#issuecomment-6909487014), completed 06:48:31 UTC on `81d01d3` | Summary reports `status: completed`, `has_any_findings: false`, `has_unresolved_findings: false`. No inline comments. No fix warranted. |
| Copilot | [Posted review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/236#pullrequestreview-5916063850), submitted 06:52:11 UTC | No findings and no inline comments. It explicitly could not complete the selected review tier because of model policy or plan restrictions. Its favorable summary is limited evidence, not a completed selected-tier review. No source fix warranted. |

Findings by severity: Blocking 0; High 0; Medium 0; Low 0; Cosmetic 0. No reviewer was absent. Copilot's incomplete selected-tier review remains a review-coverage limitation for the operator. No external review, approval or merge was started by this agent.

The implementation's required CI checks, `preflight-and-compile` and `prompt-lint`, both passed. The 22 file hashes in the operator's pre-dispatch gate comment all match the branch. This follow-up changes only this audit record; final PRE-PR and final-head CI results are recorded in the PR description.

## §4 Agent autonomous decisions

None. Scope, wording, archive destinations, decision rows and review rules are supplied by the operator. Invocation repairs changed no requirement or expected value.

## §5 Prompt Quality Score

- Fix cycles: 0.
- Checkpoint saves: 0 genuine repository mismatches.
- Preventable review findings: 0.
- Agent autonomous decisions: 0 (helpful 0 / harmful 0 / neutral 0).

The prescribed edits passed CHECKPOINT A through F without a source-edit repair. During setup the execution tool did not honor its `workdir` parameter; explicit `cd` fixed the checksum invocation. A manually transcribed §2 command used incorrect session-log dates; comparison with the verbatim prompt identified the invocation error, and the unchanged saved gate block printed `§2 PASS`. Neither event was a repository mismatch. Before the prompt's scope took effect, CI-safe provisioning changed only the generated dashboard header; that generated change was discarded before the two setup commits. No generated file is in this PR.

Known-tooling recovery in PRE-PR: not needed; the first run passed, including `playwright_manifest_spec: PASS`. No source fix followed review. The audit-only follow-up records participation and Copilot's selected-tier limitation. No unimplemented recommendation has been added by this execution; the operator's deferred work is recorded in the plan of record and decision rows.

## §6 Operator decisions recorded by this PR

| ID | Decision | Reason |
|---|---|---|
| PLAN-022 | A review runner for external review B: started by hand from `main`, three turns, Google's models, no stored key; its own tooling PR (R5r, MEDIUM) after R5 | A web chat cannot post its review, has no fixed protocol and leaves no record of what it read. A key file as a repository secret could be read by a pull request from a branch of this repository |
| PLAN-023 | Reviews A, B and C from the merge of the runner PR; A and C side by side, B last; if the runner cannot run, the step waits or review B is a Muse session | The method makes the structured review the last one. A Muse session adds a fourth model family. Gemini on the web cannot post the comment |
| PLAN-024 | The plan of record is `Docs/plan-of-record.md`; entry points by role; no forecast date is stored | The plan lived in one long document outside the repository. A planner or an agent of any vendor must be able to work from the repository alone |
| PLAN-025 | 18 documents and 25 session logs move to `Docs/archive/` as pure renames | They are history, not instruction. A pure rename shows no line of a moved file in the diff, and four of the moved files hold the old login |
| PLAN-026 | Claude Code is the fallback coding agent; review A is then a GPT model | The coding agent's subscription limit can stop a step. No external reviewer comes from the vendor of the agent that coded the step |
| PLAN-027 | The coding agent starts the inline review round itself; the stop rules are decided in advance | Both stops of PR #234 needed the operator, and neither was a real mismatch |
| PLAN-028 | CI fast path for documentation PRs, in place of the CI stub | A required check must report on every pull request. A stub that always passes would weaken it. A documentation PR needs no firmware compile |
| PLAN-029 | `AGENTS.md` is the one source of rules; the other instruction files point to it; each stays under 200 lines | The Copilot files had drifted: they still stated the BUG-082 rule that PR #235 replaced, and a severity scale that contradicted `AGENTS.md` |
| PLAN-030 | Who may run a planning session: any vendor and account with its own clone and a shell, under the planner rules, not on the build host; Claude models through other providers as overflow | The subscription limit stopped a planning session on 2026-11-14. On the build host the planner rules would rest on obedience alone |

## §7 Operator bookkeeping

**Status as of 2026-11-16 — development resumed after the May pause**

| Track | Status | Notes |
|---|---|---|
| Audit reports | Merged in PR #227 | 4 independent audits |
| §B upstream-doc fixes (B1–B8) | Merged in PR #232 | |
| Detection guardrail (lint L1–L7 + CI) | Merged in PR #231 | |
| §A produced-doc fixes (A1–A11) + §B9 | Merged in PR #233 | 4 rounds |
| PR #233 third-audit findings (H-1/M-1/M-2/L-1) | Not applied to the May prompts | Inputs to the Batch 2 re-production (PLAN-017) |
| HowTo v2.3.1 bound as method of record | Merged in PR #234 | PLAN-012, PLAN-017 |
| Restart housekeeping | Merged in PR #235 | BUG-082 status, fleet table, login out of the files agents read, decision rows |
| Plan of record into the repository | PR #236 | `Docs/plan-of-record.md`, entry points by role, archive of `Docs/`, instruction files, PLAN-022 to PLAN-030 |
| §C meta-prompt guardrails | OPEN — one tooling PR (R5) with the items that PLAN-017, PLAN-020 and PLAN-028 list | Runs before the Batch 2 re-production |
| §D phase-closure questions | DEFERRED — folded into the v7.7.3.3 closure prompt | |
| §E producer-prompt evolution | OPEN — producer contract and batch-production prompt v3.0 (R5a) | v3.0 must be shorter than v2.0 (PLAN-012) |

**Dispatch state: the May Batch 2 prompts (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) are NOT dispatched. They are re-produced under the method of record first. The order of all steps is in `Docs/plan-of-record.md`.**

The operator updates issue #228 after merge. This agent does not edit the issue, tag a release or merge.

## §8 Process metrics

| Metric | Value | Evidence |
|---|---|---|
| Producer sessions for this step's prompt | 3 | Operator supplied: inventory and runner design 2026-11-15; outline, verdicts and decision rows 2026-11-16; production, rehearsal and gate 2026-11-16. |
| Audit sessions for this step's prompt | 0 | Operator supplied: LOW tier, lint and one rehearsal inside the producer session. |
| Fix-cycle commits after the first review round | 0 | No reviewer findings required a fix; the follow-up commit completes this audit only. |
| Defects that escaped the prompt gates into agent execution | 0 | No prompt defect identified during execution or review; invocation repairs are recorded in §5. |
| Defects that escaped to devices | 0 | Documentation-only step; no deployment. |

Device testing: N/A — documentation-only step; no deployment. VERSION remains 7.7.1.1.
