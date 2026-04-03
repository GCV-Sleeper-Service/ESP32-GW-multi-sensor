# Session Handoff — v7.6.0.4: Dashboard Add/Remove/Test Satellite UI (Phase D Step 4)

_Date: 2026-04-03_
_Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor_
_Status: v7.6.0.3 is COMPLETE and merged to main. PR #119 merged 2026-04-02. Dashboard satellite management UI remains read-only placeholder._

---

## Project State Summary

**v7.6.0.3** is the current version on `main`. **Phase D Step 3 is COMPLETE.**

### What v7.6.0.3 delivered

- `handle_test_satellite_()` implementation replacing the last 501 stub
- Both `/api/aggregator/test-satellite` routing branches rewired (POST dispatch and GET fallthrough)
- `handle_aggregator_stub_501_()` removed — zero remaining callers — Phase D stub cleanup complete
- `probe_satellite_manifest_()` reused directly (no changes to the helper)
- `std::string url_param` used (Critical Rule 44 / G3 defect avoided)
- `authenticate_management_()` guard added (review fix — was missing from initial commit)
- Whitespace-tolerant parsing for `hardware` and `sensor_count` from `s_proxy_tmp` (review fix)
- Named route constants `AGGREGATOR_TEST_SATELLITE_ROUTE` and `AGGREGATOR_TEST_SATELLITE_ROUTE_LEN`
- URL length guard (`> 200` → `400 "URL too long"`)
- `snprintf` truncation guard (`→ 500 "Response too large"`)
- `s_proxy_tmp` lifetime/thread-safety comment
- Changelog entry, session log, version bump, full artifact regeneration
- PR #119: 25 files changed, 3,547 additions, 2,281 deletions; merged 2026-04-02

### v7.6.0.3 post-merge status

- **2 fixup commits** applied before merge (`c0590de`, `b43340c`) — see PR #119 audit
- **PR #122** — consolidated audit UPDATE document (open, pending merge)
- **Device testing:** COMPLETE — 6/7 tests pass, 1 known T7 failure (architectural, not a bug)

### Device Test Results — v7.6.0.3 (2026-04-03 02:45 UTC)

