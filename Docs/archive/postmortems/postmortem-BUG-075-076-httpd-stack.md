# Post-Mortem: BUG-075/076 — The 4 KB httpd Stack

_Date: 2026-03-30 | Repo: ESP32-GW-multi-sensor | PR #105_
_Duration: ~3 days of investigation across multiple sessions and agents_

---

## The Problem

Every POST request with a body to any endpoint on the ESP32-S3 aggregator
(192.168.120.191) crashed the board instantly. The crash was 100% reproducible,
affected all POST endpoints, and produced `Guru Meditation Error: StoreProhibited`
in `vPortYieldFromInt` with a corrupted backtrace.

GET requests worked perfectly. POST without a Content-Length header was rejected
cleanly by ESPHome (HTTP 411) without crashing.

---

## Timeline

### Day 1 — Initial hypothesis: our code is wrong

First session focused on the ESPHome POST handling flow. The theory was that
ESPHome's `request_post_handler` didn't consume the body for `application/json`
content types, leaving socket state corrupted. This was partially correct
(ESPHome *does* mishandle JSON POSTs) but wasn't the primary crash cause.

Attempted fixes that failed:
- Dashboard JS changed to send `Content-Type: application/json` with `body: '{}'`
- Zero-length POST guard in `handleRequest()` returning structured JSON error
- `httpd_req_recv` drain loop to consume unconsumed body bytes (added stack
  pressure, made things worse)

PR #103 and #104 were earlier iterations that didn't resolve the crash.

### Day 2 — Hypothesis: stack overflow, try CONFIG_HTTPD_STACK_SIZE

Session handoff identified four hypotheses in priority order:

1. `CONFIG_HTTPD_STACK_SIZE` not actually applied
2. httpd stack too small even at 24 KB
3. ESPHome's broken JSON content-type path
4. Race condition between httpd and aggregator polling tasks

**This was the right neighborhood but the wrong house.** The handoff recommended
setting `CONFIG_HTTPD_STACK_SIZE: "65536"` in the board profile and verifying
the sdkconfig.

### Day 3 — Root cause found: CONFIG_HTTPD_STACK_SIZE is dead code

Hardware testing with a second agent (Perplexity) proved:

- `CONFIG_HTTPD_STACK_SIZE: "65536"` → same crash, identical signature
- Race condition ruled out (polling stopped, crash persisted)
- `find .esphome -name sdkconfig | xargs grep HTTPD_STACK_SIZE` → empty

Investigation of ESP-IDF source revealed the truth:

```c
// esp_http_server.h — HTTPD_DEFAULT_CONFIG() macro
.stack_size = 4096,   // literal integer, no Kconfig reference
```

```cpp
// ESPHome web_server_idf.cpp lines 123–133
httpd_config_t config = HTTPD_DEFAULT_CONFIG();  // stack = 4096
config.lru_purge_enable = true;
config.close_fn = ...;
// stack_size is NEVER touched
httpd_start(&this->server_, &config);
```

**`CONFIG_HTTPD_STACK_SIZE` has never had any runtime effect.** It doesn't even
exist as a symbol in the compiled sdkconfig. The httpd task has been running at
exactly 4096 bytes for the entire project history.

### Day 3 continued — Wrong fix scope

Based on the root cause, a deferred task pattern was designed: move NVS-heavy
operations off the httpd stack into separate `xTaskCreate` tasks with 8192-byte
stacks. This pattern was modeled after the existing `schedule_reboot_()` /
`reboot_task_` pair already in the codebase.

PR #106 and #107 implemented:
- `reset_satellites_task_()` and `delete_data_task_()` deferred task functions
- Thinned `handle_reset_satellites_()` and `handle_delete_data_()` to
  authenticate → respond → spawn task
- Dashboard JS content-type fix (`application/json` → `x-www-form-urlencoded`)
- Removed dead `CONFIG_HTTPD_STACK_SIZE` from all board profiles

**All 7 hardware tests still crashed.**

### Day 3 final — Real fix: the stack is too small for ANY handler

The serial logs from the failed tests revealed the critical evidence:

