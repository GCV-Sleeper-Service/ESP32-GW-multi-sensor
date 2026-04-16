# Session Log - v7.6.8.0

Date: 2026-04-15
Branch: codex/v7.6.8.0-auth-guards-status-strip
PR: #180

## Scope
- V2-A: Added auth guard to `handle_api_ingest_()`.
- V2-B: Removed LESSON-OPS-089 exception and added auth guard to `handle_add_satellite_()`.
- V2-C: Added auth guards to aggregator read endpoints (`/api/aggregator/gateways`, `/api/aggregator/live`, `/api/aggregator/proxy/...`).
- V2-D: Split status contract:
  - Public `/api/status` reduced to `{ok, role, id}` (unauthenticated health endpoint).
  - Added auth-gated `/api/status/full` with full telemetry and v7.6.7.3 watermark fields retained.
- V2-D: Added optional `basic_auth` parameter to `fetch_to_buffer()` and updated aggregator polling to fetch `/api/status/full` with credentials.
- Step 5.1: Added LESSON-SEC-001 and marked LESSON-OPS-089 as resolved in `Docs/lessons/build-pipeline.md`.
- Step 5.2: Version bump + provision pipeline executed for `v7.6.8.0`.
- Step 5.3: Updated fixtures for the new public `/api/status` shape.

## Checkpoints
- Checkpoint A:
  - `grep -c "LESSON-OPS-089" firmware/core/web-handler.h` => `0`
  - `grep -A2 "handle_api_ingest_" firmware/core/web-handler.h | grep -c "authenticate_management_"` => `1`
- Checkpoint B:
  - `grep -c "api/status/full" firmware/core/web-handler.h` => pass (>= 3)
  - `grep -c "basic_auth" firmware/core/aggregator-runtime.h` => pass (>= 2)
  - `grep -A 80 "handle_status_full_" firmware/core/web-handler.h | grep -c "min_free_heap"` => `1`
  - `bash scripts/assemble-sensor-history.sh --write && --check` => PASS

## Validation Evidence
- `bash scripts/preflight.sh` => PASS
- Browser suites at PR time:
  - `browser-tests (1sensor)` PASS
  - `browser-tests (2sensor)` PASS
  - `browser-tests (4sensor)` PASS
  - `browser-tests (mixed)` PASS
  - `browser-tests (system)` PASS
  - `browser-tests (3sensor)` FAIL
  - `browser-tests (aggregator)` FAIL

## CI Failure Investigation Notes
- `browser-tests (3sensor)` failure is from BUG-043 request-order assertion expecting first API request `/api/manifest`; current behavior issues `/api/status` first.
- `browser-tests (aggregator)` failure is due fixture mismatch: `tests/fixtures/variants/aggregator/api-status.json` still reports legacy status payload without `role: aggregator`, so aggregator-mode detection never activates and `_aggregatorReady` is never set.

## Notes
- Public `/api/status` intentionally remains unauthenticated and minimal per LESSON-OPS-110 + SEC-ADR-001 constraints.
- `/api/status/full` is the canonical authenticated endpoint for full telemetry in v7.6.8.0.
