# Producer session — issue #228 §C + §D + §E coding-agent prompt

You are Claude Opus running an advisory prompt-producer session. Your output is a single coding-agent prompt that, when handed to a GitHub Copilot coding agent, will produce ONE PR closing §C, §D, and §E of issue #228 in `GCV-Sleeper-Service/ESP32-GW-multi-sensor`.

You do NOT write code or open PRs yourself. You produce the coding-agent prompt and stop.

## §1 Mandatory reading (in order)

1. **PR #233** (now merged) — full file diff and the four review rounds. Read each commit (`594ab88`, `8c13d59`, `7a539df`, `2692e74`) and the agent comments that summarize what each round fixed.
2. **The third-party audit report on PR #233** — operator will paste this report into the session as input. Treat its findings as the post-merge state. If it has CONDITIONAL PASS findings tagged "track in §C", fold them into §C as new sub-items.
3. **Issue #228** — current state, especially the §C / §D / §E sections. The §A and §B9 sections are now closed; do not re-touch them.
4. **`Docs/development-process-guide.md`** — full file. §C is meta-prompt evolution territory; §D is phase-end closure; §E is producer guidance.
5. **`prompts/handoff/phase7-batch-production-prompt-update.md`** — the canonical batch-production prompt. §E touches this file directly.
6. **`scripts/lint-prompts.sh`** and **`.github/workflows/prompt-lint.yml`** — the lint authority. §C13 (new — see §3 below) extends this script.
7. **`firmware/core/nvs-persistence.h`** — for the live `maybe_yield_nvs_scan_()` definition and the `vTaskDelay(pdMS_TO_TICKS(5))` value that §C13 lint will check against.
8. **GitHub Discussion #230** — hypothesis 4 ("every drift class ships with a lint rule"). §C13 is a direct application of this doctrine.
9. **The chat handoff notes for this session** — the operator will paste a short summary covering: (a) the Rule 61 delay-value drift defect (1ms vs 5ms) discovered during PR #233 review; (b) the PR #233 description-restoration incident (Codex agent wiped title and body during round-4); (c) the `preflight-and-compile` required-status-check deadlock and its workaround/fix options.
10. **`prompts/prompt-index-and-workflow.md`** — Critical Rules table.

## §2 Your goal

Produce ONE markdown file named `prompts/handoff/issue-228-CDE-coding-agent-prompt.md`. The operator will paste it into a fresh coding-agent session. The file MUST be self-contained per `Docs/development-process-guide.md` §3.3. Apparent length budget: 25,000–30,000 characters.

The coding-agent prompt you produce MUST:

1. Open ONE PR (one PR per logical work item is the standing rule, but §C, §D, §E are tightly coupled meta-prompt work that share the same producer audience and reviewer set; fold them).
2. Include all standard sections from the §A prompt template: §0 mandatory reading, §1 doctrinal precedence, §2 verification gates, §3 scope boundary (MAY / MUST NOT modify), §4 do-NOT list, §5 implementation per item, §6 acceptance criteria, §7 pipeline commands, §8 verification gate, §9 post-merge bookkeeping, §10 anti-patterns recap, operator constraints.

## §3 Items to fold into the coding-agent prompt

### §C — meta-prompt guardrails (drift-class lint rules)

For each existing §C row in issue #228 (C1–C12), keep their dispositions as the operator wrote them. Add **§C13** as a new row with this scope:

- **§C13 — `pdMS_TO_TICKS` delay-value drift detection (NEW lint rule L8).**
  - Defect class: a prompt that cites a `vTaskDelay(pdMS_TO_TICKS(N))` value that does not match the live value in the implementing helper (e.g., `firmware/core/nvs-persistence.h:248`).
  - Caught only by Codex P1 review on PR #233 (commit `594ab88`); the agent inherited the wrong value from my own (operator-acknowledged) round-1 prompt. This is exactly the "drift class ships with a lint rule" doctrine from Discussion #230 hypothesis 4.
  - Fix: extend `scripts/lint-prompts.sh` with rule **L8**: parse `firmware/core/nvs-persistence.h` for the canonical `maybe_yield_nvs_scan_()` `vTaskDelay(pdMS_TO_TICKS(<N>))` value, then grep `prompts/**` for any `pdMS_TO_TICKS(<M>)` line that mentions Rule 61 / NVS scan yield context and require `M == N`. Use a context window (e.g., ±3 lines) to avoid matching unrelated `pdMS_TO_TICKS` calls in different domains.
  - Update `.github/workflows/prompt-lint.yml` if any new fixture or input file is needed.
  - Add a unit test or a fixture in `tests/lint-prompts/` exercising L8 (one passing case, one failing case).
  - Update the lint-rule reference table in `Docs/multi-phase-session-run-instructions.md` §6 troubleshooting.

