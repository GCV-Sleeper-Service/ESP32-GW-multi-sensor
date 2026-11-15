# Restart Housekeeping — BUG-082 status, fleet table, login out of agent-read files, decision rows (GPT/Codex Agent Prompt)

_Full self-contained implementation instructions_
_Date: 2026-11-14_
_Prerequisite: `main` contains `8062726` (PR #234, method of record bound); `VERSION` 7.7.1.1_
_Risk: LOW — documentation, prompt files and `.gitignore` only; no firmware, dashboard, script, partition, CI or generated-artifact change; no version bump_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Apply every edit with your file-edit tool, one item at a time, in the order given. Never apply edits with a script that parses this prompt (PR #234, stop 1).
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run or mock server while one is running (PR #234, stop 2).
- Every edit is verbatim and anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines included; the fence lines themselves are not part of it.
- Every check below is executable: run each block as written. A mismatch prints `⛔ CHECKPOINT FAILED` and exits non-zero; then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- Seven files still hold the management login as a literal. Items 2.6 and 3.1-3.2 name those lines by the text beside the login. Never copy the login into a command you post, a PR body, a comment or a file; when you quote such a line as evidence, quote the new line only.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch and committed this prompt. Confirm you are on the branch:

```bash
cd /root/config/ESP32-GW-multi-sensor
test "$(git branch --show-current)" = "docs/restart-housekeeping-2026-11" || { echo "Wrong branch - STOP and report"; exit 1; }
```

Read completely, in this order:
0. `CURRENT-STATE.md` — every section; Task Group 2 edits six of them.
1. `Docs/development-process-guide.md` — §2.2 to §2.5, §3.2 and §7.
2. `AGENTS.md` — the sections "Project Overview", "Architecture — What NOT to Edit", "Critical Rules", "Device Testing" and "Permissions, Deployment Targets and Instructions".
3. `Docs/decisions/decision-log.md` — the table format for Task Group 4.
4. `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — the coverage table, "Resolution Tracking" and the last line.

## §2 — Pre-Implementation Verification Gate

Run this block BEFORE any edit. It stops at the first mismatch; then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2.

```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - §2: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
git merge-base --is-ancestor 8062726 HEAD || fail "8062726 (PR #234) is not an ancestor of HEAD"
test "$(grep -c 'Method of record' Docs/development-process-guide.md)" = "1" || fail "method of record is not bound (PR #234)"
test "$(grep -c '^_Updated: 2026-11-14_$' Docs/decisions/decision-log.md)" = "1" || fail "decision log _Updated_ line is not 2026-11-14"
test "$(grep -cE 'HEAP-002a|PLAN-01[345689]|PLAN-02[01]|BOARD-002|SEC-00[23] ' Docs/decisions/decision-log.md)" = "0" || fail "a row of this PR is already present"
test "$(grep -c '^| ' Docs/decisions/decision-log.md)" = "33" || fail "decision log table rows"
test "$(grep -c 'Amendment 2026-11' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "0" || fail "SEC-ADR amendment already present"
test "$(grep -c 'fleet.local.csv' .gitignore)" = "0" || fail ".gitignore entry already present"
test ! -e Docs/operator || fail "Docs/operator already exists"
test "$(grep -c 'httpd_resp_send_chunk' firmware/core/web-handler.h)" = "4" || fail "BUG-082 fix: chunk calls"
test "$(grep -c 'csv.reserve' firmware/core/web-handler.h)" = "0" || fail "BUG-082 fix: csv.reserve still present"
test "$(grep -c 'read_chunked_body_' firmware/core/aggregator-runtime.h)" -ge 2 || fail "BUG-082 fix: aggregator dechunking"
test "$(ls firmware/core/*.h | wc -l)" = "9" || fail "fragment count is not 9"
test "$(grep -c 'Public history endpoint' firmware/core/web-handler.h)" = "2" || fail "history endpoints are not public"
test "$(git grep -c -E -e '-u [^"$ ][^ ]*:' -- AGENTS.md Docs/development-process-guide.md prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md | wc -l)" = "4" || fail "expected a literal login in 4 files"
test "$(grep -cxF -- '### csv.reserve() Bug (BUG-082)' AGENTS.md)" = "1" || fail "1.1a anchor"
test "$(grep -cxF -- '`std::string::reserve(N)` does NOT truncate. Code building CSV from NVS loops MUST enforce explicit size checks. The full fix (chunked streaming) is Phase 7.' AGENTS.md)" = "1" || fail "1.1b anchor"
test "$(grep -cF -- '8 firmware C++ fragments' AGENTS.md)" = "1" || fail "1.2a anchor"
test "$(grep -cF -- '(8 fragments)' AGENTS.md)" = "1" || fail "1.2b anchor"
test "$(grep -cxF -- '├── nvs-persistence.h     # NVS read/write, segment management, history metadata' AGENTS.md)" = "1" || fail "1.2c anchor"
test "$(grep -cF -- '**Resolution:** Deferred to Phase 7. The proper fix is chunked HTTP streaming - serving NVS segments in paged responses (~3.6 KB each) instead of building the full CSV in RAM.' Docs/lessons/firmware.md)" = "1" || fail "1.3 anchor"
test "$(grep -cxF -- '> **Current version: v7.6.5.8** — Phase X complete (Dashboard Architecture Refactor).' README.md)" = "1" || fail "1.4a anchor"
test "$(grep -cxF -- 'esphome run firmware/esp32-c3-multi-sensor.yaml' README.md)" = "1" || fail "1.4b anchor"
test "$(grep -cxF -- '_Last verified: 2026-05-08 — v7.7.1.1 validation complete_' CURRENT-STATE.md)" = "1" || fail "2.1 anchor"
test "$(grep -cxF -- '_Next action: Phase 7 Step v7.7.1.2 — per-device structs, key scheme, and hash function_' CURRENT-STATE.md)" = "1" || fail "2.2 anchor"
test "$(grep -cF -- '- **Method of record:**' CURRENT-STATE.md)" = "1" || fail "2.3 anchor"
test "$(grep -cxF -- '| A-004 | Medium | C5 WROOM-1U BLE non-functional — external IPEX antenna not attached. Re-test pending. | Before Phase 7 |' CURRENT-STATE.md)" = "1" || fail "2.4 anchor"
test "$(grep -cxF -- '_Source: `Docs/board-measurement-log-v7.6.10.md` (2026-05-05)_' CURRENT-STATE.md)" = "1" || fail "2.5 anchor"
test "$(grep -cF -- 'Credentials: ' CURRENT-STATE.md)" = "1" || fail "2.6 anchor"
test "$(grep -cF -- '| v7.6.10.4 session log |' CURRENT-STATE.md)" = "1" || fail "2.7 anchor"
test "$(grep -cF -- '| `Docs/v7.7-v7.8-persistence-architecture.md` |' CURRENT-STATE.md)" = "1" || fail "2.8 anchor"
test "$(grep -cF -- 'http://192.168.120.189/api/status/full | python3 -m json.tool' AGENTS.md)" = "1" || fail "3.1a anchor"
test "$(grep -cF -- 'http://192.168.120.189/api/status/full | python3 -m json.tool' Docs/development-process-guide.md)" = "1" || fail "3.1b anchor"
test "$(grep -cF -- 'http://192.168.120.189/api/status/full | python3 -m json.tool | head -20' prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md)" = "1" || fail "3.1c anchor"
test "$(grep -cF -- 'http://192.168.120.170/api/status/full | python3 -m json.tool | head -20' prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md)" = "1" || fail "3.1d anchor"
test "$(grep -cF -- 'http://192.168.120.189/api/status/full | python3 -m json.tool | head -20' prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md)" = "1" || fail "3.1e anchor"
test "$(grep -cF -- 'http://192.168.120.170/api/status/full | python3 -m json.tool | head -20' prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md)" = "1" || fail "3.1f anchor"
test "$(grep -cF -- 'Credentials: ' prompts/handoff/phase7/session-handoff-v7.7.1.2.md)" = "1" || fail "3.2a anchor"
test "$(grep -cF -- 'Credentials: ' prompts/handoff/phase7/session-handoff-v7.7.1.4.md)" = "1" || fail "3.2b anchor"
test "$(grep -cF -- '- Push only to your feature branch.' AGENTS.md)" = "1" || fail "3.3 anchor"
test "$(grep -cxF -- '| `/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4a anchor"
test "$(grep -cxF -- '| `/api/v2/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4b anchor"
test "$(grep -cF -- '| RV-07 `/api/v2/live` unauthenticated |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4c anchor"
test "$(grep -cxF -- '_End of SEC-ADR-001._' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4d anchor"
test "$(grep -cxF -- 'config/aggregator.json' .gitignore)" = "1" || fail "3.5 anchor"
test "$(grep -cF -- '| 2026-11-14 | PLAN-017 |' Docs/decisions/decision-log.md)" = "1" || fail "4.1 anchor"
test "$(grep -cxF -- '| 4 | GPT/ChatGPT | Web portal (external) | Comprehensive PR analysis |' Docs/development-process-guide.md)" = "1" || fail "5.1a anchor"
test "$(grep -cxF -- '| 5 | Codex (external) | Web portal | Comprehensive PR analysis |' Docs/development-process-guide.md)" = "1" || fail "5.1b anchor"
test "$(grep -cxF -- 'Perplexity runs the structured three-turn review protocol as the final quality gate when MCP cooperates. When MCP fails, operator downloads the review output manually.' Docs/development-process-guide.md)" = "1" || fail "5.1c anchor"
test "$(grep -cxF -- '| External Reviewers | [GPT, Codex, Perplexity — list which participated] |' prompts/phase7/consolidated-audit-template-phase7.md)" = "1" || fail "5.2 anchor"
test "$(grep -cxF -- 'The CI workflow (`.github/workflows/ci.yml`) only runs on changes to code, config, scripts, and build files. Documentation-only PRs, prompts, images, and tags do not trigger CI.' Docs/development-process-guide.md)" = "1" || fail "5.3a anchor"
test "$(grep -cxF -- '3. **CI path filtering:** Submit a docs-only PR. If CI doesn'"'"'t trigger, path filtering is working.' Docs/development-process-guide.md)" = "1" || fail "5.3b anchor"
test "$(grep -cxF -- '7) Update PR description (use PR176-178 as reference)' Docs/development-process-guide.md)" = "1" || fail "5.4 anchor"
echo "§2 PASS"
)
```

## §3 — Scope Boundary

Files you MAY modify (complete list; nothing else):
- `AGENTS.md` (items 1.1, 1.2, 3.1a, 3.3 only)
- `README.md` (item 1.4 only)
- `Docs/lessons/firmware.md` (item 1.3 only)
- `CURRENT-STATE.md` (Task Group 2 only)
- `Docs/development-process-guide.md` (items 3.1b, 5.1, 5.3, 5.4 only)
- `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` (items 3.1c and 3.1d only: two lines)
- `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` (items 3.1e and 3.1f only: two lines)
- `prompts/handoff/phase7/session-handoff-v7.7.1.2.md` (item 3.2a only: one line)
- `prompts/handoff/phase7/session-handoff-v7.7.1.4.md` (item 3.2b only: one line)
- `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (item 3.4 only)
- `.gitignore` (item 3.5 only)
- `Docs/decisions/decision-log.md` (item 4.1 only)
- `prompts/phase7/consolidated-audit-template-phase7.md` (item 5.2 only: one line)
- NEW: `Docs/operator/R3b-restart-housekeeping.md` (item 6.1: a supplied file, copied byte for byte)
- NEW: `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md`
- NEW: `prompts/handoff/phase7/housekeeping-2026-11-14-restart-agent-prompt.md` (this prompt, verbatim; the setup block has committed it)

Write these sixteen paths, one bare path per line, to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`, so it is never part of the change. The PRE-PR gate checks every changed path against it.

```bash
cat > "$(git rev-parse --git-path scope-allowed.txt)" <<'EOF'
AGENTS.md
README.md
CURRENT-STATE.md
.gitignore
Docs/lessons/firmware.md
Docs/decisions/decision-log.md
Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md
Docs/development-process-guide.md
prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md
prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md
prompts/handoff/phase7/session-handoff-v7.7.1.2.md
prompts/handoff/phase7/session-handoff-v7.7.1.4.md
prompts/phase7/consolidated-audit-template-phase7.md
Docs/operator/R3b-restart-housekeeping.md
prompts/handoff/phase7/housekeeping-2026-11-14-restart.md
prompts/handoff/phase7/housekeeping-2026-11-14-restart-agent-prompt.md
EOF
```

Files you MUST NOT modify: anything under `firmware/`, `dashboard/`, `scripts/`, `src/`, `tests/`, `partitions/`, `.github/`, `config/`; `VERSION`; `Docs/changelog.md`; `CLAUDE.md`; every other file under `prompts/` and `Docs/`.

You MUST NOT: run `bash scripts/bump-version.sh` or any `--write` command; create, close or edit issues or milestones (the operator does that after the merge, §9); rename or delete files; merge.

## §4 — Critical Rules Checklist

- Rule 2 — canonical repo tooling only; `lint-prompts.sh` reports, it never rewrites.
- Rule 4 — no generated file is touched.
- Rules 62/63 — checkpoints are queries with expected values; on mismatch STOP, do not fix.

## §5 — DO-NOT List

- Do NOT reword, reformat or move text around an edit.
- Do NOT change anything else in the four May Batch 2 files of items 3.1c-3.1f and 3.2: they are superseded and are replaced later; only their login lines change now.
- Do NOT edit the board addresses, the flash commands or any other line of the `## Device Testing` section of `AGENTS.md` except the one line of item 3.1a.
- Do NOT put a credential in any command, file or PR text.
- Do NOT bump the version or add a changelog entry.

## §6 — Implementation Steps

### Task Group 1 — BUG-082 status and stale facts

**1.1a** `AGENTS.md`: replace the line
```
### csv.reserve() Bug (BUG-082)
```
with
```
### csv.reserve() Bug (BUG-082) — RESOLVED in v7.7.1.1
```

**1.1b** `AGENTS.md`: replace the line
```
`std::string::reserve(N)` does NOT truncate. Code building CSV from NVS loops MUST enforce explicit size checks. The full fix (chunked streaming) is Phase 7.
```
with
```
`std::string::reserve(N)` does NOT truncate. Never build a full CSV response in RAM. History endpoints stream with `httpd_resp_send_chunk()` (`handle_history_()` and `handle_api_v2_history_()` in `firmware/core/web-handler.h`, PR #226); the aggregator dechunks upstream history in `fetch_to_buffer()` (`firmware/core/aggregator-runtime.h`). Any new endpoint that serialises NVS-backed data MUST use the same chunked pattern.
```

**1.2a** `AGENTS.md`: this text occurs once; replace
```
8 firmware C++ fragments
```
with
```
9 firmware C++ fragments
```

**1.2b** `AGENTS.md`: this text occurs once; replace
```
(8 fragments)
```
with
```
(9 fragments)
```

**1.2c** `AGENTS.md`: immediately after the line
```
├── nvs-persistence.h     # NVS read/write, segment management, history metadata
```
insert
```
├── health-check.h        # Periodic heap, stack high-water mark and NVS statistics task (v7.7.1.0)
```

**1.3** `Docs/lessons/firmware.md`: this text occurs once; replace
```
**Resolution:** Deferred to Phase 7. The proper fix is chunked HTTP streaming - serving NVS segments in paged responses (~3.6 KB each) instead of building the full CSV in RAM.
```
with
```
**Resolution:** Fixed in v7.7.1.1 (PR #226, 2026-05-08): `handle_history_()` and `handle_api_v2_history_()` stream CSV with `httpd_resp_send_chunk()`, and the aggregator dechunks upstream responses. Device evidence: `Docs/session-log-2026-05-08-v7.7.1.1.md`. Restart check, 2026-11-11: a full-length history export from the WROOM (.170) completed without a reboot. Still open, routed to the Phase 7 closure step (v7.7.3.3): one full-length export from the WROOM at 60 % NVS fill or more, with peak heap recorded. (Original disposition, superseded: chunked streaming deferred to Phase 7, serving NVS segments in paged responses instead of building the full CSV in RAM.)
```

**1.4a** `README.md`: replace the line
```
> **Current version: v7.6.5.8** — Phase X complete (Dashboard Architecture Refactor).
```
with
```
> **Current version: v7.7.1.1** — Phase 7 in progress (per-device persistence engine). BUG-082 (history heap exhaustion) is resolved by chunked streaming in v7.7.1.1.
```

**1.4b** `README.md`: replace the line
```
esphome run firmware/esp32-c3-multi-sensor.yaml
```
with
```
esphome upload firmware/esp32-c3-multi-sensor.yaml --device=<board-ip>   # never 'esphome run': it waits on log output (see AGENTS.md)
```

⛔ **CHECKPOINT A**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - A: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- 'RESOLVED in v7.7.1.1' AGENTS.md)" = "1" || fail "1.1a"
test "$(grep -cF -- '`std::string::reserve(N)` does NOT truncate. Code building CSV from NVS loops MUST enforce explicit size checks. The full fix (chunked streaming) is Phase 7.' AGENTS.md)" = "0" || fail "1.1b old text still present"
test "$(grep -cF -- 'Never build a full CSV response in RAM.' AGENTS.md)" = "1" || fail "1.1b"
test "$(grep -cF -- '8 firmware C++ fragments' AGENTS.md)" = "0" || fail "1.2a old text still present"
test "$(grep -cF -- '9 firmware C++ fragments' AGENTS.md)" = "1" || fail "1.2a"
test "$(grep -cF -- '(8 fragments)' AGENTS.md)" = "0" || fail "1.2b old text still present"
test "$(grep -cF -- '(9 fragments)' AGENTS.md)" = "1" || fail "1.2b"
test "$(grep -cF -- '├── health-check.h' AGENTS.md)" = "1" || fail "1.2c"
test "$(grep -cF -- '**Resolution:** Deferred to Phase 7. The proper fix is chunked HTTP streaming - serving NVS segments in paged responses (~3.6 KB each) instead of building the full CSV in RAM.' Docs/lessons/firmware.md)" = "0" || fail "1.3 old text still present"
test "$(grep -cF -- '**Resolution:** Fixed in v7.7.1.1 (PR #226, 2026-05-08)' Docs/lessons/firmware.md)" = "1" || fail "1.3"
test "$(grep -cF -- '> **Current version: v7.6.5.8** — Phase X complete (Dashboard Architecture Refactor).' README.md)" = "0" || fail "1.4a old text still present"
test "$(grep -cF -- 'Current version: v7.7.1.1' README.md)" = "1" || fail "1.4a"
test "$(grep -cF -- 'esphome run firmware/esp32-c3-multi-sensor.yaml' README.md)" = "0" || fail "1.4b old text still present"
test "$(grep -cF -- '--device=<board-ip>' README.md)" = "1" || fail "1.4b"
echo "CHECKPOINT A PASS"
)
```

### Task Group 2 — `CURRENT-STATE.md`

**2.1** `CURRENT-STATE.md`: replace the line
```
_Last verified: 2026-05-08 — v7.7.1.1 validation complete_
```
with
```
_Last verified: 2026-11-14 — restart re-verification by the operator: on 2026-11-11 the production boards .189, .170 and .191 reported v7.7.1.1, ESPHome was 2026.4.1, the httpd stack override check passed and a compile without upload succeeded; on 2026-11-14 the same three boards reported v7.7.1.1 again. No firmware change since v7.7.1.1._
```

**2.2** `CURRENT-STATE.md`: replace the line
```
_Next action: Phase 7 Step v7.7.1.2 — per-device structs, key scheme, and hash function_
```
with
```
_Next action: the restart plan of record into the repository (PLAN-021), then the tooling PR, the producer contract and the Batch 2 prompts re-produced under the method of record (PLAN-017). Phase 7 Step v7.7.1.2 is dispatched after that._
```

**2.3** `CURRENT-STATE.md`: immediately after the line that begins with
```
- **Method of record:**
```
insert
```
- **Development paused:** 2026-05-10 to 2026-11-14, for reasons outside the project. The May 2026 Batch 2 prompts (v7.7.1.2 to v7.7.1.4) are not dispatched: they are re-produced under the method of record and audited at their tier first (PLAN-017).
```

**2.4** `CURRENT-STATE.md`: replace the line
```
| A-004 | Medium | C5 WROOM-1U BLE non-functional — external IPEX antenna not attached. Re-test pending. | Before Phase 7 |
```
with
```
| A-004 | Medium | C5 WROOM-1U BLE not verified. The external antenna is fitted (operator, 2026-11-05). The re-test needs a BLE-capable build on .180. | Test-board check |
| WROOM heap | Medium | `.170` reported `min_free_heap` 3,988 B at 7.5 days uptime on v7.7.1.1 (operator reading, 2026-11-14; 5,156 B on 2026-11-11 in the same boot). It is the lowest value since boot: a deep dip, not a proven leak. | Heap sampling, decided before v7.7.1.2 |
```

**2.5** `CURRENT-STATE.md`: immediately before the line
```
_Source: `Docs/board-measurement-log-v7.6.10.md` (2026-05-05)_
```
insert, then one blank line
```
_Fleet: nine boards (BOARD-002). Identity comes from the operator's board file and esptool output of 2026-11-04. `firmware_now` comes from the operator's `fleet` output of 2026-11-11 and readings of 2026-11-14; the date is in each cell._

