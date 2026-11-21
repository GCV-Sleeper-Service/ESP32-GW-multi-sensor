#!/usr/bin/env bash
# R5a.1 check file: every gate and checkpoint of the R5a.1 agent prompt contract-fixes-2026-11-21-agent-prompt.md,
# so that the agent types no check (PLAN-031). It also writes the scope list and copies the two supplied files.
# Written 2026-11-21 by the planning session; do not edit it.
# The texts between "<<'END_OF_TEXT'" and "END_OF_TEXT" are the fenced texts of the prompt, copied by a tool.
#
#   bash /root/r5a1/contract-fixes-2026-11-21-checks.sh <sec2 | scope | copy | A | B | C | D | prepr>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# It reads no credential and calls no board. Temporary files go when it ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/r5a1
BRANCH=docs/r5a1-2026-11
BASE_COMMIT=d7740b5
P=prompts/handoff/phase7/contract-fixes-2026-11-21
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
R5A=prompts/handoff/phase7/producer-contract-2026-11-21.md
OP=Docs/operator/R5a.1-contract-fixes.md
RV=prompts/handoff/phase7/contract-fixes-2026-11-21-review.md
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

FILES=("$PC" "$V3" "$CAT" "$PG" "$PSH" "$PAT" "$CS" "$POR" "$DL" "$R5A")
other_locale() { locale -a 2>/dev/null | grep -m1 -ixE 'en_US\.utf-?8'; }
fixtures() { LC_ALL="$1" bash tests/lint-prompts/run-fixtures.sh > "$TMP/fixtures.log" 2>&1 || { echo "run-fixtures.sh ended with exit $?"; return; }; tail -n 1 "$TMP/fixtures.log"; }
numstat() { git diff --numstat "$(git merge-base origin/main HEAD)" -- "$1" | awk '{print $1, $2}'; }
main_sha() { git show "$BASE_COMMIT:$1" | sha256sum | cut -d' ' -f1; }

b_sec2() {
  local p
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git merge-base --is-ancestor "$BASE_COMMIT" HEAD || fail "$BASE_COMMIT (PR #241) is not an ancestor of HEAD"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P-agent-prompt.md" "$SAVE/contract-fixes-2026-11-21-agent-prompt.md" || fail "the committed prompt differs from $SAVE/contract-fixes-2026-11-21-agent-prompt.md"
  cmp -s "$P-checks.sh" "$SAVE/contract-fixes-2026-11-21-checks.sh" || fail "the committed check file differs from $SAVE/contract-fixes-2026-11-21-checks.sh"
  test -d "$SAVE/files" || fail "$SAVE/files is missing: run the file check of the gate record"
  for t in python3 node npx git sha256sum comm locale env; do command -v "$t" >/dev/null || fail "the tool $t is missing"; done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' || fail "python3 is older than 3.12"
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing: preflight would skip the browser test"
  other_locale >/dev/null || fail "no en_US.UTF-8 locale (locale -a): the PRE-PR gate needs it"
  for p in "$OP" "$RV" "$P.md"; do
    test ! -e "$p" || fail "$p already exists"
  done
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 anchor 1: the line to replace"
5. Every command that the producer gives the operator, in a page, a gate record or a chat, the producer ran first, exactly as written. A command that needs a board, the login or a cloud account, which the producer cannot run, is marked so where it is given and checked against the vendor's page. [gate: rehearsal; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 anchor 2: the line to replace"
3. Board values come only from the fleet table of `CURRENT-STATE.md` and the operator's latest `fleet` output. A step that runs on boards tests every board that its block in the plan of record names, the test board first where the block says so. [L4; L5; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 anchor 3: the line to replace"
1. Every edit is anchored by quoted text or by a symbol (a file and a function), never by a line number. The §2 gate checks that each anchor exists, as often as the prompt says. [gate: §2]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 anchor 4: the line to replace"
4. Code that a prompt prescribes and that ends in a compiled artifact is applied on a scratch branch from `origin/main`, assembled and compiled before dispatch, as plan of record R7 shows; the result goes into the gate record. For a HIGH step this waits until the step before it is on `main`. [gate: compile]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 anchor 1: the line to replace"
3. No login, key or token in any file of the bundle. No secret in a command argument: a check that needs a secret reads it from the environment inside one process; the login stays in `$ESP_USER` and `$ESP_PASS` (SEC-003). [L11; gate: PRE-PR; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 anchor 2: the line to replace"
4. An agent prompt never runs `git checkout main` or `git switch main`; it checks the branch instead. [L10]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 anchor 3: the line to replace"
4. §3 lists every path that the PR may change, with every file that canonical tools change as a side effect (`bash scripts/bump-version.sh` and the pipeline), taken from a rehearsal run, never from an older list. A rename lists both paths. The check file writes the list; the PRE-PR gate runs `scripts/scope-gate.py` on it. A statement of scope names the files it covers. [gate: PRE-PR]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 1: the line to replace"
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state, and no check depends on an order or a spelling that the prompt leaves free. [gate: rehearsal]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 2: the line to replace"
6. Tracking: a step that resolves an issue closes it with `Fixes #<n>` and moves it in `CURRENT-STATE.md`; a new architectural decision is a row of `Docs/decisions/decision-log.md` in the same PR; a new Critical Rule goes to `prompts/prompt-index-and-workflow.md`; the record lists candidate lessons and the operator gives them their numbers in `Docs/lessons/`; the operator updates the board measurement log when device tests show new baselines. [L9; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 3: the line to replace"
2. Negative tests: each gate and checkpoint stops when its condition is broken. Supplied tests fail with no implementation and with one that refuses everything; a test that only reads the source is named so in the test file; each defect that an audit found, put back into the reference one at a time, makes a test fail. [gate: rehearsal]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 anchor 4: the line to replace"
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, for a HIGH step the compile. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 anchor 1: the line to replace"
| Batch 2 | R5b | R5a merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 anchor 2: the line to replace"
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h | head -5
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 anchor 3: the line to replace"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h | head -5
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 anchor 4: the line to replace"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h | head -5
END_OF_TEXT
  starts "$CAT" 1 <<'END_OF_TEXT' || fail "1.5 anchor 1: one line that begins with the anchor"
_Completed after the last review round and committed before merge._
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 1: the line to replace"
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and for a HIGH step compiles any embedded code on a scratch branch. Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 2: the line to replace"
| LOW | v7.7.1.2 | Lint | Intent and acceptance criteria |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 3: the line to replace"
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037) | Intent and acceptance criteria; prescribe only interface contracts |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 anchor 4: the line to replace"
Transition (PLAN-017): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched. They are re-produced under the method of record and audited at their tier before dispatch; the compile of v7.7.1.4's embedded code runs once v7.7.1.3 is on `main`.
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 anchor 1: the line to replace"
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 1: the line to replace"
| LOW | Lint | No independent audit or reconciliation file |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 2: the line to replace"
| MEDIUM | Lint + one independent auditor | One audit report; no reconciliation file |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 3: the line to replace"
9. MEDIUM: confirm the single audit report has zero HIGH / CRITICAL findings; do not create a reconciliation file. HIGH: issue the reconciliation report (per §6) confirming zero HIGH / CRITICAL findings, and record a successful scratch-branch compile for any embedded code.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 4: the line to replace"
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed, with compile evidence for any embedded code. Every tier also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 5: the line to replace"
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint only; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file, and a compile gate for embedded code.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 6: the line to replace"
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint only; MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 7: the line to replace"
This section applies to HIGH only. LOW requires lint only; MEDIUM uses its single audit report without reconciliation (PLAN-017).
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 8: the line to replace"
For LOW, steps 4–9 are not applicable; lint and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 9: the line to replace"
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint only:
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 10: the line to replace"
- **Template version:** v1.3
END_OF_TEXT
  starts "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 anchor 11: one line that begins with the anchor"
| v1.3 | 2026-11-21 |
END_OF_TEXT
  starts "$CS" 1 <<'END_OF_TEXT' || fail "3.1 anchor 1: one line that begins with the anchor"
| R5a internal audit (2026-11-21) |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 1: the line to replace"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a**, the producer contract. The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  starts "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 2: one line that begins with the anchor"
| 6 | R5a |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 3: the line to replace"
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a | Unchanged | 4 to 6 | Waiting |
END_OF_TEXT
  starts "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 4: one line that begins with the anchor"
- Done when: both files are on `main` and lint passes on them.
END_OF_TEXT
  starts "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 5: one line that begins with the anchor"
  - a `.bin` size checkpoint against the OTA slot from v7.7.1.3 on;
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 6: the line to replace"
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 7: the line to replace"
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 8: the line to replace"
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, and checks that no fill-in is left. Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 anchor 9: the line to replace"
- As R5b, with the producer contract and batch prompt v3.0. Batch 3: v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM). Batch 4: v7.7.3.1 and v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH). One auditor for a MEDIUM step; two auditors from different model families for a HIGH step. The compile gate of a HIGH step waits until the step before it is on `main`. The bundles and their audits go into one documentation PR, with the batch metrics.
END_OF_TEXT
  starts "$DL" 1 <<'END_OF_TEXT' || fail "3.3 anchor 1: one line that begins with the anchor"
