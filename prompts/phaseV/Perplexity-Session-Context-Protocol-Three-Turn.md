## Shared Perplexity Review Session Protocol

This protocol applies to every step unless the step section overrides it.

### Three-turn structure

**Turn 1 — Spec extraction (≤ 300 tokens output)**

Read only:
- The inline review context header embedded in the prompt below.
- The step handoff file.
- The implementation-instructions file (or agent prompt file for Phase V).

Produce:
1. Gate checklist (one line per gate, numbered).
2. Allowed diff scope (file list).
3. Required evidence artifacts (logs, tables, outputs).
4. Blocking gate verdict criteria (which gates, if failed, make the verdict BLOCKED regardless of others).

Do **not** open the PR diff yet.

**Turn 2 — Diff + evidence audit**

Fetch the PR diff for the exact files listed in the allowed diff scope from Turn 1.  
Fetch evidence artifacts listed in Turn 1 (compliance table, logs, session log from PR description or comments).  
For each gate: record PASS / FAIL / UNCLEAR with one-line evidence.  
Only open source files if a gate cannot be decided from the diff alone.

**Turn 3 — Verdict + output**

Produce the full review output in the format below.  
List post-merge deliverables explicitly if verdict is MERGE-READY.

### Coordinator constraints

- **Diff-first.** Do not open source files unless the diff is ambiguous for a specific gate.
- **Missing evidence ≠ failing evidence.** Mark gates UNCLEAR, not FAIL, when evidence is simply absent from the PR.
- **Do not soften blocking failures.** If a device gate or critical-rule gate fails, the verdict is BLOCKED regardless of other gates.
- **Do not reread the full repo.** The gate checklist from Turn 1 is the complete review contract.
- **Never open `firmware/core/sensor_history_multi.h` in full.** Read fragment files or line ranges only.

### Standard Turn 3 output format

```
## Gate checklist — v7.6.X.X PR #NN

| Gate | Status | Evidence |
|------|--------|----------|
| [gate] | PASS/FAIL/UNCLEAR | [one-line evidence] |

## Reviewer finding assessment

| Finding | Warranted? | Fixed? | Remaining action |
|---------|------------|--------|-----------------|
| [finding] | Y/N | Y/N | [action or none] |

## Resolved vs. remaining
- Resolved: [list]
- Remaining: [list or "none"]

## Verdict
MERGE-READY / NEEDS-FIX / BLOCKED

## Fix list (if NEEDS-FIX or BLOCKED)
1. [specific fix]

## Post-merge deliverables (if MERGE-READY)
- [deliverable]
```

---

