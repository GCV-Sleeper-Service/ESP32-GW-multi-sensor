#!/usr/bin/env bash
# R5a.2 check file: every gate and checkpoint of the R5a.2 agent prompt method-fixes-2026-11-21-agent-prompt.md,
# so that the agent types no check (PLAN-031). It also writes the scope list and copies the two supplied files.
# The blocks inline and body read the pull request through `gh api` and change nothing (PLAN-043).
# Written 2026-11-21 by the planning session; do not edit it.
# The texts between "<<'END_OF_TEXT'" and "END_OF_TEXT" are the fenced texts of the prompt, copied by a tool.
#
#   bash /root/r5a2/method-fixes-2026-11-21-checks.sh <sec2 | scope | copy | A | B | C | D | prepr | inline <PR#> | body <PR#> [final]>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# It reads no board login and calls no board; inline and body use the GitHub login that gh already has. Temporary files go when it ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/r5a2
BRANCH=docs/r5a2-2026-11
BASE_COMMIT=d0a4414
GHREPO=GCV-Sleeper-Service/ESP32-GW-multi-sensor
ROUNDS="Inline|Review A"
P=prompts/handoff/phase7/method-fixes-2026-11-21
PC=prompts/producer-contract.md
V3=prompts/handoff/phase7-batch-production-prompt-v3.md
V2=prompts/handoff/phase7-batch-production-prompt-update.md
CAT=prompts/phase7/consolidated-audit-template-phase7.md
PG=Docs/development-process-guide.md
PSH=Docs/planner-start-here.md
PAT=Docs/templates/prompt-audit-template.md
CS=CURRENT-STATE.md
POR=Docs/plan-of-record.md
DL=Docs/decisions/decision-log.md
R5A1=prompts/handoff/phase7/contract-fixes-2026-11-21.md
OP=Docs/operator/R5a.2-method-fixes.md
RV=prompts/handoff/phase7/method-fixes-2026-11-21-review.md
NAME="${1:-}"
case "$NAME" in sec2) LABEL="§2" ;; prepr) LABEL="PRE-PR" ;; *) LABEL="$NAME" ;; esac
TMP="$(mktemp -d)" || { echo "⛔ CHECKPOINT FAILED - ${LABEL}: mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
fail() { echo "⛔ CHECKPOINT FAILED - ${LABEL}: $1"; exit 1; }
sha() { sha256sum < "$1" | cut -d' ' -f1; }
begins() { awk -v p="$1" 'index($0, p) == 1 { n++ } END { print n + 0 }' "$2"; }   # how many lines of $2 begin with $1
have() { local l; l="$(cat)"; test "$(grep -cxF -- "$l" "$1")" = "$2"; }       # $1 file, $2 count; the whole line on stdin
starts() { local l; l="$(cat)"; test "$(begins "$l" "$1")" = "$2"; }            # $1 file, $2 count; the line start on stdin
after() { # $1 file, $2 start of the anchor line; the lines that must follow it on stdin
  local want n got
  want="$(cat)"; n="$(awk -v p="$2" 'index($0, p) == 1 { print NR; exit }' "$1")"
  [ -n "$n" ] || return 1
  got="$(sed -n "$((n + 1)),$((n + $(printf '%s\n' "$want" | wc -l)))p" "$1")"
  [ "$got" = "$want" ]
}
cd "$REPO" 2>/dev/null || fail "repository path $REPO"

FILES=("$PC" "$V3" "$CAT" "$PG" "$PSH" "$PAT" "$CS" "$POR" "$DL" "$R5A1")
other_locale() { locale -a 2>/dev/null | grep -m1 -ixE 'en_US\.utf-?8'; }
fixtures() { LC_ALL="$1" bash tests/lint-prompts/run-fixtures.sh > "$TMP/fixtures.log" 2>&1 || { echo "run-fixtures.sh ended with exit $?"; return; }; tail -n 1 "$TMP/fixtures.log"; }
numstat() { git diff --numstat "$(git merge-base origin/main HEAD)" -- "$1" | awk '{print $1, $2}'; }
main_sha() { git show "$BASE_COMMIT:$1" | sha256sum | cut -d' ' -f1; }

b_sec2() {
  local p
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git merge-base --is-ancestor "$BASE_COMMIT" HEAD || fail "$BASE_COMMIT (PR #243) is not an ancestor of HEAD"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P-agent-prompt.md" "$SAVE/method-fixes-2026-11-21-agent-prompt.md" || fail "the committed prompt differs from $SAVE/method-fixes-2026-11-21-agent-prompt.md"
  cmp -s "$P-checks.sh" "$SAVE/method-fixes-2026-11-21-checks.sh" || fail "the committed check file differs from $SAVE/method-fixes-2026-11-21-checks.sh"
  test -d "$SAVE/files" || fail "$SAVE/files is missing: run the file check of the gate record"
  for t in python3 node npx git gh sha256sum comm locale env; do command -v "$t" >/dev/null || fail "the tool $t is missing"; done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' || fail "python3 is older than 3.12"
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing: preflight would skip the browser test"
  other_locale >/dev/null || fail "no en_US.UTF-8 locale (locale -a): the PRE-PR gate needs it"
  gh auth status >/dev/null 2>&1 || fail "gh is not logged in (gh auth status): the review round needs it"
  for p in "$OP" "$RV" "$P.md"; do
    test ! -e "$p" || fail "$p already exists"
  done
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 anchor 1: the line to replace"
3. The tier sets the producer audit: LOW, lint; MEDIUM, one external auditor, GPT Astra in its own ChatGPT session; HIGH, two from different model families, GPT Astra and Gemini 4 Neon in AI Studio (PLAN-037, PLAN-041). Each auditor works in a session of its own. [gate: audit]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 anchor 2: the line to replace"
4. Before each external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The producer checks each finding and fixes what holds. Stop at no new HIGH or MEDIUM, or after two internal rounds. The external audit stays (PLAN-040). [gate: audit]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 anchor 1: the line to replace"
3. The setup block is block A of process guide §2.2 with the branch, the PR title and the paths filled in, and one more step after the draft PR: it checks the SHA-256 of the prompt and of the check file and commits both, verbatim, as the first commit after the bootstrap commit. [gate: §2]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 anchor 2: the line to replace"
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 anchor 3: the line to replace"
8. Hand-over: the producer gives the operator the bundle, the setup block, the operator page and the gate record. The gate record names the model, the provider and the tool that produced the prompt, and the builder and the rehearsal script (PLAN-030, PLAN-033); its file check runs first on the build host and checks the SHA-256 of every file of the bundle, before the setup block runs. [gate: hand-over]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 1: the line to replace"
10. §8 starts the PR body with the heading `## Pre-Implementation Verification`, then Per-Item Verification, Acceptance Criteria, Files Modified (with the line of the scope gate) and Round Summary; a prompt that wants the Audit Gate Notice that `AGENTS.md` names gives its text. The last `PRE-PR PASS at <commit>` in the body names the head of the PR. [gate: CI; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 2: the line to replace"
12. Items 8 to 13 of the setup block of process guide §2.2 hold: edits by the file-edit tool, the repair of one's own failed command, one test at a time, the review round, the stops, and the check file. A known tooling defect gets the recovery that the prompt writes, once (PLAN-027). [judgment]
END_OF_TEXT
  starts "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 3: one line that begins with the anchor"
12. Items 8 to 
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.4 anchor 1: the line to replace"
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling or a shared state that the prompt leaves free. [gate: rehearsal; judgment]
END_OF_TEXT
  have "$CAT" 1 <<'END_OF_TEXT' || fail "1.5 anchor 1: the line to replace"
| Fix cycles | [0/1/2/...] | Times PR needed additional commits after review |
END_OF_TEXT
  starts "$CAT" 1 <<'END_OF_TEXT' || fail "1.5 anchor 2: one line that begins with the anchor"
_Defects that escaped the prompt gates into agent execution: the unique defects
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.6 anchor 1: the line to replace"
| Batch 2 | R5b | R5a.1 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 1: the line to replace"
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 2: the line to replace"
The operator gives the agent two things:
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 3: the line to replace"
7) Update PR description (use PR176-178 as reference)
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 4: the line to replace"
11) After `gh pr ready`: post the comment `/gemini review` on the PR; wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
END_OF_TEXT
  starts "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 5: one line that begins with the anchor"
13) Run every gate and checkpoint from the check file that the prompt names
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 6: the line to replace"
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 7: the line to replace"
Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 8: the line to replace"
| LOW | v7.7.1.2 | Lint; embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 9: the line to replace"
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 10: the line to replace"
| HIGH | v7.7.1.4, v7.7.2.2, v7.7.3.3 | Lint + an internal audit (PLAN-040), then two auditors from different model families (PLAN-037, PLAN-041), reconciled in one file; embedded code compiled on a scratch branch before dispatch | Prescriptive allowed |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 11: the line to replace"
2. **Fix cycles per step** — times a PR needed additional commits after review. Track average.
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 anchor 1: the line to replace"
6. Before an external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt, and applies the edits. The planning session checks each finding against the sources and fixes what holds. It stops when a round finds no new HIGH or MEDIUM, or after two internal rounds; the external audit stays (PLAN-040). Then, for a MEDIUM step, one independent auditor checks the bundle before dispatch: GPT Astra in its own ChatGPT session. For a HIGH step, two: GPT Astra and Gemini 4 Neon in AI Studio (PLAN-017, PLAN-037, PLAN-041). The planning session writes the audit prompt from `Docs/templates/prompt-audit-template.md`; the prompt names the parts of the bundle that are pending by design. The operator gives it and the bundle to the auditor in a session of its own and pastes the whole report back. The planning session checks each finding against the sources before it acts, fixes the bundle where the finding is right, rehearses again, and puts the audit prompt, the report and its dispositions into the audit file of the step, which the agent commits. When the fixes change the bundle, a new session audits the changed parts with a new prompt (template §7 step 8): its first turn without the earlier report, its second turn with the report and the dispositions. The planning session rates each finding by the severities of PLAN-037, with its evidence; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9, PLAN-037). The audit file of the step holds the prompts, the reports and the dispositions, in place of separate report files (template §7 step 5).
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 anchor 2: the line to replace"
7. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031). The bundle, the setup block, the gate record and the planning tools go to `steps/<step>/` of the planning repository; the gate record gives the SHA-256 of the bundle (PLAN-040).
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 anchor 3: the line to replace"
8. After the merge, close the step: read the merged pull request and its audit, and correct the next prompt at its gate.
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 anchor 4: the line to replace"
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
END_OF_TEXT
  starts "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 anchor 5: one line that begins with the anchor"
