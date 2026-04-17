# Phase V — Step Scoping Prompt for v7.6.9.5 and v7.6.9.6

_Run this prompt in a fresh Claude session to produce the full three-file bundle (session handoff + agent prompt + Claude two-step) for v7.6.9.5, then again for v7.6.9.6 after v7.6.9.5 merges._
_This prompt does NOT produce the bundles by itself — it gathers the current-state evidence, then instructs the advisor to draft the step bundle using that evidence._

---

## When to Use

Run this prompt exactly twice:

**First run — scope v7.6.9.5** (C3 httpd stack watermark investigation):
- Trigger: v7.6.9.4 has merged to main and device flashing has produced post-v7.6.9.4 telemetry on all three boards
- Inputs available: v7.6.9.4 session log with post-flash `httpd_stack_watermark_bytes` measurements on C3, WROOM, S3
- Output: three-file bundle at `prompts/handoff/phaseV/session-handoff-v7.6.9.5.md` + `prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md` + `prompts/phaseV/v7.6.9.5-claude-two-step.md`

**Second run — scope v7.6.9.6** (Cloudflare polling telemetry + SEC-ADR amendment):
- Trigger: v7.6.9.5 has merged and its stack-investigation findings are documented
- Inputs available: v7.6.9.5 findings (was stack overflow actually at risk? did the investigation recommend a code change?)
- Output: three-file bundle at `prompts/handoff/phaseV/session-handoff-v7.6.9.6.md` + `prompts/phaseV/v7.6.9.6-agent-prompt-gpt-codex.md` + `prompts/phaseV/v7.6.9.6-claude-two-step.md` + SEC-ADR amendment draft

Do NOT produce both bundles in a single session. v7.6.9.6's scope depends on v7.6.9.5's outcomes — producing them simultaneously forces guesses about measurements that aren't in yet.

Do NOT use the scoping prompt as the agent prompt itself. This prompt's job is to produce prompts, not to do the work.

---

## Template

---

**Phase V — Step Scoping**

You are the architectural advisor for Phase V of the ESP32-GW Multi-Sensor Gateway project. Your job is to produce the three-file bundle for the next Phase V mitigation step.

Repo: `https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor`

### Step I am scoping

Operator selects ONE:
- [ ] **v7.6.9.5** — C3 httpd stack watermark investigation
- [ ] **v7.6.9.6** — Cloudflare polling telemetry fix + SEC-ADR amendment

---

### ⚠️ Read Before Responding

Your training data is stale on specifics. You MUST read current state. Do NOT rely on memory of previous sessions.

**1. Clone and sync:**
```
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
cd ESP32-GW-multi-sensor
git checkout main && git pull
cat VERSION
git tag -l 'v7.6.9*' --sort=creatordate
```

**2. Confirm prerequisite version is merged:**
- If scoping v7.6.9.5: `VERSION` must read `7.6.9.4` and that tag must exist. If `VERSION` is lower or the tag is missing, STOP and tell the operator v7.6.9.4 must complete first.
- If scoping v7.6.9.6: `VERSION` must read `7.6.9.5` and that tag must exist. If not, STOP.

**3. Read the authoritative context files in this order:**
- `Docs/phase-V-implementation-plan.md` — original plan (note what this step was NOT planned to do)
- `Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md` — carve-out authorising the 9.4/5/6 mitigation sequence
- `prompts/handoff/phaseV/session-handoff-v7.6.9.4.md` — context carries forward to this step (read the "To v7.6.9.5" or "To v7.6.9.6" subsection)
- `prompts/phaseV/v7.6.9.4-agent-prompt-gpt-codex.md` — structural template for the new agent prompt
- `prompts/phaseV/v7.6.9.4-claude-two-step.md` — structural template for the new Claude two-step
- `prompts/handoff/universal-bug-escalation-prompt.md` — for the failure-mode categories referenced in checkpoints
- `Docs/changelog.md` — v7.6.9.4 and earlier entries

**4. Read the evidence files for the PREVIOUS step:**
- `Docs/session-log-*-v7.6.9.4.md` (for v7.6.9.5 scoping) — pull the actual post-flash measurements from the §8 device verification table
- `Docs/session-log-*-v7.6.9.5.md` (for v7.6.9.6 scoping) — pull the stack investigation findings
- The merged PR's review comments for the previous step — note any reviewer flags that inform this step

**5. Read step-specific technical reference files:**

