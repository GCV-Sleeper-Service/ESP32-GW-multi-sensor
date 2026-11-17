#!/usr/bin/env bash
# R5c check file: every gate and checkpoint of the R5c agent prompt runner-pin-2026-11-17-agent-prompt.md,
# so that the agent types no check (PLAN-031). It also writes the scope list and copies the supplied
# files. Written 2026-11-17 by the planning session; do not edit it.
#
#   bash /root/r5c/runner-pin-2026-11-17-checks.sh <sec2 | scope | copy 3 | A | B | C | D | prepr>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# It reads no credential and calls no board. Every temporary file is removed when the block ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/r5c
BRANCH=tooling/r5c-2026-11
BASE_COMMIT=1a7bf84
P=prompts/handoff/phase7/runner-pin-2026-11-17
WORKFLOWS=(.github/workflows/browser-tests.yml .github/workflows/ci.yml .github/workflows/pr-body-check.yml .github/workflows/prompt-lint.yml)
PIN_COMMENT='    # Pinned to one Ubuntu release: the runner'"'"'s OS changes only through a pull request (R5c, PLAN-034).'
SELF_PATH="      - '.github/workflows/browser-tests.yml'"
OLD_COMM='  comm -23 "$tmp_head_keys" "$tmp_base_keys" > "$tmp_new_keys"'
NEW_COMM='  LC_ALL=C comm -23 "$tmp_head_keys" "$tmp_base_keys" > "$tmp_new_keys"'
COMM_COMMENT="  # LC_ALL=C: comm compares in the byte order of the sort in violation_keys, whatever the shell's locale (R5c, PLAN-034)."
NAME="${1:-}"
case "$NAME" in sec2) LABEL="§2" ;; prepr) LABEL="PRE-PR" ;; copy) LABEL="copy ${2:-}" ;; *) LABEL="$NAME" ;; esac
TMP="$(mktemp -d)" || { echo "⛔ CHECKPOINT FAILED - ${LABEL}: mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
fail() { echo "⛔ CHECKPOINT FAILED - ${LABEL}: $1"; exit 1; }
sha() { sha256sum < "$1" | cut -d' ' -f1; }
cnt() { grep -cxF -- "$1" "$2"; }   # $1 whole line, $2 file: how many lines are exactly $1
cd "$REPO" 2>/dev/null || fail "repository path $REPO"

other_locale() { # the en_US UTF-8 locale, whose collation differs from C
  locale -a 2>/dev/null | grep -m1 -ixE 'en_US\.utf-?8'
}

yaml_python() { # print a Python that imports yaml: python3, or the Python next to esphome
  local c e
  e="$(command -v esphome 2>/dev/null)" && e="$(dirname "$(readlink -f "$e")")/python3" || e=""
  for c in python3 "$e"; do
    [ -n "$c" ] || continue
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import yaml' 2>/dev/null; then echo "$c"; return 0; fi
  done
  return 1
}

fixtures() { # $1 locale: the last line of the lint fixture run in that locale
  LC_ALL="$1" bash tests/lint-prompts/run-fixtures.sh 2>&1 | tail -n 1
}

numstat() { # $1 path: "<added> <deleted>" lines against the merge base with origin/main
  git diff --numstat "$(git merge-base origin/main HEAD)" -- "$1" | awk '{print $1, $2}'
}

b_sec2() {
  local loc w
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git merge-base --is-ancestor "$BASE_COMMIT" HEAD || fail "$BASE_COMMIT (PR #237) is not an ancestor of HEAD"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P-agent-prompt.md" "$SAVE/runner-pin-2026-11-17-agent-prompt.md" || fail "the committed prompt differs from $SAVE/runner-pin-2026-11-17-agent-prompt.md"
  cmp -s "$P-checks.sh" "$SAVE/runner-pin-2026-11-17-checks.sh" || fail "the committed check file differs from $SAVE/runner-pin-2026-11-17-checks.sh"
  test -d "$SAVE/files" || fail "$SAVE/files is missing: run the file check of the gate record"
  for t in python3 node npx git sha256sum comm locale; do command -v "$t" >/dev/null || fail "the tool $t is missing"; done
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing: preflight would skip the browser test"
  yaml_python >/dev/null || fail "no Python with PyYAML: neither python3 nor the Python of esphome imports yaml"
  loc="$(other_locale)" || fail "no en_US.UTF-8 locale (locale -a): CHECKPOINT B needs it"
  test "$(fixtures C.UTF-8)" = "lint fixtures: 13 passed, 0 failed" || fail "the lint fixtures do not pass in C.UTF-8 before the edit: $(fixtures C.UTF-8)"
  test "$(fixtures "$loc")" = "lint fixtures: 12 passed, 1 failed" || fail "the locale defect does not show in $loc as expected (12 passed, 1 failed): $(fixtures "$loc")"
  for p in 'Docs/operator/R5c-runner-pin.md' "$P-review.md" "$P.md"; do test ! -e "$p" || fail "$p already exists"; done
  for w in "${WORKFLOWS[@]}"; do
    test "$(cnt '    runs-on: ubuntu-latest' "$w")" = "1" || fail "1.1 to 1.4 anchor in $w"
  done
  test "$(cnt "      - 'scripts/bundle-dashboard.sh'" .github/workflows/browser-tests.yml)" = "2" || fail "1.5 anchor: two lines"
  test "$(cnt "$OLD_COMM" scripts/lint-prompts.sh)" = "1" || fail "2.1 anchor"
  test "$(cnt '| PR #237 CI | Browser Tests cannot install browsers: Playwright 1.56.0 does not support the runner'"'"'s `ubuntu26.04-x64` platform | **Not implemented** — a separate scoped CI/dependency compatibility follow-up; the Browser Tests workflow and dependency files are outside R5 scope |' CURRENT-STATE.md)" = "1" || fail "3.1 anchor"
  test "$(cnt '| PR #237 external review A | Exercise the documentation CI fast path on a clean GitHub runner after the PyYAML fix | **Pending operator post-merge check** — run the existing one-off documentation PR procedure in the R5 prompt §9 and operator page immediately after merge, before relying on the fast path for real documentation PRs; no agent-created smoke PR or merge |' CURRENT-STATE.md)" = "1" || fail "3.2 anchor"
  test "$(cnt 'The next step is **R5r**, the review-runner PR. The last merged step is **R5**, the tooling PR.' Docs/plan-of-record.md)" = "1" || fail "3.4 anchor"
  test "$(cnt '| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | Done: the pull request that added `scripts/scope-gate.py` |' Docs/plan-of-record.md)" = "1" || fail "3.5 anchor"
  test "$(cnt '| 5a | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5 | Unchanged | 2 to 4 | Waiting |' Docs/plan-of-record.md)" = "1" || fail "3.7 anchor"
  test "$(cnt '### R5r: review-runner PR (MEDIUM)' Docs/plan-of-record.md)" = "1" || fail "3.8 anchor"
  test "$(grep -cF -- '| 2026-11-16 | PLAN-033 |' Docs/decisions/decision-log.md)" = "1" || fail "3.9 anchor"
  test "$(cnt 'Manual trigger via `workflow_dispatch` is always available.' Docs/development-process-guide.md)" = "1" || fail "3.10 anchor"
  test "$(sha .github/workflows/browser-tests.yml)" = "c6601828d81fddc8cfc6e46e514ed11f796feba40aab53743294b4f8997e2704" || fail ".github/workflows/browser-tests.yml differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha .github/workflows/ci.yml)" = "6cbad03ae698ec5c19c340117e0a487338e75b70e9eeca7cffa7c83584f925dd" || fail ".github/workflows/ci.yml differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha .github/workflows/pr-body-check.yml)" = "d118d04bce49fdf88bc8c88c1b633aab0fa906118d7d9754bdf34334d713a958" || fail ".github/workflows/pr-body-check.yml differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha .github/workflows/prompt-lint.yml)" = "dc0afe7ec5a30e58662196c61e5cdb0e95e75062ae964d1db5f44f6559e44119" || fail ".github/workflows/prompt-lint.yml differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha scripts/lint-prompts.sh)" = "986aff82ba98b47608b6a4b31ae321d1010ca04176288571cdf868049b405053" || fail "scripts/lint-prompts.sh differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha CURRENT-STATE.md)" = "39b8ad1457f472e50623a05515489a4719612ded29d281c25507796ab7d1fb6b" || fail "CURRENT-STATE.md differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha Docs/plan-of-record.md)" = "f43165e09a75b8b57114043b8439a2ea0d2f76312526aca0bd70f1f606c87f39" || fail "Docs/plan-of-record.md differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha Docs/decisions/decision-log.md)" = "50fd45a317af5502329edd327e36a09ff51013faf1b7ff3cf9e182f93afc96ad" || fail "Docs/decisions/decision-log.md differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha Docs/development-process-guide.md)" = "e432461c0d2e869a41c3d0f46a32feb6764ed1b085c893b5aa04c6cd3183d1b2" || fail "Docs/development-process-guide.md differs from main at 1a7bf84: the planning session renders the prompt again"
  test "$(sha Docs/planner-start-here.md)" = "8f4c1ba9e4e8505c65ad5ac9487e2f2c0ed08111d54dc6486c461ae7fae8e212" || fail "Docs/planner-start-here.md differs from main at 1a7bf84: the planning session renders the prompt again"
  echo "locale for CHECKPOINT B: $loc"
  echo "§2 PASS"
}

b_scope() {
  local a; a="$(git rev-parse --git-path scope-allowed.txt)" || fail "git rev-parse"
  cat > "$a" <<'EOF'
.github/workflows/browser-tests.yml
.github/workflows/ci.yml
.github/workflows/pr-body-check.yml
.github/workflows/prompt-lint.yml
scripts/lint-prompts.sh
CURRENT-STATE.md
Docs/plan-of-record.md
Docs/decisions/decision-log.md
Docs/development-process-guide.md
Docs/planner-start-here.md
Docs/operator/R5c-runner-pin.md
prompts/handoff/phase7/runner-pin-2026-11-17-review.md
prompts/handoff/phase7/runner-pin-2026-11-17.md
prompts/handoff/phase7/runner-pin-2026-11-17-agent-prompt.md
prompts/handoff/phase7/runner-pin-2026-11-17-checks.sh
EOF
  test "$(grep -c . "$a")" = "15" || fail "the scope list does not hold 15 paths"
  echo "scope list written: 15 paths"
}

copy_one() { # $1 path, $2 expected SHA-256, $3 "new" or the SHA-256 of the file on main
  if [ -e "$1" ] && [ "$(sha "$1")" = "$2" ]; then return 0; fi
  if [ "$3" = "new" ]; then test ! -e "$1" || fail "$1 exists and differs from the supplied file"
  else test "$(sha "$1")" = "$3" || fail "$1 differs from main: render the prompt again"; fi
  mkdir -p "$(dirname "$1")" && cp "$SAVE/files/$1" "$1" || fail "cannot copy $1"
  test "$(sha "$1")" = "$2" || fail "$1 differs from the supplied file after the copy"
}

b_copy() {
  case "${1:-}" in
    3)
      copy_one 'Docs/planner-start-here.md' bdb217899ee214e04071e911381e4a2da72c1b0da7aebe53089f858be008bad6 8f4c1ba9e4e8505c65ad5ac9487e2f2c0ed08111d54dc6486c461ae7fae8e212
      copy_one 'Docs/operator/R5c-runner-pin.md' ceca461aa4280c3d6eec6132c622bb8c8c98f69c5917bb15f00ed960efc48c58 new
      copy_one "$P-review.md" aa6c19547a550020d7314a91219db70bb4f459eb83ae51e931b7166e334e1dc4 new
      echo "copied 3 files" ;;
    *) fail "unknown group '${1:-}'" ;;
  esac
}

