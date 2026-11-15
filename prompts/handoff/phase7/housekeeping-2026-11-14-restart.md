# Restart housekeeping — PR #235

## §1 Why

Documents and the tracker did not match the code after the pause from 2026-05-10. The method of record was bound first, in PR #234. This documentation-only step corrects BUG-082 status, records the nine-board fleet and operator decisions, removes the management login from the seven named agent-read files, and records remaining work without changing firmware or deploying.

The supplied files passed their SHA-256 checks. Empty bootstrap `6034667` was followed immediately by `915e0e1`, which contains only the byte-for-byte supplied prompt. `cmp` exited 0 with no output. The branch is `docs/restart-housekeeping-2026-11` throughout.

## §2 Edit list

Each count below is the observed result of the corresponding unchanged gate check. CHECKPOINT A covers items 1.x; B covers 2.x; C covers 3.x; D covers 4.1; E covers 5.x. Item 6.1 uses the supplied-file comparison.

| Item | Verify command | Observed output |
|---|---|---|
| 1.1a | `grep -cF -- 'RESOLVED in v7.7.1.1' AGENTS.md` | `1` |
| 1.1b | `grep -cF -- 'Never build a full CSV response in RAM.' AGENTS.md` | `1`; old text count `0` |
| 1.2a | `grep -cF -- '9 firmware C++ fragments' AGENTS.md` | `1`; old count `0` |
| 1.2b | `grep -cF -- '(9 fragments)' AGENTS.md` | `1`; old count `0` |
| 1.2c | `grep -cF -- '├── health-check.h' AGENTS.md` | `1` |
| 1.3 | `grep -cF -- '**Resolution:** Fixed in v7.7.1.1 (PR #226, 2026-05-08)' Docs/lessons/firmware.md` | `1`; old text count `0` |
| 1.4a | `grep -cF -- 'Current version: v7.7.1.1' README.md` | `1`; old text count `0` |
| 1.4b | `grep -cF -- '--device=<board-ip>' README.md` | `1`; old command count `0` |
| 2.1 | `grep -cF -- '_Last verified: 2026-11-14 — restart re-verification' CURRENT-STATE.md` | `1`; old text count `0` |
| 2.2 | `grep -cF -- '_Next action: the restart plan of record' CURRENT-STATE.md` | `1`; old text count `0` |
| 2.3 | `grep -cF -- '- **Development paused:**' CURRENT-STATE.md` | `1` |
| 2.4 | `grep -cF -- '\| WROOM heap \| Medium \|' CURRENT-STATE.md` | `1`; old A-004 row count `0` |
| 2.5 | `grep -cF -- '\| sat-c5-8m-181 \|' CURRENT-STATE.md` | `1` |
| 2.6 | ``grep -cF -- 'Credentials: `$ESP_USER`' CURRENT-STATE.md`` | `1` |
| 2.7 | `grep -cF -- 'routed to the tooling PR (PLAN-020)' CURRENT-STATE.md` | `1` |
| 2.8 | `grep -cF -- '**Superseded, not to be dispatched** (PLAN-017)' CURRENT-STATE.md` | `1` |
| 3.1a | `grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' AGENTS.md` | `1` |
| 3.1b | `grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' Docs/development-process-guide.md` | `1` |
| 3.1c | `grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` | `1` |
| 3.1d | `grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.170/api/status/full' prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md` | `1` |
| 3.1e | `grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.189/api/status/full' prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | `1` |
| 3.1f | `grep -cF -- '-u "$ESP_USER:$ESP_PASS" http://192.168.120.170/api/status/full' prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md` | `1` |
| 3.2a | ``grep -cF -- 'Credentials: `$ESP_USER`' prompts/handoff/phase7/session-handoff-v7.7.1.2.md`` | `1` |
| 3.2b | ``grep -cF -- 'Credentials: `$ESP_USER`' prompts/handoff/phase7/session-handoff-v7.7.1.4.md`` | `1` |
| 3.3 | `grep -cF -- '- Credentials come only from the operator' AGENTS.md` | `1` |
| 3.4a | ``grep -cF -- '\| `/history/` \| GET \| ❌ Public since v7.6.9.0 (`0a4b0d1`), SEC-002 \| RV-04 \|' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`` | `1`; old row count `0` |
| 3.4b | ``grep -cF -- '\| `/api/v2/history/` \| GET \| ❌ Public since v7.6.9.0 (`0a4b0d1`), SEC-002 \| RV-04 \|' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`` | `1`; old row count `0` |
| 3.4c | `grep -cF -- '\| RV-09 Native OTA without a password \|' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` | `1` |
| 3.4d | `grep -cF -- '## Amendment 2026-11 (restart)' Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` | `1` |
| 3.5 | `grep -cF -- 'config/fleet.local.csv' .gitignore`; `git check-ignore -q config/fleet.local.csv` | `1`; exit `0`, no output |
| 4.1 | `grep -cF -- '\| SEC-003 \|' Docs/decisions/decision-log.md`; `grep -c '^_Updated: 2026-11-14_$' Docs/decisions/decision-log.md`; `grep -c '^\| ' Docs/decisions/decision-log.md` | `1`; `1`; `45` (12 new rows also verified by CHECKPOINT D) |
| 5.1a | `grep -cF -- '\| 4 \| Claude (external review A) \|' Docs/development-process-guide.md` | `1`; old row count `0` |
| 5.1b | `grep -cF -- '\| 5 \| Meta Muse, Spark or Wonder (external review B)' Docs/development-process-guide.md` | `1`; old row count `0` |
| 5.1c | `grep -cF -- 'No external reviewer comes from the coding agent'"'"'s vendor' Docs/development-process-guide.md` | `1`; old paragraph count `0` |
| 5.2 | `grep -cF -- '[A: Claude; B: Meta Muse (fallback: Gemini)' prompts/phase7/consolidated-audit-template-phase7.md` | `1`; old row count `0` |
| 5.3a | ``grep -cF -- 'on every pull request to `main`, documentation-only ones too: branch protection' Docs/development-process-guide.md`` | `1`; old text count `0` |
| 5.3b | `grep -cF -- '3. **CI on pull requests:**' Docs/development-process-guide.md` | `1`; old text count `0` |
| 5.4 | `grep -cF -- '8) Apply every edit with your file-edit tool' Docs/development-process-guide.md` | `1` |
| 6.1 | `cmp /root/r3b/R3b-restart-housekeeping.md Docs/operator/R3b-restart-housekeeping.md` | Exit `0`, no output |

Verbatim output from §2 and CHECKPOINTS A–F:

```text
§2 PASS
CHECKPOINT A PASS
CHECKPOINT B PASS
CHECKPOINT C PASS
CHECKPOINT D PASS
CHECKPOINT E PASS
CHECKPOINT F PASS
```

The unchanged PRE-PR block completed with exit 0: exactly 16 scoped paths, VERSION 7.7.1.1, prompt lint with zero violations, preflight and its browser test all passed. Its final output was:

```text
playwright_manifest_spec: PASS
PRE-PR PASS
```

The PR body contains the full verbatim PRE-PR output. No concurrent test command or mock server was started. The known diagnostic exception was not needed. `cmp` confirms both supplied files remain byte-for-byte identical.

## §3 Review findings by severity

No independent PR review has completed at the time of this record. The GitHub reviews query returned an empty list. Copilot, Codex inline and Gemini inline have not completed; Claude and Meta Muse/Gemini external reviews have not run. No approval or waiver is inferred. This section and the review-dependent metrics must be updated and committed after the last review round, before merge.

| Severity | Findings |
|---|---|
| Blocking / High / Medium / Low / Cosmetic | None reported yet; independent reviews are pending. |

The coding agent checked the prescribed edit scope and completed each task group before its checkpoint. Superseded May prompts receive only the specified login-line changes. Remaining recommendations are routed in `CURRENT-STATE.md`: WROOM export acceptance evidence to v7.7.3.3; OTA size checks to Batch 2 re-production; README counts to the closure rewrite; deterministic header compression to a separate code PR; browser-report visibility to the tooling PR; issue #228 §D to closure. Secret rotation remains v7.7.1.5; no deployment or issue bookkeeping was performed here.

## §4 Agent autonomous decisions

None in implementation scope or operator decisions. Execution repairs: the first checksum invocation used a login shell that changed directories; it was repeated with the explicit supplied `cd`, and both files printed OK. A patch for item 1.3 initially expected a whole line instead of the quoted substring; it was reapplied with the existing paragraph suffix preserved before CHECKPOINT A. Bootstrap safety provisioning changed the generated header's gzip metadata; that agent-created side effect was restored before §2. No checkpoint ran with a missing preceding edit.

## §5 Prompt Quality Score

```text
Prompt Quality Score:
- Fix cycles: 0
- Checkpoint saves: 0
- Preventable review findings: 0 (no independent review completed yet)
- Agent autonomous decisions: 0 (helpful 0 / harmful 0 / neutral 0)
```

The prompt's anchors and gates supported the prescribed documentation changes. The command and patch invocation repairs above are execution errors, not prompt defects. Review-dependent values remain provisional until the last review round. The known browser-report diagnostic exception has not been used.

## §6 Operator decisions recorded by this PR

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

## §7 Operator bookkeeping

This step has no tag. The operator runs this block after merge; the coding agent runs none of it.

```bash
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