| device_id | Board | Chip (esptool) | Module | Flash MB | PSRAM MB | USB | IP | Role | board_profile | firmware_now | Antenna | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sat-esp32-4m-170 | ESP32 dev board | ESP32-D0WD-V3, rev v3.1 | WROOM-32D (module marking not checked) | 4 | 0 | USB-UART bridge | 192.168.120.170 | production satellite | `esp32-wroom-32d` | v7.7.1.1 (2026-11-14) | fitted | formerly at .190 |
| sat-s3-4m-173 | ESP32-S3 SuperMini | ESP32-S3 (QFN56), rev v0.2 | none (flash and PSRAM in the chip package) | 4 | 2 | native USB-Serial/JTAG | 192.168.120.173 | test | `esp32-s3-supermini-4m` | v7.6.10.1 (2026-11-11) | fitted | marginal as an aggregator |
| sat-c5-8m-180 | ESP32-C5 dev board | ESP32-C5, rev v1.0 | WROOM-1U | 8 | 8 | USB-UART bridge | 192.168.120.180 | test | `esp32-c5-wroom1u-8m` | v7.6.10.1 (2026-11-11) | external, fitted | BLE not verified (A-004) |
| sat-c5-8m-181 | Seeed XIAO ESP32C5 | ESP32-C5, rev v1.0 | ESP32-C5-WROOM-1 | 8 | 8 | native USB-Serial/JTAG | 192.168.120.181 | not yet on project firmware | none yet | minimum firmware (2026-11-14) | external, fitted | needs a board profile |
| sat-c6-4m-184 | ESP32-C6 SuperMini | ESP32-C6FH4 (QFN32), rev v0.2 | none | 4 | 0 | native USB-Serial/JTAG | 192.168.120.184 | test | `esp32-c6-supermini-4m` | v7.6.10.1 (2026-11-11) | fitted | OTA slot 91.6 % full in May 2026 |
| esp32-c3-multi | ESP32-C3 SuperMini | ESP32-C3 (QFN32), rev v0.4 | none | 4 | 0 | native USB-Serial/JTAG | 192.168.120.189 | production satellite | `esp32-c3-supermini` | v7.7.1.1 (2026-11-14) | fitted | renamed sat-c3-4m-176 at .176 after v1.0 |
| agg-s3-16m-1 | ESP32-S3-DevKitC-1 N16R8 | ESP32-S3 (QFN56), rev v0.2 | N16R8 | 16 | 8 | USB-UART bridge | 192.168.120.191 | production aggregator | `esp32-s3-devkitc1-n16r8` | v7.7.1.1 (2026-11-14) | fitted | renamed agg-s3-16m-191 after v1.0 |
| agg-s3-16m-192 | ESP32-S3-DevKitC-1 N16R8 | ESP32-S3 (QFN56), rev v0.2 | N16R8 | 16 | 8 | USB-UART bridge | 192.168.120.192 | test aggregator | `esp32-s3-devkitc1-n16r8` | minimum firmware (2026-11-14) | fitted | its web page has an OTA upload form and no login |
| agg-c5-8m-194 | Seeed XIAO ESP32C5 | ESP32-C5, rev v1.0 | ESP32-C5-WROOM-1 | 8 | 8 | native USB-Serial/JTAG | 192.168.120.194 | not yet on project firmware | none yet | minimum firmware (2026-11-14) | external, fitted | needs a board profile |

