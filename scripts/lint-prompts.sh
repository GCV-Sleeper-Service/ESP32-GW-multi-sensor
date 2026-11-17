#!/usr/bin/env bash
# scripts/lint-prompts.sh — Detect forbidden patterns in prompts/**
#
# Usage:
#   lint-prompts.sh [--baseline <git-ref>] [file ...]
#
#   --baseline <git-ref>   Diff mode: only violations absent at <git-ref>
#                          increment FAIL_COUNT. Pre-existing violations are
#                          printed with prefix EXISTING and do not block the PR.
#
#   Without file args:  lints all tracked files under prompts/**
#   With file args:     lints only those files (used by CI for PR-changed files)
#
# Exit 0 — clean, WARN only, or all violations are pre-existing
# Exit 1 — at least one net-new violation (ERROR) found
# Exit 2 — rule L8 cannot read the live value it compares with
#
# Output format:
#   ERROR    <file>:<line>: [LN] <desc>  — new violation; blocks PR
#   EXISTING <file>:<line>: [LN] <desc>  — pre-existing; informational only
#   WARN     <file>:<line>: [LN] <desc>  — advisory; does not block

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------------------------------------------------------------------------
# Exclusions — files that legitimately quote forbidden patterns (audit reports,
# operator notes, raw session transcripts).  Hardcoded by full repo-relative
# path; no glob matching to avoid accidental over-exclusion.
# ---------------------------------------------------------------------------
EXCLUDED_FILES=(
  "prompts/handoff/phase7/operator-notes.txt"
  "prompts/handoff/phase7/new-prompts-audit-session.txt"
  "prompts/handoff/phase7/new-session-analysis-conclusion.txt"
  "prompts/handoff/phase7/new-prompts-audit-report-Copilot.md"
  "prompts/handoff/phase7/new-prompts-audit-report-Perplexity.md"
  "prompts/handoff/phase7/new-prompts-audit-report-Opus4.7.md"
  "prompts/handoff/phase7/phase7-batch2-prompt-audit-report-GPT.md"
  "prompts/handoff/phase7-prompt-production-instructions.md"
  "Docs/lessons-by-phase.md"
)

is_excluded() {
  local f="${1#./}"   # C6: strip any leading ./ so both ./foo and foo match
  for ex in "${EXCLUDED_FILES[@]}"; do
    [[ "$f" == "$ex" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
FAIL_COUNT=0
WARN_COUNT=0

emit_error()    { echo "ERROR    $1"; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }
emit_existing() { echo "EXISTING $1"; }
emit_warn()     { echo "WARN     $1"; WARN_COUNT=$(( WARN_COUNT + 1 )); }

# ---------------------------------------------------------------------------
# Human-readable message per rule ID
# ---------------------------------------------------------------------------
rule_message() {
  case "$1" in
    L1) echo "Forbidden title 'Post-Merge Deliverables' — use 'Post-Merge Bookkeeping (tag and close only)'" ;;
    L2) echo "Forbidden '(for Human)'/'for Human' in section header — remove the qualifier" ;;
    L3) echo "Cross-prompt version reference — breaks self-containedness (Docs/development-process-guide.md §3.3)" ;;
    L4) echo "Stale WROOM IP 192.168.120.190 — verify current IP via Board Info Extraction Gate" ;;
    L5) echo "Wrong YAML filename 'esp32-wroom-32d-multi-sensor.yaml' — use 'esp32-wroom-32d-gw.yaml'" ;;
    L7) echo "Forbidden §9 compound pattern — §9 must not reference 'Post-Merge Deliverables'" ;;
    L8) echo "Rule 61 delay drift — a pdMS_TO_TICKS value within 3 lines of 'Rule 61' differs from the live value in maybe_yield_nvs_scan_()" ;;
    L9) echo "Step agent prompt without a closing line 'Fixes #N' for its PR body (plan of record, section 6)" ;;
    L10) echo "Agent prompt runs 'git checkout main' or 'git switch main' — check the feature branch instead" ;;
    L11) echo "Login literal after -u, --user or 'Authorization: Basic' — take the login from \$ESP_USER and \$ESP_PASS (SEC-003)" ;;
    *)  echo "Unknown rule $1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Collect FAIL-class violations from a content source file.
