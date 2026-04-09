# Phase Y — Prompt Resource Analysis & Perplexity-Optimized Versions

_Author: Perplexity AI (analysis session 2026-04-09)_  
_Scope: Analysis of original two-session prompts vs Copilot-optimized prompts,  
plus Perplexity-optimized alternatives with token estimates._

---

## 1. Are the Original Prompts Optimal for Perplexity?

**Short answer: No.** The original prompts (`phase-y-two-session-prompts.md`) were
designed for **Claude Code** — a stateful, agentic IDE assistant with persistent file
system access, long-context tool use, and the ability to run shell commands in an
iterative REPL loop. Perplexity is a **single-turn web assistant** with a fundamentally
different architecture. The prompts are suboptimal for Perplexity for several reasons:

### 1a. Architecture Mismatch

| Capability | Claude Code | Perplexity |
|---|---|---|
| File system access | Native (reads/writes locally) | Via GitHub MCP (remote API) |
| Shell execution | Native (`bash`, `grep`, `wc`) | Not available |
| Session statefulness | Persistent workspace across turns | Stateless per-session (no shared memory) |
| Context window | 200K tokens (Anthropic), long CoT | ~32K–128K effective; degrades with load |
| Tool orchestration | Built-in IDE toolchain | GitHub MCP + web search |
| Sub-agents / deep research | No | Yes (Research mode, Labs) |
| Code execution | Direct | Python sandbox only |

### 1b. Why the Original Agent Prompts Are Poorly Suited

The original **Step 1 (agent)** prompts instruct the agent to:

1. **Read 3–6 full files before making ANY changes** — in Claude Code this is cheap
   because files are read from disk. In Perplexity, each file read is an MCP API call
   that consumes tokens AND output tokens entering the context window. Reading
   `sensor_history_multi.h` (4,325 lines ≈ 18,000 tokens) plus 3–4 other files
   before a single edit will consume 30–50% of the context window before any work
   begins.

2. **Run shell commands inline** (`grep -n`, `wc -l`, `diff`, `sed -n`, `bash scripts/...`)
   — Perplexity cannot run shell commands. These would require translating every
   shell verification step into a sequence of GitHub MCP file reads + manual
   line-counting logic, multiplying context usage 3–5x per verification step.

3. **Perform iterative pipeline validation** (`Full pipeline, Playwright suite`) —
   Perplexity cannot execute scripts or observe runtime output. All verification
   must be static (file content inspection), which requires loading more files.

4. **Produce session logs and compliance tables** — these are large structured
   outputs that consume significant output token budget, reducing space for
   further reasoning.

### 1c. Why the Original Review Prompts Are Poorly Suited

The original **Step 2 (review)** prompts are shorter but suffer from:

1. **Implicit expectation of full-context file reading** — phrases like "Read
   thoughtfully `session-handoff-v7.6.6.X.md`" load the full handoff document
   (~2,000–4,000 tokens) before any review logic begins.

2. **No delegation of heavy lifting** — the review session must read, reason,
   AND output in a single pass. There is no sub-agent to pre-fetch evidence,
   so the main context window must hold: handoff doc + PR diff + all reviewed
   files + analysis output simultaneously.

3. **Checklist items require file evidence** — e.g., "does `run_full_pipeline()`
   match Critical Rule 37 exactly?" requires loading both `provision.sh` AND
   `prompt-index-and-workflow.md` (a large file) simultaneously.

4. **Post-merge deliverables in the same session** — producing the consolidated
   audit document at the end of an already loaded review session means the context
   window is near capacity, degrading output quality.

---

## 2. What the Copilot-Optimized Prompts Fix

The Copilot-optimized review prompts (`phaseY-PR-review-prompts-Copilot-Optimized.md`)
demonstrate excellent context-window hygiene:

- **Deep-research sub-agent** handles the bulk file reading and evidence collection
  outside the main context window. The synthesis session receives a pre-processed
  structured report, not raw files.
- **Explicit delegation boundary** — "Do NOT re-read full files — use the sub-agent's
  findings." This is the key optimization. It prevents re-loading documents that the
  sub-agent already summarized.
- **4-step pipeline** separates concerns: evidence collection → synthesis → fix prompt
  generation → post-merge deliverables. Each step starts with a lighter context.
- **Structured output format pre-specified** — the sub-agent is instructed to return
  a structured table, so the synthesis step consumes compact tokens (a table row)
  rather than verbose prose per gate.

