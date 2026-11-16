# Multi-Phase Planning Session — Operator Run Guide

_Step-by-step instructions for running the multi-phase planning session._
_Last updated: 2026-05-07 (Phase VY review incorporation)_
_Prerequisite: Phase VY complete, review incorporation done, all supplements committed._

---

## When to Use This

Run this session when you're ready to produce (or rewrite) Phase 7+ implementation plans. The session reads the full project state and produces architecture reviews and scoped phase plans.

This is a **Claude Opus advisory session** — no code changes, no PRs. Output is planning documents that feed into prompt production.

---

## 1. Pre-Session Checklist

Complete every item before starting the session. Skipping items means the advisor works from stale context and produces stale plans — the exact failure mode documented in BUG-083.

### 1.1 Verify project state

```bash
cd /path/to/ESP32-GW-multi-sensor

# Version matches expectations
cat VERSION
# Expected: 7.6.10.4

# CURRENT-STATE.md is fresh
head -2 CURRENT-STATE.md
# Expected: "Last verified" date within the last step

# No uncommitted changes
git status --porcelain
# Expected: empty (clean working tree)

# On main branch, up to date
git branch --show-current
# Expected: main
git fetch origin main && git diff HEAD origin/main --stat
# Expected: empty (no divergence)
```

### 1.2 Verify supplements exist and are current

```bash
# Main planning prompt
ls prompts/handoff/multi-phase-planning-prompt.md
# Must exist

# v7.6.9.5 supplement
ls prompts/handoff/multi-phase-planning-supplement-v7.6.9.5.md
# Must exist

# Post-VX supplement
ls prompts/handoff/multi-phase-planning-supplement-post-vx.md
# Must exist — check ESPHome version
grep '2026.4.1' prompts/handoff/multi-phase-planning-supplement-post-vx.md
# Expected: ≥1 match

# Methodology audit supplement (Phase VY)
ls prompts/handoff/methodology-audit-findings-for-planning.md
# Must exist
```

### 1.3 Verify measurement data exists

```bash
# Board measurement log populated
wc -l Docs/board-measurement-log-v7.6.10.md
# Expected: ≥50 lines

# No blank measurement cells
grep -c '___' Docs/board-measurement-log-v7.6.10.md
# Expected: 0
```

### 1.4 Verify documents the session will read

These files are in the planning prompt's mandatory reading list. Confirm they exist:

```bash
ls VERSION README.md CURRENT-STATE.md AGENTS.md
ls Docs/architecture-overview.md Docs/changelog.md
ls Docs/feature-roadmap.md Docs/development-process-guide.md
ls Docs/v7.7-implementation-plan.md
ls Docs/v7.7-v7.8-persistence-architecture.md
ls Docs/lessons/firmware.md
ls firmware/core/config.h firmware/core/data-model.h
ls prompts/prompt-index-and-workflow.md
```

If any file is missing, the advisor will work from incomplete context. Fix before starting.

### 1.5 Push everything

```bash
git add -A && git status
# Review what's staged — should be only planning/methodology docs
git push origin main
```

The advisor clones from GitHub. Unpushed changes are invisible to it.

---

## 2. Assembling the Prompt

The planning session prompt is built by concatenating four documents in order. The advisor receives them as a single input.

### Assembly order

```
1. prompts/handoff/multi-phase-planning-prompt.md          (main prompt — instructions + 4 deliverables)
2. prompts/handoff/multi-phase-planning-supplement-v7.6.9.5.md  (Phase V context)
3. prompts/handoff/multi-phase-planning-supplement-post-vx.md   (Phase VX context + measurements)
4. prompts/handoff/methodology-audit-findings-for-planning.md   (Phase VY methodology gates + Phase 7 reordering)
```

### How to paste

**Option A — Single paste (preferred if within context limits):**

Copy all four files into a single text block. Paste into a fresh Claude Opus conversation with no system prompt or prior context. The prompt is self-contained.

**Option B — Sequential paste (if Option A exceeds input limits):**

1. Paste document 1 (main prompt). Claude will start reading the repo.
2. After Claude produces the "Current State Summary" checkpoint, paste documents 2-4 together as a follow-up message: "Here are three supplements to append to the planning prompt. Read these before producing any deliverables."

Option A is strongly preferred — it gives the advisor all context before it starts reading the codebase, which prevents it from forming conclusions that the supplements would have corrected.

### Estimated combined prompt size

