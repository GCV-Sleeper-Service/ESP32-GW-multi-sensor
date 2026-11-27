# Session log — R6, v7.7.1.3

Date: 2026-11-25, America/Los_Angeles. PR #247, branch `feature/v7.7.1.3-persist-write-path`.

## Evidence summary

The supplied setup and bundle hashes matched. Checkpoints 0, A–E and H passed. All three builds and OTA uploads succeeded. The first S3 persist check passed before the production uploads. C3 and WROOM each completed five writes per device without failures, and both old engines advanced. The C3 heap comparison passed. Every WROOM reading met the floor.

The latest C3 snapshot uses the repeat c3heap reading: free heap 42,144 B before, 43,316 B after (+1,172 B); minimum heap 29,868 B before, 32,368 B after (+2,500 B). Latest WROOM boot epoch: `1795670617`. Initial readings are preserved below as historical evidence.

## ESPHome output and supplied checks

The following preserves the compile summaries and device/check output, with terminal colour removed.

```text
Coding agent: Codex (VS Code extension), GPT-6, context window not shown, reasoning effort not shown
Session date: 2026-11-25 (America/Los_Angeles)
PR: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor/pull/247
Branch: feature/v7.7.1.3-persist-write-path
Setup SHA-256: bd9989294c56e197fb2f796f70a1824858efb2687662f4301bbbdebdcc5cfa08
All 14 bundle files verified OK; the prompt and check file reverified OK before the verbatim commit.
Producer sessions for this step's prompt: 2. Audit sessions for this step's prompt: 9.

Pre-implementation and implementation gates:
§2 PASS
scope list written: 47 paths
copied 12 files
CHECKPOINT 0 PASS
CHECKPOINT A PASS
CHECKPOINT B PASS
H1: all checks passed
host PASS
CHECKPOINT C PASS
CHECKPOINT D PASS

C3 compile, ESPHome 2026.4.1:
RAM:   [==        ]  18.6% (used 60816 bytes from 327680 bytes)
Flash: [========  ]  81.2% (used 1437646 bytes from 1769472 bytes)
======================== [SUCCESS] Took 530.75 seconds ========================
INFO Build Info: config_hash=0xa39c7dd8 build_time_str=2026-11-25 11:38:16 -0800
INFO Successfully compiled program.
C3 image: 1438048 B of the OTA slot of 1769472 B (81.2 %)
CHECKPOINT E PASS

S3 before upload:
dev 192.168.120.173: version v7.7.1.2, uptime 119200 s, free_heap 118600 B, min_free_heap 2197768 B, boot 1795516857
dev PASS
v2 192.168.120.173 before: version v7.7.1.2, used_entries 334, free_entries 15794, old engine segments 33, last_persist_epoch 1795633200, boot 1795516857, rings -1 -1 -1 -1 (-1: not known)
v2 PASS (before)

S3 compile, ESPHome 2026.4.1:
RAM:   [==        ]  20.4% (used 66844 bytes from 327680 bytes)
Flash: [=======   ]  74.1% (used 1310511 bytes from 1769472 bytes)
======================== [SUCCESS] Took 549.89 seconds ========================
INFO Build Info: config_hash=0xbbfe25a3 build_time_str=2026-11-25 11:47:56 -0800
INFO Successfully compiled program.
s3 image: 1310912 B of the OTA slot of 1769472 B (74.0 %)
image PASS

The S3 build finished outside the permitted upload window. Waited until 12:12 Pacific for the upload.
S3 upload began at 12:12 Pacific on 2026-11-25 and succeeded:
INFO Upload took 6.75 seconds, waiting for result...
INFO OTA successful
INFO Successfully uploaded program.
The S3 build was cleaned, satellite provisioning completed, and the prescribed 90-second wait completed.
dev 192.168.120.173: version v7.7.1.3, uptime 114 s, free_heap 119652 B, min_free_heap 2216364 B, boot 1795637543
dev PASS
Waited for the first natural hourly persist at 13:10 Pacific, then ran v2 after its 180-second grace:
v2 192.168.120.173 office: ok, meta_key dm_aa8eba31, valid_segments 1, next_slot 1, last_persist_epoch 1795640400, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 first_floor: ok, meta_key dm_9ed41104, valid_segments 1, next_slot 1, last_persist_epoch 1795640400, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 outside: ok, meta_key dm_c38eecc4, valid_segments 1, next_slot 1, last_persist_epoch 1795640400, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 wan_ping: ok, meta_key dm_7a81c392, valid_segments 1, next_slot 1, last_persist_epoch 1795640400, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 nvs: used_entries 410 (before 334), free_entries 15718, old engine segments 35, last_persist_epoch 1795640400 (before 1795633200, 788 s ago), uptime 3645 s
v2 PASS

C3 before upload:
dev 192.168.120.189: version v7.7.1.2, uptime 126756 s, free_heap 42972 B, min_free_heap 28552 B, boot 1795514437
dev PASS
v2 192.168.120.189 before: version v7.7.1.2, used_entries 10804, free_entries 5324, old engine segments 1080, last_persist_epoch 1795640400, boot 1795514437, rings -1 -1 -1 -1 (-1: not known)
v2 PASS (before)
C3 OTA upload succeeded within the permitted window:
INFO Upload took 5.15 seconds, waiting for result...
INFO OTA successful
INFO Successfully uploaded program.
The C3 build was cleaned and the prescribed 90-second wait completed.
dev 192.168.120.189: version v7.7.1.3, uptime 107 s, free_heap 43716 B, min_free_heap 34700 B, boot 1795641212
c3heap: the uptime is 107 s; waiting 73 s until 180 s
c3heap reading 1: uptime 181 s, free_heap 41812 B, min_free_heap 34700 B
c3heap reading 2: uptime 211 s, free_heap 43372 B, min_free_heap 34700 B
c3heap: the higher free_heap is 43372 B; before the upload 42972 B; no more than 2,048 B below it
dev PASS

WROOM before upload:
dev 192.168.120.170: version v7.7.1.2, uptime 127785 s, free_heap 28176 B, min_free_heap 1288 B, boot 1795513654
dev PASS
v2 192.168.120.170 before: version v7.7.1.2, used_entries 10804, free_entries 5324, old engine segments 1080, last_persist_epoch 1795640400, boot 1795513654, rings -1 -1 -1 -1 (-1: not known)
v2 PASS (before)

WROOM compile, ESPHome 2026.4.1:
RAM:   [==        ]  22.1% (used 72272 bytes from 327680 bytes)
Flash: [=======   ]  72.6% (used 1285035 bytes from 1769472 bytes)
======================== [SUCCESS] Took 505.64 seconds ========================
INFO Build Info: config_hash=0x16d49d4b build_time_str=2026-11-25 13:17:36 -0800
INFO Successfully compiled program.
wroom image: 1285440 B of the OTA slot of 1769472 B (72.6 %)
image PASS
WROOM OTA upload succeeded at 13:26 Pacific, within the permitted window:
INFO Upload took 6.90 seconds, waiting for result...
INFO OTA successful
INFO Successfully uploaded program.
The WROOM build was cleaned, satellite provisioning completed, git status --short printed nothing, and the prescribed 90-second wait completed.
dev 192.168.120.170: version v7.7.1.3, uptime 125 s, free_heap 28824 B, min_free_heap 22756 B, boot 1795641987
dev PASS
The production checks of 6.4 ran after the natural cycles, on 2026-11-25 at about 18:35 Pacific:
v2 192.168.120.189 office: ok, meta_key dm_aa8eba31, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.189 first_floor: ok, meta_key dm_9ed41104, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.189 outside: ok, meta_key dm_c38eecc4, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.189 wan_ping: ok, meta_key dm_7a81c392, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.189 nvs: used_entries 11020 (before 10804), free_entries 5108, old engine segments 1080, last_persist_epoch 1795658400 (before 1795640400, 2155 s ago), uptime 19344 s
v2 PASS
v2 192.168.120.170 office: ok, meta_key dm_aa8eba31, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.170 first_floor: ok, meta_key dm_9ed41104, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.170 outside: ok, meta_key dm_c38eecc4, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.170 wan_ping: ok, meta_key dm_7a81c392, valid_segments 5, next_slot 5, last_persist_epoch 1795658400, writes ok 5 skipped 0 failed 0
v2 192.168.120.170 nvs: used_entries 11020 (before 10804), free_entries 5108, old engine segments 1080, last_persist_epoch 1795658400 (before 1795640400, 2159 s ago), uptime 18572 s
v2 192.168.120.170 heap: free_heap 27848 B, min_free_heap 8316 B, uptime 18572 s
v2 PASS
The operator-triggered 24-hour block must use boot epoch 1795641987.
No checkpoint failure, test failure or recovery has occurred so far.

GitHub check runs read on head d3912c43ede2bd14517e42ee6a8d8535dc746fbf during the wait for the first S3 persist:
preflight-and-compile: completed, success (run 45688679832)
prompt-lint: completed, success (run 45688679868)
browser-tests (3sensor): completed, success (run 45688679852)
browser-tests (1sensor): completed, success (run 45688679852)
browser-tests (2sensor): completed, success (run 45688679852)
browser-tests (4sensor): completed, success (run 45688679852)
browser-tests (mixed): completed, success (run 45688679852)
browser-tests (aggregator): completed, success (run 45688679852)
browser-tests (system): completed, success (run 45688679852)
pr-body-check: completed, failure (run 45688679930); the PR still has the exact placeholder body required by the setup, and the full section-8 body is not due until after implementation and device validation. This is not a supplied checkpoint failure. The required check is pending a pass after the prescribed body update.

```