| 2026-11-21 | PLAN-041 |
END_OF_TEXT
  have "$R5A" 1 <<'END_OF_TEXT' || fail "3.4 anchor 1: the line to replace"
| Defects that escaped the prompt gates into agent execution | 1 |
END_OF_TEXT
  have "$R5A" 1 <<'END_OF_TEXT' || fail "3.4 anchor 2: the line to replace"
Producer and audit counts come from the operator's explicit metrics comment 7059068448 on PR #241. They confirm 1 and 0; internal producer-audit rounds are excluded per PLAN-037/PLAN-040. The earlier gate record had forecast the same values but was not the final metrics confirmation. The execution-defect count is the premature metrics/provenance choice in A L4. The seven fixed-text review findings are tracked in sections 3 and 5 separately from execution failures. No device was contacted.
END_OF_TEXT
  have "$R5A" 1 <<'END_OF_TEXT' || fail "3.4 anchor 3: the line to replace"
| A suggestion: automated Gemini style-guide sync | Reported for operator routing to a later tooling issue; no new gate added in this PR. |
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
prompts/handoff/phase7/producer-contract-2026-11-21.md
Docs/operator/R5a.1-contract-fixes.md
prompts/handoff/phase7/contract-fixes-2026-11-21-review.md
prompts/handoff/phase7/contract-fixes-2026-11-21-agent-prompt.md
prompts/handoff/phase7/contract-fixes-2026-11-21-checks.sh
prompts/handoff/phase7/contract-fixes-2026-11-21.md
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
  copy_one "$OP" 8d455899d280524fd915e978ca3b2ade2a8bc7de0ed974a08b44b5a72d4f7924
  copy_one "$RV" 7fbd6a62eea062c5c6512c7fa9b0c6791d31f1db123ae64ac17be4debc2fd4ff
  echo "copied 2 files"
}

