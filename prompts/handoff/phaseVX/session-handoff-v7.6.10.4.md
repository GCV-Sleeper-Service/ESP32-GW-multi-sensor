# Session Handoff Prompt — v7.6.10.4: Dashboard Authentication Refactor

_Use this prompt to start a new Claude session for v7.6.10.4._
_This prompt captures the full context from the v7.6.10.3 advisory session (2026-05-05)._

---

## Instructions for Claude

Please clone and understand the repo:
https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/

Checkout `main` (v7.6.10.3 documentation updates should be applied by now).

Before responding, read these files in order:
1. `prompts/handoff/dashboard-auth-refactor-issue.md` — **the design spec** (most important)
2. `prompts/handoff/phaseVX/phaseVX-board-onboarding-sprint-prompt.md` — overall sprint plan
3. `prompts/handoff/phaseVX/session-handoff-v7.6.10.3.md` — v7.6.10.3 context
4. `Docs/board-measurement-log-v7.6.10.md` — measurement data and anomalies
5. `prompts/prompt-index-and-workflow.md` — Phase VX section
6. `Docs/architecture-overview.md` — current architecture state

**Dashboard code (read ALL of these):**
7. `dashboard/core/status-snapshot.js` — the `loadStatusSnapshot()` function that triggers browser auth
8. `dashboard/core/boot.js` — dashboard initialization sequence
9. `dashboard/core/app-shell.js` — application lifecycle
10. `dashboard/core/history.js` — history fetch logic
11. `dashboard/core/manifest.js` — manifest fetch logic
12. `dashboard/components/auth-modal/index.js` — **existing auth modal** (already has `requestManagementCredentials()`)
13. `dashboard/components/auth-modal/template.html` — auth dialog HTML
14. `dashboard/components/auth-modal/styles.css` — auth dialog styles
15. `dashboard/components/gateway-panel/index.js` — aggregator UI with fetch calls
16. `dashboard/components/settings-panel/index.js` — storage-stats fetch
17. `dashboard/components/live-view/index.js` — SSE and live data fetch
18. `dashboard/components/import-panel/index.js` — import operations
19. `dashboard/components/custom-range/index.js` — storage-stats fetch

**Firmware auth handler (read but do NOT modify):**
20. `firmware/core/web-handler.h` — search for `authenticate_management_` to see which endpoints are auth-gated

**Build pipeline:**
21. `scripts/bundle-dashboard.sh` — CSS/JS bundling
22. `scripts/build-dashboard.sh` — template assembly
23. `scripts/minify-dashboard.sh` — minification
24. `scripts/generate-header.sh` — C header generation

**Test infrastructure:**
25. `tests/browser/` — all `.spec.js` files
26. `tests/mock-server/` — mock server that handles test fixtures

---

## Project Context

### Current State (as of v7.6.10.3)

Phase VX (Board Onboarding Sprint) is nearly complete:

| Step | Scope | Status |
|---|---|---|
| v7.6.10.0 (PR #200) | ESPHome 2026.4.1 upgrade | ✅ Merged |
| v7.6.10.1 (PR #201) | 3 new board profiles | ✅ Merged |
| v7.6.10.2 | Operator measurements | ✅ Complete |
| v7.6.10.3 | Documentation update | ✅ Complete |
| **v7.6.10.4** | **Dashboard auth refactor** | **⬅️ This session** |

### The Problem

The dashboard polls several auth-gated HTTP endpoints during normal operation. When the browser's cached HTTP Basic Auth credentials expire, it shows a **native Sign In dialog** mid-session. This interrupts monitoring. Observed on both satellite and aggregator dashboards.

**Affected auth-gated endpoints polled by dashboard:**
- `/api/status/full` — polled every 30s in polling mode
- `/api/gateways` — polled every 30s on aggregator
- `/api/storage-stats` — polled every 120s
- `/history/{id}/{series}` — fetched on boot and chart range changes

**Root cause:** The dashboard uses `credentials: 'same-origin'` for `/api/status/full` and relies on browser-managed Basic Auth for other endpoints. When the browser's auth cache expires, native dialogs appear.

### The Solution

Application-level credential management via a new `auth.js` core module:
1. On dashboard load: probe `/api/status/full` without credentials
2. If 401: show the custom auth dialog (already exists in `auth-modal` component)
3. Store credentials in a JS variable (`let _authHeader = null`)
4. Inject `Authorization` header via `authFetch()` wrapper in every fetch call
5. Handle 401 during operation: clear credentials, show dialog again
6. Remove all `credentials: 'same-origin'` from fetch calls

**Key: the auth-modal component already exists.** It has a working HTML dialog with username/password fields, show/hide toggle, error display, and cancel/submit buttons. The `requestManagementCredentials()` function is fully implemented. This refactor extends it from aggregator-only use to universal dashboard authentication.

### Critical Constraints

- **No firmware changes.** Keep HTTP Basic Auth as-is. Only dashboard JS/CSS/HTML changes.
- **No persistent credential storage.** No localStorage/sessionStorage/cookies. Session-scoped JS variable only.
- **POST body handling:** All POST requests use `Content-Type: application/x-www-form-urlencoded` with `body: 'a=1'`. No JSON POST bodies. (See Critical Rule regarding ESPHome POST handling.)
- **Pipeline is mandatory after changes.** Run full pipeline: `bundle-dashboard.sh --write` → `render_sensor_config.py --write` → `build-dashboard.sh --write` → `minify-dashboard.sh` → `generate-header.sh` → `render_sensor_config.py --check`.
- **Playwright tests must pass.** The mock server's auth handling may need updates for the new `Authorization` header pattern.

### Board IPs for Testing

| Board | IP | Role |
|---|---|---|
| C3 SuperMini | 192.168.120.189 | Satellite |
| WROOM-32D | 192.168.120.170 | Satellite |
| S3 DevKitC N16R8 | 192.168.120.191 | Aggregator |

Credentials: `ESPadmin`/`ESPpass100`

---

## Files to Create / Modify

### New file: `dashboard/core/auth.js`

Core auth module. Exports: `authFetch(url, opts)`, `probeAuth()`, `clearAuth()`, `isAuthenticated()`.

### Modified files (fetch → authFetch conversion):

| File | What changes |
|---|---|
| `dashboard/core/status-snapshot.js` | Replace `fetch(..., {credentials:'same-origin'})` with `authFetch()` |
| `dashboard/core/manifest.js` | Replace `fetch()` calls with `authFetch()` for auth-gated endpoints |
| `dashboard/core/history.js` | Replace `fetch()` with `authFetch()` |
| `dashboard/core/boot.js` | Add auth probe on initialization |
| `dashboard/components/live-view/index.js` | Replace `fetch()` with `authFetch()` |
| `dashboard/components/gateway-panel/index.js` | Replace `fetch()` with `authFetch()`, remove duplicate auth logic |
| `dashboard/components/settings-panel/index.js` | Replace `fetch()` with `authFetch()` |
| `dashboard/components/custom-range/index.js` | Replace `fetch()` with `authFetch()` |
| `dashboard/components/import-panel/index.js` | Replace `fetch()` with `authFetch()` |
| `dashboard/components/auth-modal/index.js` | Extend `requestManagementCredentials()` to set `_authHeader` |

### Pipeline-regenerated files (do NOT edit directly):

- `dashboard/dashboard.js` — regenerated by bundle-dashboard.sh
- `dashboard/dashboard.html` — regenerated by build-dashboard.sh
- `firmware/local_components/web_server_idf/dashboard.h` — regenerated by generate-header.sh

---

## Acceptance Criteria

1. **Fresh browser:** Open dashboard → custom auth dialog → enter credentials → dashboard loads and works indefinitely without any further auth prompts
2. **Wrong credentials:** Dialog shows error → retry → correct credentials work
3. **Cancel:** Dashboard loads in degraded mode (public endpoints only)
4. **Mid-session re-auth:** Clear browser site data while dashboard runs → next poll triggers custom dialog (NOT browser native) → re-enter credentials → polling resumes
5. **Both transports:** Works in SSE mode (LAN) and polling mode (Cloudflare Tunnel)
6. **Aggregator + satellite:** Same auth experience on both
7. **No browser native auth dialogs** appear during normal operation
8. **Playwright:** All 402 existing tests pass
9. **Preflight:** All checks pass

---

_End of session handoff prompt._
