#!/usr/bin/env bash
# R5 check file: every gate and checkpoint of the R5 agent prompt tooling-2026-11-16-agent-prompt.md,
# so that the agent types no check (R3c closure, finding 2; PLAN-031). It also writes the scope
# list and copies the supplied files. Written 2026-11-16 by the planning session; do not edit it.
#
#   bash /root/r5/tooling-2026-11-16-checks.sh <sec2 | scope | copy <1|2|6|8> | A | B | C | D | E | F | G | H | I | prepr>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# It reads no credential: CHECKPOINT C runs the stress-test script with made-up values and a stand-in
# for curl, and never reads ESP_USER or ESP_PASS of your shell.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/r5
BRANCH=tooling/r5-2026-11
BASE_COMMIT=84e8569
NAME="${1:-}"
case "$NAME" in sec2) LABEL="§2" ;; prepr) LABEL="PRE-PR" ;; copy) LABEL="copy ${2:-}" ;; *) LABEL="$NAME" ;; esac
fail() { echo "⛔ CHECKPOINT FAILED - ${LABEL}: $1"; exit 1; }
sha() { sha256sum < "$1" | cut -d' ' -f1; }
cd "$REPO" 2>/dev/null || fail "repository path $REPO"

live_value() { # the yield value of maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h
  grep -A6 '^static void maybe_yield_nvs_scan_(' firmware/core/nvs-persistence.h 2>/dev/null \
    | grep -oE 'pdMS_TO_TICKS\([0-9]+\)' | head -n 1 | grep -oE '[0-9]+'
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

extract_run() { # $1 workflow file, $2 step name: print the run block of that step without its indent
  python3 -I - "$1" "$2" <<'PYEOF'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
hits = [i for i, l in enumerate(lines) if l.strip() == "- name: " + sys.argv[2]]
if len(hits) != 1:
    sys.exit("step '%s' found %d times" % (sys.argv[2], len(hits)))
i = hits[0] + 1
while not lines[i].strip().startswith("run: |"):
    if lines[i].strip().startswith("- name:"):
        sys.exit("step '%s' has no run block" % sys.argv[2])
    i += 1
ind = len(lines[i]) - len(lines[i].lstrip()) + 2
out = []
for l in lines[i + 1:]:
    if l.strip() and len(l) - len(l.lstrip()) < ind:
        break
    out.append(l[ind:] if l.strip() else "")
print("\n".join(out).rstrip("\n"))
PYEOF
}

wf_repo() { # $1 directory: a throwaway repository on main with one file in each kind of path, and origin/main
  ( cd "$1" && git init -q -b main . && git config user.name t && git config user.email t@t \
    && mkdir -p Docs prompts scripts .github/instructions .github/workflows Images \
    && for f in Docs/a.md prompts/p.md README.md AGENTS.md CLAUDE.md CURRENT-STATE.md LICENSE scripts/s.sh \
                .github/copilot-instructions.md .github/instructions/x.instructions.md .github/workflows/ci.yml Images/i.png; do
         echo base > "$f"; done \
    && git add -A && git commit -qm base && git update-ref refs/remotes/origin/main HEAD )
}

wf_run() { # $1 repo, $2 block file, $3 event, $4 commands that make the change; prints "<exit> <docs_only>"
  ( cd "$1" && git checkout -q -B pr origin/main && eval "$4" && git add -A && git commit -q --allow-empty -m change \
    && o="$(mktemp)" && s="$(mktemp)" && r="$(mktemp -d)" \
    && { GITHUB_EVENT_NAME="$3" BASE_REF=main HEAD_SHA="$(git rev-parse HEAD)" RUNNER_TEMP="$r" \
         GITHUB_OUTPUT="$o" GITHUB_STEP_SUMMARY="$s" bash "$2" >/dev/null 2>&1; rc=$?; } \
    && printf '%s %s\n' "$rc" "$(sed -n 's/^docs_only=//p' "$o")" )
}

body_run() { # $1 repo, $2 block file, $3 commands that make the change, $4 PR body; prints the exit code
  ( cd "$1" && git checkout -q -B pr origin/main && eval "$3" && git add -A && git commit -q --allow-empty -m change \
    && r="$(mktemp -d)" \
    && { BASE_REF=main HEAD_SHA="$(git rev-parse HEAD)" RUNNER_TEMP="$r" PR_BODY="$4" bash "$2" >/dev/null 2>&1; echo $?; } )
}

b_sec2() {
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git merge-base --is-ancestor "$BASE_COMMIT" HEAD || fail "$BASE_COMMIT (PR #236) is not an ancestor of HEAD"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s prompts/handoff/phase7/tooling-2026-11-16-agent-prompt.md "$SAVE/tooling-2026-11-16-agent-prompt.md" || fail "the committed prompt differs from $SAVE/tooling-2026-11-16-agent-prompt.md"
  cmp -s prompts/handoff/phase7/tooling-2026-11-16-checks.sh "$SAVE/tooling-2026-11-16-checks.sh" || fail "the committed check file differs from $SAVE/tooling-2026-11-16-checks.sh"
  test -d "$SAVE/files" || fail "$SAVE/files is missing: run the file check of the gate record"
  for t in python3 node npx gzip git sha256sum; do command -v "$t" >/dev/null || fail "the tool $t is missing"; done
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing: preflight would skip the browser test"
  test -d node_modules/html-minifier-terser || fail "node_modules/html-minifier-terser is missing: the pipeline needs it"
  test "$(esphome version 2>/dev/null)" = "Version: 2026.4.1" || fail "ESPHome is not 2026.4.1 (PLAN-016)"
  yaml_python >/dev/null || fail "no Python with PyYAML: neither python3 nor the Python of esphome imports yaml"
  test "$(live_value)" = "5" || fail "the live value of maybe_yield_nvs_scan_() is not 5"
  for p in 'scripts/scope-gate.py' 'tests/scope-gate/run-tests.sh' 'tests/lint-prompts/L8-pass.md' 'tests/lint-prompts/L8-fail.md' 'tests/lint-prompts/v0.0.0.1-agent-prompt-L9-pass.md' 'tests/lint-prompts/v0.0.0.2-agent-prompt-L9-fail.md' 'tests/lint-prompts/L10-pass-agent-prompt.md' 'tests/lint-prompts/L10-fail-agent-prompt.md' 'tests/lint-prompts/L11-pass.md' 'tests/lint-prompts/L11-fail.md' 'tests/lint-prompts/run-fixtures.sh' '.github/workflows/pr-body-check.yml' 'prompts/handoff/phase7/tooling-2026-11-16-review.md' 'prompts/handoff/phase7/tooling-2026-11-16.md' tests/lint-prompts tests/scope-gate; do test ! -e "$p" || fail "$p already exists"; done
  test "$(grep -cxF -- '# Exit 1 — at least one net-new violation (ERROR) found' scripts/lint-prompts.sh)" = "1" || fail "2.1 anchor"
  test "$(grep -cxF -- '    *)  echo "Unknown rule $1" ;;' scripts/lint-prompts.sh)" = "1" || fail "2.2 anchor"
  test "$(grep -cxF -- '# $1 = path to file whose content to scan' scripts/lint-prompts.sh)" = "1" || fail "2.3 anchor"
  test "$(grep -cxF -- '  local src="$1"' scripts/lint-prompts.sh)" = "1" || fail "2.4 anchor"
  test "$(grep -cxF -- '  # L7: §9 compound pattern (case-insensitive)' scripts/lint-prompts.sh)" = "1" || fail "2.5 anchor"
  test "$(grep -cxF -- '# Build a sorted set of dedup keys "RULE_ID <TAB> LINE_CONTENT" from' scripts/lint-prompts.sh)" = "1" || fail "2.6 anchor"
  test "$(grep -cxF -- '  collect_fail_violations "$file" > "$violations"' scripts/lint-prompts.sh)" = "1" || fail "2.7 anchor"
  test "$(grep -cxF -- '  collect_fail_violations "$file" > "$tmp_head"' scripts/lint-prompts.sh)" = "1" || fail "2.8 anchor"
  test "$(grep -cxF -- '    collect_fail_violations "$base_src" > "$tmp_base"' scripts/lint-prompts.sh)" = "1" || fail "2.9 anchor"
  test "$(grep -cxF -- 'printf '"'"'lint-prompts: checking %d file(s)%s\n'"'"' \' scripts/lint-prompts.sh)" = "1" || fail "2.10 anchor"
  test "$(grep -cxF -- '#   - curl and jq installed' scripts/stress-test-httpd-stack.sh)" = "1" || fail "3.1 anchor"
  test "$(grep -cF -- 'AUTH="${ESP_AUTH:-' scripts/stress-test-httpd-stack.sh)" = "1" || fail "3.2 anchor"
  test "$(grep -cxF -- '    # Required status checks must run for documentation-only PRs too.' .github/workflows/ci.yml)" = "1" || fail "4.1 anchor"
  test "$(grep -cxF -- '        uses: actions/checkout@v4' .github/workflows/ci.yml)" = "1" || fail "4.2 anchor"
  test "$(grep -cxF -- '      - name: Install dependencies' .github/workflows/ci.yml)" = "1" || fail "4.3 anchor"
  test "$(grep -cxF -- '      - name: Minify dashboard' .github/workflows/ci.yml)" = "1" || fail "4.4 anchor"
  test "$(grep -cxF -- '      - name: Regenerate dashboard.h from minified source' .github/workflows/ci.yml)" = "1" || fail "4.5 anchor"
  test "$(grep -cxF -- '      - name: Compile firmware' .github/workflows/ci.yml)" = "1" || fail "4.6 anchor"
  test "$(grep -cxF -- '    npx playwright test tests/browser/manifest.spec.js --project=chromium >/dev/null' scripts/preflight.sh)" = "1" || fail "5.1 anchor"
  test "$(grep -cxF -- '    pass "playwright_manifest_spec"' scripts/preflight.sh)" = "1" || fail "5.1 anchor"
  test "$(grep -cxF -- '      - '"'"'scripts/lint-prompts.sh'"'"'' .github/workflows/prompt-lint.yml)" = "1" || fail "6.2 anchor"
  test "$(grep -cxF -- '      - name: Write lint summary' .github/workflows/prompt-lint.yml)" = "1" || fail "6.3 anchor"
  test "$(grep -cxF -- 'gzip -9 -c "$INPUT" > "$TMPGZ"' scripts/generate-header.sh)" = "1" || fail "7.1 anchor"
  test "$(grep -cF -- '_Next action: ' CURRENT-STATE.md)" = "1" || fail "8.1 anchor"
  test "$(grep -cxF -- '1. **R5, R5r, R5a, R5b** — the tooling PR, the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.' CURRENT-STATE.md)" = "1" || fail "8.2 anchor"
  test "$(grep -cxF -- '| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Not implemented** — code change, needs its own PR |' CURRENT-STATE.md)" = "1" || fail "8.3 anchor"
  test "$(grep -cxF -- '| PR #234 | `scripts/preflight.sh` sends the browser test'"'"'s report to `/dev/null`, so a failure leaves no evidence | **Not implemented** — routed to the tooling PR (PLAN-020) |' CURRENT-STATE.md)" = "1" || fail "8.4 anchor"
  test "$(grep -cxF -- '| PR #235 review (Muse) | Literal management login remains in live test scripts and historical records; the housekeeping scrub covers only seven named files | **Not implemented** — live-script cleanup and secret rotation routed to v7.7.1.5 (SEC-003); historical records and git history retain old values |' CURRENT-STATE.md)" = "1" || fail "8.5 anchor"
  test "$(grep -cxF -- 'The next step is **R5**, the tooling PR. The last merged step is **R3c**, the pull request that added this file.' Docs/plan-of-record.md)" = "1" || fail "8.6 anchor"
  test "$(grep -cxF -- '| 4a | R3c | Plan into the repository: this file, entry points by role, the archive of `Docs/`, the instruction files, the stop rules | Dispatch, review, merge | R3b | 7.7.1.1 | 2 to 3 | Done: the pull request that added this file |' Docs/plan-of-record.md)" = "1" || fail "8.7 anchor"
  test "$(grep -cxF -- '| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login | SP without the device moves | R3c | Unchanged | 2 to 3 | Waiting |' Docs/plan-of-record.md)" = "1" || fail "8.8 anchor"
  test "$(grep -cxF -- '- Scope, and nothing else (PLAN-017, PLAN-020, PLAN-028):' Docs/plan-of-record.md)" = "1" || fail "8.9 anchor"
  test "$(grep -cxF -- '  8. A PR-body check that fails when a pull request that touches `prompts/**` has no "Pre-Implementation Verification" heading.' Docs/plan-of-record.md)" = "1" || fail "8.10 anchor"
  test "$(grep -cxF -- '- Each lint rule gets one passing and one failing fixture under `tests/lint-prompts/`, with made-up values only, and works in `--baseline` mode, so old prompts report EXISTING and do not block.' Docs/plan-of-record.md)" = "1" || fail "8.11 anchor"
  test "$(grep -cxF -- '- R5 also decides whether the planning tools (the prompt builder and the rehearsal script) and the operator'"'"'s helper file enter the repository (section 10).' Docs/plan-of-record.md)" = "1" || fail "8.12 anchor"
  test "$(grep -cxF -- '- Done when: merged; `bash scripts/lint-prompts.sh` runs the new rules, each with its two fixtures; `scripts/scope-gate.py` passes its two cases; the stress-test script stops without a login in the environment; a documentation-only pull request skips the compile; issue #228 §C is closed.' Docs/plan-of-record.md)" = "1" || fail "8.13 anchor"
  test "$(grep -cF -- '| Lint errors that exist in old prompts must not block new work |' Docs/plan-of-record.md)" = "1" || fail "8.14 anchor"
  test "$(grep -cF -- '| The planning tools (prompt builder, rehearsal script) and the operator'"'"'s helper file' Docs/plan-of-record.md)" = "1" || fail "8.15 anchor"
  test "$(grep -cF -- '| Copilot did not complete its review of PR #234' Docs/plan-of-record.md)" = "1" || fail "8.16 anchor"
  test "$(grep -cF -- '| 2026-11-16 | PLAN-030 |' Docs/decisions/decision-log.md)" = "1" || fail "8.17 anchor"
  test "$(grep -cxF -- '12) Stops: a known tooling defect with a recovery written in the prompt gets that recovery once, with the result posted, and a second failure stops; a value you would have to ask for is in the prompt; a real mismatch (a missing anchor, a different value, a path out of scope, a test failing twice) always stops with the checkpoint-failure comment of §3.2' Docs/development-process-guide.md)" = "1" || fail "8.18 anchor"
  test "$(grep -cxF -- 'Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance.' Docs/development-process-guide.md)" = "1" || fail "8.19 anchor"
  test "$(grep -cF -- 'Claude Code is the fallback coding agent (PLAN-026).' Docs/development-process-guide.md)" = "1" || fail "8.20 anchor"
  test "$(grep -cxF -- 'which invokes `scripts/lint-prompts.sh` against the PR'"'"'s changed files. ERROR-level violations' Docs/development-process-guide.md)" = "1" || fail "8.21 anchor"
  test "$(grep -cxF -- '(L1–L5, L7: stale IPs, wrong filenames, forbidden section titles, cross-prompt references)' Docs/development-process-guide.md)" = "1" || fail "8.21 anchor"
  test "$(grep -cxF -- 'fail the PR. WARN-level findings (L6: pipeline-ordering advisory) are reported without blocking.' Docs/development-process-guide.md)" = "1" || fail "8.21 anchor"
  test "$(grep -cxF -- 'The CI workflow (`.github/workflows/ci.yml`) runs its `preflight-and-compile` job on every pull request to `main`, documentation-only ones too: branch protection requires that check, and a required check that a path filter skips blocks the merge (PLAN-020). On a push to `main` the workflow still runs only for changes to code, config, scripts and build files.' Docs/development-process-guide.md)" = "1" || fail "8.22 anchor"
  test "$(grep -cxF -- '6. Hand over: the prompt, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text.' Docs/planner-start-here.md)" = "1" || fail "8.23 anchor"
  test "$(grep -cxF -- '## Rules that came from review findings (PR #234, PR #235)' Docs/planner-start-here.md)" = "1" || fail "8.24 anchor"
  test "$(grep -cxF -- '- A prompt that changes a file an agent loads (`AGENTS.md`, `CLAUDE.md`, the Copilot files) says so in the review file, because Copilot reads these files from the head branch of the pull request.' Docs/planner-start-here.md)" = "1" || fail "8.25 anchor"
  test "$(sha scripts/lint-prompts.sh)" = "bb3c8856be5195568bdf7d747d419b82e8bab12e3f28ae76d52305d3d76388ad" || fail "scripts/lint-prompts.sh differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha scripts/stress-test-httpd-stack.sh)" = "a4f0917e286501ef46385b68958e2183ed3d0114c87895a3c9f0bf6c793e82b7" || fail "scripts/stress-test-httpd-stack.sh differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha .github/workflows/ci.yml)" = "8911d391509aea04b268004c8b5c65d0e83c0e6b1702065d7c86c2d9d7aa4a9d" || fail ".github/workflows/ci.yml differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha scripts/preflight.sh)" = "976aa636550c2bc36325639b489dfb195cb2dad88e58a5cbcf73584e6d0fe09d" || fail "scripts/preflight.sh differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha .github/workflows/prompt-lint.yml)" = "e0028104543af5f613a573ca1320e547f202749be653b51b8fca6b7562872889" || fail ".github/workflows/prompt-lint.yml differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha scripts/generate-header.sh)" = "bad3e783093a1d8e7ce261fdb437207cd5200edf01fb247487b2c75718ef55e5" || fail "scripts/generate-header.sh differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha dashboard/dashboard.h)" = "899346140dee4b38998326f888ba6cabab7d266f5a3c10c8220e1748366a023e" || fail "dashboard/dashboard.h differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha CURRENT-STATE.md)" = "2b50b6a52aeb073cc71df2f2c289bbf09c6fc44b409259bdf6c5800bf6b75e2e" || fail "CURRENT-STATE.md differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha Docs/plan-of-record.md)" = "fc5a87e6156d9e00a7898484652cc9a79f2ef7b9bbb7e100b0edb80d92fe9209" || fail "Docs/plan-of-record.md differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha Docs/decisions/decision-log.md)" = "f146bd28800adb856b6a82746d548b19a9fa4dc3a3a616cf9546bbfbeafeecbd" || fail "Docs/decisions/decision-log.md differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha Docs/development-process-guide.md)" = "c6f1237f6325844a41ff838d2adbd2ccb7a639ef1da664041d781ff4b879c9da" || fail "Docs/development-process-guide.md differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha Docs/planner-start-here.md)" = "6d1da8fe3e63c861ddad216cb68fd4046ac35b2065ee61c7e282f91f294c31f1" || fail "Docs/planner-start-here.md differs from main at 84e8569: the planning session renders the prompt again"
  test "$(sha Docs/operator/R5-tooling.md)" = "dceb8fe45eef96f776e226377fec09a1ae9f04c7067c9c891e41451ec8b208ae" || fail "Docs/operator/R5-tooling.md differs from main at 84e8569: the planning session renders the prompt again"
  echo "§2 PASS"
}

b_scope() {
  local a; a="$(git rev-parse --git-path scope-allowed.txt)" || fail "git rev-parse"
  cat > "$a" <<'EOF'
scripts/lint-prompts.sh
scripts/stress-test-httpd-stack.sh
.github/workflows/ci.yml
scripts/preflight.sh
.github/workflows/prompt-lint.yml
scripts/generate-header.sh
dashboard/dashboard.h
CURRENT-STATE.md
Docs/plan-of-record.md
Docs/decisions/decision-log.md
Docs/development-process-guide.md
Docs/planner-start-here.md
Docs/operator/R5-tooling.md
scripts/scope-gate.py
tests/scope-gate/run-tests.sh
tests/lint-prompts/L8-pass.md
tests/lint-prompts/L8-fail.md
tests/lint-prompts/v0.0.0.1-agent-prompt-L9-pass.md
tests/lint-prompts/v0.0.0.2-agent-prompt-L9-fail.md
tests/lint-prompts/L10-pass-agent-prompt.md
tests/lint-prompts/L10-fail-agent-prompt.md
tests/lint-prompts/L11-pass.md
tests/lint-prompts/L11-fail.md
tests/lint-prompts/run-fixtures.sh
.github/workflows/pr-body-check.yml
prompts/handoff/phase7/tooling-2026-11-16-review.md
prompts/handoff/phase7/tooling-2026-11-16.md
prompts/handoff/phase7/tooling-2026-11-16-agent-prompt.md
prompts/handoff/phase7/tooling-2026-11-16-checks.sh
EOF
  test "$(grep -c . "$a")" = "29" || fail "the scope list does not hold 29 paths"
  echo "scope list written: 29 paths"
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
    1)
      copy_one 'scripts/scope-gate.py' db93e1c797248729b9f5bf874b3a1f1e6a5a47deb0c4cd3f4bccdca3878a3421 new
      copy_one 'tests/scope-gate/run-tests.sh' 7fe7e28252ca27f6ea119411e39a9b05d5012dd2760b8b19894c23f0140f9924 new
      echo "copied 2 files" ;;
    2)
      copy_one 'tests/lint-prompts/L8-pass.md' 06207b029efeacd49192940438cc4033772c7e978579dce4676d9fa89dfbde3b new
      copy_one 'tests/lint-prompts/L8-fail.md' d2fbe188fa3917b3114e991eb9303f918147fdf9a87741b2262a480019bbd4ee new
      copy_one 'tests/lint-prompts/v0.0.0.1-agent-prompt-L9-pass.md' f586b87f71357d6d27929af36d31dace07fcec2d16c40c86b88cbcdb3c98f402 new
      copy_one 'tests/lint-prompts/v0.0.0.2-agent-prompt-L9-fail.md' d2c896f9f0be4a3958d37c5cc7bd7ba7f9eada98f8ed7c96da386690451d80a8 new
      copy_one 'tests/lint-prompts/L10-pass-agent-prompt.md' 5801db30fa9e7bde292e78caf399a17ef4f505e297d54d22556363eae5f7cac6 new
      copy_one 'tests/lint-prompts/L10-fail-agent-prompt.md' e0487cde13e5683e20647c81feaae93e315b93ee958e1be8c5c33e358bc221d3 new
      copy_one 'tests/lint-prompts/L11-pass.md' 67c83e994e80be769eccaa653fb0f000cb8060f85432e66cbe997f9b87704709 new
      copy_one 'tests/lint-prompts/L11-fail.md' 9aed51797fe403e15b39c221ffede75fc9412972a973078bca3ccf5be15d661b new
      copy_one 'tests/lint-prompts/run-fixtures.sh' d61325e1f3dad04d721474b296e21f44c8493be0ef0e689cc2b3ecd6a39d8676 new
      echo "copied 9 files" ;;
    6)
      copy_one '.github/workflows/pr-body-check.yml' d118d04bce49fdf88bc8c88c1b633aab0fa906118d7d9754bdf34334d713a958 new
      echo "copied 1 file" ;;
    8)
      copy_one 'Docs/operator/R5-tooling.md' 377e78769dc29840b925865f5537e00f6015edd85f3a9631301720bff0c93dd2 dceb8fe45eef96f776e226377fec09a1ae9f04c7067c9c891e41451ec8b208ae
      copy_one 'prompts/handoff/phase7/tooling-2026-11-16-review.md' 26372cc6e5e9e9780be30701f2fd6eeff85d2e43fb106369bb379507151c1a3d new
      echo "copied 2 files" ;;
    *) fail "unknown group '${1:-}'" ;;
  esac
}

