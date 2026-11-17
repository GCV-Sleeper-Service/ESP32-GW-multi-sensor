# Tooling PR (R5) — scope gate, lint rules L8 to L11, CI fast path, PR-body check, reproducible dashboard header (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions_
_Date: 2026-11-16_
_Prerequisite: `main` contains `84e8569` (PR #236, plan of record into the repository); `VERSION` 7.7.1.1_
_Risk: LOW — scripts, workflows, tests and documents; no firmware source, no partition, no version bump, no board; one generated file, `dashboard/dashboard.h`, is written again by the pipeline_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Every gate and every checkpoint is in the check file `/root/r5/tooling-2026-11-16-checks.sh`. The setup block has checked its SHA-256 and committed a copy as `prompts/handoff/phase7/tooling-2026-11-16-checks.sh`. Run each one exactly as this prompt writes it, for example `bash /root/r5/tooling-2026-11-16-checks.sh A`. Never type a check by hand, never retype a check from this prompt, and never edit the check file (PR #236: the agent typed the §2 gate by hand, with wrong dates).
- The check file also writes the scope list (`bash /root/r5/tooling-2026-11-16-checks.sh scope`) and copies the supplied files (`bash /root/r5/tooling-2026-11-16-checks.sh copy <group>`). Apart from these and the pipeline of item 7.2, apply every edit of Task Groups 2 to 8 with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1).
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2). CHECKPOINT E and the PRE-PR gate each run preflight once; item 7.2 and CHECKPOINT G each run the pipeline once.
- Every edit is verbatim and anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines and indentation included; the fence lines themselves are not part of it.
- A check prints `⛔ CHECKPOINT FAILED - <block>: <reason>` and exits non-zero on a mismatch. Then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- This step needs no login and calls no board. CHECKPOINT C runs the stress-test script with made-up values and a stand-in for `curl`; it never reads `$ESP_USER` or `$ESP_PASS` of your shell. Never print, echo or write either variable.
- `dashboard/dashboard.h` is generated. Never open it in an editor; item 7.2 writes it with the pipeline.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch `tooling/r5-2026-11` and committed this prompt and its check file. The §2 gate checks the branch.

Read completely, in this order:
0. `CURRENT-STATE.md` — every section; Task Group 8 edits five places.
1. `Docs/development-process-guide.md` — §2.2 to §2.5, §3.2 and §7.
2. `AGENTS.md` — every section.
3. `Docs/plan-of-record.md` — sections 2, 3, 5 (the block of R5) and 10.
4. `scripts/lint-prompts.sh` and `.github/workflows/ci.yml` — whole files; Task Groups 2 and 4 edit them.

## §2 — Pre-Implementation Verification Gate

Run this BEFORE any edit:

```bash
bash /root/r5/tooling-2026-11-16-checks.sh sec2
```

It must end with `§2 PASS`. It checks the branch, that `84e8569` is an ancestor, `VERSION`, a clean tree, the saved prompt and check file, the tools (ESPHome 2026.4.1, a Python with PyYAML, `node_modules` with Playwright and `html-minifier-terser`), the live yield value 5 of `maybe_yield_nvs_scan_()`, that no new path of §3 exists yet, every anchor of Task Groups 2 to 8, and that each file this step changes is still byte-identical to `main` at `84e8569`. On any other output STOP and post the checkpoint-failure comment.

## §3 — Scope Boundary

Files you MAY modify (complete list, 29 paths; nothing else).

CHANGED (13):
- `scripts/lint-prompts.sh`
- `scripts/stress-test-httpd-stack.sh`
- `.github/workflows/ci.yml`
- `scripts/preflight.sh`
- `.github/workflows/prompt-lint.yml`
- `scripts/generate-header.sh`
- `dashboard/dashboard.h`
- `CURRENT-STATE.md`
- `Docs/plan-of-record.md`
- `Docs/decisions/decision-log.md`
- `Docs/development-process-guide.md`
- `Docs/planner-start-here.md`
- `Docs/operator/R5-tooling.md`

`dashboard/dashboard.h` changes only through the pipeline of item 7.2, never by hand.

NEW (16):
- `scripts/scope-gate.py`
- `tests/scope-gate/run-tests.sh`
- `tests/lint-prompts/L8-pass.md`
- `tests/lint-prompts/L8-fail.md`
- `tests/lint-prompts/v0.0.0.1-agent-prompt-L9-pass.md`
- `tests/lint-prompts/v0.0.0.2-agent-prompt-L9-fail.md`
- `tests/lint-prompts/L10-pass-agent-prompt.md`
- `tests/lint-prompts/L10-fail-agent-prompt.md`
- `tests/lint-prompts/L11-pass.md`
- `tests/lint-prompts/L11-fail.md`
- `tests/lint-prompts/run-fixtures.sh`
- `.github/workflows/pr-body-check.yml`
- `prompts/handoff/phase7/tooling-2026-11-16-review.md`
- `prompts/handoff/phase7/tooling-2026-11-16.md`
- `prompts/handoff/phase7/tooling-2026-11-16-agent-prompt.md`
- `prompts/handoff/phase7/tooling-2026-11-16-checks.sh`

