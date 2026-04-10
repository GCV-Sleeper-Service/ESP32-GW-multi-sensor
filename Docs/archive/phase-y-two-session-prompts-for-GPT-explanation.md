# Phase Y — GPT Optimization Analysis for Two-Session Prompts

_Repo: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`_  
_Source files reviewed:_
- `Docs/phase-Y-architecture-and-refactor-plan-sensor-history.md`
- `prompts/handoff/phaseY/phase-y-two-session-prompts.md`
- `prompts/handoff/phaseY/phaseY-PR-review-prompts-Copilot-Optimized.md`

_Date: 2026-04-09_

---

## Executive Conclusion

The original Phase Y prompts are **high-rigor but not optimal for GPT-style coordinator workflows**.

They are strong on correctness and explicitness, but they spend too much of the main session context window on **eager full-document reading**, repeated restatement of stable repo rules, and review flows that require the coordinator session to personally ingest too much material before it can act.

The Copilot-optimized file is directionally better for **review** because it offloads broad reading into a deep-research sub-agent, but it does **not** optimize the agent/implementation side, and its deep-research prompts are still broad enough that total token spend can remain high even while the visible coordinator context stays smaller.

The GPT-optimized version in `phase-y-two-session-prompts-GPT-Optimized.md` is designed around a different operating model:

1. **Coordinator session stays narrow**
2. **Workers do bounded reads**
3. **Workers return capped structured summaries**
4. **Main session only opens full files that it will edit, quote, or verify directly**
5. **Review becomes diff-first and evidence-first, not repo-first**

That preserves quality while reducing active context pressure.

---

## 1. Why the original prompts are not the best fit for GPT

### 1.1 The agent prompts front-load too much reading

Most original Step 1 prompts tell the model to:

- read the session handoff fully
- read the implementation instructions fully
- read every file in the Required Reading section fully
- then start work

That is safe, but it is expensive. It converts nearly every step into a **broad-context preload task**.

### 1.2 They overuse eager loading instead of staged loading

For GPT, a better pattern is:

- first extract the contract
- then inspect only the target files
- then inspect only the validation surfaces that matter
- only after that open more material if a worker flags ambiguity

The original prompts usually invert that order.

### 1.3 They duplicate stable instructions inside the live working context

A lot of the “must not do X / must verify Y / remember rule Z” content is valid and should stay, but the original form makes the coordinator session carry it all at once.

GPT does better when that material is compressed into:

- allowed files
- forbidden files
- validation gates
- delivery obligations
- unresolved risks

### 1.4 The original review prompts are not truly context-window aware

The original Step 2 prompts are concise, but they implicitly require the reviewer to re-open broad repo context, PR context, and validation evidence in one session. They do not tell the model how to partition that work.

That means a GPT review session will often drift into:

- rereading implementation docs
- rereading the plan
- rereading changed files
- rereading PR comments
- rereading logs and evidence

That is exactly the sort of accumulation that degrades a long technical review session.

### 1.5 They do not distinguish “primary-session context” from “total-token work”

This matters a lot. A coordinator + worker pattern can lower the active context window without necessarily lowering the sum of all tokens across all workers. The original prompts do not exploit that distinction at all.

---

## 2. What the Copilot-optimized file improves — and what it does not

### What it improves

The Copilot review file improves the review path by delegating broad reading to a deep-research worker before synthesis. That is a real improvement for active-session context.

### What it does not improve

- It leaves the **agent prompts unchanged**
- It still uses **very broad research queries**
- It often asks the worker to return a lot of material that the main session then partially repeats
- It is optimized mainly for **review**, not for the full two-session workflow

### Net effect

For the **main review session**, Copilot’s version is lighter than the original.

For **overall token consumption**, it may be only modestly better and in some cases can be roughly comparable because the worker still performs a large repo sweep and can return oversized summaries.

---

## 3. GPT optimization strategy used in the new file

The GPT-optimized prompts use six rules.

### Rule A — bounded worker roles

Each session launches small workers with tightly scoped jobs, such as:

- contract extraction
- code-surface extraction
- validation/evidence extraction
- final reconciliation

### Rule B — output caps

Each worker is told to return a short structured brief, not a long narrative dump.

### Rule C — diff-first / target-file-first reading

The coordinator session does **not** reread the whole step universe. It opens:

- files it will edit
- files it must quote
- files a worker marked ambiguous

### Rule D — no duplicate repo rereads in review

The review session treats three things separately:

- spec gates
- actual diff
- evidence/comments/logs

That stops the reviewer from mixing all inputs into one large context blob.

### Rule E — keep stable invariants in a compact ledger

Workers return:

- allowed files
- forbidden files
- must-pass validations
- acceptance gates
- likely regression traps

That gives the coordinator the same safety with fewer tokens.

### Rule F — use workers for compression, not for authority transfer

Workers summarize. The coordinator still owns final decisions, final edits, and final review judgment.

---

## 4. Token estimate methodology

These are **estimates**, not measured tokenizer outputs.

Assumptions:

1. Counts are for **active primary-session context**, which is the number that matters most for context-window pressure.
2. “Copilot Agent” equals “Original Agent” because the Copilot-optimized file only replaced review prompts.
3. Worker-token totals can be higher than primary-session totals. That is normal. The goal here is to reduce **coordinator-session load** first.
4. The main drivers are:
   - breadth of mandatory reading
   - number of large files reread in one session
   - whether the prompt enforces decomposition
   - whether review is diff-first vs repo-first
5. Device-test and closure steps are higher because they carry more evidence, logs, and cross-file verification.

---

## 5. Estimated primary-session token usage by step

| Step | Scope | Original Agent | Original Review | Copilot Agent | Copilot Review | GPT Agent | GPT Review | GPT Agent savings vs original | GPT Review savings vs original |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `v7.6.6.0` | Pre-step: provision.sh full pipeline automation | 24,000 | 11,000 | 24,000 | 8,000 | 9,000 | 6,000 | 62% | 45% |
| `v7.6.6.1` | Establish assembly script and baseline | 32,000 | 13,000 | 32,000 | 9,000 | 13,000 | 8,000 | 59% | 38% |
| `v7.6.6.2` | Wire assembly into pipeline and fragment-level preflight | 20,000 | 10,000 | 20,000 | 7,000 | 8,000 | 5,500 | 60% | 45% |
| `v7.6.6.3` | Fragment editing workflow validated | 14,000 | 9,000 | 14,000 | 6,500 | 6,000 | 5,000 | 57% | 44% |
| `v7.6.6.4` | Ping adapter fragment validation | 14,000 | 9,000 | 14,000 | 6,500 | 6,000 | 5,000 | 57% | 44% |
| `v7.6.6.5` | NVS persistence device test gate | 18,000 | 11,000 | 18,000 | 8,000 | 8,000 | 6,500 | 56% | 41% |
| `v7.6.6.6` | Aggregator runtime device test gate | 20,000 | 12,000 | 20,000 | 8,500 | 9,000 | 7,000 | 55% | 42% |
| `v7.6.6.7` | Full endpoint smoke test | 22,000 | 12,000 | 22,000 | 8,500 | 10,000 | 7,500 | 55% | 38% |
| `v7.6.6.8` | Closure: preflight, documentation, critical rules | 26,000 | 16,000 | 26,000 | 11,000 | 12,000 | 9,000 | 54% | 44% |

### Totals across the whole phase

| Workflow | Agent total | Review total |
|---|---:|---:|
| Original | 190,000 | 103,000 |
| Copilot-optimized | 190,000 | 73,000 |
| GPT-optimized | 81,000 | 59,500 |

### Interpretation

- **Original** is the heaviest on the primary session because it expects direct broad reading.
- **Copilot review** improves coordinator load, but only on the review side.
- **GPT-optimized** cuts primary-session load on **both** agent and review steps.
- The biggest win is not just fewer tokens. It is **less context sprawl**, which means:
  - fewer accidental instruction collisions
  - less drift late in the session
  - cleaner prioritization
  - better chance that the final coordinator still remembers the actual step contract

---

## 6. Step-by-step observations

### `v7.6.6.0`
The original agent flow is heavier than it needs to be because the real work is concentrated in `scripts/provision.sh`, `Docs/lessons/operations.md`, and the step contract. GPT can safely push contract extraction and rule extraction into workers.

### `v7.6.6.1`
This is the most expensive early implementation step because it mixes plan reading, landmark verification, monolith handling, assembly script behavior, and preflight changes. It benefits strongly from worker partitioning.

### `v7.6.6.2`
Mostly tooling integration. The original prompts still overread compared with the actual change surface.

### `v7.6.6.3`
Very narrow validation step. The original prompt is already smaller, but it still benefits from using one worker for the gate contract and one for evidence expectations.

### `v7.6.6.4`
Similarly narrow. The original prompt is safe but broader than required.

### `v7.6.6.5`
The step is device-test heavy, so raw file-reading is not the dominant cost; evidence handling is. GPT benefits from separating code-surface understanding from device-evidence reconciliation.

### `v7.6.6.6`
Same pattern as `v7.6.6.5`, but with more endpoint/evidence complexity and more risk around aggregator state.

### `v7.6.6.7`
This is an evidence-heavy review and validation step. A worker-first evidence table keeps the main review session much smaller.

### `v7.6.6.8`
Closure is large because it touches preflight, lessons, README, prompt-index, and final results. This is exactly the sort of step where coordinator/worker separation matters most.

---

## 7. Design choices in the GPT-optimized prompt file

The optimized file does **not** try to make the coordinator ignorant of the project. It does something more precise:

- narrow the coordinator’s active context
- keep the contract explicit
- keep the file scope explicit
- keep the do-not-touch list explicit
- keep the validation gates explicit
- use workers to compress the rest

### What stayed intentionally strict

I preserved the following characteristics from the original prompts:

- explicit order of operations
- do-not lists
- validation expectations
- deliverables expectations
- step-specific risk awareness
- post-merge obligations where relevant

### What changed

- mandatory full rereads were replaced with worker-based extraction
- review prompts are split into contract / diff / evidence lanes
- worker outputs are capped and structured
- the coordinator is told not to reopen whole files unless necessary

---

## 8. Practical recommendation

For GPT-family usage, I recommend:

- use `phase-y-two-session-prompts-GPT-Optimized.md` as the default Phase Y execution source
- keep the original file as the “maximal explicitness” baseline
- keep the Copilot file only as a Copilot-specific review variant, not as the main GPT reference

---

## 9. Deliverables created

This analysis file is paired with:

- `prompts/handoff/phaseY/phase-y-two-session-prompts-GPT-Optimized.md`

That second file contains the full GPT-oriented two-session prompt set.

---

_End of GPT optimization analysis._