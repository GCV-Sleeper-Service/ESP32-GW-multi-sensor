# Third Independent Audit — PR #233 (issue #228 §A + §B9)

You are an independent auditor. A separate Claude Sonnet session produced a prompt to fix issue #228 §A and §B9 in the GitHub repository `GCV-Sleeper-Service/ESP32-GW-multi-sensor`. A coding agent then produced PR #233, which underwent four rounds of fixes (commits `594ab88`, `8c13d59`, `7a539df`, `2692e74`). The owner intends to merge this PR and dispatch implementation prompts v7.7.1.2 / v7.7.1.3 / v7.7.1.4 to a coding agent on the basis of your audit.

**Your job:** confirm zero remaining HIGH-severity defects in the merged state of PR #233. The PR is the gate; if you find HIGH-severity defects, the implementation prompts CANNOT be dispatched until they are fixed.

## §1 Inputs to read (in order)

1. The merged PR #233 file diff: `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/233/files` — review every file change at the final commit (`2692e74` or merge commit, whichever is current).
2. Issue #228 acceptance criteria for §A and §B9 specifically. Ignore §C / §D / §E for this audit.
3. The original audit reports that drove §A:
   - `prompts/handoff/phase7/new-prompts-audit-report-Copilot.md`
   - `prompts/handoff/phase7/new-prompts-audit-report-Opus4.7.md`
   - `prompts/handoff/phase7/phase7-batch2-prompt-audit-report-GPT.md`
4. The five files PR #233 modified for §A:
   - `prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md`
   - `prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md`
   - `prompts/phase7/v7.7.1.4-agent-prompt-gpt-codex.md`
   - `prompts/phase7/v7.7.1.3-claude-two-step.md`
   - `prompts/handoff/phase7/session-handoff-v7.7.1.3.md`
5. The four files PR #233 modified for §B9:
   - `CURRENT-STATE.md` (footer line ~129)
   - `prompts/prompt-index-and-workflow.md` (line ~71)
   - `prompts/phase7/consolidated-audit-template-phase7.md` (~line 104)
   - `prompts/phase7/phase7-review-prompts-perplexity.md` (top banner)
6. Live source-of-truth files referenced by the prompts:
   - `firmware/core/nvs-persistence.h` — for `find_partition_size_bytes_()` 3-arg signature, `maybe_yield_nvs_scan_()` body, `vTaskDelay(pdMS_TO_TICKS(5))` value, `restore_from_nvs()` location.
   - `CURRENT-STATE.md` Board Fleet table — for `.189` (C3), `.170` (WROOM-32D), `.191` (S3 N16R8).
   - `prompts/handoff/phase7-batch-production-prompt-update.md` "Scope-guard whitelist" section (around L213-233) — for the canonical `bump-version.sh` whitelist.
7. Doctrinal sources:
   - `Docs/development-process-guide.md` §2.5 (in-PR mandatory deliverables).
   - `Docs/writing-guide/methodology.md` §3.10, §4.3.
8. The PR review thread (all 4 reviews) and inline comments. The two coding-agent comments at the end of the thread (one from Copilot, one from Codex) summarize what each round fixed.

## §2 Required checks (HIGH-severity gate)

For each item, run the listed verification command (or its read-equivalent) against the final commit. Pass = ✅, Fail = ❌ with citation.

### §2.A — Doctrinal compliance (§A1–A11, §B9.1–B9.4)