## Playwright fixture table

Observed on GitHub head `d3912c43ede2bd14517e42ee6a8d8535dc746fbf`, Browser Tests run `45688679852`. These are job conclusions; final-head conclusions will be refreshed after the review round.

| Fixture | Result |
|---|---|
| 3sensor | PASS |
| 1sensor | PASS |
| 2sensor | PASS |
| 4sensor | PASS |
| mixed | PASS |
| aggregator | PASS |
| system | PASS |

## Stops and recoveries

None of the supplied checkpoints or local tests failed. Both image gates and the C3 image checkpoint passed. The expected GitHub placeholder-body check failure is recorded above; its full body update follows PRE-PR. The first long hourly wait ended when the operator asked to continue; the production checks then ran against the latest natural cycles and passed.

## Reserved observations and reviews

The 24-hour readings are pending the operator's exact trigger, `Run the block wroom24 now.` They will use the latest boot `1795670617`, followed by the two `v2 ... later` blocks in the prescribed order. External reviews A, C and B are pending operator dispatch. No external review has been started, no issue edited, and no merge or tag performed.

## PRE-PR and review rounds

CHECKPOINT F passed. PRE-PR passed at `26fb1d16702e235f3046c3089e4e46be615d74c6`; all required GitHub checks subsequently passed on that head. The full body was posted, the PR marked ready and `/gemini review` posted as comment 7181048684. No edit or push occurred before the inline block passed.

