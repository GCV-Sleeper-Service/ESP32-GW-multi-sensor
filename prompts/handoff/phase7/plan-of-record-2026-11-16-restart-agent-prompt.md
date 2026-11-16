# Plan of Record into the Repository — entry points, archive of Docs/, instruction files, decision rows (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions_
_Date: 2026-11-16_
_Prerequisite: `main` contains `160e90c` (PR #235, restart housekeeping); `VERSION` 7.7.1.1_
_Risk: LOW — documentation and agent-instruction files only; no firmware, dashboard, script, partition, workflow or generated-artifact change; no version bump_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Apply every edit of Task Groups 2 to 6 with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1). The only commands that change files are the `git mv` block of Task Group 1 and the `cp` block of Task Group 7; run both exactly as written.
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2).
- Every edit is verbatim and anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines included; the fence lines themselves are not part of it.
- Every check below is executable: run each block as written. A mismatch prints `⛔ CHECKPOINT FAILED` and exits non-zero; then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- A moved file is never opened in an editor. Each of the 43 moves is a `git mv` and nothing else, so that no line of a moved file is in the diff. Four of the moved files hold an old login; never quote a line of a moved file anywhere.
- This step edits files that agents load: `AGENTS.md`, `CLAUDE.md` and two files under `.github/`. Until the PR is merged you work under the versions on `main`, plus this prompt.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch and committed this prompt. Confirm you are on the branch:

```bash
cd /root/config/ESP32-GW-multi-sensor
test "$(git branch --show-current)" = "docs/plan-of-record-2026-11" || { echo "Wrong branch - STOP and report"; exit 1; }
```

Read completely, in this order:
0. `CURRENT-STATE.md` — every section; Task Group 3 edits four of them.
1. `Docs/development-process-guide.md` — §2.2 to §2.5, §3.2, §5.1 and §7.2.
2. `AGENTS.md` — every section; Task Group 4 edits five places.
3. `CLAUDE.md` — the first seven lines.
4. `Docs/decisions/decision-log.md` — the table format for Task Group 6.

Do not read the files that Task Group 1 moves.

## §2 — Pre-Implementation Verification Gate

Run this block BEFORE any move or edit. It stops at the first mismatch; then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2.

