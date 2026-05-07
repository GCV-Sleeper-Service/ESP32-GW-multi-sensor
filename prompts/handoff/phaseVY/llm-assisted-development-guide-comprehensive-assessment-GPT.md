# Comprehensive Assessment of `Docs/llm-assisted-development-guide.md`

_Date prepared: 2026-05-06_  
_Source repository: `GCV-Sleeper-Service/ESP32-GW-multi-sensor`  
_Primary document assessed: `Docs/llm-assisted-development-guide.md` on `main`_  
_Supporting context reviewed: `prompts/handoff/phaseVY/phaseVY-results.md`, `Docs/development-process-guide.md`_  

---

## 0. Scope and Limitations

This assessment reviews the current `Docs/llm-assisted-development-guide.md` as a reusable methodology document for LLM-assisted development, with particular attention to how well it generalizes from the ESP32-GW Multi-Sensor Gateway project.

I was able to read the repository documents directly, but not the external Claude shared conversation. Any conclusions that depend on that Claude conversation are therefore out of scope. The analysis below is based on the repository documents and the project context available in this session.

Confidence level: **medium-high**.

The confidence is not absolute because I did not independently audit every PR, bug report, reviewer comment, or device log. However, the methodology document itself, the Phase VY closure document, and the development process guide are internally consistent enough to support a strong assessment.

---

## 1. Executive Summary

The `llm-assisted-development-guide.md` is a strong and unusually mature practitioner guide. It is not merely a collection of prompt-writing tips. It captures an emerging operational discipline for using LLMs in real engineering work, especially where mistakes affect firmware, device state, persistence, auth, and field stability.

The guide’s best insight is that LLM-assisted development is not “AI writes code for you.” It is **operator-directed engineering where AI amplifies the operator’s intent**, but only when the operator supplies accurate context, precise constraints, verification gates, and disciplined review.

The guide is already strong in five areas:

1. **Planning discipline** — phases, steps, bounded PRs, phase closure.
2. **Prompt discipline** — required reading, scope guards, checkpoints, acceptance criteria.
3. **Verification discipline** — pre-implementation checks, post-implementation checks, device testing.
4. **Review discipline** — multiple LLM reviewers, external review, consolidated audit.
5. **Knowledge discipline** — current-state file, stale-document recognition, recommendation tracking.

The main improvement area is **evidence discipline**. The guide says assumptions must be verified, but it does not yet define a full system for ranking evidence, tracking hypotheses, quantifying reviewer effectiveness, recording provenance, and retiring stale claims. This is the natural next maturity step.

My bottom-line assessment:

> The methodology is already good enough to be reused outside this project. With explicit evidence management, rollback planning, security-review gates, reviewer calibration, and prompt provenance, it could become a genuinely robust handbook for AI-assisted engineering governance.

---

## 2. High-Level Scorecard

| Area | Rating | Assessment |
|---|---:|---|
| Practicality | 9/10 | The advice is grounded in real repeated failures, not abstract theory. |
| Specificity | 9/10 | The guide gives concrete structures: prompt bundles, checkpoint rules, review flow, phase closure. |
| Engineering realism | 9/10 | It acknowledges hardware testing, long-duration failures, resource exhaustion, stale context, and generated artifacts. |
| Generalizability | 8/10 | Most principles transfer well beyond this ESP32 project, though examples are embedded-specific. |
| Evidence discipline | 6.5/10 | Strong warning against unchecked assumptions, but lacks a formal evidence hierarchy and hypothesis ledger. |
| Security discipline | 6/10 | Mentions auth-sensitive work indirectly, but security review should be first-class. |
| Rollback/recovery | 5.5/10 | Device testing is covered; rollback planning is underdeveloped. |
| Reviewer calibration | 6.5/10 | Multi-reviewer strategy is strong, but effectiveness measurement is not formalized enough. |
| Documentation architecture | 8/10 | Good layering concept; could be improved with source-of-truth conflict rules and document retirement policy. |
| Automation maturity | 7/10 | Identifies manual review orchestration as a bottleneck; should convert this into a tracked automation backlog. |

Overall rating: **8.2/10**.

This is a high rating. Most LLM-assisted development advice is vague, model-centric, or overly optimistic. This guide is process-centric and failure-driven, which is the correct orientation.

---

## 3. What the Guide Gets Right

### 3.1 It correctly defines the real role of LLMs

The guide states that LLM-assisted development is not simply “AI writes code.” That distinction matters. The failure mode in many AI-assisted projects is delegating engineering judgment to the model. This guide instead treats LLMs as accelerators inside a human-directed control system.

That framing is correct.

A better metaphor is:

> An LLM is a high-throughput junior-to-mid-level contributor with unusual breadth, poor persistence, weak self-verification, and dangerous confidence when context is stale.

The guide is aligned with that reality.

### 3.2 It focuses on failure modes, not vibes

The strongest methodology documents are built from real failures. This guide is clearly built from actual project pain:

- plausible explanations accepted without diagnostics
- postmortem recommendations forgotten
- files growing beyond useful context size
- stale prompts referring to obsolete paths
- agents silently “fixing” checkpoints
- over-documentation becoming harder to search than rewrite
- reviewers catching different classes of defects

That makes the guide much more valuable than a generic “how to prompt” document.

### 3.3 The checkpoint pattern is excellent

The checkpoint rules may be the highest-value section in the guide:

- use queries, not assertions
- use identifier anchors instead of brittle line numbers
- verify before modifying
- checkpoint failure means stop and report, not silently repair

This is a mature pattern because it turns prompts from prose into a lightweight verification harness.

A weak prompt says:

```text
Change the logic near line 1431.
```

A stronger prompt says:

```bash
grep -n "handle_aggregator_gateways_" firmware/core/*.h
grep -n "satellite_caches" firmware/core/*.h
```

Then it instructs the agent what to do only after those anchors are confirmed.

This reduces both stale-context failures and agent improvisation.

### 3.4 The “optimized prompt trap” is an important insight

The warning that LLMs often remove safety constraints when asked to “optimize” prompts is important. Many users assume a shorter, cleaner prompt is better. For code execution agents, that is often false.

The most valuable parts of an execution prompt are frequently the parts a model tries to trim:

