# Phase V — Bug Escalation to Claude

## When to Use

Use this prompt when:
- An agent produces code that doesn't compile and you can't see why
- A device test crashes and the serial log doesn't make sense
- The pipeline passes but the behaviour is wrong
- You need to understand whether a problem is a prompt defect, a codebase issue, or an agent error

## Template

Paste the following into a Claude session (this project):

---

**Phase V Bug Escalation — v7.6.{x}.{y}**

**Step:** [version number and step ID, e.g., v7.6.7.1 / V1-D]

**What happened:**
[2-3 sentences describing the symptom]

**What I expected:**
[2-3 sentences describing the expected behaviour]

**Evidence:**
[Paste ONE of: serial log snippet, compiler error, curl output, Playwright failure, git diff excerpt]

**Agent used:** [GPT / Codex / Claude / Copilot]

**Files touched by the agent:**
[List from `git diff --name-only`]

**Questions:**
1. Is this a prompt defect (the instructions led to the wrong outcome)?
2. Is this a codebase issue (the code the agent was told to read doesn't match what's actually there)?
3. Is this an agent error (the agent deviated from the instructions)?
4. What's the fix?

---

Claude will diagnose, produce a fix (if possible), and recommend whether to:
- Patch the current PR and continue
- Revert and re-run the step with a corrected prompt
- Defer the issue to a later step

---

_End of bug escalation template._