b_A() {
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.1 edit 1: the old line is still in prompts/producer-contract.md"
5. Every command that the producer gives the operator, in a page, a gate record or a chat, the producer ran first, exactly as written. A command that needs a board, the login or a cloud account, which the producer cannot run, is marked so where it is given and checked against the vendor's page. [gate: rehearsal; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 edit 1: the new line, once, in prompts/producer-contract.md"
5. Every command that the producer gives the operator, in a page, a gate record or a chat, the producer ran first, exactly as written. A command that needs a board, the login or a cloud account, which the producer cannot run, is marked so where it is given and checked: a board command against `AGENTS.md` "Device Testing" and the operator's latest `fleet` output, any other command against the vendor's page. [gate: rehearsal; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.1 edit 2: the old line is still in prompts/producer-contract.md"
3. Board values come only from the fleet table of `CURRENT-STATE.md` and the operator's latest `fleet` output. A step that runs on boards tests every board that its block in the plan of record names, the test board first where the block says so. [L4; L5; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 edit 2: the new line, once, in prompts/producer-contract.md"
3. Board values come only from the fleet table of `CURRENT-STATE.md` and the operator's latest `fleet` output. A step that runs on boards tests every board that its block in the plan of record names, the test board first where the block says so. [L4 and L5 for the two known stale WROOM values; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.1 edit 3: the old line is still in prompts/producer-contract.md"
1. Every edit is anchored by quoted text or by a symbol (a file and a function), never by a line number. The §2 gate checks that each anchor exists, as often as the prompt says. [gate: §2]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 edit 3: the new line, once, in prompts/producer-contract.md"
1. Every edit is anchored by quoted text or by a symbol (a file and a function), never by a line number. The §2 gate checks that each anchor exists, as often as the prompt says. [gate: §2; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.1 edit 4: the old line is still in prompts/producer-contract.md"
4. Code that a prompt prescribes and that ends in a compiled artifact is applied on a scratch branch from `origin/main`, assembled and compiled before dispatch, as plan of record R7 shows; the result goes into the gate record. For a HIGH step this waits until the step before it is on `main`. [gate: compile]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.1 edit 4: the new line, once, in prompts/producer-contract.md"
4. Code that a prompt of any tier carries and that ends in a compiled artifact is applied on a scratch branch from `origin/main`, assembled and compiled before dispatch, as plan of record R7 shows (HowTo §5.3 item 5); the result goes into the gate record. When that code needs the step before it, the compile waits until that step is on `main` and runs in the pre-dispatch gate (rule 9.7); a HIGH step also has its compile-gate step in the plan of record, which waits until the step before it is on `main`. [gate: compile]
END_OF_TEXT
  test "$(grep -cF -- 'For a HIGH step this waits until the step before it is on `main`.' "$PC")" = "0" || fail "1.1 the old wording is still in prompts/producer-contract.md: For a HIGH step this waits until the step before it is on \`main\`."
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.2 edit 1: the old line is still in prompts/producer-contract.md"
3. No login, key or token in any file of the bundle. No secret in a command argument: a check that needs a secret reads it from the environment inside one process; the login stays in `$ESP_USER` and `$ESP_PASS` (SEC-003). [L11; gate: PRE-PR; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 edit 1: the new line, once, in prompts/producer-contract.md"
3. No login, key or token in any file of the bundle. No secret in a command argument: this covers the written text of every command and the checks of a check file. A check that needs a secret reads it from the environment inside one process; the login stays in `$ESP_USER` and `$ESP_PASS` (SEC-003), so `curl -u "$ESP_USER:$ESP_PASS"` of `AGENTS.md` stays allowed in a command that the agent or the operator runs. [L11; gate: PRE-PR; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.2 edit 2: the old line is still in prompts/producer-contract.md"
4. An agent prompt never runs `git checkout main` or `git switch main`; it checks the branch instead. [L10]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 edit 2: the new line, once, in prompts/producer-contract.md"
4. An agent prompt never runs `git checkout main` or `git switch main`; it checks the branch instead. [L10; gate: §2]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.2 edit 3: the old line is still in prompts/producer-contract.md"
4. §3 lists every path that the PR may change, with every file that canonical tools change as a side effect (`bash scripts/bump-version.sh` and the pipeline), taken from a rehearsal run, never from an older list. A rename lists both paths. The check file writes the list; the PRE-PR gate runs `scripts/scope-gate.py` on it. A statement of scope names the files it covers. [gate: PRE-PR]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.2 edit 3: the new line, once, in prompts/producer-contract.md"
4. §3 lists every path that the PR may change, with every file that canonical tools change as a side effect (`bash scripts/bump-version.sh` and the pipeline), taken from a rehearsal run, never from an older list. A rename lists both paths. The check file writes the list; the PRE-PR gate runs `scripts/scope-gate.py` on it. A statement of scope names the files it covers. [gate: rehearsal; gate: PRE-PR; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.3 edit 1: the old line is still in prompts/producer-contract.md"
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state, and no check depends on an order or a spelling that the prompt leaves free. [gate: rehearsal]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 edit 1: the new line, once, in prompts/producer-contract.md"
1. Every gate and checkpoint of the prompt is a block of its check file; the agent runs each by name and never types a check (PLAN-031). Each assertion comes from a sentence of the prompt; a check of a fenced text takes that text from the prompt by a tool; the check file holds no rule that the prompt does not state. No supplied test and no check depends on an order, a spelling or a shared state that the prompt leaves free. [gate: rehearsal; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.3 edit 2: the old line is still in prompts/producer-contract.md"
6. Tracking: a step that resolves an issue closes it with `Fixes #<n>` and moves it in `CURRENT-STATE.md`; a new architectural decision is a row of `Docs/decisions/decision-log.md` in the same PR; a new Critical Rule goes to `prompts/prompt-index-and-workflow.md`; the record lists candidate lessons and the operator gives them their numbers in `Docs/lessons/`; the operator updates the board measurement log when device tests show new baselines. [L9; judgment]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 edit 2: the new line, once, in prompts/producer-contract.md"
6. Tracking: a step that resolves an issue closes it with `Fixes #<n>` and moves it in `CURRENT-STATE.md`; a new architectural decision is a row of `Docs/decisions/decision-log.md` in the same PR; a new Critical Rule goes to `prompts/prompt-index-and-workflow.md`; the record lists candidate lessons, the agent writes each lesson entry in `Docs/lessons/` in the PR (so §3 lists `Docs/lessons/index.md` and the domain files that may take one), and the operator gives its final number before the merge, which the agent writes in; the operator updates the board measurement log when device tests show new baselines. [L9; judgment]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.3 edit 3: the old line is still in prompts/producer-contract.md"
2. Negative tests: each gate and checkpoint stops when its condition is broken. Supplied tests fail with no implementation and with one that refuses everything; a test that only reads the source is named so in the test file; each defect that an audit found, put back into the reference one at a time, makes a test fail. [gate: rehearsal]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 edit 3: the new line, once, in prompts/producer-contract.md"
2. Negative tests: each gate and checkpoint stops when its condition is broken. Every test of behaviour fails with no implementation and with one that refuses everything; a test that only reads the source is named so in the test file; each defect that an audit found, put back into the reference one at a time, makes a test fail. [gate: rehearsal]
END_OF_TEXT
  have "$PC" 0 <<'END_OF_TEXT' || fail "1.3 edit 4: the old line is still in prompts/producer-contract.md"
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, for a HIGH step the compile. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
END_OF_TEXT
  have "$PC" 1 <<'END_OF_TEXT' || fail "1.3 edit 4: the new line, once, in prompts/producer-contract.md"
7. Pre-dispatch gate, on the day of dispatch (process guide §2.1 item 6): the §2 block against `origin/main`, lint with exit 0 on the prompt file, no fill-in left, and the compile of rule 3.4 for a prompt of any tier that carries code ending in a compiled artifact. The record is the first comment of the PR. A mismatch is fixed in the prompt, never by changing an expected value. [gate: pre-dispatch]
END_OF_TEXT
  test "$(grep -cF -- 'Supplied tests fail with no implementation' "$PC")" = "0" || fail "1.3 the old wording is still in prompts/producer-contract.md: Supplied tests fail with no implementation"
  test "$(grep -cF -- 'for a HIGH step the compile' "$PC")" = "0" || fail "1.3 the old wording is still in prompts/producer-contract.md: for a HIGH step the compile"
  have "$V3" 0 <<'END_OF_TEXT' || fail "1.4 edit 1: the old line is still in prompts/handoff/phase7-batch-production-prompt-v3.md"
| Batch 2 | R5b | R5a merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 edit 1: the new line, once, in prompts/handoff/phase7-batch-production-prompt-v3.md"
| Batch 2 | R5b | R5a.1 merged | v7.7.1.2 (LOW), v7.7.1.3 (MEDIUM), v7.7.1.4 (HIGH) | Per-device structs, persist write path, restore engine and retention budget |
END_OF_TEXT
  have "$V3" 0 <<'END_OF_TEXT' || fail "1.4 edit 2: the old line is still in prompts/handoff/phase7-batch-production-prompt-v3.md"
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h | head -5
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 edit 2: the new line, once, in prompts/handoff/phase7-batch-production-prompt-v3.md"
grep -n 'handle_history_\|handle_api_v2_history_\|SegmentSnapshot' firmware/core/web-handler.h
END_OF_TEXT
  have "$V3" 0 <<'END_OF_TEXT' || fail "1.4 edit 3: the old line is still in prompts/handoff/phase7-batch-production-prompt-v3.md"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h | head -5
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 edit 3: the new line, once, in prompts/handoff/phase7-batch-production-prompt-v3.md"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Event' firmware/core/data-model.h  # no match: no output and exit 1; record "none"
END_OF_TEXT
  have "$V3" 0 <<'END_OF_TEXT' || fail "1.4 edit 4: the old line is still in prompts/handoff/phase7-batch-production-prompt-v3.md"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h | head -5
END_OF_TEXT
  have "$V3" 1 <<'END_OF_TEXT' || fail "1.4 edit 4: the new line, once, in prompts/handoff/phase7-batch-production-prompt-v3.md"
grep -n 'struct.*Segment\|struct.*Device\|struct.*Meta' firmware/core/nvs-persistence.h
END_OF_TEXT
  test "$(grep -cF -- 'head -5' "$V3")" = "0" || fail "1.4 the old wording is still in prompts/handoff/phase7-batch-production-prompt-v3.md: head -5"
  test "$(grep -cF -- '| R5a merged |' "$V3")" = "0" || fail "1.4 the old wording is still in prompts/handoff/phase7-batch-production-prompt-v3.md: | R5a merged |"
  cat > "$TMP/anchor" <<'END_OF_TEXT'
_Completed after the last review round and committed before merge._
END_OF_TEXT
  after "$CAT" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "1.5 edit 1: the inserted lines must follow the anchor line, verbatim, in prompts/phase7/consolidated-audit-template-phase7.md"

_Defects that escaped the prompt gates into agent execution: the unique defects of the step's bundle (prompt, check file, supplied texts, tests) that the producer's gates and audits missed and that were found after dispatch, each counted once; an error of the agent's own is not one of them (PLAN-042)._
END_OF_TEXT
  test "$(numstat "$PC")" = "11 11" || fail "prompts/producer-contract.md must show 11 added and 11 deleted lines; it shows $(numstat "$PC")"
  test "$(numstat "$V3")" = "4 4" || fail "prompts/handoff/phase7-batch-production-prompt-v3.md must show 4 added and 4 deleted lines; it shows $(numstat "$V3")"
  test "$(numstat "$CAT")" = "2 0" || fail "prompts/phase7/consolidated-audit-template-phase7.md must show 2 added and 0 deleted lines; it shows $(numstat "$CAT")"
  test "$(wc -l < "$PC")" -le 150 || fail "1.1 $PC has more than 150 lines: $(wc -l < "$PC")"
  python3 -I - "$PC" <<'PYEOF' || fail "1.1 a numbered rule of the contract does not end with a tag in square brackets (see the line above)"
import re, sys
bad = [l for l in open(sys.argv[1], encoding="utf-8").read().split("\n") if re.match(r"^[0-9]+\. ", l) and not re.search(r"\[[^\[\]]+\]$", l)]
if bad:
    sys.exit("untagged rule: " + bad[0][:80])
PYEOF
  test "$(wc -l < "$V3")" -lt "$(wc -l < "$V2")" || fail "1.4 $V3 has $(wc -l < "$V3") lines, not fewer than the $(wc -l < "$V2") of $V2"
  test "$(wc -c < "$V3")" -lt "$(wc -c < "$V2")" || fail "1.4 $V3 has $(wc -c < "$V3") bytes, not fewer than the $(wc -c < "$V2") of $V2"
  bash scripts/lint-prompts.sh "$PC" "$V3" "$CAT" > "$TMP/lint.log" 2>&1 || fail "lint in normal mode on $PC, $V3 and $CAT: $(grep -m2 -E 'ERROR|L[0-9]+' "$TMP/lint.log" | tr '\n' '|')"
  echo "CHECKPOINT A PASS"
}

b_B() {
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 1: the old line is still in Docs/development-process-guide.md"
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and for a HIGH step compiles any embedded code on a scratch branch. Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 1: the new line, once, in Docs/development-process-guide.md"
6. Pre-dispatch gate (PLAN-017): on the day a prompt is dispatched, a session that can run commands runs the prompt's §2 commands against `origin/main` and records each output beside its expected value, runs `bash scripts/lint-prompts.sh` on the prompt file (exit 0), confirms that every fill-in left for the operator (dates, pins, R1 values, `<LIVE>` markers) has been replaced, and, for a prompt of any tier that carries code ending in a compiled artifact, compiles that code on a scratch branch from `origin/main` (`prompts/producer-contract.md` rule 3.4, PLAN-042). Device values come only from the operator's latest `fleet` output. The record (date, `main` SHA, commands, outputs) is the PR's first comment. A mismatch is fixed in the prompt, never by changing an expected value to fit.
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 2: the old line is still in Docs/development-process-guide.md"
| LOW | v7.7.1.2 | Lint | Intent and acceptance criteria |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 2: the new line, once, in Docs/development-process-guide.md"
| LOW | v7.7.1.2 | Lint; embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria |
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 3: the old line is still in Docs/development-process-guide.md"
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037) | Intent and acceptance criteria; prescribe only interface contracts |
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 3: the new line, once, in Docs/development-process-guide.md"
| MEDIUM | v7.7.1.3, v7.7.2.1, v7.7.2.3, v7.7.3.1, v7.7.3.2 | Lint + an internal audit (PLAN-040), then one independent auditor (PLAN-037); embedded code compiled on a scratch branch before dispatch (PLAN-042) | Intent and acceptance criteria; prescribe only interface contracts |
END_OF_TEXT
  have "$PG" 0 <<'END_OF_TEXT' || fail "2.1 edit 4: the old line is still in Docs/development-process-guide.md"
Transition (PLAN-017): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched. They are re-produced under the method of record and audited at their tier before dispatch; the compile of v7.7.1.4's embedded code runs once v7.7.1.3 is on `main`.
END_OF_TEXT
  have "$PG" 1 <<'END_OF_TEXT' || fail "2.1 edit 4: the new line, once, in Docs/development-process-guide.md"
Transition (PLAN-017): the Batch 2 prompts of May 2026 (v7.7.1.2-v7.7.1.4) are not dispatched. They are re-produced under the method of record and audited at their tier before dispatch; the compile of v7.7.1.4's embedded code runs once v7.7.1.3 is on `main`. Embedded code of any tier that needs the step before it is compiled once that step is on `main`, in the pre-dispatch gate of §2.1 item 6 (PLAN-042).
END_OF_TEXT
  test "$(grep -cF -- 'for a HIGH step compiles any embedded code' "$PG")" = "0" || fail "2.1 the old wording is still in Docs/development-process-guide.md: for a HIGH step compiles any embedded code"
  have "$PSH" 0 <<'END_OF_TEXT' || fail "2.2 edit 1: the old line is still in Docs/planner-start-here.md"
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
END_OF_TEXT
  have "$PSH" 1 <<'END_OF_TEXT' || fail "2.2 edit 1: the new line, once, in Docs/planner-start-here.md"
Rules: every project claim cites a file, commit or issue; every hardware or platform claim cites a current source; give a confidence figure for each verdict. Run every command that you give me yourself first, exactly as written; a command that needs a board, my login or a cloud account, which you cannot run, you mark so and check: a board command against AGENTS.md "Device Testing" and my latest fleet output, any other against the vendor's page. Give git rev-parse one revision in each call. Never put a secret into a command argument: this covers the written text of a command and the checks of a check file; curl -u "$ESP_USER:$ESP_PASS" stays allowed in a command that I run. A check stops when its precondition fails. Credentials stay in my shell as $ESP_USER and $ESP_PASS and in the git-ignored firmware/secrets.yaml. When you want me to do something, give the commands in chat, and mark my actions with "You:". Write for me in short, simple sentences. Keep each reply short. Working notes go into the planning repository; what the next session needs goes into the product repository through the pull request of the step. At the end, replace the section "Read first" of the planning repository's README.md.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 1: the old line is still in Docs/templates/prompt-audit-template.md"
| LOW | Lint | No independent audit or reconciliation file |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 1: the new line, once, in Docs/templates/prompt-audit-template.md"
| LOW | Lint; compile embedded code on a scratch branch | No independent audit or reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 2: the old line is still in Docs/templates/prompt-audit-template.md"
| MEDIUM | Lint + one independent auditor | One audit report; no reconciliation file |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 2: the new line, once, in Docs/templates/prompt-audit-template.md"
| MEDIUM | Lint + one independent auditor; compile embedded code on a scratch branch | One audit report; no reconciliation file; compile evidence if code is embedded |
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 3: the old line is still in Docs/templates/prompt-audit-template.md"
9. MEDIUM: confirm the single audit report has zero HIGH / CRITICAL findings; do not create a reconciliation file. HIGH: issue the reconciliation report (per §6) confirming zero HIGH / CRITICAL findings, and record a successful scratch-branch compile for any embedded code.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 3: the new line, once, in Docs/templates/prompt-audit-template.md"
9. MEDIUM: confirm the single audit report has zero HIGH / CRITICAL findings; do not create a reconciliation file. HIGH: issue the reconciliation report (per §6) confirming zero HIGH / CRITICAL findings. Every tier: record a successful scratch-branch compile for any embedded code (PLAN-042).
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 4: the old line is still in Docs/templates/prompt-audit-template.md"
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed, with compile evidence for any embedded code. Every tier also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 4: the new line, once, in Docs/templates/prompt-audit-template.md"
10. Dispatch only after the tier's gate is satisfied: LOW lint passes; MEDIUM's single audit report is committed; HIGH's two audit reports and reconciliation are committed. Every tier has compile evidence for any embedded code (PLAN-042) and also passes the same-day pre-dispatch gate in `Docs/development-process-guide.md` §2.1 item 6.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 5: the old line is still in Docs/templates/prompt-audit-template.md"
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint only; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file, and a compile gate for embedded code.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 5: the new line, once, in Docs/templates/prompt-audit-template.md"
Producer sessions · audit sessions · fix-cycle PRs · defects escaped to agent execution · defects escaped to devices · verification:production session ratio. Tier rule (PLAN-017): LOW = lint; MEDIUM = one auditor, no reconciliation file; HIGH = two auditors from different model families, one reconciliation file; every tier = a compile gate for embedded code (PLAN-042).
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 6: the old line is still in Docs/templates/prompt-audit-template.md"
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint only; MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 6: the new line, once, in Docs/templates/prompt-audit-template.md"
> **How to use this file.** Use the producer-audit tier assigned under PLAN-017 in §0 below: LOW runs lint and no auditor, and every tier compiles its embedded code on a scratch branch (PLAN-042); MEDIUM uses this template for one auditor; HIGH uses it for two independent auditors from different model families, followed by reconciliation. For MEDIUM or HIGH, copy this template to `prompts/handoff/<phase>/<bundle>-audit-prompt-v<N>.md` and fill in every `<<…>>` placeholder before dispatch. Do NOT modify this template in place when running an audit — versioning is preserved here so methodology drift is traceable. To amend the template itself, increment the template version and append a CHANGELOG entry.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 7: the old line is still in Docs/templates/prompt-audit-template.md"
This section applies to HIGH only. LOW requires lint only; MEDIUM uses its single audit report without reconciliation (PLAN-017).
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 7: the new line, once, in Docs/templates/prompt-audit-template.md"
This section applies to HIGH only. LOW requires lint and no audit report; MEDIUM uses its single audit report without reconciliation (PLAN-017).
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 8: the old line is still in Docs/templates/prompt-audit-template.md"
For LOW, steps 4–9 are not applicable; lint and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 8: the new line, once, in Docs/templates/prompt-audit-template.md"
For LOW, steps 4 to 8 and the audit part of step 9 are not applicable; lint, the compile of step 9 and the project's same-day pre-dispatch gate still apply. For MEDIUM and HIGH, follow the applicable audit path below.
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 9: the old line is still in Docs/templates/prompt-audit-template.md"
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint only:
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 9: the new line, once, in Docs/templates/prompt-audit-template.md"
If the operator has explicitly recorded time pressure and accepted the residual risk **AND** the bundle is MEDIUM, its auditor may run a "minimum viable audit". LOW requires lint and no audit:
END_OF_TEXT
  have "$PAT" 0 <<'END_OF_TEXT' || fail "2.3 edit 10: the old line is still in Docs/templates/prompt-audit-template.md"
- **Template version:** v1.3
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.3 edit 10: the new line, once, in Docs/templates/prompt-audit-template.md"
- **Template version:** v1.4
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| v1.3 | 2026-11-21 |
END_OF_TEXT
  after "$PAT" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "2.3 edit 11: the inserted lines must follow the anchor line, verbatim, in Docs/templates/prompt-audit-template.md"
| v1.4 | 2026-11-21 | R5a.1 (PLAN-042): embedded code is compiled on a scratch branch before dispatch at every tier, not only HIGH: the note on how to use this file, the tier table, §6, §7 steps 9 and 10, §8 and §9. |
END_OF_TEXT
  test "$(grep -cF -- 'lint only' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: lint only"
  test "$(grep -cF -- 'reconciliation are committed, with compile evidence' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: reconciliation are committed, with compile evidence"
  test "$(grep -cF -- 'steps 4–9' "$PAT")" = "0" || fail "2.3 the old wording is still in Docs/templates/prompt-audit-template.md: steps 4–9"
  test "$(numstat "$PG")" = "4 4" || fail "Docs/development-process-guide.md must show 4 added and 4 deleted lines; it shows $(numstat "$PG")"
  test "$(numstat "$PSH")" = "1 1" || fail "Docs/planner-start-here.md must show 1 added and 1 deleted lines; it shows $(numstat "$PSH")"
  test "$(numstat "$PAT")" = "11 10" || fail "Docs/templates/prompt-audit-template.md must show 11 added and 10 deleted lines; it shows $(numstat "$PAT")"
  echo "CHECKPOINT B PASS"
}

b_C() {
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| R5a internal audit (2026-11-21) |
END_OF_TEXT
  after "$CS" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.1 edit 1: the inserted lines must follow the anchor line, verbatim, in CURRENT-STATE.md"
| R5a review A (PR #241) | A check in preflight or lint that the four parts of `.gemini/styleguide.md` still equal `AGENTS.md` word for word, as CHECKPOINT A of R5a compared them; today only contract rule 1.4 and PLAN-039 keep the two files in step, by reading (issue #242, comment 7060767358) | **Not implemented** — routed to a later tooling step that the operator schedules |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 1: the old line is still in Docs/plan-of-record.md"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a**, the producer contract. The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 1: the new line, once, in Docs/plan-of-record.md"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a.1**, the fixes of the producer contract from the reviews of R5a (PLAN-042). The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| 6 | R5a |
END_OF_TEXT
  after "$POR" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.2 edit 2: the inserted lines must follow the anchor line, verbatim, in Docs/plan-of-record.md"
| 6a | R5a.1 | Producer-contract fixes from the reviews of R5a, issue #242 (LOW, PLAN-042) | Dispatch, review and merge one documentation PR | R5a | Unchanged | 1 to 2 | Done: the pull request that fixes issue #242 |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 3: the old line is still in Docs/plan-of-record.md"
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a | Unchanged | 4 to 6 | Waiting |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 3: the new line, once, in Docs/plan-of-record.md"
| 7 | R5b | Batch 2 re-produced under the method of record: three bundles and their assumption audit, audited by tier | The auditor sessions; dispatch, review and merge one documentation PR | R5a.1 | Unchanged | 4 to 6 | Waiting |
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
- Done when: both files are on `main` and lint passes on them.
END_OF_TEXT
  after "$POR" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.2 edit 4: the inserted lines must follow the anchor line, verbatim, in Docs/plan-of-record.md"

### R5a.1: producer-contract fixes (documentation, LOW)

- Why: reviews A and B of PR #241 found seven defects in the fixed texts of R5a. The operator routed them to issue #242 and put this step before R5b (PLAN-042).
- Scope: the findings of issue #242 and of its comment 7060767358 in `prompts/producer-contract.md`, batch prompt v3.0 and the start prompt of `Docs/planner-start-here.md`; compile before dispatch for every prompt that carries code, in contract rules 3.4 and 9.7, process guide §2.1 and §3.1, the audit template, the blocks R5b, R9 and R13 and section 6 of this file; the reading of the escaped-defects metric in the consolidated-audit template and in §8 of the record of R5a; the routing of the Gemini style-guide sync in a row of `CURRENT-STATE.md` and in §9 of the record of R5a.
- Who: the planning session writes the prompt, with one internal sub-agent audit (PLAN-040); the coding agent executes it; the inline round and review A run, reviews B and C do not.
- Done when: merged, and issue #242 is closed.
- State after: version unchanged. R5b is produced under the fixed contract.
END_OF_TEXT
  cat > "$TMP/anchor" <<'END_OF_TEXT'
  - a `.bin` size checkpoint against the OTA slot from v7.7.1.3 on;
END_OF_TEXT
  after "$POR" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.2 edit 5: the inserted lines must follow the anchor line, verbatim, in Docs/plan-of-record.md"
- Compile before dispatch (PLAN-042): a prompt of any tier that carries code ending in a compiled artifact has that code compiled on a scratch branch first. If the prompt of v7.7.1.3 carries such code, its compile runs in its pre-dispatch gate, once v7.7.1.2 is on `main`; the compile of v7.7.1.4 runs in R7.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 6: the old line is still in Docs/plan-of-record.md"
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 6: the new line, once, in Docs/plan-of-record.md"
| v7.7.1.2 | LOW | Intent and acceptance criteria | Lint; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 7: the old line is still in Docs/plan-of-record.md"
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 7: the new line, once, in Docs/plan-of-record.md"
| v7.7.1.3 | MEDIUM | Intent and acceptance criteria; interface contracts prescribed | Lint and one independent auditor; the compile of any embedded code (PLAN-042) |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 8: the old line is still in Docs/plan-of-record.md"
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, and checks that no fill-in is left. Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 8: the new line, once, in Docs/plan-of-record.md"
1. Pre-dispatch gate (process guide §2.1 item 6). On the day of dispatch the planning session runs the §2 block of the prompt against `origin/main`, runs lint on the prompt file, checks that no fill-in is left, and compiles the code that the prompt carries and that ends in a compiled artifact (contract rule 3.4). Device values come only from the operator's latest fleet output. The record is the first comment of the PR.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.2 edit 9: the old line is still in Docs/plan-of-record.md"
- As R5b, with the producer contract and batch prompt v3.0. Batch 3: v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM). Batch 4: v7.7.3.1 and v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH). One auditor for a MEDIUM step; two auditors from different model families for a HIGH step. The compile gate of a HIGH step waits until the step before it is on `main`. The bundles and their audits go into one documentation PR, with the batch metrics.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.2 edit 9: the new line, once, in Docs/plan-of-record.md"
- As R5b, with the producer contract and batch prompt v3.0. Batch 3: v7.7.2.1 (MEDIUM), v7.7.2.2 (HIGH), v7.7.2.3 (MEDIUM). Batch 4: v7.7.3.1 and v7.7.3.2 (MEDIUM), v7.7.3.3 (HIGH). One auditor for a MEDIUM step; two auditors from different model families for a HIGH step. The compile gate of a HIGH step waits until the step before it is on `main`; a prompt of another tier that carries code compiles it in its pre-dispatch gate (PLAN-042). The bundles and their audits go into one documentation PR, with the batch metrics.
END_OF_TEXT
  test "$(grep -cF -- 'The last merged step is **R5a**, the producer contract.' "$POR")" = "0" || fail "3.2 the old wording is still in Docs/plan-of-record.md: The last merged step is **R5a**, the producer contract."
  cat > "$TMP/anchor" <<'END_OF_TEXT'
| 2026-11-21 | PLAN-041 |
END_OF_TEXT
  after "$DL" "$(cat "$TMP/anchor")" <<'END_OF_TEXT' || fail "3.3 edit 1: the inserted lines must follow the anchor line, verbatim, in Docs/decisions/decision-log.md"
| 2026-11-21 | PLAN-042 | R5a.1 before R5b, and the producer-contract fixes of issue #242 (operator decisions 2026-11-21, within PLAN-012 and PLAN-017: they complete the producer contract of the PLAN-017 list). The findings of reviews A and B on PR #241 against fixed texts (issue #242) are fixed, or recorded as a lesson, in one small LOW documentation PR, row 6a of the plan of record, before R5b; its producer audit is lint and one internal sub-agent round (PLAN-040), and its pull request gets the inline round and review A only; it writes no lesson entry. Compile before dispatch: every prompt, of any tier, that carries code ending in a compiled artifact has that code compiled on a scratch branch before dispatch, as HowTo §5.3 item 5 and PLAN-017 say, not only a HIGH prompt; code that needs the step before it compiles in the pre-dispatch gate once that step is on `main`, and a HIGH step keeps its compile-gate step; contract rules 3.4 and 9.7, process guide §2.1 item 6 and §3.1 and the audit template say the same. Lessons: the agent writes each lesson entry in `Docs/lessons/` in the PR, and the operator gives its final number before the merge. The process metric "defects that escaped the prompt gates into agent execution" counts the unique defects of a bundle (prompt, check file, supplied texts, tests) that the producer's gates and audits missed and that were found after dispatch; an error of the agent's own is not one of them; for R5a it is 7, not 1. Answers to review A of PR #241 (comment 7060381647): rule 1.5's exception stands, and a board command is checked against `AGENTS.md` "Device Testing" and the operator's latest `fleet` output; rule 4.3 covers the written text of a command and the checks of a check file, and `curl -u "$ESP_USER:$ESP_PASS"` stays allowed; PLAN-038 to PLAN-041 state the operator's decisions; an internal audit round is not an audit session (PLAN-040) | `prompts/handoff/phase7/contract-fixes-2026-11-21.md` §6 |
END_OF_TEXT
  have "$R5A" 0 <<'END_OF_TEXT' || fail "3.4 edit 1: the old line is still in prompts/handoff/phase7/producer-contract-2026-11-21.md"
| Defects that escaped the prompt gates into agent execution | 1 |
END_OF_TEXT
  have "$R5A" 1 <<'END_OF_TEXT' || fail "3.4 edit 1: the new line, once, in prompts/handoff/phase7/producer-contract-2026-11-21.md"
| Defects that escaped the prompt gates into agent execution | 7 |
END_OF_TEXT
  have "$R5A" 0 <<'END_OF_TEXT' || fail "3.4 edit 2: the old line is still in prompts/handoff/phase7/producer-contract-2026-11-21.md"
Producer and audit counts come from the operator's explicit metrics comment 7059068448 on PR #241. They confirm 1 and 0; internal producer-audit rounds are excluded per PLAN-037/PLAN-040. The earlier gate record had forecast the same values but was not the final metrics confirmation. The execution-defect count is the premature metrics/provenance choice in A L4. The seven fixed-text review findings are tracked in sections 3 and 5 separately from execution failures. No device was contacted.
END_OF_TEXT
  have "$R5A" 1 <<'END_OF_TEXT' || fail "3.4 edit 2: the new line, once, in prompts/handoff/phase7/producer-contract-2026-11-21.md"
Producer and audit counts come from the operator's explicit metrics comment 7059068448 on PR #241. They confirm 1 and 0; internal producer-audit rounds are excluded per PLAN-037/PLAN-040. The earlier gate record had forecast the same values but was not the final metrics confirmation. Corrected in R5a.1 (PLAN-042; issue #242, comment 7060767358): the execution-defect count is the seven fixed-text findings of issue #242 (review A's M1, M2, L1, L2, L3 and L5, and review B's check-file diagnostic), the unique defects of the bundle that the producer's gates and audits missed and that were found after dispatch. The count was 1 before, the premature metrics/provenance choice in A L4; that is an error of the agent's own, and section 4 records it. No device was contacted.
END_OF_TEXT
  have "$R5A" 0 <<'END_OF_TEXT' || fail "3.4 edit 3: the old line is still in prompts/handoff/phase7/producer-contract-2026-11-21.md"
| A suggestion: automated Gemini style-guide sync | Reported for operator routing to a later tooling issue; no new gate added in this PR. |
END_OF_TEXT
  have "$R5A" 1 <<'END_OF_TEXT' || fail "3.4 edit 3: the new line, once, in prompts/handoff/phase7/producer-contract-2026-11-21.md"
| A suggestion: automated Gemini style-guide sync | Routed by the operator to issue #242 (comment 7060767358); R5a.1 adds a row to "Unimplemented Recommendations" of `CURRENT-STATE.md` that routes it to a later tooling step (PLAN-042). |
END_OF_TEXT
  test "$(grep -cF -- '| Defects that escaped the prompt gates into agent execution | 1 |' "$R5A")" = "0" || fail "3.4 the old wording is still in prompts/handoff/phase7/producer-contract-2026-11-21.md: | Defects that escaped the prompt gates into agent execution | 1 |"
  test "$(grep -cF -- 'Reported for operator routing to a later tooling issue' "$R5A")" = "0" || fail "3.4 the old wording is still in prompts/handoff/phase7/producer-contract-2026-11-21.md: Reported for operator routing to a later tooling issue"
  test "$(numstat "$CS")" = "1 0" || fail "CURRENT-STATE.md must show 1 added and 0 deleted lines; it shows $(numstat "$CS")"
  test "$(numstat "$POR")" = "16 6" || fail "Docs/plan-of-record.md must show 16 added and 6 deleted lines; it shows $(numstat "$POR")"
  test "$(numstat "$DL")" = "1 0" || fail "Docs/decisions/decision-log.md must show 1 added and 0 deleted lines; it shows $(numstat "$DL")"
  test "$(numstat "$R5A")" = "3 3" || fail "prompts/handoff/phase7/producer-contract-2026-11-21.md must show 3 added and 3 deleted lines; it shows $(numstat "$R5A")"
  test "$(grep -c '^| ' "$DL")" = "66" || fail "3.3 decision log table rows (65 before, 66 after); found $(grep -c '^| ' "$DL")"
  test "$(tail -n 1 "$DL")" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "3.3 the last line of the log changed"
  test "$(sha "$OP")" = "8d455899d280524fd915e978ca3b2ade2a8bc7de0ed974a08b44b5a72d4f7924" || fail "3.5 $OP differs from the supplied file"
  test "$(sha "$RV")" = "7fbd6a62eea062c5c6512c7fa9b0c6791d31f1db123ae64ac17be4debc2fd4ff" || fail "3.5 $RV differs from the supplied file"
  test "$(sed -n '/^```mermaid$/,/^```$/p' "$OP" | grep -c ';')" = "0" || fail "3.5 a semicolon inside the Mermaid block of $OP"
  echo "CHECKPOINT C PASS"
}

b_D() {
  test -f "$P.md" || fail "4.1 $P.md is missing"
  test "$(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')" = "## §1 ## §2 ## §3 ## §4 ## §5 ## §6 ## §7 ## §8 ## §9 " || fail "4.1 the record file must have the nine headings '## §1 ' to '## §9 ', each once, in order; found: $(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')"
  test "$(grep -c '<NN>' "$P.md")" = "0" || fail "4.1 <NN> is left in the record file"
  cat > "$TMP/table.txt" <<'END_OF_TEXT'
| ID | Decision | Reason |
|---|---|---|
| PLAN-042 | R5a.1 comes before R5b as its own small LOW documentation PR, with lint and one internal sub-agent audit round, the inline round and review A; it fixes the findings of issue #242 and its comment 7060767358. Every prompt that carries code ending in a compiled artifact is compiled before dispatch, at every tier. The agent writes lesson entries in the PR, and the operator gives their numbers before the merge. The escaped-defects metric counts the unique defects of a bundle found after dispatch: 7 for R5a. The answers to review A's Q1 to Q3 of comment 7060381647 | The reviews of PR #241 found seven defects in fixed texts that the agent could not fix there; HowTo §5.3 item 5 and PLAN-017 compile all code that a prompt carries, while the contract, the process guide and the audit template said HIGH only; the metric compares the producer's gates across steps (process guide §4.3 item 8), so one reading is fixed before R5b |
END_OF_TEXT
  cat > "$TMP/sentence.txt" <<'END_OF_TEXT'
Issue #242 closes at the merge through the line `Fixes #242` of the PR body; no milestone changes, and the step has no tag.
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
for item in ["1.%d" % i for i in range(1, 6)] + ["2.%d" % i for i in range(1, 4)] + ["3.%d" % i for i in range(1, 6)]:
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
  test -z "$(git diff --name-only "$base" HEAD -- firmware src config dashboard partitions scripts tests .github .gemini package.json package-lock.json)" || fail "a firmware, dashboard, script, test, workflow, style-guide or package file changed"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
  cmp -s "$P-agent-prompt.md" "$SAVE/contract-fixes-2026-11-21-agent-prompt.md" || fail "the committed prompt differs from the saved one"
  cmp -s "$P-checks.sh" "$SAVE/contract-fixes-2026-11-21-checks.sh" || fail "the committed check file differs from the saved one"
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

case "$NAME" in
  sec2) b_sec2 ;;
  scope) b_scope ;;
  copy) b_copy ;;
  A|B|C|D) "b_$NAME" ;;
  prepr) b_prepr ;;
  *) echo "usage: bash $0 <sec2 | scope | copy | A | B | C | D | prepr>"; exit 2 ;;
esac