- scope boundaries
- do-not lists
- checkpoint failure behavior
- device safety warnings
- generated-file warnings
- acceptance criteria
- rollback conditions
- exact commands

The guide is right to say that execution prompts should not be “optimized” by another LLM unless the safety-critical structure is preserved.

### 3.5 It treats documentation as an active control surface

The guide’s `CURRENT-STATE.md` pattern is especially strong. It solves a real LLM limitation: session memory is unreliable, fragmented, and often unavailable across tools.

The important insight is:

> Documentation only matters if it is placed where future decisions actually read it.

This is why the recommendation-tracking rule is also strong:

> Every recommendation becomes either an issue or an entry in a tracked list. No third option.

That one rule directly addresses a common failure: valuable postmortem lessons being archived but never operationalized.

### 3.6 It correctly treats device testing as non-negotiable

For embedded projects, no amount of static review replaces hardware testing. The guide recognizes that failures can depend on:

- board variant
- heap behavior
- stack watermark
- HTTP concurrency
- accumulated persistence data
- uptime
- flash layout
- OTA behavior
- browser interaction with device endpoints

The explicit warning against relying only on code review is correct.

### 3.7 It identifies the context-window cliff

The context-window cliff is real. As files grow, LLM agents often start making partial, locally plausible edits that break global invariants.

The guide’s recognition pattern is useful:

> If fix cycles suddenly increase from 0-1 to 3+, check whether target files have grown beyond practical LLM editing size.

That is a strong operational heuristic.

---

## 4. Main Weaknesses and Missing Concepts

The guide is strong, but not complete. The following gaps are significant.

---

### 4.1 Missing: formal evidence hierarchy

The guide repeatedly says to verify assumptions. That is good, but it should define what counts as strong evidence.

Without an evidence hierarchy, several kinds of claims can be accidentally treated as equivalent:

- direct device measurement
- compiler output
- grep result
- current documentation
- old handoff
- model inference
- operator memory
- plausible explanation

These are not equally reliable.

A technical decision that affects production firmware should not rest on the same evidence standard as a planning hypothesis.

Recommended addition:

```md
### Evidence Hierarchy

When making a technical claim, classify its basis:

| Level | Evidence Type | Example | Suitable Use |
|---|---|---|---|
| 1 | Direct measurement | curl output, compiler log, telemetry, device logs | Production-impacting decisions |
| 2 | Source inspection | grep result, test output, static analysis | Implementation planning and review |
| 3 | Current documentation | CURRENT-STATE.md, decision log, current phase plan | Planning, if recently verified |
| 4 | Historical documentation | old handoff, archived postmortem, older phase plan | Context only; must be revalidated |
| 5 | Human memory | operator recollection, prior conversation memory | Useful clue; not sufficient alone |
| 6 | Model inference | plausible explanation not yet verified | Hypothesis only |

Rules:
- Production-impacting decisions require Level 1 or Level 2 evidence.
- Planning can use Level 3 evidence if the document is current.
- Level 4 evidence is historical context, not instruction.
- Level 5 and Level 6 claims must be labeled as unverified until tested.
```

Why this matters:

The BUG-083 pattern appears to have been caused by a plausible model explanation being accepted before a simple diagnostic command. A formal evidence hierarchy would make that harder.

---

### 4.2 Missing: debugging hypothesis ledger

The guide warns against plausible narratives, but complex debugging needs an artifact.

A recommended lightweight structure:

```md
### Debugging Hypothesis Ledger

For any investigation lasting more than 30 minutes, maintain:

| ID | Hypothesis | Evidence For | Evidence Against | Test Command | Result | Status |
|---|---|---|---|---|---|---|
| H1 | httpd stack differs by board architecture | C3 watermark differs | No config audit yet | grep web_server_idf config | Pending | Open |
| H2 | board missing stack override block | known local override pattern | not checked yet | grep external_components firmware/*.yaml | Pending | Open |

Rules:
- Test the simplest falsifiable hypothesis first.
- Do not add a sophisticated explanation until simpler checks are done.
- Close hypotheses explicitly as confirmed, falsified, or still open.
- If no direct test exists, record the hypothesis as unverified.
```

This improves debugging because it forces separation between:

- observation
- interpretation
- test
- conclusion

That separation is where LLMs frequently fail.

---

### 4.3 Missing: source-of-truth hierarchy

The methodology now has many documents. When they conflict, future agents need a deterministic rule for which source wins.

Recommended addition:

```md
### Source-of-Truth Hierarchy

When sources disagree, use this order:

1. Live code on `main`
2. Build, test, telemetry, and device output
3. `CURRENT-STATE.md`
4. Decision log
5. Current phase implementation plan
6. Current step prompt and handoff
7. Changelog
8. Recent phase closure
9. Historical postmortems and archived handoffs
10. Model memory or conversational memory

Rules:
- Archived documents are evidence, not instructions.
- Any plan older than the last major refactor must be treated as stale until verified.
- Generated artifacts are never the source of truth when source fragments exist.
```

This should be added because the project already experienced stale plan references and generated artifact confusion.

---

### 4.4 Missing: rollback and recovery protocol

For an embedded project, this is one of the largest gaps.

The guide discusses device testing and OTA upload, but does not define what to do when a deployment fails or corrupts state.

Recommended addition:

```md
### Rollback Protocol

Before high-risk firmware, persistence, auth, OTA, or partition changes:

1. Record the currently running version and commit SHA.
2. Confirm the previous known-good firmware artifact is available.
3. Confirm physical or network recovery path:
   - OTA reachable?
   - USB flash available?
   - device accessible via local network?
4. Export or preserve user data if persistence may be affected.
5. Define rollback command.
6. Define failure symptoms that trigger rollback.
7. After deployment, verify:
   - boot
   - `/api/status`
   - authenticated status endpoint
   - dashboard load
   - memory baseline
   - persistence behavior if applicable
8. Record rollback result or no-rollback-needed result in the PR.
```

Risk areas requiring rollback planning:

- NVS schema changes
- partition table changes
- OTA changes
- auth changes
- destructive endpoints
- history import/export
- device provisioning
- Wi-Fi/captive portal changes
- BLE scanning changes that could starve other tasks

---

### 4.5 Missing: security-review gates