| # | Test | Expected | Actual | Result |
|---|------|----------|--------|--------|
| T1 | Reachable satellite (189) | 200 + gateway JSON | 200 + ok=true + `{"id":"gw-main","name":"Main Gateway","hardware":"ESP32-C3","sensor_count":5}` | ✅ PASS |
| T4 | No side effects | count unchanged | count unchanged (2) | ✅ PASS |
| T2 | Unreachable URL | 400 | 400 "Satellite unreachable or invalid manifest" | ✅ PASS |
| T3 | Missing URL param | 400 | 400 "Missing url parameter" | ✅ PASS |
| T5 | Bad URL format (ftp://) | 400 | 400 "URL must start with http://" | ✅ PASS |
| T6 | Wrong method GET | 405 JSON | 405 "Method not allowed" (JSON) | ✅ PASS |
| T7 | Wrong method DELETE | 405 JSON | HTTP 000 (empty body) | ⚠️ KNOWN |

**T7 explanation (LESSON-OPS-109):** `HTTP 000` is a transport-layer rejection. `canHandle()` does
not register `HTTP_DELETE` for `/api/aggregator/test-satellite`. ESP-IDF httpd drops the
connection before the handler runs — no JSON 405 is sent. This is architecturally correct
behavior for a POST-only endpoint. The device-test script expected JSON 405; the result is
`HTTP 000` with an empty body. This is consistent with v7.6.0.2 BUG-079 and LESSON-OPS-109.
No code fix required — the endpoint is POST-only and DELETE is correctly rejected.

**Aggregator state at time of testing:**
- 2 satellites: `sat-esp32-4m-190` (reachable), `sat-esp32-4m-188` (unreachable)
- Firmware: v7.6.0.3 at 192.168.120.191

### Cumulative state entering Phase D Step 4

| Phase | Version Range | Status |
|-------|--------------|--------|
| Phase 1–3 | v7.5.0.x–v7.5.3.x | ✅ Complete |
| Phase 4 | v7.5.4.x | ✅ Complete |
| Phase 5 | v7.5.5.x | ✅ Complete |
| Phase 6 | v7.5.6.x | ✅ Complete |
| v7.5.7.0 | Bridge step | ✅ Complete |
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | ✅ Complete 2026-03-31 |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | ✅ Complete 2026-04-02 |
| v7.6.0.3 | POST /api/aggregator/test-satellite | ✅ Complete 2026-04-03 |
| **v7.6.0.4** | **Dashboard add/remove/test UI** | **⬅️ This session** |
| v7.6.0.5 | Playwright tests + Phase D closure | Pending |

---

## Phase D Progress Table

| Version | Scope | Status |
|---------|-------|--------|
| v7.6.0.0 | NVS satellite persistence layer | ✅ Complete 2026-03-29 |
| v7.6.0.1 | POST /api/aggregator/add-satellite | ✅ Complete 2026-03-31 |
| v7.6.0.2 | DELETE /api/aggregator/satellite/{id} | ✅ Complete 2026-04-02 |
| v7.6.0.3 | POST /api/aggregator/test-satellite | ✅ Complete 2026-04-03 |
| **v7.6.0.4** | **Dashboard add/remove/test satellite UI** | **⬅️ Next** |
| v7.6.0.5 | Playwright tests + Phase D closure | Pending |

---

## v7.6.0.4 Scope

Replace the read-only satellite list in `renderSettingsPanel()` with a fully interactive UI:
**Add Satellite form + Remove button per card + enhanced status display.** All three
management endpoints (add, delete, test-satellite) are already operational in firmware.
**NO firmware changes in this step. All changes are JS + HTML + dashboard.h regeneration.**

---

## Key Infrastructure Ready for v7.6.0.4

> This section replaces the "Key infrastructure changes from v7.6.x relevant to v7.6.0.4" pattern
> from prior handoffs. All API endpoints are now implemented and confirmed on device.

### All three management API endpoints — confirmed working

| Endpoint | Method | Auth | Device-tested |
|----------|--------|------|---------------|
| `/api/aggregator/add-satellite` | POST | ❌ Not required | ✅ v7.6.0.1 |
| `/api/aggregator/satellite/{id}` | DELETE | ✅ Required | ✅ v7.6.0.2 |
| `/api/aggregator/test-satellite` | POST | ✅ Required | ✅ v7.6.0.3 |

**Critical implication for v7.6.0.4 dashboard code:**
- `POST /api/aggregator/test-satellite` and `POST /api/aggregator/add-satellite` are POST
  endpoints — all `fetch()` calls to them **MUST** use `Content-Type:
  application/x-www-form-urlencoded` and `body: 'a=1'` (Critical Rule 38).
- `DELETE /api/aggregator/satellite/{id}` requires no body but does require auth. The dashboard
  currently sends credentials via the browser session (Basic Auth cookies or pre-auth from
  ESPHome). Verify how existing management fetch calls handle auth before following the same
  pattern.
- `POST /api/aggregator/test-satellite` is subject to the **inherited management POST
  non-empty-body guard** — `handleRequest()` rejects empty bodies with `400 "Non-empty body
  required for management POST"`. The `body: 'a=1'` pattern satisfies this guard.

### `renderSettingsPanel(gateways)` — current state

This function currently builds a **read-only** `.settings-panel` container with per-satellite
cards and status dots. The v7.6.0.4 prompt instructs replacing its **entire body** with the
new interactive version. The existing call site in `initAggregatorDashboard()` does not change.

### `_pollAggregatorGateways()` — periodic refresh

Periodic refresh still uses this function. After any add/remove, the UI should trigger a fresh
`fetch()` against `/api/aggregator/gateways` and re-render, not wait for the next poll cycle.
The `_refreshSettingsPanel()` helper in the prompt handles this correctly.

---

## ⚠️ v7.6.0.4 Prompt Audit

> Based on the v7.6.0.3 PR #119 audit findings, the v7.6.0.4 prompt
> (`prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md`) was inspected
> against `Docs/writing-prompts-for-coding-agents-guide.md`. The following issues must be
> corrected **before** the coding agent is invoked.

### P1 — §3 Current Status date is stale (MUST FIX)

**Location:** §3 line: `Current date: <INSERT_DATE>`

The `<INSERT_DATE>` placeholder was never filled in. The agent must be told the current date
and must know v7.6.0.3 is now complete on `main`.

**Correction:** Replace the current §3 block with:
```
## 3. Current Status

- v7.6.0.3 complete and merged 2026-04-03 (test-satellite endpoint)
- All three management endpoints operational:
  - POST /api/aggregator/add-satellite (200/400/409)
  - DELETE /api/aggregator/satellite/{id} (200/404)
  - POST /api/aggregator/test-satellite (200/400) — includes authenticate_management_() guard
- Device testing complete: v7.6.0.3 confirmed at 192.168.120.191 (6/7 tests pass;
  T7 DELETE is HTTP 000 transport-layer rejection — architectural, not a bug)
- main is green, all Playwright tests pass
- Current date: 2026-04-03
```

### P2 — §5f `_handleRemoveSatellite()` sends DELETE without `body: 'a=1'` — verify correct

**Location:** §5f, `_handleRemoveSatellite()`:
```javascript
fetch(ESP_HOST + '/api/aggregator/satellite/' + encodeURIComponent(satId), {
  method: 'DELETE', cache: 'no-store'
})
```

The DELETE endpoint does **not** use `is_management_post_route_()`, so it does not inherit the
non-empty-body guard. Critical Rule 38 applies to POST/PUT — DELETE with no body is correct.
However, the DELETE endpoint **requires** `authenticate_management_()`. Confirm that the
existing ESPHome dashboard auth pattern passes credentials on the DELETE request. If the
dashboard uses session-based Basic Auth (token in header from prior login), it is already
included by the browser. If not, this fetch needs explicit auth headers.

**Action:** Add a note in §5f that the DELETE request inherits auth from the browser session and
does not need `body: 'a=1'`. This prevents the agent from either (a) skipping auth on DELETE or
(b) incorrectly adding `body: 'a=1'` to DELETE.

### P3 — §5f `_handleTestSatellite()` and `_handleAddSatellite()` use POST correctly ✅

Both functions correctly include:
```javascript
headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
body: 'a=1'
```
This satisfies Critical Rule 38 and the inherited management POST non-empty-body guard.
No correction needed — note for the record.

### P4 — §5d prompt code block is a skeleton, marked as such ✅

Unlike v7.6.0.3's §5d which was a copy-ready snippet with production defects (P1: auth missing,
P2: compact JSON), the v7.6.0.4 §5e is explicitly a **skeleton**. The `// ── Add Satellite
form ──` comments make the illustrative intent clear.

