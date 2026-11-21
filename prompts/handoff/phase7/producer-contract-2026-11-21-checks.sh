#!/usr/bin/env bash
# R5a check file: every gate and checkpoint of the R5a agent prompt producer-contract-2026-11-21-agent-prompt.md,
# so that the agent types no check (PLAN-031). It also writes the scope list, copies the supplied files and
# moves the tracking supplement to the archive. Written 2026-11-21 by the planning session; do not edit it.
# The texts between "<<'END_OF_TEXT'" and "END_OF_TEXT" are the fenced texts of the prompt, copied by a tool.
#
#   bash /root/r5a/producer-contract-2026-11-21-checks.sh <sec2 | scope | copy <1|3> | move | A | B | C | D | prepr>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# It reads no credential and calls no board. Temporary files go when it ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/r5a
BRANCH=docs/r5a-2026-11
BASE_COMMIT=104b726
P=prompts/handoff/phase7/producer-contract-2026-11-21
CS=CURRENT-STATE.md
POR=Docs/plan-of-record.md
DL=Docs/decisions/decision-log.md
PG=Docs/development-process-guide.md
PSH=Docs/planner-start-here.md
PAT=Docs/templates/prompt-audit-template.md
AR=Docs/archive/README.md
PC=prompts/producer-contract.md
V3=prompts/handoff/phase7-batch-production-prompt-v3.md
V2=prompts/handoff/phase7-batch-production-prompt-update.md
SG=.gemini/styleguide.md
OP=Docs/operator/R5a-producer-contract.md
SUP_OLD=Docs/phase7-github-tracking-supplement.md
SUP_NEW=Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md
NAME="${1:-}"
case "$NAME" in sec2) LABEL="§2" ;; prepr) LABEL="PRE-PR" ;; copy) LABEL="copy ${2:-}" ;; *) LABEL="$NAME" ;; esac
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

other_locale() { locale -a 2>/dev/null | grep -m1 -ixE 'en_US\.utf-?8'; }
fixtures() { LC_ALL="$1" bash tests/lint-prompts/run-fixtures.sh > "$TMP/fixtures.log" 2>&1 || { echo "run-fixtures.sh ended with exit $?"; return; }; tail -n 1 "$TMP/fixtures.log"; }
numstat() { git diff --numstat "$(git merge-base origin/main HEAD)" -- "$1" | awk '{print $1, $2}'; }
main_sha() { git show "$BASE_COMMIT:$1" | sha256sum | cut -d' ' -f1; }

b_sec2() {
  local p
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git merge-base --is-ancestor "$BASE_COMMIT" HEAD || fail "$BASE_COMMIT (PR #240) is not an ancestor of HEAD"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P-agent-prompt.md" "$SAVE/producer-contract-2026-11-21-agent-prompt.md" || fail "the committed prompt differs from $SAVE/producer-contract-2026-11-21-agent-prompt.md"
  cmp -s "$P-checks.sh" "$SAVE/producer-contract-2026-11-21-checks.sh" || fail "the committed check file differs from $SAVE/producer-contract-2026-11-21-checks.sh"
  test -d "$SAVE/files" || fail "$SAVE/files is missing: run the file check of the gate record"
  for t in python3 node npx git sha256sum comm locale env; do command -v "$t" >/dev/null || fail "the tool $t is missing"; done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' || fail "python3 is older than 3.12"
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing: preflight would skip the browser test"
  other_locale >/dev/null || fail "no en_US.UTF-8 locale (locale -a): the PRE-PR gate needs it"
  for p in "$PC" "$V3" "$SG" .gemini "$OP" "$P-review.md" "$P.md" "$SUP_NEW"; do
    test ! -e "$p" || fail "$p already exists"
  done
  test "$(grep -c '^_Next action: ' "$CS")" = "1" || fail "2.1 anchor: one line that begins '_Next action: '"
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.2 anchor"
1. **R5a, R5b** — the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017). No firmware change. Review B runs on the review runner from now on (PLAN-022, PLAN-023).
END_OF_TEXT
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.3 anchor"
| R5c planning (CI logs) | The actions `checkout@v4`, `setup-node@v4`, `setup-python@v5`, `cache@v4` and `upload-artifact@v4` target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
END_OF_TEXT
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.4 anchor"
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Pending operator post-merge check** — `Docs/operator/R5r-review-runner.md`, sections "Dry run" and "Posting run"; until both pass, a code step that needs review B waits for the runner, or the operator chooses to run review B as a Muse session in three turns (PLAN-023) |
END_OF_TEXT
  starts "$CS" 1 <<'END_OF_TEXT' || fail "2.5 anchor"
| The nine Batch 2 prompt files of May 2026:
END_OF_TEXT
  starts "$CS" 1 <<'END_OF_TEXT' || fail "2.6 anchor"