_Minimum firmware is a plain ESPHome build without the project firmware. Such a board does not answer `/api/status`. The private columns (MAC, hub port, tty) are in the git-ignored `config/fleet.local.csv` on the build host._

### Measurements (2026-05-05)
```

**2.6** `CURRENT-STATE.md`: exactly one line begins with `Credentials: `. Replace that whole line with
```
Credentials: `$ESP_USER` / `$ESP_PASS` in the operator's shell; the firmware reads `gateway_mgmt_username` / `gateway_mgmt_password` from the git-ignored `firmware/secrets.yaml`
```

**2.7** `CURRENT-STATE.md`: immediately after the line that begins with
```
| v7.6.10.4 session log |
```
insert
```
| Restart check 2026-11 | Full-length WROOM history export at 60 % NVS fill or more, with peak heap recorded (BUG-082 acceptance evidence) | **Partly done** — a full-length export completed on 2026-11-11 without a reboot; peak heap and NVS fill were not recorded. Routed to the Phase 7 closure step (v7.7.3.3) |
| Restart check 2026-11 | Firmware `.bin` size checkpoint against the OTA slot in every Phase 7 prompt from v7.7.1.3 on (C6 4 MB at 91.6 %) | **Not implemented** — routed to the Batch 2 re-production |
| Restart check 2026-11 | README test counts disagree (402 and 117); reconcile with `npx playwright test --list` | **Not implemented** — routed to the v7.7.3.3 README rewrite |
| Restart check 2026-11 | Make `dashboard/dashboard.h` reproducible: `scripts/generate-header.sh` compresses with `gzip -9 -c`, which stores a file name and a time, so every build changes the file (for example use `gzip -n`) | **Not implemented** — code change, needs its own PR |
| PR #234 | `scripts/preflight.sh` sends the browser test's report to `/dev/null`, so a failure leaves no evidence | **Not implemented** — routed to the tooling PR (PLAN-020) |
| Issue #228 §D | Phase-closure prompt refinements | **Deferred** — folded into the v7.7.3.3 closure prompt |
```

**2.8** `CURRENT-STATE.md`: immediately after the line that begins with
```
| `Docs/v7.7-v7.8-persistence-architecture.md` |
```
insert
```
| `Docs/phase-7-review-and-rewrite.md` | 2026-05-07 | Its section "Partition Table Changes" plans the USB reflash for v7.7.1.4. The partition change moves to v1.1 as its own step (PLAN-015). |
| `Docs/phase-E-captive-portal-plan.md` | 2026-05-07 | Phase E is deferred until after Phase 9, and step E-b waits for the Zigbee spike (PLAN-014). Re-check the plan against the current ESPHome release before use. |
| `Docs/phase-9-cloud-upload-plan.md` | 2026-05-07 | The primary upload target is now the Azure tier-2 ingest endpoint, not InfluxDB Cloud (PLAN-013). Rewrite at Phase 9 start. |
| `Docs/feature-roadmap.md` | 2026-05-06 | Its phase order and cloud target are superseded by PLAN-013 to PLAN-015. Where it differs from `Docs/phase-8-notifications-plan.md`, the plan document wins. |
| The nine Batch 2 prompt files of May 2026: the agent prompt and the two-step file of v7.7.1.2, v7.7.1.3 and v7.7.1.4 in `prompts/phase7/`, and `session-handoff-v7.7.1.2.md`, `-v7.7.1.3.md` and `-v7.7.1.4.md` in `prompts/handoff/phase7/` | 2026-05 | **Superseded, not to be dispatched** (PLAN-017). They are re-produced under the method of record; until then they are source material only. |
```

⛔ **CHECKPOINT B**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - B: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '_Last verified: 2026-05-08 — v7.7.1.1 validation complete_' CURRENT-STATE.md)" = "0" || fail "2.1 old text still present"
test "$(grep -cF -- '_Last verified: 2026-11-14 — restart re-verification' CURRENT-STATE.md)" = "1" || fail "2.1"
test "$(grep -cF -- '_Next action: Phase 7 Step v7.7.1.2 — per-device structs, key scheme, and hash function_' CURRENT-STATE.md)" = "0" || fail "2.2 old text still present"
test "$(grep -cF -- '_Next action: the restart plan of record' CURRENT-STATE.md)" = "1" || fail "2.2"
test "$(grep -cF -- '- **Development paused:**' CURRENT-STATE.md)" = "1" || fail "2.3"
test "$(grep -cF -- '| A-004 | Medium | C5 WROOM-1U BLE non-functional — external IPEX antenna not attached. Re-test pending. | Before Phase 7 |' CURRENT-STATE.md)" = "0" || fail "2.4 old text still present"
test "$(grep -cF -- '| WROOM heap | Medium |' CURRENT-STATE.md)" = "1" || fail "2.4"
test "$(grep -cF -- '| sat-c5-8m-181 |' CURRENT-STATE.md)" = "1" || fail "2.5"
test "$(grep -cF -- 'Credentials: `$ESP_USER`' CURRENT-STATE.md)" = "1" || fail "2.6"
test "$(grep -cF -- 'routed to the tooling PR (PLAN-020)' CURRENT-STATE.md)" = "1" || fail "2.7"
test "$(grep -cF -- '**Superseded, not to be dispatched** (PLAN-017)' CURRENT-STATE.md)" = "1" || fail "2.8"
echo "CHECKPOINT B PASS"
)
```

