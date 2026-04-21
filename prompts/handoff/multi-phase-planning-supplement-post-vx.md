# Multi-Phase Planning Session — Post-VX Supplement

_Append this supplement to `prompts/handoff/multi-phase-planning-prompt.md` AFTER Phase VX completes (board onboarding + optional auth refactor)._
_This supplements the v7.6.9.5 supplement — both should be appended._
_Prerequisite: `Docs/board-measurement-log-v7.6.10.md` exists with populated measurements._

---

## Context: What Phase VX Delivered

Phase VX (v7.6.10.x) was an infrastructure sprint between Phase V closure and Phase 7 start. It produced:

1. **ESPHome upgrade** (2026.2.1 → 2026.4.0) — new C6/C5 board support, updated local component override
2. **Board onboarding** — up to 4 new boards (S3 SuperMini, C6 SuperMini, C6 DevKitC, C5) added to provisioning pipeline
3. **Measurement dataset** — `Docs/board-measurement-log-v7.6.10.md` with real telemetry from all boards
4. **Dashboard auth refactor** (if completed as v7.6.10.4) — unified authentication flow eliminating browser native auth dialogs

### What the measurements revealed (fill after VX completes)

_The advisor running the multi-phase planning session should read `Docs/board-measurement-log-v7.6.10.md` and note these values:_

| Board | free_heap (boot) | min_free_heap | httpd_stack_wm | Max persistent metrics | Aggregator viable? |
|---|---|---|---|---|---|
| C3 SuperMini | ___ | ___ | ___ | ___ | No (no PSRAM) |
| WROOM-32D | ___ | ___ | ___ | ___ | No (no PSRAM) |
| S3 DevKitC (8M) | ___ | ___ | ___ | ___ | Yes (current aggregator) |
| S3 SuperMini (2M) | ___ | ___ | ___ | ___ | ___ |
| C6 SuperMini | ___ | ___ | ___ | ___ | No (no PSRAM) |
| C6 DevKitC | ___ | ___ | ___ | ___ | No (no PSRAM) |
| C5 | ___ | ___ | ___ | ___ | ___ |

These measured values supersede the capacity study's estimates where they differ.

---

## Additional Phase 7 Review Questions

**10. Does the Phase 7 plan account for the dashboard auth refactor?**

If Phase VX completed v7.6.10.4 (dashboard auth refactor):
- All fetch calls now use `authFetch()` with explicit `Authorization` headers
- No browser native auth dialogs appear during operation
- Phase 7's new endpoints and dashboard components must use the same `authFetch()` pattern
- New Playwright tests may need fixture updates for the auth module

If Phase VX did NOT complete v7.6.10.4:
- The auth refactor should be folded into early Phase 7 (before any new endpoints are added that the dashboard polls)
- Doing it later means every new endpoint added in Phase 7 will trigger additional browser auth dialogs

**11. Does the Phase 7 plan reference the board measurement dataset?**

Phase 7's memory budget calculations should use measured values from `Docs/board-measurement-log-v7.6.10.md`, not the capacity study's estimates. Specifically:
- The C3's post-BUG-083-fix `free_heap` (~57 KB at boot) is ~13 KB lower than pre-fix because the 16 KB stack is now properly allocated
- The C6 and C5 measurements establish new baseline numbers that weren't available when Phase 7 was planned
- If the S3 SuperMini (2 MB PSRAM) can serve as aggregator, Phase 7's per-device persistence engine may need to accommodate a smaller PSRAM budget

**12. Does the Phase 7 plan handle the ESPHome version upgrade?**

Phase VX upgraded from ESPHome 2026.2.1 to 2026.4.0. Phase 7 should:
- Reference the updated ESPHome version in all build instructions
- Use the updated local component override (re-applied by `patch-esphome-httpd-stack.sh`)
- Note any API changes from the upgrade that affect handler registration or response building

---

## Phase 8 (Captive Portal) — Auth Integration Point

If the dashboard auth refactor completed in Phase VX, Phase 8 (captive portal provisioning) needs to account for it:

- The captive portal will need its own auth flow (WiFi provisioning credentials are distinct from management credentials)
- The `auth.js` module's `authFetch()` pattern should be extended, not duplicated
- Consider whether the captive portal uses the same credential store as management auth, or has a separate provisioning-only credential

---

## Phase 10 (Standalone Role) — Simplified Auth

If producing Phase 10 (standalone role) plans, the dashboard auth refactor changes the auth picture:

- Standalone boards may not need management auth at all (single-user, physical access only)
- The `auth.js` module should have a "no-auth" mode where `authFetch()` degrades to plain `fetch()`
- This could be driven by a firmware flag in `/api/status` (e.g., `"auth_required": false`)

---

## Updated Current State Summary Items

Add these to the Current State Summary (in addition to the v7.6.9.5 supplement's items):

- **ESPHome version:** 2026.4.0 (upgraded in Phase VX)
- **Board fleet:** 3 production + N test boards (N = count of boards that compiled successfully in Phase VX)
- **Dashboard auth:** Application-level credential management via `auth.js` module (if v7.6.10.4 completed). All fetch calls use `authFetch()`. Browser native auth dialogs eliminated.
- **Local component override:** Re-applied for ESPHome 2026.4.0. `patch-esphome-httpd-stack.sh --check` passes. Stack size uniform 16 KB.
- **Known board compilation failures:** List any C6/C5 boards that failed to compile in Phase VX — these constrain Phase 7/8/10 planning for those board families.

---

_End of post-VX multi-phase planning supplement._