| `Docs/planner-start-here.md` |
END_OF_TEXT
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.6 anchor: the line on the archive"
_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 (PLAN-025)._
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.7 anchor"
The next step is **R5a**, the producer contract. The last merged step is **R5r**, the review-runner PR; its dry run and posting run come before the next code step.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.8 anchor"
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Merged: the pull request that added `.github/workflows/external-review.yml`; done when the conditions of its block in section 5 hold |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.9 anchor"
| 6 | R5a | Producer contract and batch-production prompt v3.0 | Dispatch, review and merge one documentation PR | R5r | Unchanged | 1 to 2 | Waiting |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.10 anchor"
- R5a also decides: the form of the review file with its common part and the parts A, B and C; how a prompt hands over a long insertion; whether the Gemini inline reviewer gets a `.gemini/styleguide.md` (PLAN-029); and it takes the tracking rules of `Docs/phase7-github-tracking-supplement.md` into the contract (PLAN-025).
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.11 anchor: the first line"
| The Gemini inline reviewer loads no instruction file of this repository | R5a |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.11 anchor: the second line"
| Three points of the review runner are not verified (section 5, R5r) | R5r, first dry run |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.11 anchor: the line 'Not verified yet' of R5r"
- Not verified yet, and decided by the first dry run: that Google's Agent Platform accepts the federated identity directly (the other way is a service account without a key); which value the `ref` claim has for a run from the Actions tab; the Python calls to the model. Before the operator relies on credits from more than one Google subscription, Google's terms are checked.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.11 anchor: the line on dashboard/dashboard.h of R5b"
  - `dashboard/dashboard.h` is in the regenerated outputs of every code prompt, because each build changes it;
END_OF_TEXT
  starts "$DL" 1 <<'END_OF_TEXT' || fail "2.12 anchor"
| 2026-11-18 | PLAN-037 |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.13 anchor: the doctrinal-source line"
   - `prompts/handoff/<<phase>>-batch-production-prompt-update.md` — for the canonical scope-guard whitelist and Errata.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.13 anchor: the version line"
- **Template version:** v1.2
END_OF_TEXT
  starts "$PAT" 1 <<'END_OF_TEXT' || fail "2.13 anchor: the changelog row v1.2"
| v1.2 | 2026-11-18 |
END_OF_TEXT
  starts "$PAT" 1 <<'END_OF_TEXT' || fail "2.13 anchor: step 4 of §7"
4. MEDIUM: launch one independent auditor using this template.
END_OF_TEXT
  starts "$AR" 1 <<'END_OF_TEXT' || fail "2.14 anchor"
| `Docs/session-log-2026-05-06-v7.6.10.4.md` |
END_OF_TEXT
  for p in "$CS" "$POR" "$DL" "$PG" "$PSH" "$PAT" "$AR" "$SUP_OLD"; do
    test -f "$p" && test "$(sha "$p")" = "$(main_sha "$p")" || fail "$p differs from main at $BASE_COMMIT: the planning session renders the prompt again"
  done
  echo "§2 PASS"
}

b_scope() {
  local a; a="$(git rev-parse --git-path scope-allowed.txt)" || fail "git rev-parse"
  cat > "$a" <<'EOF'
CURRENT-STATE.md
Docs/plan-of-record.md
Docs/decisions/decision-log.md
Docs/development-process-guide.md
Docs/planner-start-here.md
Docs/templates/prompt-audit-template.md
Docs/archive/README.md
prompts/producer-contract.md
prompts/handoff/phase7-batch-production-prompt-v3.md
.gemini/styleguide.md
Docs/operator/R5a-producer-contract.md
prompts/handoff/phase7/producer-contract-2026-11-21-review.md
prompts/handoff/phase7/producer-contract-2026-11-21-agent-prompt.md
prompts/handoff/phase7/producer-contract-2026-11-21-checks.sh
prompts/handoff/phase7/producer-contract-2026-11-21.md
Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md
Docs/phase7-github-tracking-supplement.md
EOF
  test "$(grep -c . "$a")" = "17" || fail "the scope list does not hold 17 paths"
  echo "scope list written: 17 paths"
}

copy_one() { # $1 path, $2 expected SHA-256, $3 "new" or the SHA-256 of the file on main
  if [ -e "$1" ] && [ "$(sha "$1")" = "$2" ]; then return 0; fi
  if [ "$3" = "new" ]; then test ! -e "$1" || fail "$1 exists and differs from the supplied file"
  else test "$(sha "$1")" = "$3" || fail "$1 differs from main: render the prompt again"; fi
  test "$(sha "$SAVE/files/$1")" = "$2" || fail "$SAVE/files/$1 differs from the bundle: run the file check of the gate record"
  mkdir -p "$(dirname "$1")" && cp "$SAVE/files/$1" "$1" || fail "cannot copy $1"
  test "$(sha "$1")" = "$2" || fail "$1 differs from the supplied file after the copy"
}