```text
Copilot: review 6067937428 on 26fb1d1 (incomplete: Copilot could not complete its review, PLAN-032)
Gemini: review 6067862942 on 26fb1d1
Codex: status comment 7181049513, completed on 26fb1d1
inline PASS
```

All reviews, review-thread comments and reviewer issue comments were refreshed after this PASS. G1 is not warranted: default member initializers set the meta magic/version, H1 checks them and ring wrap, and the production rings advanced. C1 requests a change to the fixed stats-error contract and is routed to the named current-state row. C2 is warranted: allocation failure could log ESP_OK. The initializer is now ESP_FAIL; CHECKPOINT B and H1 passed again. Full three-board revalidation is required by the review-round instructions, and the 24-hour readings will restart from the new WROOM upload.

A scratch PR-body patch invocation was rejected for targeting one path with both delete and add. No file changed; it was repaired with a normal update patch before publication. No checkpoint or test failure resulted.


## Inline C2 — completed firmware revalidation

All three clean builds, image gates, OTA uploads, boot checks and persist checks passed again on firmware commit `48debeb`, with .173 passing before either production upload. The repeat C3 snapshot is 42,144 → 43,316 B free (+1,172 B), and 29,868 → 32,368 B minimum (+2,500 B). The latest WROOM boot is `1795670617`; the earlier deployment remains historical evidence and is superseded for the delayed observations.