### Task Group 3 — The management login leaves the files agents read (SEC-003)

In items 2.6, 3.1 and 3.2 the old line carries the login, so this prompt does not quote it. Find the line by the text given, replace the whole line, and do not copy the old line anywhere.

**3.1a** `AGENTS.md`: exactly one line contains `http://192.168.120.189/api/status/full | python3 -m json.tool`. Replace that whole line with
```
curl -s -u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full | python3 -m json.tool
```

**3.1b** `Docs/development-process-guide.md`: exactly one line contains `http://192.168.120.189/api/status/full | python3 -m json.tool`. Replace that whole line with
```
curl -s -u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full | python3 -m json.tool
```

**3.1c** `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md`: exactly one line contains `http://192.168.120.189/api/status/full | python3 -m json.tool | head -20`. Replace that whole line with
```
curl -s --connect-timeout 5 --max-time 10 -u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full | python3 -m json.tool | head -20
```

**3.1d** `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md`: exactly one line contains `http://192.168.120.170/api/status/full | python3 -m json.tool | head -20`. Replace that whole line with
```
curl -s --connect-timeout 5 --max-time 10 -u "$ESP_USER:$ESP_PASS" http://192.168.120.170/api/status/full | python3 -m json.tool | head -20
```

**3.1e** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`: exactly one line contains `http://192.168.120.189/api/status/full | python3 -m json.tool | head -20`. Replace that whole line with
```
curl -s --connect-timeout 5 --max-time 10 -u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full | python3 -m json.tool | head -20
```