b_A() {
  local w py base
  for w in "${WORKFLOWS[@]}"; do
    test "$(cnt '    runs-on: ubuntu-latest' "$w")" = "0" || fail "1.1 to 1.4 the old runs-on line is still in $w"
    test "$(cnt '    runs-on: ubuntu-24.04' "$w")" = "1" || fail "1.1 to 1.4 $w must hold one line '    runs-on: ubuntu-24.04'"
    test "$(cnt "$PIN_COMMENT" "$w")" = "1" || fail "1.1 to 1.4 the comment line above runs-on is missing in $w"
    test "$(grep -B1 -xF '    runs-on: ubuntu-24.04' "$w" | head -n 1)" = "$PIN_COMMENT" || fail "1.1 to 1.4 the comment line must stand directly above runs-on in $w"
  done
  test -z "$(grep -rl 'ubuntu-latest' .github/workflows)" || fail "1.x a workflow still names ubuntu-latest: $(grep -rl 'ubuntu-latest' .github/workflows | tr '\n' ' ')"
  test "$(cnt "$SELF_PATH" .github/workflows/browser-tests.yml)" = "2" || fail "1.5 browser-tests.yml must list its own file twice"
  test "$(grep -A1 -xF "      - 'scripts/bundle-dashboard.sh'" .github/workflows/browser-tests.yml | grep -cxF "$SELF_PATH")" = "2" || fail "1.5 the new path must follow each line of scripts/bundle-dashboard.sh"
  test "$(numstat .github/workflows/browser-tests.yml)" = "4 1" || fail "1.x browser-tests.yml must show 4 added and 1 deleted lines; it shows $(numstat .github/workflows/browser-tests.yml)"
  for w in .github/workflows/ci.yml .github/workflows/pr-body-check.yml .github/workflows/prompt-lint.yml; do
    test "$(numstat "$w")" = "2 1" || fail "1.x $w must show 2 added and 1 deleted lines; it shows $(numstat "$w")"
  done
  py="$(yaml_python)" || fail "no Python with PyYAML"
  base="$(git merge-base origin/main HEAD)" || fail "merge-base"
  for w in "${WORKFLOWS[@]}"; do git show "$base:$w" > "$TMP/$(basename "$w")" || fail "cannot read $w of main"; done
  "$py" -I - "$TMP" "${WORKFLOWS[@]}" <<'PYEOF' || fail "1.x the structure of the workflows (see the line above)"
import os, sys, yaml
tmp, files = sys.argv[1], sys.argv[2:]
self_path = ".github/workflows/browser-tests.yml"
for f in files:
    new = yaml.safe_load(open(f, encoding="utf-8"))
    old = yaml.safe_load(open(os.path.join(tmp, os.path.basename(f)), encoding="utf-8"))
    if set(new["jobs"]) != set(old["jobs"]):
        sys.exit("%s: the job names changed: %r" % (f, sorted(new["jobs"])))
    for job in new["jobs"].values():
        if job.get("runs-on") != "ubuntu-24.04":
            sys.exit("%s: a job runs on %r" % (f, job.get("runs-on")))
        job["runs-on"] = "ubuntu-latest"
    on = new.get("on", new.get(True))
    if f.endswith("browser-tests.yml"):
        for ev in ("push", "pull_request"):
            if on[ev]["paths"][-1:] != [self_path] or on[ev]["paths"].count(self_path) != 1:
                sys.exit("%s: %s must list %s once, as its last path" % (f, ev, self_path))
            on[ev]["paths"].remove(self_path)
    if new != old:
        sys.exit("%s: something besides runs-on and the new path changed" % f)
print("workflows: every job on ubuntu-24.04, nothing else changed")
PYEOF
  echo "CHECKPOINT A PASS"
}