| Check | Pass condition |
|---|---|
| A1 | v7.7.1.3 prompt §6 Task Group 3 has both **C3 .189** AND **WROOM-32D .170** device-test blocks. |
| A2 | v7.7.1.4 prompt §6 (boot-path Task Group) has both production satellites + an explicit cross-SoC-family note. |
| A3 | `bump-version.sh` is **Step 0** in §6 of v7.7.1.3 AND v7.7.1.4 — line number of bump < line number of first `esphome compile`. |
| A4 | Every embedded call to `find_partition_size_bytes_()` in v7.7.1.4 uses the **3-arg** form `(label, type, subtype)`. The §2 verification gate has a checkpoint that re-greps the live header. |
| A5 | All three `static_assert(sizeof(X) == N, …)` lines in v7.7.1.2 are in the **commented-out 2-phase form**. The §2 measurement procedure has 6 ordered steps and explicitly says "Phase 1: leave commented out", "Phase 2: uncomment with measured value substituted". A cross-board ABI note is present at step 5. |
| A6 | v7.7.1.4 §3 contains the full inlined whitelist (no cross-reference like "see v7.7.1.2 §3"). The list matches the canonical "Scope-guard whitelist" in `prompts/handoff/phase7-batch-production-prompt-update.md` byte-for-byte (6 source bullets + 6 regenerated-artifact bullets). |
| A7 | `session-handoff-v7.7.1.3.md` has ≥ 8 top-level (`## `) sections matching the depth of v7.7.1.2 / v7.7.1.4 handoffs. Risk Profile is present and lists ≥ 3 risks with mitigations. |
| A8 | Checkpoint A grep in v7.7.1.2 uses `^static constexpr` to count definitions only. |
| A9 | PERFORMANCE-ACK in v7.7.1.4 lists concrete call sites by **function name** (not line number) and warns that the helper "MUST remain off the HTTP request path". No unverified timing numbers ("< 1 ms", "<< 1 ms total") remain. |
| A10 | v7.7.1.3-claude-two-step.md cites `vTaskDelay(pdMS_TO_TICKS(5))` (NOT `(1)`) and references BUG-043 rev2 / `firmware/core/nvs-persistence.h:248`. |
| A11 | Reviewer checklist includes the `bash scripts/provision.sh status` pre-flash verification step. |
| B9.1 | `CURRENT-STATE.md` footer no longer contains `post-merge deliverable` (the in-PR reframing per `Docs/development-process-guide.md §2.5` is present). |
| B9.2 | `prompts/prompt-index-and-workflow.md` line ~71 is reframed to in-PR. The PR description must call out any remaining `post-merge` hits and justify each one (the project considers L347 "not a post-merge deliverable" and L432 historical revision-log entries acceptable). Verify each remaining hit is genuinely intentional. |
| B9.3 | `consolidated-audit-template-phase7.md` device-results section is reframed as in-PR; WROOM IP shows `.170` not `.190`. |
| B9.4 | `phase7-review-prompts-perplexity.md` has a HISTORICAL banner at the top OR the body has been fully reframed to in-PR. |

### §2.B — Cross-cutting integrity checks

| Check | Pass condition |
|---|---|
| C1 — Rule 61 delay value | All `pdMS_TO_TICKS(N)` references in `prompts/**` that pertain to Rule 61 use `N=5`, matching `firmware/core/nvs-persistence.h:248`. Zero hits of `pdMS_TO_TICKS(1)`. |
| C2 — board IPs | Zero `192.168.120.190` references in any modified file. All WROOM references use `.170`. |
| C3 — YAML filename | Zero `esp32-wroom-32d-multi-sensor.yaml` references. All WROOM-32D YAML references use `esp32-wroom-32d-gw.yaml`. |
| C4 — pipeline order | Zero instances of `assemble-sensor-history.sh --check` ordered before `--write` in any modified file. |
| C5 — `esphome run` | Zero `esphome run` references; all use `timeout 300 esphome upload <yaml> --device=<ip>`. |
| C6 — curl timeouts | All `curl -s` lines targeting board IPs in §6 device-test blocks include `--connect-timeout 5 --max-time 10`. |
| C7 — self-containedness | No cross-prompt scope references like "see v7.7.1.2 §3" or "see other prompt" in any modified §3. |
| C8 — static_assert form | No narrative `// sizeof(X) = N bytes` comments in v7.7.1.2 (replaced by static_assert form). |
| C9 — lint baseline | `bash scripts/lint-prompts.sh --baseline main` exits 0; no new ERROR; EXISTING count not increased over PR base. |