# Outputs one TSV line per violation:  RULE_ID <TAB> LINENO <TAB> LINE_CONTENT
# $1 = path to file whose content to scan
# $2 = repository path of that file; rules L9 and L10 read its name (default: $1)
# ---------------------------------------------------------------------------
collect_fail_violations() {
  local src="$1" name="${2:-$1}"
  local raw lineno content

  # L1: "Post-Merge Deliverables" (case-sensitive)
  # Rationale: §9 anatomy bug — allowed title is "Post-Merge Bookkeeping (tag and close only)".
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L1\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -n "Post-Merge Deliverables" "$src" 2>/dev/null || true)

  # L2: "(for Human)" or "for Human" in section headers (lines starting with #)
  # Rationale: "Device Testing (for Human)" anti-pattern (audit E-2 / Opus B1).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L2\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -nE '^#.*(\(for Human\)|for[[:space:]]+Human)' "$src" 2>/dev/null || true)

  # L3: Cross-prompt version references (case-insensitive)
  # Rationale: "see v7.X.Y.Z prompt §" breaks self-containedness (§3.3).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L3\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -niE 'see[[:space:]]+v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+prompt' "$src" 2>/dev/null || true)

  # L4: Stale WROOM IP 192.168.120.190
  # Rationale: Belt-and-braces; Board Info Extraction Gate should prevent this (audit E-3).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L4\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -n '192\.168\.120\.190' "$src" 2>/dev/null || true)

  # L5: Wrong WROOM YAML filename
  # Rationale: Correct filename is esp32-wroom-32d-gw.yaml (audit E-3).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L5\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -n 'esp32-wroom-32d-multi-sensor\.yaml' "$src" 2>/dev/null || true)

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

  # L7: §9 compound pattern (case-insensitive)
  # Rationale: Catches variants that L1 string match would miss (audit E-1).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L7\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -niE '§9.*Post.Merge.*Deliverables' "$src" 2>/dev/null || true)
}

# L11 helper: succeed when the line holds a login literal. A login literal is a value after -u or
# --user whose user part is a plain name (letters, digits, . _ @ -), or whose user part is a variable
# and whose password part is not; or any bare or quoted value after "Authorization: Basic" that does not start with
# $, {, <, . or *. Variables ($NAME, ${NAME}, $(...)) and placeholders (<...>) are not literals.
l11_literal() {
  local line="$1" tok val user pass
  if grep -qiE 'authorization:[[:space:]]*basic[[:space:]]+["'"'"'`]?[^[:space:]$<{"`'"'"'.*]' <<< "$line"; then
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

# Build a sorted set of dedup keys "RULE_ID <TAB> LINE_CONTENT" from
# collect_fail_violations output. Field 2 (line number) is stripped; fields
# 1 (rule ID) and 3+ (line content, which may itself contain tabs) are kept.
# Using content (not line number) as the key keeps violations stable across
# line position changes caused by unrelated edits elsewhere in the file.
violation_keys() {
  awk -F'\t' '{
    key = $1
    for (i = 3; i <= NF; i++) key = key "\t" $i
    print key
  }' "$1" | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# Check L6 (WARN-only) violations for a file.
# L6 is advisory and is never compared against a baseline.
# $1 = display file path (used in output messages)
# ---------------------------------------------------------------------------
check_warn_violations() {
  local file="$1"
  local warn_line
  # L6: assemble-sensor-history.sh --check appearing before --write within 20 lines (WARN)
  # Rationale: Best-effort ordering check (audit E-5). In prompts that describe the pipeline,
  # finding --check immediately followed by --write in the same section suggests the prompt
  # may be conflating the CI verification step (--check) with the code-generation step
  # (--write). The two flags serve different phases and should not appear in close succession
  # as sequential agent instructions. WARN only — a human must judge whether the ordering is
  # intentional (e.g., a "verify then regenerate" pattern) or an authoring error.
  while IFS= read -r warn_line; do
    [[ -n "$warn_line" ]] && emit_warn "$warn_line"
  done < <(awk -v f="$file" '
    /assemble-sensor-history\.sh[[:space:]]+--check/ { check_line = NR }
    /assemble-sensor-history\.sh[[:space:]]+--write/ {
      if (check_line > 0 && NR - check_line <= 20) {
        printf "%s:%d: [L6] assemble-sensor-history.sh --check appears before --write within 20 lines — verify pipeline ordering\n", f, check_line
        check_line = 0
      }
    }
  ' "$file" 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# Normal mode: all violations in the file are reported as ERROR.
# $1 = file path (relative to repo root)
# ---------------------------------------------------------------------------
check_file_normal() {
  local file="$1"
  is_excluded "$file" && return 0
  [[ -f "$file" ]] || return 0

  local violations
  violations="$(mktemp)"
  collect_fail_violations "$file" "$file" > "$violations"

  local rule lineno content
  while IFS=$'\t' read -r rule lineno content; do
    emit_error "$file:$lineno: [${rule}] $(rule_message "$rule")"
  done < "$violations"
  rm -f "$violations"

  check_warn_violations "$file"
}

# ---------------------------------------------------------------------------
# Baseline mode: compare HEAD violations against a baseline git ref.
# Violations absent at the baseline ref are ERROR (new drift).
# Violations already present at the baseline ref are EXISTING (informational).
# $1 = file path  $2 = baseline git ref
# ---------------------------------------------------------------------------
check_file_baseline() {
  local file="$1" baseline_ref="$2"
  is_excluded "$file" && return 0
  [[ -f "$file" ]] || return 0

  local tmp_head tmp_base tmp_head_keys tmp_base_keys tmp_new_keys base_src
  tmp_head="$(mktemp)"
  tmp_base="$(mktemp)"
  tmp_head_keys="$(mktemp)"
  tmp_base_keys="$(mktemp)"
  tmp_new_keys="$(mktemp)"
  base_src="$(mktemp)"

  # Collect HEAD violations (working tree)
  collect_fail_violations "$file" "$file" > "$tmp_head"
  violation_keys "$tmp_head" > "$tmp_head_keys"

  # Collect BASELINE violations (file content at the given ref, blobs only).
  # The cat-file blob check guards against the edge case where the path was a
  # directory (tree object) at baseline, preventing tree metadata from being
  # treated as file content. If the path doesn't exist or isn't a blob at
  # baseline, all HEAD violations are treated as new.
  if git cat-file -t "${baseline_ref}:${file}" 2>/dev/null | grep -q "^blob$" && \
     git show "${baseline_ref}:${file}" > "$base_src" 2>/dev/null; then
    collect_fail_violations "$base_src" "$file" > "$tmp_base"
  else
    # File did not exist, was not a regular blob, or baseline ref is invalid
    # — every HEAD violation is new
    : > "$tmp_base"
  fi
  violation_keys "$tmp_base" > "$tmp_base_keys"

  # New = present in HEAD but absent from BASELINE (comm -23 on sorted inputs)
  comm -23 "$tmp_head_keys" "$tmp_base_keys" > "$tmp_new_keys"

  # Load new-violation keys into an associative array for O(n) lookups.
  declare -A new_keys_set
  while IFS= read -r k; do
    new_keys_set["$k"]=1
  done < "$tmp_new_keys"

  # Report each HEAD violation as ERROR (new) or EXISTING (pre-existing).
  # The key reconstruction "${rule}"$'\t'"${content}" is equivalent to
  # violation_keys' awk logic because collect_fail_violations produces exactly
  # 3 tab-separated fields; `content` captures the full third field (which
  # may itself contain tabs via the IFS=$'\t' read-r with 3 variables).
  local rule lineno content key
  while IFS=$'\t' read -r rule lineno content; do
    # Reconstruct the dedup key with the same multi-field-aware logic as violation_keys
    key="${rule}"$'\t'"${content}"
    local msg="${file}:${lineno}: [${rule}] $(rule_message "$rule")"
    if [[ -n "${new_keys_set[$key]+x}" ]]; then
      emit_error "$msg"
    else
      emit_existing "$msg"
    fi
  done < "$tmp_head"

  rm -f "$tmp_head" "$tmp_base" "$tmp_head_keys" "$tmp_base_keys" "$tmp_new_keys" "$base_src"

  # WARN violations: always reported regardless of baseline
  check_warn_violations "$file"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
BASELINE_REF=""
POSITIONAL=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --baseline)
      [[ "$#" -ge 2 ]] || { echo "lint-prompts: --baseline requires an argument" >&2; exit 1; }
      BASELINE_REF="$2"
      shift 2
      ;;
    --baseline=*)
      BASELINE_REF="${1#--baseline=}"
      shift
      ;;
    --)
      shift
      POSITIONAL+=("$@")
      break
      ;;
    -*)
      echo "lint-prompts: unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Collect files to lint
