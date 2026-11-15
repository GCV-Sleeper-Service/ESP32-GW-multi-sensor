# Restart housekeeping — PR #235

## §1 Why

Documents and the tracker did not match the code after the pause from 2026-05-10. The method of record was bound first, in PR #234. This documentation-only step corrects BUG-082 status, records the nine-board fleet and operator decisions, removes the management login from the seven named agent-read files, and records remaining work without changing firmware or deploying.

The supplied files passed their SHA-256 checks. Empty bootstrap `6034667` was followed immediately by `915e0e1`, which contains only the byte-for-byte supplied prompt. `cmp` exited 0 with no output. The branch is `docs/restart-housekeeping-2026-11` throughout.

## §2 Edit list

Each count below records the original implementation at `ce6495d`, before review fixes. CHECKPOINT A covers items 1.x; B covers 2.x; C covers 3.x; D covers 4.1; E covers 5.x. Item 6.1 records the original supplied-file comparison. The review-authorized changes and current hashes are recorded in §3; historical checks are not claims that the amended operator page still equals the supplied file.

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

The PR body contains the full verbatim original PRE-PR output. No concurrent test command or mock server was started. The known diagnostic exception was not needed. At `ce6495d`, `cmp` confirmed both supplied files were byte-for-byte identical. The agent prompt remains identical; the operator page is amended in the review round below.

## §3 Review findings by severity

Round 2 assesses the reviews on `ce6495d`, following the operator's explicit request to assess findings and implement warranted fixes. Codex completed code review with no findings ([summary](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/235#issuecomment-6891925562)). Gemini completed its inline review with one finding ([review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/235#pullrequestreview-5910002781)). Copilot supplied one finding but explicitly could not complete the selected review tier because of model policy or plan restrictions ([limited review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/235#pullrequestreview-5909924837)); this is not a completed full Copilot review. Meta Muse (Spark) supplied external review B through the operator, comment-only and explicitly not an approval ([review](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/235#pullrequestreview-5909986144)). Claude external review A and a separate Gemini external fallback have not run. No approval or waiver is inferred, and these reviews do not constitute review of the follow-up commit.