*For v7.6.9.5 (stack watermark):*
- `firmware/core/web-handler.h` — note current `handleRequest()` dispatch chain depth; note every handler that uses deferred tasks (`xTaskCreate`) vs runs on httpd task directly
- `firmware/local_components/web_server_idf/` — if it exists, the httpd stack patch that brought the stack to 16 KB; confirm patch is still in place
- `scripts/patch-esphome-httpd-stack.sh` — the patch application script
- `Docs/lessons/firmware.md` — LESSON-OPS-097 through 102 (the httpd stack patch backstory)
- `Docs/lessons/operations.md` or `Docs/lessons/firmware.md` — any earlier lesson about stack watermark thresholds

*For v7.6.9.6 (polling telemetry):*
- `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` — full text, with special attention to RV-03 (public `/api/status` strip)
- `firmware/core/web-handler.h` `handle_status_` (around line 1339) vs `handle_status_full_` (around line 1360) — note the field lists on each
- `dashboard/core/status-snapshot.js` `loadStatusSnapshot()` — current fetch URL and credentials option
- `dashboard/core/status-snapshot.js` `applyStatusSnapshot()` — field names it reads from the response
- Recent v7.6.9.0 session log — the console output showing the 500s over Cloudflare Tunnel

**6. Confirm device state is reproducible:**

Request that the operator paste current `curl` output for the step you are scoping:

*For v7.6.9.5:*
```
curl -s -u ESPadmin:ESPpass100 http://192.168.120.189/api/status/full | jq '.httpd_stack_watermark_bytes, .free_heap, .min_free_heap, .uptime_seconds, .version'
curl -s -u ESPadmin:ESPpass100 http://192.168.120.190/api/status/full | jq '.httpd_stack_watermark_bytes, .free_heap, .min_free_heap, .uptime_seconds, .version'
curl -s -u ESPadmin:ESPpass100 http://192.168.120.191/api/status/full | jq '.httpd_stack_watermark_bytes, .free_heap, .min_free_heap, .uptime_seconds, .version'
```

Compare `version` against `VERSION` on disk. If a board is running older firmware, have the operator reflash before proceeding — scoping against stale device state produces wrong acceptance criteria.

*For v7.6.9.6:*

Ask the operator to paste:
- Browser console output reproducing the `api/status/full 500 ()` error over the Cloudflare Tunnel URL
- `curl -i` of the same URL from the operator's LAN (to confirm the ESP32 itself returns 200 with credentials)
- The current `SEC-ADR-001` state (full text of RV-03 section)

---

### Drafting Protocol

After evidence-gathering, produce three files. Use v7.6.9.4's bundle as the structural template — match its anatomy, heading sequence, preamble, checkpoint structure, and "DO-NOT" list conventions.

**File 1 — `prompts/handoff/phaseV/session-handoff-v<VER>.md`**

Required sections (match the v7.6.9.4 handoff structure exactly):

- Status summary line + project state summary (one paragraph)
- Phase V progress table — extended with this version's row
- Scope section — "Why this step exists" with the operator-measured evidence from Step 6, "What this step does", "What this step does NOT do", Files modified, Acceptance criteria reference
- Pre-merge checklist
- Critical Rules relevant to this step
- Risk assessment
- Workflow numbered list (steps 1–12 or so, matching v7.6.9.4)
- Device testing table — pre-filled with the target boards and IPs
- Post-PR closure deliverables (consolidated audit, LESSON-OPS entry if applicable, issue comments if applicable, Phase V closure checklist updates)
- Context that carries forward (to the next step or, for v7.6.9.6, to Phase 7 planning)

**File 2 — `prompts/phaseV/v<VER>-agent-prompt-gpt-codex.md`**

Required sections (match v7.6.9.4 agent prompt exactly):

- `§0 — Why This Step Exists` — evidence-based rationale, including specific measurement values from the previous step's session log
- `§1 — Repository & Required Reading` — numbered file list
- `§2 — Pre-Implementation Verification Gate` — specific grep/cat/curl commands with expected outputs
- `§3 — Scope Boundary` — IN scope (specific files + line ranges where known) and NOT in scope (explicit carve-outs)
- `§4 — Critical Rules Checklist` — existing rules that apply + any new rules this step might establish
- `§5 — Implementation Instructions` — step-by-step with inline anti-patterns and ⛔ CHECKPOINT blocks
- `§6 — Acceptance Criteria` — checkbox list where every item has a grep/measurement that verifies it
- `§7 — ⛔ PRE-PR GATE` — pre-PR verification including device smoke test if applicable
- `§8 — Operator Device Testing` — verification table with specific measurement rows
- `§9 — Post-Merge Deliverables` — consolidated audit path, LESSON-OPS, issue updates
- `§10 — DO-NOT List` — explicit exclusions
- `§11 — Multi-LLM Execution Preamble Reference` — copy from v7.6.9.4