However, per the writing guide improvement identified in the v7.6.0.3 audit (G-Audit-1):
add the following preamble comment to §5e and §5f:

> **NOTE for coding agent:** Code blocks in §5e and §5f are **production-quality skeletons**.
> Cross-check all event bindings and fetch patterns against the existing dashboard before using.
> Do not copy without reading §2 and §12 (Snippet Quality Gates) first.

### P5 — §7 Critical Rules count is correct ✅

Prompt states "All 44 Critical Rules" — this matches the current count (Rules 43–44 added
during v7.6.0.1 era for BUG-078/077). No correction needed.

### P6 — §11 Device Testing section references `minify-dashboard.sh` — verify it exists

**Location:** §11 Prerequisites:
```bash
bash scripts/minify-dashboard.sh
```

This script is referenced as "CRITICAL for this step" but was not mentioned in prior prompts
or session logs. Verify the script exists at `scripts/minify-dashboard.sh` before the agent
runs. If it does not exist, either create it or update §11 to use `generate-header.sh` alone
(which is referenced in §5i and §10).

**Action:** Confirm `scripts/minify-dashboard.sh` exists. If not, flag to human before
invoking the agent.

### P7 — §13 Session log filename format — verify consistency with prior sessions

Prior session logs follow: `Docs/session-log-YYYY-MM-DD-v7.6.0.3.md`
§13 instructs: `Docs/session-log-<DATE>-v7.6.0.4.md`

The `<DATE>` placeholder needs to be pre-filled with today's date (`2026-04-03`) or instructed
to use the current date. Note that the agent wrote the v7.6.0.3 session log correctly without
being told the date — but being explicit avoids filename inconsistency.

