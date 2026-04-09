# Phase Y Prompt Optimization for Codex (sub/agents-worker)

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor  
Date: 2026-04-09

## Executive answer

## 1) Are the original prompts optimal for Codex resources?

Short answer: **No**.

The original two-session prompts are high-quality for rigor, but not optimal for Codex context efficiency because they:

1. Require large up-front reads in the **main session** (handoff + implementation + required reading lists), even when much of that can be delegated and summarized.
2. Repeat many instructions across steps instead of using compact reusable execution contracts.
3. Mix immutable policy/rules with per-step deltas, forcing re-ingestion each session.
4. Are review-heavy in one session without explicit worker delegation patterns.

The Copilot-optimized review file improves review flow by introducing deep research, but for Codex it is still verbose and still keeps per-step review payloads relatively large.

## 2) Estimated context usage for original prompts if run in Codex

There are two useful estimates:

- **Prompt-body tokens**: size of what you paste as the step prompt.
- **Effective working-set tokens**: prompt + files it instructs to read.

For repeatable measurement below, I used a simple approximation:  
`estimated_tokens ~= characters / 4`.

### Effective working-set estimate (original, agent sessions)

Approximate ranges if executed literally (depends on each step's Required Reading list and whether large files are re-opened):

- v7.6.6.0: **~20k–30k**
- v7.6.6.1: **~55k–75k** (includes monolith split work context)
- v7.6.6.2: **~12k–22k**
- v7.6.6.3: **~10k–18k**
- v7.6.6.4: **~12k–22k**
- v7.6.6.5: **~15k–28k**
- v7.6.6.6: **~16k–30k**
- v7.6.6.7: **~18k–32k**
- v7.6.6.8: **~22k–38k**

Interpretation: the original flow is robust, but expensive; context pressure increases especially when large architecture and workflow docs are repeatedly loaded.

## 3) Codex-optimized replacement without quality loss

Created:  
`prompts/handoff/phaseY/phase-y-two-session-prompts-CODEX-Optimized.md`

Design principles used:

1. **Delegate first**: `sub/agents-worker` handles broad reading and evidence extraction.
2. **Main session stays surgical**: only apply edits, resolve ambiguity, synthesize outputs.
3. **Structured evidence**: worker returns strict gate tables (`PASS/FAIL/UNCLEAR` + evidence).
4. **No quality compromise**: all critical gates remain, including Do-NOT constraints and post-merge deliverables.
5. **Lower repetition**: common execution rules defined once, per-step deltas kept short.

## 4) Token/context estimate table by step

> Notes
> - “Original Agent” and “Copilot Agent” are the same (Copilot file only optimized review prompts).
> - These numbers are **prompt-body** estimates (not full working-set with loaded docs).
> - Method: `chars/4` from each per-step section.

| Step | Original Agent | Original Review | Copilot Agent | Copilot Review | CODEX Agent (new) | CODEX Review (new) |
|---|---:|---:|---:|---:|---:|---:|
| v7.6.6.0 | 492 | 393 | 492 | 1327 | 275 | 188 |
| v7.6.6.1 | 513 | 335 | 513 | 1279 | 190 | 132 |
| v7.6.6.2 | 325 | 234 | 325 | 1077 | 143 | 93 |
| v7.6.6.3 | 288 | 211 | 288 | 977 | 107 | 90 |
| v7.6.6.4 | 296 | 229 | 296 | 850 | 87 | 68 |
| v7.6.6.5 | 469 | 263 | 469 | 1007 | 86 | 60 |
| v7.6.6.6 | 518 | 253 | 518 | 1122 | 74 | 54 |
| v7.6.6.7 | 403 | 251 | 403 | 943 | 71 | 51 |
| v7.6.6.8 | 509 | 332 | 509 | 1746 | 79 | 97 |

### What this means

- New Codex prompts reduce **agent prompt size** by roughly **45–85%** depending on step.
- New Codex prompts reduce **review prompt size** dramatically versus Copilot deep-research prompts.
- Biggest gains come from replacing repeated prose with a stable worker orchestration pattern.

## Deliverables produced

1. `prompts/handoff/phaseY/phase-y-two-session-prompts-for-CODEX-explanation.md` (this file)
2. `prompts/handoff/phaseY/phase-y-two-session-prompts-CODEX-Optimized.md` (optimized prompts)