Write this list, one bare path per line, to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`, so it is never part of the change. The PRE-PR gate checks every changed path against it with `scripts/scope-gate.py`:

```bash
bash /root/r5/tooling-2026-11-16-checks.sh scope
```

It must print `scope list written: 29 paths`.

Files you MUST NOT modify: anything under `firmware/`, `src/`, `partitions/`, `config/`; every file under `dashboard/` except `dashboard/dashboard.h`; every other file under `scripts/`, `tests/`, `.github/` and `prompts/`; `AGENTS.md`, `CLAUDE.md`, `README.md`, `VERSION`, `Docs/changelog.md`; every other file under `Docs/`. `scripts/exporters/system-metrics-exporter.sh` also sets a default login; it is not part of this step (SEC-003 routes it to v7.7.1.5).

You MUST NOT: run `bash scripts/bump-version.sh`; run `esphome compile`, `esphome upload` or `esphome run`; contact any board; create, close or edit issues or milestones; change branch protection; delete a file; merge.

## §4 — Critical Rules Checklist

- Rule 4 — no generated file is edited by hand: `dashboard/dashboard.h` comes from the pipeline.
- Rule 37 — the full pipeline is `bash scripts/provision.sh satellite`; it also restores the satellite configuration that CI expects.
- Rules 62/63 — checkpoints are queries with expected values; on mismatch STOP, do not fix.
- SEC-003 — no login in any command, file, fixture outside `tests/lint-prompts/`, or PR text.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit.
- Do NOT open a supplied file or a fixture in an editor: the check file copies them byte for byte.
- Do NOT write `${{ github.event.pull_request.body }}`, or any other text of a pull request, into a `run:` script. Text from a pull request reaches a script through `env:` only.
- Do NOT add a `paths:` filter to the `pull_request` trigger of `ci.yml` or `pr-body-check.yml`: a required check that a path filter skips blocks the merge (PLAN-020).
- Do NOT put a login into any file, not even a made-up one outside `tests/lint-prompts/`.
- Do NOT bump the version or add a changelog entry: `VERSION` does not change in this step.
- Do NOT change `AGENTS.md`, `CLAUDE.md` or a Copilot instruction file.

## §6 — Implementation Steps

Commit after each checkpoint that passes, with a message that names the task group, and push.

### Task Group 1 — Scope gate (R5 item 1)

**1.1** Copy the two supplied files: `scripts/scope-gate.py`, a byte copy of `templates/scope-gate.py` of HowTo-LLM-Assisted-Workflow-v2 at tag v2.3.1, and `tests/scope-gate/run-tests.sh`, the two integration cases of that HowTo's `tests/run-tests.sh`, adapted to this repository. It must print `copied 2 files`.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh copy 1
```

⛔ **CHECKPOINT A** — the gate is the HowTo file, and both cases pass.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh A
```

### Task Group 2 — Lint rules L8 to L11 (R5 items 2 to 4)

Four rules join `scripts/lint-prompts.sh`. L8: a `pdMS_TO_TICKS` value within 3 lines of "Rule 61" that differs from the live value of `maybe_yield_nvs_scan_()` is an ERROR. L9: a step agent prompt (a file named `v<a>.<b>.<c>.<d>-agent-prompt*.md`) with no line that begins with `Fixes #N` is an ERROR. L10: an agent prompt (a file name that contains `agent-prompt`) that runs `git checkout main` or `git switch main` inside a code block is an ERROR. L11: a login literal after `-u` or `--user`, or a value after `Authorization: Basic`, is an ERROR; the rule holds no real value, and lint prints only the file, the line and the rule. L9 and L10 read the file name, so the scan of the base content in `--baseline` mode gets the name as a second argument (items 2.3, 2.4, 2.7 to 2.9). L8 reads the live value once and stops lint with exit 2 if it cannot (item 2.10).

**2.1** `scripts/lint-prompts.sh`: immediately after the line
```
# Exit 1 — at least one net-new violation (ERROR) found
```
insert
```
# Exit 2 — rule L8 cannot read the live value it compares with
```

**2.2** `scripts/lint-prompts.sh`: immediately before the line
```
    *)  echo "Unknown rule $1" ;;
```
insert
```
    L8) echo "Rule 61 delay drift — a pdMS_TO_TICKS value within 3 lines of 'Rule 61' differs from the live value in maybe_yield_nvs_scan_()" ;;
    L9) echo "Step agent prompt without a closing line 'Fixes #N' for its PR body (plan of record, section 6)" ;;
    L10) echo "Agent prompt runs 'git checkout main' or 'git switch main' — check the feature branch instead" ;;
    L11) echo "Login literal after -u, --user or 'Authorization: Basic' — take the login from \$ESP_USER and \$ESP_PASS (SEC-003)" ;;
```

**2.3** `scripts/lint-prompts.sh`: replace the line
```
# $1 = path to file whose content to scan
```
with
```
# $1 = path to file whose content to scan
# $2 = repository path of that file; rules L9 and L10 read its name (default: $1)
```

**2.4** `scripts/lint-prompts.sh`: replace the line
```
  local src="$1"
```
with
```
  local src="$1" name="${2:-$1}"
```