b_copy() {
  case "${1:-}" in
    1)
      copy_one "$PC" 38b7d12d87baf6e5aebf61b4fb39ac3dd2b929269ccd7100a5bde591868ee4bd new
      copy_one "$V3" 8f18020df5c3fe963785e6a7e8a5705fe4ed94aab7a726a1ab434beddd169d2a new
      copy_one "$SG" f13e6e2e100229d18adf448b772499371bf7d1e7a09677bb711a7d7f83638bb2 new
      echo "copied 3 files" ;;
    3)
      copy_one "$PG" e2b903dec8e6fe1cbacb28ea1cc2e1974284c2ec6dcf098c0774a8e6af0b6c59 "$(main_sha "$PG")"
      copy_one "$PSH" d6a39301ae16808be6d49a7aa3fb347ae13608bfb80f352985bd0d9cd3acd0d3 "$(main_sha "$PSH")"
      copy_one "$OP" 8aea6bf24fe8c4f8c00dd8b4528aec349b20d66949b34f3dc0f0646373d7a781 new
      copy_one "$P-review.md" cc19040d113154913d544c7a3647780af2311a5e052a9956a4bdb4192eec4bfc new
      echo "copied 4 files" ;;
    *) fail "unknown group '${1:-}'" ;;
  esac
}

b_move() {
  if [ ! -e "$SUP_OLD" ] && [ -f "$SUP_NEW" ] && [ "$(sha "$SUP_NEW")" = "$(main_sha "$SUP_OLD")" ]; then echo "moved 1 file"; return 0; fi
  test -f "$SUP_OLD" || fail "2.15 $SUP_OLD is missing"
  test "$(sha "$SUP_OLD")" = "$(main_sha "$SUP_OLD")" || fail "2.15 $SUP_OLD differs from main at $BASE_COMMIT"
  test ! -e "$SUP_NEW" || fail "2.15 $SUP_NEW exists already"
  git mv "$SUP_OLD" "$SUP_NEW" || fail "2.15 git mv"
  echo "moved 1 file"
}

b_A() {
  test "$(sha "$PC")" = "38b7d12d87baf6e5aebf61b4fb39ac3dd2b929269ccd7100a5bde591868ee4bd" || fail "1.1 $PC differs from the supplied file"
  test "$(sha "$V3")" = "8f18020df5c3fe963785e6a7e8a5705fe4ed94aab7a726a1ab434beddd169d2a" || fail "1.1 $V3 differs from the supplied file"
  test "$(sha "$SG")" = "f13e6e2e100229d18adf448b772499371bf7d1e7a09677bb711a7d7f83638bb2" || fail "1.1 $SG differs from the supplied file"
  test "$(wc -l < "$PC")" -le 150 || fail "1.1 $PC has more than 150 lines: $(wc -l < "$PC")"
  python3 -I - "$PC" <<'PYEOF' || fail "1.1 a numbered rule of the contract does not end with a tag in square brackets (see the line above)"
import re, sys
bad = [l for l in open(sys.argv[1], encoding="utf-8").read().split("\n") if re.match(r"^[0-9]+\. ", l) and not re.search(r"\[[^\[\]]+\]$", l)]
if bad:
    sys.exit("untagged rule: " + bad[0][:80])
PYEOF
  test "$(wc -l < "$V3")" -lt "$(wc -l < "$V2")" || fail "1.1 $V3 has $(wc -l < "$V3") lines, not fewer than the $(wc -l < "$V2") of $V2"
  test "$(wc -c < "$V3")" -lt "$(wc -c < "$V2")" || fail "1.1 $V3 has $(wc -c < "$V3") bytes, not fewer than the $(wc -c < "$V2") of $V2"
  bash scripts/lint-prompts.sh "$PC" "$V3" > "$TMP/lint.log" 2>&1 || fail "1.1 lint in normal mode on $PC and $V3: $(grep -m2 -E 'ERROR|L[0-9]+' "$TMP/lint.log" | tr '\n' '|')"
  python3 -I - AGENTS.md "$SG" <<'PYEOF' || fail "1.1 $SG below its line --- is not the four parts of AGENTS.md word for word (see the line above)"
import sys
L = open(sys.argv[1], encoding="utf-8").read().split("\n")
def part(head, stops):
    if L.count(head) != 1:
        sys.exit("AGENTS.md has not exactly one line '%s'" % head)
    i = L.index(head); out = [head]
    for l in L[i + 1:]:
        if l == "---" or any(l.startswith(s) for s in stops):
            break
        out.append(l)
    while out[-1] == "":
        out.pop()
    return "\n".join(out)
parts = [part("### Generated Files (NEVER edit directly)", ("## ", "### ")),
         part("## Critical Rules", ("## ",)),
         part("## Code Review Checklist", ("## ",)),
         part("## Severity Classification", ("## ",))]
S = open(sys.argv[2], encoding="utf-8").read().split("\n")
if "---" not in S:
    sys.exit("no line --- in the style guide")
rest = "\n".join(S[S.index("---") + 1:])
for p in parts:
    if p not in rest:
        sys.exit("missing, or not word for word: " + p.split("\n")[0])
    rest = rest.replace(p, "", 1)
if rest.strip():
    sys.exit("text that is not a part of AGENTS.md: " + rest.strip().split("\n")[0][:80])
PYEOF
  echo "CHECKPOINT A PASS"
}

