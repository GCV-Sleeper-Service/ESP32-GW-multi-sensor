# Dashboard Authentication Refactor — Issue Template

_Copy the Title and Body sections below into a new GitHub issue._
_This file also serves as the design spec for producing agent prompts in Phase VX (v7.6.10.4)._

---

## Title

Enhancement: Unified dashboard authentication — eliminate mid-session browser auth dialogs

## Labels

`enhancement`, `dashboard`, `ux`, `security`

## Milestone

Phase VX (v7.6.10.x)

## Body

### Problem

The dashboard polls several auth-gated HTTP endpoints during normal operation. When the browser's cached HTTP Basic Auth credentials expire (browser-dependent timing), it shows a **native Sign In dialog** mid-session. This interrupts monitoring and creates a confusing UX — users expect authentication once on dashboard open, not repeatedly during operation.

**Affected endpoints (auth-gated, polled by dashboard):**
- `/api/status/full` — polled every 30s in polling mode (`status-snapshot.js`)
- `/api/gateways` — polled every 30s in polling mode (`aggregator-ui.js` or equivalent)
- `/storage-stats` — polled every 120s (`storage-stats.js`)
- History endpoints (`/history/{id}/{series}`) — fetched on boot and chart range changes

**Observed behavior (v7.6.9.5):**
1. Dashboard loads successfully via both LAN (SSE mode) and Cloudflare Tunnel (polling mode)
2. After some time (minutes to hours), the browser shows a native "Sign in" dialog for the hostname
3. If user clicks Cancel, one poll cycle fails (401 visible in Network tab), then next cycle triggers another dialog
4. On the S3 aggregator, **two different auth dialogs** appear: the custom JS-level "Management authentication required" dialog AND the browser's native dialog
5. Even SSE mode triggers auth dialogs when companion status/gateways fetches hit auth-gated endpoints

**Root cause chain:**
- v7.6.8.0 (SEC-ADR RV-03) moved sensitive fields from `/api/status` to `/api/status/full` (auth-gated)
- Dashboard `loadStatusSnapshot()` calls `/api/status/full` with `credentials: 'same-origin'`
- `credentials: 'same-origin'` relies on the browser's cached Basic Auth realm — when the cache expires, the browser pops its native dialog
- The custom aggregator auth dialog (from `requestManagementCredentials()`) is a separate layer that doesn't share state with the browser's native auth cache

**What this is NOT:**
- This is not the original Cloudflare HTTP 500 issue — that was BUG-078 (fixed in v7.6.0.1, `init_response_()` status code switch expansion)
- This is not a security vulnerability — auth is working correctly, the UX is just disruptive

### Design Requirements

**Goal:** Authentication should happen ONCE on dashboard open, then all subsequent API calls should include credentials automatically without any further user interaction.

**Approach — Application-level credential management:**

1. **On dashboard load**, detect whether auth-gated endpoints are available:
   - Attempt a single `fetch('/api/status/full', {cache:'no-store'})` without credentials
   - If 401: show the custom auth dialog (the "Management authentication required" one already in the aggregator code)
   - If 200: no auth needed (e.g., future public deployment mode)

2. **Store credentials in a JS variable** (session-scoped, not persistent):
   ```javascript
   let _authHeader = null;  // Set after successful auth: 'Basic <base64>'
   ```
   Do NOT use `localStorage` or `sessionStorage` — these are blocked in artifacts and inappropriate for embedded device credentials.

3. **Inject `Authorization` header in every `fetch()` call:**
   ```javascript
   function authFetch(url, opts = {}) {
     if (_authHeader) {
       opts.headers = Object.assign({}, opts.headers, { 'Authorization': _authHeader });
     }
     return fetch(url, opts);
   }
   ```
   Replace all `fetch()` calls in polling/status/gateways/history/storage-stats modules with `authFetch()`.

4. **Never rely on browser-managed credentials.** Remove `credentials: 'same-origin'` from all fetch calls. The `Authorization` header sent explicitly by JS takes precedence over browser-cached realm auth, and no browser dialog will appear when the explicit header is present.

5. **Handle 401 during operation gracefully:**
   - If any `authFetch()` gets a 401 response: clear `_authHeader`, show the custom auth dialog again
   - After re-authentication: resume polling automatically (no page reload needed)

6. **Unify satellite and aggregator auth:**
   - The aggregator has `requestManagementCredentials()` with a custom HTML dialog
   - Satellites rely solely on browser native auth
   - After this refactor, both should use the same custom dialog and `authFetch()` pattern

### Files to Modify

**Core module (new or extended):**
- `dashboard/core/auth.js` — new module: `authFetch()`, `requestAuth()`, `clearAuth()`, `isAuthenticated()`

**Modules that call `fetch()` directly (each needs `authFetch()` swap):**
- `dashboard/core/status-snapshot.js` — `loadStatusSnapshot()`
- `dashboard/core/polling.js` — `startPolling()` batch fetches
- `dashboard/core/sse.js` — SSE connection setup (if it uses fetch for initial handshake)
- `dashboard/components/storage-stats/storage-stats.js` — `loadStorageStats()`
- `dashboard/components/aggregator-ui/aggregator-ui.js` — `pollAggregatorLive()`, `requestManagementCredentials()`
- `dashboard/components/history/history.js` — `loadHistory()`, history range fetches
- `dashboard/components/management/management.js` — reboot, delete, import buttons

**Template:**
- `dashboard/dashboard.tmpl.html` — ensure auth dialog HTML is present in template (may already be there from aggregator code)

**Pipeline (mandatory after changes):**
- Run full pipeline: `bundle-dashboard.sh --write` → `render_sensor_config.py --write` → `build-dashboard.sh --write` → `minify-dashboard.sh` → `generate-header.sh` → `render_sensor_config.py --check`

### Acceptance Criteria

1. **Fresh browser (no cached credentials):** Open dashboard → custom auth dialog appears → enter credentials → dashboard loads and operates indefinitely without another auth prompt
2. **Wrong credentials:** Enter wrong credentials → dialog shows error → retry → correct credentials work
3. **Cancel:** Click Cancel → dashboard loads in degraded mode (public endpoints only — sensor names visible but no heap/uptime/gateways)
4. **Mid-session credential expiry simulation:** While dashboard is running, manually clear browser site data → next poll cycle triggers custom dialog (not browser native) → re-enter credentials → polling resumes
5. **Both transports:** Works in SSE mode (LAN) and polling mode (Cloudflare Tunnel)
6. **Aggregator vs satellite:** Same auth experience on both board types (aggregator may show additional aggregator-specific UI after auth, but the auth flow itself is identical)
7. **No browser native auth dialogs:** The browser's built-in "Sign in" prompt NEVER appears during normal operation
8. **Playwright:** All existing tests pass (test fixtures may need updating if they relied on `credentials: 'same-origin'` behavior)

### Out of Scope

- No changes to firmware auth logic (keep HTTP Basic Auth as-is)
- No persistent credential storage (no localStorage/sessionStorage/cookies)
- No multi-user support
- No OAuth/SSO/token-based auth (that's Phase E territory)
- No changes to which endpoints are auth-gated vs public

### Related

- BUG-078: `init_response_()` 401→500 mapping (fixed v7.6.0.1) — the original Cloudflare 500 issue
- SEC-ADR-001 RV-03: `/api/status` field strip decision (v7.6.8.0)
- BUG-083: C3 missing external_components (fixed v7.6.9.5) — unrelated but same phase

---

_End of issue template._