The guide mentions auth-sensitive examples, but security should be a first-class methodology section.

This project has management endpoints, Basic Auth, exposed dashboards, potential reverse proxy/tunnel access, destructive operations, and future provisioning/import/export features. Those are security-relevant.

Recommended addition:

```md
### Security Review Gate

Any step touching the following areas is security-sensitive:

- authentication
- authorization
- credentials
- destructive endpoints
- OTA/update paths
- import/export
- persistence mutation
- provisioning/captive portal
- network exposure
- cloud upload
- browser-side credential handling

Required checks:
1. Is the endpoint public, authenticated, or management-only?
2. Can the operation change device state?
3. Can it delete, overwrite, or export data?
4. Does the dashboard send credentials safely?
5. Are errors non-leaky?
6. Is CORS behavior intentional?
7. Is rate limiting or abuse resistance needed?
8. Are secrets absent from prompts, logs, screenshots, and committed files?
9. Does the review prompt include abuse cases, not only happy paths?
```

This is not overkill. A small embedded device exposed through a tunnel can still have real operational risk.

---

### 4.6 Missing: reviewer effectiveness measurement

The guide says multiple reviewers catch different defect categories. That is likely true. But the exact effectiveness percentages should be tracked as project-specific observations, not treated as general facts.

Recommended addition:

```md
### Reviewer Calibration

For each PR, record each non-trivial review finding:

| Finding | Reviewer | Category | Severity | True Positive? | Duplicate? | Prompt-Preventable? | Fixed? |
|---|---|---|---:|---|---|---|---|

At phase closure, summarize:

- unique true positives by reviewer
- false positives by reviewer
- duplicated findings
- severe issues missed by all reviewers
- categories each reviewer catches best
- categories that need better prompt/checkpoint coverage
```

Reviewer calibration prevents multi-reviewer orchestration from becoming a ritual. It answers:

- Which reviewers are adding unique value?
- Which reviewers mostly duplicate others?
- Which reviewers generate expensive false positives?
- Which defect classes are still escaping all review?

---

### 4.7 Missing: reviewer disagreement protocol

Multiple reviewers are useful, but disagreement is inevitable.

Recommended addition:

```md
### Reviewer Disagreement Protocol

When reviewers disagree:

1. Reproduce or inspect the claim directly.
2. Classify each finding:
   - confirmed defect
   - valid risk, not immediate defect
   - style preference
   - false positive
   - requires operator decision
3. Do not blindly fix contradictory recommendations.
4. Record the final disposition in the consolidated audit.
5. If the disagreement reveals ambiguous project policy, update the relevant guide or decision log.
```

This matters because accepting every reviewer suggestion can produce churn and sometimes worse code.

---

### 4.8 Missing: risk-tiered execution workflow

The guide recommends more reviewers for high-risk steps, but it would benefit from a formal risk tier model.

Recommended addition:

```md
### Risk-Tiered Workflow

| Risk Tier | Examples | Required Gates |
|---|---|---|
| Low | docs, comments, cosmetic UI | normal review, no device test unless relevant |
| Medium | dashboard logic, non-destructive API, test changes | CI, 3 reviewers, focused acceptance checks |
| High | NVS writes, auth, new API endpoints, OTA-adjacent changes, BLE scan behavior | CI, 5 reviewers, device test, rollback plan |
| Critical | partition table, persistence migration, destructive endpoint changes, provisioning, data import | pre-mortem, backup/export, 5 reviewers, device test on representative boards, explicit operator approval |
```

The advantage of this model is that the process becomes efficient without becoming lax. Low-risk changes do not need heavyweight ceremony; high-risk changes cannot bypass safeguards.

---

### 4.9 Missing: prompt provenance

When a PR introduces a defect, it is valuable to know whether the problem came from:

- stale plan
- weak prompt
- agent deviation
- reviewer miss
- operator change
- model/tool limitation
- unverified assumption

The current guide has prompt bundles, but it should add provenance requirements.

Recommended addition:

```md
### Prompt Provenance

Every non-trivial PR description should include:

- agent prompt path
- review prompt path
- handoff path
- source commit used when the prompt was written
- source commit used when the agent executed
- model/tool used for implementation
- model/tool versions if available
- whether the prompt was modified before execution
- list of failed or skipped checkpoints
```

This creates traceability from plan to prompt to PR.

---

### 4.10 Missing: model and tool drift management

LLM tools change. Copilot, Codex, Claude, Gemini, Perplexity, and other systems can change behavior without project-level notice.

Recommended addition:

```md
### Model and Tool Drift

At each phase closure, record:

- implementation tool used
- reviewer tools used
- notable behavior changes
- recurring false positives
- recurring missed defect types
- whether instruction files appear to be consumed
- any model/tool that should be removed, replaced, or assigned a narrower role

If a reviewer stops catching known defect classes or stops following project instructions, recalibrate prompts or change the reviewer mix.
```

The project already checks whether instruction files are being consumed. This should be generalized into a tool drift control.

---

### 4.11 Missing: test data realism

The guide acknowledges long-duration device failures, but persistence/history features need a stronger test-data doctrine.

Recommended addition:

```md
### Test Data Realism

For features involving persistence, history, import/export, API payloads, or dashboards, test with:

- empty data
- one sensor
- normal configured sensor count
- maximum supported sensor count
- malformed records
- missing fields
- duplicate timestamps
- out-of-order timestamps
- large history near retention limit
- multi-week accumulated data
- interrupted write/reboot scenario
- concurrent clients
- slow network behavior
- browser reload during active operation
```

This matters because several embedded/dashboard bugs only appear with accumulated data, large payloads, or multi-client load.

---

### 4.12 Missing: automation backlog

The guide says manual review orchestration is a bottleneck. That should become a tracked backlog.

Recommended addition:

```md
### Automation Backlog

Track repeated manual work:

| Manual Task | Frequency | Time Cost | Risk if Skipped | Automation Candidate | Priority |
|---|---:|---:|---|---|---|

Prioritize automation when:

- the task occurs every PR or every phase
- skipping it causes defects
- results can be machine-checked
- the automation is less risky than manual repetition
```

Examples for this project:

- generating reviewer prompt bundles
- posting standard PR comments
- collecting review findings
- calculating fix cycles
- verifying prompt anchors
- checking stale file paths
- validating `CURRENT-STATE.md` was updated
- checking docs-only CI path filtering
- summarizing reviewer true-positive rates

---

### 4.13 Missing: documentation retirement policy

The guide correctly warns about over-documentation. The next step is to define when documents are retired, summarized, archived, or deleted.

Recommended addition:

```md
### Documentation Retirement Policy

At phase closure, classify documents:

| Status | Meaning | Action |
|---|---|---|
| Active | Must be read by future sessions | Keep short and current |
| Reference | Useful when working in a specific area | Link from active docs |
| Historical | Useful only for investigation | Archive with warning banner |
| Superseded | Replaced by newer source | Add pointer to replacement |
| Obsolete | No longer accurate or useful | Delete or archive with explicit warning |

Rules:
- Any stale plan must have a visible warning at the top.
- Archived documents must not be listed as required reading unless the prompt explains why.
- `CURRENT-STATE.md` should link to stale documents only to warn against using them uncritically.
```

This would help prevent the “documentation drift” and “over-documentation trap” described in the guide.

---

### 4.14 Missing: decision lifecycle

The guide mentions a decision log, but architectural decisions need status.

Recommended addition:

```md
### Decision Lifecycle

Every architectural decision should have a status:

- Proposed
- Accepted
- Superseded
- Rejected
- Deprecated
- Needs revalidation

Decision entries should include:

- decision
- rationale
- date
- affected files/components
- evidence used
- known tradeoffs
- revisit trigger
```

The revisit trigger is especially important. Example:

> Revisit if firmware grows beyond 90% of OTA partition or if non-PSRAM board min heap drops below threshold.

---

### 4.15 Missing: operator workload and cognitive-load controls

The methodology asks a lot of the operator. That may be necessary, but operator fatigue becomes a risk.

Recommended addition:

```md
### Operator Workload Controls

Track:

- number of active PRs
- number of unresolved review findings
- number of open recommendations
- number of stale documents
- number of manual orchestration tasks per step

Rules:
- Do not start a high-risk step while unresolved high-severity review findings exist.
- Do not run more parallel tracks than the operator can review.
- If review orchestration becomes the bottleneck for more than one phase, automate before expanding scope.
```

The methodology is strong, but if it depends too heavily on one human operator remembering and coordinating everything, it can fail under load.

---

## 5. Suggested Structural Changes to the Guide

The current guide is organized as:

```text
1. Fundamental Reality
2. Planning Phase
3. Prompt Engineering
4. Multi-LLM Workflow
5. Execution and Review
6. Pitfall Patterns
7. Continuous Improvement
Appendix A/B
```

That is good. I would keep it.

But I would add or expand sections as follows:

```text
1. Fundamental Reality of LLM-Assisted Development
2. Planning Phase
   2.1 Phase Architecture
   2.2 Assumption Audit
   2.3 Evidence Discipline              <-- add
   2.4 Pre-Mortem Thinking
   2.5 Current State Document
   2.6 Source-of-Truth Hierarchy         <-- add
3. Prompt Engineering
   3.1 Three-Prompt Bundle
   3.2 Prompt Anatomy
   3.3 Checkpoint Design
   3.4 Stale Prompt Problem
   3.5 Prompt Provenance                 <-- add
4. Multi-LLM Workflow
   4.1 Role Assignment
   4.2 Why Multiple Reviewers Matter
   4.3 Reviewer Calibration              <-- add
   4.4 Reviewer Disagreement Protocol    <-- add
   4.5 Optimized Prompt Trap
   4.6 Model and Tool Drift              <-- add
   4.7 Cost Optimization
5. Execution and Review
   5.1 Agent Setup Protocol
   5.2 Review Orchestration
   5.3 Risk-Tiered Workflow              <-- add
   5.4 Device Testing
   5.5 Rollback Protocol                 <-- add
   5.6 Security Review Gate              <-- add
   5.7 Test Data Realism                 <-- add
6. Pitfall Patterns and Early Recognition
   Existing sections
   6.6 Blind Reviewer Consensus          <-- add
   6.7 Process Ritual Without Measurement <-- add
7. Continuous Improvement
   Existing sections
   7.4 Automation Backlog                <-- add
   7.5 Documentation Retirement Policy   <-- add
   7.6 Decision Lifecycle                <-- add
8. Appendices
   Appendix A: Glossary
   Appendix B: New Project Checklist
   Appendix C: Copy-Ready Templates       <-- add
```

---

## 6. Recommended Copy-Ready Additions

The following sections can be pasted directly into the guide with light editing.

---

### 6.1 Add after Section 2.2: Evidence Discipline

```md
### 2.3 Evidence Discipline

LLM-assisted development fails when hypotheses, documentation, memory, and measured facts are treated as equally reliable. Every non-trivial technical claim should be classified by evidence level.

| Level | Evidence Type | Example | Suitable Use |
|---|---|---|---|
| 1 | Direct measurement | curl output, compiler log, device telemetry, runtime logs | Production-impacting decisions |
| 2 | Source inspection | grep result, test output, static analysis, generated artifact diff | Implementation planning and review |
| 3 | Current documentation | CURRENT-STATE.md, decision log, current phase plan | Planning, if recently verified |
| 4 | Historical documentation | archived handoff, old postmortem, previous phase plan | Context only; must be revalidated |
| 5 | Human memory | operator recollection, previous conversation memory | Useful clue; not sufficient alone |
| 6 | Model inference | plausible explanation not yet verified | Hypothesis only |

Rules:

- Production-impacting decisions require Level 1 or Level 2 evidence.
- Planning may use Level 3 evidence if the document is current.
- Level 4 evidence is historical context, not instruction.
- Level 5 and Level 6 claims must be labeled as unverified until tested.
- If a claim cannot be verified, record it as an `UNVERIFIED ASSUMPTION`.

For debugging sessions lasting more than 30 minutes, maintain a hypothesis ledger:

| ID | Hypothesis | Evidence For | Evidence Against | Test Command | Result | Status |
|---|---|---|---|---|---|---|

Test the simplest falsifiable hypothesis first. Do not accept a sophisticated explanation until simple diagnostics have ruled out simpler causes.
```