**3.1f** `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`: exactly one line contains `http://192.168.120.170/api/status/full | python3 -m json.tool | head -20`. Replace that whole line with
```
curl -s --connect-timeout 5 --max-time 10 -u "$ESP_USER:$ESP_PASS" http://192.168.120.170/api/status/full | python3 -m json.tool | head -20
```

**3.2a** `prompts/handoff/phase7/session-handoff-v7.7.1.2.md`: exactly one line begins with `Credentials: `. Replace that whole line with
```
Credentials: `$ESP_USER` / `$ESP_PASS` in the operator's shell; the firmware reads `gateway_mgmt_username` / `gateway_mgmt_password` from the git-ignored `firmware/secrets.yaml`
```

**3.2b** `prompts/handoff/phase7/session-handoff-v7.7.1.4.md`: exactly one line begins with `Credentials: `. Replace that whole line with
```
Credentials: `$ESP_USER` / `$ESP_PASS` in the operator's shell; the firmware reads `gateway_mgmt_username` / `gateway_mgmt_password` from the git-ignored `firmware/secrets.yaml`
```

**3.3** `AGENTS.md`: immediately after the line that begins with
```
- Push only to your feature branch.
```
insert
```
- Credentials come only from the operator's environment: `curl -u "$ESP_USER:$ESP_PASS"`. Never write a user name with its password, an API key or an OTA password into a command you post, a PR body, a log or a file. If you find one in the repository, report the file and line in the PR, not the value.
```

**3.4a** `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`: replace the line
```
| `/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |
```
with
```
| `/history/` | GET | ❌ Public since v7.6.9.0 (`0a4b0d1`), SEC-002 | RV-04 |
```

**3.4b** `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`: replace the line
```
| `/api/v2/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |
```
with
```
| `/api/v2/history/` | GET | ❌ Public since v7.6.9.0 (`0a4b0d1`), SEC-002 | RV-04 |
```

**3.4c** `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`: immediately after the line that begins with
```
| RV-07 `/api/v2/live` unauthenticated |
```
insert
```
| RV-08 Secrets in the public repository | Out of the files agents read (restart housekeeping PR); every board secret changed (SEC-003) | v7.7.1.5 |
| RV-09 Native OTA without a password | Per-board OTA password (SEC-003) | v7.7.1.5 |
```

**3.4d** `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`: immediately before the line
```
_End of SEC-ADR-001._
```
insert, then one blank line
```
## Amendment 2026-11 (restart)

_Added 2026-11-14 by the restart housekeeping PR. It records what changed since this ADR was written; the sections above stay as written._

1. **Deployment.** The boards are LAN-only since 2026-11-05: the operator deleted every Cloudflare Tunnel route. No route returns until the conditions of SEC-003 hold.
2. **History is public.** Since v7.6.9.0 (`0a4b0d1`, PR #183) `/history/` and `/api/v2/history/` need no login. This replaces the history statements in RV-01 and RV-04 and the two V2-E rows of the coverage table. It is accepted for the LAN-only deployment and is re-decided before any Internet route (SEC-002).
3. **Shared management login.** Since v7.6.8.0 (`56ae93c`, PR #180) the aggregator sends its own management login to each satellite's `/api/status/full`, so every board on project firmware carries the same login. `/api/v2/live` and `/api/manifest` stay public (RV-06, RV-07).
4. **RV-08, secrets in the public repository.** The management password, the native API key and the bootstrap OTA and fallback-AP passwords are in tracked files. The restart housekeeping PR takes the management login out of the files agents read. Every board secret changes in v7.7.1.5 (SEC-003). Git history keeps the old values, so only that change makes them useless.
5. **RV-09, native OTA without a password.** The `ota:` block of `firmware/esp32-c3-multi-sensor.yaml` sets no password, so any device on the LAN can upload firmware to a board on project firmware. v7.7.1.5 adds a per-board OTA password (SEC-003).

---
```

**3.5** `.gitignore`: immediately after the line
```
config/aggregator.json
```
insert
```
# Local fleet file with private columns (MAC, hub port, tty) - never commit
config/fleet.local.csv
```