---

## Lessons from v7.6.0.3 Directly Relevant to v7.6.0.4

### LESSON-OPS-108 — handleRequest() GET fallthrough method guard

Not relevant to v7.6.0.4 (no new firmware routes). But **dashboard fetch() method selection
must match the registered endpoint method exactly**. POST to a POST endpoint, DELETE to a
DELETE endpoint. The agent must not accidentally call `test-satellite` with GET.

### LESSON-OPS-109 — Plain-text 405 vs JSON 405

Not relevant to v7.6.0.4 (no firmware changes). Documented for completeness.

### LESSON-OPS-110 — Prompt code blocks must include explicit auth policy (2026-04-03)

**Directly relevant.** The v7.6.0.3 audit established: every endpoint prompt code block must
include an explicit auth decision. For dashboard JS, the equivalent is: every fetch() call
to a management endpoint must have an explicit note about whether it inherits auth from the
browser session or requires explicit headers.

**Applied to v7.6.0.4:**
- `POST test-satellite` — requires auth (authenticated via ESPHome session cookies; no
  explicit header needed if ESPHome Basic Auth is in use, but must verify)
- `POST add-satellite` — does NOT require auth (intentional policy from v7.6.0.1)
- `DELETE satellite/{id}` — requires auth (same session-cookie pattern)

### Whitespace-tolerant parsing reminder

All manifest field extraction from JSON responses uses `strstr`-based parsing in firmware.
The dashboard **receives JSON from the firmware's HTTP responses** — these are properly
formatted JSON strings, not raw manifests. So `data.gateway.hardware`, `data.gateway.sensor_count`,
etc., are standard JS object property accesses. No strstr concerns on the JS side.

### JSON escaping is required in JS (different from firmware)

The v7.6.0.3 audit noted that `probe_id`, `probe_name`, `hw_str` are not JSON-escaped in
firmware (accepted known limitation). On the **JS side**, `escHtml()` must be called on every
config-derived or manifest-derived string inserted into HTML. The prompt §5d already requires
this — it is a quality gate in §12. The agent must not skip it.

---

## v7.6.0.4 API Contract (for dashboard fetch() calls)

All three endpoints are confirmed working. Dashboard JS must use these exact contract rows.

### POST /api/aggregator/test-satellite

```
POST /api/aggregator/test-satellite?url=http://192.168.x.x
Content-Type: application/x-www-form-urlencoded
Body: a=1
```