# ---------------------------------------------------------------------------
if [[ "${#POSITIONAL[@]}" -gt 0 ]]; then
  mapfile -t FILES < <(printf '%s\n' "${POSITIONAL[@]}")
else
  mapfile -t FILES < <(git ls-files 'prompts/**' || true)
fi

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "lint-prompts: no files to lint"
  exit 0
fi

# Rule L8 compares with the live yield value of maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h.
L8_LIVE="$(grep -A6 '^static void maybe_yield_nvs_scan_(' firmware/core/nvs-persistence.h 2>/dev/null \
  | grep -oE 'pdMS_TO_TICKS\([0-9]+\)' | head -n 1 | grep -oE '[0-9]+' || true)"
if [[ -z "$L8_LIVE" ]]; then
  echo "lint-prompts: rule L8 cannot read the live value of maybe_yield_nvs_scan_() in firmware/core/nvs-persistence.h" >&2
  exit 2
fi

printf 'lint-prompts: checking %d file(s)%s\n' \
  "${#FILES[@]}" \
  "${BASELINE_REF:+ (baseline: ${BASELINE_REF})}"

for f in "${FILES[@]}"; do
  if [[ -n "$BASELINE_REF" ]]; then
    check_file_baseline "$f" "$BASELINE_REF"
  else
    check_file_normal "$f"
  fi
done

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  if [[ "$WARN_COUNT" -gt 0 ]]; then
    printf '\nlint-prompts: FAIL — %d violation(s), %d warning(s) (see ERROR/WARN lines above)\n' \
      "$FAIL_COUNT" "$WARN_COUNT" >&2
  else
    printf '\nlint-prompts: FAIL — %d violation(s) found (see ERROR lines above)\n' "$FAIL_COUNT" >&2
  fi
  exit 1
fi

if [[ "$WARN_COUNT" -gt 0 ]]; then
  printf 'lint-prompts: OK with %d warning(s) — review WARN lines above\n' "$WARN_COUNT"
  exit 0
fi

printf 'lint-prompts: OK — 0 violations\n'
exit 0