```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - §2: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
git merge-base --is-ancestor 160e90c HEAD || fail "160e90c (PR #235) is not an ancestor of HEAD"
test "$(grep -c '^_Updated: 2026-11-14_$' Docs/decisions/decision-log.md)" = "1" || fail "decision log _Updated_ line is not 2026-11-14"
test "$(grep -cE 'PLAN-0(2[2-9]|30) ' Docs/decisions/decision-log.md)" = "0" || fail "a row of this PR is already present"
test "$(grep -c '^| ' Docs/decisions/decision-log.md)" = "45" || fail "decision log table rows"
test "$(wc -l < AGENTS.md)" = "204" || fail "AGENTS.md is not 204 lines"
test "$(wc -l < CLAUDE.md)" = "69" || fail "CLAUDE.md is not 69 lines"
test "$(wc -l < .github/copilot-instructions.md)" = "49" || fail "copilot-instructions.md is not 49 lines"
test "$(grep -c '^@' CLAUDE.md AGENTS.md | grep -c ':0$')" = "2" || fail "an import line is already present"
test "$(git ls-files Docs | grep -vc '^Docs/.*/')" = "65" || fail "Docs/ top level is not 65 files"
test "$(git ls-files Docs/archive | wc -l)" = "61" || fail "Docs/archive is not 61 files"
for p in Docs/plan-of-record.md Docs/planner-start-here.md Docs/archive/README.md Docs/operator/R3c-plan-into-repository.md Docs/operator/R5-tooling.md Docs/archive/planning-2026-05 Docs/archive/methodology-audits-2026-05; do test ! -e "$p" || fail "$p already exists"; done
while read -r old new; do
  test -f "$old" || fail "move source $old is missing"
  test ! -e "$new" || fail "move target $new already exists"
done <<'EOF'
Docs/feature-roadmap.md Docs/archive/planning-2026-05/feature-roadmap.md
Docs/multi-phase-planning-session-summary.md Docs/archive/planning-2026-05/multi-phase-planning-session-summary.md
Docs/multi-phase-session-run-instructions.md Docs/archive/planning-2026-05/multi-phase-session-run-instructions.md
Docs/v7.7-implementation-plan.md Docs/archive/planning-2026-05/v7.7-implementation-plan.md
Docs/phase-V-implementation-plan.md Docs/archive/completed-phases/phase-V-implementation-plan.md
Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md Docs/archive/completed-phases/phase-V-implementation-plan-addendum-v7.6.9.4.md
Docs/phase-V-implementation-plan-prompt.md Docs/archive/completed-phases/phase-V-implementation-plan-prompt.md
Docs/phase-V-closure-analysis.md Docs/archive/completed-phases/phase-V-closure-analysis.md
Docs/phase-X-architecture-and-refactor-plan-dashboard.md Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md
Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md
Docs/phase-Y-current-state-inventory-sensor-history-v2.md Docs/archive/completed-phases/phase-Y-current-state-inventory-sensor-history-v2.md
Docs/phase-d-implementation-plan.md Docs/archive/completed-phases/phase-d-implementation-plan.md
Docs/v7.6.10.2-operator-procedure.md Docs/archive/completed-phases/v7.6.10.2-operator-procedure.md
Docs/prompt-producing-methodology-audit-Codex-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-Codex-2026-05-10.md
Docs/prompt-producing-methodology-audit-Perplexity-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-Perplexity-2026-05-10.md
Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md
Docs/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md
Docs/device-test-report-template.md Docs/archive/device-test-report-template.md
Docs/session-log-2026-04-10-v7.6.6.0.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.0.md
Docs/session-log-2026-04-10-v7.6.6.1.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.1.md
Docs/session-log-2026-04-10-v7.6.6.2.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.2.md
Docs/session-log-2026-04-10-v7.6.6.3.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.3.md
Docs/session-log-2026-04-10-v7.6.6.4.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.4.md
Docs/session-log-2026-04-10-v7.6.6.5.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.5.md
Docs/session-log-2026-04-11-v7.6.6.6.md Docs/archive/session-logs/session-log-2026-04-11-v7.6.6.6.md
Docs/session-log-2026-04-11-v7.6.6.7.md Docs/archive/session-logs/session-log-2026-04-11-v7.6.6.7.md
Docs/session-log-2026-04-12-v7.6.6.8.md Docs/archive/session-logs/session-log-2026-04-12-v7.6.6.8.md
Docs/session-log-2026-04-14-v7.6.7.0.md Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.0.md
Docs/session-log-2026-04-14-v7.6.7.1.md Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.1.md
Docs/session-log-2026-04-14-v7.6.7.2.md Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.2.md
Docs/session-log-2026-04-15-v7.6.8.0.md Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.0.md
Docs/session-log-2026-04-15-v7.6.8.1.md Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.1.md
Docs/session-log-2026-04-15-v7.6.8.2.md Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.2.md
Docs/session-log-2026-04-16-v7.6.9.0-hotfix.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.0-hotfix.md
Docs/session-log-2026-04-16-v7.6.9.0.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.0.md
Docs/session-log-2026-04-16-v7.6.9.1.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.1.md
Docs/session-log-2026-04-16-v7.6.9.2.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.2.md
Docs/session-log-2026-04-17-v7.6.9.3.md Docs/archive/session-logs/session-log-2026-04-17-v7.6.9.3.md
Docs/session-log-2026-04-17-v7.6.9.4.md Docs/archive/session-logs/session-log-2026-04-17-v7.6.9.4.md
Docs/session-log-2026-04-20-v7.6.9.5.md Docs/archive/session-logs/session-log-2026-04-20-v7.6.9.5.md
Docs/session-log-2026-04-24-v7.6.10.0-review-fix.md Docs/archive/session-logs/session-log-2026-04-24-v7.6.10.0-review-fix.md
Docs/session-log-2026-05-05-v7.6.10.1.md Docs/archive/session-logs/session-log-2026-05-05-v7.6.10.1.md
Docs/session-log-2026-05-06-v7.6.10.4.md Docs/archive/session-logs/session-log-2026-05-06-v7.6.10.4.md
EOF
test "$(grep -c 'update_interval: 60s' firmware/esp32-c3-multi-sensor.yaml)" = "3" || fail "template sensor rule: expected three 60s lambdas"
test "$(grep -c 'httpd_resp_send_chunk' firmware/core/web-handler.h)" = "4" || fail "BUG-082 fix: chunk calls"
test "$(grep -cF -- 'Docs/phase-X-architecture-and-refactor-plan-dashboard.md' README.md)" = "1" || fail "2.1a anchor"
test "$(grep -oF -- 'Docs/phase-d-implementation-plan.md' README.md | wc -l)" = "2" || fail "2.1b anchor"
test "$(grep -oF -- 'Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md' README.md | wc -l)" = "2" || fail "2.1c anchor"
test "$(grep -oF -- 'Docs/phase-X-architecture-and-refactor-plan-dashboard.md' Docs/architecture-overview.md | wc -l)" = "2" || fail "2.2a anchor"
test "$(grep -cF -- 'Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/architecture-overview.md)" = "1" || fail "2.2b anchor"
test "$(grep -cF -- 'Docs/phase-Y-current-state-inventory-sensor-history-v2.md' Docs/architecture-overview.md)" = "1" || fail "2.2c anchor"
test "$(grep -cF -- 'Docs/phase-d-implementation-plan.md' Docs/architecture-overview.md)" = "1" || fail "2.2d anchor"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/architecture-overview.md)" = "1" || fail "2.2e anchor"
test "$(grep -oF -- 'Docs/v7.7-implementation-plan.md' Docs/decisions/AGG-ADR-001-satellite-history-storage.md | wc -l)" = "2" || fail "2.3 anchor"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "2.4 anchor"
test "$(grep -cF -- 'Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md' Docs/decisions/decision-log.md)" = "1" || fail "2.5a anchor"
test "$(grep -cF -- 'Docs/session-log-2026-05-06-v7.6.10.4.md' Docs/decisions/decision-log.md)" = "1" || fail "2.5b anchor"
test "$(grep -oF -- 'Docs/v7.7-implementation-plan.md' Docs/phase-7-review-and-rewrite.md | wc -l)" = "2" || fail "2.6 anchor"
test "$(grep -oF -- '[Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md)' Docs/templates/prompt-audit-template.md | wc -l)" = "2" || fail "2.7 anchor"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/v7.7-v7.8-persistence-architecture.md)" = "1" || fail "2.8 anchor"
test "$(grep -cF -- 'Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md)" = "1" || fail "2.9 anchor"
test "$(grep -cF -- '_Next action: ' CURRENT-STATE.md)" = "1" || fail "3.1 anchor"
test "$(grep -cxF -- '1. **Phase 7 Step v7.7.1.2** — Per-device structs, key scheme, hash function.' CURRENT-STATE.md)" = "1" || fail "3.2a anchor"
test "$(grep -cxF -- '1. **Phase 7 Step v7.7.1.2** — Per-device structs, key scheme, hash function.' CURRENT-STATE.md)" = "1" || fail "3.2b anchor"
test "$(grep -cxF -- '2. **Phase 7 Step v7.7.1.3** — Per-device persist engine (write path).' CURRENT-STATE.md)" = "1" || fail "3.2c anchor"
test "$(grep -cxF -- '3. **Phase 7 Step v7.7.1.4** — Per-device restore engine (boot path) + retention budget.' CURRENT-STATE.md)" = "1" || fail "3.2d anchor"
test "$(grep -cxF -- '4. **Phase 7 Steps v7.7.2.1–v7.7.3.3** — Engine switchover, migration, export/import, and closure.' CURRENT-STATE.md)" = "1" || fail "3.2e anchor"
test "$(grep -cxF -- '5. **Phase 7 optimization sprint v7.7.5.x** — NVS dedup study, RAM window reduction.' CURRENT-STATE.md)" = "1" || fail "3.2f anchor"
test "$(grep -cF -- '| `Docs/v7.7-implementation-plan.md` |' CURRENT-STATE.md)" = "1" || fail "3.3a anchor"
test "$(grep -cF -- '| `Docs/feature-roadmap.md` |' CURRENT-STATE.md)" = "1" || fail "3.3b anchor"
test "$(grep -cxF -- '## Architecture Quick Reference' CURRENT-STATE.md)" = "1" || fail "3.3c anchor"
test "$(grep -cxF -- '## Planning Documents (2026-05-07 Multi-Phase Session)' CURRENT-STATE.md)" = "1" || fail "3.4a anchor"
test "$(grep -cxF -- '| `Docs/phase-7-review-and-rewrite.md` | Rewritten Phase 7 plan (supersedes v7.7-implementation-plan.md) |' CURRENT-STATE.md)" = "1" || fail "3.4b anchor"
test "$(grep -cF -- '| `Docs/multi-phase-planning-session-summary.md` |' CURRENT-STATE.md)" = "1" || fail "3.4c anchor"
test "$(grep -cxF -- '_Instructions for AI coding agents working on this repository._' AGENTS.md)" = "1" || fail "4.1a anchor"
test "$(grep -cxF -- '## Device Testing' AGENTS.md)" = "1" || fail "4.1b anchor"
test "$(grep -cxF -- 'esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' AGENTS.md)" = "1" || fail "4.1c anchor"
test "$(grep -cxF -- '- **Blocking:** Generated file edited, NVS on httpd stack, missing external_components, data corruption risk' AGENTS.md)" = "1" || fail "4.1d anchor"
test "$(grep -cxF -- '## PR Title and Body — Preservation Rules (binding for all coding and review agents)' AGENTS.md)" = "1" || fail "4.1e anchor"
test "$(grep -cxF -- '## 0. This project (ESP32-GW-multi-sensor)' CLAUDE.md)" = "1" || fail "4.2a anchor"
test "$(grep -cF -- 'Claude sessions in this repository act as architect/planner or prompt producer' CLAUDE.md)" = "1" || fail "4.2b anchor"
test "$(grep -cxF -- '## Architecture — Generated Files' .github/copilot-instructions.md)" = "1" || fail "4.3 anchor"
test "$(grep -cxF -- '- All string building from NVS loops must enforce explicit size limits (csv.reserve does NOT truncate)' .github/instructions/firmware.instructions.md)" = "1" || fail "4.4 anchor"
test "$(grep -cxF -- '10) Run one test command at a time: no second preflight, Playwright run or mock server while one is running' Docs/development-process-guide.md)" = "1" || fail "5.1a anchor"
test "$(grep -cxF -- '**B) The agent prompt** — copy the agent section from the Claude two-step prompt.' Docs/development-process-guide.md)" = "1" || fail "5.1b anchor"
test "$(grep -cxF -- 'esphome upload  firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' Docs/development-process-guide.md)" = "1" || fail "5.2 anchor"
test "$(grep -cxF -- 'After inline reviews complete, agent addresses findings:' Docs/development-process-guide.md)" = "1" || fail "5.3a anchor"
test "$(grep -cF -- 'External review B runs the structured three-turn review protocol as the final quality gate.' Docs/development-process-guide.md)" = "1" || fail "5.3b anchor"
test "$(grep -cxF -- '2. **`CURRENT-STATE.md` update** — bump "Last verified" date, append to "What Just Shipped," update "What'"'"'s Next," add/remove "Open Issues" and "Unimplemented Recommendations."' Docs/development-process-guide.md)" = "1" || fail "5.4 anchor"
test "$(grep -cxF -- '| 2 — Decision Index | `Docs/decisions/decision-log.md` | ~3K | Planning sessions |' Docs/development-process-guide.md)" = "1" || fail "5.5 anchor"
test "$(grep -cxF -- '- `.github/copilot-instructions.md` — top 10 review rules, consumed by Copilot inline review (4,000 char limit)' Docs/development-process-guide.md)" = "1" || fail "5.6 anchor"
test "$(grep -cxF -- '- `.github/instructions/*.instructions.md` — path-specific rules for firmware, dashboard, and Playwright files' Docs/development-process-guide.md)" = "1" || fail "5.6 anchor"
test "$(grep -cxF -- '- `AGENTS.md` — comprehensive agent instructions, consumed by multiple AI agents (Copilot, Claude, Gemini)' Docs/development-process-guide.md)" = "1" || fail "5.6 anchor"
test "$(grep -cxF -- '- **Post-execution review (3-turn):** Perplexity — GitHub MCP access, structured review protocol' Docs/writing-guide/methodology.md)" = "1" || fail "5.7 anchor"
test "$(grep -cxF -- '_Updated: 2026-11-14_' Docs/decisions/decision-log.md)" = "1" || fail "6.1 anchor"
test "$(grep -cF -- '| 2026-11-14 | SEC-003 |' Docs/decisions/decision-log.md)" = "1" || fail "6.2 anchor"
echo "§2 PASS"
)
```

## §3 — Scope Boundary

Files you MAY modify (complete list; nothing else):
- `AGENTS.md` (items 4.1a to 4.1e only)
- `CLAUDE.md` (items 4.2a and 4.2b only)
- `.github/copilot-instructions.md` (item 4.3 only)
- `.github/instructions/firmware.instructions.md` (item 4.4 only: one line)
- `Docs/development-process-guide.md` (items 5.1 to 5.6 only)
- `Docs/writing-guide/methodology.md` (item 5.7 only: one line)
- `Docs/decisions/decision-log.md` (items 2.5, 6.1 and 6.2 only)
- `CURRENT-STATE.md` (Task Group 3 only)
- `README.md` (item 2.1 only: three lines)
- `Docs/architecture-overview.md` (item 2.2 only: six lines)
- `Docs/decisions/AGG-ADR-001-satellite-history-storage.md` (item 2.3 only: two lines)
- `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (item 2.4 only: one line)
- `Docs/phase-7-review-and-rewrite.md` (item 2.6 only: two lines)
- `Docs/templates/prompt-audit-template.md` (item 2.7 only: two lines)
- `Docs/v7.7-v7.8-persistence-architecture.md` (item 2.8 only: one line)
- `Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md` (item 2.9 only: one line)
- MOVED, with `git mv` and no edit: the 43 files of the moves list below, each from its old path under `Docs/` to its new path under `Docs/archive/`
- NEW: `Docs/plan-of-record.md`, `Docs/planner-start-here.md`, `Docs/archive/README.md`, `Docs/operator/R3c-plan-into-repository.md`, `Docs/operator/R5-tooling.md` (Task Group 7: supplied files, copied byte for byte)
- NEW: `prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md`
- NEW: `prompts/handoff/phase7/plan-of-record-2026-11-16-restart-agent-prompt.md` (this prompt, verbatim; the setup block has committed it)

That is 109 paths when a move counts as two: 16 changed files, the 43 old and the 43 new paths of the moves, and 7 new files. Write them, one bare path per line, to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`, so it is never part of the change. The PRE-PR gate checks every changed path against it.

```bash
cat > "$(git rev-parse --git-path scope-allowed.txt)" <<'EOF'
AGENTS.md
CLAUDE.md
.github/copilot-instructions.md
.github/instructions/firmware.instructions.md
Docs/development-process-guide.md
Docs/decisions/decision-log.md
CURRENT-STATE.md
README.md
Docs/architecture-overview.md
Docs/decisions/AGG-ADR-001-satellite-history-storage.md
Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md
Docs/phase-7-review-and-rewrite.md
Docs/templates/prompt-audit-template.md
Docs/v7.7-v7.8-persistence-architecture.md
Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md
Docs/writing-guide/methodology.md
Docs/feature-roadmap.md
Docs/multi-phase-planning-session-summary.md
Docs/multi-phase-session-run-instructions.md
Docs/v7.7-implementation-plan.md
Docs/phase-V-implementation-plan.md
Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md
Docs/phase-V-implementation-plan-prompt.md
Docs/phase-V-closure-analysis.md
Docs/phase-X-architecture-and-refactor-plan-dashboard.md
Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md
Docs/phase-Y-current-state-inventory-sensor-history-v2.md
Docs/phase-d-implementation-plan.md
Docs/v7.6.10.2-operator-procedure.md
Docs/prompt-producing-methodology-audit-Codex-2026-05-10.md
Docs/prompt-producing-methodology-audit-Perplexity-2026-05-10.md
Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md
Docs/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md
Docs/device-test-report-template.md
Docs/session-log-2026-04-10-v7.6.6.0.md
Docs/session-log-2026-04-10-v7.6.6.1.md
Docs/session-log-2026-04-10-v7.6.6.2.md
Docs/session-log-2026-04-10-v7.6.6.3.md
Docs/session-log-2026-04-10-v7.6.6.4.md
Docs/session-log-2026-04-10-v7.6.6.5.md
Docs/session-log-2026-04-11-v7.6.6.6.md
Docs/session-log-2026-04-11-v7.6.6.7.md
Docs/session-log-2026-04-12-v7.6.6.8.md
Docs/session-log-2026-04-14-v7.6.7.0.md
Docs/session-log-2026-04-14-v7.6.7.1.md
Docs/session-log-2026-04-14-v7.6.7.2.md
Docs/session-log-2026-04-15-v7.6.8.0.md
Docs/session-log-2026-04-15-v7.6.8.1.md
Docs/session-log-2026-04-15-v7.6.8.2.md
Docs/session-log-2026-04-16-v7.6.9.0-hotfix.md
Docs/session-log-2026-04-16-v7.6.9.0.md
Docs/session-log-2026-04-16-v7.6.9.1.md
Docs/session-log-2026-04-16-v7.6.9.2.md
Docs/session-log-2026-04-17-v7.6.9.3.md
Docs/session-log-2026-04-17-v7.6.9.4.md
Docs/session-log-2026-04-20-v7.6.9.5.md
Docs/session-log-2026-04-24-v7.6.10.0-review-fix.md
Docs/session-log-2026-05-05-v7.6.10.1.md
Docs/session-log-2026-05-06-v7.6.10.4.md
Docs/archive/planning-2026-05/feature-roadmap.md
Docs/archive/planning-2026-05/multi-phase-planning-session-summary.md
Docs/archive/planning-2026-05/multi-phase-session-run-instructions.md
Docs/archive/planning-2026-05/v7.7-implementation-plan.md
Docs/archive/completed-phases/phase-V-implementation-plan.md
Docs/archive/completed-phases/phase-V-implementation-plan-addendum-v7.6.9.4.md
Docs/archive/completed-phases/phase-V-implementation-plan-prompt.md
Docs/archive/completed-phases/phase-V-closure-analysis.md
Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md
Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md
Docs/archive/completed-phases/phase-Y-current-state-inventory-sensor-history-v2.md
Docs/archive/completed-phases/phase-d-implementation-plan.md
Docs/archive/completed-phases/v7.6.10.2-operator-procedure.md
Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-Codex-2026-05-10.md
Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-Perplexity-2026-05-10.md
Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md
Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md
Docs/archive/device-test-report-template.md
Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.0.md
Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.1.md
Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.2.md
Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.3.md
Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.4.md
Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.5.md
Docs/archive/session-logs/session-log-2026-04-11-v7.6.6.6.md
Docs/archive/session-logs/session-log-2026-04-11-v7.6.6.7.md
Docs/archive/session-logs/session-log-2026-04-12-v7.6.6.8.md
Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.0.md
Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.1.md
Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.2.md
Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.0.md
Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.1.md
Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.2.md
Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.0-hotfix.md
Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.0.md
Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.1.md
Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.2.md
Docs/archive/session-logs/session-log-2026-04-17-v7.6.9.3.md
Docs/archive/session-logs/session-log-2026-04-17-v7.6.9.4.md
Docs/archive/session-logs/session-log-2026-04-20-v7.6.9.5.md
Docs/archive/session-logs/session-log-2026-04-24-v7.6.10.0-review-fix.md
Docs/archive/session-logs/session-log-2026-05-05-v7.6.10.1.md
Docs/archive/session-logs/session-log-2026-05-06-v7.6.10.4.md
Docs/plan-of-record.md
Docs/planner-start-here.md
Docs/archive/README.md
Docs/operator/R3c-plan-into-repository.md
Docs/operator/R5-tooling.md
prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md
prompts/handoff/phase7/plan-of-record-2026-11-16-restart-agent-prompt.md
EOF
```

Write the list of the 43 moves, one line per move with the old path and the new path, to the file that `git rev-parse --git-path r3c-moves.txt` names. Task Group 1 and the checks read it.

```bash
cat > "$(git rev-parse --git-path r3c-moves.txt)" <<'EOF'
Docs/feature-roadmap.md Docs/archive/planning-2026-05/feature-roadmap.md
Docs/multi-phase-planning-session-summary.md Docs/archive/planning-2026-05/multi-phase-planning-session-summary.md
Docs/multi-phase-session-run-instructions.md Docs/archive/planning-2026-05/multi-phase-session-run-instructions.md
Docs/v7.7-implementation-plan.md Docs/archive/planning-2026-05/v7.7-implementation-plan.md
Docs/phase-V-implementation-plan.md Docs/archive/completed-phases/phase-V-implementation-plan.md
Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md Docs/archive/completed-phases/phase-V-implementation-plan-addendum-v7.6.9.4.md
Docs/phase-V-implementation-plan-prompt.md Docs/archive/completed-phases/phase-V-implementation-plan-prompt.md
Docs/phase-V-closure-analysis.md Docs/archive/completed-phases/phase-V-closure-analysis.md
Docs/phase-X-architecture-and-refactor-plan-dashboard.md Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md
Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md
Docs/phase-Y-current-state-inventory-sensor-history-v2.md Docs/archive/completed-phases/phase-Y-current-state-inventory-sensor-history-v2.md
Docs/phase-d-implementation-plan.md Docs/archive/completed-phases/phase-d-implementation-plan.md
Docs/v7.6.10.2-operator-procedure.md Docs/archive/completed-phases/v7.6.10.2-operator-procedure.md
Docs/prompt-producing-methodology-audit-Codex-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-Codex-2026-05-10.md
Docs/prompt-producing-methodology-audit-Perplexity-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-Perplexity-2026-05-10.md
Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md
Docs/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-gpt-5-5-thinking-2026-05-10.md
Docs/device-test-report-template.md Docs/archive/device-test-report-template.md
Docs/session-log-2026-04-10-v7.6.6.0.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.0.md
Docs/session-log-2026-04-10-v7.6.6.1.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.1.md
Docs/session-log-2026-04-10-v7.6.6.2.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.2.md
Docs/session-log-2026-04-10-v7.6.6.3.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.3.md
Docs/session-log-2026-04-10-v7.6.6.4.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.4.md
Docs/session-log-2026-04-10-v7.6.6.5.md Docs/archive/session-logs/session-log-2026-04-10-v7.6.6.5.md
Docs/session-log-2026-04-11-v7.6.6.6.md Docs/archive/session-logs/session-log-2026-04-11-v7.6.6.6.md
Docs/session-log-2026-04-11-v7.6.6.7.md Docs/archive/session-logs/session-log-2026-04-11-v7.6.6.7.md
Docs/session-log-2026-04-12-v7.6.6.8.md Docs/archive/session-logs/session-log-2026-04-12-v7.6.6.8.md
Docs/session-log-2026-04-14-v7.6.7.0.md Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.0.md
Docs/session-log-2026-04-14-v7.6.7.1.md Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.1.md
Docs/session-log-2026-04-14-v7.6.7.2.md Docs/archive/session-logs/session-log-2026-04-14-v7.6.7.2.md
Docs/session-log-2026-04-15-v7.6.8.0.md Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.0.md
Docs/session-log-2026-04-15-v7.6.8.1.md Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.1.md
Docs/session-log-2026-04-15-v7.6.8.2.md Docs/archive/session-logs/session-log-2026-04-15-v7.6.8.2.md
Docs/session-log-2026-04-16-v7.6.9.0-hotfix.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.0-hotfix.md
Docs/session-log-2026-04-16-v7.6.9.0.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.0.md
Docs/session-log-2026-04-16-v7.6.9.1.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.1.md
Docs/session-log-2026-04-16-v7.6.9.2.md Docs/archive/session-logs/session-log-2026-04-16-v7.6.9.2.md
Docs/session-log-2026-04-17-v7.6.9.3.md Docs/archive/session-logs/session-log-2026-04-17-v7.6.9.3.md
Docs/session-log-2026-04-17-v7.6.9.4.md Docs/archive/session-logs/session-log-2026-04-17-v7.6.9.4.md
Docs/session-log-2026-04-20-v7.6.9.5.md Docs/archive/session-logs/session-log-2026-04-20-v7.6.9.5.md
Docs/session-log-2026-04-24-v7.6.10.0-review-fix.md Docs/archive/session-logs/session-log-2026-04-24-v7.6.10.0-review-fix.md
Docs/session-log-2026-05-05-v7.6.10.1.md Docs/archive/session-logs/session-log-2026-05-05-v7.6.10.1.md
Docs/session-log-2026-05-06-v7.6.10.4.md Docs/archive/session-logs/session-log-2026-05-06-v7.6.10.4.md
EOF
```

Files you MUST NOT modify: anything under `firmware/`, `dashboard/`, `scripts/`, `src/`, `tests/`, `partitions/`, `config/`, `.github/workflows/`; the other four files under `.github/instructions/`; `VERSION`; `Docs/changelog.md`; every other file under `prompts/` and `Docs/`; every file that is in `Docs/archive/` today.

You MUST NOT: run `bash scripts/bump-version.sh` or any `--write` command; create, close or edit issues or milestones (the operator does that after the merge, §9); delete a file; change a line of a moved file; merge.

## §4 — Critical Rules Checklist

- Rule 2 — canonical repo tooling only; `lint-prompts.sh` reports, it never rewrites.
- Rule 4 — no generated file is touched.
- Rules 62/63 — checkpoints are queries with expected values; on mismatch STOP, do not fix.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit.
- Do NOT open a moved file in an editor, and do NOT "fix" a link inside a moved file: `Docs/archive/`, `Docs/changelog.md` and `prompts/` keep the old paths as history (PLAN-025).
- Do NOT change the reviewer table of `Docs/development-process-guide.md` §2.4: it describes the reviews as they are today (PLAN-019). The scheme with reviews A, B and C takes effect when the review-runner PR is merged; this PR only records it as decision rows.
- Do NOT put a credential in any command, file or PR text.
- Do NOT bump the version or add a changelog entry.

## §6 — Implementation Steps

### Task Group 1 — Archive moves (PLAN-025)

**1.1** Run this block exactly as written. It makes two new folders and moves the 43 files of the list of §3: 18 documents and 25 session logs. It edits nothing. It must end with `moved 43 files`.

```bash
(
fail() { echo "MOVE FAILED: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
M="$(git rev-parse --git-path r3c-moves.txt)"
test -s "$M" || fail "r3c-moves.txt missing (see §3)"
mkdir -p Docs/archive/planning-2026-05 Docs/archive/methodology-audits-2026-05 || fail "mkdir"
while read -r old new; do git mv "$old" "$new" || fail "$old"; done < "$M"
echo "moved $(wc -l < "$M") files"
)
```

⛔ **CHECKPOINT A** — every move is a pure rename: the new file is byte-identical to the old one on `main`, and git shows 43 renames at 100 %.
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - A: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
M="$(git rev-parse --git-path r3c-moves.txt)"
test -s "$M" || fail "r3c-moves.txt missing (see §3)"
BASE="$(git merge-base origin/main HEAD)" || fail "merge-base"
n=0
while read -r old new; do
  test ! -e "$old" || fail "1.1 $old still exists"
  test -f "$new" || fail "1.1 $new is missing"
  test "$(git rev-parse "$BASE:$old")" = "$(git hash-object "$new")" || fail "1.1 $new is not identical to $old: a move must change no line"
  n=$((n+1))
done < "$M"
test "$n" = "43" || fail "1.1 expected 43 moves"
test "$(git diff --cached -M100% --name-status "$BASE" | grep -c '^R100')" = "43" || fail "1.2 git does not show 43 pure renames"
test "$(git diff --cached -M100% --name-status "$BASE" | grep -c '^R')" = "43" || fail "1.2 a rename with changed lines"
test "$(git diff --cached -M100% --name-status "$BASE" | grep -c '^D')" = "0" || fail "1.2 a file was deleted"
test "$(git ls-files Docs | grep -v -e '^Docs/.*/' -e '^Docs/plan-of-record.md$' -e '^Docs/planner-start-here.md$' | wc -l)" = "22" || fail "1.3 expected 22 old files at the top level of Docs/"
echo "CHECKPOINT A PASS"
)
```

### Task Group 2 — Moved paths in live files

Live files that name a moved file get the new path. The old path must not stay anywhere in these files. Items 2.1 to 2.9 cover 20 lines in 9 files; the four lines of `CURRENT-STATE.md` are in Task Group 3.

**2.1a** `README.md`: this text occurs once; replace
```
Docs/phase-X-architecture-and-refactor-plan-dashboard.md
```
with
```
Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md
```

**2.1b** `README.md`: this text occurs 2 times; replace every occurrence of
```
Docs/phase-d-implementation-plan.md
```
with
```
Docs/archive/completed-phases/phase-d-implementation-plan.md
```

**2.1c** `README.md`: this text occurs 2 times; replace every occurrence of
```
Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md
```
with
```
Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md
```

**2.2a** `Docs/architecture-overview.md`: this text occurs 2 times; replace every occurrence of
```
Docs/phase-X-architecture-and-refactor-plan-dashboard.md
```
with
```
Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md
```

**2.2b** `Docs/architecture-overview.md`: this text occurs once; replace
```
Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md
```
with
```
Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md
```

**2.2c** `Docs/architecture-overview.md`: this text occurs once; replace
```
Docs/phase-Y-current-state-inventory-sensor-history-v2.md
```
with
```
Docs/archive/completed-phases/phase-Y-current-state-inventory-sensor-history-v2.md
```

**2.2d** `Docs/architecture-overview.md`: this text occurs once; replace
```
Docs/phase-d-implementation-plan.md
```
with
```
Docs/archive/completed-phases/phase-d-implementation-plan.md
```

**2.2e** `Docs/architecture-overview.md`: this text occurs once; replace
```
Docs/v7.7-implementation-plan.md
```
with
```
Docs/archive/planning-2026-05/v7.7-implementation-plan.md
```

**2.3** `Docs/decisions/AGG-ADR-001-satellite-history-storage.md`: this text occurs 2 times; replace every occurrence of
```
Docs/v7.7-implementation-plan.md
```
with
```
Docs/archive/planning-2026-05/v7.7-implementation-plan.md
```

**2.4** `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`: this text occurs once; replace
```
Docs/v7.7-implementation-plan.md
```
with
```
Docs/archive/planning-2026-05/v7.7-implementation-plan.md
```

**2.5a** `Docs/decisions/decision-log.md`: this text occurs once; replace
```
Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md
```
with
```
Docs/archive/completed-phases/phase-V-implementation-plan-addendum-v7.6.9.4.md
```

**2.5b** `Docs/decisions/decision-log.md`: this text occurs once; replace
```
Docs/session-log-2026-05-06-v7.6.10.4.md
```
with
```
Docs/archive/session-logs/session-log-2026-05-06-v7.6.10.4.md
```

**2.6** `Docs/phase-7-review-and-rewrite.md`: this text occurs 2 times; replace every occurrence of
```
Docs/v7.7-implementation-plan.md
```
with
```
Docs/archive/planning-2026-05/v7.7-implementation-plan.md
```

**2.7** `Docs/templates/prompt-audit-template.md`: this text occurs 2 times; replace every occurrence of
```
[Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md)
```
with
```
[Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md)
```

**2.8** `Docs/v7.7-v7.8-persistence-architecture.md`: this text occurs once; replace
```
Docs/v7.7-implementation-plan.md
```
with
```
Docs/archive/planning-2026-05/v7.7-implementation-plan.md
```

**2.9** `Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md`: this text occurs once; replace
```
Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md
```
with
```
Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md
```

⛔ **CHECKPOINT B**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - B: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- 'Docs/phase-X-architecture-and-refactor-plan-dashboard.md' README.md)" = "0" || fail "2.1a old text still present"
test "$(grep -cF -- 'Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md' README.md)" = "1" || fail "2.1a"
test "$(grep -cF -- 'Docs/phase-d-implementation-plan.md' README.md)" = "0" || fail "2.1b old text still present"
test "$(grep -oF -- 'Docs/archive/completed-phases/phase-d-implementation-plan.md' README.md | wc -l)" = "2" || fail "2.1b"
test "$(grep -cF -- 'Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md' README.md)" = "0" || fail "2.1c old text still present"
test "$(grep -oF -- 'Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md' README.md | wc -l)" = "2" || fail "2.1c"
test "$(grep -cF -- 'Docs/phase-X-architecture-and-refactor-plan-dashboard.md' Docs/architecture-overview.md)" = "0" || fail "2.2a old text still present"
test "$(grep -oF -- 'Docs/archive/completed-phases/phase-X-architecture-and-refactor-plan-dashboard.md' Docs/architecture-overview.md | wc -l)" = "2" || fail "2.2a"
test "$(grep -cF -- 'Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/architecture-overview.md)" = "0" || fail "2.2b old text still present"
test "$(grep -cF -- 'Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/architecture-overview.md)" = "1" || fail "2.2b"
test "$(grep -cF -- 'Docs/phase-Y-current-state-inventory-sensor-history-v2.md' Docs/architecture-overview.md)" = "0" || fail "2.2c old text still present"
test "$(grep -cF -- 'Docs/archive/completed-phases/phase-Y-current-state-inventory-sensor-history-v2.md' Docs/architecture-overview.md)" = "1" || fail "2.2c"
test "$(grep -cF -- 'Docs/phase-d-implementation-plan.md' Docs/architecture-overview.md)" = "0" || fail "2.2d old text still present"
test "$(grep -cF -- 'Docs/archive/completed-phases/phase-d-implementation-plan.md' Docs/architecture-overview.md)" = "1" || fail "2.2d"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/architecture-overview.md)" = "0" || fail "2.2e old text still present"
test "$(grep -cF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/architecture-overview.md)" = "1" || fail "2.2e"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/decisions/AGG-ADR-001-satellite-history-storage.md)" = "0" || fail "2.3 old text still present"
test "$(grep -oF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/decisions/AGG-ADR-001-satellite-history-storage.md | wc -l)" = "2" || fail "2.3"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "0" || fail "2.4 old text still present"
test "$(grep -cF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "2.4"
test "$(grep -cF -- 'Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md' Docs/decisions/decision-log.md)" = "0" || fail "2.5a old text still present"
test "$(grep -cF -- 'Docs/archive/completed-phases/phase-V-implementation-plan-addendum-v7.6.9.4.md' Docs/decisions/decision-log.md)" = "1" || fail "2.5a"
test "$(grep -cF -- 'Docs/session-log-2026-05-06-v7.6.10.4.md' Docs/decisions/decision-log.md)" = "0" || fail "2.5b old text still present"
test "$(grep -cF -- 'Docs/archive/session-logs/session-log-2026-05-06-v7.6.10.4.md' Docs/decisions/decision-log.md)" = "1" || fail "2.5b"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/phase-7-review-and-rewrite.md)" = "0" || fail "2.6 old text still present"
test "$(grep -oF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/phase-7-review-and-rewrite.md | wc -l)" = "2" || fail "2.6"
test "$(grep -cF -- '[Docs/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md)' Docs/templates/prompt-audit-template.md)" = "0" || fail "2.7 old text still present"
test "$(grep -oF -- '[Docs/archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md](../archive/methodology-audits-2026-05/prompt-producing-methodology-audit-claude-opus-4.7-2026-05-10.md)' Docs/templates/prompt-audit-template.md | wc -l)" = "2" || fail "2.7"
test "$(grep -cF -- 'Docs/v7.7-implementation-plan.md' Docs/v7.7-v7.8-persistence-architecture.md)" = "0" || fail "2.8 old text still present"
test "$(grep -cF -- 'Docs/archive/planning-2026-05/v7.7-implementation-plan.md' Docs/v7.7-v7.8-persistence-architecture.md)" = "1" || fail "2.8"
test "$(grep -cF -- 'Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md)" = "0" || fail "2.9 old text still present"
test "$(grep -cF -- 'Docs/archive/completed-phases/phase-Y-architecture-and-refactor-plan-sensor-history.md' Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md)" = "1" || fail "2.9"
M="$(git rev-parse --git-path r3c-moves.txt)"
test -s "$M" || fail "r3c-moves.txt missing (see §3)"
while read -r old new; do
  b="${old#Docs/}"; a="${new#Docs/}"
  bad="$(git grep -n -F -e "$b" -- . ':!prompts' ':!Docs/archive' ':!Docs/changelog.md' | grep -v -F -e "$a")"
  test -z "$(printf '%s\n' "$bad" | grep -v '^CURRENT-STATE.md:' | grep .)" || fail "a live file still names $b by its old path: $bad"
done < "$M"
echo "CHECKPOINT B PASS"
)
```