b_B() {
  local loc out1 out2 rc r n
  test "$(cnt "$OLD_COMM" scripts/lint-prompts.sh)" = "0" || fail "2.1 the old comm line is still present"
  test "$(cnt "$NEW_COMM" scripts/lint-prompts.sh)" = "1" || fail "2.1 the new comm line is missing"
  test "$(grep -B1 -xF "$NEW_COMM" scripts/lint-prompts.sh | head -n 1)" = "$COMM_COMMENT" || fail "2.1 the comment line must stand directly above the new comm line"
  test "$(grep -c 'LC_ALL' scripts/lint-prompts.sh)" = "3" || fail "2.1 expected LC_ALL in three lines: the sort, the comment and the comm line"
  test "$(numstat scripts/lint-prompts.sh)" = "2 1" || fail "2.1 scripts/lint-prompts.sh must show 2 added and 1 deleted lines; it shows $(numstat scripts/lint-prompts.sh)"
  bash -n scripts/lint-prompts.sh || fail "2.1 scripts/lint-prompts.sh has a syntax error"
  loc="$(other_locale)" || fail "no en_US.UTF-8 locale"
  test "$(fixtures C.UTF-8)" = "lint fixtures: 13 passed, 0 failed" || fail "2.1 the lint fixtures in C.UTF-8: $(fixtures C.UTF-8)"
  test "$(fixtures "$loc")" = "lint fixtures: 13 passed, 0 failed" || fail "2.1 the lint fixtures in $loc: $(fixtures "$loc")"
  out1="$(LC_ALL=C.UTF-8 bash scripts/lint-prompts.sh --baseline origin/main 2>&1)"; rc=$?
  test "$rc" = "0" || fail "2.1 lint of all prompts against origin/main in C.UTF-8 exited $rc: $(grep -E '^ERROR|^comm' <<< "$out1" | head -n 3 | tr '\n' '|')"
  out2="$(LC_ALL="$loc" bash scripts/lint-prompts.sh --baseline origin/main 2>&1)"; rc=$?
  test "$rc" = "0" || fail "2.1 lint of all prompts against origin/main in $loc exited $rc: $(grep -E '^ERROR|^comm' <<< "$out2" | head -n 3 | tr '\n' '|')"
  test "$(grep -E '^(ERROR|EXISTING)' <<< "$out1")" = "$(grep -E '^(ERROR|EXISTING)' <<< "$out2")" || fail "2.1 lint gives different results in C.UTF-8 and $loc"
  test "$(grep -c '^ERROR' <<< "$out1")" = "0" || fail "2.1 lint reports an ERROR in the prompts of this branch"
  test "$(grep -c '^EXISTING' <<< "$out1")" = "152" || fail "2.1 expected 152 EXISTING lines; got $(grep -c '^EXISTING' <<< "$out1")"
  for r in L8=2 L9=19 L10=10 L11=28; do
    n="${r#*=}"; r="${r%=*}"
    test "$(grep -c "^EXISTING .*\[$r\]" <<< "$out1")" = "$n" || fail "2.1 expected $n EXISTING lines of rule $r"
  done
  echo "CHECKPOINT B PASS"
}