# Inline C2 firmware revalidation — 2026-11-25

Firmware commit: 48debeb. Initial deployment readings remain preserved in the committed session log.
The new WROOM upload will replace boot 1795641987 as the epoch for the operator-triggered 24-hour checks.

```text
CHECKPOINT B PASS
H1: all checks passed
host PASS
RAM:   [==        ]  18.6% (used 60816 bytes from 327680 bytes)
Flash: [========  ]  81.2% (used 1437646 bytes from 1769472 bytes)
======================== [SUCCESS] Took 517.36 seconds ========================
INFO Build Info: config_hash=0xa39c7dd8 build_time_str=2026-11-25 11:38:16 -0800
INFO Successfully compiled program.
C3 image: 1438048 B of the OTA slot of 1769472 B (81.2 %)
CHECKPOINT E PASS
dev 192.168.120.173: version v7.7.1.3, uptime 24936 s, free_heap 118216 B, min_free_heap 2212592 B, boot 1795637543
dev PASS
v2 192.168.120.173 before: version v7.7.1.3, used_entries 660, free_entries 15468, old engine segments 40, last_persist_epoch 1795658400, boot 1795637543, rings 6 6 6 6 (-1: not known)
v2 PASS (before)

S3 repeat build and upload at 19:17 Pacific:
RAM:   [==        ]  20.4% (used 66844 bytes from 327680 bytes)
Flash: [=======   ]  74.1% (used 1310511 bytes from 1769472 bytes)
======================== [SUCCESS] Took 550.53 seconds ========================
INFO Build Info: config_hash=0xbbfe25a3 build_time_str=2026-11-25 11:47:56 -0800
INFO Successfully compiled program.
s3 image: 1310912 B of the OTA slot of 1769472 B (74.0 %)
image PASS
INFO Upload took 6.76 seconds, waiting for result...
INFO OTA successful
INFO Successfully uploaded program.
dev 192.168.120.173: version v7.7.1.3, uptime 121 s, free_heap 116072 B, min_free_heap 2215380 B, boot 1795663085
dev PASS

S3 repeat persist validation:
v2 192.168.120.173 office: ok, meta_key dm_aa8eba31, valid_segments 8, next_slot 8, last_persist_epoch 1795665600, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 first_floor: ok, meta_key dm_9ed41104, valid_segments 8, next_slot 8, last_persist_epoch 1795665600, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 outside: ok, meta_key dm_c38eecc4, valid_segments 8, next_slot 8, last_persist_epoch 1795665600, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 wan_ping: ok, meta_key dm_7a81c392, valid_segments 8, next_slot 8, last_persist_epoch 1795665600, writes ok 1 skipped 0 failed 0
v2 192.168.120.173 nvs: used_entries 760 (before 660), free_entries 15368, old engine segments 42, last_persist_epoch 1795665600 (before 1795658400, 789 s ago), uptime 3304 s
v2 PASS

C3 repeat pre-upload readings:
dev 192.168.120.189: version v7.7.1.3, uptime 25183 s, free_heap 42144 B, min_free_heap 29868 B, boot 1795641211
dev PASS
v2 192.168.120.189 before: version v7.7.1.3, used_entries 11100, free_entries 5028, old engine segments 1080, last_persist_epoch 1795665600, boot 1795641211, rings 7 7 7 7 (-1: not known)
v2 PASS (before)

C3 repeat upload and heap validation:
INFO Upload took 5.30 seconds, waiting for result...
INFO OTA successful
INFO Successfully uploaded program.
dev 192.168.120.189: version v7.7.1.3, uptime 114 s, free_heap 42936 B, min_free_heap 42708 B, boot 1795666412
c3heap: the uptime is 114 s; waiting 66 s until 180 s
c3heap reading 1: uptime 180 s, free_heap 43316 B, min_free_heap 32368 B
c3heap reading 2: uptime 211 s, free_heap 43316 B, min_free_heap 32368 B
c3heap: the higher free_heap is 43316 B; before the upload 42144 B; no more than 2,048 B below it
dev PASS

WROOM repeat pre-upload readings:
dev 192.168.120.170: version v7.7.1.3, uptime 24654 s, free_heap 27728 B, min_free_heap 5764 B, boot 1795641987
dev PASS
v2 192.168.120.170 before: version v7.7.1.3, used_entries 11100, free_entries 5028, old engine segments 1080, last_persist_epoch 1795665600, boot 1795641987, rings 7 7 7 7 (-1: not known)
v2 PASS (before)

WROOM repeat build:
RAM:   [==        ]  22.1% (used 72272 bytes from 327680 bytes)
Flash: [=======   ]  72.6% (used 1285035 bytes from 1769472 bytes)
======================== [SUCCESS] Took 511.03 seconds ========================
INFO Build Info: config_hash=0x16d49d4b build_time_str=2026-11-25 13:17:36 -0800
INFO Successfully compiled program.
wroom image: 1285440 B of the OTA slot of 1769472 B (72.6 %)
image PASS

Refreshed readings after the operator's continuation, before the upload at 21:23 Pacific:
dev 192.168.120.170: version v7.7.1.3, uptime 28604 s, free_heap 27608 B, min_free_heap 5764 B, boot 1795641987
dev PASS
v2 192.168.120.170 before: version v7.7.1.3, used_entries 11140, free_entries 4988, old engine segments 1080, last_persist_epoch 1795669200, boot 1795641987, rings 8 8 8 8 (-1: not known)
v2 PASS (before)

INFO Upload took 7.81 seconds, waiting for result...
INFO OTA successful
INFO Successfully uploaded program.
dev 192.168.120.170: version v7.7.1.3, uptime 133 s, free_heap 28584 B, min_free_heap 21656 B, boot 1795670617
dev PASS

WROOM build cleaned, satellite configuration restored, git status --short empty.
Latest WROOM boot for the operator-triggered 24-hour blocks: 1795670617 (supersedes 1795641987).
Production repeat persist checks after the 22:10 Pacific cycle:
v2 192.168.120.189 office: ok, meta_key dm_aa8eba31, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 2 skipped 0 failed 0
v2 192.168.120.189 first_floor: ok, meta_key dm_9ed41104, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 2 skipped 0 failed 0
v2 192.168.120.189 outside: ok, meta_key dm_c38eecc4, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 2 skipped 0 failed 0
v2 192.168.120.189 wan_ping: ok, meta_key dm_7a81c392, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 2 skipped 0 failed 0
v2 192.168.120.189 nvs: used_entries 11180 (before 11100), free_entries 4948, old engine segments 1080, last_persist_epoch 1795672800 (before 1795665600, 792 s ago), uptime 7180 s
v2 PASS
v2 192.168.120.170 office: ok, meta_key dm_aa8eba31, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 1 skipped 0 failed 0
v2 192.168.120.170 first_floor: ok, meta_key dm_9ed41104, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 1 skipped 0 failed 0
v2 192.168.120.170 outside: ok, meta_key dm_c38eecc4, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 1 skipped 0 failed 0
v2 192.168.120.170 wan_ping: ok, meta_key dm_7a81c392, valid_segments 9, next_slot 9, last_persist_epoch 1795672800, writes ok 1 skipped 0 failed 0
v2 192.168.120.170 nvs: used_entries 11180 (before 11140), free_entries 4948, old engine segments 1080, last_persist_epoch 1795672800 (before 1795669200, 797 s ago), uptime 2980 s
v2 192.168.120.170 heap: free_heap 27900 B, min_free_heap 8292 B, uptime 2980 s
v2 PASS
```