---

### 6.2 Add after Current State Document: Source-of-Truth Hierarchy

```md
### 2.5 Source-of-Truth Hierarchy

When sources disagree, use this order:

1. Live code on `main`
2. Build, test, telemetry, and device output
3. `CURRENT-STATE.md`
4. Decision log
5. Current phase implementation plan
6. Current step prompt and handoff
7. Changelog
8. Recent phase closure
9. Historical postmortems and archived handoffs
10. Model memory or conversational memory

Rules:

- Archived documents are evidence, not instructions.
- Any plan older than the last major refactor must be treated as stale until verified.
- Generated artifacts are never the source of truth when source fragments exist.
- If the source-of-truth hierarchy produces an unexpected answer, verify it with a direct command before changing code.
```

---

### 6.3 Add to Prompt Engineering: Prompt Provenance

```md
### 3.5 Prompt Provenance

Every non-trivial PR should record which prompt and context produced it. This makes defects traceable to planning, prompt authoring, agent execution, review, or operator decisions.

PR descriptions should include:

- agent prompt path
- review prompt path
- handoff path
- source commit used when the prompt was written
- source commit used when the agent executed
- model/tool used for implementation
- model/tool versions if available
- whether the prompt was modified before execution
- failed, skipped, or manually overridden checkpoints

If a later bug appears, the postmortem should be able to answer:

1. Was the plan stale?
2. Was the prompt missing a guard?
3. Did the agent violate the prompt?
4. Did review miss the issue?
5. Did operator context differ from repository context?
```

---

### 6.4 Add to Multi-LLM Workflow: Reviewer Calibration

```md
### 4.3 Reviewer Calibration

Multiple reviewers only help if their findings are measured. For each non-trivial review finding, record:

| Finding | Reviewer | Category | Severity | True Positive? | Duplicate? | Prompt-Preventable? | Fixed? |
|---|---|---|---:|---|---|---|---|

At phase closure, summarize:

- unique true positives by reviewer
- false positives by reviewer
- duplicated findings
- severe findings missed by all reviewers
- defect categories each reviewer catches best
- defect categories that need better prompt/checkpoint coverage

Use this data to adjust reviewer assignment. Do not assume reviewer count equals review quality.
```

---

### 6.5 Add to Multi-LLM Workflow: Reviewer Disagreement Protocol

```md
### 4.4 Reviewer Disagreement Protocol

When reviewers disagree:

1. Reproduce or inspect the claim directly.
2. Classify each finding:
   - confirmed defect
   - valid risk, not immediate defect
   - style preference
   - false positive
   - requires operator decision
3. Do not blindly fix contradictory recommendations.
4. Record final disposition in the consolidated audit.
5. If disagreement reveals an ambiguous project policy, update the relevant guide, decision log, or prompt rule.

Multi-reviewer workflows are valuable because reviewers disagree. The disagreement must be resolved with evidence, not majority vote.
```

---

### 6.6 Add to Execution and Review: Risk-Tiered Workflow

```md
### 5.3 Risk-Tiered Workflow

Not every change needs the same process weight. Use risk tiers to match review depth to failure cost.

| Risk Tier | Examples | Required Gates |
|---|---|---|
| Low | docs, comments, cosmetic UI | normal review; no device test unless relevant |
| Medium | dashboard logic, non-destructive API, test changes | CI, 3 reviewers, focused acceptance checks |
| High | NVS writes, auth, new API endpoints, OTA-adjacent changes, BLE scan behavior | CI, 5 reviewers, device test, rollback plan |
| Critical | partition table, persistence migration, destructive endpoints, provisioning, data import | pre-mortem, backup/export, 5 reviewers, representative-device test, explicit operator approval |

The goal is not more ceremony. The goal is matching safeguards to operational risk.
```

---

### 6.7 Add to Execution and Review: Rollback Protocol

```md
### 5.5 Rollback Protocol

Before high-risk firmware, persistence, auth, OTA, or partition changes:

1. Record the currently running version and commit SHA.
2. Confirm the previous known-good firmware artifact is available.
3. Confirm physical or network recovery path:
   - OTA reachable?
   - USB flash available?
   - device accessible via local network?
4. Export or preserve user data if persistence may be affected.
5. Define rollback command.
6. Define failure symptoms that trigger rollback.
7. After deployment, verify:
   - boot
   - `/api/status`
   - authenticated status endpoint
   - dashboard load
   - memory baseline
   - persistence behavior if applicable
8. Record rollback result or no-rollback-needed result in the PR.

A deployment plan without a rollback path is incomplete for embedded work.
```

---

### 6.8 Add to Execution and Review: Security Review Gate

```md
### 5.6 Security Review Gate

Any step touching the following areas is security-sensitive:

- authentication
- authorization
- credentials
- destructive endpoints
- OTA/update paths
- import/export
- persistence mutation
- provisioning/captive portal
- network exposure
- cloud upload
- browser-side credential handling

Required checks:

1. Is the endpoint public, authenticated, or management-only?
2. Can the operation change device state?
3. Can it delete, overwrite, or export data?
4. Does the dashboard send credentials safely?
5. Are errors non-leaky?
6. Is CORS behavior intentional?
7. Is rate limiting or abuse resistance needed?
8. Are secrets absent from prompts, logs, screenshots, and committed files?
9. Does the review prompt include abuse cases, not only happy paths?

Security-sensitive steps should use the high-risk or critical workflow tier.
```

---

### 6.9 Add to Execution and Review: Test Data Realism

```md
### 5.7 Test Data Realism

For features involving persistence, history, import/export, API payloads, or dashboards, test with realistic and adversarial data:

- empty data
- one sensor
- normal configured sensor count
- maximum supported sensor count
- malformed records
- missing fields
- duplicate timestamps
- out-of-order timestamps
- large history near retention limit
- multi-week accumulated data
- interrupted write/reboot scenario
- concurrent clients
- slow network behavior
- browser reload during active operation

Bugs that do not appear in small synthetic data often appear immediately with real accumulated device history.
```

---

### 6.10 Add to Continuous Improvement: Automation Backlog

