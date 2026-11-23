# Session log — v7.7.1.2, PR #246

Session opened 2026-11-22 (America/Los_Angeles); the filename retains the date supplied to the scope block. Operator continuation decision dated 2026-11-23. Agent: Codex, GPT-6; context window and reasoning effort not shown. Branch: `feature/v7.7.1.2-per-device-structs`. Scope: 39 allowed paths.

## Evidence summary

- Setup SHA-256 matched `01b0af80cde91f5d053e59163da9598d2236528c355bc79e49c05c1781155e0b`; all eleven unpacked files printed OK.
- Bootstrap `ea082fa`; corrected prompt/check file committed verbatim at `c6ed12b`; nine supplied files copied at `15e8668`.
- Task Group 1 `c65be9a`, Task Group 2 `4b75f8e`, Task Group 3 `6442f85`, version/pipeline `7970985`, measured assertions `2cac2b2`. No runtime use of the added definitions.
- Required reading completed before §2. Every named gate ran from the supplied check file. Fragment sources were edited and assembled; generated artifacts were never edited directly.
- Test and compile commands ran one at a time. Both builds succeeded with T1, T2 and the five size assertions.
- Uploaded only .189 and .170, using their own YAMLs and `timeout 300 esphome upload`. Both uploads reported `INFO OTA successful` and `INFO Successfully uploaded program.`; builds cleaned afterward.
- Item 5.3: `bash scripts/provision.sh satellite` succeeded, then `git status --short` printed nothing.
- One checkpoint stop on a stale baseline, accepted below; no agent error, gate alteration or c3heap retry.
- CHECKPOINT E passed after the Task Group 6 documents were completed. PRE-PR runs after their commit; the PR body records its result for each current head.
- Inline, review A and review B: pending. Review C does not run (PLAN-036, PLAN-044).

Verbatim completed gate output:

```text
§2 PASS
scope list written: 39 paths
copied 9 files
CHECKPOINT 0 PASS
CHECKPOINT A PASS
CHECKPOINT B PASS
CHECKPOINT C PASS
CHECKPOINT E PASS
```

## ESPHome output and measured sizes

The `measure` block compiled a temporary copy of commit `7970985` with placeholder secrets. Its output:

```text
sizeof DeviceHistoryMeta = 60
sizeof DeviceSegmentHeader = 24
sizeof DeviceSegment = 228
sizeof EventEntry = 8
sizeof EventLog = 168
measure PASS
```

Five assertions use these measured values. The C3 and WROOM builds both passed them.

C3 clean compile (`firmware/esp32-c3-multi-sensor.yaml`):

```text
RAM:   [==        ]  18.5% (used 60720 bytes from 327680 bytes)
Flash: [========  ]  81.1% (used 1434680 bytes from 1769472 bytes)
======================== [SUCCESS] Took 519.95 seconds ========================
INFO Successfully compiled program.
```

CHECKPOINT D, before cleaning the C3 build:

```text
C3 image: 1435088 B of the OTA slot of 1769472 B (81.1 %)
CHECKPOINT D PASS
```

WROOM clean compile (`firmware/esp32-wroom-32d-gw.yaml`):

```text
RAM:   [==        ]  22.0% (used 72160 bytes from 327680 bytes)
Flash: [=======   ]  72.4% (used 1281923 bytes from 1769472 bytes)
======================== [SUCCESS] Took 514.22 seconds ========================
INFO Successfully compiled program.
```

WROOM upload used a 1,282,320-byte firmware image. ESPHome version for both builds: 2026.4.1; ESP-IDF 5.5.4.

## Device tests — verbatim output

### Item 5.1: C3 before upload

```text
dev 192.168.120.189: version v7.7.1.1, uptime 179720 s, free_heap 42596 B, min_free_heap 28272 B, boot 1795207501
dev PASS
```

### Item 5.1: C3 after upload, including the stop

```text
dev 192.168.120.189: version v7.7.1.2, uptime 109 s, free_heap 43832 B, min_free_heap 40308 B, boot 1795387236
c3heap: the uptime is 109 s; waiting 71 s until 180 s
c3heap reading 1: uptime 180 s, free_heap 41956 B
c3heap reading 2: uptime 211 s, free_heap 43864 B
⛔ CHECKPOINT FAILED - dev: the higher free_heap, 43864 B, is more than 2,048 B below 52,080 B (CURRENT-STATE.md, v7.7.1.1 C3 value): STOP and report
```

