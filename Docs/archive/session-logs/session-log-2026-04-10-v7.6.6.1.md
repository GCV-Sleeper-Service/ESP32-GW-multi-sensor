# Session Log — v7.6.6.1 — 2026-04-10

## Objective
Phase Y Step 1: Establish assembly script and 8-fragment baseline.

## Deliverables Completed
- Created `firmware/core/` directory with 8 fragment files extracted from
  `dashboard/sensor_history_multi.h`
- Created `scripts/assemble-sensor-history.sh` with --write, --check, --list,
  --dry-run modes (generator-aware `--check` strips `SENSOR_MANIFEST` marker
  regions before SHA-256 comparison)
- Added `firmware_core_fragments_exist` to `scripts/preflight.sh`
- Activated assembly step in `scripts/provision.sh` (Step 0)
- Fixed critical security defect in `firmware/core/aggregator-runtime.h`:
  added `snprintf` truncation guard before `lwip_send` to prevent buffer over-read
- Hardened `scripts/assemble-sensor-history.sh`:
  - Added `ROOT` normalization so script is invocable from any directory
  - Added explicit `$OUTPUT` existence check in `--check` path
- Reverted out-of-scope version-bump changes to keep split as pure infrastructure

## Fragment Manifest

| Fragment | Lines |
|---|---:|
| `firmware/core/config.h` | 95 |
| `firmware/core/data-model.h` | 460 |
| `firmware/core/nvs-persistence.h` | 614 |
| `firmware/core/deferred-management.h` | 50 |
| `firmware/core/ping-adapter.h` | 168 |
| `firmware/core/aggregator-runtime.h` | 892 |
| `firmware/core/web-handler.h` | 2,006 |
| `firmware/core/registration.h` | 41 |
| **Total** | **4,326** |

Note: `aggregator-runtime.h` is 892 lines (one more than the 891-line plan) because
the `lwip_send` truncation guard fix adds one line. All other counts match the plan.

## Verification

```
$ bash scripts/assemble-sensor-history.sh --list
  firmware/core/config.h (95 lines)
  firmware/core/data-model.h (460 lines)
  firmware/core/nvs-persistence.h (614 lines)
  firmware/core/deferred-management.h (50 lines)
  firmware/core/ping-adapter.h (168 lines)
  firmware/core/aggregator-runtime.h (892 lines)
  firmware/core/web-handler.h (2006 lines)
  firmware/core/registration.h (41 lines)
Total: 4326 lines

$ bash scripts/assemble-sensor-history.sh --check
PASS: Assembly identity verified (non-generated regions match: 1b175a82ad8fc3df15d933bfc584af5e78aafa94787dad805b8318cc89dc923e)

$ diff dashboard/sensor_history_multi.h <(cat firmware/core/config.h \
    firmware/core/data-model.h firmware/core/nvs-persistence.h \
    firmware/core/deferred-management.h firmware/core/ping-adapter.h \
    firmware/core/aggregator-runtime.h firmware/core/web-handler.h \
    firmware/core/registration.h)
(no output — exit 0)
```

## Commit
9bead05b39ec9a82061e4bbd304b6c91eac7f387 (original PR commit)
Post-review fixes applied on top (see PR #155 fix commit).