| Document | Est. tokens |
|---|---|
| Main planning prompt | ~2,500 |
| v7.6.9.5 supplement | ~1,800 |
| Post-VX supplement | ~1,700 |
| Methodology audit supplement | ~2,000 |
| **Total** | **~8,000** |

This fits comfortably in a single Claude Opus input. The advisor then reads ~20 repo files (another ~30-40K tokens of codebase). Total session context will be ~80-120K tokens including output.

---

## 3. What to Expect

### Timing

| Phase | Duration | What happens |
|---|---|---|
| Codebase reading | 5-10 min | Advisor clones repo, reads ~20 files in order |
| Current State Summary | 2-3 min | Advisor produces a 1-page summary proving it read the codebase. **Review this before proceeding.** |
| Deliverable 1 (Phase 7 review) | 10-15 min | Reviews staleness of Phase 7 plans against current code |
| Deliverable 2 (Phase E / captive portal) | 10-15 min | Scoping and architecture |
| Deliverable 3 (Phase 8-9 / notifications + cloud) | 10-15 min | Scoping and architecture |
| Deliverable 4 (Phase 10 / standalone or UI) | 5-10 min | Scoping and lighter analysis |
| Phase ordering recommendation | 5 min | Final synthesis |
| **Total** | **45-75 min** | Single session |

### Output size

Expect ~15-25K tokens of output across 4 deliverables + ordering recommendation. This is a large session. If Claude Opus hits output limits, ask it to continue — it will pick up where it left off.

### Checkpoint: Current State Summary

After the advisor reads the codebase, it produces a "Current State Summary" before generating deliverables. **Read this carefully.** Check:

- Does the version match? (Should be 7.6.10.4)
- Does it mention the 6-board fleet?
- Does it reference BUG-082 as the critical open issue?
- Does it list the correct measurements from the board measurement log?
- Does it acknowledge that the Phase 7 plan is stale and needs rewriting?

If any of these are wrong, correct the advisor before it proceeds. A wrong state summary means wrong plans.

---

## 4. Post-Session Actions

### 4.1 Save the output

Copy the full session output. Save each deliverable as a separate file:

```
Docs/phase-7-review-and-rewrite.md          (Deliverable 1)
Docs/phase-E-captive-portal-plan.md          (Deliverable 2)
Docs/phase-8-9-notifications-cloud-plan.md   (Deliverable 3)
Docs/phase-10-plan.md                        (Deliverable 4)
```

File names may vary based on what the advisor produces. Use descriptive names.

### 4.2 Create GitHub infrastructure

```bash
# Create Phase 7 milestone
gh milestone create "Phase 7 — Per-Device Persistence" \
  --description "Chunked streaming, health-check telemetry, per-device NVS" \
  --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor

# Create standard labels (if not already present)
for label in "phase/7" "phase/E" "phase/8" "phase/9" "phase/10" \
  "type/firmware" "type/dashboard" "type/docs" "type/tests" "type/infra" \
  "risk/high" "risk/medium" "risk/low" \
  "status/review-in-progress" "status/device-test-needed" "status/blocked"; do
  gh label create "$label" --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor 2>/dev/null
done
```

### 4.3 Update CURRENT-STATE.md

Update "What's Next" to reflect the planning session output. Add any new open issues or architectural decisions discovered during planning.

### 4.4 Commit planning output

```bash
git add Docs/phase-7-review-and-rewrite.md \
       Docs/phase-E-captive-portal-plan.md \
       Docs/phase-8-9-notifications-cloud-plan.md \
       Docs/phase-10-plan.md \
       CURRENT-STATE.md
git commit -m "docs: multi-phase planning session output (Phase 7 rewrite + E/8-10 scoping)"
git push origin main
```

### 4.5 Start Phase 7 prompt production

The planning session output feeds into the next Claude session: prompt production for Phase 7 Step -1 and Step 0. That session reads:

- `CURRENT-STATE.md`
- The Phase 7 review/rewrite from this session
- `Docs/writing-guide/methodology.md`
- `prompts/handoff/methodology-audit-findings-for-planning.md`

And produces the agent prompt bundle (agent prompt + review prompt + session handoff) for the first Phase 7 step.

---

## 5. Troubleshooting

### Advisor produces stale analysis

**Symptom:** Advisor references `dashboard/sensor_history_multi.h` as a source file, or doesn't mention `authFetch()`, or uses pre-Phase-V heap numbers.

**Cause:** Advisor read an older version of the repo, or skipped mandatory reading files.