⛔ **CHECKPOINT C**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - C: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' AGENTS.md)" = "1" || fail "3.1a"
test "$(grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' Docs/development-process-guide.md)" = "1" || fail "3.1b"
test "$(grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md)" = "1" || fail "3.1c"
test "$(grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.170/api/status/full' prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md)" = "1" || fail "3.1d"
test "$(grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md)" = "1" || fail "3.1e"
test "$(grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.170/api/status/full' prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md)" = "1" || fail "3.1f"
test "$(grep -cF -- 'Credentials: `$ESP_USER`' prompts/handoff/phase7/session-handoff-v7.7.1.2.md)" = "1" || fail "3.2a"
test "$(grep -cF -- 'Credentials: `$ESP_USER`' prompts/handoff/phase7/session-handoff-v7.7.1.4.md)" = "1" || fail "3.2b"
test "$(grep -cF -- '- Credentials come only from the operator' AGENTS.md)" = "1" || fail "3.3"
test "$(grep -cF -- '| `/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "0" || fail "3.4a old text still present"
test "$(grep -cF -- '| `/history/` | GET | ❌ Public since v7.6.9.0 (`0a4b0d1`), SEC-002 | RV-04 |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4a"
test "$(grep -cF -- '| `/api/v2/history/` | GET | ✅ Yes (V2-E) | RV-01, RV-04 |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "0" || fail "3.4b old text still present"
test "$(grep -cF -- '| `/api/v2/history/` | GET | ❌ Public since v7.6.9.0 (`0a4b0d1`), SEC-002 | RV-04 |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4b"
test "$(grep -cF -- '| RV-09 Native OTA without a password |' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4c"
test "$(grep -cF -- '## Amendment 2026-11 (restart)' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md)" = "1" || fail "3.4d"
test "$(grep -cF -- 'config/fleet.local.csv' .gitignore)" = "1" || fail "3.5"
test -z "$(grep -nE -- '-u [^"$ ][^ ]*:' AGENTS.md Docs/development-process-guide.md prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md)" || fail "a curl line still carries a literal login"
test -z "$(grep -n '^Credentials: `[^$]' CURRENT-STATE.md prompts/handoff/phase7/session-handoff-v7.7.1.2.md prompts/handoff/phase7/session-handoff-v7.7.1.4.md)" || fail "a Credentials line still carries a value"
git check-ignore -q config/fleet.local.csv || fail "config/fleet.local.csv is not ignored"
echo "CHECKPOINT C PASS"
)
```

### Task Group 4 — Decision log

The `_Updated: 2026-11-14_` line already carries today's date; leave it.

**4.1** `Docs/decisions/decision-log.md`: immediately after the line that begins with
```
| 2026-11-14 | PLAN-017 |
```
insert
```
| 2026-11-14 | HEAP-002a | BUG-082 is resolved in v7.7.1.1 by chunked history streaming (supersedes HEAP-002, "full fix deferred to Phase 7"); the HEAP-001 adaptive cap stays as a second guard | `Docs/session-log-2026-05-08-v7.7.1.1.md` |
| 2026-11-14 | PLAN-013 | The primary Phase 9 upload target is the Azure tier-2 ingest endpoint (supersedes decision C-2, InfluxDB Cloud as primary target, in `Docs/phase-9-cloud-upload-plan.md`); InfluxDB stays documented as an alternative only (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-014 | Phase E is deferred until after Phase 9 (supersedes the position of Phase E in PLAN-005); step 8.1 owns the settings and credential NVS namespace; step E-b waits for the Zigbee spike (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-015 | v1.0 is v7.7.3.3, the Phase 7 closure; `v1.0-rc1` is tagged at v7.7.2.3; the v7.7.5.x optimisation sprint becomes v1.1; the PLAN-004 partition layouts (USB reflash) move to v1.1 as their own HIGH step (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-016 | ESPHome stays pinned at 2026.4.1 through v1.0; an upgrade is assessed after v1.0 in a spike on test boards only (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-018 | Quality, functionality and security come before speed; every planned date is indicative, and no estimate justifies skipping a check, shortening a review or merging early (operator decision 2026-11-05) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-019 | Review pipeline (operator decisions 2026-11-14): Codex is the coding agent; external review A is Claude in its own session; external review B is a Meta Muse model (Spark or Wonder), with Gemini on the web as the fallback. This supersedes reviewer rows 4 and 5 and the Perplexity paragraph of `Docs/development-process-guide.md` §2.4, because both former external reviewers came from the coding agent's vendor | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-020 | CI (PR #234, `d4fe89a`): the required `preflight-and-compile` job runs on every pull request to `main`, documentation-only ones too, because a required check that a path filter skips blocks the merge. The tooling PR of PLAN-017 also makes `scripts/preflight.sh` show the browser test's report when that test fails (operator decision 2026-11-14) | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | PLAN-021 | Two additions to the PLAN-017 list, as exceptions to PLAN-012 (operator decisions 2026-11-14): an operator guide in `Docs/operator/`, one page per step, in simple English with one diagram; and one documentation PR that brings the restart plan of record into `Docs/` and moves superseded planning documents to `Docs/archive/` after an inventory | `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` §6 |
| 2026-11-14 | BOARD-002 | Nine-board fleet (supersedes BOARD-001): production C3 .189, WROOM .170 and S3 16 MB .191; test S3 4 MB .173, C5 .180, C6 .184 and S3 16 MB .192; two XIAO ESP32C5 (.181, .194) not yet on project firmware. Boards are renamed to the role-chip-flash-octet convention after v1.0 (.189 becomes sat-c3-4m-176 at .176; agg-s3-16m-1 becomes agg-s3-16m-191) | `CURRENT-STATE.md` (Board Fleet and Measurements) |
| 2026-11-14 | SEC-002 | `/history/` and `/api/v2/history/` are public since v7.6.9.0 (`0a4b0d1`); accepted for the LAN-only deployment; replaces the V2-E history login recorded in SEC-ADR-001; re-decided before any Internet route (SEC-003) | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (Amendment 2026-11) |
| 2026-11-14 | SEC-003 | No secret value in any tracked file agents read: agents and scripts take the management login from `$ESP_USER`/`$ESP_PASS`, firmware from the git-ignored `firmware/secrets.yaml`. The management password, native API key and OTA password change in one sitting in v7.7.1.5 (LOW), the step after v7.7.1.4. No Internet route until that is done, an Access application with an Allow policy fronts the hostname, only the aggregator is published, and SEC-002 is re-decided | `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` (Amendment 2026-11) |
```

⛔ **CHECKPOINT D**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - D: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '| SEC-003 |' Docs/decisions/decision-log.md)" = "1" || fail "4.1"
test "$(grep -c '^_Updated: 2026-11-14_$' Docs/decisions/decision-log.md)" = "1" || fail "_Updated_ line"
test "$(grep -cE '^\| 2026-11-14 \| (HEAP-002a|PLAN-01[345689]|PLAN-02[01]|BOARD-002|SEC-00[23]) \|' Docs/decisions/decision-log.md)" = "12" || fail "12 new rows"
test "$(grep -c '^| ' Docs/decisions/decision-log.md)" = "45" || fail "table rows (33 before, 45 after)"
echo "CHECKPOINT D PASS"
)
```

### Task Group 5 — Review pipeline, CI text and setup lines

**5.1a** `Docs/development-process-guide.md`: replace the line
```
| 4 | GPT/ChatGPT | Web portal (external) | Comprehensive PR analysis |
```
with
```
| 4 | Claude (external review A) | Its own session, apart from planning and from the coding agent | Whole-PR review: findings by severity, each acceptance criterion checked |
```

**5.1b** `Docs/development-process-guide.md`: replace the line
```
| 5 | Codex (external) | Web portal | Comprehensive PR analysis |
```
with
```
| 5 | Meta Muse, Spark or Wonder (external review B); fallback: Gemini on the web | Its own session | Structured three-turn review |
```

**5.1c** `Docs/development-process-guide.md`: replace the line
```
Perplexity runs the structured three-turn review protocol as the final quality gate when MCP cooperates. When MCP fails, operator downloads the review output manually.
```
with
```
External review B runs the structured three-turn review protocol as the final quality gate. No external reviewer comes from the coding agent's vendor; the coding agent is Codex (PLAN-019). Each external reviewer posts one PR comment, or the operator pastes its output into the PR. A reviewer never pushes, merges or approves.
```

**5.2** `prompts/phase7/consolidated-audit-template-phase7.md`: replace the line
```
| External Reviewers | [GPT, Codex, Perplexity — list which participated] |
```
with
```
| External Reviewers | [A: Claude; B: Meta Muse (fallback: Gemini) — list which participated and the model each one named] |
```

**5.3a** `Docs/development-process-guide.md`: replace the line
```
The CI workflow (`.github/workflows/ci.yml`) only runs on changes to code, config, scripts, and build files. Documentation-only PRs, prompts, images, and tags do not trigger CI.
```
with
```
The CI workflow (`.github/workflows/ci.yml`) runs its `preflight-and-compile` job on every pull request to `main`, documentation-only ones too: branch protection requires that check, and a required check that a path filter skips blocks the merge (PLAN-020). On a push to `main` the workflow still runs only for changes to code, config, scripts and build files.
```

**5.3b** `Docs/development-process-guide.md`: replace the line
```
3. **CI path filtering:** Submit a docs-only PR. If CI doesn't trigger, path filtering is working.
```
with
```
3. **CI on pull requests:** Submit a docs-only PR. The `preflight-and-compile` check must start; if it does not, the merge stays blocked (PLAN-020).
```

**5.4** `Docs/development-process-guide.md`: immediately after the line
```
7) Update PR description (use PR176-178 as reference)
```
insert
```
8) Apply every edit with your file-edit tool; never with a script that parses the prompt
9) If one of your own commands fails, repair it and repeat the step; run no checkpoint while an edit before it is missing
10) Run one test command at a time: no second preflight, Playwright run or mock server while one is running
```

⛔ **CHECKPOINT E**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - E: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(grep -cF -- '| 4 | GPT/ChatGPT | Web portal (external) | Comprehensive PR analysis |' Docs/development-process-guide.md)" = "0" || fail "5.1a old text still present"
test "$(grep -cF -- '| 4 | Claude (external review A) |' Docs/development-process-guide.md)" = "1" || fail "5.1a"
test "$(grep -cF -- '| 5 | Codex (external) | Web portal | Comprehensive PR analysis |' Docs/development-process-guide.md)" = "0" || fail "5.1b old text still present"
test "$(grep -cF -- '| 5 | Meta Muse, Spark or Wonder (external review B)' Docs/development-process-guide.md)" = "1" || fail "5.1b"
test "$(grep -cF -- 'Perplexity runs the structured three-turn review protocol as the final quality gate when MCP cooperates. When MCP fails, operator downloads the review output manually.' Docs/development-process-guide.md)" = "0" || fail "5.1c old text still present"
test "$(grep -cF -- 'No external reviewer comes from the coding agent'"'"'s vendor' Docs/development-process-guide.md)" = "1" || fail "5.1c"
test "$(grep -cF -- '| External Reviewers | [GPT, Codex, Perplexity — list which participated] |' prompts/phase7/consolidated-audit-template-phase7.md)" = "0" || fail "5.2 old text still present"
test "$(grep -cF -- '[A: Claude; B: Meta Muse (fallback: Gemini)' prompts/phase7/consolidated-audit-template-phase7.md)" = "1" || fail "5.2"
test "$(grep -cF -- 'The CI workflow (`.github/workflows/ci.yml`) only runs on changes to code, config, scripts, and build files. Documentation-only PRs, prompts, images, and tags do not trigger CI.' Docs/development-process-guide.md)" = "0" || fail "5.3a old text still present"
test "$(grep -cF -- 'on every pull request to `main`, documentation-only ones too: branch protection' Docs/development-process-guide.md)" = "1" || fail "5.3a"
test "$(grep -cF -- '3. **CI path filtering:** Submit a docs-only PR. If CI doesn'"'"'t trigger, path filtering is working.' Docs/development-process-guide.md)" = "0" || fail "5.3b old text still present"
test "$(grep -cF -- '3. **CI on pull requests:**' Docs/development-process-guide.md)" = "1" || fail "5.3b"
test "$(grep -cF -- '8) Apply every edit with your file-edit tool' Docs/development-process-guide.md)" = "1" || fail "5.4"
echo "CHECKPOINT E PASS"
)
```

### Task Group 6 — Operator guide, first page

**6.1** The operator has saved the page as `/root/r3b/R3b-restart-housekeeping.md`, and the setup block has checked its SHA-256. Create the directory `Docs/operator/` and copy the file byte for byte to `Docs/operator/R3b-restart-housekeeping.md` (`cp`, then `cmp`). Do not open it in an editor and do not reformat it.

### Task Group 7 — Housekeeping record (this step's consolidated audit)

**7.0** The setup block has made this prompt, verbatim, the first commit after the bootstrap commit, as `prompts/handoff/phase7/housekeeping-2026-11-14-restart-agent-prompt.md`. Confirm it with `git log --oneline -- prompts/handoff/phase7/housekeeping-2026-11-14-restart-agent-prompt.md`; if the file is missing, STOP.

**7.1** Create `prompts/handoff/phase7/housekeeping-2026-11-14-restart.md` with these eight sections, each under a heading line that begins `## §<number> `, in this order: §1 Why (documents and the tracker did not match the code after the pause from 2026-05-10; the method of record was bound first, in PR #234); §2 Edit list, one row per item 1.1a-6.1 with its verify command and observed output, quoting no old login line; §3 Review findings by severity (fill after the review round; name every reviewer that ran and state plainly when one did not complete); §4 Agent autonomous decisions (expected none); §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2; §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the §9 command block and the issue #228 status table below, both verbatim, with `<NN>` replaced by this PR's number; §8 Process metrics (the five numbers of HowTo v2 §5.6). For §8 the operator supplies two numbers: producer sessions 4 (first draft 2026-09-22; amendments 2026-11-05 and 2026-11-10; production, rehearsal and gate 2026-11-14) and audit sessions 0 (LOW tier: lint and one rehearsal inside the producer session). Take the other three from this PR.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-013 | Azure tier-2 ingest is the primary Phase 9 upload target | One upload path is all the S3 heap and the schedule allow, and the cost model needs real Azure traffic |
| PLAN-014 | Phase E after Phase 9 | Phase 8 needs only the credential pattern, which step 8.1 defines; step E-b waits for the Zigbee spike |
| PLAN-015 | v1.0 is v7.7.3.3; the partition change moves to v1.1 | The v7.7.1.4 prompt already defers the partition change, and the retention calculator reads the live partition size, so nothing in Phase 7 depends on it; this takes the only USB reflash off the v1.0 path |
| PLAN-016 | ESPHome stays at 2026.4.1 through v1.0 | An upgrade on top of a boot-path phase is the wrong time (STACK-001, LESSON-OPS-130) |
| PLAN-018 | Quality, functionality and security before speed; dates are indicative | Operator priority for the restart |
| PLAN-019 | External review A by Claude, B by a Meta Muse model, fallback Gemini on the web | With Codex as the coding agent, the former external reviewers (GPT and Codex) came from the coding agent's vendor; the method asks for different model families |
| PLAN-020 | CI runs on every pull request to `main`; the tooling PR makes the browser test's report visible | PR #234 was blocked: the required check never started on a documentation-only PR, and a manual run does not satisfy a required check. In the same PR the preflight browser test failed once and the script hid its report |
| PLAN-021 | Operator guide in `Docs/operator/`; the restart plan of record moves into `Docs/` | The plan lived in one long planning document outside the repository, with two kinds of reader; the repository becomes the source for both |
| BOARD-002 | Nine-board fleet | Three boards joined the USB hub since May 2026; the fleet table in `CURRENT-STATE.md` lists all nine |
```

Issue #228 status table for §7 of the record:
```
**Status as of 2026-11-14 — development resumed after the May pause**

| Track | Status | Notes |
|---|---|---|
| Audit reports | Merged in PR #227 | 4 independent audits |
| §B upstream-doc fixes (B1–B8) | Merged in PR #232 | |
| Detection guardrail (lint L1–L7 + CI) | Merged in PR #231 | |
| §A produced-doc fixes (A1–A11) + §B9 | Merged in PR #233 | 4 rounds |
| PR #233 third-audit findings (H-1/M-1/M-2/L-1) | Not applied to the May prompts | Inputs to the Batch 2 re-production (PLAN-017) |
| HowTo v2.3.1 bound as method of record | Merged in PR #234 | PLAN-012, PLAN-017 |
| Restart housekeeping | PR #<NN> | BUG-082 status, fleet table, login out of the files agents read, decision rows |
| §C meta-prompt guardrails | OPEN — one tooling PR with the items that PLAN-017 and PLAN-020 list | Runs before the Batch 2 re-production |
| §D phase-closure questions | DEFERRED — folded into the v7.7.3.3 closure prompt | |
| §E producer-prompt evolution | OPEN — producer contract and batch-production prompt v3.0 | v3.0 must be shorter than v2.0 (PLAN-012) |

**Dispatch state: the May Batch 2 prompts (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) are NOT dispatched. They are re-produced under the method of record first.**
```

⛔ **CHECKPOINT F**
```bash
(
fail() { echo "⛔ CHECKPOINT FAILED - F: $1"; exit 1; }
cd /root/config/ESP32-GW-multi-sensor || fail "repository path"
test "$(sha256sum < Docs/operator/R3b-restart-housekeeping.md | cut -d" " -f1)" = "2f3c3babeb06fb5511b321975c0ecac69443ed9122df73e0dee81d51858dd1f2" || fail "6.1 operator page differs from the supplied file"
test "$(ls prompts/handoff/phase7/housekeeping-2026-11-14-restart*.md | wc -l)" = "2" || fail "7.x expected 2 housekeeping files"
test "$(grep -c '^## §[1-8] ' prompts/handoff/phase7/housekeeping-2026-11-14-restart.md)" = "8" || fail "7.1 record sections"
test -z "$(grep -lE '<D[D]>|<S[0]' AGENTS.md README.md CURRENT-STATE.md .gitignore Docs/lessons/firmware.md Docs/decisions/decision-log.md Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md Docs/development-process-guide.md prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md prompts/handoff/phase7/session-handoff-v7.7.1.2.md prompts/handoff/phase7/session-handoff-v7.7.1.4.md prompts/phase7/consolidated-audit-template-phase7.md)" || fail "operator placeholder left in a modified file"
echo "CHECKPOINT F PASS"
)
```

### PRE-PR Gate

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
test "$(printf '%s\n' "$CHANGED" | grep -c .)" = "16" || fail "expected 16 changed paths"
test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION changed"
bash scripts/lint-prompts.sh --baseline origin/main prompts/phase7/consolidated-audit-template-phase7.md prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md prompts/handoff/phase7/session-handoff-v7.7.1.2.md prompts/handoff/phase7/session-handoff-v7.7.1.4.md prompts/handoff/phase7/housekeeping-2026-11-14-restart*.md || fail "lint"
bash scripts/preflight.sh || fail "preflight"
echo "PRE-PR PASS"
)
```

Known tooling defect: `scripts/preflight.sh` hides the browser test's report. If the block stops with `PRE-PR: preflight` and the last check printed before it is `mutex_single_owner: PASS`, the browser test failed. The operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; run `npx playwright test tests/browser/manifest.spec.js --project=chromium; echo "playwright exit $?"` and post its last 40 lines as a PR comment; if it prints `playwright exit 0`, run the PRE-PR block one more time, unchanged. If the diagnostic or the second run fails, STOP and report. Record the event in §5 of the record file. Any other failure of this block is a normal checkpoint failure: STOP.

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to F and the PRE-PR block each print PASS; their verbatim output is in the PR body
- [ ] Exactly the §3 files changed (13 modified + 3 new); no code, no generated file, no `VERSION` change
- [ ] No literal login in `AGENTS.md`, `CURRENT-STATE.md`, `Docs/development-process-guide.md` or the four Batch 2 files of Task Group 3, and none in the PR body or in any comment
- [ ] The GitHub checks `preflight-and-compile` and `prompt-lint` pass on the final head
- [ ] The record file is complete after the last review round and committed before merge
- [ ] PR title: `docs: restart housekeeping 2026-11 — BUG-082 status, fleet table, credentials, decision rows (refs #228)`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet. Device testing: N/A — documentation-only step; no deployment.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag. The operator runs this block after the merge; you run none of it. Copy it into §7 of the record file.

```
REPO=GCV-Sleeper-Service/ESP32-GW-multi-sensor
gh issue close 213 --repo $REPO -c "Shipped in PR #226 (v7.7.1.1, chunked history streaming). Closed after the fact: the PR body had no closing keyword."
gh issue close 203 --repo $REPO -c "Shipped in PR #225 (v7.7.1.0, health-check task). Socket counters stay tracked in #205."
gh issue close 196 --repo $REPO -c "Shipped in PR #202 (v7.6.10.4, authFetch refactor)."
gh issue close 209 --repo $REPO -c "Delivered by Docs/phase-7-review-and-rewrite.md (fd863eb, 2026-05-07)."
gh api -X PATCH repos/$REPO/issues/190 -F milestone=null --jq '"issue 190 milestone: \(.milestone)"'
gh issue edit 137 166 171 --repo $REPO --milestone "Phase 7 — Per-Device Persistence"
for m in 1 2 3 4; do
  n=$(gh api repos/$REPO/milestones/$m --jq .open_issues)
  if [ "$n" = "0" ]; then gh api -X PATCH repos/$REPO/milestones/$m -f state=closed --jq '"milestone \(.number) \(.state)"'
  else echo "milestone $m has $n open issues: not closed"; fi
done
```