b_A() {
  local out rc
  test "$(sha scripts/scope-gate.py)" = "db93e1c797248729b9f5bf874b3a1f1e6a5a47deb0c4cd3f4bccdca3878a3421" || fail "1.1 scripts/scope-gate.py is not templates/scope-gate.py of HowTo v2.3.1"
  test "$(sha tests/scope-gate/run-tests.sh)" = "7fe7e28252ca27f6ea119411e39a9b05d5012dd2760b8b19894c23f0140f9924" || fail "1.1 tests/scope-gate/run-tests.sh differs from the supplied file"
  out="$(bash tests/scope-gate/run-tests.sh 2>&1)"; rc=$?
  test "$rc" = "0" && test "$(tail -n 1 <<< "$out")" = "scope-gate cases: 2 passed, 0 failed" \
    || fail "1.2 the scope-gate cases (exit $rc): $(tail -n 4 <<< "$out" | tr '\n' '|')"
  echo "CHECKPOINT A PASS"
}

b_B() {
  local out rc r n
  test "$(grep -cF -- '# Exit 2 — rule L8 cannot read the live value it compares with' scripts/lint-prompts.sh)" = "1" || fail "2.1"
  test "$(grep -cF -- '    L8) echo "Rule 61 delay drift — a pdMS_TO_TICKS value within 3 lines of '"'"'Rule 61'"'"' differs from the live value in maybe_yield_nvs_scan_()" ;;' scripts/lint-prompts.sh)" = "1" || fail "2.2"
  test "$(grep -cF -- '# $2 = repository path of that file; rules L9 and L10 read its name (default: $1)' scripts/lint-prompts.sh)" = "1" || fail "2.3"
  test "$(grep -cxF -- '  local src="$1" name="${2:-$1}"' scripts/lint-prompts.sh)" = "1" || fail "2.4"
  test "$(grep -cF -- '  # L8: Rule 61 delay drift (issue #228 §C13, R5)' scripts/lint-prompts.sh)" = "1" || fail "2.5"
  test "$(grep -cF -- '# L11 helper: succeed when the line holds a login literal. A login literal is a value after -u or' scripts/lint-prompts.sh)" = "1" || fail "2.6"
  test "$(grep -cF -- '  collect_fail_violations "$file" > "$violations"' scripts/lint-prompts.sh)" = "0" || fail "2.7 old text still present"
  test "$(grep -cxF -- '  collect_fail_violations "$file" "$file" > "$violations"' scripts/lint-prompts.sh)" = "1" || fail "2.7"
  test "$(grep -cF -- '  collect_fail_violations "$file" > "$tmp_head"' scripts/lint-prompts.sh)" = "0" || fail "2.8 old text still present"
  test "$(grep -cxF -- '  collect_fail_violations "$file" "$file" > "$tmp_head"' scripts/lint-prompts.sh)" = "1" || fail "2.8"
  test "$(grep -cF -- '    collect_fail_violations "$base_src" > "$tmp_base"' scripts/lint-prompts.sh)" = "0" || fail "2.9 old text still present"
  test "$(grep -cxF -- '    collect_fail_violations "$base_src" "$file" > "$tmp_base"' scripts/lint-prompts.sh)" = "1" || fail "2.9"
  test "$(grep -cF -- '# Rule L8 compares with the live yield value of maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h.' scripts/lint-prompts.sh)" = "1" || fail "2.10"
  bash -n scripts/lint-prompts.sh || fail "2.x scripts/lint-prompts.sh has a syntax error"
  test "$(sha tests/lint-prompts/L8-pass.md)" = "06207b029efeacd49192940438cc4033772c7e978579dce4676d9fa89dfbde3b" || fail "2.11 tests/lint-prompts/L8-pass.md differs from the supplied file"
  test "$(sha tests/lint-prompts/L8-fail.md)" = "d2fbe188fa3917b3114e991eb9303f918147fdf9a87741b2262a480019bbd4ee" || fail "2.11 tests/lint-prompts/L8-fail.md differs from the supplied file"
  test "$(sha tests/lint-prompts/v0.0.0.1-agent-prompt-L9-pass.md)" = "f586b87f71357d6d27929af36d31dace07fcec2d16c40c86b88cbcdb3c98f402" || fail "2.11 tests/lint-prompts/v0.0.0.1-agent-prompt-L9-pass.md differs from the supplied file"
  test "$(sha tests/lint-prompts/v0.0.0.2-agent-prompt-L9-fail.md)" = "d2c896f9f0be4a3958d37c5cc7bd7ba7f9eada98f8ed7c96da386690451d80a8" || fail "2.11 tests/lint-prompts/v0.0.0.2-agent-prompt-L9-fail.md differs from the supplied file"
  test "$(sha tests/lint-prompts/L10-pass-agent-prompt.md)" = "5801db30fa9e7bde292e78caf399a17ef4f505e297d54d22556363eae5f7cac6" || fail "2.11 tests/lint-prompts/L10-pass-agent-prompt.md differs from the supplied file"
  test "$(sha tests/lint-prompts/L10-fail-agent-prompt.md)" = "e0487cde13e5683e20647c81feaae93e315b93ee958e1be8c5c33e358bc221d3" || fail "2.11 tests/lint-prompts/L10-fail-agent-prompt.md differs from the supplied file"
  test "$(sha tests/lint-prompts/L11-pass.md)" = "67c83e994e80be769eccaa653fb0f000cb8060f85432e66cbe997f9b87704709" || fail "2.11 tests/lint-prompts/L11-pass.md differs from the supplied file"
  test "$(sha tests/lint-prompts/L11-fail.md)" = "9aed51797fe403e15b39c221ffede75fc9412972a973078bca3ccf5be15d661b" || fail "2.11 tests/lint-prompts/L11-fail.md differs from the supplied file"
  test "$(sha tests/lint-prompts/run-fixtures.sh)" = "d61325e1f3dad04d721474b296e21f44c8493be0ef0e689cc2b3ecd6a39d8676" || fail "2.11 tests/lint-prompts/run-fixtures.sh differs from the supplied file"
  out="$(bash tests/lint-prompts/run-fixtures.sh 2>&1)"; rc=$?
  test "$rc" = "0" && test "$(tail -n 1 <<< "$out")" = "lint fixtures: 13 passed, 0 failed" \
    || fail "2.x the lint fixtures (exit $rc): $(grep '^FAIL' <<< "$out" | head -n 3 | tr '\n' '|') $(tail -n 1 <<< "$out")"
  out="$(bash scripts/lint-prompts.sh --baseline origin/main 2>&1)"; rc=$?
  test "$rc" = "0" || fail "2.x lint of all prompts against origin/main exited $rc: $(grep '^ERROR' <<< "$out" | head -n 3 | tr '\n' '|')"
  for r in L8 L9 L10 L11; do
    test "$(grep -c "^ERROR .*\[$r\]" <<< "$out")" = "0" || fail "2.x rule $r reports an ERROR in the prompts of main"
  done
  for r in L8=2 L9=19 L10=10 L11=28; do
    n="${r#*=}"; r="${r%=*}"
    test "$(grep -c "^EXISTING .*\[$r\]" <<< "$out")" = "$n" \
      || fail "2.x expected $n EXISTING lines of rule $r in the prompts of main"
  done
  test "$(bash scripts/lint-prompts.sh scripts/lint-prompts.sh 2>&1 | grep -c '\[L11\]')" = "0" \
    || fail "2.4 scripts/lint-prompts.sh holds a login literal by its own rule L11"
  echo "CHECKPOINT B PASS"
}

