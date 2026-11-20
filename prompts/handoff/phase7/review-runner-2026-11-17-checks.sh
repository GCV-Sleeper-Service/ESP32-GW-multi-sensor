#!/usr/bin/env bash
# R5r check file: every gate and checkpoint of the R5r agent prompt review-runner-2026-11-17-agent-prompt.md,
# so that the agent types no check (PLAN-031). It also writes the scope list and copies the supplied
# files. Written 2026-11-17 and reconciled with the audit on 2026-11-18 by the planning session; do not edit it.
# The texts between "<<'END_OF_TEXT'" and "END_OF_TEXT" are the fenced texts of the prompt, copied by a tool.
#
#   bash /root/r5r/review-runner-2026-11-17-checks.sh <sec2 | scope | copy <1|3> | A | B | C | D | prepr>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# It reads no credential, calls no board and calls no Google service. Temporary files go when it ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/r5r
BRANCH=tooling/r5r-2026-11
BASE_COMMIT=640906f
P=prompts/handoff/phase7/review-runner-2026-11-17
WF=.github/workflows/external-review.yml
SC=scripts/external-review.py
TESTS=tests/external-review/test_external_review.py
NTESTS=31
CS=CURRENT-STATE.md
POR=Docs/plan-of-record.md
DL=Docs/decisions/decision-log.md
PAT=Docs/templates/prompt-audit-template.md
CAT=prompts/phase7/consolidated-audit-template-phase7.md
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
contains() { python3 -I -c 'import sys; sys.exit(0 if sys.stdin.read().rstrip("\n") in open(sys.argv[1], encoding="utf-8").read() else 1)' "$1"; }
cd "$REPO" 2>/dev/null || fail "repository path $REPO"

other_locale() { locale -a 2>/dev/null | grep -m1 -ixE 'en_US\.utf-?8'; }
fixtures() { LC_ALL="$1" bash tests/lint-prompts/run-fixtures.sh > "$TMP/fixtures.log" 2>&1 || { echo "run-fixtures.sh ended with exit $?"; return; }; tail -n 1 "$TMP/fixtures.log"; }
numstat() { git diff --numstat "$(git merge-base origin/main HEAD)" -- "$1" | awk '{print $1, $2}'; }
yaml_python() { # a Python that imports yaml in the mode that block B uses: python3 -I
  local c e
  e="$(command -v esphome 2>/dev/null)" && e="$(dirname "$(readlink -f "$e")")/python3" || e=""
  for c in python3 "$e"; do
    [ -n "$c" ] || continue
    if command -v "$c" >/dev/null 2>&1 && "$c" -I -c 'import yaml' 2>/dev/null; then echo "$c"; return 0; fi
  done
  return 1
}
runner_tests() { python3 -I "$TESTS" > "$TMP/tests.log" 2>&1; }