| Severity | Finding and disposition |
|---|---|
| Blocking | None reported. |
| High | [Copilot: password in process argv](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/235#discussion_r4577731024). Warranted: shell expansion passes the value to `git grep` as an argument. Replaced the operator example with an in-process Python byte search of the seven named files. It reads the environment internally, starts no child process, writes nothing, fails on unset/empty input or file-read errors, and prints only matching paths or an explicit clean result. The scan no longer implies that broad historical prompt directories were scrubbed. |
| Medium | [Gemini: RV-04 still appears in the history coverage rows](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/235#discussion_r4577790014). Warranted documentation inconsistency. Added an authoritative restart-amendment paragraph stating RV-04 was resolved in v7.7.1.1 and superseding its older narrative/target. The prescribed coverage rows retain the identifier for historical traceability. Routed the older narrative/target cleanup to v7.7.1.5 in `CURRENT-STATE.md`, preserving the original prompt and CHECKPOINT C assertions. |
| Low | Muse item 1, credential-scope overstatement. Warranted. SEC-003 and RV-08 now distinguish the secret-handling policy from the actual seven-file cleanup. Live-script cleanup and board-secret rotation remain pending for v7.7.1.5; historical records and git history retain old values. No scripts were changed. |
| Low | Muse item 2, incomplete test-count reconciliation. Warranted. Expanded the existing v7.7.3.3 recommendation to reconcile README (402/117), `AGENTS.md` (~370) and `CURRENT-STATE.md` (~370+) with the same Playwright listing. No test count is guessed here. |
| Process deliverable | Muse's request to record every review and update §3/§5/§8 before merge is warranted and implemented by this record update. Producer/audit session counts remain operator-supplied; PR fix/defect counts below now reflect this review round. |

The seven cleaned files are:

- `AGENTS.md`
- `CURRENT-STATE.md`
- `Docs/development-process-guide.md`
- `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md`
- `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`
- `prompts/handoff/phase7/session-handoff-v7.7.1.2.md`
- `prompts/handoff/phase7/session-handoff-v7.7.1.4.md`

Remaining live-script authentication references were verified without printing values: `scripts/stress-test-httpd-stack.sh:52`, `scripts/device-test-v7.6.0.1.sh:346`, `scripts/device-test-v7.6.0.2.sh:24-25`, and `scripts/device-test-v7.6.0.3.sh:26-27`. The v7.6.0.1 script uses an inline auth reference rather than the assignments described by the reviewer; the scope concern still holds. No live script or board was exercised.

All 15 rehearsal hashes matched before this round. The operator's follow-up request authorizes the necessary documentation fixes, including amendment of the supplied page after its original byte-for-byte copy. Four rehearsal-hashed files now deliberately differ; the fifth changed file is this review record, which has no supplied expected hash. Current SHA-256 values for the four amended artifacts:

```text
aabab895e84ae30d97ed0fa0d5c905028246650693781138296f875451e70889  CURRENT-STATE.md
37e9ab6d886511c08ba89d25b3157593935388ee82f0cf291b689e7b3027cd41  Docs/decisions/decision-log.md
d6b383dad27f47b235a6598104064720025a985621310d04aa9a970d32d8926c  Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md
1f4176a7f425bafe34ba8b0a0fb832804f8f8a790b4b3eae5addb4b25e9e6927  Docs/operator/R3b-restart-housekeeping.md
```

The supplied prompt, its SHA-256, and all checkpoint commands/expected values remain unchanged. CHECKPOINT F's supplied-page equality is original-copy evidence; it is not redefined or claimed for the reviewed page. The original §2 pre-edit gate is likewise historical. The PR title and body are preserved; the follow-up assessment is posted as a new PR comment.

Validation of the documented credential check used synthetic values only:

```text
operator_credential_check: PASS (11 synthetic cases; no real login used)
operator_credential_argv_and_output: PASS (value absent from argv/output; no child commands or writes in snippet)
```

The cases cover unset/empty input, a clean seven-file set with an out-of-scope match, one match in each file, and a missing required file. The original prompt still passes `cmp`; `git diff --check` exits 0. The unchanged PRE-PR block then passed with exactly 16 scoped paths, VERSION 7.7.1.1, zero prompt-lint violations, preflight and the Playwright manifest spec. No other preflight, Playwright run or mock server was active; no diagnostic retry was needed.

```text
lint-prompts: checking 7 file(s) (baseline: origin/main)
lint-prompts: OK — 0 violations
playwright_manifest_spec: PASS
PRE-PR PASS
```

Other recommendations remain routed in `CURRENT-STATE.md`: WROOM export evidence and documentation test counts to v7.7.3.3; OTA size checks to Batch 2 re-production; deterministic header compression to a separate code PR; browser-report visibility to the tooling PR; issue #228 §D to closure. No deployment, issue, milestone or merge action was performed.

## §4 Agent autonomous decisions

None in implementation scope or operator decisions. Execution repairs: the first checksum invocation used a login shell that changed directories; it was repeated with the explicit supplied `cd`, and both files printed OK. A patch for item 1.3 initially expected a whole line instead of the quoted substring; it was reapplied with the existing paragraph suffix preserved before CHECKPOINT A. Bootstrap safety provisioning changed the generated header's gzip metadata; that agent-created side effect was restored before §2. No checkpoint ran with a missing preceding edit.

## §5 Prompt Quality Score

```text
Prompt Quality Score:
- Fix cycles: 1
- Checkpoint saves: 0
- Preventable review findings: 4
- Agent autonomous decisions: 0 (helpful 0 / harmful 0 / neutral 0)
```

The prompt's anchors supported the original edit execution, but its gates did not catch the supplied operator command's argv exposure, the credential-scope overstatement, the incomplete test-count routing or the stale RV-04 status. These four findings are counted as preventable prompt gaps, including the documentation cleanup now routed to v7.7.1.5. The pre-implementation invocation repairs in §4 remain execution errors. One follow-up commit addresses the review round; later rounds must update these counts before merge. The known browser-report diagnostic exception has not been used.

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
| Fix-cycle commits after the first review round | 1 | One follow-up commit records/disposes of Copilot, Muse and Gemini findings and Codex's no-findings review. |
| Defects that escaped the prompt gates into agent execution | 4 | Password-in-argv example; credential-scope overstatement; incomplete test-count routing; stale RV-04 status. |
| Defects that escaped to devices | 0 | Documentation-only step; no device deployment. |

The final three values come from this PR and must reflect its last review round before merge. Device testing: N/A — documentation-only step; no deployment. VERSION remains 7.7.1.1.