b_C() {
  local f=scripts/stress-test-httpd-stack.sh st out rc
  test "$(grep -cF -- '#   - ESP_USER and ESP_PASS set in your shell (SEC-003); the script holds no login and stops without one' scripts/stress-test-httpd-stack.sh)" = "1" || fail "3.1"
  test "$(grep -cF -- 'ESP_AUTH' scripts/stress-test-httpd-stack.sh)" = "0" || fail "3.2 old wording still present"
  test "$(grep -cF -- 'This script holds no login.' scripts/stress-test-httpd-stack.sh)" = "1" || fail "3.2"
  test "$(grep -cE '\$\{[A-Za-z_]+:-[^}]*:[^}]*\}' $f)" = "0" || fail "5.x a default value with a colon is still in $f"
  bash -n $f || fail "5.x $f has a syntax error"
  st="$(mktemp -d)" || fail "mktemp"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "$R5_CURL_LOG"\nexit 7\n' > "$st/curl" && chmod +x "$st/curl" || fail "stand-in for curl"
  : > "$st/log"
  out="$(env -u ESP_USER -u ESP_PASS R5_CURL_LOG="$st/log" PATH="$st:$PATH" bash $f 192.0.2.1 2>&1)"; rc=$?
  test "$rc" = "2" || fail "5.2 without ESP_USER and ESP_PASS the script must exit 2; it exited $rc"
  grep -q 'ESP_USER and ESP_PASS must be set' <<< "$out" || fail "5.2 the script did not say which variables are missing"
  test ! -s "$st/log" || fail "5.2 the script called curl without a login"
  out="$(env -u ESP_PASS ESP_USER=fixture-user R5_CURL_LOG="$st/log" PATH="$st:$PATH" bash $f 192.0.2.1 2>&1)"; rc=$?
  test "$rc" = "2" && test ! -s "$st/log" || fail "5.2 with ESP_PASS unset the script must stop before curl (exit $rc)"
  out="$(env ESP_USER=fixture-user ESP_PASS=fixture-pass R5_CURL_LOG="$st/log" PATH="$st:$PATH" bash $f 192.0.2.1 2>&1)"; rc=$?
  test "$rc" = "1" || fail "5.2 with both variables set the script must try the board and exit 1 when it cannot reach it; it exited $rc"
  test "$(grep -cx 'fixture-user:fixture-pass' "$st/log")" = "1" || fail "5.2 curl did not get the login from ESP_USER and ESP_PASS"
  rm -rf "$st"
  echo "CHECKPOINT C PASS"
}