The failure was posted in [comment 7087046206](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/246#issuecomment-7087046206), with a clean working tree and CHECKPOINT D as the last completed checkpoint. No WROOM work occurred before the operator accepted the stop.

### Item 5.2: WROOM before upload

```text
dev 192.168.120.170: version v7.7.1.1, uptime 185237 s, free_heap 27892 B, min_free_heap 3648 B, boot 1795209883
dev PASS
```

### Item 5.2: WROOM after upload

```text
dev 192.168.120.170: version v7.7.1.2, uptime 118 s, free_heap 29052 B, min_free_heap 12336 B, boot 1795395664
dev PASS
```

The boot epoch for the future `wroom24` command is **1795395664**. Fresh v7.7.1.2 minimum heap: 12,336 B at 118 s uptime.

### Item 5.4: WROOM 24-hour observation and second C3 reading

Pending the operator's exact instruction, `Run the block wroom24 now.` Then run the supplied block with boot epoch 1795395664 and also `bash /root/v7712/v7.7.1.2-checks.sh dev 192.168.120.189 v7.7.1.2`. Add both outputs here, in the record and in the PR body. The C3 heap block is not repeated.

## Accepted Exceptions

[Operator decision comment 7088682835](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/246#issuecomment-7088682835), dated 2026-11-23, verbatim:

> Operator decision on the c3heap stop of PR #246 (comment 7087046206), 2026-11-23. The stop is accepted; it shows no regression from v7.7.1.2. Your own evidence: v7.7.1.1 read free_heap 42,596 B just before the upload (uptime 179,720 s); v7.7.1.2 reads 41,956 B and 43,864 B at 180 s and 211 s. The 52,080 B baseline of CURRENT-STATE.md (2026-05-08) no longer fits this board; the planning session corrects it in a later step. Continue with item 5.2. Do not run the c3heap block again, and do not change any check, expected value or supplied text.
> 
> 1. Session log and PR body (Per-Item row 5.1): the verbatim c3heap output and this decision. In section 7 of the PR body, tick the c3heap criterion and add after it: "not met against 52,080 B; accepted by the operator's decision comment on this PR (2026-11-23)".
> 2. Record, section 6 (Device Test Results): the two readings of v7.7.1.1 and v7.7.1.2, the stop and this decision. Count the stop in the process metrics as a checkpoint stop on a stale baseline, not as an agent error.
> 3. When I paste "Run the block wroom24 now.", also run: bash /root/v7712/v7.7.1.2-checks.sh dev 192.168.120.189 v7.7.1.2 . Put its line into the session log, the record and the PR body as a second C3 reading.

The higher C3 reading, 43,864 B, is 1,268 B above the immediate pre-upload v7.7.1.1 reading of 42,596 B. The decision accepts the stop on the stale May baseline; it does not turn the failed block into a PASS. The historical baseline and supplied checks/texts are unchanged. Baseline correction is routed to a later planning step in CURRENT-STATE.md.

## Playwright fixture table

All seven jobs of GitHub run 45079026414 passed on firmware commit `2cac2b2`. Counts below come from their job logs. Final-head checks are recorded in the PR body and refreshed after later commits.

| Fixture | Passed | Skipped | Result and job |
|---|---|---|---|
| 3sensor | 192 | 106 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382713146) |
| 1sensor | 18 | 0 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382713183) |
| 2sensor | 18 | 0 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382713197) |
| 4sensor | 18 | 0 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382713220) |
| mixed | 14 | 0 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382713165) |
| aggregator | 22 | 0 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382712934) |
| system | 16 | 0 | [PASS](https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/actions/runs/45079026414/job/137382713177) |

## Pipeline and preflight

The full repository pipeline passed after each code task group. The last local preflight before `2cac2b2` ended with `playwright_manifest_spec: PASS`. PRE-PR runs preflight again on the documented head. No known-tooling recovery was needed.

## Stops and recoveries

| Event | Result | Classification |
|---|---|---|
| Item 5.1 c3heap, first run | Stopped; failure comment posted; operator accepted continuation at item 5.2 | One checkpoint stop on a stale baseline; one bundle defect reaching execution, zero agent errors |
| C3 heap re-run | Not run; prohibited by operator | No changed check, expected value or supplied text |
| WROOM compile/upload/post-upload reading | PASS | Normal continuation authorized by operator |
| WROOM 24-hour reading / second C3 reading | pending operator instruction | Required later observation |