b_B() {
  test "$(grep -c '^_Next action: ' "$CS")" = "1" || fail "2.1 expected one Next action line"
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.1 the new Next action line"
_Next action: R5b, the Batch 2 prompts re-produced under the producer contract `prompts/producer-contract.md` with batch prompt v3.0 (PLAN-017, PLAN-038). The review runner passed its dry run (2026-11-20) and its posting run (2026-11-21) on PR #239; the next code step, R4, uses it for review B. The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5b._
END_OF_TEXT
  test "$(grep -cF 'R5a, R5b' "$CS")" = "0" || fail "2.2 the old What-is-Next item is still in the file"
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.2 the new What-is-Next item"
1. **R5b** — the Batch 2 prompts re-produced under the producer contract and batch prompt v3.0 (PLAN-017, PLAN-038). No firmware change. Review B runs on the review runner (PLAN-022, PLAN-023).
END_OF_TEXT
  have "$CS" 0 <<'END_OF_TEXT' || fail "2.3 the old row 'R5c planning (CI logs)' is still in the file"
| R5c planning (CI logs) | The actions `checkout@v4`, `setup-node@v4`, `setup-python@v5`, `cache@v4` and `upload-artifact@v4` target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
END_OF_TEXT
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.3 the new row 'R5c planning (CI logs)'"
| R5c planning (CI logs) | The actions `checkout@v4`, `setup-node@v4`, `setup-python@v5`, `cache@v4` and `upload-artifact@v4` target Node.js 20; the runner forces them to Node.js 24 and warns that Node.js 20 is deprecated. `setup-node` also installs Node.js 20 for the jobs. `.github/workflows/external-review.yml` pins `actions/checkout` at v4.4.0, which gives the same warning (run 44861784463) | **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |
END_OF_TEXT
  test "$(grep -cF -- '**Pending operator post-merge check**' "$CS")" = "0" || fail "2.4 the status mark 'Pending operator post-merge check' is still in the file"
  cat > "$TMP/r5r.txt" <<'END_OF_TEXT'
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Done 2026-11-21** — dry run 44828100924 (`gemini-4-argon`, 2026-11-20) wrote three turns to its summary; posting run 44861784463 (`gemini-4-hydrogen`, 2026-11-21) posted one comment on PR #239; the sign-in used direct federation, with no service account. The last condition of R5r in plan of record section 5, that the next code step uses the runner for review B, is checked at R4 |
| PR #240 inline review and review A M1 | The three inline fixes of the runner (thought parts screened before reuse, the raw PR title screened, every Link header read) and the fix of review A finding M1 (encoded at signs and slashes) have no permanent test: their regression tests ran from a temporary file, because the supplied test file was fixed | **Not implemented** — routed to a later runner-hardening tooling step that the operator schedules |
| PR #240 review A L1, Q1 and Q2 | L1 (LOW): the runner reads the diff and the file list of the PR without pinning them to the two commits that its header prints; reading them through the compare endpoint, pinned to both commits, closes it. Q1: hidden HTML (comments, `<details>`) in the model's answer. Q2: Unicode spaces before a slash. Q1 and Q2 are not verified | **Not implemented** — routed to the runner-hardening step |
| R5r runs (2026-11-21) | The runner sends no check-run data, so review B marks the CI gates UNCLEAR and advises FIX FIRST on every step whose review file has CI gates; a data block with the check runs of the PR head (name, status, conclusion, head commit) fixes it | **Not implemented** — routed to the runner-hardening step; until then the operator's merge checklist covers the CI gates |
| R5r runs (2026-11-21) | A second profile (step 4 of "Add a profile" in `Docs/operator/R5r-review-runner.md`); a comparison of the runner's models on a PR with seeded defects; and, for the operator page, deleting an earlier runner comment before a new run, so that the model does not review its own earlier output | **Not implemented** — routed to the runner-hardening step |
| R5a internal audit (2026-11-21) | `AGENTS.md`, "PR Title and Body — Preservation Rules" item 2, names an "Audit Gate Notice" among the sections of a PR body. No document under `Docs/` defines it. The May 2026 prompt `prompts/handoff/phase7/issue-228-CDE-producer-session-prompt.md` gave a text for the PR of issue #228 §C to §E, which no longer holds, because the Batch 2 prompts are re-produced first (PLAN-017); §8 of the prompts of the restart steps does not ask for it, and R5a does not use it. Rule 7.10 of `prompts/producer-contract.md` asks for it only when a prompt gives its text | **Not implemented** — routed to the next pull request that changes `AGENTS.md` |
END_OF_TEXT
  have "$CS" 1 < <(head -n 1 "$TMP/r5r.txt") || fail "2.4 the new R5r row"
  after "$CS" "$(head -n 1 "$TMP/r5r.txt")" < <(tail -n +2 "$TMP/r5r.txt") || fail "2.4 the four new rows must follow the R5r row, in order"
  after "$CS" '| The nine Batch 2 prompt files of May 2026:' <<'END_OF_TEXT' || fail "2.5 the new row must follow the row of the nine Batch 2 prompt files"
| `prompts/handoff/phase7-batch-production-prompt.md` (version 1), `prompts/handoff/phase7-batch-production-prompt-update.md` (version 2.0), and the banner of `prompts/handoff/phase7-prompt-production-instructions.md`, which names version 2.0 as current | 2026-05 | **Superseded** by `prompts/producer-contract.md` and `prompts/handoff/phase7-batch-production-prompt-v3.md` (PLAN-038). History only. |
END_OF_TEXT
  after "$CS" '| `Docs/planner-start-here.md` |' <<'END_OF_TEXT' || fail "2.6 the new row must follow the row of the planner page"
| `prompts/producer-contract.md` | Producer contract: the binding rules of a prompt bundle (PLAN-038) |
END_OF_TEXT
  have "$CS" 0 <<'END_OF_TEXT' || fail "2.6 the old line on the archive is still present"
_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 (PLAN-025)._
END_OF_TEXT
  have "$CS" 1 <<'END_OF_TEXT' || fail "2.6 the new line on the archive"
_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 and on 2026-11-21 (PLAN-025, PLAN-038)._
END_OF_TEXT
  test "$(numstat "$CS")" = "12 5" || fail "2.1 to 2.6 $CS must show 12 added and 5 deleted lines; it shows $(numstat "$CS")"
  test "$(grep -cF -- 'The next step is **R5a**' "$POR")" = "0" || fail "2.7 the old You-are-here line is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.7 the new You-are-here line"
The next step is **R5b**, the Batch 2 prompts re-produced under the producer contract. The last merged step is **R5a**, the producer contract. The review runner passed its dry run on 2026-11-20 and its posting run on 2026-11-21.
END_OF_TEXT
  test "$(grep -cF -- 'done when the conditions of its block in section 5 hold' "$POR")" = "0" || fail "2.8 the old status of the R5r row is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.8 the new R5r row"
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Merged; dry run (2026-11-20) and posting run (2026-11-21) passed (runs 44828100924 and 44861784463); done when the next code step uses the runner for review B |
END_OF_TEXT
  test "$(grep -c '^| 6 | R5a | .* | Waiting |$' "$POR")" = "0" || fail "2.9 the R5a row is still Waiting"
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.9 the new R5a row"
| 6 | R5a | Producer contract and batch-production prompt v3.0 | Dispatch, review and merge one documentation PR | R5r | Unchanged | 1 to 2 | Done: the pull request that added `prompts/producer-contract.md` |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "2.10 the old line 'R5a also decides' is still present"
- R5a also decides: the form of the review file with its common part and the parts A, B and C; how a prompt hands over a long insertion; whether the Gemini inline reviewer gets a `.gemini/styleguide.md` (PLAN-029); and it takes the tracking rules of `Docs/phase7-github-tracking-supplement.md` into the contract (PLAN-025).
END_OF_TEXT
  cat > "$TMP/r5a.txt" <<'END_OF_TEXT'
- R5a also decides: the form of the review file with its common part and the parts A, B and C; how a prompt hands over a long insertion; whether the Gemini inline reviewer gets a `.gemini/styleguide.md` (PLAN-029); and it takes the tracking rules of `Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md` into the contract (PLAN-025).
- Decided in R5a (PLAN-038 to PLAN-041): the contract also holds the planner rules from review findings and from the audit of R5r; a long text reaches the agent as a supplied file; the review file has a common part, the checks of the step and the parts A, B and C; the Gemini inline reviewer gets `.gemini/styleguide.md`; the tracking supplement moves to the archive; an internal sub-agent audit comes before each external audit; the bundle goes to the planning repository; Gemini 4 Neon is the second auditor of a HIGH prompt. R5a is LOW: an internal sub-agent audit and no external auditor; reviews A and B on its PR.
END_OF_TEXT
  have "$POR" 1 < <(head -n 1 "$TMP/r5a.txt") || fail "2.10 the new line 'R5a also decides'"
  after "$POR" "$(head -n 1 "$TMP/r5a.txt")" < <(tail -n +2 "$TMP/r5a.txt") || fail "2.10 the line 'Decided in R5a' must follow the line 'R5a also decides'"
  have "$POR" 0 <<'END_OF_TEXT' || fail "2.11 the open finding on the Gemini reviewer is still present"
| The Gemini inline reviewer loads no instruction file of this repository | R5a |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "2.11 the open finding on the three points of the runner is still present"
| Three points of the review runner are not verified (section 5, R5r) | R5r, first dry run |
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "2.11 the old line 'Not verified yet' of R5r is still present"
- Not verified yet, and decided by the first dry run: that Google's Agent Platform accepts the federated identity directly (the other way is a service account without a key); which value the `ref` claim has for a run from the Actions tab; the Python calls to the model. Before the operator relies on credits from more than one Google subscription, Google's terms are checked.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.11 the new line 'Decided by the dry run' of R5r"
- Decided by the dry run of 2026-11-20 and the posting run of 2026-11-21 (runs 44828100924 and 44861784463): Agent Platform accepts the federated identity directly, with no service account; the condition on `refs/heads/main` and `workflow_dispatch` accepts a run started from the Actions tab; the Python calls to the model work. Before the operator relies on credits from more than one Google subscription, Google's terms are checked.
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "2.11 the old line on dashboard/dashboard.h of R5b is still present"
  - `dashboard/dashboard.h` is in the regenerated outputs of every code prompt, because each build changes it;
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "2.11 the new line on dashboard/dashboard.h of R5b"
  - `dashboard/dashboard.h` is in the regenerated outputs of every code prompt that bumps the version, because the version is in the dashboard (R5 made the header reproducible);
END_OF_TEXT
  test "$(numstat "$POR")" = "7 8" || fail "2.7 to 2.11 $POR must show 7 added and 8 deleted lines; it shows $(numstat "$POR")"
  after "$DL" '| 2026-11-18 | PLAN-037 |' <<'END_OF_TEXT' || fail "2.12 the rows PLAN-038 to PLAN-041 must follow PLAN-037, in order and verbatim"
| 2026-11-21 | PLAN-038 | Producer contract and batch-production prompt v3.0 (R5a, within PLAN-012 and PLAN-017). `prompts/producer-contract.md` holds the binding rules of a prompt bundle, at most 150 lines, each tagged with the lint rule, the gate or the judgment that enforces it. It also holds the rules from review findings and from the audit of R5r that `Docs/planner-start-here.md` held, and the tracking rules of `Docs/phase7-github-tracking-supplement.md`, which moves to `Docs/archive/planning-2026-05/` with `git mv` (PLAN-025). `prompts/handoff/phase7-batch-production-prompt-v3.md` replaces version 2.0 and is shorter. The planning session decided the forms: a long text (a new file, a whole rewritten file, an insertion of more than 10 lines) reaches the agent as a supplied file with its SHA-256, copied by the check file; the review file has a table of reviews A, B and C, a common part, the checks of the step, parts A and B, part C when review C runs, and the line for after a review; a firmware step has no two-step prompt. The operator decided on 2026-11-21 that R5a is LOW, with an internal sub-agent audit and no external auditor, and that reviews A and B by the runner run on its pull request. This widens the scope of R5a in the plan of record (two files) to the places that state the rules it changes (contract rule 1.4) and to the operator decisions of 2026-11-19 and 2026-11-21 | `prompts/handoff/phase7/producer-contract-2026-11-21.md` §6 |
| 2026-11-21 | PLAN-039 | The Gemini inline reviewer gets `.gemini/styleguide.md` (operator decision 2026-11-21; completes PLAN-029). Google's pages on its code review (customize-repo-review and style-guide, read 2026-11-21) name `.gemini/config.yaml` and a style guide `styleguide.md` in the folder `.gemini/`; they do not name `AGENTS.md`. The file copies four parts of `AGENTS.md` word for word: the table of generated files, the section "Critical Rules", the review checklist and the severities. A PR that changes one of these parts of `AGENTS.md` changes the file too. No `.gemini/config.yaml` | `prompts/handoff/phase7/producer-contract-2026-11-21.md` §6 |
| 2026-11-21 | PLAN-040 | Planner working method (operator decisions 2026-11-19, after the R5r trial in `steps/R5r/subagent-trial-2026-11-18.md` of the planning repository). Before each external audit, one internal sub-agent audits the bundle with the external audit prompt and executes it: it runs the gates, writes its own implementation to the contract of the prompt and applies the edits. The planning session checks each finding against the sources and fixes what holds. It stops when a round finds no new HIGH or MEDIUM, or after two internal rounds; the external audit of PLAN-037 stays. An internal round is not an audit session of the process metrics, as the operator counted R5r's internal checks on PR #240. Each step's bundle, setup block, gate record and planning tools go to `steps/<step>/` of the planning repository, and the gate record gives the SHA-256 of the bundle (amends PLAN-035) | `prompts/producer-contract.md`, rules 1.3 and 5.4 |
| 2026-11-21 | PLAN-041 | Models (operator decisions 2026-11-21; amends PLAN-037). The second auditor of a HIGH prompt is Gemini 4 Neon in AI Studio, in place of Gemini 4 Argon. The review runner stays the default for review B, and its model list stays until Gemini 4 Neon is on Agent Platform. Each planning session reads Google's page "Model versions and lifecycle" for the runner's models; a model change of the runner is a small LOW pull request, then a dry run | `Docs/planner-start-here.md`, the restart check and step 6 |
END_OF_TEXT
  test "$(grep -c '^| ' "$DL")" = "65" || fail "2.12 decision log table rows (61 before, 65 after); found $(grep -c '^| ' "$DL")"
  test "$(tail -n 1 "$DL")" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "2.12 the last line of the log changed"
  test "$(numstat "$DL")" = "4 0" || fail "2.12 $DL must show 4 added lines; it shows $(numstat "$DL")"
  test "$(grep -cF 'batch-production-prompt-update' "$PAT")" = "0" || fail "2.13 the audit template still names version 2.0"
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.13 the new doctrinal-source line"
   - `prompts/producer-contract.md` — the binding rules of a bundle (PLAN-038); `prompts/handoff/phase7-batch-production-prompt-v3.md` — the lessons of Phase 7 and the live-extract table of a batch.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "2.13 the version line"
- **Template version:** v1.3
END_OF_TEXT
  after "$PAT" '| v1.2 | 2026-11-18 |' <<'END_OF_TEXT' || fail "2.13 the changelog row v1.3 must follow v1.2"
| v1.3 | 2026-11-21 | R5a (PLAN-038, PLAN-040): the doctrinal sources name the producer contract and batch prompt v3.0; a note under §7 step 4 sets the internal sub-agent audit before the external audit. |
END_OF_TEXT
  after "$PAT" '4. MEDIUM: launch one independent auditor using this template.' <<'END_OF_TEXT' || fail "2.13 the note on PLAN-040 must follow step 4 of §7"
   PLAN-040 (2026-11-21): before step 4, one internal sub-agent audits the bundle with this audit prompt and executes it; the planning session checks each finding and fixes what holds; at most two internal rounds. It does not replace the audit of step 4. PLAN-037 and PLAN-041 name the auditors.
END_OF_TEXT
  test "$(numstat "$PAT")" = "4 2" || fail "2.13 the audit template must show 4 added and 2 deleted lines; it shows $(numstat "$PAT")"
  after "$AR" '| `Docs/session-log-2026-05-06-v7.6.10.4.md` |' <<'END_OF_TEXT' || fail "2.14 the new section must follow the last row of the moves of 2026-11-16"

## What moved here on 2026-11-21

One file, with `git mv` and no edit, in R5a (PLAN-025, PLAN-038). Its tracking rules are now in `prompts/producer-contract.md`, section 8.

| Old path | New path |
|---|---|
| `Docs/phase7-github-tracking-supplement.md` | `Docs/archive/planning-2026-05/phase7-github-tracking-supplement.md` |
END_OF_TEXT
  test "$(numstat "$AR")" = "8 0" || fail "2.14 $AR must show 8 added lines; it shows $(numstat "$AR")"
  test ! -e "$SUP_OLD" || fail "2.15 $SUP_OLD still exists"
  ! git ls-files --error-unmatch "$SUP_OLD" >/dev/null 2>&1 || fail "2.15 $SUP_OLD is still tracked"
  test -f "$SUP_NEW" || fail "2.15 $SUP_NEW is missing"
  test "$(sha "$SUP_NEW")" = "$(main_sha "$SUP_OLD")" || fail "2.15 $SUP_NEW differs from $SUP_OLD on main: the move must be a pure rename"
  git ls-files --error-unmatch "$SUP_NEW" >/dev/null 2>&1 || fail "2.15 $SUP_NEW is not tracked: use the block move"
  echo "CHECKPOINT B PASS"
}