Keep working notes outside this repository, in the private planning repository
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 1: the line to replace"
- **Template version:** v1.4
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 2: the line to replace"
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint and no auditor, and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 3: the line to replace"
| LOW | Lint; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 4: the line to replace"
| MEDIUM | Lint + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 5: the line to replace"
| HIGH | Lint + two independent auditors from different model families; compile embedded code on a scratch branch | Two audit reports and one reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 6: the line to replace"
This section applies to HIGH only. LOW requires lint and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 7: the line to replace"
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 8: the line to replace"
   PLAN-040 (2026-11-21): before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; at most two internal rounds. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 9: the line to replace"
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 10: the line to replace"
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint and no audit:
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 11: the line to replace"
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
END_OF_TEXT
  starts "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 12: one line that begins with the anchor"
| v1.4 | 2026-11-21 |
END_OF_TEXT
  starts "$CS" 1 <<'END_OF_TEXT' || fail "3.1 anchor 1: one line that begins with the anchor"
| R5a review A (PR #241) |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 1: the line to replace"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.1**, the fixes of the producer contract from the reviews of R5a (PLAN-042). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  starts "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 2: one line that begins with the anchor"
| 6a | R5a.1 |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 3: the line to replace"
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 4 to 6 | Waiting |
END_OF_TEXT
  starts "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 4: one line that begins with the anchor"
- State after: version unchanged. R5b is produced under the fixed contract.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 5: the line to replace"
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 6: the line to replace"
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 7: the line to replace"
| v7.7.1.4 | HIGH | Prescriptive | Lint, two auditors from different model families reconciled in one file, and the compile gate in R7 |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 8: the line to replace"
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 9: the line to replace"
2. Dispatch. The operator pastes the setup block (process guide §2.2) and then the agent prompt, word for word. A step prompt closes its issue with `Fixes #N`: #214 for v7.7.1.2, #215 for v7.7.1.3, #216 for v7.7.1.4, #217 for v7.7.2.1, #218 for v7.7.2.2, #219 and #224 for v7.7.2.3, #220 for v7.7.3.1, #221 for v7.7.3.2, #222 for v7.7.3.3.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 10: the line to replace"
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). Section 7 shows the scheme.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 11: the line to replace"
5. Evidence check before the merge, by the operator. The PR body holds the gate outputs, the per-item verification and the device evidence. The branch holds the session log, the consolidated audit, `CURRENT-STATE.md`, the changelog entry, and this file with the step's row marked.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 12: the line to replace"
7. Post-merge check: `VERSION` shows the new version; the boards that the step flashed report it.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 13: the line to replace"
8. Metrics and step closure. The agent fills the process-metrics block of the consolidated audit. The planning session reads the merged PR and the audit, and corrects the next prompt at its gate.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 14: the line to replace"
    Y->>A: Dispatch: setup block, then the prompt
END_OF_TEXT
  starts "$DL" 1 <<'END_OF_TEXT' || fail "3.3 anchor 1: one line that begins with the anchor"
| 2026-11-21 | PLAN-042 |
END_OF_TEXT
  have "$R5A1" 1 <<'END_OF_TEXT' || fail "3.4 anchor 1: the line to replace"
| fix-cycle commits after the first review round | 2 |
END_OF_TEXT
  have "$R5A1" 1 <<'END_OF_TEXT' || fail "3.4 anchor 2: the line to replace"
| defects that escaped the prompt gates into agent execution | 0 |
END_OF_TEXT
  starts "$R5A1" 1 <<'END_OF_TEXT' || fail "3.4 anchor 3: one line that begins with the anchor"
| defects that escaped to devices | 0 |
END_OF_TEXT
  for p in "${FILES[@]}"; do
    test -f "$p" && test "$(sha "$p")" = "$(main_sha "$p")" || fail "$p differs from main at $BASE_COMMIT: the planning session renders the prompt again"
  done
  echo "§2 PASS"
}

b_scope() {
  local a; a="$(git rev-parse --git-path scope-allowed.txt)" || fail "git rev-parse"
  cat > "$a" <<'EOF'
prompts/producer-contract.md
prompts/handoff/phase7-batch-production-prompt-v3.md
prompts/phase7/consolidated-audit-template-phase7.md
Docs/development-process-guide.md
Docs/planner-start-here.md
Docs/templates/prompt-audit-template.md
CURRENT-STATE.md
Docs/plan-of-record.md
Docs/decisions/decision-log.md
prompts/handoff/phase7/contract-fixes-2026-11-21.md
Docs/operator/R5a.2-method-fixes.md
prompts/handoff/phase7/method-fixes-2026-11-21-review.md
prompts/handoff/phase7/method-fixes-2026-11-21-agent-prompt.md
prompts/handoff/phase7/method-fixes-2026-11-21-checks.sh
prompts/handoff/phase7/method-fixes-2026-11-21.md
EOF
  test "$(grep -c . "$a")" = "15" || fail "the scope list does not hold 15 paths"
  echo "scope list written: 15 paths"
}

copy_one() { # $1 path, $2 expected SHA-256 (the path is new on main)
  if [ -e "$1" ] && [ "$(sha "$1")" = "$2" ]; then return 0; fi
  test ! -e "$1" || fail "3.5 $1 exists and differs from the supplied file"
  test "$(sha "$SAVE/files/$1")" = "$2" || fail "3.5 $SAVE/files/$1 differs from the bundle: run the file check of the gate record"
  mkdir -p "$(dirname "$1")" && cp "$SAVE/files/$1" "$1" || fail "3.5 cannot copy $1"
  test "$(sha "$1")" = "$2" || fail "3.5 $1 differs from the supplied file after the copy"
}

b_copy() {
  copy_one "$OP" 160041b937a3f506be08464472a263767cb0ec8cc84d7b28bec0117954bea1e3
  copy_one "$RV" 018bab16cc71ba16b85437d6d897ca8a4d6af960df48ab1108cd9b334ea482c7
  echo "copied 2 files"
}

