# Phase VX — Perplexity PR Review Prompt (Three-Turn)

_Use this template for Perplexity three-turn PR review of Phase VX PRs._
_Reference: `prompts/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md` for methodology._

---

## Turn 1 — Context

```
I need you to review a PR for the ESP32-GW multi-sensor gateway project.

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
PR: #[NN]
Branch: [branch-name]
Step: v7.6.10.[X] — [Step Title]

Phase VX is an infrastructure sprint (board onboarding, ESPHome upgrade, measurement).
No firmware logic changes, no NVS changes, no dashboard feature changes.

Please read the PR diff and the agent's Instruction Compliance Output table.
```

## Turn 2 — Review Focus

```
Review this PR against the two-step prompt's Step 2 checklist:
prompts/phaseVX/v7.6.10.[X]-claude-two-step.md → Step 2

Focus areas:
1. Scope discipline — did the agent stay within the defined scope?
2. Critical Rule compliance — especially Rules 38 (ota_0), 42 (external_components), 63 (session log)
3. For v7.6.10.0: patch verified? Stack value 16384? All boards compile?
4. For v7.6.10.1: board profiles schema correct? Partition tables valid? SRAM_KB_BY_CHIP updated?
5. Any autonomous decisions not in the prompt?

Use the agent's compliance table as substitute for shell verification.
```

## Turn 3 — Verdict

```
Based on your review:
1. APPROVE or REQUEST CHANGES
2. List any blocking issues (must fix before merge)
3. List any non-blocking observations (can fix in later step)
4. Confirm the step's acceptance criteria are met per the compliance table
```

---

_End of Perplexity review prompt template._
