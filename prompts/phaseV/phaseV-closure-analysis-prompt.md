# Phase V — Closure Analysis Prompt

## When to Use

Run this prompt in a Claude session after the final Phase V step merges to main.

## Template

---

**Phase V Closure Analysis**

Please clone the repo and perform a closure analysis of Phase V (v7.6.7.0 through v7.6.9.x).

**Read in this order:**
1. `Docs/phase-V-implementation-plan.md` — the plan
2. `prompts/handoff/phaseV-results.md` — the results (fill this in before running this prompt)
3. All Phase V session logs in `Docs/` (session-log-*-v7.6.7.*, session-log-*-v7.6.8.*, session-log-*-v7.6.9.*)
4. All Phase V PRs (linked in the results document)
5. `prompts/handoff/phaseY/phaseY-closure-analysis.md` — Phase Y closure (structural template)

**Answer these questions:**

### 1. Plan Fidelity
- Was every planned step delivered? Which were deferred?
- Did any step require more than 2 fix cycles? Why?
- Were the version numbers and step groupings correct?

### 2. Implementation Quality
- Did any Critical Rule get violated? Which, and how was it caught?
- Were the acceptance criteria sufficient? Any that should have been more specific?
- Did the auth coverage table (SEC-ADR-001) match the actual post-V2 state?

### 3. Agent Execution Quality
- Compare GPT/Codex vs Claude execution: which steps went to which agent, and how many fix cycles?
- Did the GPT/Codex prompt adaptations (§2.1 of the addendum) work? What should change?
- Did the Perplexity review prompts catch issues the agents missed?

### 4. Documentation
- Are all new lessons numbered and indexed?
- Are all Critical Rules current?
- Is the handoff to Phase 7 complete?

### 5. Recommendations
- What should change for Phase 7 prompts?
- What lessons should be added?
- What Critical Rules should be added or modified?

**Output:** Produce a `Docs/phase-V-closure-analysis.md` document following the Phase Y closure analysis structure.

---

_End of closure analysis prompt._