However, the Copilot-optimized prompts **keep the original Step 1 (agent) prompts
unchanged**, meaning the agent-side context problem remains unaddressed.

---

## 3. Estimated Token Usage — Original vs. Copilot vs. Perplexity-Optimized

### Token Estimation Methodology

- **Input tokens**: sum of all content loaded into context (prompt text + files read)
- **Output tokens**: generated response (session log, tables, deliverables)
- **Effective context pressure**: percentage of a ~32K context window consumed
- File size estimates based on actual repo files:
  - `session-handoff-v7.6.6.X.md` ≈ 1,500–2,500 tokens each
  - `implementation-instructions-for-coding-agent.md` ≈ 3,000–6,000 tokens each
  - `sensor_history_multi.h` ≈ 18,000 tokens (4,325 lines)
  - `provision.sh` ≈ 4,000–6,000 tokens (complex pipeline script)
  - `preflight.sh` ≈ 3,000–5,000 tokens
  - `prompt-index-and-workflow.md` ≈ 8,000–12,000 tokens (large index)
  - `phase-Y-architecture-and-refactor-plan-sensor-history.md` ≈ 6,000–10,000 tokens
  - Step-specific files (fragment headers, etc.) ≈ 1,000–3,000 tokens each
  - Output (session log + tables + deliverables) ≈ 3,000–8,000 tokens

### Token Estimates per Step

| Step | Prompt Type | Original Input (tokens) | Original Output (tokens) | Copilot Input (tokens) | Copilot Output (tokens) | Perplexity-Opt Input (tokens) | Perplexity-Opt Output (tokens) |
|---|---|---|---|---|---|---|---|
| **v7.6.6.0** | Agent (Step 1) | ~38,000 | ~6,000 | ~38,000 (unchanged) | ~6,000 | ~12,000 | ~3,000 |
| **v7.6.6.0** | Review (Step 2) | ~22,000 | ~5,000 | ~4,000 (synthesis only) | ~4,000 | ~3,500 | ~3,500 |
| **v7.6.6.1** | Agent (Step 1) | ~52,000 | ~8,000 | ~52,000 (unchanged) | ~8,000 | ~14,000 | ~4,000 |
| **v7.6.6.1** | Review (Step 2) | ~28,000 | ~6,000 | ~4,500 (synthesis only) | ~5,000 | ~4,000 | ~4,000 |
| **v7.6.6.2** | Agent (Step 1) | ~32,000 | ~5,000 | ~32,000 (unchanged) | ~5,000 | ~10,000 | ~2,500 |
| **v7.6.6.2** | Review (Step 2) | ~18,000 | ~4,000 | ~3,500 (synthesis only) | ~3,500 | ~3,000 | ~3,000 |
| **v7.6.6.3** | Agent (Step 1) | ~24,000 | ~4,000 | ~24,000 (unchanged) | ~4,000 | ~8,000 | ~2,000 |
| **v7.6.6.3** | Review (Step 2) | ~16,000 | ~3,500 | ~3,000 (synthesis only) | ~3,000 | ~2,500 | ~2,500 |
| **v7.6.6.4** | Agent (Step 1) | ~20,000 | ~4,000 | ~20,000 (unchanged) | ~4,000 | ~7,000 | ~2,000 |
| **v7.6.6.4** | Review (Step 2) | ~14,000 | ~3,000 | ~2,500 (synthesis only) | ~2,500 | ~2,000 | ~2,000 |
| **v7.6.6.5** | Agent (Step 1) | ~34,000 | ~6,000 | ~34,000 (unchanged) | ~6,000 | ~11,000 | ~3,000 |
| **v7.6.6.5** | Review (Step 2) | ~20,000 | ~5,000 | ~3,500 (synthesis only) | ~4,500 | ~3,000 | ~3,500 |
| **v7.6.6.6** | Agent (Step 1) | ~36,000 | ~7,000 | ~36,000 (unchanged) | ~7,000 | ~12,000 | ~3,500 |
| **v7.6.6.6** | Review (Step 2) | ~24,000 | ~6,000 | ~4,000 (synthesis only) | ~5,000 | ~3,500 | ~4,000 |
| **v7.6.6.7** | Agent (Step 1) | ~38,000 | ~7,000 | ~38,000 (unchanged) | ~7,000 | ~13,000 | ~4,000 |
| **v7.6.6.7** | Review (Step 2) | ~22,000 | ~5,500 | ~3,500 (synthesis only) | ~5,000 | ~3,000 | ~4,000 |
| **v7.6.6.8** | Agent (Step 1) | ~44,000 | ~8,000 | ~44,000 (unchanged) | ~8,000 | ~15,000 | ~4,500 |
| **v7.6.6.8** | Review (Step 2) | ~32,000 | ~8,000 | ~5,000 (synthesis only) | ~7,000 | ~4,000 | ~5,500 |
| **TOTALS** | **All** | **~538,000** | **~115,000** | **~355,000** | **~109,000** | **~153,500** | **~65,500** |