The updated record and this log precede the end-of-round commit, PRE-PR and body checks. Their current-head PASS evidence is published in the PR body and assessment. The 24-hour observations and external reviews remain pending their operator triggers.

## Operator-directed recovery of the remote-head mismatch

The push of the local round record `5286b9e` was rejected because remote commit `2d247a88acda1d4120a57c2b236e6e9fc6301ea7` advanced the feature branch. The operator's comment 7183584518, `@codex[agent]+gpt-5.3-codex security review`, had triggered a Codex coding-agent change to the stats-error result, reported in comment 7183634484. That change conflicted with fixed R6 item 2.2 step 6; checkpoint-failure comment 7184295730 records the stop and full push output.

The operator authorized a fetch, rebase of the unpushed record, and a new revert commit. The rebase completed as `75b40d6`; `git revert --no-edit 2d247a8` created `3a5cb1e512f20f142a1bc28821e7ce9b888c8fd7`. No pushed history was rewritten. The subsequent command printed nothing:

```bash
git diff --stat 48debeb HEAD -- firmware config src scripts/render_sensor_config.py dashboard/sensor_history_multi.h
```

The restored history was pushed normally. Per the operator's decision, the firmware is the one already validated on `48debeb`, and Task Group 6 does not run again. The existing device outputs and WROOM boot `1795670617` remain the observation baseline. Copilot C1 stays a v7.7.1.4 recommendation in CURRENT-STATE.md, row "PR #247 inline Copilot C1". The supplied prompt, check file and item 2.2 contract are unchanged. A C3 rebuild supplies the image required by checkpoint E; there is no OTA upload or live-board read in this recovery.