**Test 6 (unauthenticated request, no NVS work at all)** produced a full
backtrace showing the crash inside `authenticate_management_()` →
`send_json_error_(401)` → `httpd_resp_send`. The handler never got past
authentication. No NVS, no mutex, no satellite loop — just auth check +
one HTTP response overflows 4 KB.

**Test 4 (`/api/reboot`)** — the endpoint that was "already safe" with its
own `xTaskCreate` pattern — also crashed. The lightest handler in the
codebase overflowed 4 KB.

**Conclusion:** The ESPHome wrapper layers (`AsyncWebServerRequest`, header
parsing, `request_post_handler`, `request_handler_`) plus the
`HistoryWebHandler::handleRequest()` routing plus `authenticate_management_()`
with its `std::string` header parsing plus `send_json_error_()` /
`beginResponse` / `httpd_resp_send` — just that basic path alone exceeds 4 KB.

### Day 3 resolution — Patch ESPHome's installed copy

Direct patch to ESPHome's installed `web_server_idf.cpp`:

```cpp
httpd_config_t config = HTTPD_DEFAULT_CONFIG();
config.stack_size = 16384;  // BUG-076: ESPHome default 4KB overflows
```

**First successful POST in three days.** Board stayed up. Response returned
cleanly (500/auth error — a separate minor bug, but no crash).

Permanent fix: local ESPHome component override via `external_components` in
YAML, managed by `scripts/patch-esphome-httpd-stack.sh`.

---

## Root Cause

ESP-IDF's `HTTPD_DEFAULT_CONFIG()` macro hardcodes `.stack_size = 4096` as a
literal integer. ESPHome's `web_server_idf.cpp` calls `httpd_start()` with
this config and never overrides `stack_size`. The httpd task therefore runs at
exactly 4096 bytes at all times.

Any HTTP handler that does more than trivial work overflows this stack. The
stack corruption overwrites the FreeRTOS TCB, causing unpredictable crashes
during the next context switch — typically `StoreProhibited` in
`vPortYieldFromInt` with `EXCVADDR: 0xfffffec0`.

`CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` is completely inert dead
config. It has zero runtime effect because the macro uses a literal, not a
Kconfig reference.

---

## Contributing Factors

