# Perplexity Review Prompt Generator — Reusable Briefing

## What you are doing

You are producing a **PR reviewer prompt file** for Perplexity AI, optimized for
Perplexity's environment (stateless, MCP GitHub tool access, no persistent sub-agents,
context window is the scarcest resource).

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

---

## Your environment constraints (apply to every prompt you produce)

- No shell execution — every file read is a GitHub MCP API call costing context tokens
- No persistent state between turns — each turn is discrete
- Three-turn session structure: Turn 1 = spec extraction, Turn 2 = diff + evidence audit,
  Turn 3 = verdict + output
- Diff-first reviews: only open source files if the diff alone is ambiguous for a gate
- Inline context headers (≤ 400 tokens) must front-load all constraints before any file is opened
- Table-first output: gate checklist tables, not prose narratives
- Missing evidence ≠ failing evidence: mark UNCLEAR, not FAIL

---

## Reference files to read before producing anything

Read these files from the repo in this order:

1. `prompts/handoff/phaseV/Perplexity-Session-Context-Protocol-Three-Turn.md`
   — the shared three-turn review protocol (your output must reference this file,
     not inline it)

2. `prompts/handoff/phaseY/phase-y-two-session-prompts-PR-Optimized.md`
   — the Phase Y Perplexity-optimized file; this is your structural template

3. `prompts/phaseV/phase-v-review-prompts-perplexity.md`
   — the Phase V file you produced previously; this is your style and quality reference

4. `Docs/phase-[X]-implementation-plan.md`
   — the implementation plan for the NEW phase (substitute correct filename)
   Read: objectives, version sequences, steps, acceptance criteria, hard constraints,
   critical rules called out per step, gated conditions, and §5.2 prompt artefacts spec

5. Every `prompts/phase[X]/v7.x.x.x-claude-two-step.md` file for the new phase
   — for EACH file, read only the `## Step 2 — Review Session` section
   — these are your source material: extract the gates, evidence requirements,
     post-merge deliverables, and operator actions from each one

---

## What to produce

A single downloadable markdown file named:
`phase-[X]-review-prompts-perplexity.md`

The file must contain, in order:

1. **Header block** — repo, date, optimization target, scope note (review only)

2. **"How these prompts differ" section** — 4–6 bullet points explaining the
   Perplexity-specific design choices for this phase (adapt from Phase V/Y versions
   but reflect any phase-specific constraints)

3. **Reference to shared protocol** — one short paragraph directing users to
   `Perplexity-Session-Context-Protocol-Three-Turn.md`; do NOT inline the protocol

4. **One section per step**, each containing:

   a. `## Inline review context` — fenced code block (≤ 400 tokens) with:
      - Step label and objectives
      - Allowed diff scope (exact file paths with one-line annotations)
      - ⛔ Out of scope items
      - Critical rules (rule number + one-line description)
      - Blocking gates (gates that make verdict BLOCKED regardless of others)
      - Evidence needed (what logs/outputs/tables must be present)

   b. `## Review prompt — vX.X.X.X` — the actual pasteable prompt containing:
      - Repo line
      - Instruction to read the shared protocol file
      - Turn 1 reads (handoff file + agent/implementation prompt, nothing else)
      - Turn 2 diff + evidence fetch (exact file paths, evidence sources)
      - Review gates list (explicit, one line each, directly checkable from diff)
      - Turn 3 — Verdict + output block:
        * Post as PR comment instruction
        * Fix prompt generation instruction (if NEEDS-FIX or BLOCKED):
          - Address ONLY remaining failing/unclear gates
          - Include Do-NOT list covering already-passing gates
          - Style reference: the agent prompt file for that step
        * Post-merge deliverables (if MERGE-READY):
          - Consolidated audit file to create
          - Next step handoff + instructions files to review and update
          - Version tag to apply
          - Operator device tests or measurements to include in consolidated audit
          - Any phase-specific closure actions (issue closes, ADR commits, etc.)

5. **Token budget reference table** at the end — estimated context per step,
   Claude original vs. Perplexity, with savings percentage

---

## Quality rules

- Every acceptance criterion from the implementation plan must appear as an
  explicit gate — do not summarize or collapse related criteria
- Blocking gates must be identified from: critical rule violations, device test
  failures, gated changes without measurement evidence
- Gated steps (ship only if measurement passes) must have explicit
  "if gate NOT triggered → no code change must be present in diff" gates
- Post-merge deliverables must be complete — include consolidated audit, next
  handoff update, version tag, AND any operator actions specific to that step
- Do NOT inline the shared protocol — reference the file
- Do NOT produce agent prompts — review prompts only
- Style anchor for fix prompts must point to the agent prompt file for that
  specific step, not a generic reference

---

## Output

Produce the complete file content ready for download.
Do not summarize — produce the full file.
Ask a clarifying question first if the implementation plan or any claude two-step
file is missing, ambiguous, or not yet committed to the repo.