## Reviews A and C — 2026-11-26

Codex (VS Code extension), GPT-6; context window and reasoning effort not shown. Refreshed PR reviews, threads and comments. Both external reviews name head `50ff835f5bfa69b04f50e19731013d5181d1a20f`; all ten required CI jobs pass on that head.

Claude Opus 5.5 review A (7186138464) has three warranted documentation findings: F1 routes the measured WROOM 1,288 B low by 127,785 s against the planning texts' 2,252 B; F2 refreshes the record's stale acceptance table and distinguishes a workflow stop from a supplied-block failure; F3 clarifies the resolved Copilot C1 thread. Reply 4705518038 names the deferred current-state row and the operator-directed revert of `2d247a8` by `3a5cb1e`, following the coding-agent mention in comment 7183584518.

Muse Spark review C (7186297014) reports no formal findings. Assessed A Q1–Q4 and notes 1–5 and C Q1–Q3. The current-state recommendations route NVS allocatable-space semantics, transient response RAM, meta-first/epoch-validated restore, interruption and overlap handling, compact buffered-row identity, layout changes, stale keys and the WROOM budget to v7.7.1.4. Installed ESP-IDF 5.5.4 and ESPHome 2026.4.1 sources answer the counter and build-info questions. Equal build-info strings and image sizes are not binary-revision identifiers; the recorded freshness gates and uploads remain the validation evidence.

This round changes only CURRENT-STATE, this log and the consolidated audit. No firmware change, build, OTA upload or board read is performed for these findings. The fixed prompt, check file and item 2.2 contract remain unchanged. The operator decides whether an observation at 36 h or later is needed; no extra check is added. Review B has not posted, Copilot's selected-tier review was incomplete, and the reserved 24-hour blocks have not been triggered. Current-head F, PRE-PR, CI and body evidence are published in the PR body before the assessment comment.

Checkpoint F rejected commit 296c6c0 because my date wording did not start with the required `_Last verified: <date> ...` prefix. Posted failure comment 7186509829 before repairing the line once; the corrected wording distinguishes today's review update from the older device measurements. The supplied check file and expectations remain unchanged.

```text
⛔ CHECKPOINT FAILED - F: 7.1 CURRENT-STATE.md line 3: '_Last verified: <date> ...' naming v7.7.1.3
```

## Operator-triggered same-boot observations — 2026-11-27