### 1. Misleading sdkconfig option
`CONFIG_HTTPD_STACK_SIZE` *looks* like it should control the httpd stack size.
Multiple sessions assumed it was effective. The only way to discover it's dead
is to grep the compiled sdkconfig (where it doesn't appear) or read the ESP-IDF
macro source.

### 2. Variable crash signatures masked the root cause
Stack overflow doesn't produce a consistent crash. The same root cause produced
five different crash signatures across testing:
- `LoadProhibited` in `pthread_getspecific`
- `StoreProhibited` in `uxListRemove`
- `StoreProhibited` in `vPortYieldFromInt`
- Explicit `stack overflow in task httpd` detection
- `LoadProhibited` in `vTaskSwitchContext`

This made it appear that multiple different bugs were present.

### 3. Deferred task pattern was correct but insufficient
The `schedule_reboot_()` pattern was the right approach for NVS-heavy handlers
and remains necessary. But diagnosing "NVS operations overflow 4 KB" led to a
fix scoped too narrowly — the overflow happens before NVS is ever reached.

### 4. `handle_reboot_()` was a misleading "proof" that POST works
`handle_reboot_()` had never been tested with a proper POST body (`-d 'a=1'`).
It appeared to work because previous calls used bare `-X POST` (no body), which
ESPHome rejects at the framework level before reaching our handler. This created
the false belief that the reboot handler was safe and the crash was specific to
NVS-heavy handlers.

---

## The Fix (Permanent)

### Primary: Local ESPHome component override

`scripts/patch-esphome-httpd-stack.sh` copies ESPHome's `web_server_idf`
component into `firmware/custom_components/web_server_idf/` and applies one
line:

```cpp
config.stack_size = 16384;
```

Board YAMLs include:
```yaml
external_components:
  - source:
      type: local
      path: custom_components
    components: [web_server_idf]
```

### Secondary: Deferred task pattern for NVS handlers

`handle_reset_satellites_()` and `handle_delete_data_()` use `xTaskCreate`
(8192-byte stack) for NVS work. This was implemented in PR #106 and remains
correct — even with 16 KB httpd stack, NVS operations should not run on the
httpd task.

### Tertiary: Content-type fix

Dashboard POST calls changed from `application/json` to
`application/x-www-form-urlencoded` with `body: 'a=1'`. ESPHome only consumes
form-encoded POST bodies.

---

## Lessons Learned

### For this project

| Lesson | Description |
|---|---|
| LESSON-OPS-099 | ESPHome only consumes `x-www-form-urlencoded` POST bodies |
| LESSON-OPS-100 | `CONFIG_HTTPD_STACK_SIZE` is dead config — ESPHome hardcodes 4 KB |
| LESSON-OPS-101 | Deferred task pattern required for NVS-heavy HTTP handlers |
| LESSON-OPS-102 | ESPHome httpd stack must be patched via local component override |

| Critical Rule | Requirement |
|---|---|
| 38 | Dashboard POST → `x-www-form-urlencoded`, `body: 'a=1'` |
| 39 | curl POST → `-d 'a=1'`, never JSON, never empty |
| 40 | NVS in HTTP handler → deferred task pattern, 8192+ byte stack |
| 41 | Never add `CONFIG_HTTPD_STACK_SIZE` to board profiles |
| 42 | All board YAMLs must include `external_components` for patched `web_server_idf` |

### For embedded development generally

**1. Verify your config actually takes effect.** `grep` the compiled output.
If a setting doesn't appear in the binary's config, it's dead code no matter
how official the documentation looks.

**2. Stack overflows are chameleons.** The same overflow produced five different
crash signatures. If you see multiple different crashes from the same trigger,
suspect stack corruption first.

**3. "It works for this endpoint" is not proof.** `handle_reboot_()` appeared
safe only because it had never been tested with a proper POST body. The
framework-level rejection masked the stack overflow.

**4. Read the framework source.** Two layers of abstraction
(Kconfig → macro → runtime struct) hid the fact that the config option was
dead. The answer was in ESP-IDF's `esp_http_server.h` line ~200 and ESPHome's
`web_server_idf.cpp` lines 123–133.

**5. When a fix doesn't work, question the diagnosis scope, not just the fix.**
The deferred task pattern was correct but the problem was bigger than diagnosed.
The shift from "NVS overflows the stack" to "everything overflows the stack"
only happened after testing showed even the lightest handler crashed.

---

## Remaining Unknown Risks

This investigation exposed a class of problem: **ESPHome/ESP-IDF defaults that
are insufficient for non-trivial projects but invisible until they crash.**

Similar potential landmines:

| Area | Risk | How to check |
|---|---|---|
| FreeRTOS task stacks | Other tasks (main, WiFi, lwIP) may also be undersized for our workload | Add `uxTaskGetStackHighWaterMark()` logging to all custom tasks |
| lwIP socket pool | `CONFIG_LWIP_MAX_SOCKETS` *is* effective, but the default (10) may be low for aggregator + SSE + satellite polling | Monitor socket exhaustion under load |
| NVS partition size | Default 16 KB may be tight with satellite persistence + history metadata | Monitor `nvs_get_stats()` |
| ESP-IDF heap fragmentation | Long-running allocations on the internal heap may fragment over days | Periodic `heap_caps_get_info()` logging |
| ESPHome component defaults | Other components may have similar hardcoded-too-small defaults | Audit any component where we override behavior |

**Recommendation:** Add a periodic health-check task that logs stack HWM, heap
stats, socket usage, and NVS stats. This catches the next landmine before it
becomes a three-day investigation.

---

## Impact on Project Workflow

### For coding agents
- All future prompts must include Critical Rules 38–42
- All POST handler implementations must include the deferred task boilerplate
- `scripts/patch-esphome-httpd-stack.sh --check` should be part of CI preflight

### For ESPHome upgrades
- After `pip install --upgrade esphome`: re-run `scripts/patch-esphome-httpd-stack.sh`
- If the script fails (upstream changed the target area): manual inspection of
  the new `web_server_idf.cpp` and patch adaptation required
- Check ESPHome release notes for any httpd stack changes (this may eventually
  be fixed upstream)

---

_End of post-mortem._
