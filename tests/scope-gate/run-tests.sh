#!/usr/bin/env bash
# tests/scope-gate/run-tests.sh - the two integration cases of tests/run-tests.sh in
# HowTo-LLM-Assisted-Workflow-v2 at tag v2.3.1, adapted to this repository (R5, PLAN-017).
# Each case runs, in a throwaway git repository, the scope-gate lines of a PRE-PR gate exactly as
# the prompts of this repository give them, with scripts/scope-gate.py of this checkout.
# The throwaway repository has no remote; a ref refs/remotes/origin/main stands in for origin/main.
# Exit 0 only if both cases give their expected result.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT/scripts/scope-gate.py"
pass=0; fail=0
check() { # $1 name, $2 expected, $3 actual
  if [[ "$2" == "$3" ]]; then pass=$((pass+1)); printf 'ok    %-50s %s\n' "$1" "$3"
  else fail=$((fail+1)); printf 'FAIL  %-50s expected %s, got %s\n' "$1" "$2" "$3"; fi
}
prepr_block() { # the scope-gate lines of a PRE-PR gate, then a marker for the checks that follow them
  cat <<'EOF'
python3 scripts/scope-gate.py --allowed "$(git rev-parse --git-path scope-allowed.txt)" --target origin/main \
  || { rc=$?; echo "PRE-PR GATE FAILED (scope-gate exit $rc) - STOP"; exit "$rc"; }
echo LATER_CHECK_RAN
EOF
}
integration_repo() { # scripts/scope-gate.py committed on main, origin/main at main, then branch "step"
  cd "$(mktemp -d)" && git init -q -b main . && git config user.name t && git config user.email t@t
  printf 'a\n' > a.txt; printf 'c\n' > c.txt; mkdir scripts; cp "$GATE" scripts/scope-gate.py
  git add -A && git commit -qm base && git update-ref refs/remotes/origin/main HEAD && git checkout -qb step
  prepr_block > "$(git rev-parse --git-path prepr.sh)"
  printf 'a.txt\n' > "$(git rev-parse --git-path scope-allowed.txt)"
}
run_block() { # prints "<exit> <ran|stopped> <PASS|nopass>"
  local out rc; out=$(bash "$(git rev-parse --git-path prepr.sh)" 2>&1); rc=$?
  printf '%s %s %s\n' "$rc" "$(grep -q LATER_CHECK_RAN <<< "$out" && echo ran || echo stopped)" \
    "$(grep -q 'PASS: every changed path is allowed' <<< "$out" && echo PASS || echo nopass)"
}
[[ -f "$GATE" ]] || { echo "scripts/scope-gate.py is missing"; exit 2; }
integration_repo; echo x >> a.txt
check "valid change passes the PRE-PR block" "0 ran PASS" "$(run_block)"
integration_repo; echo x >> c.txt
check "failed gate stops the PRE-PR block" "1 stopped nopass" "$(run_block)"
echo "----"; echo "scope-gate cases: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
