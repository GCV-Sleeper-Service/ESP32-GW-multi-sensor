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
    *)  echo "Unknown rule $1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Collect FAIL-class violations from a content source file.
# Outputs one TSV line per violation:  RULE_ID <TAB> LINENO <TAB> LINE_CONTENT
# $1 = path to file whose content to scan
# ---------------------------------------------------------------------------
collect_fail_violations() {
  local src="$1"
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

  # L7: §9 compound pattern (case-insensitive)
  # Rationale: Catches variants that L1 string match would miss (audit E-1).
  while IFS= read -r raw; do
    lineno="${raw%%:*}"; content="${raw#*:}"
    printf 'L7\t%s\t%s\n' "$lineno" "$content"
  done < <(grep -niE '§9.*Post.Merge.*Deliverables' "$src" 2>/dev/null || true)
}

# Build a sorted set of dedup keys "RULE_ID <TAB> LINE_CONTENT" from
# collect_fail_violations output, stripping the line-number column.
# Using content (not line number) as the key keeps violations stable across
# line position changes caused by unrelated edits elsewhere in the file.
# Handles content containing tabs by capturing all fields from the third onward.
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
  collect_fail_violations "$file" > "$violations"

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
  collect_fail_violations "$file" > "$tmp_head"
  violation_keys "$tmp_head" > "$tmp_head_keys"

  # Collect BASELINE violations (file content at the given ref, blobs only)
  if git cat-file -t "${baseline_ref}:${file}" 2>/dev/null | grep -q "^blob$" && \
     git show "${baseline_ref}:${file}" > "$base_src" 2>/dev/null; then
    collect_fail_violations "$base_src" > "$tmp_base"
  else
    # File did not exist (or was not a regular file) at baseline — every HEAD violation is new
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

  # Report each HEAD violation as ERROR (new) or EXISTING (pre-existing)
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
