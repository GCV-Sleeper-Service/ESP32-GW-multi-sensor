# Session Handoff Prompt — Phase VY: Development Methodology Audit

_Use this prompt to start the Phase VY Claude session._
_Phase VY runs AFTER Phase VX closes and BEFORE the multi-phase planning session._
_This is not a firmware or dashboard session — it's about how the development itself works._

---

## Instructions for Claude

Please clone and understand the repo:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/

Checkout `main` (PR #202 should be merged, Phase VX complete at v7.6.10.4).

### Primary Session Prompt

The full session prompt is already in the repo:

**`prompts/handoff/methodology-audit-session-prompt.md`**

Read that file completely — it contains the full reading list (25 files), the five analysis dimensions, the deliverable specifications, and the session structure. That prompt is your operating instructions for this session.

### What This Handoff Adds

This handoff provides context that the methodology audit prompt doesn't have — the Phase VX experience and v7.6.10.4 findings.

---

## Phase VX Context for the Methodology Audit

Phase VX (v7.6.10.0–v7.6.10.4) just completed. It exercised the prompt methodology across several workload types, and the v7.6.10.4 session log documents specific failure modes that feed directly into the audit.

### Phase VX Prompt Sets to Read (in addition to the methodology audit's reading list)

```
23. prompts/phaseVX/v7.6.10.1-agent-prompt-gpt-codex.md  — board profile creation (infrastructure)
24. prompts/phaseVX/v7.6.10.4-agent-prompt-gpt-codex.md  — dashboard auth refactor (JS-only)
25. prompts/phaseVX/v7.6.10.4-claude-two-step.md          — two-step with auth context
26. prompts/handoff/phaseVX/phaseVX-results.md             — Phase VX delivery record
27. Docs/session-log-2026-05-06-v7.6.10.4.md              — CRITICAL: 10 prompt recommendations
```

**The v7.6.10.4 session log (item 27) is particularly important.** Its "Prompt Recommendations" section documents 10 specific failure modes and proposed fixes that the methodology audit should evaluate, validate, and either adopt or reject:

1. Canonical version-sync checklist before any gate run
2. Explicit permission for version-only sync updates in assembly sources
3. `assemble-sensor-history.sh --check` in pre-gate instructions
4. Sequential pipeline ordering documented explicitly
5. `minify-dashboard.sh` and `generate-header.sh` non-parallel requirement
6. PR bootstrap contingency (reuse existing PR if branch already has one)
7. localStorage/sessionStorage rule clarification (credentials vs. preferences)
8. `--body-file` preference for GitHub CLI PR operations
9. REST fallback for `gh pr edit` GraphQL failures
10. Post-review checklist for browser code (modal cancel, retry cancel, dead state, selector safety)

### Phase VX Methodology Observations

These are not in any existing document — they're observations for the methodology auditor:

**What worked well in Phase VX:**
- The two-step pattern (Claude advisory → agent execution) successfully handled both firmware infrastructure (v7.6.10.0/1) and dashboard-only (v7.6.10.4) workloads
- Perplexity three-turn review caught real issues (confirmed by Codex, Copilot, Gemini reviews)
- Session handoff prompts maintained context across sessions effectively
- The POST-STEP-EDIT-TRACKER prevented documentation drift
- Board measurement protocol enabled an operator-driven step (v7.6.10.2) without agent involvement

**What didn't work well:**
- The agent prompt for v7.6.10.4 didn't account for version-sync requirements across assembly source fragments (caused pipeline failures)
- The "402 tests" count in handoff prompts was stale — actual count after fixture changes was 206 passed + 92 skipped
- PR metadata operations (body, comments) via `gh` CLI were fragile — GraphQL failures required REST fallback
- Multiple code review tools (Codex, Copilot, Gemini, Perplexity) found the same issues independently — suggests the prompt should have caught them pre-merge
- The v7.6.10.3 advisory session produced a zip deliverable but no automated way to apply surgical edits — the operator had to manually find/replace

**Questions the methodology audit should address:**
1. Should surgical edit documents use a machine-parseable format (not markdown find/replace blocks)?
2. Is the three-turn Perplexity review redundant with Codex/Copilot/Gemini automated reviews?
3. Should the prompt include a "browser code review checklist" to catch modal/cancel/retry issues before PR?
4. How should test count discrepancies be tracked across prompt handoffs?
5. Should there be a standard "version bump protocol" that all step prompts inherit?

---

## Pre-Session Verification

Before starting the methodology audit session, verify:

```bash
# Phase VX is complete
cat VERSION
# Expected: 7.6.10.4

# Phase VX results exist
test -f prompts/handoff/phaseVX/phaseVX-results.md && echo "YES" || echo "MISSING"

# All phase results exist (the methodology audit reads all of them)
for f in prompts/handoff/phaseD/phaseD-results.md \
         prompts/handoff/phaseX/phaseX-results.md \
         prompts/handoff/phaseY/phaseY-results.md \
         prompts/handoff/phaseV/phaseV-results.md \
         prompts/handoff/phaseVX/phaseVX-results.md; do
  test -f "$f" && echo "OK: $f" || echo "MISSING: $f"
done

# v7.6.10.4 session log exists (contains the 10 prompt recommendations)
test -f Docs/session-log-2026-05-06-v7.6.10.4.md && echo "YES" || echo "MISSING"
```

---

## Board Fleet Reference (for hardware-specific methodology examples)

| Board | IP | Chip | Role |
|---|---|---|---|
| C3 SuperMini | .189 | ESP32-C3 | Satellite (production) |
| WROOM-32D | .170 | ESP32 | Satellite (production) |
| S3 DevKitC N16R8 | .191 | ESP32-S3 | Aggregator (production) |
| S3 SuperMini | .173 | ESP32-S3 | Satellite (new) |
| C6 SuperMini | .184 | ESP32-C6 | Satellite (new) |
| C5 WROOM-1U | .180 | ESP32-C5 | Satellite (⚠️ BLE re-test) |

---

## After Phase VY

The next session is the multi-phase planning session:
```
1. prompts/handoff/multi-phase-planning-prompt.md
2. prompts/handoff/multi-phase-planning-supplement-v7.6.9.5.md
3. prompts/handoff/multi-phase-planning-supplement-post-vx.md
```

Then Phase 7 (v7.7.0.0) begins.

---

_End of Phase VY session handoff prompt._