```md
### 7.4 Automation Backlog

Track repeated manual work:

| Manual Task | Frequency | Time Cost | Risk if Skipped | Automation Candidate | Priority |
|---|---:|---:|---|---|---|

Prioritize automation when:

- the task occurs every PR or every phase
- skipping it causes defects
- results can be machine-checked
- automation is less risky than manual repetition

Common candidates:

- verifying prompt anchors against live code
- posting standard PR review requests
- collecting review findings
- calculating fix cycles
- checking `CURRENT-STATE.md` updates
- checking stale file paths
- generating phase closure KPI tables
```

---

### 6.11 Add to Continuous Improvement: Documentation Retirement Policy

```md
### 7.5 Documentation Retirement Policy

At phase closure, classify documents:

| Status | Meaning | Action |
|---|---|---|
| Active | Must be read by future sessions | Keep short and current |
| Reference | Useful when working in a specific area | Link from active docs |
| Historical | Useful only for investigation | Archive with warning banner |
| Superseded | Replaced by newer source | Add pointer to replacement |
| Obsolete | No longer accurate or useful | Delete or archive with explicit warning |

Rules:

- Any stale plan must have a visible warning at the top.
- Archived documents must not be listed as required reading unless the prompt explains why.
- `CURRENT-STATE.md` should link to stale documents only to warn against using them uncritically.
- If a lesson cannot be found within 30 seconds, the documentation is organized for writing, not retrieval.
```

---

### 6.12 Add to Continuous Improvement: Decision Lifecycle

```md
### 7.6 Decision Lifecycle

Every architectural decision should have a lifecycle status:

- Proposed
- Accepted
- Superseded
- Rejected
- Deprecated
- Needs revalidation

Decision entries should include:

- decision
- rationale
- date
- affected files/components
- evidence used
- known tradeoffs
- revisit trigger

Example revisit triggers:

- firmware exceeds 90% of OTA partition
- non-PSRAM board minimum heap falls below threshold
- a generated file becomes too large for reliable review
- a new ESPHome version changes component defaults
- a reviewer repeatedly flags the same architectural issue
```

---

## 7. Recommended Prioritized Improvement Plan

Not all improvements need to happen at once. I would apply them in this order.

---

### Priority 1 — Add evidence discipline and source-of-truth hierarchy

Why first:

- Directly addresses the most expensive failure pattern.
- Requires only documentation changes.
- Improves every future planning, debugging, and review session.

Files likely affected:

- `Docs/llm-assisted-development-guide.md`
- `Docs/development-process-guide.md`
- prompt writing guide / templates, if separate

Expected benefit:

- Fewer plausible-but-wrong explanations.
- Better debugging discipline.
- Clearer distinction between measured facts and model hypotheses.

---

### Priority 2 — Add rollback protocol for high-risk embedded changes

Why second:

- Phase 7 is expected to touch persistence and streaming.
- Future phases may touch provisioning, import/export, and cloud upload.
- Rollback planning is central to safe embedded development.

Files likely affected:

- `Docs/llm-assisted-development-guide.md`
- `Docs/development-process-guide.md`
- future Phase 7 prompts
- high-risk prompt template

Expected benefit:

- Reduced risk from OTA, persistence, and partition-related work.
- Better operator confidence during device testing.

---

### Priority 3 — Add risk-tiered workflow and security review gate

Why third:

- Prevents under-reviewing high-risk work.
- Prevents over-burdening low-risk work.
- Makes security-sensitive changes explicit.

Expected benefit:

- More efficient review pipeline.
- Fewer auth, endpoint, and destructive-action regressions.

---

### Priority 4 — Add reviewer calibration

Why fourth:

- Multi-reviewer workflow is already in use.
- Calibration turns it from ritual into measured process.
- Helps decide which reviewers are worth using for which defect classes.

Expected benefit:

- Lower false-positive burden.
- Better reviewer assignment.
- More accurate process KPIs.

---

### Priority 5 — Add prompt provenance

Why fifth:

- Useful for postmortems and prompt improvement.
- Low implementation cost.
- Helps isolate whether defects came from plan, prompt, agent, or review.

Expected benefit:

- Better root cause analysis.
- Easier prompt template improvement.

---

### Priority 6 — Add documentation retirement policy

Why sixth:

- The project already has significant documentation volume.
- Without retirement, the documentation corpus can become a liability.

Expected benefit:

- Less stale-context risk.
- Lower session context burden.
- Easier onboarding for future agents.

---

## 8. Specific Assessment of Existing Sections

### 8.1 Preface

Strong. It establishes that recommendations are based on real experience across many phases, PRs, and models.

Suggested improvement:

Add one sentence clarifying that the guide is **evidence-informed but project-specific**, and that numerical claims should be treated as observed project baselines unless separately measured elsewhere.

Example:

```md
Where numeric values are provided, treat them as observed project baselines unless a broader dataset is cited.
```

---

### 8.2 Section 1 — Fundamental Reality

Strongest part:

- It correctly separates LLM strengths and weaknesses.
- It frames LLMs as amplifiers, not replacements.

Suggested improvement:

Add “LLMs are weak at evidence ranking” to the weakness list.

Suggested text:

```md
LLMs are also weak at ranking evidence quality. They may present a grep result, stale documentation, and an inferred explanation with similar confidence unless the prompt forces evidence classification.
```

---

### 8.3 Section 2 — Planning Phase

Strongest part:

- Assumption audit.
- Pre-mortem thinking.
- Current-state file.

Suggested improvement:

This section should gain the evidence hierarchy and source-of-truth hierarchy.

Planning is where bad assumptions are most expensive. A bad assumption in planning propagates into every downstream prompt.

---

### 8.4 Section 3 — Prompt Engineering

Strongest part:

- Prompt anatomy.
- Checkpoint design.
- Stale prompt mitigation.

Suggested improvement:

Add prompt provenance. The methodology already treats prompts as first-class artifacts; the next step is traceability from prompt to PR outcome.

Also consider adding “prompt diff review” for high-risk steps:

```md
For high-risk prompts, review changes to the prompt itself before giving it to the execution agent.
```

This prevents a prompt producer from accidentally omitting critical safety constraints.

---

### 8.5 Section 4 — Multi-LLM Workflow

Strongest part:

- Role assignment.
- Multi-reviewer rationale.
- Warning against optimized prompt variants.