**File 3 — `prompts/phaseV/v<VER>-claude-two-step.md`**

Required sections (match v7.6.9.4 claude two-step exactly):

- Step 1 — Agent Session (scope discipline, critical invariants, inline checkpoints, pre-PR gate, mandatory device smoke test if applicable)
- Step 2 — Review Session (scope-discipline review questions, implementation-correctness review, documentation review, device test gate verification, post-merge deliverables)
- External Reviewer Workflow section

---

### Step-Specific Guidance

*For v7.6.9.5 — stack watermark investigation:*

This is an **investigation step**, not a feature step. Key scope points:

- The output is a **measurement + decision**, not necessarily a code change. It is valid for v7.6.9.5 to merge with zero firmware code changes if the investigation concludes the watermark is stable under load and no overflow occurred.
- If a code change IS recommended, it must be narrow: either a stack bump (modify `scripts/patch-esphome-httpd-stack.sh` to increase `.stack_size`), or a specific call-chain flattening in a named handler. Not a broad refactor.
- Acceptance criteria must include: (a) a specific stress-test protocol ran on C3 under load (history fetch + status full + storage stats concurrently), (b) the watermark bottomed out at a documented value, (c) the new value is above a documented floor threshold (suggested: ≥ 2000 bytes) OR the code change that achieved that threshold is landed.
- Forbidden expansions: any change to the `HistoryBuffer`, `SegmentSnapshot`, NVS format, partition table, or any handler body that wasn't specifically identified by the call-chain analysis.

Anti-patterns to explicitly list in the DO-NOT block:

- Do NOT change stack size without measuring first — a blind bump obscures whether the problem is usage depth or stack sizing
- Do NOT refactor handlers for "cleanliness" — scope is strictly the call-chain that drove the watermark low
- Do NOT roll in optimisations that look related — those go to Phase 7

Device testing for v7.6.9.5 must include a **reproducible stress test protocol** the operator can re-run. Suggested protocol:

1. Flash C3 with the v7.6.9.5 build
2. Let boot stabilise (2 min)
3. Execute 10 concurrent calls: 3x `/history/*/temp` + 2x `/api/status/full` + 5x `/api/storage-stats` (staggered 100ms apart)
4. After each wave, curl `/api/status/full` and record watermark
5. Repeat 5 times, 30 seconds between waves
6. Record minimum watermark observed across all 5 runs

The acceptance gate is: minimum watermark from step 6 ≥ 2000 bytes.

*For v7.6.9.6 — Cloudflare polling telemetry + SEC-ADR amendment:*

This step has **two deliverables tightly coupled**:

1. **Code change:** add `free_heap` + `uptime_seconds` fields back to `handle_status_` (public `/api/status`). Revert dashboard `loadStatusSnapshot()` from `/api/status/full` back to `/api/status` and drop `credentials: 'same-origin'` (no longer needed).

2. **SEC-ADR amendment:** `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` RV-03 section must be amended to narrow the strip scope. The two fields being un-stripped need an explicit threat-model paragraph: why `free_heap` and `uptime_seconds` are the lowest-sensitivity fields in the full body, and why `version`, `sensors[]`, `httpd_stack_watermark_bytes` etc. stay auth-gated.

**The SEC-ADR amendment must land in the same PR as the code change.** Separating them lets the code ship ahead of its justification. Sequence: ADR draft first (in the agent prompt), then code change implementing the narrowed scope.

The v7.6.9.6 agent prompt must explicitly include:

- Exact proposed replacement text for RV-03 (operator may request changes; the agent generates a first draft)
- A scope guard list stating the amendment MUST NOT relax other RVs in SEC-ADR-001
- A test showing `curl /api/status` (no auth) returns exactly the fields `ok, role, id, free_heap, uptime_seconds` — no more, no less
- A test showing `curl /api/status` still does NOT return `version`, `sensors[]`, `min_free_heap`, `httpd_stack_watermark_bytes` (proving the narrowing, not a full un-strip)

Device testing must include a Cloudflare Tunnel URL test — the Cloudflare browser fix is the whole point of the step, so testing over LAN only is insufficient.

Because this is the **actual Phase V closure step**, the v7.6.9.6 bundle must also include in §9 Post-Merge Deliverables:

- Phase V closure checklist completion (mark v7.6.9.6 row in `phaseV-results.md`)
- Trigger: run `phaseV-issue-sweep-prompt.md` next
- Trigger: then run `phaseV-closure-analysis-prompt.md`
- Flag to operator: DO NOT start Phase 7 planning until both sweep and closure analysis documents exist

---

### Output Delivery

After the three files are drafted, package them matching the standard bundle pattern:

1. Produce each file as a complete markdown document
2. Produce a zip archive at `<version>-bundle.zip` with files laid out matching the repo directory structure (so the operator can unzip directly over the working copy)
3. If a SEC-ADR amendment is included (v7.6.9.6 only), include it as a fourth file in the bundle: `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md` as a complete replacement (not a patch), with the amendment applied

Final bundle structure for v7.6.9.5:
```
v7.6.9.5-bundle.zip
  prompts/handoff/phaseV/session-handoff-v7.6.9.5.md
  prompts/phaseV/v7.6.9.5-agent-prompt-gpt-codex.md
  prompts/phaseV/v7.6.9.5-claude-two-step.md
```

Final bundle structure for v7.6.9.6:
```
v7.6.9.6-bundle.zip
  prompts/handoff/phaseV/session-handoff-v7.6.9.6.md
  prompts/phaseV/v7.6.9.6-agent-prompt-gpt-codex.md
  prompts/phaseV/v7.6.9.6-claude-two-step.md
  Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md   # amended full replacement
```

---

### Quality Self-Check Before Delivery

Before handing the bundle to the operator, verify:

- [ ] Every acceptance criterion has a specific grep, curl, or measurement that verifies it
- [ ] No acceptance criterion says "verify the change works correctly" without a concrete command
- [ ] Checkpoints have expected output values (not just "expected: passes")
- [ ] Pre-merge device test gate is present for steps with hardware implications
- [ ] DO-NOT list has at least 5 explicit exclusions, each tied to a concrete risk
- [ ] Scope Boundary NOT-in-scope list cites explicit files, not categories
- [ ] Session handoff's "Context that carries forward" section has actual next-step handoff content (not a TODO)
- [ ] For v7.6.9.6: SEC-ADR replacement text is complete prose, not a diff marker; threat model paragraph is substantive
- [ ] For v7.6.9.6: the "this is Phase V actual closure" triggers for sweep + closure analysis are explicit in §9
- [ ] No assumptions about measurements that aren't in the operator's pasted evidence

If any item fails, revise before delivering.

---

### Anti-patterns to avoid during scoping

Based on the v7.6.9.4 drafting experience, watch for these mistakes:

**Getting the prerequisite chain wrong.** v7.6.9.5 runs after v7.6.9.4 (not v7.6.9.3). The previous drafting session mis-read the merge log and claimed v7.6.9.1/2/3 were already merged when only v7.6.8.x was. Confirm `VERSION` on disk before writing "v7.6.9.x is complete" anywhere.

**Guessing at measurements.** If the operator hasn't pasted the actual post-flash telemetry, ask for it. Do not write acceptance criteria like "watermark ≥ 2000 bytes" without knowing the current baseline.

**Assuming v7.6.9.5 will find a problem.** The investigation may conclude no code change is needed. The agent prompt must allow a zero-code-change merge as a valid outcome, with the measurement evidence being the entire deliverable.

**Conflating two Cloudflare concerns in v7.6.9.6.** The 500 error over Cloudflare has two independent causes: (a) browser not attaching Basic Auth (the real cause), and (b) stack watermark narrow margin on the C3 (unrelated, possibly handled by v7.6.9.5). Don't mix them — v7.6.9.6 fixes (a). If v7.6.9.5 didn't fix (b), that stays its own problem.

**Leaking Phase 7 scope.** Both v7.6.9.5 and v7.6.9.6 must preserve the "no Phase 7 work in Phase V" invariant. Chunked streaming, per-device NVS, partition changes — all forbidden. The DO-NOT list must state this.

**Producing both bundles in one session.** Don't. v7.6.9.6's scope depends on v7.6.9.5's outcome. Produce them serially.

---

**After the bundle is produced**, deliver to the operator with:

1. The three (or four for v7.6.9.6) files as markdown documents
2. A single zip archive with repo-layout paths
3. A one-paragraph summary of what changed in the scope relative to the thin description in the v7.6.9.4 addendum (if anything did)
4. Any items that were ambiguous during scoping where operator input is needed before execution

---

_End of Phase V step scoping prompt._