### Task Group 3 — `CURRENT-STATE.md`

Two status marks change in this file: the `_Next action:` line and the list under `## What's Next`. CHECKPOINT C searches the whole file for the old wording of both.

**3.1** `CURRENT-STATE.md`: exactly one line begins with `_Next action: `. Replace that whole line with
```
_Next action: R5, the tooling PR (PLAN-017, PLAN-020, PLAN-028). The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5, R5r, R5a and R5b._
```

**3.2a** `CURRENT-STATE.md`: immediately before the line
```
1. **Phase 7 Step v7.7.1.2** — Per-device structs, key scheme, hash function.
```
insert this text, then one blank line
```
The order, the scope and the status of every step are in `Docs/plan-of-record.md` (PLAN-024). In short:
```

**3.2b** `CURRENT-STATE.md`: replace the line
```
1. **Phase 7 Step v7.7.1.2** — Per-device structs, key scheme, hash function.
```
with
```
1. **R5, R5r, R5a, R5b** — the tooling PR, the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.
```

**3.2c** `CURRENT-STATE.md`: replace the line
```
2. **Phase 7 Step v7.7.1.3** — Per-device persist engine (write path).
```
with
```
2. **Phase 7 Steps v7.7.1.2 to v7.7.1.4** — per-device structs and key scheme; persist engine (write path); restore engine (boot path) and retention budget.
```

