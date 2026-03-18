# BUG-043 Preflight Enhancement — Implementation Instructions

_For assistant implementation. Self-contained prompt._

---

## Context

Repo: https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor

After the BUG-043 gzip + pre-reserved history response fix, the following preflight checks were added:
- `dashboard_h_gzip_format` — verifies `DASHBOARD_HTML_GZ` in dashboard.h
- `dashboard_h_no_raw_literal` — verifies no `R"DASH64(` in dashboard.h
- `dashboard_inline_favicon` — verifies inline favicon in dashboard.html
- `firmware_gzip_content_encoding` — verifies `Content-Encoding", "gzip` in firmware
- `dashboard_h_size_guard` — verifies dashboard.h < 400KB

These are already implemented in `scripts/preflight.sh`. This document specifies additional preflight enhancements to prevent regression.

---

## Additional preflight checks to implement

### 1. No beginResponseStream for history endpoints

**Purpose:** Prevent regression to the heap-killing streaming pattern for large responses.

**Implementation:**
```bash
# BUG-043: history handler must use pre-reserved string, not beginResponseStream
if grep -n 'beginResponseStream.*text/plain' dashboard/sensor_history_multi.h | grep -v '^\s*//' | grep -q .; then
  echo "✗ no_streaming_history_response: FAIL — handle_history_ must use pre-reserved string, not beginResponseStream"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "no_streaming_history_response: OK"
fi
```

**Location:** Add after the `startup_poll_sequential` check block in `scripts/preflight.sh`.

**Rationale:** LESSON-OPS-056 — `beginResponseStream` for large responses causes heap exhaustion from std::string reallocation cascade.

### 2. Dashboard.h uses gzip byte array (already implemented — verify)

Already in preflight. Verify these three checks exist:
- `dashboard_h_gzip_format`: `DASHBOARD_HTML_GZ` present
- `dashboard_h_no_raw_literal`: `R"DASH64(` NOT present
- `dashboard_h_size_guard`: file size < 400KB

### 3. NVS yield interval check

**Purpose:** Prevent regression to the non-yielding NVS scan pattern.

**Implementation:**
```bash
# BUG-043: NVS scan loops must have yield calls
if grep -c 'maybe_yield_nvs_scan_' dashboard/sensor_history_multi.h | grep -qE '^[3-9]|^[0-9]{2,}'; then
  echo "nvs_yield_present: OK"
else
  echo "✗ nvs_yield_present: FAIL — expected 3+ calls to maybe_yield_nvs_scan_ in sensor_history_multi.h"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
```

### 4. In-flight guard verification

**Purpose:** Ensure all interval-driven fetch functions have in-flight guards.

**Implementation:**
```bash
# BUG-043: all interval-driven fetch functions must have in-flight guards
for guard in "_statusInFlight" "_storageStatsInFlight" "_historyInFlight"; do
  if grep -q "var ${guard}" dashboard/dashboard.js; then
    echo "inflight_guard_${guard}: OK"
  else
    echo "✗ inflight_guard_${guard}: FAIL — missing in-flight guard"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done
```

### 5. generate-header.sh produces gzip format

**Purpose:** Verify the build script itself uses gzip compression.

**Implementation:**
```bash
# BUG-043: generate-header.sh must use gzip compression
if grep -q 'gzip' scripts/generate-header.sh; then
  echo "generate_header_uses_gzip: OK"
else
  echo "✗ generate_header_uses_gzip: FAIL — generate-header.sh must gzip-compress the dashboard"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
```

---

## Validation

After implementing, run:
```bash
bash scripts/preflight.sh
```

All new checks should show OK. If any fail, the corresponding regression has been introduced.

---

## Critical rules

1. Add checks AFTER the existing `FAIL_COUNT=0` line (where other BUG-043 checks live)
2. Each check must increment `FAIL_COUNT` on failure
3. Use clear, descriptive check names
4. Include comments referencing the relevant LESSON-OPS number
5. Run `bash scripts/preflight.sh` after all changes — must pass