b_D() {
  local py blk t w
  test "$(grep -cF -- '    # Required status checks must run for documentation-only PRs too.' .github/workflows/ci.yml)" = "0" || fail "4.1 old text still present"
  test "$(grep -cF -- '    # Required status checks must run for documentation-only PRs too (PLAN-020).' .github/workflows/ci.yml)" = "1" || fail "4.1"
  test "$(grep -cF -- '      - name: List changed paths' .github/workflows/ci.yml)" = "1" || fail "4.2"
  test "$(grep -cxF "        if: steps.paths.outputs.docs_only != 'true'" .github/workflows/ci.yml)" = "4" || fail "4.3 to 4.6 expected four steps with the docs_only condition"
  py="$(yaml_python)" || fail "no Python with PyYAML"
  "$py" -I - .github/workflows/ci.yml <<'PYEOF' || fail "4.x the structure of ci.yml (see the line above)"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
on = d.get("on", d.get(True))
if on["pull_request"] != {"branches": ["main"]}:
    sys.exit("the pull_request trigger changed: %r" % on["pull_request"])
steps = d["jobs"]["preflight-and-compile"]["steps"]
names = [s["name"] for s in steps]
if names[0] != "Checkout repository" or steps[0].get("with") != {"fetch-depth": 0}:
    sys.exit("the checkout must fetch the whole history")
if names[1] != "List changed paths" or steps[1].get("id") != "paths":
    sys.exit("the second step must be 'List changed paths' with id 'paths'")
cond = "steps.paths.outputs.docs_only != 'true'"
gated = [s["name"] for s in steps if s.get("if") == cond]
want = ["Install dependencies", "Minify dashboard", "Regenerate dashboard.h from minified source", "Compile firmware"]
if gated != want:
    sys.exit("steps with the docs_only condition: %r" % gated)
if "if" in steps[names.index("Run preflight")]:
    sys.exit("preflight must run on every path")
print("ci.yml structure: ok")
PYEOF
  blk="$(mktemp)" && extract_run .github/workflows/ci.yml "List changed paths" > "$blk" || fail "4.2 cannot read the run block of 'List changed paths'"
  t="$(mktemp -d)" && wf_repo "$t" || fail "4.x cannot build the test repository"
  w() { test "$(wf_run "$t" "$blk" "$1" "$2")" = "0 $3" || fail "4.x event $1, change '$2': docs_only must be $3"; }
  w pull_request 'echo x >> Docs/a.md' true
  w pull_request 'echo x >> prompts/p.md; echo x >> README.md; echo x >> CURRENT-STATE.md' true
  w pull_request 'echo x >> AGENTS.md; echo x >> CLAUDE.md; echo x >> .github/copilot-instructions.md; echo x >> .github/instructions/x.instructions.md' true
  w pull_request 'mkdir -p Docs/new && echo x > Docs/new/b.md' true
  w pull_request 'mkdir -p Docs/archive && git mv Docs/a.md Docs/archive/a.md' true
  w pull_request 'echo x >> scripts/s.sh' false
  w pull_request 'echo x >> Docs/a.md; echo x >> scripts/s.sh' false
  w pull_request 'echo x >> .github/workflows/ci.yml' false
  w pull_request 'echo x >> Images/i.png' false
  w pull_request 'echo x >> LICENSE' false
  w pull_request 'git mv Docs/a.md scripts/a.md' false
  w pull_request 'true' false
  w push 'echo x >> Docs/a.md' false
  w workflow_dispatch 'echo x >> Docs/a.md' false
  test "$(cd "$t" && git checkout -q -B pr origin/main && o="$(mktemp)" && { GITHUB_EVENT_NAME=pull_request BASE_REF=nosuchbranch HEAD_SHA="$(git rev-parse HEAD)" \
    RUNNER_TEMP="$(mktemp -d)" GITHUB_OUTPUT="$o" GITHUB_STEP_SUMMARY=/dev/null bash "$blk" >/dev/null 2>&1; echo $?; })" != "0" \
    || fail "4.x the step must fail, not pass, when it cannot compute the diff"
  rm -rf "$t" "$blk"
  echo "CHECKPOINT D PASS"
}

