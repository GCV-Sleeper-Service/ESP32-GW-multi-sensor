# Fix PR64 — lwIP Socket Namespace Collision (CI Failure)

_Targeted fix for the v7.5.5.1 aggregator polling task PR before merge_
_Date: 2026-03-22_

---

## Context

PR #64 (`copilot/v7-5-5-1-implement-changes`) implements the aggregator polling task for v7.5.5.1. The CI pipeline fails with:

```
src/sensor_history_multi.h: In function 'bool fetch_to_buffer(const char*, char*, uint16_t, uint16_t*)':
src/sensor_history_multi.h:1440:14: error: reference to 'socket' is ambiguous
```

**Root cause:** ESPHome defines a C++ namespace `esphome::socket` (in `esphome/components/socket/headers.h`). When `fetch_to_buffer()` calls `socket(...)`, the compiler cannot distinguish between the lwIP function `int socket(int, int, int)` and the namespace `esphome::socket`. The same ambiguity potentially affects `connect`, `close`, `send`, `recv`, and `setsockopt`.

**Fix:** Replace all BSD socket convenience wrappers (`socket()`, `connect()`, `send()`, `recv()`, `close()`, `setsockopt()`) with their lwIP-prefixed equivalents (`lwip_socket()`, `lwip_connect()`, `lwip_send()`, `lwip_recv()`, `lwip_close()`, `lwip_setsockopt()`). These are the actual lwIP functions — the unprefixed names are just inline aliases defined in `lwip/sockets.h`. The prefixed names have zero namespace collision risk because nothing in ESPHome defines `lwip_socket` etc.

---

## Repository & Setup

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
git checkout copilot/v7-5-5-1-implement-changes
```

---

## Required Reading

1. `dashboard/sensor_history_multi.h` — locate the `fetch_to_buffer()` function inside the `#if AGGREGATOR_ENABLED` block (around line 1390–1500 in the PR branch)
2. The CI error output above — understand exactly which line triggers the ambiguity

---

## Exact Scope — ONLY these changes, NOTHING else

### Step 1: Replace BSD socket functions with lwip_* prefixed equivalents in `fetch_to_buffer()`

In `dashboard/sensor_history_multi.h`, inside the `fetch_to_buffer()` function, make these exact replacements:

| Current (ambiguous) | Replacement (explicit) |
|---|---|
| `socket(res->ai_family, res->ai_socktype, res->ai_protocol)` | `lwip_socket(res->ai_family, res->ai_socktype, res->ai_protocol)` |
| `setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv))` | `lwip_setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv))` |
| `setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv))` | `lwip_setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv))` |
| `connect(sock, res->ai_addr, res->ai_addrlen)` | `lwip_connect(sock, res->ai_addr, res->ai_addrlen)` |
| `send(sock, req, req_len, 0)` | `lwip_send(sock, req, req_len, 0)` |
| `recv(sock, hdr + hdr_len, 1, 0)` | `lwip_recv(sock, hdr + hdr_len, 1, 0)` |
| `recv(sock, buf + total, buf_size - 1 - total, 0)` | `lwip_recv(sock, buf + total, buf_size - 1 - total, 0)` |
| Every `close(sock)` call (there are 4) | `lwip_close(sock)` |

**WHY lwip_* instead of :: prefix:** Using `::socket()` would resolve the ambiguity for the function call, but `close()` has the same risk (POSIX `close` vs potential ESPHome wrappers), and the pattern isn't self-documenting. The `lwip_*` prefix makes it explicitly clear these are lwIP networking calls, and it matches the existing pattern in the PingAdapter code which already uses `lwip_getaddrinfo()` and `lwip_freeaddrinfo()`.

### Step 2: Add a code comment explaining the choice

Add this comment above the `fetch_to_buffer()` function, after the existing `s_fetch_tmp` declaration:

```cpp
// All socket operations use lwip_*() prefixed functions (not the BSD-compat
// aliases socket()/connect()/send()/recv()/close()) to avoid namespace
// collision with esphome::socket — see CI failure in PR #64.
```

### Step 3: Verify no other files are affected

Run `grep -rn 'socket(' dashboard/sensor_history_multi.h | grep -v lwip | grep -v nvs | grep -v '//\|ESP_LOG\|\*'` to confirm no unprefixed socket calls remain.

---

## Critical Rules