b_C() {
  local n5 nc nr hb hr
  test "$(grep -cF -- 'a separate scoped CI/dependency compatibility follow-up' CURRENT-STATE.md)" = "0" || fail "3.1 old status still present"
  test "$(cnt '| PR #237 CI | Browser Tests cannot install browsers: Playwright 1.56.0 does not support the runner'"'"'s `ubuntu26.04-x64` platform | **Implemented in R5c** — the four workflows run on `ubuntu-24.04` (PLAN-034); `browser-tests.yml` also starts when its own file changes |' CURRENT-STATE.md)" = "1" || fail "3.1"
  test "$(grep -cF -- 'Pending operator post-merge check' CURRENT-STATE.md)" = "0" || fail "3.2 old status still present"
  test "$(cnt '| PR #237 external review A | Exercise the documentation CI fast path on a clean GitHub runner after the PyYAML fix | **Done after the R5 merge** — in the operator'"'"'s PR #238 (closed, never merged) `preflight-and-compile` took the fast path and passed in 26 seconds |' CURRENT-STATE.md)" = "1" || fail "3.2"
  grep -A2 -F -- '| **Done after the R5 merge** —' CURRENT-STATE.md | sed -n '2p' | grep -q '^| R5 after-merge check | ' || fail "3.3 the first new row must follow the row of item 3.2"
  grep -A2 -F -- '| **Done after the R5 merge** —' CURRENT-STATE.md | sed -n '3p' | grep -q '^| R5c planning (CI logs) | ' || fail "3.3 the second new row must follow the first"
  test "$(grep -cF -- '**Implemented in R5c** — `LC_ALL=C comm -23` (PLAN-034); a fixture run in a non-C locale joins the next fixture production (PLAN-031) |' CURRENT-STATE.md)" = "1" || fail "3.3 first row"
  test "$(grep -cF -- '| **Not implemented** — no job fails yet; the operator decides when a CI maintenance step updates them |' CURRENT-STATE.md)" = "1" || fail "3.3 second row"
  test "$(numstat CURRENT-STATE.md)" = "4 2" || fail "3.1 to 3.3 CURRENT-STATE.md must show 4 added and 2 deleted lines; it shows $(numstat CURRENT-STATE.md)"
  test "$(grep -c '^_Next action: R5r, the review-runner PR' CURRENT-STATE.md)" = "1" || fail "3.x the Next action line must stay R5r"
  test "$(grep -cF -- 'The last merged step is **R5**,' Docs/plan-of-record.md)" = "0" || fail "3.4 old text still present"
  test "$(cnt 'The next step is **R5r**, the review-runner PR. The last merged step is **R5c**, the CI runner pin.' Docs/plan-of-record.md)" = "1" || fail "3.4"
  test "$(grep -cF -- 'Done: the pull request that added `scripts/scope-gate.py`' Docs/plan-of-record.md)" = "0" || fail "3.5 old status still present"
  n5="$(grep -nxF -- '| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | Done 2026-11-16, PR #237 (`1a7bf84`) |' Docs/plan-of-record.md | cut -d: -f1)"
  test -n "$n5" || fail "3.5"
  nc="$(grep -nxF -- '| 5a | R5c | CI runner pin (LOW): the four workflows on `ubuntu-24.04`, lint baseline mode in the C locale, two planner rules, the start prompt for a planning session | SP without the device moves | R5 | Unchanged | 1 to 2 | Done: the pull request that pinned the runners to `ubuntu-24.04` |' Docs/plan-of-record.md | cut -d: -f1)"
  test -n "$nc" || fail "3.6"
  test "$(grep -c '^| 5a | R5r |' Docs/plan-of-record.md)" = "0" || fail "3.7 the old row of R5r is still present"
  nr="$(grep -nxF -- '| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Waiting |' Docs/plan-of-record.md | cut -d: -f1)"
  test -n "$nr" || fail "3.7"
  test "$nc" = "$((n5 + 1))" && test "$nr" = "$((nc + 1))" || fail "3.5 to 3.7 the rows of R5, R5c and R5r must stand one after the other"
  test "$(grep -c '^| 5a |' Docs/plan-of-record.md)" = "1" && test "$(grep -c '^| 5b |' Docs/plan-of-record.md)" = "1" || fail "3.6 and 3.7 the ladder numbers 5a and 5b must each appear once"
  hb="$(grep -nxF '### R5c: CI runner pin (LOW)' Docs/plan-of-record.md | cut -d: -f1)"
  hr="$(grep -nxF '### R5r: review-runner PR (MEDIUM)' Docs/plan-of-record.md | cut -d: -f1)"
  test -n "$hb" && test -n "$hr" && test "$hr" = "$((hb + 12))" || fail "3.8 the block of R5c must hold 11 lines and one blank line directly before the block of R5r"
  test "$(sed -n "$((hb + 1))p;$((hb + 11))p" Docs/plan-of-record.md | tr -d '\n')" = "" || fail "3.8 a blank line must follow the heading and end the block"
  test "$(grep -cxF -- '- Done when: merged; Browser Tests is green on the pull request and on `main`; the lint fixtures pass in `C.UTF-8` and in `en_US.UTF-8`.' Docs/plan-of-record.md)" = "1" || fail "3.8 done-when line"
  test "$(numstat Docs/plan-of-record.md)" = "16 3" || fail "3.4 to 3.8 Docs/plan-of-record.md must show 17 added and 3 deleted lines; it shows $(numstat Docs/plan-of-record.md)"
  test "$(grep -c '^| 2026-11-17 | PLAN-034 |' Docs/decisions/decision-log.md)" = "1" || fail "3.9"
  grep -A1 -F -- '| 2026-11-16 | PLAN-033 |' Docs/decisions/decision-log.md | sed -n '2p' | grep -q '^| 2026-11-17 | PLAN-034 | R5c, ' || fail "3.9 the row of PLAN-034 must follow the row of PLAN-033"
  test "$(grep -c '^| ' Docs/decisions/decision-log.md)" = "58" || fail "3.9 decision log table rows (57 before, 58 after)"
  test "$(tail -n 1 Docs/decisions/decision-log.md)" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "3.9 the last line of the log changed"
  test "$(numstat Docs/decisions/decision-log.md)" = "1 0" || fail "3.9 Docs/decisions/decision-log.md must show 1 added line; it shows $(numstat Docs/decisions/decision-log.md)"
  test "$(cnt 'Manual trigger via `workflow_dispatch` is always available.' Docs/development-process-guide.md)" = "0" || fail "3.10 old line still present"
  test "$(grep -cF -- 'Every workflow runs on `ubuntu-24.04`, not `ubuntu-latest`, so the operating system of a job changes only through a pull request (PLAN-034).' Docs/development-process-guide.md)" = "1" || fail "3.10"
  test "$(grep -cF -- 'is always available' Docs/development-process-guide.md)" = "0" || fail "3.10 the old claim is still in the file"
  test "$(numstat Docs/development-process-guide.md)" = "1 1" || fail "3.10 Docs/development-process-guide.md must show 1 added and 1 deleted line; it shows $(numstat Docs/development-process-guide.md)"
  test "$(sha Docs/planner-start-here.md)" = "bdb217899ee214e04071e911381e4a2da72c1b0da7aebe53089f858be008bad6" || fail "3.11 Docs/planner-start-here.md differs from the supplied file"
  test "$(sha Docs/operator/R5c-runner-pin.md)" = "ceca461aa4280c3d6eec6132c622bb8c8c98f69c5917bb15f00ed960efc48c58" || fail "3.11 Docs/operator/R5c-runner-pin.md differs from the supplied file"
  test "$(sha "$P-review.md")" = "aa6c19547a550020d7314a91219db70bb4f459eb83ae51e931b7166e334e1dc4" || fail "3.11 $P-review.md differs from the supplied file"
  test "$(sed -n '/^```mermaid$/,/^```$/p' Docs/plan-of-record.md Docs/operator/R5c-runner-pin.md | grep -c ';')" = "0" || fail "3.11 a semicolon inside a Mermaid block"
  echo "CHECKPOINT C PASS"
}