If the operator's audit report (input #2 above) recommends additional §C items, fold each as §C14, §C15, etc., one row each, with the same level of mechanical detail.

### §D — phase-end closure refinements

§D in issue #228 covers closure-prompt evolutions discovered during Phase 7. Without re-reading the issue body verbatim, you must:

1. Quote each §D item from the live issue body.
2. For each, write the implementation instruction inline in the coding-agent prompt (no cross-references).
3. The closure prompt template lives at `prompts/handoff/phase7-batch-production-prompt-update.md` "Final Batch: Phase Closure Deliverables" section AND any per-phase closure prompt currently in flight. Verify locations before writing instructions.

### §E — producer-side meta-prompt evolution

§E in issue #228 covers updates to `prompts/handoff/phase7-batch-production-prompt-update.md` itself — the prompt that produces the prompts. Quote each §E item and write inline instructions. Likely items (verify against the live issue body):

- New "Prompt Code Quality Gate" requiring producers to re-grep live signatures before embedding any function call in §6 code (the doctrine that, had it been in place, would have prevented A4).
- New "Doctrinal Value Pinning Gate" requiring any numeric constant cited in a prompt (delay value, byte size, board IP) to either reference a measurement procedure OR a live source file via grep.
- New "Self-containedness Gate" requiring §3 scope boundaries to be inlined verbatim (the doctrine that, had it been in place, would have prevented A6).
- New "PR Body Preservation" producer note: when an agent (especially Codex via the `chatgpt-codex-connector`) takes over a PR, the producer must include in §6 acceptance criteria a check that PR title and body have not been overwritten relative to the original problem statement. Reference the PR #233 incident.
- New "Path-filtered required check" producer note: when the producer sets up branch protection rules, required checks MUST NOT be path-filtered (or must use the `ci-required.yml` stub pattern). Reference the discussion of Options 1–3 from the PR #233 chat handoff.

If §E in the issue is broader, expand accordingly. Each §E sub-item must be a discrete, mechanically verifiable edit.

## §4 What the coding-agent prompt MUST require the agent to do

For traceability, list these acceptance criteria:

- [ ] Each §C / §D / §E sub-item maps to one or more concrete file edits with verify-column commands.
- [ ] `bash scripts/lint-prompts.sh --baseline main` exits 0; new EXISTING count not increased; zero new ERROR.
- [ ] If §C13 lint rule L8 is added, a passing fixture and a failing fixture exist under `tests/lint-prompts/`. The CI job runs both.
- [ ] PR title format: `prompts: issue #228 §C + §D + §E — meta-prompt guardrails, closure refinements, producer evolution`.
- [ ] PR body uses `Closes §C, §D, §E of #228; closes #228` (this is the final piece of #228).
- [ ] PR description has Pre-Implementation Verification block with verbatim verification outputs for any G-gates the producer prompt defines.
- [ ] PR description has Per-Item Verification block.
- [ ] PR description has the standard "Audit Gate Notice" block: "After this PR merges, the meta-prompt evolution is complete and Phase 7 implementation prompts (v7.7.1.2 / v7.7.1.3 / v7.7.1.4) can be dispatched. The §C lint rules will run on every future prompt PR going forward."
- [ ] If any item discovered during production cannot be implemented in this PR (e.g., needs operator decision), document it as a follow-up issue and link from the PR description.

## §5 Producer constraints

- Do not invent §C / §D / §E sub-items beyond what the live issue body and the audit report list. If both sources are silent on something you think should be there, raise it as an open question in your output (separate from the agent prompt itself), not as an additional sub-item.
- Do not edit the issue body, only consume it as input.
- Do not exceed 30,000 characters in the agent prompt body. If you reach that limit, summarize the §0 mandatory reading list and inline less verbatim content from doctrinal sources, citing them by path instead.
- Do not skip the Rule 61 / L8 lint rule even if the audit report does not explicitly call for it. The operator has flagged it as a known gap and it must be in §C13.
- Use the same prompt structure I used for the §A + §B9 prompt: tables for items, verify columns, explicit do-NOT list, anti-patterns recap. Self-containedness is the standing rule.
- Confirm you read input #9 (chat handoff notes) before writing §E producer notes.

## §6 Output format

Output exactly two artifacts in this order:

1. **The coding-agent prompt itself** as a single fenced markdown block titled `issue-228-CDE-coding-agent-prompt.md`. The operator will paste this verbatim into the coding-agent session.
2. **A short producer note** (≤ 1000 characters) listing: (a) any §C / §D / §E items you could not fully specify and why, (b) any operator decisions required before dispatch, (c) any lint-rule edge cases worth raising before the agent starts.

Stop after these two artifacts. Do not also produce a "next steps" or "verification" section in your own voice; the coding-agent prompt itself contains those.

End of producer session prompt.