Suggested improvement:

Add reviewer calibration and disagreement protocol. Multi-reviewer review is powerful, but it must not become “accept all comments from all models.”

Also, the table assigning best-fit models should be treated carefully because model availability and performance change over time. A short caveat would help:

```md
Model names and relative strengths are time-sensitive. Revalidate role assignments when model behavior, tool access, or pricing changes.
```

---

### 8.6 Section 5 — Execution and Review

Strongest part:

- Agent setup protocol.
- Review orchestration.
- Device testing.

Suggested improvement:

Add rollback, risk tiers, security review, and test data realism.

This section is where the methodology most needs project-safety controls. The existing testing guidance is good but not enough for persistence, auth, OTA, and destructive operations.

---

### 8.7 Section 6 — Pitfall Patterns

Strongest part:

- Plausible narrative trap.
- Forgotten recommendation.
- Context window cliff.
- Documentation drift.
- Over-documentation trap.

Suggested additional pitfall patterns:

#### Blind Reviewer Consensus

```md
Pattern: Several reviewers agree on a plausible finding, so the operator accepts it without direct verification.

Risk: Multi-reviewer agreement can still be wrong if all reviewers share the same stale context or incorrect assumption.

Prevention: For high-impact findings, consensus is not evidence. Verify with source inspection, test output, or device measurement.
```

#### Process Ritual Without Measurement

```md
Pattern: The team continues using a process because it feels disciplined, but no longer measures whether it catches defects.

Risk: Ceremony grows while defect prevention stagnates.

Prevention: Track true positives, false positives, fix cycles, checkpoint saves, and prompt-preventable findings.
```

#### Local Fix, Global Regression

```md
Pattern: Agent fixes the exact review comment but misses adjacent invariants.

Risk: Review-driven patching can make the local symptom disappear while leaving the broader design issue.

Prevention: Every fix to a review finding should include an adjacency check: what nearby code follows the same pattern?
```

---

### 8.8 Section 7 — Continuous Improvement

Strongest part:

- Phase closure protocol.
- KPI tracking.
- Evidence-driven process updates.

Suggested improvement:

The KPIs should include source and confidence.

Example:

```md
| KPI | Value | Source | Confidence |
|---|---:|---|---|
| Fix cycles/step | 0.5 | PR commit history | High |
| Wall-clock/step | ~2.5h | operator estimate | Medium |
| Preventable findings | 3 | consolidated audit | Medium |
```

This prevents rough estimates from being treated as precise measurements.

---

## 9. Suggested KPI Additions

The current KPI set is good but incomplete. I recommend adding:

| KPI | What it Measures | Why It Matters |
|---|---|---|
| Reviewer true-positive rate | quality of reviewers | identifies useful vs noisy reviewers |
| Reviewer unique-finding rate | non-duplicated reviewer value | supports reviewer selection |
| False-positive handling time | review overhead | detects review noise |
| Stale-reference count per prompt | prompt freshness | detects stale prompt risk |
| Unverified-assumption count | planning risk | detects weak evidence discipline |
| Rollback readiness | deployment safety | high-risk embedded requirement |
| Documentation retrieval time | doc usability | detects over-documentation |
| Prompt provenance completeness | traceability | improves postmortems |
| Automation candidate count | process friction | identifies repeatable manual work |
| Security-sensitive PR count | risk exposure | ensures proper review gates |

Recommended phase closure KPI table:

```md
| KPI | Value | Source | Confidence | Trend | Action |
|---|---:|---|---|---|---|
| Fix cycles/step | 0.6 | PR history | High | down | continue checkpoint pattern |
| Preventable findings | 2 | consolidated audits | Medium | flat | update prompt template |
| Unverified assumptions | 1 | planning audit | Medium | down | add evidence table |
| Reviewer false positives | 5 | review calibration sheet | Medium | up | adjust reviewer prompt |
```

---

## 10. Recommended Phase 7-Specific Application

Given the project’s expected next direction, the guide improvements should be applied before or during Phase 7 planning.

Phase 7 appears to involve high-risk areas:

- persistence engine
- chunked streaming
- accumulated history data
- production board crashes
- non-PSRAM constraints
- long-duration behavior
- likely NVS changes
- API/dashboard integration

Recommended Phase 7 controls:

1. Add evidence hierarchy before Phase 7 prompts are written.
2. Require hypothesis ledger for BUG-082/streaming investigation if it becomes non-trivial.
3. Require rollback plan for any persistence or NVS schema change.
4. Require large-history test data.
5. Require representative-board testing:
   - C3 SuperMini
   - WROOM-32D
   - S3 aggregator if aggregator behavior is affected
6. Require source-of-truth audit against current generated/source file architecture.
7. Require reviewer calibration starting with Phase 7 PRs.
8. Require prompt provenance in every Phase 7 PR description.

---

## 11. Potential Risks in Applying These Improvements

### Risk 1: Methodology becomes too heavy

Adding more controls can slow development if applied uniformly.

Mitigation:

Use risk tiers. Low-risk docs changes should not need rollback plans or five reviewers.

### Risk 2: Evidence tracking becomes bureaucratic

A full hypothesis ledger for every small bug would be excessive.

Mitigation:

Trigger the ledger only when debugging lasts more than 30 minutes or when a claim affects production behavior.

### Risk 3: Reviewer calibration becomes another manual chore

Tracking every tiny style comment would be noisy.

Mitigation:

Track only non-trivial findings:
- correctness
- safety
- security
- performance
- maintainability
- test gaps
- prompt-preventable issues

### Risk 4: Documentation grows again

Ironically, adding methodology sections can worsen the over-documentation problem.

Mitigation:

Add a documentation retirement policy at the same time. Keep the guide compact; move templates to appendices.

---

## 12. Recommended Final Form of the Guide

The guide should remain a practitioner guide, not become an encyclopedia. My recommendation:

- Keep the main body concise.
- Add critical controls to the main body.
- Move templates to appendices.
- Keep project-specific examples, but mark general rules clearly.
- Add a “what to do tomorrow” checklist.

Suggested final appendices:

