# v7.4.0.1 Import/Export Fix Candidate

## Request
Fix two issues discovered after successful LAN and Cloudflare import stabilization:
1. Single-sensor CSV exports do not include the sensor name in metric headers, which causes individual imports to map into the first configured sensor (Office).
2. The import confirmation text should include an approximate total import duration now that real timing is known.

## Request Understanding
The issue is not in the transport anymore. Import now succeeds over both LAN and Cloudflare. The remaining defect is a schema mismatch between single-sensor export and import detection:
- merged export uses prefixed headers such as `outside_temp_c`
- single-sensor export uses bare headers such as `temp_c`
- the importer currently maps bare single-sensor CSV files to the first known sensor, which is why Outside import lands in Office

The requested change is to make single-sensor export/import consistent and safe, and to improve the import UX with a time estimate.

## Deliverables
- Updated `dashboard/dashboard.js`
- Updated `dashboard/dashboard.html`
- Updated `dashboard/dashboard.h`
- This documentation file
- `development-notes-v7.4.0.1.md`

## Actions Performed
1. Reviewed current import/export behavior in the feature branch dashboard code.
2. Confirmed the existing bug source:
   - single-sensor export builds headers from shared columns plus bare suffixes
   - import detection maps legacy bare single-sensor CSV files to the first configured sensor
3. Implemented prefixed single-sensor export headers so individual exports now match merged export naming style.
4. Updated import parsing to accept:
   - new prefixed single-sensor exports
   - merged exports
   - old legacy bare single-sensor exports **only when the sensor can be inferred from the file name**
5. Removed the unsafe fallback that silently mapped legacy single-sensor files to Office.
6. Added approximate import-time messaging to the confirmation dialog.
7. Added approximate remaining-time messaging to per-batch status text during import.
8. Regenerated `dashboard.html` inline script content and `dashboard.h` from the updated dashboard JavaScript.

## What Changed
### 1) Single-sensor export headers are now prefixed
Example after this patch:
- `gateway_host,gateway_ip,timestamp,datetime_utc,outside_temp_c,outside_temp_f,outside_humidity_pct,outside_dewpoint_c`

This aligns single-sensor export with merged export and makes re-import deterministic.

### 2) Legacy single-sensor import is now safe
Older exported files with bare headers such as `temp_c` and `humidity_pct` are no longer silently imported into Office.

Behavior now:
- if the filename clearly contains a sensor token such as `outside`, `office`, or `first_floor`, import maps correctly
- if the sensor cannot be identified from the filename, import stops with an explicit error instead of importing into the wrong sensor

### 3) Import confirmation now includes estimated duration
The confirmation dialog now shows an estimated import time based on current access path:
- LAN/direct estimate
- Cloudflare/remote estimate

### 4) In-progress status now shows approximate remaining time
Each batch status line now includes an approximate time left estimate.

## Bug Cause
The exporter and importer were using two different schema assumptions:
- merged export included sensor-prefixed metric columns
- single-sensor export used bare metric columns
- the importer compensated by assigning bare single-sensor files to the first known sensor

That fallback made the flow appear to work but routed valid single-sensor imports into the wrong sensor slot.

## Lessons Learned
- Export and import formats must share one canonical column naming scheme.
- Silent fallback to a default sensor is dangerous for destructive workflows such as history replacement.
- For migration compatibility, legacy files should either be inferred safely or rejected explicitly.
- Once timing characteristics are known, user confirmation text should reflect expected duration so the user can make an informed decision.

## Files Changed
- `dashboard/dashboard.js` — functional changes
- `dashboard/dashboard.html` — regenerated to embed the updated script
- `dashboard/dashboard.h` — regenerated from HTML for firmware embedding

## Validation Notes
Static validation performed here:
- code path review for export header generation
- code path review for import column detection
- regenerated embedded HTML/header payloads

Not validated here:
- live browser runtime test
- firmware compile
- on-device import/export round-trip

## Recommended User Test Order
1. Replace the three dashboard files with the versions from this bundle.
2. Rebuild and deploy firmware/dashboard.
3. Export one single-sensor CSV for each sensor.
4. Verify the headers are prefixed, for example `outside_temp_c`.
5. Import each single-sensor CSV and confirm it lands in the matching sensor.
6. Confirm the import dialog shows an approximate duration.
7. Confirm batch status text shows approximate remaining time.
8. Optionally test an old legacy single-sensor CSV filename:
   - should import correctly if the filename contains the sensor token
   - should fail safely if the filename is ambiguous

## Suggested Follow-up
After this fix is verified, update the main project docs so the documented CSV import/export format matches the now-canonical prefixed-header scheme.