**Status as of 2026-11-14 — development resumed after the May pause**

| Track | Status | Notes |
|---|---|---|
| Audit reports | Merged in PR #227 | 4 independent audits |
| §B upstream-doc fixes (B1–B8) | Merged in PR #232 | |
| Detection guardrail (lint L1–L7 + CI) | Merged in PR #231 | |
| §A produced-doc fixes (A1–A11) + §B9 | Merged in PR #233 | 4 rounds |
| PR #233 third-audit findings (H-1/M-1/M-2/L-1) | Not applied to the May prompts | Inputs to the Batch 2 re-production (PLAN-017) |
| HowTo v2.3.1 bound as method of record | Merged in PR #234 | PLAN-012, PLAN-017 |
| Restart housekeeping | PR #235 | BUG-082 status, fleet table, login out of the files agents read, decision rows |
| §C meta-prompt guardrails | OPEN — one tooling PR with the items that PLAN-017 and PLAN-020 list | Runs before the Batch 2 re-production |
| §D phase-closure questions | DEFERRED — folded into the v7.7.3.3 closure prompt | |
| §E producer-prompt evolution | OPEN — producer contract and batch-production prompt v3.0 | v3.0 must be shorter than v2.0 (PLAN-012) |

**Dispatch state: the May Batch 2 prompts (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) are NOT dispatched. They are re-produced under the method of record first.**

## §8 Process metrics

| Metric | Value | Evidence |
|---|---|---|
| Producer sessions for this step's prompt | 4 | Operator supplied: first draft 2026-09-22; amendments 2026-11-05 and 2026-11-10; production, rehearsal and gate 2026-11-14. |
| Audit sessions for this step's prompt | 0 | Operator supplied: LOW tier, lint and one rehearsal inside the producer session. |
| Fix-cycle commits after the first review round | 0 | No independent PR review has completed. |
| Defects that escaped the prompt gates into agent execution | 0 | No prompt defect identified; invocation repairs are execution errors. |
| Defects that escaped to devices | 0 | Documentation-only step; no device deployment. |

The final three values come from this PR and must reflect its last review round before merge. Device testing: N/A — documentation-only step; no deployment. VERSION remains 7.7.1.1.