**3.2d** `CURRENT-STATE.md`: replace the line
```
3. **Phase 7 Step v7.7.1.4** — Per-device restore engine (boot path) + retention budget.
```
with
```
3. **v7.7.1.5** — new board secrets (SEC-003).
```

**3.2e** `CURRENT-STATE.md`: replace the line
```
4. **Phase 7 Steps v7.7.2.1–v7.7.3.3** — Engine switchover, migration, export/import, and closure.
```
with
```
4. **Phase 7 Steps v7.7.2.1 to v7.7.3.3** — engine switchover, migration, export and import, and closure. v7.7.3.3 is v1.0 (PLAN-015).
```

**3.2f** `CURRENT-STATE.md`: replace the line
```
5. **Phase 7 optimization sprint v7.7.5.x** — NVS dedup study, RAM window reduction.
```
with
```
5. **After v1.0** — the ESPHome upgrade spike; v1.1 with the partition layouts and the former optimisation sprint; then Phases 8 and 9.
```

**3.3a** `CURRENT-STATE.md`: exactly one line begins with
```
| `Docs/v7.7-implementation-plan.md` |
```
Delete that whole line.

**3.3b** `CURRENT-STATE.md`: exactly one line begins with
```
| `Docs/feature-roadmap.md` |
```
Delete that whole line.

**3.3c** `CURRENT-STATE.md`: immediately before the line
```
## Architecture Quick Reference
```
insert this text, then one blank line
```
_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 (PLAN-025)._
```

**3.4a** `CURRENT-STATE.md`: replace the line
```
## Planning Documents (2026-05-07 Multi-Phase Session)
```
with
```
## Planning Documents
```

**3.4b** `CURRENT-STATE.md`: replace the line
```
| `Docs/phase-7-review-and-rewrite.md` | Rewritten Phase 7 plan (supersedes v7.7-implementation-plan.md) |
```
with
```
| `Docs/plan-of-record.md` | Plan of record: the ladder of steps to v1.0, the scope and done-when of each step, open findings and risks (PLAN-024) |
| `Docs/planner-start-here.md` | Entry page for planning and prompt-producing sessions (PLAN-030) |
| `Docs/phase-7-review-and-rewrite.md` | Rewritten Phase 7 plan (supersedes `Docs/archive/planning-2026-05/v7.7-implementation-plan.md`) |
```

**3.4c** `CURRENT-STATE.md`: exactly one line begins with
```
| `Docs/multi-phase-planning-session-summary.md` |
```
Delete that whole line.