**Fix:** Ask: "Please confirm: what is the current ESPHome version, and what files exist under `firmware/core/`? Run `ls firmware/core/` and `grep -c 'authFetch' dashboard/core/auth.js`." If the answers are wrong, the advisor is working from a cached or partial clone. Ask it to re-clone.

### Advisor hits output limit mid-deliverable

**Symptom:** Response cuts off mid-sentence or mid-table.

**Fix:** Type "Continue from where you left off." Claude will resume. If it loses context, paste the last 10 lines of its output and ask it to continue from there.

### Session runs out of context window

**Symptom:** Later deliverables (3 and 4) are noticeably less detailed than earlier ones, or the advisor starts contradicting its own earlier output.

**Cause:** Context window saturation. The planning prompt + supplements + 20 repo files + 4 deliverables can approach 100K+ tokens.

**Fix:** For Deliverable 4 specifically, consider running it as a separate shorter session with just the relevant context. Or ask the advisor to produce Deliverable 4 as a concise 1-page assessment rather than a full plan — Phase 10 is lowest priority anyway.

### Measurement data seems wrong

**Symptom:** Advisor quotes heap numbers that don't match `Docs/board-measurement-log-v7.6.10.md`.

**Fix:** Ask: "Please re-read `Docs/board-measurement-log-v7.6.10.md` and quote the exact `min_free_heap` values for C3 and WROOM." If the advisor's numbers still don't match, it may be reading an older version of the file. Verify the file is committed and pushed.

### Planning session recommends something that contradicts a decision log entry

**Symptom:** Advisor suggests using `application/json` for POST calls, or editing generated files directly, or running NVS operations on the httpd task.

**Fix:** Point the advisor to the specific decision log entry or critical rule. Example: "Decision ARCH-005 prohibits `application/json` POST calls. Please revise." The advisor should correct itself. If it doesn't, the advisory output needs manual correction before use.

---

## 6. Prompt Production Session — Troubleshooting

The following symptoms, diagnostics, and fixes apply when running a **prompt production session** (e.g., the Phase 7 batch sessions). Use alongside `Docs/development-process-guide.md` §3 and the CI lint rules.

| Symptom | Diagnostic | Fix |
|---|---|---|
| Producer wrote `§9 — Post-Merge Deliverables` (E-1) | `grep -n 'Post-Merge Deliverables' <produced-prompt>` returns hits | Use `Post-Merge Bookkeeping (tag and close only)`; move docs to §6. CI lint **L1** catches this automatically. |
| Producer used a stale board IP / YAML filename (E-3) | Compare prompts against the `CURRENT-STATE.md` Board Fleet table (file lives at the repository root, not under `Docs/`) | Rerun Board Info Extraction Gate; embed result in handoff. CI lint **L4** (stale WROOM IP) and **L5** (wrong YAML name) catch the known-bad values. |
| Producer wrote spec paths that don't exist (`tests/mixed.spec.js`) | `find tests -name '*.spec.js'` does not include the cited path | Use the live `find` output; never rely on memory of file names. |
| Producer punted device testing to operator (E-2) | §6 task groups list "operator does X" for compile/upload/curl | Reassign to agent per `Docs/development-process-guide.md` §2.3. Methodology `Docs/writing-guide/methodology.md` §3.10 must agree. |
| Producer cross-referenced another prompt for scope (A6) | Prompt §3 says "see vX.Y.Z prompt §3" | Inline the full whitelist. CI lint **L3** catches this class of cross-prompt reference automatically. |
| Producer hit `bump-version.sh` scope explosion (E-4) | Agent stopped because canonical pipeline files weren't whitelisted | Add the bump-version.sh whitelist (the 6 source files written by `bump-version.sh` plus the 6 generated artifacts it regenerates — full enumeration in `prompts/handoff/phase7-batch-production-prompt-update.md`, "Scope-guard whitelist" section) to §3 of every prompt that touches versioned files. |
| Producer ordered `assemble-sensor-history.sh --check` before `--write` (E-5) | Pipeline runs `--check` against stale data | Always `--write` first (regenerate), then `--check` (verify). CI lint **L6** warns when `--check` appears before `--write` within 20 lines. |

**Cross-reference:** Each row maps to a lint rule (L1, L3, L4, L5, L6) that mechanically prevents it on every future PR. If you find a new symptom pattern, open an issue to add a lint rule and update this table.

---

_This document is updated when the planning session structure changes._