b_A() {
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.1 edit 1: the old line is still in prompts/producer-contract.md"
3. The tier sets the producer audit: LOW, lint; MEDIUM, one external auditor, GPT Astra in its own ChatGPT session; HIGH, two from different model families, GPT Astra and Gemini 4 Neon in AI Studio (PLAN-037, PLAN-041). Each auditor works in a session of its own. [gate: audit]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 edit 1: the new line, once, in prompts/producer-contract.md"
3. The tier sets the producer audit: LOW, lint and the internal round of rule 5.4; MEDIUM, the same and one external auditor, GPT Astra in its own ChatGPT session; HIGH, the same and two external auditors from different model families, GPT Astra and Gemini 4 Neon in AI Studio (PLAN-037, PLAN-041). Each auditor works in a session of its own. At every tier, code that the prompt carries is also compiled (rule 3.4). [gate: audit; gate: compile]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.1 edit 2: the old line is still in prompts/producer-contract.md"
4. Before each external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The producer checks each finding and fixes what holds. Stop at no new HIGH or MEDIUM, or after two internal rounds. The external audit stays (PLAN-040). [gate: audit]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 edit 2: the new line, once, in prompts/producer-contract.md"
4. At every tier, before dispatch and before any external audit, one internal sub-agent audits the bundle with an audit prompt from `Docs/templates/prompt-audit-template.md`, the external audit prompt where the tier has one, and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The producer checks each finding and fixes what holds. LOW and MEDIUM run one round; HIGH runs a second round when the first finds a new HIGH or MEDIUM, and never a third. The external audit stays (PLAN-040, PLAN-043). [gate: audit]
END_OF_TEXT
  test "$(grep -cF -- 'The tier sets the producer audit: LOW, lint;' "$PC")" = "0" || fail "1.1 the old wording is still in prompts/producer-contract.md: The tier sets the producer audit: LOW, lint;"
  test "$(grep -cF -- 'Before each external audit, one internal sub-agent' "$PC")" = "0" || fail "1.1 the old wording is still in prompts/producer-contract.md: Before each external audit, one internal sub-agent"
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.2 edit 1: the old line is still in prompts/producer-contract.md"
3. The setup block is block A of process guide §2.2 with the branch, the PR title and the paths filled in, and one more step after the draft PR: it checks the SHA-256 of the prompt and of the check file and commits both, verbatim, as the first commit after the bootstrap commit. [gate: §2]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 edit 1: the new line, once, in prompts/producer-contract.md"
3. The setup block is block A of process guide §2.2 with the branch, the PR title and the paths filled in, and two more steps: before the branch work, it unpacks the bundle from the operator's clone of the planning repository and runs the file check of every file of the bundle; after the draft PR, it checks the SHA-256 of the prompt and of the check file and commits both, verbatim, as the first commit after the bootstrap commit. It is a file in `steps/<step>/`: the operator pulls the planning repository on the build host and pastes the dispatch paragraph, which names the setup file and its SHA-256, and the agent checks that hash before it runs a line of the file (PLAN-043). [gate: §2; gate: hand-over; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.2 edit 2: the old line is still in prompts/producer-contract.md"
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 edit 2: the new line, once, in prompts/producer-contract.md"
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The operator posts the record as the first operator comment of the PR; an inline bot may post before it (PLAN-043). A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.2 edit 3: the old line is still in prompts/producer-contract.md"
8. Hand-over: the producer gives the operator the bundle, the setup block, the operator page and the gate record. The gate record names the model, the provider and the tool that produced the prompt, and the builder and the rehearsal script (PLAN-030, PLAN-033); its file check runs first on the build host and checks the SHA-256 of every file of the bundle, before the setup block runs. [gate: hand-over]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 edit 3: the new line, once, in prompts/producer-contract.md"
8. Hand-over: the producer commits the bundle, the setup file and the gate record to `steps/<step>/` of the planning repository and gives the operator, in chat, the dispatch paragraph: the path of the setup file and its SHA-256. The gate record names the model, the provider and the tool that produced the prompt, the harness and the model of the coding agent as the operator names them, and the builder and the rehearsal script (PLAN-030, PLAN-033, PLAN-043); it gives the two numbers that the agent copies into §8 of the record, producer sessions and audit sessions. The file check of the setup file checks the SHA-256 of every file of the bundle before the branch work. [gate: hand-over]
END_OF_TEXT
  test "$(grep -cF -- 'The record is the first comment of the PR.' "$PC")" = "0" || fail "1.2 the old wording is still in prompts/producer-contract.md: The record is the first comment of the PR."
  test "$(grep -cF -- 'the producer gives the operator the bundle, the setup block, the operator page and the gate record' "$PC")" = "0" || fail "1.2 the old wording is still in prompts/producer-contract.md: the producer gives the operator the bundle, the setup block, the operator page and the gate record"
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.3 edit 1: the old line is still in prompts/producer-contract.md"
10. §8 starts the PR body with the heading `## Pre-Implementation Verification`, then Per-Item Verification, Acceptance Criteria, Files Modified (with the line of the scope gate) and Round Summary; a prompt that wants the Audit Gate Notice that `AGENTS.md` names gives its text. The last `PRE-PR PASS at <commit>` in the body names the head of the PR. [gate: CI; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 edit 1: the new line, once, in prompts/producer-contract.md"
10. §8 starts the PR body with the heading `## Pre-Implementation Verification`, then Per-Item Verification, Acceptance Criteria, Files Modified (with the line of the scope gate) and Round Summary; a prompt that wants the Audit Gate Notice that `AGENTS.md` names gives its text. The Round Summary is a table with one row for each review round that the step runs, which begins with the name of the round (`| Inline |`, `| Review A |`, `| Review B |`, `| Review C |`) and gives the reviewers, the head that each reviewed, the findings and the outcome, or `pending` before the round. A ticked criterion says no `pending`. The last `PRE-PR PASS at <commit>` in the body names the head of the PR. [gate: CI; gate: checkpoint; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.3 edit 2: the old line is still in prompts/producer-contract.md"
12. Items 8 to 13 of the setup block of process guide §2.2 hold: edits by the file-edit tool, the repair of one's own failed command, one test at a time, the review round, the stops, and the check file. A known tooling defect gets the recovery that the prompt writes, once (PLAN-027). [judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 edit 2: the new line, once, in prompts/producer-contract.md"
12. Items 8 to 14 of the setup block of process guide §2.2 hold: edits by the file-edit tool, the repair of one's own failed command, one test at a time, the review round, the stops, the check file and the end of a round. A known tooling defect gets the recovery that the prompt writes, once (PLAN-027). [judgment]
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
12. Items 8 to 
END_OF_TEXT
  after "$PC" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "1.3 edit 3: the inserted lines must follow the anchor line, verbatim, in prompts/producer-contract.md"
13. The review round of §6: the agent edits the PR body with `gh api --method PATCH`, runs `gh pr ready` and posts `/gemini review`; it pushes nothing until the check block `inline <PR#>` prints `inline PASS`, which waits for the three inline reviewers, at most 30 minutes after that comment (after `inline WAIT` it runs the block again); then it assesses and fixes. Each round ends with one end-of-round step: the record, the row of the round in the Round Summary, the boxes of the criteria that hold, the PRE-PR block and its last line in the body, the check block `body <PR#>`, then one assessment comment whose first line names the agent and its model as its harness shows them. A finding about the agent's own name is answered, never fixed by renaming. The agent runs `inline` only until it prints `inline PASS`, never after its first push. The blocks `inline` and `body` are those of the last merged check file, with the rounds of the step, and the prompt names the logins of the inline reviewers and the marks that the blocks read (PLAN-043). [gate: checkpoint; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.4 edit 1: the old line is still in prompts/producer-contract.md"
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling or a shared state that the prompt leaves free. [gate: rehearsal; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.4 edit 1: the new line, once, in prompts/producer-contract.md"
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling, a shared state or any other choice that the prompt leaves free, such as an import. [gate: rehearsal; judgment]
END_OF_TEXT
  test "$(grep -cF -- 'a spelling or a shared state that the prompt leaves free' "$PC")" = "0" || fail "1.4 the old wording is still in prompts/producer-contract.md: a spelling or a shared state that the prompt leaves free"
  have "$CAT" 0 <<'END_OF_TEXT' || fail "1.5 edit 1: the old line is still in prompts/phase7/consolidated-audit-template-phase7.md"
| Fix cycles | [0/1/2/...] | Times PR needed additional commits after review |
END_OF_TEXT
  have "$CAT" 1 <<'END_OF_TEXT' || fail "1.5 edit 1: the new line, once, in prompts/phase7/consolidated-audit-template-phase7.md"
| Fix cycles | [0/1/2/...] | Review rounds that ended in at least one fix-cycle commit (PLAN-043) |
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
_Defects that escaped the prompt gates into agent execution: the unique defects
END_OF_TEXT
  after "$CAT" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "1.5 edit 2: the inserted lines must follow the anchor line, verbatim, in prompts/phase7/consolidated-audit-template-phase7.md"

_Fix-cycle commits after the first review round: the commits after the first review round that change a file because of a review finding, the fixes of the inline round's findings included; a commit that records a round and fixes no finding is not one. It is a count per step; HowTo §5.6 counts fix-cycle PRs per batch (PLAN-043)._
END_OF_TEXT
  test "$(grep -cF -- 'Times PR needed additional commits after review' "$CAT")" = "0" || fail "1.5 the old wording is still in prompts/phase7/consolidated-audit-template-phase7.md: Times PR needed additional commits after review"
  have "$V3" 0 <<'END_OF_TEXT' || fail "1.6 edit 1: the old line is still in prompts/handoff/phase7-batch-production-prompt-v3.md"
| Batch 2 | R5b | R5a.1 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.6 edit 1: the new line, once, in prompts/handoff/phase7-batch-production-prompt-v3.md"
| Batch 2 | R5b | R5a.2 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
END_OF_TEXT
  test "$(grep -cF -- '| R5a.1 merged |' "$V3")" = "0" || fail "1.6 the old wording is still in prompts/handoff/phase7-batch-production-prompt-v3.md: | R5a.1 merged |"
  test "$(numstat "$PC")" = "9 8" || fail "prompts/producer-contract.md must show 9 added and 8 deleted lines; it shows $(numstat "$PC")"
  test "$(numstat "$CAT")" = "3 1" || fail "prompts/phase7/consolidated-audit-template-phase7.md must show 3 added and 1 deleted lines; it shows $(numstat "$CAT")"
  test "$(numstat "$V3")" = "1 1" || fail "prompts/handoff/phase7-batch-production-prompt-v3.md must show 1 added and 1 deleted lines; it shows $(numstat "$V3")"
  test "$(wc -l < "$PC")" -le 150 || fail "1.1 $PC has more than 150 lines: $(wc -l < "$PC")"
  python3 -I - "$PC" <<'PYEOF' || fail "1.1 a numbered rule of the contract does not end with a tag in square brackets (see the line above)"
import re, sys
bad = [l for l in open(sys.argv[1], encoding="utf-8").read().split("\n") if re.match(r"^[0-9]+\. ", l) and not re.search(r"\[[^\[\]]+\]$", l)]
if bad:
    sys.exit("untagged rule: " + bad[0][:80])
PYEOF
  test "$(sed -n '/^## 7\. /,/^## 8\. /p' "$PC" | grep -oE '^[0-9]+\. ' | tr -d ' \n')" = "1.2.3.4.5.6.7.8.9.10.11.12.13." || fail "1.3 section 7 of $PC must number its rules 1 to 13, in order"
  test "$(wc -l < "$V3")" -lt "$(wc -l < "$V2")" || fail "1.6 $V3 has $(wc -l < "$V3") lines, not fewer than the $(wc -l < "$V2") of $V2"
  test "$(wc -c < "$V3")" -lt "$(wc -c < "$V2")" || fail "1.6 $V3 has $(wc -c < "$V3") bytes, not fewer than the $(wc -c < "$V2") of $V2"
  bash scripts/lint-prompts.sh "$PC" "$V3" "$CAT" > "$TMP/lint.log" 2>&1 || fail "lint in normal mode on $PC, $V3 and $CAT: $(grep -m2 -E 'ERROR|L[0-9]+' "$TMP/lint.log" | tr '\n' '|')"
  echo "CHECKPOINT A PASS"
}

b_B() {
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 1: the old line is still in Docs/development-process-guide.md"
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 1: the new line, once, in Docs/development-process-guide.md"
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs, and the producer and audit numbers of the step) is the operator's first comment on the PR; an inline bot may post before it (PLAN-043). A mismatch is fixed in the prompt, never by changing an expected value to fit.
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 2: the old line is still in Docs/development-process-guide.md"
The operator gives the agent two things:
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 2: the new line, once, in Docs/development-process-guide.md"
The operator pulls the planning repository on the build host and pastes the dispatch paragraph of the planning session: the path of the step's setup file in `steps/<step>/` and its SHA-256. The agent checks that hash and stops if it differs; then the setup file gives it two things (PLAN-043):
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 3: the old line is still in Docs/development-process-guide.md"
7) Update PR description (use PR176-178 as reference)
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 3: the new line, once, in Docs/development-process-guide.md"
7) Write the PR body to §8 of the prompt, and edit it with `gh api --method PATCH repos/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pulls/<PR#> -F body=@<file>`
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 4: the old line is still in Docs/development-process-guide.md"
11) After `gh pr ready`: post the comment `/gemini review` on the PR; wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 4: the new line, once, in Docs/development-process-guide.md"
11) After `gh pr ready`: post the comment `/gemini review` on the PR; run the check block `inline <PR#>` until it prints `inline PASS` (it waits for Copilot, Codex and Gemini, at most 30 minutes after the comment), and push nothing before it; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
13) Run every gate and checkpoint from the check file that the prompt names
END_OF_TEXT
  after "$PG" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "2.1 edit 5: the inserted lines must follow the anchor line, verbatim, in Docs/development-process-guide.md"