b_C() {
  test "$(sha "$PG")" = "e2b903dec8e6fe1cbacb28ea1cc2e1974284c2ec6dcf098c0774a8e6af0b6c59" || fail "3.1 $PG differs from the supplied file"
  test "$(sha "$PSH")" = "d6a39301ae16808be6d49a7aa3fb347ae13608bfb80f352985bd0d9cd3acd0d3" || fail "3.1 $PSH differs from the supplied file"
  test "$(sha "$OP")" = "8aea6bf24fe8c4f8c00dd8b4528aec349b20d66949b34f3dc0f0646373d7a781" || fail "3.1 $OP differs from the supplied file"
  test "$(sha "$P-review.md")" = "cc19040d113154913d544c7a3647780af2311a5e052a9956a4bdb4192eec4bfc" || fail "3.1 $P-review.md differs from the supplied file"
  git ls-files -z -co --exclude-standard | grep -zv -e '^prompts/' -e '^Docs/archive/' | grep -zvx -e 'Docs/changelog.md' -e "$DL" \
    | xargs -0 grep -lF -- "$SUP_OLD" > "$TMP/old-path.txt" 2>/dev/null
  test ! -s "$TMP/old-path.txt" || fail "3.1 a live file names the old path $SUP_OLD: $(tr '\n' ' ' < "$TMP/old-path.txt")"
  test "$(grep -c 'Argon' "$PSH")" = "0" || fail "3.1 the planner page names Gemini 4 Argon"
  test "$(grep -c '^## Rules that came from review findings\|^## Rules from the audit of R5r' "$PSH")" = "0" || fail "3.1 the planner page still has rule sections of its own"
  test "$(grep -cF 'batch-production-prompt-update' "$PAT" "$PG" | awk -F: '{s += $2} END {print s + 0}')" = "0" || fail "3.1 the audit template or the process guide names version 2.0"
  test "$(grep -cF 'claude-two-step' "$PAT" "$PG" | awk -F: '{s += $2} END {print s + 0}')" = "0" || fail "3.1 the audit template or the process guide names a claude-two-step file"
  test "$(sed -n '/^```mermaid$/,/^```$/p' "$OP" | grep -c ';')" = "0" || fail "3.1 a semicolon inside the Mermaid block of $OP"
  echo "CHECKPOINT C PASS"
}