b_sec2() {
  local p
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git merge-base --is-ancestor "$BASE_COMMIT" HEAD || fail "$BASE_COMMIT (PR #239) is not an ancestor of HEAD"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P-agent-prompt.md" "$SAVE/review-runner-2026-11-17-agent-prompt.md" || fail "the committed prompt differs from $SAVE/review-runner-2026-11-17-agent-prompt.md"
  cmp -s "$P-checks.sh" "$SAVE/review-runner-2026-11-17-checks.sh" || fail "the committed check file differs from $SAVE/review-runner-2026-11-17-checks.sh"
  test -d "$SAVE/files" || fail "$SAVE/files is missing: run the file check of the gate record"
  for t in python3 node npx git sha256sum comm locale env; do command -v "$t" >/dev/null || fail "the tool $t is missing"; done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' || fail "python3 is older than 3.12"
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing: preflight would skip the browser test"
  yaml_python >/dev/null || fail "no Python imports yaml under -I: neither python3 nor the Python of esphome"
  other_locale >/dev/null || fail "no en_US.UTF-8 locale (locale -a): the PRE-PR gate needs it"
  for p in "$WF" "$SC" "$TESTS" Docs/templates/external-review-template.md Docs/operator/R5r-review-runner.md "$P-review.md" "$P-audit.md" "$P.md" tests/external-review; do
    test ! -e "$p" || fail "$p already exists"
  done
  test "$(grep -c '^_Next action: ' "$CS")" = "1" || fail "3.1 anchor: one line that begins '_Next action: '"
  have "$CS" 1 <<'END_OF_TEXT' || fail "3.2 anchor"
1. **R5r, R5a, R5b** — the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.
END_OF_TEXT
  test "$(begins '| R5c planning (CI logs) |' "$CS")" = "1" || fail "3.3 anchor"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.4 anchor"
The next step is **R5r**, the review-runner PR. The last merged step is **R5c**, the CI runner pin.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.5 anchor"
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Waiting |
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.6 anchor"
- The planning document outside the repository is a working notebook. It is not a source (PLAN-024).
END_OF_TEXT
  starts "$POR" 1 <<'END_OF_TEXT' || fail "3.7 anchor"
- Scope: the workflow `.github/workflows/external-review.yml` and its script
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.8 anchor"
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run. Today these are review A and review B (PLAN-019). Section 7 shows the scheme that follows.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.9 anchor"
This scheme takes effect when the review-runner PR is merged (PLAN-022, PLAN-023). Until then PLAN-019 holds: review B is a Muse session in three turns, and there is no review C. Review C is required on MEDIUM and HIGH firmware steps and optional elsewhere.
END_OF_TEXT
  have "$POR" 2 <<'END_OF_TEXT' || fail "3.10 anchor: exactly two lines"
- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews, as for any code PR.
END_OF_TEXT
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.11 anchor"
- Done when: merged; a dry run on PR #235 posts nothing and writes a three-turn review to the run summary; the next code step uses the runner for review B.
END_OF_TEXT
  starts "$DL" 1 <<'END_OF_TEXT' || fail "3.12 anchor"
| 2026-11-17 | PLAN-034 |
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "3.13 anchor"
These producer-audit tiers do not change the PR review pipeline: five reviewers on every code step; three inline reviewers on documentation-only PRs, with external reviewers optional.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "3.14 anchor: the version line"
- **Template version:** v1.1
END_OF_TEXT
  starts "$PAT" 1 <<'END_OF_TEXT' || fail "3.14 anchor: the changelog row v1.1"
| v1.1 | 2026-11-14 |
END_OF_TEXT
  starts "$PAT" 1 <<'END_OF_TEXT' || fail "3.14 anchor: step 9 of §7"
9. MEDIUM: confirm the single audit report has zero HIGH
END_OF_TEXT
  have "$CAT" 1 <<'END_OF_TEXT' || fail "3.15 anchor"
| External Reviewers | [A: Claude; B: Meta Muse (fallback: Gemini) — list which participated and the model each one named] |
END_OF_TEXT
  test "$(sha "$CS")" = "3ad758cbcd86addb642e252a81206bc32033e97640df8ab8495982f4d3518435" || fail "$CS differs from main at 640906f: the planning session renders the prompt again"
  test "$(sha "$POR")" = "72825f24859d45dd6882d11d8b9953b5b332a9f84660a61bc2d2cfe4bf2424c4" || fail "$POR differs from main at 640906f: the planning session renders the prompt again"
  test "$(sha "$DL")" = "a4de5aea6ebe4b63f569b817b697454b575ee997a4c0268628a338de6fa4a1f1" || fail "$DL differs from main at 640906f: the planning session renders the prompt again"
  test "$(sha Docs/development-process-guide.md)" = "cdc24108bb66f3da3fd4bbe8e064856874d3f51f62050b228374407e79588b67" || fail "Docs/development-process-guide.md differs from main at 640906f: the planning session renders the prompt again"
  test "$(sha Docs/planner-start-here.md)" = "bdb217899ee214e04071e911381e4a2da72c1b0da7aebe53089f858be008bad6" || fail "Docs/planner-start-here.md differs from main at 640906f: the planning session renders the prompt again"
  test "$(sha "$PAT")" = "9afc54d44c963d6999de9d3fd92d8936f145e2358ebff78946cb2e473a551040" || fail "$PAT differs from main at 640906f: the planning session renders the prompt again"
  test "$(sha "$CAT")" = "6e628831d4c72a1ab43df6ddc19bb2d4e0a42ce64e787c0e9a1d00446aec15f8" || fail "$CAT differs from main at 640906f: the planning session renders the prompt again"
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
prompts/phase7/consolidated-audit-template-phase7.md
.github/workflows/external-review.yml
scripts/external-review.py
Docs/templates/external-review-template.md
tests/external-review/test_external_review.py
Docs/operator/R5r-review-runner.md
prompts/handoff/phase7/review-runner-2026-11-17-review.md
prompts/handoff/phase7/review-runner-2026-11-17-audit.md
prompts/handoff/phase7/review-runner-2026-11-17-agent-prompt.md
prompts/handoff/phase7/review-runner-2026-11-17-checks.sh
prompts/handoff/phase7/review-runner-2026-11-17.md
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
      copy_one Docs/templates/external-review-template.md 2ccc83edeb04c7c6ed83bf90b80f1e5c9fb9a25f40d463d61f0557a76cc5eefe new
      copy_one "$TESTS" 18a8a2a6f1a63f32e4bbd688961fc98bc06b66809c1159898e7b8bda5eead0b6 new
      echo "copied 2 files" ;;
    3)
      copy_one Docs/development-process-guide.md 28403d60bba772bf2578e8d837651d271226ccbd3dd7af083d70c94741432271 cdc24108bb66f3da3fd4bbe8e064856874d3f51f62050b228374407e79588b67
      copy_one Docs/planner-start-here.md 428e8c4dcd199cdb4277148e8e92ad1d8f6692a9c7621434f8f14e00a2cbb241 bdb217899ee214e04071e911381e4a2da72c1b0da7aebe53089f858be008bad6
      copy_one Docs/operator/R5r-review-runner.md d2bd8cf5a53f7683b6bb87e143012c8e5374ebe32fbd2c326b65b5c674766804 new
      copy_one "$P-review.md" 47da85198964f1fd8c2d140b30d5e59078216cf30973ddd46aa90abd5b2c7bce new
      copy_one "$P-audit.md" f49f8ec3d7eaa9342684b04d827afb39b1f0a2bb4276bcea8968c52c101239ec new
      echo "copied 5 files" ;;
    *) fail "unknown group '${1:-}'" ;;
  esac
}

b_A() {
  test "$(sha Docs/templates/external-review-template.md)" = "2ccc83edeb04c7c6ed83bf90b80f1e5c9fb9a25f40d463d61f0557a76cc5eefe" || fail "1.1 the template differs from the supplied file"
  test "$(sha "$TESTS")" = "18a8a2a6f1a63f32e4bbd688961fc98bc06b66809c1159898e7b8bda5eead0b6" || fail "1.1 the tests differ from the supplied file"
  test ! -e "$SC" || fail "1.1 $SC exists already: Task Group 2 writes it"
  runner_tests && fail "1.1 the tests pass without the script: they test nothing"
  grep -q "^Ran $NTESTS tests" "$TMP/tests.log" || fail "1.1 the test file does not run $NTESTS tests: $(tail -n 3 "$TMP/tests.log" | tr '\n' '|')"
  test "$(grep -c ' \.\.\. ok$' "$TMP/tests.log")" = "0" || fail "1.1 a test passes without the script: $(grep ' \.\.\. ok$' "$TMP/tests.log" | head -n 3 | tr '\n' '|')"
  grep -q "can't open file .*scripts/external-review.py" "$TMP/tests.log" || fail "1.1 the tests fail, but not because the script is missing: $(grep -m2 -E '^(FAIL|ERROR|[A-Za-z]*Error)' "$TMP/tests.log" | tr '\n' '|')"
  ! grep '^ERROR: ' "$TMP/tests.log" | grep -qv '^ERROR: test_25_' || fail "1.1 a test other than test 25 errors without the script: $(grep '^ERROR: ' "$TMP/tests.log" | head -n 3 | tr '\n' '|')"
  test "$(grep -c '^ERROR: ' "$TMP/tests.log")" -le 1 || fail "1.1 more than one test errors without the script (only test 25, which reads the script, may): $(grep '^ERROR: ' "$TMP/tests.log" | head -n 3 | tr '\n' '|')"
  ! grep -qE 'Errno 98|Address already in use|PermissionError' "$TMP/tests.log" || fail "1.1 the stub servers could not start on 127.0.0.1"
  test -z "$(git status --porcelain --untracked-files=all | grep -v -e " Docs/templates/external-review-template.md$" -e " $TESTS$")" || fail "1.1 the test run left files behind: $(git status --porcelain | tr '\n' ' ')"
  echo "CHECKPOINT A PASS"
}