14) End every review round with the end-of-round step of the prompt: the record, the row of the round in the Round Summary, the criteria, the PRE-PR block and its last line in the body, the check block `body <PR#>`, then your assessment, whose first line names you and your model as your harness shows them
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 6: the old line is still in Docs/development-process-guide.md"
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 6: the new line, once, in Docs/development-process-guide.md"
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256. The block `inline` of item 11 and item 14 hold from R5a.2 on, the dispatch paragraph from R5b on (PLAN-043).
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 7: the old line is still in Docs/development-process-guide.md"
Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 7: the new line, once, in Docs/development-process-guide.md"
The coding agent runs an OpenAI Codex model, in the GitHub Copilot Chat agent of VS Code or in OpenAI's Codex agent; the gate record and the operator page name the harness and the model of each dispatch, and the agent names itself as its harness shows it (PLAN-043). Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout.
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 8: the old line is still in Docs/development-process-guide.md"
| LOW | v7.7.1.2 | Lint; embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 8: the new line, once, in Docs/development-process-guide.md"
| LOW | v7.7.1.2 | Lint + one internal audit round (PLAN-043); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 9: the old line is still in Docs/development-process-guide.md"
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 9: the new line, once, in Docs/development-process-guide.md"
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + one internal audit round (PLAN-040, PLAN-043), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 10: the old line is still in Docs/development-process-guide.md"
| HIGH | v7.7.1.4, v7.7.2.2, v7.7.3.3 | Lint + an internal audit (PLAN-040), then two auditors from different model families (PLAN-037, PLAN-041), reconciled in one file; embedded code compiled on a scratch branch before dispatch | Prescriptive allowed |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 10: the new line, once, in Docs/development-process-guide.md"
| HIGH | v7.7.1.4, v7.7.2.2, v7.7.3.3 | Lint + one or two internal audit rounds (PLAN-040, PLAN-043), then two auditors from different model families (PLAN-037, PLAN-041), reconciled in one file; embedded code compiled on a scratch branch before dispatch | Prescriptive allowed |
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 11: the old line is still in Docs/development-process-guide.md"
2. **Fix cycles per step** — times a PR needed additional commits after review. Track average.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 11: the new line, once, in Docs/development-process-guide.md"
2. **Fix cycles per step** — review rounds that ended in at least one fix-cycle commit, as the consolidated-audit template defines it (PLAN-043). Track average.
END_OF_TEXT
  test "$(grep -cF -- 'times a PR needed additional commits after review' "$PG")" = "0" || fail "2.1 the old wording is still in Docs/development-process-guide.md: times a PR needed additional commits after review"
  test "$(grep -cF -- 'The operator gives the agent two things:' "$PG")" = "0" || fail "2.1 the old wording is still in Docs/development-process-guide.md: The operator gives the agent two things:"
  test "$(grep -cF -- 'use PR176-178 as reference' "$PG")" = "0" || fail "2.1 the old wording is still in Docs/development-process-guide.md: use PR176-178 as reference"
  test "$(grep -cF -- 'wait up to 30 minutes for the inline reviews' "$PG")" = "0" || fail "2.1 the old wording is still in Docs/development-process-guide.md: wait up to 30 minutes for the inline reviews"
  test "$(grep -cF -- 'Lint + an internal audit (PLAN-040)' "$PG")" = "0" || fail "2.1 the old wording is still in Docs/development-process-guide.md: Lint + an internal audit (PLAN-040)"
  have "$PSH" 0 <<'END_OF_TEXT' || fail "2.2 edit 1: the old line is still in Docs/planner-start-here.md"
6. Before an external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt, and applies the edits. The planning session checks each finding against the sources and fixes what holds. It stops when a round finds no new HIGH or MEDIUM, or after two internal rounds; the external audit stays (PLAN-040). Then, for a MEDIUM step, one independent auditor checks the bundle before dispatch: GPT Astra in its own ChatGPT session. For a HIGH step, two: GPT Astra and Gemini 4 Neon in AI Studio (PLAN-017, PLAN-037, PLAN-041). The planning session writes the audit prompt from `Docs/templates/prompt-audit-template.md`; the prompt names the parts of the bundle that are pending by design. The operator gives it and the bundle to the auditor in a session of its own and pastes the whole report back. The planning session checks each finding against the sources before it acts, fixes the bundle where the finding is right, rehearses again, and puts the audit prompt, the report and its dispositions into the audit file of the step, which the agent commits. When the fixes change the bundle, a new session audits the changed parts with a new prompt (template §7 step 8): its first turn without the earlier report, its second turn with the report and the dispositions. The planning session rates each finding by the severities of PLAN-037, with its evidence; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9, PLAN-037). The audit file of the step holds the prompts, the reports and the dispositions, in place of separate report files (template §7 step 5).
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 edit 1: the new line, once, in Docs/planner-start-here.md"
6. At every tier, before dispatch and before any external audit, one internal sub-agent audits the bundle with an audit prompt from `Docs/templates/prompt-audit-template.md`, the external audit prompt where the tier has one, and executes it: it runs the gates, writes its own implementation to the contract of the prompt, and applies the edits. The planning session checks each finding against the sources and fixes what holds. LOW and MEDIUM run one round; HIGH runs a second round when the first finds a new HIGH or MEDIUM, and never a third; the external audit stays (PLAN-040, PLAN-043). Then, for a MEDIUM step, one independent auditor checks the bundle before dispatch: GPT Astra in its own ChatGPT session. For a HIGH step, two: GPT Astra and Gemini 4 Neon in AI Studio (PLAN-017, PLAN-037, PLAN-041). The planning session writes the audit prompt from `Docs/templates/prompt-audit-template.md`; the prompt names the parts of the bundle that are pending by design. The operator gives it and the bundle to the auditor in a session of its own and pastes the whole report back. The planning session checks each finding against the sources before it acts, fixes the bundle where the finding is right, rehearses again, and puts the audit prompt, the report and its dispositions into the audit file of the step, which the agent commits. When the fixes change the bundle, a new session audits the changed parts with a new prompt (template §7 step 8): its first turn without the earlier report, its second turn with the report and the dispositions. The planning session rates each finding by the severities of PLAN-037, with its evidence; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9, PLAN-037). The audit file of the step holds the prompts, the reports and the dispositions, in place of separate report files (template §7 step 5).
END_OF_TEXT
  have "$PSH" 0 <<'END_OF_TEXT' || fail "2.2 edit 2: the old line is still in Docs/planner-start-here.md"
7. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031). The bundle, the setup block, the gate record and the planning tools go to `steps/<step>/` of the planning repository; the gate record gives the SHA-256 of the bundle (PLAN-040).
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 edit 2: the new line, once, in Docs/planner-start-here.md"
7. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031). The bundle, the setup block, the gate record and the planning tools go to `steps/<step>/` of the planning repository; the gate record gives the SHA-256 of the bundle (PLAN-040), the harness and the model of the coding agent as the operator names them, and the producer and audit numbers. The operator pulls the planning repository on the build host; the planning session gives the dispatch paragraph in chat: the path of the setup file and its SHA-256 (PLAN-043).
END_OF_TEXT
  have "$PSH" 0 <<'END_OF_TEXT' || fail "2.2 edit 3: the old line is still in Docs/planner-start-here.md"
