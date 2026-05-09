#!/usr/bin/env bash
# scripts/lint-prompts.sh — Detect forbidden patterns in prompts/**
#
# Usage:
#   lint-prompts.sh [file ...]
#     With arguments: lints only those files (used by CI to lint PR-changed files)
#     Without arguments: lints all tracked files under prompts/**
#
# Exit 0 — clean or WARN only
# Exit 1 — at least one FAIL (ERROR) found
#
# Output format:
#   ERROR <file>:<line>: [LN] <description>   — violation that blocks the PR
#   WARN  <file>:<line>: [LN] <description>   — advisory, does not block

set -uo pipefail

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
  local f="$1"
  for ex in "${EXCLUDED_FILES[@]}"; do
    [[ "$f" == "$ex" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
FAIL_COUNT=0

emit_error() {
  echo "ERROR $1"
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
}

emit_warn() {
  echo "WARN  $1"
}

# ---------------------------------------------------------------------------
# Per-file lint checks
# ---------------------------------------------------------------------------
check_file() {
  local file="$1"

  is_excluded "$file" && return 0
  [[ -f "$file" ]] || return 0

  local lineno _rest

  # L1: "Post-Merge Deliverables" (case-sensitive exact string)
  # Rationale: §9 anatomy bug — allowed title is "Post-Merge Bookkeeping (tag and close only)".
  while IFS=: read -r lineno _rest; do
    emit_error "$file:$lineno: [L1] Forbidden title 'Post-Merge Deliverables' — use 'Post-Merge Bookkeeping (tag and close only)'"
  done < <(grep -n "Post-Merge Deliverables" "$file" 2>/dev/null || true)

  # L2: "(for Human)" or "for Human" in section headers (lines starting with #)
  # Rationale: "Device Testing (for Human)" anti-pattern (audit E-2 / Opus B1).
  while IFS=: read -r lineno _rest; do
    emit_error "$file:$lineno: [L2] Forbidden '(for Human)'/'for Human' in section header — remove the qualifier"
  done < <(grep -nE '^#.*(\(for Human\)|for[[:space:]]+Human)' "$file" 2>/dev/null || true)

  # L3: Cross-prompt version references (case-insensitive)
  # Rationale: "see v7.X.Y.Z prompt §" breaks self-containedness (§3.3).
  while IFS=: read -r lineno _rest; do
    emit_error "$file:$lineno: [L3] Cross-prompt version reference — breaks self-containedness (Docs/development-process-guide.md §3.3)"
  done < <(grep -niE 'see[[:space:]]+v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+prompt' "$file" 2>/dev/null || true)

  # L4: Stale WROOM IP 192.168.120.190
  # Rationale: Belt-and-braces; Board Info Extraction Gate should prevent this (audit E-3).
  while IFS=: read -r lineno _rest; do
    emit_error "$file:$lineno: [L4] Stale WROOM IP 192.168.120.190 — verify current IP via Board Info Extraction Gate"
  done < <(grep -n '192\.168\.120\.190' "$file" 2>/dev/null || true)

  # L5: Wrong WROOM YAML filename
  # Rationale: Correct filename is esp32-wroom-32d-gw.yaml (audit E-3).
  while IFS=: read -r lineno _rest; do
    emit_error "$file:$lineno: [L5] Wrong YAML filename 'esp32-wroom-32d-multi-sensor.yaml' — use 'esp32-wroom-32d-gw.yaml'"
  done < <(grep -n 'esp32-wroom-32d-multi-sensor\.yaml' "$file" 2>/dev/null || true)

  # L6: assemble-sensor-history.sh --check appearing before --write within 20 lines (WARN)
  # Rationale: Best-effort ordering check; correct pipeline order is --check then --write
  # is NOT the concern — the concern is invoking --check alone where --write is needed.
  # This WARN flags co-occurrence patterns for human review.
  while IFS= read -r warn_line; do
    [[ -n "$warn_line" ]] && emit_warn "$warn_line"
  done < <(awk '
    /assemble-sensor-history\.sh[[:space:]]+--check/ { check_line = NR }
    /assemble-sensor-history\.sh[[:space:]]+--write/ {
      if (check_line > 0 && NR - check_line <= 20) {
        printf "%s:%d: [L6] assemble-sensor-history.sh --check appears before --write within 20 lines — verify pipeline ordering\n", FILENAME, check_line
        check_line = 0
      }
    }
  ' "$file" 2>/dev/null || true)

  # L7: §9 + Post-Merge + Deliverables compound pattern (case-insensitive)
  # Rationale: Catches variants that L1 string match would miss (audit E-1).
  while IFS=: read -r lineno _rest; do
    emit_error "$file:$lineno: [L7] Forbidden §9 compound pattern — §9 must not reference 'Post-Merge Deliverables'"
  done < <(grep -niE '§9.*Post.Merge.*Deliverables' "$file" 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# Collect files to lint
# ---------------------------------------------------------------------------
if [[ "$#" -gt 0 ]]; then
  mapfile -t FILES < <(printf '%s\n' "$@")
else
  mapfile -t FILES < <(git ls-files 'prompts/**')
fi

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "lint-prompts: no files to lint"
  exit 0
fi

printf 'lint-prompts: checking %d file(s)\n' "${#FILES[@]}"

for f in "${FILES[@]}"; do
  check_file "$f"
done

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  printf '\nlint-prompts: FAIL — %d violation(s) found (see ERROR lines above)\n' "$FAIL_COUNT" >&2
  exit 1
fi

printf 'lint-prompts: OK — 0 violations\n'
exit 0
