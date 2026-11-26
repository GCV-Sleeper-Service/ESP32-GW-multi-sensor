# Session log — R6, v7.7.1.3

Date: 2026-11-25, America/Los_Angeles. PR #247, branch `feature/v7.7.1.3-persist-write-path`.

## Evidence summary

The supplied setup and bundle hashes matched. Checkpoints 0, A–E and H passed. All three builds and OTA uploads succeeded. The first S3 persist check passed before the production uploads. C3 and WROOM each completed five writes per device without failures, and both old engines advanced. The C3 heap comparison passed. Every WROOM reading met the floor.

The C3 snapshot uses the higher c3heap reading: free heap 42,972 B before, 43,372 B after (+400 B); minimum heap 28,552 B before, 34,700 B after (+6,148 B). WROOM boot epoch: `1795641987`.

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

The 24-hour readings are pending the operator's exact trigger, `Run the block wroom24 now.` They will use boot `1795641987`, followed by the two `v2 ... later` blocks in the prescribed order. External reviews A, C and B are pending operator dispatch. No external review has been started, no issue edited, and no merge or tag performed.

## PRE-PR and review rounds

Pending the documentation checkpoint and PRE-PR gate. Inline review has not run yet.

