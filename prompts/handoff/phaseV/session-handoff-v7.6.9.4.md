# Session Handoff — v7.6.9.4: Heap-Adaptive History Cap + Boot Sequencing (#139 Partial Fix)

_Date: 2026-04-16_
_Repo: https://github.com/GCV-Sleeper-Service/claude_sleeper_service_v2_
_Status: v7.6.9.3 COMPLETE. Phase V plan addendum committed. Three mitigation steps (v7.6.9.4, v7.6.9.5, v7.6.9.6) queued before Phase V actual closure; #139 partial mitigation is the first._

---

## Project State Summary

**v7.6.9.3 is complete.** Struct audit conditional step ran per V3-F. Phase V preliminary closure was declared at v7.6.9.3 but three mitigation steps (v7.6.9.4 / v7.6.9.5 / v7.6.9.6) surfaced during v7.6.9.0 device testing and must complete before Phase V actually closes and Phase 7 planning begins. This step (v7.6.9.4) is the first of those three.

**v7.6.9.0 hotfix 2** (commit `1edc4cb` on PR #183) merged successfully in SSE mode across all three boards. Polling mode still shows 500 errors on `/api/status/full` over the Cloudflare Tunnel — that is tracked separately as v7.6.9.6 (architectural fix: narrow SEC-ADR RV-03 to un-strip `free_heap` + `uptime_seconds` from public `/api/status`). PR #183 is accepted as merged; the polling limitation is a documented known issue in the v7.6.9.0 release notes.

---

## Phase V Progress Table

| Version | Scope | Status |
|---|---|---|
| v7.6.7.0 | V1-A/B/C: Proxy fix + NAS disable + logger | ✅ Complete |
| v7.6.7.1 | V1-D: Import crash fix | ✅ Complete |
| v7.6.7.2 | V1-E/F/G: Badge + dead code + comment | ✅ Complete |
| v7.6.7.3 | Operational telemetry in /api/status | ✅ Complete (PR #179) |
| v7.6.8.0 | V2-A/B/C/D: Auth guards + status split | ✅ Complete |
| v7.6.8.1 | V2-E/F/G: History auth + DoS + SEC-ADR (60 KB fixed cap) | ✅ Complete |
| v7.6.8.2 | V2-H/I/J: Gated optimisations | ✅ Complete |
| v7.6.9.0 | V3-A: Device card cleanup (+ hotfix 1, 2) | ✅ Complete (PR #183) — polling /api/status/full 500 deferred to v7.6.9.6 |
| v7.6.9.1 | V3-B/C: Hostname/IP + CSV role | ✅ Complete |
| v7.6.9.2 | V3-D/E: Manifest export + AGG-ADR | ✅ Complete |
| v7.6.9.3 | V3-F: Struct audit (conditional) | ✅ Complete (preliminary Phase V closure) |
| **v7.6.9.4** | **V4: Heap-adaptive history cap + boot sequencing (#139 partial)** | **⬅️ Current** |
| v7.6.9.5 | V5: C3 httpd stack watermark investigation | 🔜 Queued |
| v7.6.9.6 | V6: Polling telemetry — narrow /api/status un-strip + SEC-ADR amendment (**Phase V actual closure**) | 🔜 Queued |

---

## v7.6.9.4 Scope

### Why this step exists

Phase V plan as originally written (Docs/phase-V-implementation-plan.md line 44) deferred #139 ("History loading serialization for C3 boards") fully to Phase 7. Two events since plan finalisation changed the risk profile:

1. Issue #139 comment (2026-04-12) reported the same heap exhaustion on 520 KB SRAM WROOM-class boards — wider blast radius than the plan assumed.
2. v7.6.9.0 device testing (2026-04-16) reproduced the WROOM crash on a `/history/office/temp` curl.

The v7.6.8.1 safety-net (fixed 60 KB `csv.reserve()` cap) is sized for C3's ~68 KB heap. On WROOM at ~30 KB free, 60 KB exceeds the running heap and crashes the board.

A plan addendum (`Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md`, committed alongside this step) authorises a **single OTA-safe mitigation** within Phase V: replace the fixed 60 KB cap with a heap-adaptive formula, and defer the initial history load on the client until after the first status snapshot succeeds.

This is **not** the full #139 fix. Chunked streaming and per-device storage remain Phase 7. This step delivers the ~80% stability win that can ship OTA.

### What this step does

1. **Server-side:** two-site edit in `firmware/core/web-handler.h` replacing `std::min(est_bytes, (size_t)60000)` with a heap-adaptive formula `std::min(est_bytes, clamp(esp_get_free_heap_size()/3, 12000, 60000))`. Same edit in both `handle_history_()` and `handle_api_v2_history_()`.
2. **Client-side:** edit `dashboard/core/boot.js` to gate the initial `loadHistory()` call on the first `loadStatusSnapshot()` resolving, with a 15 s fallback timer preserving the old behaviour.
3. **Docs:** changelog entry, LESSON-OPS entry on heap-adaptive caps, update `phaseV-results.md` with v7.6.9.4 outcomes.
4. **Device testing:** verify all three boards post-flash.

### What this step does NOT do

- No server-side chunked/windowed responses (stays Phase 7)
- No per-device NVS storage (stays Phase 7)
- No dashboard paged loader (dashboard still fetches a single CSV per sensor)
- No change to auth posture on history endpoints (unchanged from v7.6.9.0 hotfix 1 — still public GET, still Copilot-reviewed trade-off)
- No change to `SegmentSnapshot`, `HistoryMeta`, `PERSIST_SLOTS`, `HISTORY_HOURS`, `HISTORY_INTERVAL_MINUTES`
- No partition table changes
- No fragment boundary changes (Rule 62)
- No SEC-ADR changes

### Files modified

- `firmware/core/web-handler.h` — two sites (see agent prompt §5)
- `dashboard/core/boot.js` — one block (see agent prompt §5)
- `Docs/changelog.md` — v7.6.9.4 entry
- `Docs/lessons/bugs-and-lessons-learned.md` — new LESSON-OPS entry on adaptive allocation caps
- `Docs/phase-V-implementation-plan.md` — addendum references at lines 44, 805, 1223, 1241 (see addendum for exact inserts)
- `prompts/handoff/phaseV-results.md` — fill v7.6.9.4 row
- Generated artifacts regenerated via pipeline, never hand-edited

### Acceptance criteria

See `prompts/phaseV/v7.6.9.4-agent-prompt-gpt-codex.md` §6 for the full checklist.

---

## Pre-merge Checklist for v7.6.9.4

- [ ] Read the coding agent prompt (`prompts/phaseV/v7.6.9.4-agent-prompt-gpt-codex.md`) completely
- [ ] Read this handoff completely
- [ ] Read the plan addendum (`Docs/phase-V-implementation-plan-addendum-v7.6.9.4.md`)
- [ ] Confirm v7.6.9.0 PR #183 is merged (including hotfix 2) and v7.6.9.1/2/3 are merged
- [ ] Verify `main` is green: `bash scripts/preflight.sh` passes
- [ ] All ⛔ CHECKPOINT gates in §5 verified
- [ ] All acceptance criteria in §6 met
- [ ] ⛔ PRE-PR GATE in §7 passes
- [ ] Device smoke tests on all three boards complete (§8 table filled in)
- [ ] Session log created
- [ ] Instruction Compliance Output table in PR description
- [ ] Plan addendum file committed in same PR

---

## Critical Rules Relevant to v7.6.9.4

| # | Rule | Why Relevant |
|---|---|---|
| 47 | Never edit `dashboard/dashboard.js` / `dashboard/dashboard.html` directly | Generated; boot.js change propagates through pipeline |
| 58 | Never edit `dashboard/sensor_history_multi.h` directly | Edit fragment (`firmware/core/web-handler.h`), run assembly |
| 62 | No fragment boundary reorganisation | v7.6.9.4 edits within existing fragments only |

Additional constraints (not numbered rules but equally binding):
- **SEC-ADR RV-03:** `/api/status` public response stays stripped — no dashboard change here touches that
- **Phase V invariant:** "No Phase 7 work in Phase V" — the addendum explicitly carves out this one mitigation; verify scope against the addendum text before adding anything

---

## Risk: LOW-MEDIUM

- Server-side: 6 lines × 2 sites. Simple math. Worst case: cap slightly smaller than optimal → CSV truncates a few rows, dashboard tolerates.
- Client-side: alters boot sequencing. 15 s fallback preserves old behaviour if status snapshot path fails (e.g. auth mismatch, network drop).
- Regression risk: Playwright mock server doesn't exercise `esp_get_free_heap_size()` — adaptive cap validation is device-only. Agent prompt §8 makes device smoke tests mandatory.

---

## Workflow for v7.6.9.4

1. Read the coding agent prompt and this handoff completely
2. Read the plan addendum
3. Open a NEW coding agent session and paste the GPT/Codex prompt (or use Claude two-step)
4. Agent implements per §5 with ⛔ CHECKPOINT verification
5. Agent runs pipeline, preflight, Playwright
6. Agent produces changelog + LESSON-OPS entry + plan addendum amendments (lines 44, 805, 1223, 1241)
7. Review the PR — verify scope, acceptance criteria, Critical Rules
8. Send universal reviewer prompt + v7.6.9.4 supplement to external reviewers
   - Universal prompt: `prompts/phaseV/pr-audit-question-template-phaseV.md` (top section)
   - Supplement: "verify that no Phase 7 work is in scope — specifically no changes to storage engine, NVS format, response framing, or chunked/paged responses; verify adaptive formula preserves the 60 KB ceiling for healthy boards; verify client 15 s fallback preserves old behaviour on auth failure"
   - Reviewers post findings as PR comments; fix Blocking/High before merge
9. **Device testing gate before merge:** flash all three boards, fill in §8 verification table. If WROOM still crashes on `/history/office/temp`, STOP — adaptive formula needs revision before merge.
10. Merge, tag `v7.6.9.4`
11. Produce consolidated audit
12. Update #139 on GitHub: add `bug`, `memory`, `esp32-c3` labels + v7.6.9.x milestone per plan Part 0 table; post comment referencing v7.6.9.4 PR, noting partial fix; issue **stays open** for Phase 7 full fix
13. Run Phase V closure analysis (`prompts/phaseV/phaseV-closure-analysis-prompt.md`)

---

## Device Testing

| Board | IP | Role |
|---|---|---|
| ESP32-C3 SuperMini | `192.168.120.189` | Satellite |
| ESP32-WROOM-32D | `192.168.120.190` | Satellite (the crash-reproducing board) |
| ESP32-S3-DevKitC1-N16R8 | `192.168.120.191` | Aggregator |

- [ ] C3 `/history/office/temp` returns 200 with CSV (~20 KB expected given current heap budget)
- [ ] **WROOM `/history/office/temp` returns 200 with truncated CSV (≤ 12 KB) — no crash** ← primary success gate
- [ ] S3 `/history/office/temp` returns 200 with full CSV up to 60 KB
- [ ] C3 `httpd_stack_watermark_bytes` does not regress below v7.6.9.0 baseline (~644 B per hotfix 2 measurements)
- [ ] WROOM `min_free_heap` stays above 15 KB after 10 minutes of dashboard traffic
- [ ] Dashboard initial load shows history charts within 15 s in SSE and polling modes
- [ ] `/api/status/full` returns correctly on all three boards (hotfix 2 verification still passes)
- [ ] `/api/status` still returns only `{ok, role, id}` (SEC-ADR RV-03 intact)

**If WROOM still crashes:** capture serial log, use bug escalation prompt (`prompts/handoff/universal-bug-escalation-prompt.md`). Do NOT merge v7.6.9.4 until WROOM is stable. Candidate follow-ups: lower the floor from 12 KB to 8 KB, or switch floor/divisor ratio.

---

## Post-PR Closure Deliverables

### 1. Consolidated Audit

**File:** `prompts/phaseV/v7.6.9.4-PR<NN>-consolidated-audit-and-lessons.md`

Use template: `prompts/phaseV/consolidated-audit-template-phaseV.md`
Use PR audit questions: `prompts/phaseV/pr-audit-question-template-phaseV.md`

### 2. New LESSON-OPS Entry

Topic: heap-adaptive allocation caps on HTTP handlers. Key points:
- Fixed byte thresholds age poorly across SoC variants and future board additions
- `esp_get_free_heap_size() / N` with a floor and ceiling self-calibrates
- Floor prevents starvation cases where the whole request fails rather than just truncating
- Ceiling preserves existing behaviour for healthy boards, containing change blast radius

### 3. Issue #139 Update

On GitHub:
- Add labels per plan Part 0: `bug`, `memory`, `esp32-c3`
- Add milestone: v7.6.9.x (or create if missing)
- Post comment: "Partial mitigation landed in v7.6.9.4 (PR #NN). Heap-adaptive cap replaces the v7.6.8.1 fixed 60 KB cap, resolving the WROOM crash path. Full fix (chunked/windowed history streaming + per-device storage) remains tracked for Phase 7 (v7.7.x)."
- **Do NOT close the issue** — partial fix only. Close when Phase 7 delivers the full fix.

### 4. Phase V Closure

- Fill in `prompts/handoff/phaseV-results.md` v7.6.9.4 row
- Update `prompts/phaseV/phaseV-conclusion-assessment.md` with the V4 deviation and rationale
- Run `prompts/phaseV/phaseV-closure-analysis-prompt.md` in a Claude session

### 5. Plan Amendments Applied

Confirm these edits to `Docs/phase-V-implementation-plan.md` land in the same PR or a follow-up doc PR:
- Line 44 issue-table entry for #139 → `Partial v7.6.8.x (auth cap), partial v7.6.9.4 (adaptive cap + boot sequencing), full fix Phase 7`
- Line 805 V2-E note amended to reference v7.6.9.4 as additional mitigation layer
- Line 1223 decision checklist annotated with the addendum carve-out
- Line 1241 version table updated with the V4 row

---

## Context That Carries Forward

### To v7.6.9.5 (next step — C3 stack watermark investigation)

- Current C3 `httpd_stack_watermark_bytes` baseline: **644 bytes** (from v7.6.9.0 hotfix 2 post-flash `/api/status/full` output). 16 KB patched stack (per LESSON-OPS-097). Remaining headroom represents a stability risk.
- Re-measure watermark after v7.6.9.4 flashes to see if the adaptive cap's reduced peak CSV allocation indirectly improves stack usage (unlikely — heap and stack are independent — but worth confirming as a cheap data point).
- v7.6.9.5 is an investigation step: capture watermark under load scenarios, identify the deepest call chain, decide whether stack bump, call-chain flattening, or handler restructuring is the right remedy.

### To v7.6.9.6 (architectural fix — Cloudflare polling telemetry)

- Root cause: dashboard is served from a public `/dashboard` endpoint (no auth prompt) over Cloudflare Tunnel. `fetch('/api/status/full', {credentials: 'same-origin'})` has no cached Basic Auth to attach. ESP32 returns 401; Cloudflare appears to rewrite the bare 401 reason phrase to an empty `500 ()` surface.
- Required fix: narrow SEC-ADR RV-03 to permit `free_heap` + `uptime_seconds` on public `/api/status`. These two fields are the lowest-sensitivity members of the current `/api/status/full` body. Keep `version`, `sensors[]`, `httpd_stack_watermark_bytes`, and similar fingerprint-ing fields behind auth on `/api/status/full`.
- Dashboard reverts `loadStatusSnapshot()` back to `/api/status` (drops `credentials: 'same-origin'` with it — no longer needed since the endpoint is public).
- v7.6.9.6 is the actual Phase V closure step. Phase V is NOT closed until v7.6.9.6 merges, regardless of v7.6.9.4 / v7.6.9.5 outcomes.

### To Phase 7 planning

- Phase 7 (v7.7.x) planning begins only after v7.6.9.6 merges.
- Issue #139 stays open with a tick-list of remaining deliverables:
  - [ ] Server-side chunked/windowed history response protocol
  - [ ] Dashboard paged history loader
  - [ ] Per-device NVS storage (folds into v7.7.0.x engine rewrite)
- Phase V capacity study (`Docs/phase-V-capacity-study.md`) inputs the 640 KB partition sizing and per-device segment model for Phase 7 — already referenced by the Phase 7 plan

---

_End of session handoff document._