⛔ **CHECKPOINT C**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - C: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '_Next action: R5, the tooling PR' CURRENT-STATE.md)" = "1" || fail "3.1"
test "$(grep -cF -- 'The order, the scope and the status of every step are in `Docs/plan-of-record.md` (PLAN-024). In short:' CURRENT-STATE.md)" = "1" || fail "3.2a"
test "$(grep -cF -- '1. **Phase 7 Step v7.7.1.2** — Per-device structs, key scheme, hash function.' CURRENT-STATE.md)" = "0" || fail "3.2b old text still present"
test "$(grep -cxF -- '1. **R5, R5r, R5a, R5b** — the tooling PR, the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.' CURRENT-STATE.md)" = "1" || fail "3.2b"
test "$(grep -cF -- '2. **Phase 7 Step v7.7.1.3** — Per-device persist engine (write path).' CURRENT-STATE.md)" = "0" || fail "3.2c old text still present"
test "$(grep -cxF -- '2. **Phase 7 Steps v7.7.1.2 to v7.7.1.4** — per-device structs and key scheme; persist engine (write path); restore engine (boot path) and retention budget.' CURRENT-STATE.md)" = "1" || fail "3.2c"
test "$(grep -cF -- '3. **Phase 7 Step v7.7.1.4** — Per-device restore engine (boot path) + retention budget.' CURRENT-STATE.md)" = "0" || fail "3.2d old text still present"
test "$(grep -cxF -- '3. **v7.7.1.5** — new board secrets (SEC-003).' CURRENT-STATE.md)" = "1" || fail "3.2d"
test "$(grep -cF -- '4. **Phase 7 Steps v7.7.2.1–v7.7.3.3** — Engine switchover, migration, export/import, and closure.' CURRENT-STATE.md)" = "0" || fail "3.2e old text still present"
test "$(grep -cxF -- '4. **Phase 7 Steps v7.7.2.1 to v7.7.3.3** — engine switchover, migration, export and import, and closure. v7.7.3.3 is v1.0 (PLAN-015).' CURRENT-STATE.md)" = "1" || fail "3.2e"
test "$(grep -cF -- '5. **Phase 7 optimization sprint v7.7.5.x** — NVS dedup study, RAM window reduction.' CURRENT-STATE.md)" = "0" || fail "3.2f old text still present"
test "$(grep -cxF -- '5. **After v1.0** — the ESPHome upgrade spike; v1.1 with the partition layouts and the former optimisation sprint; then Phases 8 and 9.' CURRENT-STATE.md)" = "1" || fail "3.2f"
test "$(grep -cF -- '| `Docs/v7.7-implementation-plan.md` |' CURRENT-STATE.md)" = "0" || fail "3.3a line still present"
test "$(grep -cF -- '| `Docs/feature-roadmap.md` |' CURRENT-STATE.md)" = "0" || fail "3.3b line still present"
test "$(grep -cF -- '_Documents that are history only are in `Docs/archive/`. `Docs/archive/README.md` lists what moved there on 2026-11-16 (PLAN-025)._' CURRENT-STATE.md)" = "1" || fail "3.3c"
test "$(grep -cF -- '## Planning Documents (2026-05-07 Multi-Phase Session)' CURRENT-STATE.md)" = "0" || fail "3.4a old text still present"
test "$(grep -cxF -- '## Planning Documents' CURRENT-STATE.md)" = "1" || fail "3.4a"
test "$(grep -cF -- '| `Docs/phase-7-review-and-rewrite.md` | Rewritten Phase 7 plan (supersedes v7.7-implementation-plan.md) |' CURRENT-STATE.md)" = "0" || fail "3.4b old text still present"
test "$(grep -cF -- '| `Docs/plan-of-record.md` | Plan of record: the ladder of steps to v1.0, the scope and done-when of each step, open findings and risks (PLAN-024) |' CURRENT-STATE.md)" = "1" || fail "3.4b"
test "$(grep -cF -- '| `Docs/multi-phase-planning-session-summary.md` |' CURRENT-STATE.md)" = "0" || fail "3.4c line still present"
test "$(grep -c '^_Next action: ' CURRENT-STATE.md)" = "1" || fail "3.1 expected one Next action line"
test "$(grep -c 'Phase 7 Step v7.7.1.2 is dispatched after that' CURRENT-STATE.md)" = "0" || fail "3.1 old Next action text in the file"
test "$(grep -c 'optimization sprint v7.7.5.x' CURRENT-STATE.md)" = "0" || fail "3.2 old What is Next text in the file"
test "$(grep -c 'Multi-Phase Session' CURRENT-STATE.md)" = "0" || fail "3.4 old heading text in the file"
M="$(git rev-parse --git-path r3c-moves.txt)"
test -s "$M" || fail "r3c-moves.txt missing (see §3)"
while read -r old new; do
  b="${old#Docs/}"; a="${new#Docs/}"
  bad="$(git grep -n -F -e "$b" -- . ':!prompts' ':!Docs/archive' ':!Docs/changelog.md' | grep -v -F -e "$a")"
  test -z "$bad" || fail "a live file still names $b by its old path: $bad"
done < "$M"
echo "CHECKPOINT C PASS"
)
```

### Task Group 4 — Instruction files (PLAN-029, PLAN-026)

`AGENTS.md` becomes the one source of rules. The rule on template sensors moves into it from the Copilot file, and the Copilot file shrinks to a pointer. In item 4.2a the new line is an import: write it exactly as given, alone on its line, with no backticks around it.

**4.1a** `AGENTS.md`: immediately after the line
```
_Instructions for AI coding agents working on this repository._
```
insert
```
_Planning and prompt-producing sessions do not start here. They start at `Docs/planner-start-here.md` (PLAN-024)._
```

**4.1b** `AGENTS.md`: immediately before the line
```
## Device Testing
```
insert this text, then one blank line
```
### Template Sensor Updates