b_B() {
  local py blk rc
  test -f "$SC" || fail "2.1 $SC is missing"
  python3 -I - "$SC" <<'PYEOF' || fail "2.1 the code of the script (see the line above)"
import ast, sys
tree = ast.parse(open(sys.argv[1], encoding="utf-8").read())
def stop(m):
    sys.exit(m)
SUB_BAD = {"Popen", "call", "check_call", "check_output", "getoutput", "getstatusoutput"}
OS_BAD = {"system", "popen", "startfile", "posix_spawn", "posix_spawnp", "fork", "forkpty", "execl", "execle", "execlp",
          "execlpe", "execv", "execve", "execvp", "execvpe", "spawnl", "spawnle", "spawnlp", "spawnlpe", "spawnv", "spawnve",
          "spawnvp", "spawnvpe"}
mods, alias, run_names = set(), {}, set()
for n in ast.walk(tree):
    if isinstance(n, ast.Import):
        for a in n.names:
            mods.add(a.name.split(".")[0])
            alias[a.asname or a.name.split(".")[0]] = a.name.split(".")[0]
    elif isinstance(n, ast.ImportFrom):
        if n.level:
            stop("the script uses a relative import")
        m = n.module.split(".")[0]
        mods.add(m)
        for a in n.names:
            if (m == "subprocess" and a.name in SUB_BAD) or (m == "os" and a.name in OS_BAD) or a.name == "*":
                stop("the script imports %s from %s" % (a.name, n.module))
            if m == "subprocess" and a.name == "run":
                run_names.add(a.asname or "run")
bad = sorted(m for m in mods if m not in sys.stdlib_module_names)
if bad:
    stop("modules outside the standard library: %s" % ", ".join(bad))
for m in ("importlib", "ctypes", "pty", "multiprocessing"):
    if m in mods:
        stop("the script imports %s" % m)
runs = []
for n in ast.walk(tree):
    if isinstance(n, ast.Call):
        f = n.func
        if isinstance(f, ast.Name) and f.id in ("eval", "exec", "compile", "__import__"):
            stop("the script calls %s()" % f.id)
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name):
            mod = alias.get(f.value.id)
            if mod == "subprocess":
                if f.attr != "run":
                    stop("the script calls subprocess.%s(); only subprocess.run is allowed" % f.attr)
                runs.append(n)
            if mod == "os" and f.attr in OS_BAD:
                stop("the script calls os.%s()" % f.attr)
        if isinstance(f, ast.Name) and f.id in run_names:
            runs.append(n)
        for k in n.keywords:
            if k.arg == "shell" and not (isinstance(k.value, ast.Constant) and k.value.value is False):
                stop("the script passes shell= other than False")
want = ["gcloud", "auth", "print-access-token"]
if len(runs) != 1:
    stop("the script must start exactly one process, with one subprocess.run call; found %d" % len(runs))
ALLOWED_KW = {"capture_output", "text", "timeout", "check", "stdout", "stderr", "encoding", "errors"}
kw = sorted(k.arg or "**" for k in runs[0].keywords if (k.arg or "**") not in ALLOWED_KW)
if kw or len(runs[0].args) != 1:
    stop("the subprocess.run call may take only the list and the keywords %s; found extra %s" % (", ".join(sorted(ALLOWED_KW)), kw or "positional arguments"))
arg = runs[0].args[0] if runs[0].args else None
if not (isinstance(arg, ast.List) and [getattr(e, "value", None) for e in arg.elts] == want):
    stop('the one subprocess.run call must take the list ["gcloud", "auth", "print-access-token"], written in the call')
print("script code: standard library only, no shell, one child process: gcloud auth print-access-token")
PYEOF
  runner_tests || fail "2.1 the runner tests: $(grep -E '^(FAIL|ERROR):' "$TMP/tests.log" | head -n 4 | tr '\n' '|') $(tail -n 1 "$TMP/tests.log")"
  grep -q "^Ran $NTESTS tests" "$TMP/tests.log" && test "$(tail -n 1 "$TMP/tests.log")" = "OK" || fail "2.1 expected 'Ran $NTESTS tests' and 'OK'"
  test -f "$WF" || fail "2.2 $WF is missing"
  grep -qF 'secrets.' "$WF" && fail "2.2 the workflow names a secret"
  grep -qF 'credentials_json' "$WF" && fail "2.2 the workflow names credentials_json"
  grep -qF 'toJSON(' "$WF" && fail "2.2 the workflow serializes a context with toJSON"
  grep -qF 'Docs/operator/R5r-review-runner.md' "$WF" || fail "2.2 the workflow does not point to Docs/operator/R5r-review-runner.md"
  test "$(grep -cxF "    # Pinned to one Ubuntu release: the runner's OS changes only through a pull request (R5c, PLAN-034)." "$WF")" = "1" || fail "2.2 the pin comment of R5c is missing"
  test "$(grep -cE '^ +(- )?uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4\.4\.0$' "$WF")" = "1" || fail "2.2 actions/checkout must be pinned as 'actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0'"
  test "$(grep -cE '^ +(- )?uses: google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 # v3\.0\.0$' "$WF")" = "1" || fail "2.2 google-github-actions/auth must be pinned as 'google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 # v3.0.0'"
  py="$(yaml_python)" || fail "no Python imports yaml under -I"
  "$py" -I - "$WF" <<'PYEOF' || fail "2.2 the structure of the workflow (see the line above)"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