| Condition | HTTP | Response |
|-----------|------|----------|
| Valid URL, probe succeeds | 200 | `{"ok":true,"gateway":{"id":"...","name":"...","hardware":"...","sensor_count":N}}` |
| Missing `url` parameter | 400 | `{"ok":false,"message":"Missing url parameter","status":400}` |
| URL doesn't start with `http://` | 400 | `{"ok":false,"message":"URL must start with http://","status":400}` |
| URL length > 200 chars | 400 | `{"ok":false,"message":"URL too long","status":400}` |
| Probe failed | 400 | `{"ok":false,"message":"Satellite unreachable or invalid manifest","status":400}` |
| Empty POST body | 400 | `{"ok":false,"message":"Non-empty body required for management POST","status":400}` |
| Authentication failure | 401 | `{"ok":false,"message":"Management authentication required","status":401}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |
| Response buffer overflow | 500 | `{"ok":false,"message":"Response too large","status":500}` |

**⚠️ Note:** The `URL length > 200` and `Empty POST body` rows are implementation-added (not
in the v7.6.0.3 original prompt §12). Both are confirmed present in the merged firmware.
The `URL too long` row is relevant if users paste long URLs in the dashboard URL input.

### POST /api/aggregator/add-satellite

```
POST /api/aggregator/add-satellite?url=...&name=...&poll=...
Content-Type: application/x-www-form-urlencoded
Body: a=1
```

| Condition | HTTP | Response |
|-----------|------|----------|
| Satellite added successfully | 200 | `{"ok":true,"id":"...","name":"...","satellite_count":N}` |
| Missing `url` param | 400 | `{"ok":false,"message":"Missing url parameter","status":400}` |
| Bad URL format | 400 | `{"ok":false,"message":"...","status":400}` |
| Max satellites reached | 400 | `{"ok":false,"message":"Max satellites reached","status":400}` |
| Duplicate URL | 409 | `{"ok":false,"message":"Satellite already exists","status":409}` |
| Probe failed | 400 | `{"ok":false,"message":"Satellite unreachable or invalid manifest","status":400}` |
| Empty POST body | 400 | `{"ok":false,"message":"Non-empty body required for management POST","status":400}` |

### DELETE /api/aggregator/satellite/{id}

```
DELETE /api/aggregator/satellite/{satellite_id}
```

| Condition | HTTP | Response |
|-----------|------|----------|
| Satellite deleted | 200 | `{"ok":true}` |
| Unknown ID | 404 | `{"ok":false,"message":"Unknown satellite ID","status":404}` |
| Authentication failure | 401 | `{"ok":false,"message":"Management authentication required","status":401}` |
| Wrong HTTP method | 405 | `{"ok":false,"message":"Method not allowed","status":405}` |

---

## Pre-merge Checklist for v7.6.0.4

- [ ] v7.6.0.3 merged, tagged (`v7.6.0.3`), all fixups committed
- [ ] PR #122 (audit UPDATE) merged or noted as open
- [ ] Prompt audit issues P1–P7 addressed (see section above)
- [ ] `scripts/minify-dashboard.sh` confirmed to exist
- [ ] Playwright CI all passing:
  - [ ] 3sensor chromium
  - [ ] 3sensor firefox
  - [ ] Mixed chromium
  - [ ] System chromium
  - [ ] Aggregator chromium
- [ ] `preflight.sh` passes
- [ ] `render_sensor_config.py --check` passes
- [ ] `escHtml()` used on all dynamic HTML strings (§12 quality gate)
- [ ] Programmatic event binding only — no inline `onclick`/`oninput`/`onchange`
- [ ] `dashboard.html` mirrors ALL JS changes (LESSON-OPS-043 — highest-risk single failure)
- [ ] `generate-header.sh` run after all changes
- [ ] Dark mode verified for all new inputs and buttons
- [ ] Device testing completed (see Device Testing section below)
- [ ] Switched back to CI-safe mode: `bash scripts/provision.sh satellite`

---

## v7.6.0.4 Prompt Known Issues (Must Address Before Invoking Agent)

| # | Issue | Location | Correction |
|---|-------|----------|------------|
| P1 | `<INSERT_DATE>` placeholder not filled | §3 | Replace with `2026-04-03`, update status to reflect v7.6.0.3 complete |
| P2 | DELETE fetch auth not documented | §5f | Add inline comment noting auth is inherited from ESPHome session |
| P4 | Code blocks not marked as illustrative | §5e/§5f preamble | Add "cross-check before use" note per G-Audit-1 writing guide improvement |
| P6 | `minify-dashboard.sh` existence not verified | §11 Prerequisites | Confirm script exists before running agent |
| P7 | `<DATE>` in session log filename | §13 | Pre-fill with `2026-04-03` |

> **P3 and P5 are non-issues** (confirmed correct as-is). See detail in Prompt Audit section.

---

## Critical Rules Particularly Relevant to v7.6.0.4

| # | Rule | Why Especially Relevant |
|---|------|-------------------------|
| 6 | Mirror JS → HTML (LESSON-OPS-043) | **THE highest-risk single failure for this step** |
| 9 | dashboard.h must be gzip-compressed | `generate-header.sh` handles this |
| 16 | `color-scheme` CSS for native widgets | All new `<input>` and `<button>` elements |
| 28 | Both generators + verify | Full regeneration pipeline |
| 38 | Dashboard POST → `x-www-form-urlencoded`, `body: 'a=1'` | **All three management fetch() POST calls** |
| 39 | curl POST → `-d 'a=1'` | Device testing commands |
| 44 | Never use Arduino `String` | N/A — no firmware changes; still applies if agent drifts |

---

## v7.6.0.3 Lessons Relevant to v7.6.0.4

### LESSON-OPS-110 — Auth policy must be explicit in every endpoint prompt section

For dashboard JS: every `fetch()` to a management endpoint must have a documented auth
intention. This prevents the agent from accidentally omitting credentials (as happened in
v7.6.0.3's initial commit on the firmware side).

Auth summary for dashboard calls:
- `test-satellite` POST → auth required → inherited from ESPHome session
- `add-satellite` POST → **no auth required** (intentional policy)
- `satellite/{id}` DELETE → auth required → inherited from ESPHome session

### LESSON-OPS-043 — JS/HTML mirror (pre-existing, elevated to top concern)

The v7.6.0.3 PR introduced no JS changes, so LESSON-OPS-043 did not apply. v7.6.0.4 is
primarily a JS change — this lesson is the top risk for this step.

### Inherited route-level behavior applies to fetch() POST calls

The management POST body guard (`Non-empty body required for management POST`) fires BEFORE
the handler. The dashboard `body: 'a=1'` pattern correctly satisfies it. The agent must not
remove `body: 'a=1'` thinking it is unnecessary padding.

### v7.6.0.3 PR prompt-snippet pattern was the source of 2 review fixup commits

The coding agent for v7.6.0.3 faithfully reproduced the prompt's code block, including its
defects. For v7.6.0.4, the risk is the same: if the agent copies the `_handleRemoveSatellite()`
scaffold without checking auth behavior against the actual ESPHome session pattern, it may
omit or incorrectly handle credentials.

---

## Workflow for v7.6.0.4

> **⚠️ IMPORTANT: Do NOT open PR immediately after reading this document — ask human if PR
> for this session has been opened yet and if yes, ask to provide PR number to work on.**
> **⚠️ IMPORTANT: Do NOT use this chat session to invoke the coding agent directly.**
> **⚠️ IMPORTANT: If something is not clear when reading instructions, stop and ask for
> clarification.**

1. Verify `scripts/minify-dashboard.sh` exists — if not, flag to human before proceeding
2. Apply prompt corrections P1, P2, P4, P6, P7 to
   `prompts/phaseD/v7.6.0.4-implementation-instructions-for-coding-agent.md`
3. Ask human if PR for v7.6.0.4 has been opened and ask to provide the PR number
4. If PR has not been opened, **open a NEW coding agent session outside of this chat** and
   paste the corrected prompt
5. Wait for the agent to create the PR
6. Copilot PR reviewer reviews automatically and additional reviews might be posted
7. Human reviews PR against the Review Checklist in the prompt (§12 quality gates)
8. Fix any issues (expect at least one review round — dashboard mirroring is the likeliest
   missed item)
9. **Produce PR and prompt audit documents** (see Post-PR Closure section below)
10. Provide device testing instructions
11. Provide merge + tag instructions

---

## Post-PR Closure Deliverables for v7.6.0.4

After the v7.6.0.4 PR is merged:

### 1. Session Handoff Document

**File:** `prompts/handoff/session-handoff-v7.6.0.5.md`
**Format:** Same structure as this document.

### 2. PR and Prompt Audit Document

**File:** `prompts/phaseD/v7.6.0.4-PR<NN>-consolidated-audit-and-lessons.md`
**Format:** Same structure as `prompts/phaseD/v7.6.0.3-PR119-consolidated-audit-and-lessons-UPDATE.md`

**Must answer:**
- Did the coding agent deliver properly and accurately what was required?
- Did the codebase state match the prompt's assumptions?
- What implementation decisions did the agent make beyond the prompt?
- Coding agent prompt audit against the writing guide (especially P1–P7 from this document)
- PR comment review and disposition
- Fixes implemented (per-commit if multiple rounds)
- Remaining issues and deferred fixes

**Additional quality check specific to v7.6.0.4:**
- Was LESSON-OPS-043 (JS/HTML mirror) correctly followed?
- Were all fetch() calls using the correct method, headers, and body?
- Was `escHtml()` applied to all dynamic HTML insertions?
- Did dark mode work correctly for all new inputs and buttons?

### 3. Updated prompt-index-and-workflow.md

Mark v7.6.0.3 and v7.6.0.4 as complete with dates.

---

## Device Testing Audit & Automated Script

> **⚠️ MANDATORY SECTION — required in every handoff document.**

### Why this section exists

Experience from Phase D (v7.6.0.1–v7.6.0.3) established:
1. Prompt-provided device tests may have gaps vs. actual implementation
2. Manual curl sequences are error-prone (missing `-d 'a=1'`, wrong timing)
3. Test results must be machine-parseable for audit documentation
4. The v7.6.0.3 device test script had a T7 expectation mismatch (transport 000 vs JSON 405)

### Pre-implementation gap analysis — v7.6.0.4

v7.6.0.4 is a **dashboard-only change** (no firmware). Device testing focuses on the browser
UI and HTTP interactions from the dashboard. The automated script approach (curl) remains valid
for verifying the firmware endpoints still behave correctly, but the primary validation is:

1. **Visual browser testing** — Settings panel renders correctly
2. **JS interaction testing** — Test/Add/Remove buttons function as expected
3. **Dark mode testing** — New inputs and buttons render in both themes
4. **Re-render verification** — Panel refreshes after add/remove

Firmware-side API contracts are unchanged from v7.6.0.3. The device test focus for v7.6.0.4
is UI behavior, not endpoint behavior.

### Device test script for v7.6.0.4

A dedicated `scripts/device-test-v7.6.0.4.sh` should be created to test the full UI interaction
flow from a headless perspective. Since Playwright tests are deferred to v7.6.0.5, the script
should at minimum verify:

| # | Test | Method | Expected |
|---|------|--------|----------|
| T1 | Settings panel HTML includes new elements | curl `/` | `add-sat-form` and `add-sat-btn` present in response |
| T2 | Test satellite via dashboard endpoint | curl POST test-satellite | 200 + gateway JSON |
| T3 | Add satellite via dashboard | curl POST add-satellite | 200 + new satellite in gateways |
| T4 | Remove satellite via dashboard | curl DELETE | 200 + satellite gone from gateways |
| T5 | Re-add satellite | curl POST add-satellite | 200 + count restored |
| T6 | Error handling — duplicate add | curl POST add-satellite (duplicate) | 409 |
| T7 | Error handling — bad URL format | curl POST test-satellite (ftp://) | 400 |

**⚠️ Gap from §11 prompt:** The prompt's §11 device tests are browser-centric ("Navigate to
http://192.168.120.191, click Settings"). These cannot be automated with curl. The gap:
- §11 Tests 1–5 are manual browser tests — no automated equivalent until v7.6.0.5 Playwright
- T1–T7 above are curl-level verification that the dashboard's fetch() calls would succeed
- Human visual verification for dark mode and UI rendering is required

### Provisioning workflow

```bash
# Before device testing:
bash scripts/provision.sh aggregator   # switch to S3 aggregator mode
python3 scripts/render_sensor_config.py --write
node tests/fixtures/generate-fixtures.js
bash scripts/minify-dashboard.sh       # if exists
bash scripts/generate-header.sh
esphome clean firmware/esp32-s3-devkitc1-n16r8-gw.yaml
esphome run firmware/esp32-s3-devkitc1-n16r8-gw.yaml
bash scripts/device-test-v7.6.0.4.sh 192.168.120.191  # once created

# After device testing, before push:
bash scripts/provision.sh satellite    # switch back to CI-safe mode
bash scripts/provision.sh status       # verify CI-safe=YES
```

---

## Device Testing Resources

- **S3 aggregator** (ESP32-S3-DevKitC-1 at 192.168.120.191, PSRAM-equipped, serial `/dev/ttyACM0`)
- **C3 satellite** (ESP32-C3 SuperMini at 192.168.120.189) — `gw-main`, `Main Gateway`, `ESP32-C3`, 5 sensors
- **WROOM-32D satellite** (ESP32-WROOM-32D at 192.168.120.190) — `sat-esp32-4m-190`, reachable
- **Placeholder satellite** (sat-esp32-4m-188 at 192.168.120.188 — in satellite list, unreachable API)

Current aggregator state (as of v7.6.0.3 device test):
- 2 satellites configured: `sat-esp32-4m-190` (reachable), `sat-esp32-4m-188` (unreachable)
- MAX_SATELLITES=3 (one slot available for add testing)

---

_End of session handoff document._