b_D() {
  test -f "$P.md" || fail "4.1 $P.md is missing"
  test "$(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')" = "## §1 ## §2 ## §3 ## §4 ## §5 ## §6 ## §7 ## §8 ## §9 " || fail "4.1 the record file must have the nine headings '## §1 ' to '## §9 ', each once, in order; found: $(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')"
  test "$(grep -c '<NN>' "$P.md")" = "0" || fail "4.1 <NN> is left in the record file"
  cat > "$TMP/table.txt" <<'END_OF_TEXT'
| ID | Decision | Reason |
|---|---|---|
| PLAN-038 | The producer contract holds the binding rules of a bundle, the planner rules from review findings and from the audit of R5r, and the tracking rules; batch prompt v3.0 replaces version 2.0; a long text reaches the agent as a supplied file; the form of the review file; the tracking supplement moves to the archive; R5a is LOW, with an internal audit and no external auditor, and reviews A and B by the runner are to run on its PR | One source of producer rules of about 150 lines (HowTo §5.4); v3.0 shorter than v2.0 (PLAN-012); R5c and R5r handed over their long texts as supplied files, and each arrived byte for byte |
| PLAN-039 | The Gemini inline reviewer gets `.gemini/styleguide.md`, which copies four parts of `AGENTS.md` word for word | Google's pages name `.gemini/styleguide.md` and do not name `AGENTS.md`; without the file Gemini reviews without the rules of the project |
| PLAN-040 | An internal sub-agent audit before each external audit, at most two rounds; the bundle and the gate record in the planning repository | In the R5r trial the internal executing checks found every defect that would have stopped the agent, and the external auditor found more gaps in the text; both are needed |
| PLAN-041 | Gemini 4 Neon is the second auditor of a HIGH prompt; the runner stays the default for review B with its model list; each planning session checks the runner's models on Google's lifecycle page | The operator's choice of 2026-11-21; Neon and Argon are both selectable in AI Studio, and Neon is not yet on Agent Platform |
END_OF_TEXT
  cat > "$TMP/sentence.txt" <<'END_OF_TEXT'
No issue closes in this step, and no milestone changes. After the merge the operator marks §E of issue #228 closed in the status table of its body, with the number of this pull request.
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
for item in ["1.1"] + ["2.%d" % i for i in range(1, 16)] + ["3.1"]:
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
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^M')" = "7" || fail "expected 7 changed files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^A')" = "9" || fail "expected 9 new files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^D')" = "1" || fail "expected 1 deleted path, the old path of the moved file"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -vc '^[MAD]')" = "0" || fail "a file changed its type"
  test "$(git diff --name-only --no-renames --diff-filter=D "$base" HEAD)" = "$SUP_OLD" || fail "a file other than $SUP_OLD was deleted"
  test -z "$(git diff --name-only "$base" HEAD -- firmware src config dashboard partitions scripts tests .github package.json package-lock.json)" || fail "a firmware, dashboard, script, test, workflow or package file changed"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
  cmp -s "$P-agent-prompt.md" "$SAVE/producer-contract-2026-11-21-agent-prompt.md" || fail "the committed prompt differs from the saved one"
  cmp -s "$P-checks.sh" "$SAVE/producer-contract-2026-11-21-checks.sh" || fail "the committed check file differs from the saved one"
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
  copy) b_copy "${2:-}" ;;
  move) b_move ;;
  A|B|C|D) "b_$NAME" ;;
  prepr) b_prepr ;;
  *) echo "usage: bash $0 <sec2 | scope | copy <1|3> | move | A | B | C | D | prepr>"; exit 2 ;;
esac