def need(c, m):
    if not c:
        sys.exit(m)
top = sorted("on" if k is True else k for k in d)
need(top == ["jobs", "name", "on", "permissions"], "the top level must hold name, on, permissions and jobs only; found %s" % top)
need(d.get("name") == "External Review", "name must be 'External Review'")
on = d.get("on", d.get(True))
need(isinstance(on, dict) and list(on) == ["workflow_dispatch"], "the only trigger must be workflow_dispatch: %r" % (list(on) if isinstance(on, dict) else on))
need(isinstance(on["workflow_dispatch"], dict) and list(on["workflow_dispatch"]) == ["inputs"], "workflow_dispatch must hold the key inputs only")
inp = on["workflow_dispatch"]["inputs"]
want = {
 "pr": {"type": "string", "required": True},
 "prompt_path": {"type": "string", "required": True},
 "review_path": {"type": "string", "required": False, "default": ""},
 "model": {"type": "choice", "required": True, "default": "gemini-4-hydrogen", "options": ["gemini-4-hydrogen", "gemini-4-argon", "gemini-4-carbon"]},
 "thinking_level": {"type": "choice", "required": True, "default": "HIGH", "options": ["LOW", "MEDIUM", "HIGH", "XHIGH"]},
 "profile": {"type": "choice", "required": True, "default": "default", "options": ["default"]},
 "dry_run": {"type": "boolean", "required": True, "default": True},
}
need(set(inp) == set(want), "inputs must be exactly %s; found %s" % (sorted(want), sorted(inp)))
for k, w in want.items():
    for f, v in w.items():
        need(inp[k].get(f) == v, "input %s: %s must be %r, found %r" % (k, f, v, inp[k].get(f)))
    need(set(inp[k]) <= {"description", "required", "type", "default", "options"} and inp[k].get("description"),
         "input %s: a description, and no key but description, required, type, default and options; found %s" % (k, sorted(inp[k])))
d_tl = str(inp["thinking_level"]["description"])
need("XHIGH" in d_tl and "gemini-4-hydrogen" in d_tl, "the description of thinking_level must name XHIGH and gemini-4-hydrogen")
need(d.get("permissions") == {}, "top-level permissions must be {}")
need(list(d["jobs"]) == ["review"], "the one job must be 'review'")
j = d["jobs"]["review"]
need(sorted(j) == sorted(["if", "runs-on", "environment", "timeout-minutes", "concurrency", "permissions", "steps"]),
     "the job must hold if, runs-on, environment, timeout-minutes, concurrency, permissions and steps only; found %s" % sorted(j))
need(j["if"] == "github.ref == 'refs/heads/main'", "the job's if must be github.ref == 'refs/heads/main'")
need(j["runs-on"] == "ubuntu-24.04", "runs-on must be ubuntu-24.04")
need(j["environment"] == "external-review", "environment must be external-review")
need(j["timeout-minutes"] == 60, "timeout-minutes must be 60")
need(j["concurrency"] == {"group": "external-review", "cancel-in-progress": False}, "concurrency must be group external-review, cancel-in-progress false")
need(j["permissions"] == {"contents": "read", "id-token": "write", "pull-requests": "write"}, "job permissions must be contents read, id-token write, pull-requests write")
steps = j["steps"]
need(isinstance(steps, list) and len(steps) == 4, "the job must have exactly four steps; found %d" % len(steps))
need([s.get("name") for s in steps] == ["Checkout main", "Select profile", "Sign in to Google Cloud", "Run the review"],
     "the steps must be, in order: Checkout main, Select profile, Sign in to Google Cloud, Run the review; found %r" % [s.get("name") for s in steps])
for s in steps:
    need("${{" not in str(s.get("run", "")), "a run block holds a ${{ }} expression: step %r" % s.get("name"))
co, pr, au, rv = steps
need(sorted(co) == ["name", "uses", "with"] and co["uses"] == "actions/checkout@11d5960a326750d5838078e36cf38b85af677262"
     and co["with"] == {"persist-credentials": False}, "Checkout main: uses the pinned checkout with persist-credentials: false and nothing else")
need(sorted(pr) == ["env", "id", "name", "run", "shell"] and pr["id"] == "profile" and pr["shell"] == "bash",
     "Select profile: id profile, shell bash, env and run, nothing else")
need(pr["env"] == {"PROFILE": "${{ inputs.profile }}",
                   "PROJECT_ID": "${{ inputs.profile == 'default' && vars.GCP_PROJECT_ID_DEFAULT || '' }}",
                   "PROVIDER": "${{ inputs.profile == 'default' && vars.GCP_WIF_PROVIDER_DEFAULT || '' }}",
                   "SERVICE_ACCOUNT": "${{ inputs.profile == 'default' && vars.GCP_SERVICE_ACCOUNT_DEFAULT || '' }}"},
     "Select profile: the env must be the four lines of item 2.2")