Codex (VS Code extension), GPT-6; context window and reasoning effort not shown. On the operator's trigger, ran wroom24 with the recorded upload boot `1795670617`, then later v2 on .170, then later v2 on .189, one at a time. All three blocks passed. Only these two boards were read; no firmware change or upload was performed.

```text
wroom24 192.168.120.170: version v7.7.1.3, uptime 139311 s, free_heap 24524 B, min_free_heap 1824 B, boot 1795670620
wroom24 PASS: 192.168.120.170, boot 1795670620, uptime 139311 s, min_free_heap 1824 B
v2 192.168.120.170 office: ok, meta_key dm_aa8eba31, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 38 skipped 0 failed 0
v2 192.168.120.170 first_floor: ok, meta_key dm_9ed41104, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 38 skipped 0 failed 0
v2 192.168.120.170 outside: ok, meta_key dm_c38eecc4, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 38 skipped 0 failed 0
v2 192.168.120.170 wan_ping: ok, meta_key dm_7a81c392, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 38 skipped 0 failed 0
v2 192.168.120.170 nvs: used_entries 11780 (before 11140), free_entries 4348, old engine segments 1080, last_persist_epoch 1795806000 (before 1795669200, 3934 s ago), uptime 139314 s
v2 192.168.120.170 since the first v2 PASS (uptime 2980 s): old engine last_persist_epoch 1795672800 -> 1795806000; writes_ok grew for ['office', 'first_floor', 'outside', 'wan_ping']
v2 192.168.120.170 heap: free_heap 24440 B, min_free_heap 1824 B, uptime 139314 s
v2 192.168.120.170 PASS (later): boot 1795670620, uptime 139314 s, free_heap 24440 B, min_free_heap 1824 B, since the first v2 PASS at 1795673597: old engine last_persist_epoch 1795672800 -> 1795806000, writes_ok grew for office, first_floor, outside, wan_ping
v2 192.168.120.189 office: ok, meta_key dm_aa8eba31, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 39 skipped 0 failed 0
v2 192.168.120.189 first_floor: ok, meta_key dm_9ed41104, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 39 skipped 0 failed 0
v2 192.168.120.189 outside: ok, meta_key dm_c38eecc4, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 39 skipped 0 failed 0
v2 192.168.120.189 wan_ping: ok, meta_key dm_7a81c392, valid_segments 24, next_slot 22, last_persist_epoch 1795806000, writes ok 39 skipped 0 failed 0
v2 192.168.120.189 nvs: used_entries 11780 (before 11100), free_entries 4348, old engine segments 1080, last_persist_epoch 1795806000 (before 1795665600, 3938 s ago), uptime 143529 s
v2 192.168.120.189 since the first v2 PASS (uptime 7180 s): old engine last_persist_epoch 1795672800 -> 1795806000; writes_ok grew for ['office', 'first_floor', 'outside', 'wan_ping']
v2 192.168.120.189 PASS (later): boot 1795666409, uptime 143529 s, free_heap 39344 B, min_free_heap 21892 B, since the first v2 PASS at 1795673592: old engine last_persist_epoch 1795672800 -> 1795806000, writes_ok grew for office, first_floor, outside, wan_ping
```

WROOM's boot estimate `1795670620` is within 3 s of the recorded epoch. The observation is at 38.7 h, also exceeding the 36 h duration raised by review A F1. Minimum heap 1,824 B leaves 800 B above the required floor. Both boards have full 24-slot rings, all four writers advanced (WROOM 38 successes each, C3 39), and skipped/failed counts remain zero. The old engines advanced to epoch 1795806000 as well. The RAM-budget recommendation remains open for v7.7.1.4; this is no proof of a leak or of unlimited long-term margin.

Updated CURRENT-STATE and the audit, including criterion 9 and the exact saved PASS lines. The firmware diff against validated 48debeb is empty. F, PRE-PR, CI and normal body validation for this documentation head are published in the PR body and closing comment. Review B has not posted, so final body mode is not run and no merge is performed. This observation update adds no fix cycle.