_Notes:_
- _Copilot Step 1 (agent) tokens are identical to Original because Copilot-optimized prompts_
  _explicitly kept the agent prompts unchanged._
- _Copilot Step 2 (review) savings come from the sub-agent pre-processing — the synthesis_
  _session only receives structured results, not raw files. However, the sub-agent itself_
  _runs its own context window separately (not counted in the "Copilot" column above)._
- _Perplexity-Optimized tokens reflect the redesign described in Section 4 below._

### Summary: Context Window Savings

| Prompt Variant | Est. Total Input Tokens | Est. Total Output Tokens | Est. Grand Total | Reduction vs. Original |
|---|---|---|---|---|
| Original (Claude Code) | ~538,000 | ~115,000 | ~653,000 | — |
| Copilot-Optimized (review only) | ~355,000 | ~109,000 | ~464,000 | −29% |
| **Perplexity-Optimized (both)** | **~153,500** | **~65,500** | **~219,000** | **−66%** |

---

## 4. Why Perplexity-Optimized Prompts Save Context and Prevent Degradation

### 4a. Context Window Degradation Explained

In Perplexity (and LLMs generally), context window degradation occurs when:

1. **Early context displacement** — if a large file (e.g., `sensor_history_multi.h`
   at 18K tokens) is loaded at the start, it occupies a fixed block of the window.
   By the time the agent reaches step 8 of 13 in its task, the earlier instructions
   and constraints may have low effective attention weight due to positional dilution.

2. **Instruction forgetting** — long "read N files then do M things" prompts cause
   critical rules (e.g., "Do NOT use `eval`", "Do NOT modify firmware files") to be
   encountered at token position 30,000+, where they receive less attention during
   decoding than instructions in the first 5,000 tokens.

3. **Output quality degradation** — when input context is near-full, the model must
   compress or omit details in its output. Session logs, compliance tables, and
   audit documents produced at the end of a heavy session are often incomplete.

### 4b. Perplexity-Specific Optimizations

The following design changes improve token efficiency for Perplexity:

1. **Replace "read this whole file" with targeted GitHub MCP queries** — instead of
   loading full files, use `get_file_contents` with specific path + line range
   parameters to fetch only the sections relevant to each gate. This reduces
   per-file consumption by 70–90%.

2. **Front-load constraints, not context** — move the Do-NOT list and critical rules
   to the TOP of the prompt (within the first 1,000 tokens). In the original prompts,
   critical rules appear after the reading list and after the task steps.

3. **Use Research mode for evidence collection** — for review prompts, delegate PR
   diff reading and cross-file verification to Research mode (analogous to the
   Copilot sub-agent). The synthesis conversation then only receives the research
   summary.

4. **Split the session explicitly** — instead of "read 5 files, then implement 13
   steps, then produce session log", split into:
   - **Turn 1**: Read constraints + handoff summary only. Confirm understanding.
   - **Turn 2**: Execute implementation (specific targeted file reads as needed).
   - **Turn 3**: Verification and output (session log, compliance table).
   This prevents all context from accumulating before any work begins.

5. **Pre-summarize context in the prompt** — instead of pointing to handoff docs,
   inline a 200-token summary of the current state. The 1,500-token full handoff doc
   is only referenced if clarification is needed.

6. **Checklist outputs over prose outputs** — instruct the model to produce structured
   tables rather than prose session logs. A table with 14 rows × 3 columns is ~400
   tokens vs. a narrative session log of ~2,500 tokens.

---

## 5. Perplexity-Optimized Prompts

The following prompts are redesigned for Perplexity. Only v7.6.6.0 and v7.6.6.1 are
shown in full as examples — the pattern is identical for all 9 steps.

**Key conventions used:**
- Constraints and Do-NOTs are in the first block (high attention weight)
- Context is inlined as a compact summary (not a file reference)
- File reads are targeted and deferred until needed
- Review prompts use Research mode for evidence collection
- Output format is table-first, not prose-first

---