```text
Appendix A: Glossary
Appendix B: Template Checklist for New LLM-Assisted Project
Appendix C: Evidence and Hypothesis Templates
Appendix D: Risk-Tiered Review Matrix
Appendix E: Reviewer Calibration Table
Appendix F: Rollback Checklist
Appendix G: Security Review Checklist
```

---

## 13. Concise List of Recommended Changes

If only a short PR is desired, implement these first:

1. Add **Evidence Discipline** section.
2. Add **Source-of-Truth Hierarchy** section.
3. Add **Rollback Protocol** section.
4. Add **Security Review Gate** section.
5. Add **Reviewer Calibration** section.
6. Add **Risk-Tiered Workflow** section.
7. Add **Prompt Provenance** section.
8. Add **Test Data Realism** section.
9. Add **Documentation Retirement Policy** section.
10. Add KPI `Source` and `Confidence` columns.

If I had to choose only three:

1. Evidence Discipline
2. Rollback Protocol
3. Reviewer Calibration

Those three would likely provide the highest defect-prevention value per documentation change.

---

## 14. Final Assessment

The current `llm-assisted-development-guide.md` is already a strong document. It captures a meaningful shift from “using AI to code faster” to “building an AI-assisted engineering system.”

The most important thing it gets right is that LLM development quality is determined less by model cleverness and more by:

- current context
- scoped intent
- verification checkpoints
- human judgment
- review diversity
- measured process improvement

The main thing it still needs is stronger **evidence governance**:

- classify evidence
- track hypotheses
- require rollback paths
- calibrate reviewers
- record prompt provenance
- define security gates
- retire stale documents

With those additions, the methodology would become significantly harder to derail by stale context, confident model inference, ritualized review, or documentation drift.

My final recommendation:

> Treat the current guide as a strong v1.0. Update it to v1.1 by adding evidence discipline, rollback/security gates, reviewer calibration, and prompt provenance before Phase 7 implementation begins.

---

## Appendix A — Proposed New Checklist: Before Planning a Phase

```md
## Pre-Planning Evidence Checklist

Before producing a phase plan:

1. Read `CURRENT-STATE.md`.
2. Verify repo version with `cat VERSION`.
3. Verify referenced file paths exist.
4. Verify referenced functions/classes exist with `grep`.
5. Check unimplemented recommendations.
6. Check stale documents list.
7. Check recent bug/postmortem records.
8. Identify high-risk areas:
   - auth
   - persistence
   - OTA
   - partition table
   - destructive endpoints
   - provisioning
   - import/export
9. List assumptions as:
   - verified
   - unverified but low-risk
   - unverified and high-risk
10. Convert high-risk unverified assumptions into checkpoint commands.
```

---

## Appendix B — Proposed New Checklist: Before Executing a High-Risk Prompt

```md
## High-Risk Prompt Readiness Checklist

Before giving a high-risk prompt to an execution agent:

1. Prompt references live source files, not generated artifacts.
2. All file paths verified against `main`.
3. All function anchors verified with grep.
4. Scope boundary lists MAY and MUST NOT files.
5. Do-NOT list includes known project hazards.
6. Checkpoint failure behavior says STOP, not fix.
7. Device test commands are included.
8. Rollback plan is included.
9. Security gate is included if endpoints/auth/data mutation are touched.
10. Large-data or long-duration test cases are included if persistence/history is touched.
11. Acceptance criteria are checkable.
12. Post-merge deliverables include `CURRENT-STATE.md`.
13. Prompt provenance fields are included for PR description.
```

---

## Appendix C — Proposed New Template: Consolidated Review Finding Log

```md
# Consolidated Review Finding Log

PR:  
Version/Step:  
Risk tier:  
Agent prompt:  
Review prompt:  
Execution model/tool:  

| ID | Finding | Reviewer | Category | Severity | True Positive? | Duplicate? | Prompt-Preventable? | Disposition |
|---|---|---|---|---:|---|---|---|---|
| R1 |  |  | correctness/security/perf/test/docs |  | yes/no/partial | yes/no | yes/no | fixed/deferred/rejected |

## Summary

- Total findings:
- True positives:
- False positives:
- Duplicates:
- Prompt-preventable:
- Fixed:
- Deferred:
- Rejected:

## Prompt Improvements

- Add checkpoint:
- Add scope guard:
- Add Do-NOT rule:
- Add acceptance criterion:
```

---

## Appendix D — Proposed New Template: Rollback Plan

```md
# Rollback Plan

PR:  
Version/Step:  
Risk tier:  
Devices affected:  

## Current Known-Good State

- Version:
- Commit SHA:
- Firmware artifact location:
- Device IPs:
- Last successful smoke test:

## Recovery Paths

- OTA rollback available: yes/no
- USB flash available: yes/no
- Physical access available: yes/no
- Data export needed before change: yes/no

## Rollback Trigger Symptoms

Rollback if:

- device fails to boot
- `/api/status` unreachable after N minutes
- dashboard fails to load
- min heap below threshold
- persistence data missing/corrupt
- repeated watchdog reset
- auth blocks expected management access

## Rollback Command

```bash
# command here
```

## Post-Rollback Verification

```bash
curl -s http://DEVICE/api/status | python3 -m json.tool
curl -s -u USER:PASS http://DEVICE/api/status/full | python3 -m json.tool
```
```

---

## Appendix E — Proposed New Template: Evidence Table

```md
# Evidence Table

Claim:  

| Evidence | Level | Source | Supports/Contradicts | Notes |
|---|---:|---|---|---|
| curl output from C3 `/api/status/full` | 1 | device test | supports |  |
| grep result for handler function | 2 | source inspection | supports |  |
| old phase plan | 4 | historical doc | contradicts | stale after refactor |
| model explanation | 6 | inference | supports | hypothesis only |

Conclusion:

- Verified:
- Unverified:
- Next diagnostic:
```

---

## Appendix F — Proposed New Template: Documentation Status Header

```md
> **Document status:** Active / Reference / Historical / Superseded / Obsolete  
> **Last verified:** YYYY-MM-DD  
> **Applies to version:** vX.Y.Z  
> **Source of truth:** live code / CURRENT-STATE.md / decision log / other  
> **Superseded by:** path/to/newer-doc.md  
> **Warning:** Do not use this document for implementation without verifying file paths and function anchors.
```

---

_End of assessment._