8. After the merge, close the step: read the merged pull request and its audit, and correct the next prompt at its gate.
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 edit 3: the new line, once, in Docs/planner-start-here.md"
8. After the merge, close the step at the next restart check: confirm in your own clone that `main` holds the merge and that the checks of the step's operator page for after the merge pass, read the merged pull request and its audit, and correct the next prompt at its gate. After the merge the operator only updates the checkout on the build host to `main` (PLAN-043).
END_OF_TEXT
  have "$PSH" 0 <<'END_OF_TEXT' || fail "2.2 edit 4: the old line is still in Docs/planner-start-here.md"
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 edit 4: the new line, once, in Docs/planner-start-here.md"
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that the coding agent or I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
Keep working notes outside this repository, in the private planning repository
END_OF_TEXT
  after "$PSH" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "2.2 edit 5: the inserted lines must follow the anchor line, verbatim, in Docs/planner-start-here.md"

At the end of its work, a planning session replaces "Read first" of the planning repository's `README.md` and ends it with the start prompt of the next session, filled in, with the open questions for the operator under "My decisions" (PLAN-043).
END_OF_TEXT
  test "$(grep -cF -- 'Before an external audit, one internal sub-agent' "$PSH")" = "0" || fail "2.2 the old wording is still in Docs/planner-start-here.md: Before an external audit, one internal sub-agent"
  test "$(grep -cF -- 'or after two internal rounds; the external audit stays (PLAN-040).' "$PSH")" = "0" || fail "2.2 the old wording is still in Docs/planner-start-here.md: or after two internal rounds; the external audit stays (PLAN-040)."
  test "$(grep -cF -- 'stays allowed in a command that I run.' "$PSH")" = "0" || fail "2.2 the old wording is still in Docs/planner-start-here.md: stays allowed in a command that I run."
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 1: the old line is still in Docs/templates/prompt-audit-template.md"
- **Template version:** v1.4
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 1: the new line, once, in Docs/templates/prompt-audit-template.md"
- **Template version:** v1.5
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 2: the old line is still in Docs/templates/prompt-audit-template.md"
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint and no auditor, and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 2: the new line, once, in Docs/templates/prompt-audit-template.md"
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint, one internal sub-agent round with an audit prompt from this template and no external auditor (PLAN-043), and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 3: the old line is still in Docs/templates/prompt-audit-template.md"
| LOW | Lint; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 3: the new line, once, in Docs/templates/prompt-audit-template.md"
| LOW | Lint + one internal round; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 4: the old line is still in Docs/templates/prompt-audit-template.md"
| MEDIUM | Lint + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 4: the new line, once, in Docs/templates/prompt-audit-template.md"
| MEDIUM | Lint + one internal round + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 5: the old line is still in Docs/templates/prompt-audit-template.md"
| HIGH | Lint + two independent auditors from different model families; compile embedded code on a scratch branch | Two audit reports and one reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 5: the new line, once, in Docs/templates/prompt-audit-template.md"
| HIGH | Lint + one or two internal rounds + two independent auditors from different model families; compile embedded code on a scratch branch | Two audit reports and one reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 6: the old line is still in Docs/templates/prompt-audit-template.md"
This section applies to HIGH only. LOW requires lint and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 6: the new line, once, in Docs/templates/prompt-audit-template.md"
This section applies to HIGH only. LOW requires lint, one internal round and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 7: the old line is still in Docs/templates/prompt-audit-template.md"
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 7: the new line, once, in Docs/templates/prompt-audit-template.md"
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the internal round of the note under step 4, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 8: the old line is still in Docs/templates/prompt-audit-template.md"
   PLAN-040 (2026-11-21): before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; at most two internal rounds. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 8: the new line, once, in Docs/templates/prompt-audit-template.md"
   PLAN-040 and PLAN-043 (2026-11-21): at every tier, before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; LOW and MEDIUM run one round, HIGH a second when the first finds a new HIGH or MEDIUM, and never a third. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 9: the old line is still in Docs/templates/prompt-audit-template.md"
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 9: the new line, once, in Docs/templates/prompt-audit-template.md"
10. Dispatch only after the tier's gate is satisfied: LOW lint passes and its internal round is done; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 10: the old line is still in Docs/templates/prompt-audit-template.md"
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint and no audit:
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 10: the new line, once, in Docs/templates/prompt-audit-template.md"
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint, one internal round and no external audit:
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 11: the old line is still in Docs/templates/prompt-audit-template.md"
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 11: the new line, once, in Docs/templates/prompt-audit-template.md"
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017, PLAN-043): every tier = one internal sub-agent round, HIGH at most two; LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| v1.4 | 2026-11-21 |
END_OF_TEXT
  after "$PAT" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "2.3 edit 12: the inserted lines must follow the anchor line, verbatim, in Docs/templates/prompt-audit-template.md"
| v1.5 | 2026-11-21 | R5a.2 (PLAN-043): one internal sub-agent round at every tier, LOW included, and HIGH at most two: the note on how to use this file, the tier table, §6, §7 (the note under step 4, the LOW paragraph and step 10), §8 and §9. |
END_OF_TEXT
  test "$(grep -cF -- 'LOW runs lint and no auditor' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: LOW runs lint and no auditor"
  test "$(grep -cF -- 'LOW requires lint and no audit report;' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: LOW requires lint and no audit report;"
  test "$(grep -cF -- 'LOW requires lint and no audit:' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: LOW requires lint and no audit:"
  test "$(grep -cF -- '- **Template version:** v1.4' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: - **Template version:** v1.4"
  test "$(numstat "$PG")" = "11 10" || fail "Docs/development-process-guide.md must show 11 added and 10 deleted lines; it shows $(numstat "$PG")"
  test "$(numstat "$PSH")" = "6 4" || fail "Docs/planner-start-here.md must show 6 added and 4 deleted lines; it shows $(numstat "$PSH")"
  test "$(numstat "$PAT")" = "12 11" || fail "Docs/templates/prompt-audit-template.md must show 12 added and 11 deleted lines; it shows $(numstat "$PAT")"
  test "$(sed -n '/^\*\*A) Setup instructions:\*\*$/,/^\*\*B) /p' "$PG" | grep -oE '^[0-9]+\)' | tr -d '\n')" = "1)2)3)4)5)6)7)8)9)10)11)12)13)14)" || fail "2.1 the setup block of $PG §2.2 must number its items 1 to 14, in order"
  echo "CHECKPOINT B PASS"
}

