# SEC-ADR-001 RV-03 — Documentation-Only Amendment

_Apply this amendment to `Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md`, section RV-03._
_Context: v7.6.9.6 (Cloudflare polling fix) was dropped from Phase V scope. The original HTTP 500 issue was resolved by BUG-078 in v7.6.0.1. A dashboard auth UX refactor is deferred to Phase VX._
_Date: 2026-04-20_

---

## Replacement text for RV-03

Replace the existing RV-03 section (lines ~66–82) with the following:

```markdown
### RV-03 — `/api/status` Public Field Exposure (Partial Mitigation)

**Vulnerability:**

Before V2-D, `/api/status` exposes `version`, `free_heap`, `free_heap_internal`, `uptime_s`, `wifi_rssi`, and hardware identifiers in a public (unauthenticated) response. This allows a passive attacker to fingerprint the firmware version, infer board type from heap values, and detect reboots via uptime.

**Mitigation (V2-D, v7.6.8.0):**

The public `/api/status` response is stripped to include only `{"ok":true,"role":"...","id":"..."}` (non-sensitive fields). The full response is moved to the new `/api/status/full` endpoint, which requires authentication.

**Residual exposure:**

`role` and `id` still identify the device as an ESP32 firmware node. The `id` field may disclose the satellite's hostname. This is accepted risk for a LAN deployment; for internet exposure, operators should use Cloudflare Access or similar to gate all `/api/` paths behind SSO.

**Dashboard interaction (v7.6.9.5 state):**

The dashboard calls `/api/status/full` in both SSE and polling modes to display Free Heap, Uptime, and telemetry chart data. This endpoint requires HTTP Basic Auth. The browser handles credential management via its native "Sign in" dialog:

- On first access, the browser prompts for credentials. Once entered, the browser caches them for the auth realm and sends them with subsequent requests.
- When the browser's cached credentials expire (browser-dependent timing), it re-prompts with a native dialog. This is a **UX disruption** but not a security issue — auth is functioning correctly.
- BUG-078 (fixed v7.6.0.1) eliminated an earlier problem where the `init_response_()` function mapped HTTP 401 to 500, causing the dashboard to show "Status snapshot failed: HTTP 500" instead of triggering the browser's auth dialog.

A dashboard-level authentication refactor is planned for Phase VX (v7.6.10.4). The refactor will: (1) prompt for credentials via a custom JS dialog on dashboard load, (2) store credentials in a JS session variable, (3) inject `Authorization` headers on all fetch calls explicitly, eliminating browser native auth dialogs entirely. See `prompts/handoff/dashboard-auth-refactor-issue.md` for the full design spec.
```

---

## Also update the RV-03 row in the summary table

In the summary table near the end of SEC-ADR-001 (around line 205), replace the RV-03 row:

**Current:**
```
| RV-03 Status field exposure | V2-D (partial) + Phase E (full) | v7.6.8.0 partial / v8.0.x full |
```

**Replacement:**
```
| RV-03 Status field exposure | V2-D (partial) + Phase VX auth UX | v7.6.8.0 partial / v7.6.10.4 UX fix / v8.0.x full (TLS) |
```

---

_End of SEC-ADR RV-03 amendment._