1. **DO NOT change any other code.** This is a surgical fix for the namespace collision only.
2. **DO NOT change the version number.** The version is already 7.5.5.1 from the previous commits on this branch.
3. **DO NOT regenerate dashboard.h, dashboard.html, or any other generated files.** Only `sensor_history_multi.h` changes.
4. **DO NOT modify the `#include` directives.** `lwip/sockets.h` is already included and provides both the unprefixed and prefixed function declarations.
5. **DO NOT touch the `PingAdapter` code** — it already uses `lwip_getaddrinfo()` correctly and has no socket calls that need fixing.

---

## Validation

```bash
# 1. Preflight must pass
bash scripts/preflight.sh

# 2. Playwright tests must pass (confirms no behavioral regression)
FIXTURE_SET=3sensor npx playwright test --project=chromium
FIXTURE_SET=3sensor npx playwright test --project=firefox
FIXTURE_SET=mixed npx playwright test --grep "Mixed-Category" --project=chromium

# 3. Verify no unprefixed socket calls remain in aggregator code
grep -n 'socket\|connect\|setsockopt' dashboard/sensor_history_multi.h | grep -v lwip | grep -v nvs | grep -v '//\|ESP_LOG\|\*\|esphome\|namespace\|#include\|ping_sock\|SOCK_STREAM'
# Expected: ZERO matches in the fetch_to_buffer function area
```

---

## Commit Message

```
fix(v7.5.5.1): replace BSD socket aliases with lwip_* to fix esphome::socket namespace collision

ESPHome defines `namespace esphome::socket` which makes bare `socket()`,
`connect()`, `close()` etc. ambiguous when lwip/sockets.h is also
included. Replace all BSD-compat aliases in fetch_to_buffer() with their
lwip_*() prefixed equivalents (lwip_socket, lwip_connect, lwip_send,
lwip_recv, lwip_close, lwip_setsockopt). These are the actual lwIP
functions — the unprefixed names are inline wrappers.

Matches the existing pattern used by PingAdapter (lwip_getaddrinfo,
lwip_freeaddrinfo).

Fixes CI compilation failure in PR #64.
```

---

## Bug Entry (add to `Docs/bugs-and-lessons-learned.md`)

```markdown
### BUG-057 — lwIP BSD socket aliases collide with `esphome::socket` namespace (2026-03-22)

**Severity:** Build-breaking (CI failure)
**Introduced in:** v7.5.5.1 (PR #64, aggregator polling task)
**Fixed in:** v7.5.5.1 (same PR, fix commit)

**Symptoms:** CI compilation fails with `error: reference to 'socket' is ambiguous`. The compiler cannot distinguish between lwIP's `int socket(int, int, int)` function and ESPHome's `namespace esphome::socket`.

**Root cause:** The `fetch_to_buffer()` function used BSD-compatible socket function names (`socket()`, `connect()`, `send()`, `recv()`, `close()`, `setsockopt()`). These are inline convenience aliases defined in `lwip/sockets.h` that wrap the real lwIP functions. ESPHome defines a C++ namespace `esphome::socket` (in `esphome/components/socket/headers.h`) which creates a name collision.

**Fix:** Replace all BSD socket aliases with their `lwip_*` prefixed equivalents (`lwip_socket()`, `lwip_connect()`, `lwip_send()`, `lwip_recv()`, `lwip_close()`, `lwip_setsockopt()`). These are the actual lwIP function names with no namespace collision.

**Prevention:** LESSON-OPS-068.
```

## Lesson Entry (add to `Docs/bugs-and-lessons-learned.md`)

```markdown
### LESSON-OPS-068: Use lwip_*() prefixed functions, not BSD socket aliases, in ESPHome C++ code (2026-03-22)

**Context:** ESPHome defines `namespace esphome::socket` which collides with lwIP's BSD-compatible inline wrappers (`socket()`, `connect()`, `close()` etc.). This is not visible when reading lwIP documentation because the aliases work fine in standalone ESP-IDF projects — the collision only appears inside the ESPHome build environment.

**Rule:** In any C++ code that runs inside ESPHome (headers included via YAML `includes:`), always use the `lwip_*` prefixed function names for socket operations:
- `lwip_socket()` not `socket()`
- `lwip_connect()` not `connect()`
- `lwip_send()` not `send()`
- `lwip_recv()` not `recv()`
- `lwip_close()` not `close()`
- `lwip_setsockopt()` not `setsockopt()`
- `lwip_getaddrinfo()` not `getaddrinfo()` (already used by PingAdapter)
- `lwip_freeaddrinfo()` not `freeaddrinfo()` (already used by PingAdapter)

**Applies to:** All current and future code that uses lwIP sockets — aggregator polling, history proxy, any future HTTP client code.
```