b_E() {
  local st out rc before
  test "$(grep -cxF -- '    npx playwright test tests/browser/manifest.spec.js --project=chromium >/dev/null' scripts/preflight.sh)" = "0" || fail "5.1 old line still present"
  test "$(grep -cxF -- '    pass "playwright_manifest_spec"' scripts/preflight.sh)" = "0" || fail "5.1 old line still present"
  test "$(grep -cF -- '    if npx playwright test tests/browser/manifest.spec.js --project=chromium >"$PW_LOG" 2>&1; then' scripts/preflight.sh)" = "1" || fail "5.1"
  test -d node_modules/@playwright/test || fail "5.x node_modules/@playwright/test is missing"
  st="$(mktemp -d)" || fail "mktemp"
  printf '#!/usr/bin/env bash\necho "R5-STAND-IN: browser test report, line 1"\necho "R5-STAND-IN: browser test report, line 2"\nexit 1\n' > "$st/npx" \
    && chmod +x "$st/npx" || fail "stand-in for npx"
  before="$(git status --porcelain)"
  out="$(PATH="$st:$PATH" bash scripts/preflight.sh 2>&1)"; rc=$?
  test "$rc" != "0" || fail "5.1 preflight passed although the browser test failed"
  test "$(grep -c 'R5-STAND-IN: browser test report' <<< "$out")" = "2" || fail "5.1 preflight did not print the report of the failed browser test"
  grep -qx 'playwright_manifest_spec: FAIL' <<< "$out" || fail "5.1 preflight did not print 'playwright_manifest_spec: FAIL'"
  test "$(git status --porcelain)" = "$before" || fail "5.1 preflight changed the working tree"
  rm -rf "$st"
  echo "CHECKPOINT E PASS"
}