**2.5** `scripts/lint-prompts.sh`: immediately before the line
```
  # L7: §9 compound pattern (case-insensitive)
```
insert this text, then one blank line
```
  # L8: Rule 61 delay drift (issue #228 §C13, R5)
  # Rationale: a pdMS_TO_TICKS value within 3 lines of "Rule 61" must equal the live value of
  # maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h (a draft in PR #233 cited 1; the code has 5).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L8\t%s\t%s\n' "$lineno" "$content"
  done < <(awk -v live="$L8_LIVE" '
    { line[NR] = $0 }
    /Rule 61([^0-9]|$)/ { r61[NR] = 1 }
    END {
      for (i = 1; i <= NR; i++) {
        s = line[i]; bad = 0
        while (match(s, /pdMS_TO_TICKS\([ \t]*[0-9]+[ \t]*\)/)) {
          v = substr(s, RSTART, RLENGTH); gsub(/[^0-9]/, "", v)
          if (v + 0 != live + 0) bad = 1
          s = substr(s, RSTART + RLENGTH)
        }
        if (!bad) continue
        for (j = i - 3; j <= i + 3; j++) if (j in r61) { printf "%d:%s\n", i, line[i]; break }
      }
    }' "$src" 2>/dev/null || true)

  # L9: a step agent prompt with no closing line "Fixes #N" (recurrence, R5)
  # Rationale: a step prompt closes its issue from the PR body (plan of record, section 6, move 2).
  # A step agent prompt is a file named v<a>.<b>.<c>.<d>-agent-prompt*.md.
  if [[ "$(basename "$name")" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-agent-prompt.*\.md$ ]] \
     && ! grep -qE '^[[:space:]>*-]*Fixes #[0-9]+' "$src" 2>/dev/null; then
    printf 'L9\t1\t%s\n' "no closing line Fixes #N"
  fi

  # L10: an agent prompt that runs "git checkout main" or "git switch main" (recurrence, R5)
  # Rationale: the agent stays on its feature branch; a branch check replaces the checkout of main.
  # An agent prompt is a file whose name contains "agent-prompt"; only lines inside code blocks count.
  if [[ "$(basename "$name")" == *agent-prompt* ]]; then
    while IFS= read -r raw; do
      lineno="${raw%%:*}"; content="${raw#*:}"
      printf 'L10\t%s\t%s\n' "$lineno" "$content"
    done < <(awk '
      BEGIN { fence_mark = sprintf("%c%c%c", 96, 96, 96) }
      { t = $0; sub(/^[ \t]+/, "", t) }
      substr(t, 1, 3) == fence_mark { in_code = !in_code; next }
      in_code && /git([ \t]+-C[ \t]+[^ \t]+)?[ \t]+(checkout|switch)([ \t]+-[^ \t]+)*[ \t]+main([ \t;&|)]|$)/ { printf "%d:%s\n", NR, $0 }
    ' "$src" 2>/dev/null || true)
  fi

  # L11: a login literal after -u or --user, or a value after "Authorization: Basic" (SEC-003, R5)
  # Rationale: agents and scripts take the login from $ESP_USER and $ESP_PASS. The rule holds no real value.
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    if l11_literal "$content"; then
      printf 'L11\t%s\t%s\n' "$lineno" "$content"
    fi
  done < <(grep -niE -- '-u|--user|authorization' "$src" 2>/dev/null || true)
```

**2.6** `scripts/lint-prompts.sh`: immediately before the line
```
# Build a sorted set of dedup keys "RULE_ID <TAB> LINE_CONTENT" from
```
insert this text, then one blank line
```
# L11 helper: succeed when the line holds a login literal. A login literal is a value after -u or
# --user whose user part is a plain name (letters, digits, . _ @ -), or whose user part is a variable
# and whose password part is not; or any value after "Authorization: Basic" that does not start with
# $, {, <, . or *. Variables ($NAME, ${NAME}, $(...)) and placeholders (<...>) are not literals.
l11_literal() {
  local line="$1" tok val user pass
  if grep -qiE 'authorization:[[:space:]]*basic[[:space:]]+[^[:space:]$<{"`'"'"'.*]' <<< "$line"; then
    return 0
  fi
  while IFS= read -r tok; do
    val="$(sed -E 's/^[^-]?(-u|--user)([[:space:]]+|=)?//; s/^["'"'"']//; s/["'"'"'`]+$//' <<< "$tok")"
    [[ "$val" == *:* ]] || continue
    user="${val%%:*}"; pass="${val#*:}"
    if [[ "$user" =~ ^[A-Za-z0-9._@-]+$ ]]; then return 0; fi
    if [[ "$user" == [\$\<]* && -n "$pass" && "$pass" != [\$\<]* ]]; then return 0; fi
  done < <(grep -oE -- "(^|[^[:alnum:]_-])(-u|--user)([[:space:]]+|=)?(\"[^\"]*\"|'[^']*'|[^[:space:]\"'|;&)]+)" <<< "$line" || true)
  return 1
}
```

**2.7** `scripts/lint-prompts.sh`: replace the line
```
  collect_fail_violations "$file" > "$violations"
```
with
```
  collect_fail_violations "$file" "$file" > "$violations"
```

**2.8** `scripts/lint-prompts.sh`: replace the line
```
  collect_fail_violations "$file" > "$tmp_head"
```
with
```
  collect_fail_violations "$file" "$file" > "$tmp_head"
```

**2.9** `scripts/lint-prompts.sh`: replace the line
```
    collect_fail_violations "$base_src" > "$tmp_base"
```
with
```
    collect_fail_violations "$base_src" "$file" > "$tmp_base"
```

**2.10** `scripts/lint-prompts.sh`: immediately before the line
```
printf 'lint-prompts: checking %d file(s)%s\n' \
```
insert this text, then one blank line
```
# Rule L8 compares with the live yield value of maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h.
L8_LIVE="$(grep -A6 '^static void maybe_yield_nvs_scan_(' firmware/core/nvs-persistence.h 2>/dev/null \
  | grep -oE 'pdMS_TO_TICKS\([0-9]+\)' | head -n 1 | grep -oE '[0-9]+' || true)"
if [[ -z "$L8_LIVE" ]]; then
  echo "lint-prompts: rule L8 cannot read the live value of maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h" >&2
  exit 2