### v7.6.6.0 — Perplexity Agent Prompt (Step 1)

```
Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

⛔ HARD CONSTRAINTS (enforce throughout — do not drift):
- Do NOT modify sensor_history_multi.h, any firmware file, or any test file
- Do NOT use eval for pipeline step execution
- Do NOT make status mutating (no pipeline call in status case)
- Do NOT use Content-Type: application/json for POST commands
- Version bump ONLY via: bash scripts/bump-version.sh 7.6.6.0

CONTEXT (v7.6.6.0 pre-step: provision.sh pipeline automation):
Goal: replace print_workflow() with run_full_pipeline() in provision.sh.
Pipeline order (Critical Rule 37): bundle → render → fixtures → render → build → minify → header → check (8 steps).
Step 0 is a placeholder for assembly script (no-op comment — script doesn't exist yet).
All three board modes (satellite, aggregator, wroom) must run the full pipeline.
--dry-run must print all steps with [DRY-RUN] prefix, zero filesystem changes.
status must remain non-mutating.

TASK (execute in order — read files only when you reach the step that needs them):
1. Fetch and read scripts/provision.sh — understand run_render(), print_workflow(), activate_*() functions
2. Implement run_full_pipeline() with exact step array from Context above
3. Add require_node() and require_npm_deps() dependency pre-checks
4. Add --dry-run support to all board modes
5. Replace print_workflow() calls with run_full_pipeline() in all activate_*() functions
6. Add Step 0 placeholder comment (no-op)
7. Verify status case is non-mutating
8. Fetch and read Docs/lessons/operations.md — add LESSON-OPS entry
9. Run: bash scripts/bump-version.sh 7.6.6.0
10. Add changelog entry
11. Produce compliance table (14 gates, PASS/FAIL, one-line evidence each)

OUTPUT FORMAT: Compliance table first, then session summary (max 500 words).
Do not produce verbose prose narrating each file read.
```

---

### v7.6.6.0 — Perplexity Review Prompt (Step 2)

```
Use Research mode to investigate PR #<PR_NUMBER> in
GCV-Sleeper-Service/ESP32-GW-multi-sensor.

Research query:
> For PR #<PR_NUMBER> (v7.6.6.0 — provision.sh pipeline automation):
> 1. Read provision.sh — does run_full_pipeline() exist? List all steps in order.
>    Do all 3 board modes call it? Is status non-mutating?
> 2. Read the PR diff — any changes to firmware, tests, or sensor_history_multi.h?
> 3. Is there eval usage in run_full_pipeline()?
> 4. Do require_node() and require_npm_deps() exist and are called before pipeline?
> 5. Is there a --dry-run implementation? Does it avoid filesystem changes?
> 6. Is Step 0 a no-op comment (not a script call)?
> 7. Is there a LESSON-OPS entry in Docs/lessons/operations.md?
> 8. Do all 4 Playwright fixture sets pass (check CI status)?
> Return results as a 14-row table: gate | PASS/FAIL/UNCLEAR | evidence (one line).

After research returns, synthesize:
- Gate checklist table (use research results — do not re-read files)
- Review comment assessment (warranted? fixed? remaining?)
- Concrete fix list (if any)
- Post findings as PR comment on #<PR_NUMBER>

CONTEXT: v7.6.6.0 pre-step. provision.sh gets run_full_pipeline() replacing print_workflow().
Pipeline: bundle → render → fixtures → render → build → minify → header → check.
BLOCKING rules: no eval, status non-mutating, no firmware/test changes.
```

---

### v7.6.6.1 — Perplexity Agent Prompt (Step 1)