b_F() {
  local py blk t b
  test "$(grep -cF -- '      - '"'"'scripts/scope-gate.py'"'"'' .github/workflows/prompt-lint.yml)" = "1" || fail "6.2"
  test "$(grep -cF -- '      - name: Run lint fixtures and scope-gate cases' .github/workflows/prompt-lint.yml)" = "1" || fail "6.3"
  test "$(sha .github/workflows/pr-body-check.yml)" = "d118d04bce49fdf88bc8c88c1b633aab0fa906118d7d9754bdf34334d713a958" || fail "6.1 .github/workflows/pr-body-check.yml differs from the supplied file"
  py="$(yaml_python)" || fail "no Python with PyYAML"
  "$py" -I - .github/workflows/pr-body-check.yml .github/workflows/prompt-lint.yml <<'PYEOF' || fail "6.x the structure of the workflows (see the line above)"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
on = d.get("on", d.get(True))
pr = on["pull_request"]
if "paths" in pr or "paths-ignore" in pr or pr.get("branches") != ["main"]:
    sys.exit("pr-body-check must run on every pull request to main")
if "edited" not in pr.get("types", []):
    sys.exit("pr-body-check must run again when the body is edited")
step = d["jobs"]["pr-body-check"]["steps"][1]
if "${{" in step["run"] or step["env"].get("PR_BODY") != "${{ github.event.pull_request.body }}":
    sys.exit("the PR body must come through env, never into the script")
p = yaml.safe_load(open(sys.argv[2], encoding="utf-8"))
pon = p.get("on", p.get(True))
for path in ("scripts/scope-gate.py", "tests/lint-prompts/**", "tests/scope-gate/**"):
    if path not in pon["pull_request"]["paths"]:
        sys.exit("prompt-lint does not start on " + path)
runs = [s.get("run", "") for s in p["jobs"]["prompt-lint"]["steps"] if s["name"] == "Run lint fixtures and scope-gate cases"]
if runs != ["bash tests/lint-prompts/run-fixtures.sh\nbash tests/scope-gate/run-tests.sh\n"]:
    sys.exit("prompt-lint: the step 'Run lint fixtures and scope-gate cases' is missing or differs")
print("workflows structure: ok")
PYEOF
  blk="$(mktemp)" && extract_run .github/workflows/pr-body-check.yml "Check the PR body" > "$blk" || fail "6.1 cannot read the run block of 'Check the PR body'"
  t="$(mktemp -d)" && wf_repo "$t" || fail "6.x cannot build the test repository"
  b() { test "$(body_run "$t" "$blk" "$1" "$2")" = "$3" || fail "6.x change '$1': the check must exit $3"; }
  b 'echo x >> Docs/a.md' '' 0
  b 'echo x >> prompts/p.md' $'## Pre-Implementation Verification\n\n§2 PASS' 0
  b 'echo x >> prompts/p.md' $'### pre-implementation verification\r\n§2 PASS\r\n' 0
  b 'echo x >> prompts/p.md' $'## Summary\nNo gate output here.' 1
  b 'echo x >> prompts/p.md' 'See the Pre-Implementation Verification below.' 1
  b 'echo x >> prompts/p.md' '' 1
  rm -rf "$t" "$blk"
  echo "CHECKPOINT F PASS"
}

b_G() {
  local base t before
  test "$(grep -cF -- 'gzip -9 -c "$INPUT" > "$TMPGZ"' scripts/generate-header.sh)" = "0" || fail "7.1 old text still present"
  test "$(grep -cF -- 'gzip -9 -n -c "$INPUT" > "$TMPGZ"' scripts/generate-header.sh)" = "1" || fail "7.1"
  base="$(git merge-base origin/main HEAD)" || fail "merge-base"
  test "$(git diff --name-only "$base" -- dashboard src config firmware tests/fixtures)" = "dashboard/dashboard.h" \
    || fail "7.2 the pipeline must change dashboard/dashboard.h and no other generated file"
  t="$(mktemp -d)" && git show "$base:dashboard/dashboard.h" > "$t/base.h" || fail "7.2 cannot read the header of main"
  python3 -I - "$t/base.h" dashboard/dashboard.h <<'PYEOF' || fail "7.2 the regenerated header (see the line above)"
import gzip, re, sys
def payload(p):
    t = open(p, encoding="utf-8").read()
    body = t.split("DASHBOARD_HTML_GZ[] DASHBOARD_STORAGE_ATTR = {", 1)[1].split("};", 1)[0]
    return bytes(int(x, 16) for x in re.findall(r"0x([0-9a-f]{2})", body))
old, new = payload(sys.argv[1]), payload(sys.argv[2])
if gzip.decompress(old) != gzip.decompress(new):
    sys.exit("the dashboard inside the header changed")
if new[3] != 0:
    sys.exit("the gzip header still stores a file name")
if new[4:8] != b"\0\0\0\0":
    sys.exit("the gzip header still stores a time")
print("header: the same dashboard, no file name, no time")
PYEOF
  before="$(sha dashboard/dashboard.h)"
  sleep 1 && touch dashboard/dashboard.html
  bash scripts/provision.sh satellite > "$t/provision.log" 2>&1 || fail "7.3 the second pipeline run failed: $(tail -n 3 "$t/provision.log" | tr '\n' '|')"
  test "$(sha dashboard/dashboard.h)" = "$before" || fail "7.3 a second pipeline run changed dashboard/dashboard.h: the header is not reproducible"
  test "$(git diff --name-only "$base" -- dashboard src config firmware tests/fixtures)" = "dashboard/dashboard.h" \
    || fail "7.3 the second pipeline run changed another generated file"
  rm -rf "$t"
  echo "CHECKPOINT G PASS"
}