b_D() {
  test -f "$P.md" || fail "4.1 $P.md is missing"
  test "$(grep -c '^## §[1-9] ' "$P.md")" = "9" || fail "4.1 the record file must have nine sections '## §1 ' to '## §9 '"
  test "$(grep -c '<NN>' "$P.md")" = "0" || fail "4.1 <NN> is left in the record file"
  test "$(grep -c '^| PLAN-034 | R5c before R5r:' "$P.md")" = "1" || fail "4.1 the table of section 6 must hold PLAN-034"
  test "$(cnt 'No issue closes in this step, no milestone changes, and the status table of issue #228 does not change.' "$P.md")" = "1" || fail "4.1 the sentence of section 7 is missing"
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
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^M')" = "10" || fail "expected 10 changed files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^A')" = "5" || fail "expected 5 new files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -vc '^[MA]')" = "0" || fail "a file was deleted or changed its type"
  test -z "$(git diff --name-only "$base" HEAD -- firmware src config dashboard tests partitions package.json package-lock.json)" || fail "a firmware, dashboard, test or package file changed"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
  cmp -s "$P-agent-prompt.md" "$SAVE/runner-pin-2026-11-17-agent-prompt.md" || fail "the committed prompt differs from the saved one"
  cmp -s "$P-checks.sh" "$SAVE/runner-pin-2026-11-17-checks.sh" || fail "the committed check file differs from the saved one"
  mapfile -t f < <(git diff --name-only --no-renames "$base" HEAD -- prompts)
  bash scripts/lint-prompts.sh --baseline origin/main "${f[@]}" || fail "lint of the prompt files of this PR"
  mapfile -t f < <(git diff --name-only --no-renames "$base" HEAD)
  n="$(bash scripts/lint-prompts.sh "${f[@]}" 2>&1 | grep -c '\[L11\]')"
  test "$n" = "0" || fail "rule L11 finds a login literal in a changed file ($n lines)"
  loc="$(other_locale)" || fail "no en_US.UTF-8 locale"
  test "$(fixtures C.UTF-8)" = "lint fixtures: 13 passed, 0 failed" || fail "lint fixtures in C.UTF-8"
  test "$(fixtures "$loc")" = "lint fixtures: 13 passed, 0 failed" || fail "lint fixtures in $loc"
  out="$(bash tests/scope-gate/run-tests.sh 2>&1)" && test "$(tail -n 1 <<< "$out")" = "scope-gate cases: 2 passed, 0 failed" || fail "scope-gate cases"
  bash scripts/preflight.sh || fail "preflight"
  echo "PRE-PR PASS"
}

case "$NAME" in
  sec2) b_sec2 ;;
  scope) b_scope ;;
  copy) b_copy "${2:-}" ;;
  A|B|C|D) "b_$NAME" ;;
  prepr) b_prepr ;;
  *) echo "usage: bash $0 <sec2 | scope | copy 3 | A | B | C | D | prepr>"; exit 2 ;;
esac
