# Development Notes - v7.4.0.1 Import/Export Fix Candidate

## Fresh-Start Memory Notes
- Import transport has already been redesigned away from custom headers.
- Current stable direction is URL-path batch import.
- Import now works over both LAN and Cloudflare after pacing/retry/network-quieting changes.
- New defect found after transport stabilization: single-sensor export schema mismatch causes single-sensor re-import to map into Office.
- This patch fixes the schema mismatch in the dashboard layer; firmware was not changed.

## Current Stage
Dashboard-layer bugfix after transport stabilization.

## Scope of This Iteration
- Fix single-sensor export/import mismatch
- Add import duration estimate to confirmation message
- Add approximate remaining-time text during import

## Implementation Approach
1. Make single-sensor export use prefixed metric columns, same convention as merged export.
2. Preserve backward compatibility for old single-sensor files when the sensor can be derived from the filename.
3. Remove unsafe fallback to the first configured sensor.
4. Keep the change dashboard-only to minimize regression surface.

## File Purposes
- `dashboard/dashboard.js` — source of runtime dashboard logic
- `dashboard/dashboard.html` — hosted single-page dashboard with embedded script
- `dashboard/dashboard.h` — generated header payload consumed by firmware

## Smoke / Pre-Flight Check Status
- Static edit completed
- Embedded HTML regenerated
- Embedded header regenerated
- No live compile run from this environment
- No on-device browser validation from this environment

## User Action Instructions
1. Back up current versions of:
   - `dashboard/dashboard.js`
   - `dashboard/dashboard.html`
   - `dashboard/dashboard.h`
2. Copy in the updated versions from this bundle.
3. Rebuild/deploy as you normally do.
4. Test export/import round-trip per sensor and merged export.
5. Record observed headers and whether legacy files still import as expected.

## Expected User Test Results
Pass conditions:
- single-sensor export headers include sensor prefix
- single-sensor import loads into the correct sensor
- merged export/import still works
- confirmation dialog shows estimated total time
- batch progress shows approximate remaining time

Fail indicators:
- exported single-sensor headers are still bare (`temp_c`, `humidity_pct`)
- single-sensor import still lands in Office regardless of file
- ambiguous legacy filename imports without warning
- hosted dashboard fails to load after replacing HTML/header

## Changelog
### v7.4.0.1
- Prefixed single-sensor CSV headers to match merged export schema
- Added safe legacy single-sensor filename-based sensor detection
- Removed unsafe default-to-first-sensor import fallback
- Added estimated import duration to confirmation dialog
- Added approximate remaining-time progress text during import