b_H() {
  test "$(grep -cF -- '_Next action: R5r, the review-runner PR' CURRENT-STATE.md)" = "1" || fail "8.1"
  test "$(grep -cF -- '1. **R5, R5r, R5a, R5b** — the tooling PR, the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.' CURRENT-STATE.md)" = "0" || fail "8.2 old text still present"
  test "$(grep -cxF -- '1. **R5r, R5a, R5b** — the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.' CURRENT-STATE.md)" = "1" || fail "8.2"
  test "$(grep -cF -- '| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Not implemented** — code change, needs its own PR |' CURRENT-STATE.md)" = "0" || fail "8.3 old text still present"
  test "$(grep -cxF -- '| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Implemented in R5** — `scripts/generate-header.sh` compresses with `gzip -n`; the pipeline wrote the header once (PLAN-031) |' CURRENT-STATE.md)" = "1" || fail "8.3"
  test "$(grep -cF -- '| PR #234 | `scripts/preflight.sh` sends the browser test'"'"'s report to `/dev/null`, so a failure leaves no evidence | **Not implemented** — routed to the tooling PR (PLAN-020) |' CURRENT-STATE.md)" = "0" || fail "8.4 old text still present"
  test "$(grep -cxF -- '| PR #234 | `scripts/preflight.sh` sends the browser test'"'"'s report to `/dev/null`, so a failure leaves no evidence | **Implemented in R5** — preflight prints the report when the browser test fails (PLAN-020) |' CURRENT-STATE.md)" = "1" || fail "8.4"
  test "$(grep -cF -- '| PR #235 review (Muse) | Literal management login remains in live test scripts and historical records; the housekeeping scrub covers only seven named files | **Not implemented** — live-script cleanup and secret rotation routed to v7.7.1.5 (SEC-003); historical records and git history retain old values |' CURRENT-STATE.md)" = "0" || fail "8.5 old text still present"
  test "$(grep -cxF -- '| PR #235 review (Muse) | Literal management login remains in live test scripts and historical records; the housekeeping scrub covers only seven named files | **Partly implemented in R5** — `scripts/stress-test-httpd-stack.sh` holds no default login now; `scripts/exporters/system-metrics-exporter.sh` still sets default values for `METRICS_USER` and `METRICS_PASS`; live-script cleanup and secret rotation routed to v7.7.1.5 (SEC-003); historical records and git history retain old values |' CURRENT-STATE.md)" = "1" || fail "8.5"
  test "$(grep -cF -- 'The next step is **R5**, the tooling PR. The last merged step is **R3c**, the pull request that added this file.' Docs/plan-of-record.md)" = "0" || fail "8.6 old text still present"
  test "$(grep -cxF -- 'The next step is **R5r**, the review-runner PR. The last merged step is **R5**, the tooling PR.' Docs/plan-of-record.md)" = "1" || fail "8.6"
  test "$(grep -cF -- '| 4a | R3c | Plan into the repository: this file, entry points by role, the archive of `Docs/`, the instruction files, the stop rules | Dispatch, review, merge | R3b | 7.7.1.1 | 2 to 3 | Done: the pull request that added this file |' Docs/plan-of-record.md)" = "0" || fail "8.7 old text still present"
  test "$(grep -cxF -- '| 4a | R3c | Plan into the repository: this file, entry points by role, the archive of `Docs/`, the instruction files, the stop rules | Dispatch, review, merge | R3b | 7.7.1.1 | 2 to 3 | Done 2026-11-16, PR #236 (`84e8569`) |' Docs/plan-of-record.md)" = "1" || fail "8.7"
  test "$(grep -cF -- '| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login | SP without the device moves | R3c | Unchanged | 2 to 3 | Waiting |' Docs/plan-of-record.md)" = "0" || fail "8.8 old text still present"
  test "$(grep -cxF -- '| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | Done: the pull request that added `scripts/scope-gate.py` |' Docs/plan-of-record.md)" = "1" || fail "8.8"
  test "$(grep -cF -- '- Scope, and nothing else (PLAN-017, PLAN-020, PLAN-028):' Docs/plan-of-record.md)" = "0" || fail "8.9 old text still present"
  test "$(grep -cxF -- '- Scope, and nothing else (PLAN-017, PLAN-020, PLAN-028, PLAN-031):' Docs/plan-of-record.md)" = "1" || fail "8.9"
  test "$(grep -cF -- '  9. `scripts/generate-header.sh` compresses with `gzip -n`, so `dashboard/dashboard.h` changes only when the dashboard changes; R5 writes the header once with the pipeline (PLAN-031).' Docs/plan-of-record.md)" = "1" || fail "8.10"
  test "$(grep -cF -- '- The workflow `prompt-lint` also runs these fixtures and the two scope-gate cases (PLAN-031).' Docs/plan-of-record.md)" = "1" || fail "8.11"
  test "$(grep -cF -- '- R5 also decides whether the planning tools (the prompt builder and the rehearsal script) and the operator'"'"'s helper file enter the repository (section 10).' Docs/plan-of-record.md)" = "0" || fail "8.12 old text still present"
  test "$(grep -cxF -- '- Decided in R5 (PLAN-033): the planning tools (the prompt builder and the rehearsal script) and the operator'"'"'s helper file stay outside the repository.' Docs/plan-of-record.md)" = "1" || fail "8.12"
  test "$(grep -cF -- '- Done when: merged; `bash scripts/lint-prompts.sh` runs the new rules, each with its two fixtures; `scripts/scope-gate.py` passes its two cases; the stress-test script stops without a login in the environment; a documentation-only pull request skips the compile; issue #228 §C is closed.' Docs/plan-of-record.md)" = "0" || fail "8.13 old text still present"
  test "$(grep -cxF -- '- Done when: merged; `bash scripts/lint-prompts.sh` runs the new rules, each with its two fixtures; `scripts/scope-gate.py` passes its two cases; the stress-test script stops without a login in the environment; a documentation-only pull request skips the compile; a second run of the pipeline leaves `dashboard/dashboard.h` unchanged; issue #228 §C is closed.' Docs/plan-of-record.md)" = "1" || fail "8.13"
  test "$(grep -cF -- '| Lint errors that exist in old prompts must not block new work |' Docs/plan-of-record.md)" = "0" || fail "8.14 line still present"
  test "$(grep -cF -- '| The planning tools (prompt builder, rehearsal script) and the operator'"'"'s helper file' Docs/plan-of-record.md)" = "0" || fail "8.15 line still present"
  test "$(grep -cF -- '| Copilot did not complete its review of PR #234' Docs/plan-of-record.md)" = "0" || fail "8.16 line still present"
  test "$(grep -cF -- '| PLAN-033 |' Docs/decisions/decision-log.md)" = "1" || fail "8.17"
  test "$(grep -cF -- '13) Run every gate and checkpoint from the check file that the prompt names, exactly as the prompt says; never type a check by hand' Docs/development-process-guide.md)" = "1" || fail "8.18"
  test "$(grep -cF -- 'Item 13 holds from R5 on (PLAN-031)' Docs/development-process-guide.md)" = "1" || fail "8.19"
  test "$(grep -cF -- 'When Copilot posts no complete review, the agent'"'"'s assessment says so, and the step goes on with the other inline reviews and the external reviews; the operator decides at the merge (PLAN-032).' Docs/development-process-guide.md)" = "1" || fail "8.20"
  test "$(grep -cxF -- 'which invokes `scripts/lint-prompts.sh` against the PR'"'"'s changed files. ERROR-level violations' Docs/development-process-guide.md)" = "0" || fail "8.21 old line still present"
  test "$(grep -cxF -- '(L1–L5, L7: stale IPs, wrong filenames, forbidden section titles, cross-prompt references)' Docs/development-process-guide.md)" = "0" || fail "8.21 old line still present"
  test "$(grep -cxF -- 'fail the PR. WARN-level findings (L6: pipeline-ordering advisory) are reported without blocking.' Docs/development-process-guide.md)" = "0" || fail "8.21 old line still present"
  test "$(grep -cF -- 'block; L11: a login literal after `-u`, `--user` or `Authorization: Basic`) fail the PR. A violation that' Docs/development-process-guide.md)" = "1" || fail "8.21"
  test "$(grep -cF -- 'The job takes a fast path for documentation (PLAN-028). Its step "List changed paths" reads the paths that the pull request changes. When every path is under `Docs/` or `prompts/`, or is `README.md`, `CURRENT-STATE.md`, `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` or a file `.github/instructions/*.instructions.md`, the job runs preflight only: it skips the ESPHome install, the dashboard minify, the header and the compile. Any other path, an empty diff, a push to `main` and a manual run take the full job.' Docs/development-process-guide.md)" = "1" || fail "8.22"
  test "$(grep -cF -- '6. Hand over: the prompt, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text.' Docs/planner-start-here.md)" = "0" || fail "8.23 old text still present"
  test "$(grep -cxF -- '6. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031).' Docs/planner-start-here.md)" = "1" || fail "8.23"
  test "$(grep -cF -- '## Rules that came from review findings (PR #234, PR #235)' Docs/planner-start-here.md)" = "0" || fail "8.24 old text still present"
  test "$(grep -cxF -- '## Rules that came from review findings (PR #234, PR #235, PR #236)' Docs/planner-start-here.md)" = "1" || fail "8.24"
  test "$(grep -cF -- '- Every gate and checkpoint of a prompt is in its check file, which has a known SHA-256; the agent runs the file and never types a check (PR #236: the agent typed the §2 gate by hand, with wrong dates).' Docs/planner-start-here.md)" = "1" || fail "8.25"
  test "$(sha Docs/operator/R5-tooling.md)" = "377e78769dc29840b925865f5537e00f6015edd85f3a9631301720bff0c93dd2" || fail "8.26 Docs/operator/R5-tooling.md differs from the supplied file"
  test "$(sha prompts/handoff/phase7/tooling-2026-11-16-review.md)" = "26372cc6e5e9e9780be30701f2fd6eeff85d2e43fb106369bb379507151c1a3d" || fail "8.26 prompts/handoff/phase7/tooling-2026-11-16-review.md differs from the supplied file"
  test "$(grep -c '^| ' Docs/decisions/decision-log.md)" = "57" || fail "8.17 decision log table rows (54 before, 57 after)"
  test "$(grep -cE '^\| 2026-11-16 \| PLAN-03[1-3] \|' Docs/decisions/decision-log.md)" = "3" || fail "8.17 three new rows"
  test "$(tail -n 1 Docs/decisions/decision-log.md)" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "8.17 the last line of the log changed"
  test "$(grep -c 'The next step is \*\*R5\*\*' Docs/plan-of-record.md)" = "0" || fail "8.6 the old You-are-here line is still in the plan of record"
  test "$(grep -cE 'R5 decides|Watch at R5' Docs/plan-of-record.md)" = "0" || fail "8.14 to 8.16 a finding that R5 owned is still in section 10"
  test "$(grep -c '^| 5 | R5 | .* | Waiting |$' Docs/plan-of-record.md)" = "0" || fail "8.8 the R5 row is still Waiting"
  test "$(grep -c '^_Next action: ' CURRENT-STATE.md)" = "1" || fail "8.1 expected one Next action line"
  test "$(grep -c 'R5, R5r, R5a, R5b' CURRENT-STATE.md)" = "0" || fail "8.2 the old What-is-Next item is still in the file"
  test "$(grep -c 'needs its own PR' CURRENT-STATE.md)" = "0" || fail "8.3 the old status of the header row is still in the file"
  test "$(sed -n '/^```mermaid$/,/^```$/p' Docs/plan-of-record.md Docs/operator/R5-tooling.md | grep -c ';')" = "0" || fail "8.26 a semicolon inside a Mermaid block"
  echo "CHECKPOINT H PASS"
}