fi
```

**2.11** Copy the nine supplied files of `tests/lint-prompts/`: one passing and one failing fixture for each rule, with made-up values only, and `run-fixtures.sh`, which runs each fixture in normal and in `--baseline` mode. It must print `copied 9 files`.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh copy 2
```

⛔ **CHECKPOINT B** — each new rule against its two fixtures in normal and in `--baseline` mode; all prompts of `main` in `--baseline` mode with 0 ERROR and the expected EXISTING counts.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh B
```

### Task Group 3 — Stress-test login (R5 item 5)

The script loses its default login. It stops with exit 2, before any request, when `ESP_USER` or `ESP_PASS` is unset or empty.

**3.1** `scripts/stress-test-httpd-stack.sh`: immediately after the line
```
#   - curl and jq installed
```
insert
```
#   - ESP_USER and ESP_PASS set in your shell (SEC-003); the script holds no login and stops without one
```

**3.2** `scripts/stress-test-httpd-stack.sh`: exactly one line begins with `AUTH="${ESP_AUTH:-`. Replace that whole line with
```
if [[ -z "${ESP_USER:-}" || -z "${ESP_PASS:-}" ]]; then
    echo "ERROR: ESP_USER and ESP_PASS must be set in your shell (SEC-003). This script holds no login." >&2
    exit 2
fi
AUTH="${ESP_USER}:${ESP_PASS}"
```