A template sensor that has a `lambda:` MUST NOT use `update_interval: never`: ESPHome then never evaluates the lambda, and the value stays empty. Use `60s`. `never` is correct only for a template sensor without a lambda, which the firmware publishes to (FINDING-V769-01, PR #183).
```

**4.1c** `AGENTS.md`: replace the line
```
esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
```
with
```
timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
```

**4.1d** `AGENTS.md`: replace the line
```
- **Blocking:** Generated file edited, NVS on httpd stack, missing external_components, data corruption risk
```
with
```
- **Blocking:** Generated file edited, NVS on httpd stack, missing external_components, data corruption risk, a credential in the diff, the PR body or a comment
```

**4.1e** `AGENTS.md`: delete every line from this line to the end of the file, this line included
```
## PR Title and Body — Preservation Rules (binding for all coding and review agents)
```
and put this text in their place
```
## PR Title and Body — Preservation Rules (binding for all coding and review agents)

When you push commits to or comment on a pull request that you did NOT originate, you MUST treat the PR title and body as **append-only producer-supplied content** unless the original problem statement explicitly authorizes you to rewrite them. This binds every coding or review agent and every automation. It applies equally to the first commit on a branch, to follow-up commits in the same session, and to commits authored under a different bot identity than the one that opened the PR. It overrides any default agent behavior of "ensure PR description is up to date."

1. **Do not replace the PR title.** If the title needs an addendum, append `— round-N: <short note>` rather than overwriting. The original title format `prompts: issue #NNN §X — ...` (or whatever the producer set) MUST remain the leading substring.
2. **Do not replace the PR body.** It contains operator-facing audit evidence: Pre-Implementation Verification, Per-Item Verification, Acceptance Criteria, Audit Gate Notice, Files Modified, and the Round Summary table. These are mandatory in-PR deliverables per `Docs/development-process-guide.md` §2.5.
3. **If you need to add information,** append a new section under a heading `## Round-N notes (added by <your-agent-name>)` at the bottom of the existing body. Never modify the producer-supplied sections above it.
4. **If the PR body is empty or missing a required section** when you arrive, STOP. Post a single comment on the PR titled `⛔ PR body missing required sections` listing which sections are absent, and do not push further commits until the body is restored. Do not attempt to reconstruct the body yourself — you do not have the original verification evidence.
5. **Do not call the GitHub REST API endpoint `PATCH /repos/{owner}/{repo}/pulls/{number}` with a `body` or `title` parameter** unless the operator's problem statement explicitly authorizes it for this PR. Commits and inline review comments do not require this endpoint; only metadata edits do.
6. **Do not "clean up" producer-supplied tables, checkboxes, or verification commands.** Their literal text — including verbatim shell-command output — is part of the audit trail.

A repository CI check (`pr-body-preservation.yml`, when present) enforces this mechanically by failing PRs that lose required sections after they were once present. If your push causes that check to fail, your edit is the regression — restore the missing content from the PR's edit history before adding any new material.
```

**4.2a** `CLAUDE.md`: immediately before the line
```
## 0. This project (ESP32-GW-multi-sensor)
```
insert this text, then one blank line
```
@AGENTS.md
```

**4.2b** `CLAUDE.md`: exactly one line begins with `Claude sessions in this repository act as architect/planner or prompt producer`. Replace that whole line with
```
The role of a Claude session in this repository follows its task (PLAN-026). By default it plans or produces prompts: start at `Docs/planner-start-here.md`, which holds the reading order, the source hierarchy and the planner rules. It is the coding agent only when the operator dispatches an agent prompt to it. Then `AGENTS.md`, imported above, and that prompt bind it, and the execution preamble of the prompt wins over §1 to §4 below: when an instruction seems wrong, stop and flag it, and never change it silently. One session holds one role. In every role: confirm what is happening with one diagnostic command before explaining why, and treat chat memory and past conversations as hints, never as state.
```

**4.3** `.github/copilot-instructions.md`: delete every line from this line to the end of the file, this line included
```
## Architecture — Generated Files
```
and put this text in their place
```
Review against `AGENTS.md`, the one source of rules for coding agents and reviewers (PLAN-029). Use its sections "Generated Files", "Critical Rules", "Code Review Checklist" and "Severity Classification". Skip the diffs of generated files and review their sources.
```

**4.4** `.github/instructions/firmware.instructions.md`: replace the line
```
- All string building from NVS loops must enforce explicit size limits (csv.reserve does NOT truncate)
```
with
```
- Never build a full CSV response in RAM: stream NVS-backed data with `httpd_resp_send_chunk()`, as the history endpoints do (BUG-082, resolved in v7.7.1.1; see `AGENTS.md`)
```

⛔ **CHECKPOINT D**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - D: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '_Planning and prompt-producing sessions do not start here. They start at `Docs/planner-start-here.md` (PLAN-024)._' AGENTS.md)" = "1" || fail "4.1a"
test "$(grep -cF -- '### Template Sensor Updates' AGENTS.md)" = "1" || fail "4.1b"
test "$(grep -cxF -- 'timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' AGENTS.md)" = "1" || fail "4.1c"
test "$(grep -cxF -- '- **Blocking:** Generated file edited, NVS on httpd stack, missing external_components, data corruption risk, a credential in the diff, the PR body or a comment' AGENTS.md)" = "1" || fail "4.1d"
test "$(grep -cF -- 'Wiping them defeats the merge gate.' AGENTS.md)" = "0" || fail "4.1e old wording still present"
test "$(grep -cF -- 'Copilot SWE Agent' AGENTS.md)" = "0" || fail "4.1e old wording still present"
test "$(grep -cF -- 'They are evidence, not formatting drafts.' AGENTS.md)" = "0" || fail "4.1e old wording still present"
test "$(grep -cF -- 'This binds every coding or review agent and every automation.' AGENTS.md)" = "1" || fail "4.1e"
test "$(grep -cF -- '@AGENTS.md' CLAUDE.md)" = "1" || fail "4.2a"
test "$(grep -cF -- 'not as the coding agent' CLAUDE.md)" = "0" || fail "4.2b old wording still present"
test "$(grep -cF -- 'The role of a Claude session in this repository follows its task (PLAN-026).' CLAUDE.md)" = "1" || fail "4.2b"
test "$(grep -cF -- 'must enforce explicit size checks' .github/copilot-instructions.md)" = "0" || fail "4.3 old wording still present"
test "$(grep -cF -- '68 validation checks' .github/copilot-instructions.md)" = "0" || fail "4.3 old wording still present"
test "$(grep -cF -- '## Severity Guide' .github/copilot-instructions.md)" = "0" || fail "4.3 old wording still present"
test "$(grep -cF -- 'update_interval' .github/copilot-instructions.md)" = "0" || fail "4.3 old wording still present"
test "$(grep -cF -- 'the one source of rules for coding agents and reviewers (PLAN-029)' .github/copilot-instructions.md)" = "1" || fail "4.3"
test "$(grep -cF -- '- All string building from NVS loops must enforce explicit size limits (csv.reserve does NOT truncate)' .github/instructions/firmware.instructions.md)" = "0" || fail "4.4 old text still present"
test "$(grep -cxF -- '- Never build a full CSV response in RAM: stream NVS-backed data with `httpd_resp_send_chunk()`, as the history endpoints do (BUG-082, resolved in v7.7.1.1; see `AGENTS.md`)' .github/instructions/firmware.instructions.md)" = "1" || fail "4.4"
test "$(wc -l < AGENTS.md)" = "195" || fail "4.1 AGENTS.md line count"
test "$(wc -l < CLAUDE.md)" = "71" || fail "4.2 CLAUDE.md line count"
test "$(sed -n 3p CLAUDE.md)" = "@AGENTS.md" || fail "4.2 line 3 of CLAUDE.md is not the import"
test "$(grep -c '^@' AGENTS.md)" = "0" || fail "4.1 AGENTS.md must hold no import line"
test "$(wc -l < .github/copilot-instructions.md)" = "5" || fail "4.3 copilot-instructions.md line count"
test -z "$(grep -rn -e 'explicit size checks' -e 'explicit size limits' .github AGENTS.md CLAUDE.md)" || fail "the old BUG-082 rule is still stated in an instruction file"
test "$(grep -c 'update_interval: never' AGENTS.md)" = "1" || fail "4.1b the template sensor rule"
echo "CHECKPOINT D PASS"
)
```

### Task Group 5 — Process guide and methodology

Items 5.2 and 4.1c put the same `timeout 300` in front of the same upload command in two files: the process guide states the rule (§2.3), and both examples now follow it.

**5.1a** `Docs/development-process-guide.md`: immediately after the line
```
10) Run one test command at a time: no second preflight, Playwright run or mock server while one is running
```
insert
```
11) After `gh pr ready`: post the comment `/gemini review` on the PR; wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini; then assess each finding, fix what is warranted, and post one comment with your assessment that names any reviewer that did not post. Never merge, approve or start an external review
12) Stops: a known tooling defect with a recovery written in the prompt gets that recovery once, with the result posted, and a second failure stops; a value you would have to ask for is in the prompt; a real mismatch (a missing anchor, a different value, a path out of scope, a test failing twice) always stops with the checkpoint-failure comment of §3.2
```

**5.1b** `Docs/development-process-guide.md`: immediately before the line
```
**B) The agent prompt** — copy the agent section from the Claude two-step prompt.
```
insert this text, then one blank line
```
Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance.
```

**5.2** `Docs/development-process-guide.md`: replace the line
```
esphome upload  firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
```
with
```
timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189
```

**5.3a** `Docs/development-process-guide.md`: replace the line
```
After inline reviews complete, agent addresses findings:
```
with
```
After the inline reviews the agent addresses the findings by itself (§2.2 item 11, PLAN-027). After each external review the operator pastes the same line to the agent:
```

**5.3b** `Docs/development-process-guide.md`: immediately after the line that begins with
```
External review B runs the structured three-turn review protocol as the final quality gate.
```
insert one blank line, then
```
Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout. When Claude Code codes a step, external review A is a GPT model. When the review-runner PR is merged, PLAN-022 and PLAN-023 replace this section: after the inline round, reviews A and C run side by side, and review B by the runner comes last (`Docs/plan-of-record.md`, section 7).
```

**5.4** `Docs/development-process-guide.md`: replace the line
```
2. **`CURRENT-STATE.md` update** — bump "Last verified" date, append to "What Just Shipped," update "What's Next," add/remove "Open Issues" and "Unimplemented Recommendations."
```
with
```
2. **`CURRENT-STATE.md` update** — bump "Last verified" date, append to "What Just Shipped," update "What's Next," add/remove "Open Issues" and "Unimplemented Recommendations." Mark the step's row in the ladder of `Docs/plan-of-record.md` and move its "You are here" line (PLAN-024).
```

**5.5** `Docs/development-process-guide.md`: immediately after the line
```
| 2 — Decision Index | `Docs/decisions/decision-log.md` | ~3K | Planning sessions |
```
insert
```
| 2 — Plan of Record | `Docs/plan-of-record.md`; planners enter at `Docs/planner-start-here.md` | ~8K | Planning sessions |
```

**5.6** `Docs/development-process-guide.md`: replace these 3 consecutive lines
```
- `.github/copilot-instructions.md` — top 10 review rules, consumed by Copilot inline review (4,000 char limit)
- `.github/instructions/*.instructions.md` — path-specific rules for firmware, dashboard, and Playwright files
- `AGENTS.md` — comprehensive agent instructions, consumed by multiple AI agents (Copilot, Claude, Gemini)
```
with
```
`AGENTS.md` is the one source of rules for coding agents and reviewers. The other files point to it and repeat a rule only where their reader needs it. Each file stays under 200 lines, and a PR that changes a rule changes every file that states it (PLAN-029).

| File | Who loads it by itself (vendors' documentation, checked 2026-11-16) |
|---|---|
| `AGENTS.md` | Codex; GitHub Copilot (code review and cloud agent on GitHub, VS Code chat, CLI); Claude Code through the import line in `CLAUDE.md` |
| `CLAUDE.md` | Claude Code; GitHub Copilot (code review and cloud agent on GitHub, CLI). Not Codex |
| `.github/copilot-instructions.md` | GitHub Copilot only, in every Copilot feature |
| `.github/instructions/*.instructions.md` | GitHub Copilot only (code review and cloud agent on GitHub, VS Code chat, CLI); `applyTo` names the paths |

The Gemini inline reviewer loads none of these files; R5a decides whether it gets a `.gemini/styleguide.md`. Copilot's code review reads the instruction files from the head branch of the PR, so a PR that edits one of them changes its own Copilot review: the review file of such a step tells reviewers A and B to read that diff by hand.
```

**5.7** `Docs/writing-guide/methodology.md`: replace the line
```
- **Post-execution review (3-turn):** Perplexity — GitHub MCP access, structured review protocol
```
with
```
- **Post-execution review (3-turn):** in Phase Y, Perplexity — GitHub MCP access, structured review protocol. The reviewers of today are in `Docs/development-process-guide.md` §2.4 (PLAN-019)
```

⛔ **CHECKPOINT E**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - E: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '11) After `gh pr ready`: post the comment `/gemini review` on the PR' Docs/development-process-guide.md)" = "1" || fail "5.1a"
test "$(grep -cF -- 'Items 11 and 12 hold from R3c on (PLAN-027): the coding agent starts the inline review round itself, and the stop rules are decided in advance.' Docs/development-process-guide.md)" = "1" || fail "5.1b"
test "$(grep -cF -- 'esphome upload  firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' Docs/development-process-guide.md)" = "0" || fail "5.2 old text still present"
test "$(grep -cxF -- 'timeout 300 esphome upload firmware/esp32-c3-multi-sensor.yaml --device=192.168.120.189' Docs/development-process-guide.md)" = "1" || fail "5.2"
test "$(grep -cF -- 'After inline reviews complete, agent addresses findings:' Docs/development-process-guide.md)" = "0" || fail "5.3a old text still present"
test "$(grep -cxF -- 'After the inline reviews the agent addresses the findings by itself (§2.2 item 11, PLAN-027). After each external review the operator pastes the same line to the agent:' Docs/development-process-guide.md)" = "1" || fail "5.3a"
test "$(grep -cF -- 'Claude Code is the fallback coding agent (PLAN-026). The agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout. When Claude Code codes a step, external review A is a GPT model. When the review-runner PR is merged, PLAN-022 and PLAN-023 replace this section: after the inline round, reviews A and C run side by side, and review B by the runner comes last (`Docs/plan-of-record.md`, section 7).' Docs/development-process-guide.md)" = "1" || fail "5.3b"
test "$(grep -cF -- 'Mark the step'"'"'s row in the ladder of `Docs/plan-of-record.md`' Docs/development-process-guide.md)" = "1" || fail "5.4"
test "$(grep -cF -- '| 2 — Plan of Record | `Docs/plan-of-record.md`; planners enter at `Docs/planner-start-here.md` | ~8K | Planning sessions |' Docs/development-process-guide.md)" = "1" || fail "5.5"
test "$(grep -cxF -- '- `.github/copilot-instructions.md` — top 10 review rules, consumed by Copilot inline review (4,000 char limit)' Docs/development-process-guide.md)" = "0" || fail "5.6 old line still present"
test "$(grep -cxF -- '- `.github/instructions/*.instructions.md` — path-specific rules for firmware, dashboard, and Playwright files' Docs/development-process-guide.md)" = "0" || fail "5.6 old line still present"
test "$(grep -cxF -- '- `AGENTS.md` — comprehensive agent instructions, consumed by multiple AI agents (Copilot, Claude, Gemini)' Docs/development-process-guide.md)" = "0" || fail "5.6 old line still present"
test "$(grep -cF -- '4,000 char' Docs/development-process-guide.md)" = "0" || fail "5.6 old wording still present"
test "$(grep -cF -- '`AGENTS.md` is the one source of rules for coding agents and reviewers.' Docs/development-process-guide.md)" = "1" || fail "5.6"
test "$(grep -cF -- '- **Post-execution review (3-turn):** Perplexity — GitHub MCP access, structured review protocol' Docs/writing-guide/methodology.md)" = "0" || fail "5.7 old text still present"
test "$(grep -cF -- 'The reviewers of today are in `Docs/development-process-guide.md` §2.4 (PLAN-019)' Docs/writing-guide/methodology.md)" = "1" || fail "5.7"
test "$(grep -c '^| 5 | Meta Muse, Spark or Wonder (external review B); fallback: Gemini on the web |' Docs/development-process-guide.md)" = "1" || fail "5.x the reviewer table of §2.4 must stay as it is (PLAN-019)"
test "$(grep -c 'timeout 300 esphome upload' Docs/development-process-guide.md AGENTS.md | grep -c ':1$')" = "2" || fail "5.2 one upload line with a timeout in each of the two files"
test -z "$(git grep -n 'Post-execution review (3-turn):\*\* Perplexity' -- . ':!prompts' ':!Docs/archive' ':!Docs/changelog.md')" || fail "5.7 the old reviewer line is still in a live file"
echo "CHECKPOINT E PASS"
)
```

### Task Group 6 — Decision log

Add the nine rows directly below the row of SEC-003, in the order given. Do not touch the lines after the table.

**6.1** `Docs/decisions/decision-log.md`: replace the line
```
_Updated: 2026-11-14_
```
with
```
_Updated: 2026-11-16_
```

**6.2** `Docs/decisions/decision-log.md`: immediately after the line that begins with
```
| 2026-11-14 | SEC-003 |
```
insert
```
| 2026-11-16 | PLAN-022 | Review runner for external review B (operator decisions 2026-11-15 and 2026-11-16), an exception to PLAN-012: one workflow, `.github/workflows/external-review.yml`, that the operator starts from the Actions tab (`workflow_dispatch` only) with its code on `main`, in the GitHub environment `external-review`, which allows `main` only. It signs in to Google Cloud through Workload Identity Federation and stores no key. It runs the three turns of the external review template on the step's agent prompt and review file, read from the PR head; it treats all PR text and earlier reviews as data; it stops when its input exceeds its limit; it posts one comment as `github-actions[bot]`, with @-mentions and review commands removed. Models: an allow-list in the script on `main`, `gemini-4-hydrogen` by default, `gemini-4-argon` and `gemini-4-carbon`; models of other vendors are listed and switched off, and switching one on is a PR to `main`. The input `profile` selects one of several Google Cloud projects. It comes in its own tooling PR (R5r, MEDIUM) after the R5 tooling PR, with all five reviews; its first run is a dry run on PR #235. Until that PR is merged, PLAN-019 stands | `Docs/plan-of-record.md` (One code step with reviews A, B and C) |
| 2026-11-16 | PLAN-023 | Reviews A, B and C (operator decisions 2026-11-16), from the merge of the review-runner PR (PLAN-022), an exception to PLAN-012 (HowTo §6.1: a project sets its review default once). After the three inline reviews: external review A is Claude in its own session, or a GPT model when Claude Code coded the step (PLAN-026); external review C is a Meta Muse session, required on MEDIUM and HIGH firmware steps and optional on LOW steps and documentation PRs; A and C run side by side in one round; external review B is the review runner in three turns, always last. If the runner cannot run, the step waits for it; the operator may instead run review B as a Muse session in three turns, as before the runner (PLAN-019), and the consolidated audit names the change. Gemini on the web is no fallback, because it cannot post the comment. After each round the coding agent assesses and fixes with the fixed line; after the last round it writes every finding and its outcome into the consolidated audit, before the merge (HowTo §6.2). The planning session writes one review file per step, with a common part and the parts A, B and C. The runner PR changes every place that states the review pipeline: process guide §2.4 and §3.1, the review-pipeline line of `Docs/templates/prompt-audit-template.md`, the reviewer line of `prompts/phase7/consolidated-audit-template-phase7.md`, and the plan of record. From that merge this supersedes the reviewer clauses of PLAN-019, its Gemini-on-the-web fallback included, and "five reviewers on every code step" in PLAN-017 | `Docs/plan-of-record.md` (One code step with reviews A, B and C) |
| 2026-11-16 | PLAN-024 | Plan of record and entry points by role (completes PLAN-021): `Docs/plan-of-record.md` holds the step ladder with estimates in sessions, the scope and done-when of each step, open findings, risks and what still holds of the feature roadmap. It replaces the planning document outside the repository as a source; that document is a working notebook only. Entry points: `Docs/planner-start-here.md` for planning and prompt-producing sessions of any vendor, `AGENTS.md` for coding agents, `Docs/operator/` for the operator; `CLAUDE.md` and `.github/copilot-instructions.md` point to them. The plan changes only through PRs: each step's PR marks its own ladder row and moves "You are here" (process guide §2.5 item 2), and a change of order or scope writes a decision row first (HowTo §3.4). No forecast date is stored | `Docs/plan-of-record.md` (How to read this file) |
| 2026-11-16 | PLAN-025 | Archive of `Docs/` (operator decision 2026-11-16, on the inventory of 2026-11-15): 18 documents and 25 session logs move to `Docs/archive/` (its root, `planning-2026-05/`, `completed-phases/`, `methodology-audits-2026-05/`, `session-logs/`) with `git mv` and no edit, so each move is a pure rename; 20 documents and the two Phase 7 session logs stay. Live files that name a moved file get the new path; `Docs/changelog.md`, `prompts/**` and `Docs/archive/**` keep the old paths as history. `Docs/archive/README.md` lists every move. The feature roadmap merges into the plan of record, then moves; `Docs/board-selection-guide-expansion.md` merges at v7.7.3.3 and `Docs/phase7-github-tracking-supplement.md` in R5a | `Docs/archive/README.md` |
| 2026-11-16 | PLAN-026 | Claude Code is the fallback coding agent (operator decision 2026-11-15; amends the coding-agent clause of PLAN-019, where Codex is the coding agent): the agent changes only at a step boundary, or at a passed checkpoint with a handoff comment on the PR, and two agents never work in one checkout; when Claude Code codes a step, external review A is a GPT model, so no external reviewer comes from the coding agent's vendor; the first use is on a documentation step. `CLAUDE.md` imports `AGENTS.md`, so Claude Code reads the same rules as the other agents, and a Claude session codes only when the operator dispatches a prompt to it | `prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md` §6 |
| 2026-11-16 | PLAN-027 | Review round started by the coding agent, and stop rules decided in advance (operator decisions 2026-11-15), from R3c on, written into the setup block of process guide §2.2. After `gh pr ready` the agent posts `/gemini review`, waits up to 30 minutes for the three inline reviews, then assesses and fixes with the fixed line and posts its assessment, naming any reviewer that did not post; it never merges, approves or starts an external review. Stops: a failed command of the agent's own is repaired and repeated, and no checkpoint runs while an edit before it is missing; a known tooling defect with a recovery written in the prompt gets that recovery once, with the result posted, and a second failure stops; a value the agent would have to ask for is supplied by the prompt; a real mismatch (a missing anchor, a different value, a path out of scope, a test failing twice) always stops with the checkpoint-failure comment of process guide §3.2 | `prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md` §6 |
| 2026-11-16 | PLAN-028 | CI fast path for documentation PRs (operator decision 2026-11-14), replacing the CI stub in the R5 item list of PLAN-017: the required `preflight-and-compile` job still starts on every pull request to `main` (PLAN-020); its first step lists the changed paths; when every path is documentation, it runs preflight only and skips the ESPHome install and the compile; any other path, and any path the list does not know, runs the full job. The R5 prompt fixes the list of documentation paths and tests it in its rehearsal | `Docs/plan-of-record.md` (R5) |
| 2026-11-16 | PLAN-029 | Instruction files (vendors' documentation checked 2026-11-15 and 2026-11-16): `AGENTS.md` is the one source of rules for coding agents and reviewers; `CLAUDE.md` holds only Claude-specific text below an `@AGENTS.md` import; `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md` point to `AGENTS.md` and repeat a rule only where their reader needs it; each file stays under 200 lines. A PR that changes a rule changes every file that states it. Copilot reads instruction files from the PR's head branch, so the review file of a PR that edits an instruction file tells reviewers A and B to read that diff by hand. Whether the Gemini inline reviewer gets a `.gemini/styleguide.md` is decided in R5a | `Docs/development-process-guide.md` §7.2 |
| 2026-11-16 | PLAN-030 | Who may run a planning or prompt-producing session (operator decisions 2026-11-16; completes PLAN-024). A session of any vendor and any account may plan and produce prompts, on three conditions. It has its own clone of the repository and a shell, so that it can run the gates. It starts at `Docs/planner-start-here.md` and keeps the planner rules: it never pushes to this repository or opens a pull request in it, never touches the boards, never writes a credential, and holds one role. It does not run on the build host, where the checkout of the coding agent, the boards and the secrets are. The normal way is Claude Code on the operator's Claude subscription, in a cloud session. Overflow, for a session that the subscription limit stops: a Claude model through another provider that meets the three conditions, which is Claude Code on Google's Agent Platform (Vertex AI), on Amazon Bedrock or on Microsoft Foundry, or the agent of GitHub Copilot in VS Code or its CLI. A metered provider is relied on only after one session has been measured in its billing report. A chat without a shell may plan, but it cannot gate. Each gate record names the model, the provider and the tool that produced the prompt | `prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md` §6 |
```

⛔ **CHECKPOINT F**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - F: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '_Updated: 2026-11-14_' Docs/decisions/decision-log.md)" = "0" || fail "6.1 old text still present"
test "$(grep -cxF -- '_Updated: 2026-11-16_' Docs/decisions/decision-log.md)" = "1" || fail "6.1"
test "$(grep -cF -- '| PLAN-030 |' Docs/decisions/decision-log.md)" = "1" || fail "6.2"
test "$(grep -c '^_Updated: 2026-11-16_$' Docs/decisions/decision-log.md)" = "1" || fail "6.1 _Updated_ line"
test "$(grep -cE '^\| 2026-11-16 \| PLAN-0(2[2-9]|30) \|' Docs/decisions/decision-log.md)" = "9" || fail "6.2 nine new rows"
test "$(grep -c '^| ' Docs/decisions/decision-log.md)" = "54" || fail "6.2 table rows (45 before, 54 after)"
test "$(tail -n 1 Docs/decisions/decision-log.md)" = "_Add new entries at the bottom. Format: date, short ID, one-line decision, link to source._" || fail "6.2 the last line of the log changed"
echo "CHECKPOINT F PASS"
)
```

### Task Group 7 — Supplied files

**7.1** The operator has saved five files in `/root/r3c/`, and the setup block has checked their SHA-256. Copy each one byte for byte with this block. Do not open them in an editor and do not reformat them. The block must print nothing.

```bash
cd /root/config/ESP32-GW-multi-sensor || exit 1
cp /root/r3c/plan-of-record.md Docs/plan-of-record.md && cmp /root/r3c/plan-of-record.md Docs/plan-of-record.md || echo "COPY FAILED: Docs/plan-of-record.md"
cp /root/r3c/planner-start-here.md Docs/planner-start-here.md && cmp /root/r3c/planner-start-here.md Docs/planner-start-here.md || echo "COPY FAILED: Docs/planner-start-here.md"
cp /root/r3c/archive-README.md Docs/archive/README.md && cmp /root/r3c/archive-README.md Docs/archive/README.md || echo "COPY FAILED: Docs/archive/README.md"
cp /root/r3c/R3c-plan-into-repository.md Docs/operator/R3c-plan-into-repository.md && cmp /root/r3c/R3c-plan-into-repository.md Docs/operator/R3c-plan-into-repository.md || echo "COPY FAILED: Docs/operator/R3c-plan-into-repository.md"
cp /root/r3c/R5-tooling.md Docs/operator/R5-tooling.md && cmp /root/r3c/R5-tooling.md Docs/operator/R5-tooling.md || echo "COPY FAILED: Docs/operator/R5-tooling.md"
```

### Task Group 8 — Record of this step (its consolidated audit)

**8.0** The setup block has made this prompt, verbatim, the first commit after the bootstrap commit, as `prompts/handoff/phase7/plan-of-record-2026-11-16-restart-agent-prompt.md`. Confirm it with `git log --oneline -- prompts/handoff/phase7/plan-of-record-2026-11-16-restart-agent-prompt.md`; if the file is missing, STOP.

**8.1** Create `prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md` with these eight sections, each under a heading line that begins `## §<number> `, in this order: §1 Why (the plan of the restart lived outside the repository, so only one vendor's session could plan; PLAN-021 asked for this step); §2 Edit list, one row per item 1.1 to 7.1 with its verify command and observed output, quoting no line of a moved file; §3 Review findings by severity (fill after the review round; name every reviewer that ran and state plainly when one did not post); §4 Agent autonomous decisions (expected none); §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2; §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the issue #228 status table below, verbatim, with `<NN>` replaced by this PR's number; §8 Process metrics (the five numbers of HowTo v2 §5.6). For §8 the operator supplies two numbers: producer sessions 3 (inventory and runner design 2026-11-15; outline, verdicts and decision rows 2026-11-16; production, rehearsal and gate 2026-11-16) and audit sessions 0 (LOW tier: lint and one rehearsal inside the producer session). Take the other three from this PR.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-022 | A review runner for external review B: started by hand from `main`, three turns, Google's models, no stored key; its own tooling PR (R5r, MEDIUM) after R5 | A web chat cannot post its review, has no fixed protocol and leaves no record of what it read. A key file as a repository secret could be read by a pull request from a branch of this repository |
| PLAN-023 | Reviews A, B and C from the merge of the runner PR; A and C side by side, B last; if the runner cannot run, the step waits or review B is a Muse session | The method makes the structured review the last one. A Muse session adds a fourth model family. Gemini on the web cannot post the comment |
| PLAN-024 | The plan of record is `Docs/plan-of-record.md`; entry points by role; no forecast date is stored | The plan lived in one long document outside the repository. A planner or an agent of any vendor must be able to work from the repository alone |
| PLAN-025 | 18 documents and 25 session logs move to `Docs/archive/` as pure renames | They are history, not instruction. A pure rename shows no line of a moved file in the diff, and four of the moved files hold the old login |
| PLAN-026 | Claude Code is the fallback coding agent; review A is then a GPT model | The coding agent's subscription limit can stop a step. No external reviewer comes from the vendor of the agent that coded the step |
| PLAN-027 | The coding agent starts the inline review round itself; the stop rules are decided in advance | Both stops of PR #234 needed the operator, and neither was a real mismatch |
| PLAN-028 | CI fast path for documentation PRs, in place of the CI stub | A required check must report on every pull request. A stub that always passes would weaken it. A documentation PR needs no firmware compile |
| PLAN-029 | `AGENTS.md` is the one source of rules; the other instruction files point to it; each stays under 200 lines | The Copilot files had drifted: they still stated the BUG-082 rule that PR #235 replaced, and a severity scale that contradicted `AGENTS.md` |
| PLAN-030 | Who may run a planning session: any vendor and account with its own clone and a shell, under the planner rules, not on the build host; Claude models through other providers as overflow | The subscription limit stopped a planning session on 2026-11-14. On the build host the planner rules would rest on obedience alone |
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
| Plan of record into the repository | PR #<NN> | `Docs/plan-of-record.md`, entry points by role, archive of `Docs/`, instruction files, PLAN-022 to PLAN-030 |
| §C meta-prompt guardrails | OPEN — one tooling PR (R5) with the items that PLAN-017, PLAN-020 and PLAN-028 list | Runs before the Batch 2 re-production |
| §D phase-closure questions | DEFERRED — folded into the v7.7.3.3 closure prompt | |
| §E producer-prompt evolution | OPEN — producer contract and batch-production prompt v3.0 (R5a) | v3.0 must be shorter than v2.0 (PLAN-012) |

**Dispatch state: the May Batch 2 prompts (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) are NOT dispatched. They are re-produced under the method of record first. The order of all steps is in `Docs/plan-of-record.md`.**
```

⛔ **CHECKPOINT G**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - G: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(sha256sum < Docs/plan-of-record.md | cut -d" " -f1)" = "fc5a87e6156d9e00a7898484652cc9a79f2ef7b9bbb7e100b0edb80d92fe9209" || fail "7.1 Docs/plan-of-record.md differs from the supplied file"
test "$(sha256sum < Docs/planner-start-here.md | cut -d" " -f1)" = "6d1da8fe3e63c861ddad216cb68fd4046ac35b2065ee61c7e282f91f294c31f1" || fail "7.1 Docs/planner-start-here.md differs from the supplied file"
test "$(sha256sum < Docs/archive/README.md | cut -d" " -f1)" = "7055c7145aad653edc99fb4b548ef4c43f6a26a00812140219539c2bd6ab6135" || fail "7.1 Docs/archive/README.md differs from the supplied file"
test "$(sha256sum < Docs/operator/R3c-plan-into-repository.md | cut -d" " -f1)" = "29284534a9049e06d75c4db6364b51d9aa99cb6110e34da550dbb9338dbca48a" || fail "7.1 Docs/operator/R3c-plan-into-repository.md differs from the supplied file"
test "$(sha256sum < Docs/operator/R5-tooling.md | cut -d" " -f1)" = "dceb8fe45eef96f776e226377fec09a1ae9f04c7067c9c891e41451ec8b208ae" || fail "7.1 Docs/operator/R5-tooling.md differs from the supplied file"
test "$(sed -n '/^```mermaid$/,/^```$/p' Docs/plan-of-record.md Docs/operator/R3c-plan-into-repository.md Docs/operator/R5-tooling.md | grep -c ';')" = "0" || fail "7.1 a semicolon inside a Mermaid block"
test "$(ls prompts/handoff/phase7/plan-of-record-2026-11-16-restart*.md | wc -l)" = "2" || fail "8.x expected 2 plan-of-record files"
test "$(grep -c '^## §[1-8] ' prompts/handoff/phase7/plan-of-record-2026-11-16-restart.md)" = "8" || fail "8.1 record sections"
test -z "$(grep -lE '<D[D]>' AGENTS.md CLAUDE.md .github/copilot-instructions.md .github/instructions/firmware.instructions.md Docs/development-process-guide.md Docs/decisions/decision-log.md CURRENT-STATE.md README.md Docs/architecture-overview.md Docs/decisions/AGG-ADR-001-satellite-history-storage.md Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md Docs/phase-7-review-and-rewrite.md Docs/templates/prompt-audit-template.md Docs/v7.7-v7.8-persistence-architecture.md Docs/writing-guide/multi-llm-prompt-optimization-analysis-2026-04-09.md Docs/writing-guide/methodology.md Docs/plan-of-record.md Docs/planner-start-here.md Docs/archive/README.md Docs/operator/R3c-plan-into-repository.md Docs/operator/R5-tooling.md)" || fail "a placeholder is left in a changed file"
echo "CHECKPOINT G PASS"
)
```

### PRE-PR Gate

Commit everything first; the gate stops on an uncommitted change.

```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - PRE-PR: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
git fetch origin || fail "git fetch"
A="$(git rev-parse --git-path scope-allowed.txt)"
test -s "$A" || fail "scope-allowed.txt missing (see §3)"
BASE="$(git merge-base origin/main HEAD)" || fail "merge-base"
CHANGED="$( { git diff --name-only --no-renames "$BASE"...HEAD; git diff --name-only --no-renames --cached; git diff --name-only --no-renames; git ls-files --others --exclude-standard; } | sort -u )"
OUT="$(printf '%s\n' "$CHANGED" | grep -v '^$' | grep -vxF -f "$A")"
test -z "$OUT" || fail "out-of-scope paths: $OUT"
test "$(printf '%s\n' "$CHANGED" | grep -c .)" = "109" || fail "expected 109 changed paths (16 changed, 43 old and 43 new paths of the moves, 7 new)"
test -z "$(git status --porcelain)" || fail "uncommitted changes: commit before this gate"
test "$(git diff -M100% --name-status "$BASE" HEAD | grep -c '^R100')" = "43" || fail "git does not show 43 pure renames"
test "$(git diff -M100% --name-status "$BASE" HEAD | grep -c '^[RD]')" = "43" || fail "a rename with changed lines, or a deleted file"
test "$(git diff -M100% --name-status "$BASE" HEAD | grep -c '^M')" = "16" || fail "expected 16 changed files"
test "$(git diff -M100% --name-status "$BASE" HEAD | grep -c '^A')" = "7" || fail "expected 7 new files"
test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
M="$(git rev-parse --git-path r3c-moves.txt)"
test -s "$M" || fail "r3c-moves.txt missing (see §3)"
while read -r old new; do
  b="${old#Docs/}"; a="${new#Docs/}"
  bad="$(git grep -n -F -e "$b" -- . ':!prompts' ':!Docs/archive' ':!Docs/changelog.md' | grep -v -F -e "$a")"
  test -z "$bad" || fail "a live file still names $b by its old path: $bad"
done < "$M"
bash scripts/lint-prompts.sh --baseline origin/main prompts/handoff/phase7/plan-of-record-2026-11-16-restart*.md || fail "lint"
bash scripts/preflight.sh || fail "preflight"
echo "PRE-PR PASS"
)
```

Known tooling defect: `scripts/preflight.sh` hides the browser test's report. If the block stops with `PRE-PR: preflight` and the last check printed before it is `mutex_single_owner: PASS`, the browser test failed. The operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; run `npx playwright test tests/browser/manifest.spec.js --project=chromium; echo "playwright exit $?"` and post its last 40 lines as a PR comment; if it prints `playwright exit 0`, run the PRE-PR block one more time, unchanged. If the diagnostic or the second run fails, STOP and report. Record the event in §5 of the record file. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027; new from this step on)

1. Update the PR body (§8), then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini. Do not wait longer.
4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions").
5. After a fix, run every CHECKPOINT that covers the changed file, and the PRE-PR block, again.
6. Fill §3 of the record file, commit, push, and post one comment with your assessment. Name each reviewer that posted, and each one that did not post within the 30 minutes.
7. Never merge, never approve, and never start an external review. The operator decides.

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to G and the PRE-PR block each print PASS; their verbatim output is in the PR body
- [ ] Exactly the §3 paths changed: 16 changed files, 43 pure renames, 7 new files; no code, no workflow, no generated file, no `VERSION` change
- [ ] No line of a moved file is in the diff: git shows each of the 43 moves as a rename at 100 %
- [ ] No live file names a moved file by its old path; `Docs/changelog.md`, `prompts/` and `Docs/archive/` are unchanged apart from the new files of §3
- [ ] `AGENTS.md` and `CLAUDE.md` are each under 200 lines; line 3 of `CLAUDE.md` is the import of `AGENTS.md`
- [ ] The reviewer table of process guide §2.4 is unchanged
- [ ] The GitHub checks `preflight-and-compile` and `prompt-lint` pass on the final head
- [ ] The record file is complete after the review round and committed before merge
- [ ] PR title: `docs: plan of record into the repository — entry points, archive of Docs/, instruction files, decision rows (refs #228)`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet. Under Files Modified, list the 16 changed files and the 7 new files by name, and the moves as "43 files moved to `Docs/archive/` with `git mv`; `Docs/archive/README.md` lists each one". Device testing: N/A — documentation-only step; no deployment.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag, and it closes no issue. After the merge the operator replaces the status table at the top of issue #228 with the table in §7 of the record file. You run none of it.