b_I() {
  test -f prompts/handoff/phase7/tooling-2026-11-16.md || fail "9.1 prompts/handoff/phase7/tooling-2026-11-16.md is missing"
  test "$(grep -c '^## §[1-9] ' prompts/handoff/phase7/tooling-2026-11-16.md)" = "9" || fail "9.1 the record file must have nine sections '## §1 ' to '## §9 '"
  test "$(grep -c '<NN>' prompts/handoff/phase7/tooling-2026-11-16.md)" = "0" || fail "9.1 <NN> is left in the record file"
  test "$(grep -cE '^\| PLAN-03[1-3] \|' prompts/handoff/phase7/tooling-2026-11-16.md)" = "3" || fail "9.1 the table of section 6 must hold PLAN-031 to PLAN-033"
  test "$(grep -c '^| §C meta-prompt guardrails | CLOSED' prompts/handoff/phase7/tooling-2026-11-16.md)" = "1" || fail "9.1 the table of section 7 must close §C"
  echo "CHECKPOINT I PASS"
}

b_prepr() {
  local base out rc n
  local -a f
  git fetch origin || fail "git fetch"
  python3 scripts/scope-gate.py --allowed "$(git rev-parse --git-path scope-allowed.txt)" --target origin/main \
    || { rc=$?; echo "PRE-PR GATE FAILED (scope-gate exit $rc) - STOP"; exit "$rc"; }
  test -z "$(git status --porcelain)" || fail "uncommitted changes: commit before this gate"
  base="$(git merge-base origin/main HEAD)" || fail "merge-base"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^M')" = "13" || fail "expected 13 changed files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^A')" = "16" || fail "expected 16 new files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -vc '^[MA]')" = "0" || fail "a file was deleted or changed its type"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
  cmp -s prompts/handoff/phase7/tooling-2026-11-16-agent-prompt.md "$SAVE/tooling-2026-11-16-agent-prompt.md" || fail "the committed prompt differs from the saved one"
  cmp -s prompts/handoff/phase7/tooling-2026-11-16-checks.sh "$SAVE/tooling-2026-11-16-checks.sh" || fail "the committed check file differs from the saved one"
  mapfile -t f < <(git diff --name-only --no-renames "$base" HEAD -- prompts)
  bash scripts/lint-prompts.sh --baseline origin/main "${f[@]}" || fail "lint of the prompt files of this PR"
  mapfile -t f < <(git diff --name-only --no-renames "$base" HEAD | grep -vx -e dashboard/dashboard.h -e tests/lint-prompts/L11-fail.md)
  n="$(bash scripts/lint-prompts.sh "${f[@]}" 2>&1 | grep -c '\[L11\]')"
  test "$n" = "0" || fail "rule L11 finds a login literal in a changed file ($n lines)"
  out="$(bash tests/lint-prompts/run-fixtures.sh 2>&1)" && test "$(tail -n 1 <<< "$out")" = "lint fixtures: 13 passed, 0 failed" || fail "lint fixtures"
  out="$(bash tests/scope-gate/run-tests.sh 2>&1)" && test "$(tail -n 1 <<< "$out")" = "scope-gate cases: 2 passed, 0 failed" || fail "scope-gate cases"
  bash scripts/preflight.sh || fail "preflight"
  echo "PRE-PR PASS"
}

case "$NAME" in
  sec2) b_sec2 ;;
  scope) b_scope ;;
  copy) b_copy "${2:-}" ;;
  A|B|C|D|E|F|G|H|I) "b_$NAME" ;;
  prepr) b_prepr ;;
  *) echo "usage: bash $0 <sec2 | scope | copy <1|2|6|8> | A | B | C | D | E | F | G | H | I | prepr>"; exit 2 ;;
esac
