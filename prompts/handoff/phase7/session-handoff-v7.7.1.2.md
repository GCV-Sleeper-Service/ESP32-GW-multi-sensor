# Session handoff - v7.7.1.2 (R4)

_Written 2026-11-22 by the planning session inside the PR of R5b (PLAN-044), from the template of HowTo v2.3.1 `templates/session-handoff.template.md`. It replaces the May 2026 handoff of this step. Amend it inside any later PR that changes these assumptions._

## State snapshot this step was written against

| Item | Value | Source |
| --- | --- | --- |
| Version on main | 7.7.1.1 | `VERSION` |
| Commit on main (SHA) | `1c95906` at production; the R5b merge at dispatch, which the pre-dispatch gate records | `git rev-parse --short origin/main` |
| Last verified | 2026-11-14: .189, .170 and .191 report v7.7.1.1 | `CURRENT-STATE.md`, line 3 |
| Deployment targets (name → address → deployed version and commit) | `esp32-c3-multi` → 192.168.120.189 → v7.7.1.1; `sat-esp32-4m-170` → 192.168.120.170 → v7.7.1.1 (2026-11-14) | `CURRENT-STATE.md`, "Board Fleet"; the operator's `fleet` output on the day of dispatch |
| Measurements this step depends on | C3 `free_heap` 52,080 B after the v7.7.1.1 flash (2026-05-08); .170 `min_free_heap` 3,988 B at 7.5 days of uptime (2026-11-14); C3 image 1,435,840 B of the 1,769,472-byte OTA slot (81.1 %), compiled by the planning session from `1c95906` on 2026-11-22 | `CURRENT-STATE.md`, "Phase 7 Device Validation Snapshot" and "Open Issues"; the gate record of R5b |

## What this step does

- Defines the per-device persistence model in `firmware/core/data-model.h`: `DeviceHistoryMeta`, `DeviceSegmentHeader`, `DeviceSegment`, `EventEntry`, `EventLog`, the constants `DEV_HIST_MAGIC`, `DEV_HIST_VERSION`, `MAX_PERSIST_METRICS` (6), `DEVICE_ID_MAX_LEN` (32), `MAX_DEVICE_SLOTS` (4,096), and the enum `PersistPriority`.
- Defines the FNV-1a hash and the NVS keys in `firmware/core/nvs-persistence.h`: `dm_<8 hex>` for a device's meta blob and `ds_<8 hex>_<3 hex>` for a segment, both at most 15 characters.
- Makes the generator write the persist defaults of each device: `PERSIST_DEVICE_COUNT`, `PERSIST_DEVICE_IDS[]`, `PERSIST_METRIC_COUNTS[]` and `PERSIST_PRIORITIES[]`.
- Proves all of it at compile time with two supplied tests and five measured size assertions; bumps to 7.7.1.2; flashes .189 and .170.

## What this step does NOT do

- No runtime code uses the new definitions: no NVS read or write, no task, no endpoint, no dashboard change.
- The served manifest does not change, and `config/sensors.json` gets no `persist` block; an explicit `persist` block per device waits for the step that needs it.
- The old engine (`SegmentSnapshot`, `HistoryMeta`, `PERSIST_SLOTS`) is unchanged.
- No partition change (PLAN-015).

## Risk tier and why

LOW (PLAN-017): additive definitions only, proved at compile time on both CPU families of the fleet. The only runtime change is the version string and the image size.

## Critical rules that apply

| # | Rule | Why here |
| --- | --- | --- |
| 2 | Version bump through `bump-version.sh` | The step bumps to 7.7.1.2 |
| 5, 58 | No hand edit of generated files; code in `firmware/core/` | Two fragments and the generator change |
| 62 | Fragment order unchanged | No fragment is added |
| 63 | Session log in the PR | Firmware step |
| 64 | Counts from the prompt's text | The checks count definitions |
| 67 | Binary metrics use `EventLog` | This step defines it |

## Risks and mitigations

| Risk | Trigger | Mitigation |
| --- | --- | --- |
| A struct layout differs between RISC-V and Xtensa | The WROOM compile fails a size assertion | The agent stops and reports; the layout has explicit reserved fields, so no difference is expected |
| The C3 heap moves | `c3heap`: the higher of two readings at an uptime of 180 s or more, 30 s apart, is more than 2,048 B below 52,080 B (PLAN-045) | The agent stops and reports; the step adds no runtime data, so a change points at the platform |
| The WROOM heap keeps falling | `min_free_heap` of .170 lower after 24 h | Recorded, not fixed here; it decides the heap checks of v7.7.1.3 |
| A slot count above 4,095 | A later budget on a 16 MB board | `MAX_DEVICE_SLOTS` caps it; v7.7.1.4 clamps its budget to it |

## Context that carries forward to the next step

- v7.7.1.3 persists the structs of this step for the first time. Its bundle is produced by the planning session after this merge, from the code on `main` (PLAN-044): the measured sizes, the key helpers and the generated constants are its interface.
- `NvsKey` holds its key in `s`; "no key" is `s[0] == '\0'`; the persist path must check it.
- The 24-hour reading of .170 and the C3 image size are the baselines of v7.7.1.3's checks.

## Open questions for the operator (answer before dispatch)

- [ ] The operator's latest `fleet` output on the day of dispatch: .189 and .170 report v7.7.1.1.
- [ ] The harness and the model of the coding agent, for the gate record (PLAN-043).