first = next((l.strip() for l in str(pr["run"]).split("\n") if l.strip() and not l.strip().startswith("#")), "")
need(first.startswith("python3 -I"), "Select profile: the first command line of the run block must run python3 -I; found %r" % first)
need(sorted(au) == ["name", "uses", "with"] and au["uses"] == "google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093"
     and au["with"] == {"project_id": "${{ steps.profile.outputs.project_id }}",
                        "workload_identity_provider": "${{ steps.profile.outputs.provider }}",
                        "service_account": "${{ steps.profile.outputs.service_account }}"}, "Sign in to Google Cloud: the pinned auth action with the three inputs of item 2.2 and nothing else")
we = {"GITHUB_TOKEN": "${{ github.token }}", "ER_PR": "${{ inputs.pr }}", "ER_PROMPT_PATH": "${{ inputs.prompt_path }}",
      "ER_REVIEW_PATH": "${{ inputs.review_path }}", "ER_MODEL": "${{ inputs.model }}", "ER_THINKING_LEVEL": "${{ inputs.thinking_level }}",
      "ER_DRY_RUN": "${{ inputs.dry_run }}", "ER_PROJECT_ID": "${{ steps.profile.outputs.project_id }}", "ER_PROFILE": "${{ inputs.profile }}"}
need(sorted(rv) == ["env", "name", "run", "shell"] and rv["shell"] == "bash" and str(rv["run"]).strip() == "python3 -I scripts/external-review.py",
     "Run the review: shell bash, run exactly 'python3 -I scripts/external-review.py', env, nothing else")
need(rv["env"] == we, "Run the review: the env must be exactly the nine variables of item 2.2")
print("workflow structure: ok")
PYEOF
  blk="$TMP/profile.sh"
  "$py" -I - "$WF" "$blk" <<'PYEOF' || fail "2.2 cannot read the run block of the step Select profile"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
s = next(s for s in d["jobs"]["review"]["steps"] if s.get("id") == "profile")
open(sys.argv[2], "w", encoding="utf-8").write(s["run"])
PYEOF
  pv() { # $1 PROFILE, $2 PROJECT_ID, $3 PROVIDER, $4 SERVICE_ACCOUNT: prints "<exit>|<sorted output lines;>|<stderr>"
    local o e
    o="$TMP/out.$RANDOM"; e="$TMP/err.$RANDOM"; : > "$o"
    ( cd "$TMP" && env -i PATH="$PATH" HOME="$TMP" PROFILE="$1" PROJECT_ID="$2" PROVIDER="$3" SERVICE_ACCOUNT="$4" GITHUB_OUTPUT="$o" bash --noprofile --norc -eo pipefail "$blk" >/dev/null 2>"$e" ); rc=$?
    printf '%s|%s|%s\n' "$rc" "$(sort "$o" | tr '\n' ';')" "$(tr '\n' ' ' < "$e")"
  }
  local prov="projects/1/locations/global/workloadIdentityPools/github/providers/p" r
  test "$(pv default example-project-1 "$prov" '' | cut -d'|' -f1,2)" = "0|project_id=example-project-1;provider=$prov;service_account=;" || fail "2.2 Select profile with profile default: $(pv default example-project-1 "$prov" '')"
  test "$(pv second example-project-2 prov-2 account-of-example-project-2 | cut -d'|' -f1,2)" = "0|project_id=example-project-2;provider=prov-2;service_account=account-of-example-project-2;" || fail "2.2 Select profile with a second profile and a service account"
  r="$(pv default example-project-1 '' '')"
  [[ "$r" == [1-9]*"||"*"the environment external-review has no GCP_PROJECT_ID_DEFAULT or no GCP_WIF_PROVIDER_DEFAULT"* ]] || fail "2.2 Select profile without a provider must fail, write no output and name both variables: $r"
  r="$(pv second '' prov-2 '')"
  [[ "$r" == [1-9]*"||"*"the environment external-review has no GCP_PROJECT_ID_SECOND or no GCP_WIF_PROVIDER_SECOND"* ]] || fail "2.2 Select profile without a project ID must fail, write no output and name both variables: $r"
  for n in Default 'default;id' '' 1default de-fault aaaaaaaaaaaaaaaaaaaaa; do
    r="$(pv "$n" example-project-1 "$prov" '')"
    [[ "$r" == [1-9]*"||"* ]] || fail "2.2 Select profile must refuse the name '$n' and write no output: $r"
  done
  for r in "$(pv default $'example-project-1\nx' "$prov" '')" "$(pv default $'example-project-1\rx' "$prov" '')" \
           "$(pv default example-project-1 $'prov\nx' '')" "$(pv default example-project-1 $'prov\rx' '')" \
           "$(pv default example-project-1 "$prov" $'acct\nx')" "$(pv default example-project-1 "$prov" $'acct\rx')"; do
    [[ "$r" == [1-9]*"||"* ]] || fail "2.2 Select profile must refuse a value with a carriage return or a line feed and write no output: $r"
  done
  echo "profile step: ok"
  echo "CHECKPOINT B PASS"
}

b_C() {
  local n
  test "$(grep -c '^_Next action: ' "$CS")" = "1" || fail "3.1 expected one Next action line"
  have "$CS" 1 <<'END_OF_TEXT' || fail "3.1 the new Next action line"
_Next action: R5a, the producer contract, a documentation PR that does not wait for the review runner; the dry run and the posting run of the runner on PR #239 (operator, `Docs/operator/R5r-review-runner.md`) come before the next code step. The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5a and R5b._
END_OF_TEXT
  test "$(grep -c 'R5r, R5a, R5b' "$CS")" = "0" || fail "3.2 the old What-is-Next item is still in the file"
  have "$CS" 1 <<'END_OF_TEXT' || fail "3.2 the new What-is-Next item"
1. **R5a, R5b** — the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017). No firmware change. Review B runs on the review runner from now on (PLAN-022, PLAN-023).
END_OF_TEXT
  after "$CS" '| R5c planning (CI logs) |' <<'END_OF_TEXT' || fail "3.3 the four new rows must follow the row 'R5c planning (CI logs)', in order"