### §2.C — Hot-take quality concerns (your independent inspection)

This is where you add value beyond the mechanical checks. Look for issues no prior reviewer caught:

1. **Coherence:** Read each modified prompt end-to-end. Does the §6 Task Group ordering still make sense after `bump-version.sh` was moved to Step 0? Are step renumberings consistent throughout?
2. **Unverified factual claims:** Search for any embedded code or commentary that asserts a number (size, timing, count, line number) without a measurement procedure or a citation to a live file.
3. **Cross-prompt consistency:** v7.7.1.2 and v7.7.1.4 both touch `nvs-persistence.h`. Are their assumptions about each other's deliverables (e.g., "structs from v7.7.1.2 with sizes verified") consistent?
4. **Non-idempotent procedures:** The §2 measurement checkpoint in v7.7.1.2 instructs adding a SIZING log line, then removing it. If the agent re-runs the procedure, will the prompt still be coherent? Are there other procedures that assume single-pass execution?
5. **Doctrinal drift not caught by lint:** Are there subtle violations of `Docs/development-process-guide.md` §2.5 not covered by the lint rules? Especially around "in-PR" framing of items the prompts implicitly defer.
6. **Rule 61 lint gap:** The Rule 61 delay value drift was caught by a Codex P1 review, NOT by any automated check. Should there be a lint rule? (Answer: yes — this is the intended §C13 / lint rule L8 follow-up. Note this in your report so the operator can confirm it is captured.)
7. **N3 verification:** I claim the inlined whitelist in v7.7.1.4 §3 matches the canonical source. Verify this **byte-for-byte** by quoting both lists in your report. If you find a single bullet difference, that is a HIGH finding.

## §3 Output format

Produce a single Markdown report titled "PR #233 third-party audit — <auditor name> — <date>". Required sections:

1. **Verdict** — one of: **PASS** (zero HIGH findings; merge and dispatch); **CONDITIONAL PASS** (only LOW/MEDIUM findings; merge but track findings as follow-up issues); **FAIL** (≥ 1 HIGH finding; do NOT merge until fixed).
2. **Summary table** — one row per check from §2.A, §2.B, §2.C with PASS/FAIL/N/A and one-sentence note.
3. **HIGH findings** — for each, cite the file path and line number, quote the offending content, explain why it is HIGH, and propose a concrete fix.
4. **MEDIUM/LOW findings** — same structure, lower bar.
5. **Cross-audit reconciliation** — if you have access to other auditors' reports, list disagreements and your verdict on each.
6. **Disposition recommendation** — for each finding: (a) fix in this PR before merge, (b) merge and track as follow-up issue under #228 §C, (c) merge and accept as-is. The operator will follow your disposition unless they have a concrete reason to override.
7. **Confidence statement** — your confidence that the implementation agents (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) can execute these prompts to merge without re-discovering defects you missed.

## §4 Constraints

- Do not invent file contents, function signatures, or line numbers. If a tool you have access to cannot retrieve the file, say so and mark the related check as "unable to verify".
- Do not propose new functionality. The audit is about whether PR #233 correctly fixes #228 §A and §B9, not about expanding scope.
- Quote verbatim when claiming a defect — do not paraphrase the alleged offending content.
- If you would change the verdict based on a single check that you cannot verify, say so and recommend the operator manually verify that one check before merging.

## §5 Out of scope for this audit

- Issue #228 §C, §D, §E (separate session).
- The `preflight-and-compile` required-status-check deadlock (operator infrastructure issue).
- The Rule 61 lint rule (L8) itself — note its absence as a finding for §C, but do not block the merge on it. The intent is to add it as §C13 in the next session.
- Phase 7 implementation correctness of v7.7.1.2 / v7.7.1.3 / v7.7.1.4 themselves — those will be audited by their own coding-agent dispatches.

End of audit prompt.