b_C() {
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| R5a review A (PR #241) |
END_OF_TEXT
  after "$CS" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.1 edit 1: the inserted lines must follow the anchor line, verbatim, in CURRENT-STATE.md"
| R5a.1 process review (2026-11-21) | A `.gemini/config.yaml` with `code_review.pull_request_opened.code_review: false`, so that Gemini reviews only after `/gemini review` and posts nothing when a draft PR opens (Google's page "Customize Gemini Code Assist behavior in GitHub", read 2026-11-21); one test PR must show that `/gemini review` still works. It changes PLAN-039, "No `.gemini/config.yaml`" | **Not implemented** — routed to a later tooling step that the operator schedules (PLAN-043) |
| R5a.1 process review (2026-11-21) | The required check `pr-body-check.yml` also checks what the block `body` of a check file checks (the last `PRE-PR PASS at <commit>` names the head; no ticked criterion says pending; one Round Summary row for each round), so that GitHub enforces the PR body, edits after the merge included | **Not implemented** — routed to a later tooling step that the operator schedules (PLAN-043) |
| R5a.2 production (2026-11-21) | `AGENTS.md`, "PR Description Standards", still says "Use PRs #176-178 as reference for description format"; those PRs have no Round Summary, and process guide §2.2 item 7 no longer names them. Until it changes, §8 of the step's prompt governs the PR body | **Not implemented** — routed to the next pull request that changes `AGENTS.md` (PLAN-043) |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 1: the old line is still in Docs/plan-of-record.md"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.1**, the fixes of the producer contract from the reviews of R5a (PLAN-042). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 1: the new line, once, in Docs/plan-of-record.md"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.2**, the method fixes from the reviews of R5a.1 (PLAN-043). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| 6a | R5a.1 |
END_OF_TEXT
  after "$POR" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.2 edit 2: the inserted lines must follow the anchor line, verbatim, in Docs/plan-of-record.md"
| 6b | R5a.2 | Method fixes from the reviews of R5a.1 (LOW, PLAN-043): an internal round at every tier, dispatch by a setup file, the checks `inline` and `body` of the review round | Dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 1 to 2 | Done: the pull request that adds PLAN-043 |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 3: the old line is still in Docs/plan-of-record.md"
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 4 to 6 | Waiting |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 3: the new line, once, in Docs/plan-of-record.md"
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.2 | Unchanged | 4 to 6 | Waiting |
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
- State after: version unchanged. R5b is produced under the fixed contract.
END_OF_TEXT
  after "$POR" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.2 edit 4: the inserted lines must follow the anchor line, verbatim, in Docs/plan-of-record.md"

### R5a.2: method fixes from the reviews of R5a.1 (documentation, LOW)

- Why: the reviews of PR #243 and the planner's process review of R5a.1 found that no check makes the agent wait for the inline round or keeps the PR body current, that the operator moves data that the planning session has already fixed, and four open questions of review A (PLAN-043).
- Scope: the coding agent of PLAN-019; one internal sub-agent round at every tier; dispatch by a setup file in the planning repository; the producer and audit numbers in the gate record; the Round Summary, the end-of-round step and the check blocks `inline` and `body`; the gate record as the operator's first comment; the after-merge check by the planning session; the filled start prompt at the end of "Read first"; review A's Q1 to Q4 of PR #243; the counts of the record of R5a.1; three rows of `CURRENT-STATE.md`.
- Who: the planning session writes the prompt, with one internal sub-agent round; the coding agent executes it; the inline round and review A run, reviews B and C do not.
- Done when: merged. It is the last method PR before R5b (risks 7 and 10).
- State after: version unchanged. R5b is produced under the changed contract, and its dispatch is the first by a setup file.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 5: the old line is still in Docs/plan-of-record.md"
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 5: the new line, once, in Docs/plan-of-record.md"
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint and one internal round; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 6: the old line is still in Docs/plan-of-record.md"
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 6: the new line, once, in Docs/plan-of-record.md"
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint, one internal round and one independent auditor; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 7: the old line is still in Docs/plan-of-record.md"
| v7.7.1.4 | HIGH | Prescriptive | Lint, two auditors from different model families reconciled in one file, and the compile gate in R7 |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 7: the new line, once, in Docs/plan-of-record.md"
| v7.7.1.4 | HIGH | Prescriptive | Lint, one or two internal rounds, two auditors from different model families reconciled in one file, and the compile gate in R7 |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 8: the old line is still in Docs/plan-of-record.md"
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 8: the new line, once, in Docs/plan-of-record.md"
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The operator posts the record as the first operator comment of the PR.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 9: the old line is still in Docs/plan-of-record.md"
2. Dispatch. The operator pastes the setup block (process guide §2.2) and then the agent prompt, word for word. A step prompt closes its issue with `Fixes #N`: #214 for v7.7.1.2, #215 for v7.7.1.3, #216 for v7.7.1.4, #217 for v7.7.2.1, #218 for v7.7.2.2, #219 and #224 for v7.7.2.3, #220 for v7.7.3.1, #221 for v7.7.3.2, #222 for v7.7.3.3.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 9: the new line, once, in Docs/plan-of-record.md"
2. Dispatch. The operator pulls the planning repository on the build host and pastes the dispatch paragraph; the agent checks the setup file by its SHA-256 and follows it, and the setup file gives it the agent prompt, word for word (process guide §2.2, PLAN-043). A step prompt closes its issue with `Fixes #N`: #214 for v7.7.1.2, #215 for v7.7.1.3, #216 for v7.7.1.4, #217 for v7.7.2.1, #218 for v7.7.2.2, #219 and #224 for v7.7.2.3, #220 for v7.7.3.1, #221 for v7.7.3.2, #222 for v7.7.3.3.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 10: the old line is still in Docs/plan-of-record.md"
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). Section 7 shows the scheme.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 10: the new line, once, in Docs/plan-of-record.md"
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). The agent waits for the inline round with the check block `inline` and ends each round with the check block `body` (PLAN-043). Section 7 shows the scheme.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 11: the old line is still in Docs/plan-of-record.md"
5. Evidence check before the merge, by the operator. The PR body holds the gate outputs, the per-item verification and the device evidence. The branch holds the session log, the consolidated audit, `CURRENT-STATE.md`, the changelog entry, and this file with the step's row marked.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 11: the new line, once, in Docs/plan-of-record.md"
5. Evidence check before the merge, by the operator: the check block `body <PR#> final` prints `body final PASS`. The PR body holds the gate outputs, the per-item verification and the device evidence. The branch holds the session log, the consolidated audit, `CURRENT-STATE.md`, the changelog entry, and this file with the step's row marked.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 12: the old line is still in Docs/plan-of-record.md"
7. Post-merge check: `VERSION` shows the new version; the boards that the step flashed report it.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 12: the new line, once, in Docs/plan-of-record.md"
7. Post-merge check: the operator updates the checkout on the build host to `main`, and the boards that the step flashed report the new version; the planning session checks `main` and `VERSION` at its next restart check (PLAN-043).
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 13: the old line is still in Docs/plan-of-record.md"
8. Metrics and step closure. The agent fills the process-metrics block of the consolidated audit. The planning session reads the merged PR and the audit, and corrects the next prompt at its gate.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 13: the new line, once, in Docs/plan-of-record.md"
8. Metrics and step closure. The agent fills the process-metrics block of the consolidated audit, with the producer and audit numbers of the gate record. The planning session reads the merged PR and the audit, and corrects the next prompt at its gate.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 14: the old line is still in Docs/plan-of-record.md"
    Y->>A: Dispatch: setup block, then the prompt
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 14: the new line, once, in Docs/plan-of-record.md"
    Y->>A: Dispatch paragraph: the setup file and its SHA-256
END_OF_TEXT
  test "$(grep -cF -- 'The last merged step is **R5a.1**' "$POR")" = "0" || fail "3.2 the old wording is still in Docs/plan-of-record.md: The last merged step is **R5a.1**"
  test "$(grep -cF -- 'The operator pastes the setup block (process guide §2.2)' "$POR")" = "0" || fail "3.2 the old wording is still in Docs/plan-of-record.md: The operator pastes the setup block (process guide §2.2)"
  test "$(grep -cF -- 'Dispatch: setup block, then the prompt' "$POR")" = "0" || fail "3.2 the old wording is still in Docs/plan-of-record.md: Dispatch: setup block, then the prompt"
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| 2026-11-21 | PLAN-042 |
END_OF_TEXT
  after "$DL" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.3 edit 1: the inserted lines must follow the anchor line, verbatim, in Docs/decisions/decision-log.md"
| 2026-11-21 | PLAN-043 | R5a.2 before R5b, and the method changes from the reviews of R5a.1 (operator decisions 2026-11-21, within PLAN-012 and PLAN-017; R5a.2 is the last method PR before R5b): one small LOW documentation PR, row 6b of the plan of record, with one internal sub-agent round, the inline round and review A. Coding agent (amends the coding-agent clause of PLAN-019; PLAN-026 stands): an OpenAI Codex model codes, in the GitHub Copilot Chat agent of VS Code or in OpenAI's Codex agent; the operator names the harness and the model of each dispatch, the gate record and the operator page state them, and the agent names itself as its harness shows it. Internal audit (amends PLAN-040 and the tier rule of PLAN-017): one internal sub-agent round at every tier before dispatch, LOW included; HIGH runs a second round when the first finds a new HIGH or MEDIUM, and never a third. Dispatch (amends PLAN-035): the bundle, the setup file and the gate record are in `steps/<step>/` of the planning repository; the operator pulls that repository on the build host and pastes the dispatch paragraph, the path of the setup file and its SHA-256; the agent checks the hash, then follows the file, which unpacks the bundle and runs its file check; the agent never pulls or pushes the planning repository. The operator posts the gate record as the first operator comment of the PR and so keeps the independent anchor; the gate record gives the producer and audit numbers, which the agent copies into §8 of the record; the operator comments only if they change. Review round: the agent waits for the inline round with the check block `inline` (at most 30 minutes after `/gemini review`), pushes nothing before it passes, ends each round with one end-of-round step closed by the check block `body`, and edits the PR body with `gh api --method PATCH`; before the merge `body <PR#> final` prints PASS. After the merge the operator only updates the checkout on the build host to `main`; the planning session checks `main` at its next restart check. Each planning session ends "Read first" of the planning repository with the filled start prompt of the next one. Answers to review A of PR #243 (comment 7067240679): Q1, rule 8.1 covers any choice that the prompt leaves free, an import included; Q2, rule 5.3 points to rule 3.4; Q3, the start prompt allows `curl -u "$ESP_USER:$ESP_PASS"` in a command of the coding agent or the operator, as rule 4.3 does; Q4, a fix-cycle commit is a commit after the first review round that changes a file because of a review finding, §5 of a record counts the rounds with one and §8 the commits, a count per step in place of the fix-cycle PRs of HowTo §5.6, which a batch counts. The record of R5a.1 counts 2 escaped defects (the `curl -u` wording; the harness label "Codex" of its operator page and review file) and 1 fix-cycle commit. A `.gemini/config.yaml` test and an extension of `pr-body-check.yml` wait for a later tooling step | `prompts/handoff/phase7/method-fixes-2026-11-21.md` §6 |
END_OF_TEXT
  have "$R5A1" 0 <<'END_OF_TEXT' || fail "3.4 edit 1: the old line is still in prompts/handoff/phase7/contract-fixes-2026-11-21.md"
| fix-cycle commits after the first review round | 2 |
END_OF_TEXT
  have "$R5A1" 1 <<'END_OF_TEXT' || fail "3.4 edit 1: the new line, once, in prompts/handoff/phase7/contract-fixes-2026-11-21.md"
| fix-cycle commits after the first review round | 1 |
END_OF_TEXT
  have "$R5A1" 0 <<'END_OF_TEXT' || fail "3.4 edit 2: the old line is still in prompts/handoff/phase7/contract-fixes-2026-11-21.md"
| defects that escaped the prompt gates into agent execution | 0 |
END_OF_TEXT
  have "$R5A1" 1 <<'END_OF_TEXT' || fail "3.4 edit 2: the new line, once, in prompts/handoff/phase7/contract-fixes-2026-11-21.md"
| defects that escaped the prompt gates into agent execution | 2 |
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| defects that escaped to devices | 0 |
END_OF_TEXT
  after "$R5A1" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.4 edit 3: the inserted lines must follow the anchor line, verbatim, in prompts/handoff/phase7/contract-fixes-2026-11-21.md"

Corrected in R5a.2 (PLAN-043; review A of PR #243, Q3 and Q4): two defects of the bundle escaped into agent execution. The start prompt of `Docs/planner-start-here.md` allowed `curl -u "$ESP_USER:$ESP_PASS"` only "in a command that I run", against rule 4.3; the operator page and the review file named the coding agent "Codex", where the operator ran the GitHub Copilot Chat agent with GPT-5.3-Codex. One fix-cycle commit: `8bfb315` fixed review A's F1 and F2; `7b9d03d` recorded the inline round early and fixed no finding.
END_OF_TEXT
  test "$(grep -cF -- '| fix-cycle commits after the first review round | 2 |' "$R5A1")" = "0" || fail "3.4 the old wording is still in prompts/handoff/phase7/contract-fixes-2026-11-21.md: | fix-cycle commits after the first review round | 2 |"
  test "$(grep -cF -- '| defects that escaped the prompt gates into agent execution | 0 |' "$R5A1")" = "0" || fail "3.4 the old wording is still in prompts/handoff/phase7/contract-fixes-2026-11-21.md: | defects that escaped the prompt gates into agent execution | 0 |"
  test "$(numstat "$CS")" = "3 0" || fail "CURRENT-STATE.md must show 3 added and 0 deleted lines; it shows $(numstat "$CS")"
  test "$(numstat "$POR")" = "21 12" || fail "Docs/plan-of-record.md must show 21 added and 12 deleted lines; it shows $(numstat "$POR")"
  test "$(numstat "$DL")" = "1 0" || fail "Docs/decisions/decision-log.md must show 1 added and 0 deleted lines; it shows $(numstat "$DL")"
  test "$(numstat "$R5A1")" = "4 2" || fail "prompts/handoff/phase7/contract-fixes-2026-11-21.md must show 4 added and 2 deleted lines; it shows $(numstat "$R5A1")"
  test "$(grep -c '^| ' "$DL")" = "67" || fail "3.3 decision log table rows (66 before, 67 after); found $(grep -c '^| ' "$DL")"
  test "$(tail -n 1 "$DL")" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "3.3 the last line of the log changed"
  test "$(sha "$OP")" = "160041b937a3f506be08464472a263767cb0ec8cc84d7b28bec0117954bea1e3" || fail "3.5 $OP differs from the supplied file"
  test "$(sha "$RV")" = "018bab16cc71ba16b85437d6d897ca8a4d6af960df48ab1108cd9b334ea482c7" || fail "3.5 $RV differs from the supplied file"
  test "$(sed -n '/^```mermaid$/,/^```$/p' "$OP" | grep -c ';')" = "0" || fail "3.5 a semicolon inside the Mermaid block of $OP"
  test "$(sed -n '/^```mermaid$/,/^```$/p' "$POR" | grep -c ';')" = "0" || fail "3.2 a semicolon inside a Mermaid block of $POR"
  echo "CHECKPOINT C PASS"
}

b_D() {
  test -f "$P.md" || fail "4.1 $P.md is missing"
  test "$(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')" = "## §1 ## §2 ## §3 ## §4 ## §5 ## §6 ## §7 ## §8 ## §9 " || fail "4.1 the record file must have the nine headings '## §1 ' to '## §9 ', each once, in order; found: $(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')"
  test "$(grep -c '<NN>' "$P.md")" = "0" || fail "4.1 <NN> is left in the record file"
  cat > "$TMP/table.txt" <<'END_OF_TEXT'
| ID | Decision | Reason |
|---|---|---|
| PLAN-043 | R5a.2 comes before R5b as its own small LOW documentation PR, the last method PR before R5b, with one internal sub-agent round, the inline round and review A. An OpenAI Codex model codes, in the GitHub Copilot Chat agent of VS Code or in OpenAI's Codex agent, and the gate record names the harness and the model of each dispatch. One internal sub-agent round at every tier; HIGH at most two. Dispatch by a setup file in the planning repository, which the operator pulls, and a dispatch paragraph with its SHA-256. The operator posts the gate record as the first operator comment, with the producer and audit numbers. The check blocks `inline` and `body` close the review round. The answers to review A's Q1 to Q4 of PR #243; the counts of the record of R5a.1 | Reviews A of PRs #241 and #243 found the same gaps that no check enforced: the wait for the inline round, the PR body after a round, the agent's name; the operator moved data that the planning session had already fixed; each internal round of R5a and R5a.1 found a MEDIUM that the rehearsal missed; review A's four questions of PR #243 were unrouted |
END_OF_TEXT
  cat > "$TMP/sentence.txt" <<'END_OF_TEXT'
This step closes no issue; no milestone changes, and the step has no tag.
END_OF_TEXT
  python3 -I - "$P.md" "$TMP/table.txt" "$TMP/sentence.txt" <<'PYEOF' || fail "4.1 the sections of the record file (see the line above)"
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
table = open(sys.argv[2], encoding="utf-8").read().rstrip("\n")
sentence = open(sys.argv[3], encoding="utf-8").read().rstrip("\n")
parts = re.split(r"(?m)^## §([1-9]) .*$", text)
sec = {int(parts[i]): parts[i + 1] for i in range(1, len(parts), 2)}
def need(c, m):
    if not c:
        sys.exit(m)
for n in (1, 3, 4, 5, 9):
    need(sec[n].strip(), "section %d is empty" % n)
rows2 = [[c.strip() for c in l.strip().strip("|").split("|")] for l in sec[2].split("\n") if l.strip().startswith("|")]
for item in ["1.%d" % i for i in range(1, 7)] + ["2.%d" % i for i in range(1, 4)] + ["3.%d" % i for i in range(1, 6)]:
    mine = [r for r in rows2 if r and r[0] == item]
    need(len(mine) == 1, "section 2 needs exactly one table row for item %s; found %d" % (item, len(mine)))
    need(len(mine[0]) >= 3 and all(mine[0][:3]), "section 2: the row of item %s needs its check and its observed output" % item)
need(table in sec[6], "section 6 must hold the table of item 4.1, verbatim")
need(sentence in sec[7].split("\n"), "section 7 must hold the sentence of item 4.1, verbatim, as one line")
for m in ("producer sessions for this step's prompt", "audit sessions for this step's prompt",
          "fix-cycle commits after the first review round", "defects that escaped the prompt gates into agent execution",
          "defects that escaped to devices"):
    rows = [l for l in sec[8].split("\n") if l.lower().startswith("| " + m)]
    need(len(rows) == 1, "section 8 must have one table row for the metric '%s'" % m)
    cells = [c.strip() for c in rows[0].strip().strip("|").split("|")]
    need(len(cells) >= 2 and cells[1], "section 8: the metric '%s' has no value" % m)
print("record sections: ok")
PYEOF
  test "$(git log --oneline -- "$P-agent-prompt.md" "$P-checks.sh" | wc -l)" = "1" || fail "4.0 the prompt and the check file must be in exactly one commit"
  echo "CHECKPOINT D PASS"
}

b_prepr() {
  local base loc out rc n
  local -a f
  git fetch origin || fail "git fetch"
  python3 scripts/scope-gate.py --allowed "$(git rev-parse --git-path scope-allowed.txt)" --target origin/main \
    || { rc=$?; echo "PRE-PR GATE FAILED (scope-gate exit $rc) - STOP"; exit "$rc"; }
  test -z "$(git status --porcelain)" || fail "uncommitted changes: commit before this gate"
  base="$(git merge-base origin/main HEAD)" || fail "merge-base"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^M')" = "10" || fail "expected 10 changed files; found $(git diff --name-status --no-renames "$base" HEAD | grep -c '^M')"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^A')" = "5" || fail "expected 5 new files; found $(git diff --name-status --no-renames "$base" HEAD | grep -c '^A')"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -vc '^[MA]')" = "0" || fail "a file was deleted or changed its type"
  test -z "$(git diff --name-only "$base" HEAD -- firmware src config dashboard partitions scripts tests .github .gemini package.json package-lock.json AGENTS.md CLAUDE.md)" || fail "a firmware, dashboard, script, test, workflow, instruction, style-guide or package file changed"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
  cmp -s "$P-agent-prompt.md" "$SAVE/method-fixes-2026-11-21-agent-prompt.md" || fail "the committed prompt differs from the saved one"
  cmp -s "$P-checks.sh" "$SAVE/method-fixes-2026-11-21-checks.sh" || fail "the committed check file differs from the saved one"
  ( b_A ) || exit 1
  ( b_B ) || exit 1
  ( b_C ) || exit 1
  ( b_D ) || exit 1
  mapfile -t f < <(git diff --name-only --no-renames --diff-filter=d "$base" HEAD -- prompts)
  bash scripts/lint-prompts.sh --baseline origin/main "${f[@]}" || fail "lint of the prompt files of this PR"
  mapfile -t f < <(git diff --name-only --no-renames --diff-filter=d "$base" HEAD)
  bash scripts/lint-prompts.sh "${f[@]}" > "$TMP/lint.log" 2>&1; rc=$?
  n="$(grep -c 'L11' "$TMP/lint.log")"
  test "$n" = "0" || fail "rule L11 finds a login literal in a changed file ($n lines)"
  test "$rc" = "0" || fail "lint of the changed files ended with exit $rc: $(grep -m2 -E 'ERROR|L[0-9]+' "$TMP/lint.log" | tr '\n' '|')"
  loc="$(other_locale)" || fail "no en_US.UTF-8 locale"
  test "$(fixtures C.UTF-8)" = "lint fixtures: 13 passed, 0 failed" || fail "lint fixtures in C.UTF-8"
  test "$(fixtures "$loc")" = "lint fixtures: 13 passed, 0 failed" || fail "lint fixtures in $loc"
  out="$(bash tests/scope-gate/run-tests.sh 2>&1)" && test "$(tail -n 1 <<< "$out")" = "scope-gate cases: 2 passed, 0 failed" || fail "scope-gate cases"
  bash scripts/preflight.sh || fail "preflight"
  test -z "$(git status --porcelain)" || fail "preflight changed files in the tree: $(git status --porcelain | tr '\n' ' ')"
  echo "PRE-PR PASS at $(git rev-parse HEAD)"
}