| PR #239 review A | Four helper scripts print `esphome run` advice: `scripts/provision.sh`, `scripts/render_sensor_config.py`, `scripts/change_sensor_number.py`, `scripts/patch-esphome-httpd-stack.sh`; `AGENTS.md` allows only `esphome upload` and `esphome compile` | **Not implemented** — the advice is printed, not run; routed to a later script-cleanup step that the operator schedules |
| R5r audit (GPT, finding 9) | The tests of the review runner run in no CI job: `.github/workflows/ci.yml` calls `scripts/preflight.sh`, which does not run `tests/external-review/test_external_review.py` | **Not implemented** — it needs a change of `ci.yml` outside R5r; routed to a later tooling step that the operator schedules |
| R5r planning (lint L11) | Rule L11 of `scripts/lint-prompts.sh` reports a false login literal on a quoted diff line that begins with `-u` and has a colon later in the same word, as a removed YAML key `update_interval` with its colon has; the login check of `scripts/external-review.py` (item 2.1) uses the same rule, so it refuses such a line too | **Not implemented** — a false finding, not a leak; routed to a later tooling step that the operator schedules |
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Pending operator post-merge check** — `Docs/operator/R5r-review-runner.md`, sections "Dry run" and "Posting run"; until both pass, a code step that needs review B waits for the runner, or the operator chooses to run review B as a Muse session in three turns (PLAN-023) |
END_OF_TEXT
  test "$(grep -cF -- '**Pending operator post-merge check**' "$CS")" = "1" || fail "3.3 the status mark of the R5r row"
  test "$(numstat "$CS")" = "6 2" || fail "3.1 to 3.3 $CS must show 6 added and 2 deleted lines; it shows $(numstat "$CS")"
  test "$(grep -cF -- 'The next step is **R5r**' "$POR")" = "0" || fail "3.4 the old You-are-here line is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.4 the new You-are-here line"
The next step is **R5a**, the producer contract. The last merged step is **R5r**, the review-runner PR; its dry run and posting run come before the next code step.
END_OF_TEXT
  test "$(grep -c '^| 5b | R5r | .* | Waiting |$' "$POR")" = "0" || fail "3.5 the R5r row is still Waiting"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.5 the new R5r row"
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Merged: the pull request that added `.github/workflows/external-review.yml`; done when the conditions of its block in section 5 hold |
END_OF_TEXT
  test "$(grep -cF -- 'is a working notebook' "$POR")" = "0" || fail "3.6 the old notebook line is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.6 the new notebook line"
- The planning notes outside this repository are working notes in the private planning repository that `Docs/planner-start-here.md` names. They are not a source (PLAN-024, PLAN-035).
END_OF_TEXT
  after "$POR" '- Scope: the workflow `.github/workflows/external-review.yml` and its script' <<'END_OF_TEXT' || fail "3.7 the new line must follow the Scope line of R5r"
- Decided before R5r (PLAN-036, PLAN-037): one profile, `default`, as variables of the GitHub environment `external-review`, with a documented way to add one; the turn texts in `Docs/templates/external-review-template.md`; the script on the Python standard library only; the dry run on PR #239 with its agent prompt and review file, because the diff of PR #235 holds deleted login literals. R5r also carries the planning repository (PLAN-035) and routes the PR #239 review A finding on `esphome run` advice.
END_OF_TEXT
  test "$(grep -cF -- 'Today these are review A and review B (PLAN-019)' "$POR")" = "0" || fail "3.8 the old text is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.8 the new line"
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). Section 7 shows the scheme.
END_OF_TEXT
  test "$(grep -cF -- 'This scheme takes effect when the review-runner PR is merged' "$POR")" = "0" || fail "3.9 the old text is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.9 the new line"
This scheme holds from the merge of the review-runner PR, R5r (PLAN-022, PLAN-023). If the runner cannot run, the step waits for it, or the operator runs review B as a Muse session in three turns and the consolidated audit names the change. Review C is required on MEDIUM and HIGH firmware steps and optional elsewhere (PLAN-036).
END_OF_TEXT
  have "$POR" 0 <<'END_OF_TEXT' || fail "3.10 an old Who line of R5 or R5c is still present"
- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews, as for any code PR.
END_OF_TEXT
  have "$POR" 2 <<'END_OF_TEXT' || fail "3.10 expected the new Who line twice"
- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews of PLAN-019, as for any code PR at that time.
END_OF_TEXT
  test "$(grep -cF -- 'a dry run on PR #235 posts nothing' "$POR")" = "0" || fail "3.11 the old Done-when line is still present"
  have "$POR" 1 <<'END_OF_TEXT' || fail "3.11 the new Done-when line"
- Done when: merged; a dry run on PR #239 posts nothing and writes a three-turn review to the run summary; one posting run posts one comment; the next code step uses the runner for review B.
END_OF_TEXT
  test "$(numstat "$POR")" = "9 8" || fail "3.4 to 3.11 $POR must show 9 added and 8 deleted lines; it shows $(numstat "$POR")"
  after "$DL" '| 2026-11-17 | PLAN-034 |' <<'END_OF_TEXT' || fail "3.12 the rows PLAN-035, PLAN-036 and PLAN-037 must follow PLAN-034, in order and verbatim"