⛔ **CHECKPOINT C** — the script stops without a login and sends nothing; with made-up values it passes them to `curl`.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh C
```

### Task Group 4 — CI fast path for documentation PRs (R5 item 6, PLAN-028)

The job `preflight-and-compile` still starts on every pull request. Its new second step lists the paths that the pull request changes and sets `docs_only`. The list of documentation paths is fixed by this prompt: `Docs/**`, `prompts/**`, `README.md`, `CURRENT-STATE.md`, `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`. Any other path, an empty diff, a push and a manual run take the full job. The checkout fetches the whole history so that the step can compare the head of the pull request with `origin/<base>`.

**4.1** `.github/workflows/ci.yml`: replace the line
```
    # Required status checks must run for documentation-only PRs too.
```
with
```
    # Required status checks must run for documentation-only PRs too (PLAN-020).
    # Such a PR takes the fast path that the step "List changed paths" decides (PLAN-028).
```

**4.2** `.github/workflows/ci.yml`: immediately after the line
```
        uses: actions/checkout@v4
```
insert
```
        with:
          fetch-depth: 0

      - name: List changed paths
        id: paths
        shell: bash
        env:
          BASE_REF: ${{ github.base_ref }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          set -euo pipefail
          # PLAN-028: a pull request whose every changed path is documentation runs preflight only.
          # Any other path, an empty diff, a push and a manual run take the full job.
          docs_only=false
          if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
            git diff --name-only --no-renames "origin/${BASE_REF}...${HEAD_SHA}" > "$RUNNER_TEMP/changed-paths.txt"
            if [[ -s "$RUNNER_TEMP/changed-paths.txt" ]]; then
              docs_only=true
              while IFS= read -r p; do
                case "$p" in
                  Docs/*|prompts/*|README.md|CURRENT-STATE.md|AGENTS.md|CLAUDE.md) ;;
                  .github/copilot-instructions.md|.github/instructions/*.instructions.md) ;;
                  *) docs_only=false ;;
                esac
              done < "$RUNNER_TEMP/changed-paths.txt"
            fi
            echo "Changed paths: $(wc -l < "$RUNNER_TEMP/changed-paths.txt")"
          fi
          echo "docs_only=${docs_only}" >> "$GITHUB_OUTPUT"
          if [[ "$docs_only" == "true" ]]; then
            echo "### Fast path: documentation only; ESPHome install and compile skipped (PLAN-028)" >> "$GITHUB_STEP_SUMMARY"
          else
            echo "### Full job: ESPHome install and compile" >> "$GITHUB_STEP_SUMMARY"
          fi
```

**4.3** `.github/workflows/ci.yml`: immediately after the line
```
      - name: Install dependencies
```
insert
```
        if: steps.paths.outputs.docs_only != 'true'
```

**4.4** `.github/workflows/ci.yml`: immediately after the line
```
      - name: Minify dashboard
```
insert
```
        if: steps.paths.outputs.docs_only != 'true'
```

**4.5** `.github/workflows/ci.yml`: immediately after the line
```
      - name: Regenerate dashboard.h from minified source
```
insert
```
        if: steps.paths.outputs.docs_only != 'true'
```

**4.6** `.github/workflows/ci.yml`: immediately after the line
```
      - name: Compile firmware
```
insert
```
        if: steps.paths.outputs.docs_only != 'true'
```

⛔ **CHECKPOINT D** — the structure of `ci.yml`, and the step "List changed paths" on 15 cases.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh D
```

### Task Group 5 — Browser-test report (R5 item 7, PLAN-020)

Preflight keeps the output of the browser test in a temporary file and prints it when the test fails. It still fails. CHECKPOINT E runs preflight once with a stand-in for `npx` that fails on purpose.

**5.1** `scripts/preflight.sh`: replace these 2 consecutive lines
```
    npx playwright test tests/browser/manifest.spec.js --project=chromium >/dev/null
    pass "playwright_manifest_spec"
```
with
```
    # R5 (PLAN-020): keep the report of the browser test, and print it when the test fails.
    PW_LOG="$(mktemp)"
    if npx playwright test tests/browser/manifest.spec.js --project=chromium >"$PW_LOG" 2>&1; then
      rm -f "$PW_LOG"
      pass "playwright_manifest_spec"
    else
      echo "    playwright report:"
      sed 's/^/    /' "$PW_LOG"
      rm -f "$PW_LOG"
      fail "playwright_manifest_spec"
    fi
```

⛔ **CHECKPOINT E** — preflight prints the report of a failing browser test and still fails.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh E
```

### Task Group 6 — PR-body check and CI tests (R5 item 8, PLAN-031)

**6.1** Copy the supplied workflow `.github/workflows/pr-body-check.yml`. It runs on every pull request to `main`, also when the body is edited, and passes when no path under `prompts/` changed. It must print `copied 1 file`.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh copy 6
```

**6.2** `.github/workflows/prompt-lint.yml`: immediately after the line
```
      - 'scripts/lint-prompts.sh'
```
insert
```
      - 'scripts/scope-gate.py'
      - 'tests/lint-prompts/**'
      - 'tests/scope-gate/**'
```

**6.3** `.github/workflows/prompt-lint.yml`: immediately before the line
```
      - name: Write lint summary
```
insert this text, then one blank line
```
      - name: Run lint fixtures and scope-gate cases
        shell: bash
        run: |
          bash tests/lint-prompts/run-fixtures.sh
          bash tests/scope-gate/run-tests.sh
```

⛔ **CHECKPOINT F** — the structure of both workflows, and the step "Check the PR body" on 6 cases.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh F
```

### Task Group 7 — Reproducible dashboard header (PLAN-031)

`gzip -n` stores no file name and no time stamp in the gzip header, so the same dashboard gives the same `dashboard/dashboard.h`.

**7.1** `scripts/generate-header.sh`: replace the line
```
gzip -9 -c "$INPUT" > "$TMPGZ"
```
with
```
# -n stores no file name and no time, so the same input gives the same header (R5, PLAN-031)
gzip -9 -n -c "$INPUT" > "$TMPGZ"
```

**7.2** Run the full pipeline once. It writes `dashboard/dashboard.h` again; no other file may change.

```bash
cd /root/config/ESP32-GW-multi-sensor && bash scripts/provision.sh satellite
```

Its last lines say that the configuration is the C3 satellite and that it is safe to push. If it fails, STOP and post the checkpoint-failure comment with its last 20 lines.

⛔ **CHECKPOINT G** — the header holds the same dashboard, no file name and no time; a second pipeline run changes nothing.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh G
```

### Task Group 8 — Documents: state, plan, decisions, process guide, planner page, operator page, review file

Two status marks change in `Docs/plan-of-record.md` (the ladder and "You are here") and three in `CURRENT-STATE.md`; CHECKPOINT H searches the whole file for the old wording of each. Add the three decision rows directly below the row of PLAN-030, in the order given.

**8.1** `CURRENT-STATE.md`: exactly one line begins with `_Next action: `. Replace that whole line with
```
_Next action: R5r, the review-runner PR (PLAN-022). The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5r, R5a and R5b._
```

**8.2** `CURRENT-STATE.md`: replace the line
```
1. **R5, R5r, R5a, R5b** — the tooling PR, the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.
```
with
```
1. **R5r, R5a, R5b** — the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.
```

**8.3** `CURRENT-STATE.md`: replace the line
```
| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Not implemented** — code change, needs its own PR |
```
with
```
| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Implemented in R5** — `scripts/generate-header.sh` compresses with `gzip -n`; the pipeline wrote the header once (PLAN-031) |
```

**8.4** `CURRENT-STATE.md`: replace the line
```
| PR #234 | `scripts/preflight.sh` sends the browser test's report to `/dev/null`, so a failure leaves no evidence | **Not implemented** — routed to the tooling PR (PLAN-020) |
```
with
```
| PR #234 | `scripts/preflight.sh` sends the browser test's report to `/dev/null`, so a failure leaves no evidence | **Implemented in R5** — preflight prints the report when the browser test fails (PLAN-020) |
```

**8.5** `CURRENT-STATE.md`: replace the line
```
| PR #235 review (Muse) | Literal management login remains in live test scripts and historical records; the housekeeping scrub covers only seven named files | **Not implemented** — live-script cleanup and secret rotation routed to v7.7.1.5 (SEC-003); historical records and git history retain old values |
```
with
```
| PR #235 review (Muse) | Literal management login remains in live test scripts and historical records; the housekeeping scrub covers only seven named files | **Partly implemented in R5** — `scripts/stress-test-httpd-stack.sh` holds no default login now; `scripts/exporters/system-metrics-exporter.sh` still sets default values for `METRICS_USER` and `METRICS_PASS`; live-script cleanup and secret rotation routed to v7.7.1.5 (SEC-003); historical records and git history retain old values |
```

**8.6** `Docs/plan-of-record.md`: replace the line
```
The next step is **R5**, the tooling PR. The last merged step is **R3c**, the pull request that added this file.
```
with
```
The next step is **R5r**, the review-runner PR. The last merged step is **R5**, the tooling PR.
```

**8.7** `Docs/plan-of-record.md`: replace the line
```
| 4a | R3c | Plan into the repository: this file, entry points by role, the archive of `Docs/`, the instruction files, the stop rules | Dispatch, review, merge | R3b | 7.7.1.1 | 2 to 3 | Done: the pull request that added this file |
```
with
```
| 4a | R3c | Plan into the repository: this file, entry points by role, the archive of `Docs/`, the instruction files, the stop rules | Dispatch, review, merge | R3b | 7.7.1.1 | 2 to 3 | Done 2026-11-16, PR #236 (`84e8569`) |
```

**8.8** `Docs/plan-of-record.md`: replace the line
```
| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login | SP without the device moves | R3c | Unchanged | 2 to 3 | Waiting |
```
with
```
| 5 | R5 | Tooling PR (LOW): scope gate, lint rules, CI fast path for documentation PRs, visible browser-test report, PR-body check, stress-test login, reproducible dashboard header | SP without the device moves | R3c | Unchanged | 2 to 3 | Done: the pull request that added `scripts/scope-gate.py` |
```

**8.9** `Docs/plan-of-record.md`: replace the line
```
- Scope, and nothing else (PLAN-017, PLAN-020, PLAN-028):
```
with
```
- Scope, and nothing else (PLAN-017, PLAN-020, PLAN-028, PLAN-031):
```

**8.10** `Docs/plan-of-record.md`: immediately after the line
```
  8. A PR-body check that fails when a pull request that touches `prompts/**` has no "Pre-Implementation Verification" heading.
```
insert
```
  9. `scripts/generate-header.sh` compresses with `gzip -n`, so `dashboard/dashboard.h` changes only when the dashboard changes; R5 writes the header once with the pipeline (PLAN-031).
```

**8.11** `Docs/plan-of-record.md`: immediately after the line
```
- Each lint rule gets one passing and one failing fixture under `tests/lint-prompts/`, with made-up values only, and works in `--baseline` mode, so old prompts report EXISTING and do not block.
```
insert
```
- The workflow `prompt-lint` also runs these fixtures and the two scope-gate cases (PLAN-031).
```

**8.12** `Docs/plan-of-record.md`: replace the line
```
- R5 also decides whether the planning tools (the prompt builder and the rehearsal script) and the operator's helper file enter the repository (section 10).
```
with
```
- Decided in R5 (PLAN-033): the planning tools (the prompt builder and the rehearsal script) and the operator's helper file stay outside the repository.
```

**8.13** `Docs/plan-of-record.md`: replace the line
```
- Done when: merged; `bash scripts/lint-prompts.sh` runs the new rules, each with its two fixtures; `scripts/scope-gate.py` passes its two cases; the stress-test script stops without a login in the environment; a documentation-only pull request skips the compile; issue #228 §C is closed.
```
with
```
- Done when: merged; `bash scripts/lint-prompts.sh` runs the new rules, each with its two fixtures; `scripts/scope-gate.py` passes its two cases; the stress-test script stops without a login in the environment; a documentation-only pull request skips the compile; a second run of the pipeline leaves `dashboard/dashboard.h` unchanged; issue #228 §C is closed.
```

**8.14** `Docs/plan-of-record.md`: exactly one line begins with
```
| Lint errors that exist in old prompts must not block new work |
```
Delete that whole line.

**8.15** `Docs/plan-of-record.md`: exactly one line begins with
```
| The planning tools (prompt builder, rehearsal script) and the operator's helper file
```
Delete that whole line.

**8.16** `Docs/plan-of-record.md`: exactly one line begins with
```
| Copilot did not complete its review of PR #234
```
Delete that whole line.

**8.17** `Docs/decisions/decision-log.md`: immediately after the line that begins with
```
| 2026-11-16 | PLAN-030 |
```
insert
```
| 2026-11-16 | PLAN-031 | R5 additions (operator decisions 2026-11-16; they widen the R5 list of PLAN-017, PLAN-020 and PLAN-028, an exception to PLAN-012): `scripts/generate-header.sh` compresses with `gzip -n`, so `dashboard/dashboard.h` changes only when the dashboard changes, and R5 writes it once with the pipeline (R3c closure, finding 3); the workflow `prompt-lint` also runs the lint fixtures in `tests/lint-prompts/` and the two scope-gate cases in `tests/scope-gate/`; the PR-body check `pr-body-check` runs on every pull request to `main` and passes when no path under `prompts/` changed, so that the operator can make it a required check. From R5 on, the planning session hands over every gate and checkpoint of a prompt as one check file with its SHA-256, and the agent runs that file and types no check (R3c closure, finding 2) | `prompts/handoff/phase7/tooling-2026-11-16.md` §6 |
| 2026-11-16 | PLAN-032 | Copilot's inline review is accepted as it is (operator decision 2026-11-16; R3c closure, finding 1): Copilot did not complete its review of PR #234, reviewed PR #235, and limited its review of PR #236 because of "model policy or plan restrictions"; no plan change comes first. When Copilot posts no complete review on a code PR, the agent's assessment says so, the round summary counts it as not posted, and the step goes on with the other inline reviews and reviews A and B; the operator decides at the merge. This qualifies "five reviewers on every code step" of PLAN-017 for Copilot only | `prompts/handoff/phase7/tooling-2026-11-16.md` §6 |
| 2026-11-16 | PLAN-033 | The planning tools (the builder and the rehearsal script of each step) and the operator's helper file (`fleet`, `backup_history`, `board_port`) stay outside the repository (operator decision 2026-11-16; closes the finding of plan of record section 10 that R5 owned). Each builder serves one step, and the helper file touches hub ports, which the plan of record keeps out of the repository. The operator keeps them as files, and the gate record of a step names the builder and the rehearsal script that produced it | `prompts/handoff/phase7/tooling-2026-11-16.md` §6 |
```

**8.18** `Docs/development-process-guide.md`: immediately after the line
```
12) Stops: a known tooling defect with a recovery written in the prompt gets that recovery once, with the result posted, and a second failure stops; a value you would have to ask for is in the prompt; a real mismatch (a missing anchor, a different value, a path out of scope, a test failing twice) always stops with the checkpoint-failure comment of §3.2
```
insert
```
13) Run every gate and checkpoint from the check file that the prompt names, exactly as the prompt says; never type a check by hand
```

**8.19** `Docs/development-process-guide.md`: replace the line
```
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance.
```
with
```
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance. Item 13 holds from R5 on (PLAN-031): the planning session hands over every check in one check file with its SHA-256.
```

**8.20** `Docs/development-process-guide.md`: immediately after the line that begins with
```
Claude Code is the fallback coding agent (PLAN-026).
```
insert one blank line, then
```
When Copilot posts no complete review, the agent's assessment says so, and the step goes on with the other inline reviews and the external reviews; the operator decides at the merge (PLAN-032).
```

**8.21** `Docs/development-process-guide.md`: replace these 3 consecutive lines
```
which invokes `scripts/lint-prompts.sh` against the PR's changed files. ERROR-level violations
(L1–L5, L7: stale IPs, wrong filenames, forbidden section titles, cross-prompt references)
fail the PR. WARN-level findings (L6: pipeline-ordering advisory) are reported without blocking.
```
with
```
which invokes `scripts/lint-prompts.sh --baseline` against the PR's changed files. ERROR-level violations
(L1–L5, L7: stale IPs, wrong filenames, forbidden section titles, cross-prompt references; L8: a Rule 61
delay that differs from the live value in `maybe_yield_nvs_scan_()`; L9: a step agent prompt without a
closing line `Fixes #N`; L10: an agent prompt that runs `git checkout main` or `git switch main` in a code
block; L11: a login literal after `-u`, `--user` or `Authorization: Basic`) fail the PR. A violation that
the base of the PR already has is reported as EXISTING and does not block. WARN-level findings (L6:
pipeline-ordering advisory) are reported without blocking. The same workflow runs the passing and the
failing fixture of each rule from L8 on (`tests/lint-prompts/run-fixtures.sh`) and the two scope-gate
cases (`tests/scope-gate/run-tests.sh`). The workflow `pr-body-check.yml` fails a PR that touches
`prompts/**` and has no "Pre-Implementation Verification" heading in its body.
```

**8.22** `Docs/development-process-guide.md`: immediately after the line
```
The CI workflow (`.github/workflows/ci.yml`) runs its `preflight-and-compile` job on every pull request to `main`, documentation-only ones too: branch protection requires that check, and a required check that a path filter skips blocks the merge (PLAN-020). On a push to `main` the workflow still runs only for changes to code, config, scripts and build files.
```
insert one blank line, then
```
The job takes a fast path for documentation (PLAN-028). Its step "List changed paths" reads the paths that the pull request changes. When every path is under `Docs/` or `prompts/`, or is `README.md`, `CURRENT-STATE.md`, `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` or a file `.github/instructions/*.instructions.md`, the job runs preflight only: it skips the ESPHome install, the dashboard minify, the header and the compile. Any other path, an empty diff, a push to `main` and a manual run take the full job.
```

**8.23** `Docs/planner-start-here.md`: replace the line
```
6. Hand over: the prompt, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text.
```
with
```
6. Hand over: the prompt, the check file, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text. The check file holds every gate and checkpoint of the prompt, so the agent runs it and types no check (PLAN-031).
```

**8.24** `Docs/planner-start-here.md`: replace the line
```
## Rules that came from review findings (PR #234, PR #235)
```
with
```
## Rules that came from review findings (PR #234, PR #235, PR #236)
```

**8.25** `Docs/planner-start-here.md`: immediately after the line
```
- A prompt that changes a file an agent loads (`AGENTS.md`, `CLAUDE.md`, the Copilot files) says so in the review file, because Copilot reads these files from the head branch of the pull request.
```
insert
```
- Every gate and checkpoint of a prompt is in its check file, which has a known SHA-256; the agent runs the file and never types a check (PR #236: the agent typed the §2 gate by hand, with wrong dates).
```

**8.26** Copy the two supplied files: the completed operator page `Docs/operator/R5-tooling.md` and the review file `prompts/handoff/phase7/tooling-2026-11-16-review.md`. It must print `copied 2 files`.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh copy 8
```

⛔ **CHECKPOINT H** — every edit and every status mark of Task Group 8, and the two supplied files.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh H
```

### Task Group 9 — Record of this step (its consolidated audit)

**9.0** The setup block has made this prompt and its check file, verbatim, the first commit after the bootstrap commit. Confirm it with `git log --oneline -- prompts/handoff/phase7/tooling-2026-11-16-agent-prompt.md prompts/handoff/phase7/tooling-2026-11-16-checks.sh`: one commit. If it is missing, STOP.

**9.1** Create `prompts/handoff/phase7/tooling-2026-11-16.md` with these nine sections, each under a heading line that begins `## §<number> `, in this order: §1 Why (R5 in the plan of record, PLAN-017, PLAN-020, PLAN-028 and PLAN-031; the three findings of the R3c closure); §2 Edit list, one row per item 1.1 to 8.26 with the check that covers it and its observed output; §3 Review findings by severity (fill after the last review round; name every reviewer that ran, and state plainly when one did not post or did not complete, PLAN-032); §4 Agent autonomous decisions (expected none); §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2, with any use of the recovery of the PRE-PR gate; §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the issue #228 status table below, verbatim, with `<NN>` replaced by this PR's number; §8 Process metrics (the five numbers of HowTo v2 §5.6); §9 Recommendations and where each was routed (process guide §2.5 item 4 (d)). For §8 the operator supplies two numbers: producer sessions 1 (restart check, decisions, production, rehearsal and gate on 2026-11-16) and audit sessions 0 (LOW tier: lint and one rehearsal inside the producer session). Take the other three from this PR.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-031 | The reproducible header, the CI run of the lint fixtures and the scope-gate cases, a PR-body check that can be required, and a check file for every prompt | The header changed on every build and disturbed three documentation steps. A linter that CI does not test can break unseen. A required check must report on every pull request. In PR #236 the agent typed a gate by hand, with wrong dates |
| PLAN-032 | Copilot's inline review is accepted as it is; a missing review is named and counted, and the step goes on | Copilot completed one of its last three reviews. Reviews A and B still cover every code step |
| PLAN-033 | The planning tools and the helper file stay outside the repository | Each builder serves one step. The helper file touches private values that the plan of record keeps out of the repository |
```

Issue #228 status table for §7 of the record:
```
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
| Plan of record into the repository | Merged in PR #236 | `Docs/plan-of-record.md`, entry points by role, archive of `Docs/`, instruction files, PLAN-022 to PLAN-030 |
| §C meta-prompt guardrails | CLOSED — tooling merged in PR #<NN> (R5) | Scope gate, lint rules L8 to L11, CI fast path for documentation PRs, PR-body check; the meta-prompt items of §C are inputs to the producer contract (R5a) |
| §D phase-closure questions | DEFERRED — folded into the v7.7.3.3 closure prompt | |
| §E producer-prompt evolution | OPEN — producer contract and batch-production prompt v3.0 (R5a) | v3.0 must be shorter than v2.0 (PLAN-012) |

**Dispatch state: the May Batch 2 prompts (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) are NOT dispatched. They are re-produced under the method of record first. The order of all steps is in `Docs/plan-of-record.md`.**
```

⛔ **CHECKPOINT I** — the nine sections, the two tables, and no `<NN>` left.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh I
```

### PRE-PR Gate

Commit and push everything first; the gate stops on an uncommitted change.

```bash
bash /root/r5/tooling-2026-11-16-checks.sh prepr
```

It must end with `PRE-PR PASS`. Its first check is `scripts/scope-gate.py` against the list of §3. It also runs lint on the prompt files of this PR, rule L11 on every changed file, the lint fixtures, the two scope-gate cases and the real `scripts/preflight.sh`.

Known tooling defect: the browser test of preflight has failed once without cause (PR #234). From this step on, preflight prints its report. If the block stops with `PRE-PR: preflight` and the output shows `playwright_manifest_spec: FAIL`, the operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; post the lines after `playwright report:` as a PR comment; run the PRE-PR block one more time, unchanged. If it fails again, STOP and report. Record the event in §5 of the record file. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027, PLAN-032)

1. Update the PR body (§8), then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini. Do not wait longer.
4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions").
5. After a fix, run every CHECKPOINT that covers the changed file, and the PRE-PR block, again.
6. Fill §3 of the record file, commit, push, and post one comment with your assessment. Name each reviewer that posted, and each one that did not post within the 30 minutes. If Copilot posted no complete review, say so; the step goes on without it (PLAN-032).
7. Never merge, never approve, and never start an external review. The operator starts reviews A and B and pastes one line to you after each; then assess, fix and post again as in items 4 to 6.

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to I and the PRE-PR block each print PASS; their verbatim output is in the PR body
- [ ] Exactly the §3 paths changed: 13 changed files and 16 new files; no file deleted or renamed; `VERSION` unchanged; no firmware source changed
- [ ] `scripts/scope-gate.py` is byte-identical to the HowTo v2.3.1 template, and its two cases pass
- [ ] The 13 cases of `tests/lint-prompts/run-fixtures.sh` pass; lint of all prompts against `origin/main` reports 0 ERROR, and EXISTING lines L8: 2, L9: 19, L10: 10, L11: 28
- [ ] The stress-test script exits 2 without `ESP_USER` or `ESP_PASS` and sends no request
- [ ] The step "List changed paths" gives the expected `docs_only` on all 15 cases of CHECKPOINT D; this PR's own `preflight-and-compile` run takes the full job, because the PR changes scripts
- [ ] Preflight prints the report of a failing browser test and still fails
- [ ] `pr-body-check` passes on all 6 cases of CHECKPOINT F and on this PR
- [ ] `dashboard/dashboard.h` holds the same dashboard as on `main`, with no file name and no time in its gzip header, and a second pipeline run leaves it unchanged
- [ ] The GitHub checks `preflight-and-compile`, `prompt-lint` and `pr-body-check` pass on the final head
- [ ] The record file is complete after the last review round and committed before the merge
- [ ] PR title: `tooling: R5 — scope gate, lint rules L8 to L11, CI fast path, PR-body check, reproducible dashboard header (refs #228)`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet, each under a `## ` heading; the first heading is exactly `## Pre-Implementation Verification`. Under Files Modified, list the 13 changed and the 16 new files by name, and paste the line that `scripts/scope-gate.py` printed in the PRE-PR gate. Device testing: N/A — this step flashes no board and calls no board.

Until the body has that heading, the check `pr-body-check` fails on this PR; that is expected, and the check runs again when you edit the body. The workflow `Browser Tests` also starts on this PR, because it watches `tests/**` and `scripts/preflight.sh`; give its result in the Round Summary.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag, and it closes no issue. After the merge the operator replaces the status table at the top of issue #228 with the table in §7 of the record file, makes `pr-body-check` a required check, and checks the CI fast path once with a documentation pull request that is never merged. You run none of it.