# --- review round: the blocks inline and body (PLAN-043) ---
# They read the PR through `gh api` and change nothing. GHREPO and ROUNDS are set at the top of the file.

b_inline() { # inline <PR#>: waits for the three inline reviewers, at most 5 minutes per run and 30 minutes in all
  local pr="${1:-}" t0 now out rc
  [[ "$pr" =~ ^[0-9]+$ ]] || fail "usage: inline <PR#>"
  t0="$(date -u +%s)" || fail "date"
  while :; do
    gh api "repos/$GHREPO/pulls/$pr" > "$TMP/pull.json" 2> "$TMP/gh.err" \
      && gh api "repos/$GHREPO/pulls/$pr/reviews?per_page=100" > "$TMP/reviews.json" 2>> "$TMP/gh.err" \
      && gh api "repos/$GHREPO/issues/$pr/comments?per_page=100" > "$TMP/comments.json" 2>> "$TMP/gh.err" \
      || fail "gh api cannot read PR #$pr: $(head -c 200 "$TMP/gh.err" | tr '\n' ' ')"
    now="$(date -u +%s)" || fail "date"
    out="$(python3 -I - "$TMP" "$now" <<'PYEOF'
import json, re, sys
from datetime import datetime, timezone
d, now = sys.argv[1], int(sys.argv[2])
pull = json.load(open(d + "/pull.json", encoding="utf-8"))
reviews = json.load(open(d + "/reviews.json", encoding="utf-8"))
comments = json.load(open(d + "/comments.json", encoding="utf-8"))
def t(s):
    return int(datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())
def who(x):
    return (x.get("user") or {}).get("login", "")
if pull.get("draft"):
    print("the PR is still a draft: run gh pr ready first"); sys.exit(2)
starts = [t(c["created_at"]) for c in comments if (c.get("body") or "").strip() == "/gemini review"]
if not starts:
    print("no comment '/gemini review' on the PR: post it first"); sys.exit(2)
if len(reviews) >= 100 or len(comments) >= 100:
    print("the PR has 100 or more reviews or comments: this block reads only the first 100"); sys.exit(2)
start, head = max(starts), pull["head"]["sha"]
posted, lines = {}, []
for r in reviews:
    if r.get("state") == "PENDING" or not r.get("submitted_at"):
        continue
    name = {"gemini-code-assist[bot]": "Gemini", "copilot-pull-request-reviewer[bot]": "Copilot",
            "chatgpt-codex-connector[bot]": "Codex"}.get(who(r))
    if not name or (name == "Gemini" and t(r["submitted_at"]) < start):
        continue
    if r.get("commit_id") != head:
        print("%s reviewed %s, not the head %s: a commit was pushed during the inline round" % (name, r.get("commit_id"), head)); sys.exit(2)
    note = " (incomplete: Copilot could not complete its review, PLAN-032)" if name == "Copilot" and "unable to complete" in (r.get("body") or "") else ""
    posted.setdefault(name, "%s: review %s on %s%s" % (name, r["id"], r["commit_id"][:7], note))
for c in comments:
    b = c.get("body") or ""
    if who(c) != "chatgpt-codex-connector[bot]":
        continue
    if "<!-- codex-review-receipt" in b:
        m = re.search(r"Reviewed commit:\*\* `([0-9a-f]{7,40})`", b)
        if m and not head.startswith(m.group(1)):
            print("Codex reviewed %s, not the head %s: a commit was pushed during the inline round" % (m.group(1), head)); sys.exit(2)
        posted.setdefault("Codex", "Codex: receipt comment %s" % c["id"])
    m = re.search(r"<!-- codex-review-state:v1 (\{.*?\}) -->", b)
    if m:
        try:
            cr = json.loads(m.group(1)).get("code_review") or {}
        except ValueError:
            cr = {}
        if cr.get("status") == "completed":
            if cr.get("commit_sha") and cr["commit_sha"] != head:
                print("Codex reviewed %s, not the head %s: a commit was pushed during the inline round" % (cr["commit_sha"], head)); sys.exit(2)
            posted.setdefault("Codex", "Codex: status comment %s, completed on %s" % (c["id"], (cr.get("commit_sha") or "")[:7]))
for n in ("Copilot", "Codex", "Gemini"):
    print(posted.get(n, "%s: not posted" % n))
left = 30 - (now - start) // 60
if len(posted) == 3:
    sys.exit(0)
if left <= 0:
    print("30 minutes have passed since '/gemini review'; the reviewers that did not post are named above"); sys.exit(0)
print("%d of 3 posted; %d minutes left" % (len(posted), left)); sys.exit(3)
PYEOF
)"; rc=$?
    case "$rc" in
      0) echo "$out"; echo "inline PASS"; return 0 ;;
      3) if [ $((now - t0)) -ge 300 ]; then echo "$out"; echo "inline WAIT: run this block again"; return 0; fi
         echo "inline: waiting, $(tail -n 1 <<< "$out")"
         sleep 30 ;;
      *) fail "$out" ;;
    esac
  done
}