| 2026-11-17 | PLAN-035 | The planning notes move to the private repository `GCV-Sleeper-Service/Planning-Workflow` (operator decision 2026-11-17; amends the notebook of PLAN-024, the files of PLAN-033 and the placeholder of PLAN-034). The operator left its layout to the planning session, which chose: `README.md` opens with "Read first", the current status; working notes go to `sessions/`, and the gate record, setup block and planning tools of a step to `steps/<step>/`; the Claude Doc notebook is archived under `notebook/`; planning sessions commit their notes to its `main`. The start prompt in `Docs/planner-start-here.md` names the repository; it is private, so its address gives no access. No credential is ever stored there | `prompts/handoff/phase7/review-runner-2026-11-17.md` §6 |
| 2026-11-18 | PLAN-036 | Choices for the review runner R5r (operator decisions 2026-11-17 and 2026-11-18, within PLAN-022). One profile, `default`, at the start; a profile is the variables `GCP_PROJECT_ID_<PROFILE>`, `GCP_WIF_PROVIDER_<PROFILE>` and the optional `GCP_SERVICE_ACCOUNT_<PROFILE>` of the GitHub environment `external-review`, plus its name in the workflow's choice list and in the expressions of the step `Select profile`; `Docs/operator/R5r-review-runner.md` says how to add one. Only the chosen profile's three values are passed to a step; they may appear in the run's Actions log and in no file of the repository. Sign-in by direct Workload Identity Federation through a pool that holds only this provider, whose condition names the repository by name and ID, its owner's ID, this workflow file on `refs/heads/main` (`workflow_ref`), the environment, the ref and `workflow_dispatch`, and which a failed run does not loosen; if Agent Platform refuses direct federation, `GCP_SERVICE_ACCOUNT_<PROFILE>` switches to a service account without a key, with no code change. The two actions are pinned to commits. The turn texts are `Docs/templates/external-review-template.md`, built from the review files of R5 and R5c. The script uses the Python standard library only, leaves wholly generated diff sections out by name, refuses data and answers that hold a login literal of rule L11, and follows no redirect to another origin. The dry run reads PR #239, because the diff of PR #235 holds deleted login literals. The operator page gives every Google Cloud step as a `gcloud` command and as console steps, checked against Google's pages; the planning session cannot run them. Review C is optional on MEDIUM and HIGH steps that change no firmware, so R5r has five reviews | `prompts/handoff/phase7/review-runner-2026-11-17.md` §6 |
| 2026-11-18 | PLAN-037 | Producer audit, within PLAN-017 (operator decisions 2026-11-18): a MEDIUM prompt gets one auditor, GPT Astra in its own ChatGPT session (the model names itself Codex, GPT-6); a HIGH prompt gets two, GPT Astra and Gemini 4 Argon in AI Studio. Gemini 4 Carbon joins only once it runs under a subscription. The step's audit file holds the audit prompts, each report verbatim (a report that the auditor could only restate is marked so) and the dispositions, in place of the separate report files of `Docs/templates/prompt-audit-template.md` §7 step 5. A re-audit is a new session with a new prompt (template §7 step 8). The planning session checks every finding against the sources and rates it: CRITICAL as the template defines it (data loss, credential exposure, unrecoverable device risk); HIGH, it would let the step merge a defect, leak a credential or make what the step builds unsafe; MEDIUM, it would make the agent stop or the step's acceptance run fail; LOW, clarity or style. Where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9). An official round counts as an audit session; a comparison report does not. For R5r the auditor of record is GPT Astra; four more models audited round 1 for comparison, and their reports are in the audit file | `prompts/handoff/phase7/review-runner-2026-11-17-audit.md` |
END_OF_TEXT
  test "$(grep -c '^| ' "$DL")" = "61" || fail "3.12 decision log table rows (58 before, 61 after); found $(grep -c '^| ' "$DL")"
  test "$(tail -n 1 "$DL")" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "3.12 the last line of the log changed"
  test "$(numstat "$DL")" = "3 0" || fail "3.12 $DL must show 3 added lines; it shows $(numstat "$DL")"
  test "$(grep -ciF 'five reviewers' "$PAT")" = "0" || fail "3.13 'five reviewers' is still in the audit template"
  have "$PAT" 1 <<'END_OF_TEXT' || fail "3.13 the new review-pipeline line"
These producer-audit tiers do not change the PR review pipeline of `Docs/development-process-guide.md` §2.4 (PLAN-023): three inline reviewers; reviews A and C side by side, with C required on MEDIUM and HIGH firmware steps; review B by the runner, last. Documentation-only PRs run the three inline reviewers, with external reviewers optional.
END_OF_TEXT
  have "$PAT" 1 <<'END_OF_TEXT' || fail "3.14 the version line"
- **Template version:** v1.2
END_OF_TEXT
  after "$PAT" '| v1.1 | 2026-11-14 |' <<'END_OF_TEXT' || fail "3.14 the changelog row v1.2 must follow v1.1"
| v1.2 | 2026-11-18 | R5r (PLAN-023, PLAN-037): the review-pipeline line names reviews A, B and C; a note under §7 step 9 points to PLAN-037. |
END_OF_TEXT
  after "$PAT" '9. MEDIUM: confirm the single audit report has zero HIGH' <<'END_OF_TEXT' || fail "3.14 the note on PLAN-037 must follow step 9 of §7"
   PLAN-037 (2026-11-18): the step's audit file holds the audit prompts, the reports and the dispositions, for MEDIUM and HIGH (step 5). The planning session rates each finding by the severities of PLAN-037; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (step 9).
END_OF_TEXT
  test "$(numstat "$PAT")" = "4 2" || fail "3.13 and 3.14 the audit template must show 4 added and 2 deleted lines; it shows $(numstat "$PAT")"
  test "$(grep -cF -- 'B: Meta Muse (fallback: Gemini)' "$CAT")" = "0" || fail "3.15 the old text is still present"
  have "$CAT" 1 <<'END_OF_TEXT' || fail "3.15 the new line"