```
Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

⛔ HARD CONSTRAINTS:
- Do NOT use split command — use sed -n with explicit line ranges only
- Do NOT modify sensor_history_multi.h — fragments are copies, not moves
- Do NOT add fragments to YAML includes:
- Do NOT redirect render_sensor_config.py to fragment files
- --check mode MUST use strip_generated() to handle generator marker content
- Version bump ONLY via: bash scripts/bump-version.sh 7.6.6.1

CONTEXT (v7.6.6.1: establish assembly script and 8-fragment baseline):
Split dashboard/sensor_history_multi.h (4,325 lines) into 8 fragments in firmware/core/.
Fragment manifest (line ranges from the original file):
  config.h:              lines 1–95     (95 lines)
  data-model.h:          lines 96–555   (460 lines)
  nvs-persistence.h:     lines 556–1169 (614 lines)
  registration.h:        lines 1170–1219 (50 lines)
  ping-adapter.h:        lines 1220–1387 (168 lines)
  aggregator-runtime.h:  lines 1388–2278 (891 lines)
  http-handlers.h:       lines 2279–4284 (2006 lines)
  dashboard-init.h:      lines 4285–4325 (41 lines)
  TOTAL: 4,325 lines
Assembly script: scripts/assemble-sensor-history.sh with --write/--check/--list/--dry-run modes.
Identity gate: cat firmware/core/*.h | diff - dashboard/sensor_history_multi.h must exit 0.

TASK (execute in order):
1. Fetch wc -l of dashboard/sensor_history_multi.h via get_file_contents — confirm 4325 lines
2. Record SHA-256 of sensor_history_multi.h (fetch full file, compute hash)
3. Create firmware/core/ directory (create placeholder .gitkeep or first fragment)
4. Extract all 8 fragments using create_or_update_file with exact content from line ranges
5. Verify total lines across 8 fragments sum to 4,325
6. Create scripts/assemble-sensor-history.sh with all 4 modes and strip_generated()
7. Activate assembly step in provision.sh (replace placeholder from v7.6.6.0)
8. Add firmware_core_fragments_exist check to scripts/preflight.sh
9. Run: bash scripts/bump-version.sh 7.6.6.1
10. Add changelog entry
11. Produce compliance table (17 gates, PASS/FAIL, one-line evidence each)

OUTPUT FORMAT: Compliance table first, then session summary (max 500 words).
```

---

### v7.6.6.1 — Perplexity Review Prompt (Step 2)

```
Use Research mode to investigate PR #<PR_NUMBER> in
GCV-Sleeper-Service/ESP32-GW-multi-sensor.

Research query:
> For PR #<PR_NUMBER> (v7.6.6.1 — establish assembly script and 8-fragment baseline):
> 1. List all files in firmware/core/ — exactly 8 fragments?
>    Report each filename and its line count (wc -l equivalent from file content).
>    Do line counts sum to 4,325? (expected: 95+460+614+50+168+891+2006+41)
> 2. Does scripts/assemble-sensor-history.sh exist? Does it implement strip_generated()?
> 3. Is the assembly step active in provision.sh (not a placeholder comment)?
> 4. Does scripts/preflight.sh contain firmware_core_fragments_exist function?
> 5. Does sensor_history_multi.h appear unmodified (check PR diff)?
> 6. Are any fragment files added to YAML includes: (check .yaml files in PR diff)?
> 7. Is sed -n used for extraction (not split command)?
> 8. Do all 4 Playwright fixture sets pass?
> 9. Check boundary landmarks: head -1 of data-model.h (should be a TAG comment),
>    head -1 of aggregator-runtime.h (should be #if AGGREGATOR_ENABLED).
> Return results as a 17-row gate table: gate | PASS/FAIL/UNCLEAR | evidence.

After research returns, synthesize:
- Gate checklist table (17 gates — use research results only)
- Review comment assessment
- Concrete fix list (if any)
- Post findings as PR comment on #<PR_NUMBER>

CONTEXT: v7.6.6.1. Fragment extraction from 4,325-line sensor_history_multi.h.
Identity gate and generator-aware --check are the key correctness signals.
```

---

_For steps v7.6.6.2 through v7.6.6.8, apply the same pattern:_
_1. Front-load ⛔ HARD CONSTRAINTS._
_2. Inline a compact CONTEXT block (150–300 tokens, not a file reference)._
_3. Defer file reads to the task step that needs them._
_4. Instruct Research mode for review evidence collection._
_5. Require table-first output format._

---

## 6. Quick Reference — Context Savings by Design Choice

| Design Choice | Original | Perplexity-Optimized | Token Saving |
|---|---|---|---|
| File reading strategy | Load all required reading up front | Load files on-demand, targeted sections | ~60–70% input reduction |
| Constraint placement | After reading list, mid-prompt | First block (top 500 tokens) | Attention quality ↑ |
| Context delivery | "Read handoff doc" (1,500 tokens) | Inline compact summary (200 tokens) | ~87% per step |
| Output format | Prose session log (2,000–4,000 tokens) | Structured compliance table (300–600 tokens) | ~75% output reduction |
| Review evidence | Main session reads all files | Research mode pre-collects; synthesis uses summary | ~80% review input reduction |
| Session structure | Single giant turn | 3 focused turns (constraints → implement → verify) | Degradation risk ↓ |

---

_End of analysis._