b_body() { # body <PR#> [final]: the PR body after a round, or before the merge
  local pr="${1:-}" mode="${2:-}" out
  [[ "$pr" =~ ^[0-9]+$ ]] || fail "usage: body <PR#> [final]"
  [ -z "$mode" ] || [ "$mode" = "final" ] || fail "usage: body <PR#> [final]"
  gh api "repos/$GHREPO/pulls/$pr" > "$TMP/pull.json" 2> "$TMP/gh.err" \
    && gh api "repos/$GHREPO/issues/$pr/comments?per_page=100" > "$TMP/comments.json" 2>> "$TMP/gh.err" \
    || fail "gh api cannot read PR #$pr: $(head -c 200 "$TMP/gh.err" | tr '\n' ' ')"
  out="$(python3 -I - "$TMP" "$mode" "$ROUNDS" <<'PYEOF'
import json, re, sys
d, mode, rounds = sys.argv[1], sys.argv[2], sys.argv[3].split("|")
pull = json.load(open(d + "/pull.json", encoding="utf-8"))
comments = json.load(open(d + "/comments.json", encoding="utf-8"))
body, head, bad = (pull.get("body") or "").replace("\r\n", "\n"), pull["head"]["sha"], []
if len(comments) >= 100:
    bad.append("the PR has 100 or more comments: this block reads only the first 100")
heads = [h for h in re.findall(r"(?m)^## (.+?)\s*$", body)]
want = ["Pre-Implementation Verification", "Per-Item Verification", "Acceptance Criteria", "Files Modified", "Round Summary"]
got = [h for h in heads if h in want]
if got[:5] != want or len(got) != 5:
    bad.append("the body needs the headings ## " + ", ## ".join(want) + ", each once, in this order; found: " + ", ".join(got))
pre = re.findall(r"PRE-PR PASS at ([0-9a-f]{40})", body)
if not pre or pre[-1] != head:
    bad.append("the last 'PRE-PR PASS at <commit>' of the body is %s, not the head %s" % (pre[-1] if pre else "missing", head))
for l in body.split("\n"):
    if re.match(r"^\s*[-*] \[[xX]\]", l) and "pending" in l.lower():
        bad.append("a ticked criterion says pending: " + l.strip()[:120])
    if mode == "final" and re.match(r"^\s*[-*] \[ \]", l):
        bad.append("a criterion is not ticked: " + l.strip()[:120])
m = re.search(r"(?ms)^## Round Summary\s*$(.*?)(?=^## |\Z)", body)
rows = {}
for l in (m.group(1) if m else "").split("\n"):
    for r in rounds:
        if l.startswith("| %s |" % r):
            rows.setdefault(r, []).append(l)
posted = {"Inline": not pull.get("draft"),
          "Review A": any((c.get("body") or "").lstrip().startswith("## Review A") for c in comments),
          "Review B": any((c.get("body") or "").lstrip().startswith("## Review B") for c in comments),
          "Review C": any((c.get("body") or "").lstrip().startswith("## Review C") for c in comments)}
for r in rounds:
    if len(rows.get(r, [])) != 1:
        bad.append("the Round Summary needs one row that begins '| %s |'; found %d" % (r, len(rows.get(r, []))))
    elif "pending" in rows[r][0].lower() and (mode == "final" or posted.get(r)):
        bad.append("the Round Summary row of %s still says pending" % r)
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PYEOF
)" || fail "$(printf '%s' "$out" | tr '\n' '|')"
  [ "$mode" = "final" ] && echo "body final PASS" || echo "body PASS"
}

case "$NAME" in
  sec2) b_sec2 ;;
  scope) b_scope ;;
  copy) b_copy ;;
  A|B|C|D) "b_$NAME" ;;
  prepr) b_prepr ;;
  inline) b_inline "${2:-}" ;;
  body) b_body "${2:-}" "${3:-}" ;;
  *) echo "usage: bash $0 <sec2 | scope | copy | A | B | C | D | prepr | inline <PR#> | body <PR#> [final]>"; exit 2 ;;
esac