| External Reviewers | [A: Claude (a GPT model when Claude Code coded the step); C: Meta Muse (required on MEDIUM and HIGH firmware steps); B: the review runner, or a Muse session in three turns when the runner cannot run — list which participated and the model each one named] |
END_OF_TEXT
  test "$(numstat "$CAT")" = "1 1" || fail "3.15 the consolidated audit template must show 1 added and 1 deleted line; it shows $(numstat "$CAT")"
  test "$(sha Docs/development-process-guide.md)" = "28403d60bba772bf2578e8d837651d271226ccbd3dd7af083d70c94741432271" || fail "3.16 Docs/development-process-guide.md differs from the supplied file"
  test "$(sha Docs/planner-start-here.md)" = "428e8c4dcd199cdb4277148e8e92ad1d8f6692a9c7621434f8f14e00a2cbb241" || fail "3.16 Docs/planner-start-here.md differs from the supplied file"
  test "$(sha Docs/operator/R5r-review-runner.md)" = "d2bd8cf5a53f7683b6bb87e143012c8e5374ebe32fbd2c326b65b5c674766804" || fail "3.16 Docs/operator/R5r-review-runner.md differs from the supplied file"
  test "$(sha "$P-review.md")" = "47da85198964f1fd8c2d140b30d5e59078216cf30973ddd46aa90abd5b2c7bce" || fail "3.16 $P-review.md differs from the supplied file"
  test "$(sha "$P-audit.md")" = "f49f8ec3d7eaa9342684b04d827afb39b1f0a2bb4276bcea8968c52c101239ec" || fail "3.16 $P-audit.md differs from the supplied file"
  test "$(grep -ciF 'five reviewers' Docs/development-process-guide.md)" = "0" || fail "3.16 'five reviewers' is still in the process guide"
  test "$(sed -n '/^```mermaid$/,/^```$/p' "$POR" Docs/operator/R5r-review-runner.md | grep -c ';')" = "0" || fail "3.16 a semicolon inside a Mermaid block"
  echo "CHECKPOINT C PASS"
}

b_D() {
  test -f "$P.md" || fail "4.1 $P.md is missing"
  test "$(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')" = "## §1 ## §2 ## §3 ## §4 ## §5 ## §6 ## §7 ## §8 ## §9 " || fail "4.1 the record file must have the nine headings '## §1 ' to '## §9 ', each once, in order; found: $(grep -o '^## §[1-9] ' "$P.md" | tr -d '\n')"
  test "$(grep -c '<NN>' "$P.md")" = "0" || fail "4.1 <NN> is left in the record file"
  cat > "$TMP/table.txt" <<'END_OF_TEXT'
| ID | Decision | Reason |
|---|---|---|
| PLAN-035 | The planning notes live in the private repository `GCV-Sleeper-Service/Planning-Workflow`; the start prompt names it; the Claude Doc notebook is archived there | A planner of any vendor can read a Git repository; a Claude Doc needs the Claude Docs connector. The repository keeps the history of every note |
| PLAN-036 | One profile at the start, with a documented way to add one; only the chosen profile's values are passed to a step; direct federation under a fixed condition, with a service-account fallback by variable; actions pinned to commits; the turn texts from the review files on `main`; refusal of data with a login literal; the dry run on PR #239; review C optional on steps that change no firmware | Project IDs stay out of the repository and unrelated variables out of the log; the dry run decides the sign-in without a code change; the diff of PR #235 holds deleted login literals |
| PLAN-037 | MEDIUM prompt: one auditor, GPT Astra; HIGH prompt: GPT Astra and Gemini 4 Argon; Gemini 4 Carbon once it runs under a subscription; the planning session rates each finding, the operator decides where the auditor rates higher | In the comparison of five auditors on R5r, GPT Astra found the most serious findings, and GPT Astra with Argon covered 15 of the 17 HIGH and MEDIUM findings; Carbon is billed per use |
END_OF_TEXT
  cat > "$TMP/sentence.txt" <<'END_OF_TEXT'
No issue closes in this step, no milestone changes, and the status table of issue #228 does not change. The operator creates the Google Cloud resources and the GitHub environment `external-review`, then runs the dry run and the posting run of `Docs/operator/R5r-review-runner.md`.
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
for item in ["1.1", "2.1", "2.2"] + ["3.%d" % i for i in range(1, 17)]:
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
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -c '^A')" = "10" || fail "expected 10 new files"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -vc '^[MA]')" = "0" || fail "a file was deleted or changed its type"
  test -z "$(git diff --name-only "$base" HEAD -- firmware src config dashboard partitions package.json package-lock.json)" || fail "a firmware, dashboard or package file changed"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
  cmp -s "$P-agent-prompt.md" "$SAVE/review-runner-2026-11-17-agent-prompt.md" || fail "the committed prompt differs from the saved one"
  cmp -s "$P-checks.sh" "$SAVE/review-runner-2026-11-17-checks.sh" || fail "the committed check file differs from the saved one"
  ( b_B ) || exit 1
  ( b_C ) || exit 1
  ( b_D ) || exit 1
  mapfile -t f < <(git diff --name-only --no-renames "$base" HEAD -- prompts)
  bash scripts/lint-prompts.sh --baseline origin/main "${f[@]}" || fail "lint of the prompt files of this PR"
  mapfile -t f < <(git diff --name-only --no-renames "$base" HEAD)
  bash scripts/lint-prompts.sh "${f[@]}" > "$TMP/lint.log" 2>&1; rc=$?
  n="$(grep -c 'L11' "$TMP/lint.log")"
  test "$n" = "0" || fail "rule L11 finds a login literal in a changed file ($n lines)"
  test "$rc" = "0" || fail "lint of the changed files ended with exit $rc: $(grep -m2 -E 'ERROR|L[0-9]+' "$TMP/lint.log" | tr '\n' '|')"
  n="$(git diff "$base" HEAD | grep -E '^\+' | grep -cE 'projects/[0-9]{6,}|[a-z0-9-]+@[a-z0-9-]+\.iam\.gserviceaccount\.com' || true)"
  test "$n" = "0" || fail "a Google Cloud project number or service account appears in the diff ($n lines)"
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
  A|B|C|D) "b_$NAME" ;;
  prepr) b_prepr ;;
  *) echo "usage: bash $0 <sec2 | scope | copy <1|3> | A | B | C | D | prepr>"; exit 2 ;;
esac
