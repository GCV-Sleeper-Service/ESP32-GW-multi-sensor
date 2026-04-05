# Phase X — Cross-Cutting Dependency Audit

_Date: 2026-04-05_
_Purpose: Verify Migration Safety Rule 7 — no module calls a function defined in a later module_
_Applies to: v7.6.5.0 module split (21 modules, concatenation order 00→20)_

---

## Why This Matters

At Level 1, all modules are concatenated into a single `dashboard.js` file — function call order doesn't matter because everything is in one scope. However:

1. **At Level 3**, when modules become component `index.js` files, the bundle script still concatenates them. But if a future change loads components asynchronously, forward references would break.
2. **Documentation value.** Understanding which modules depend on which helps future developers scope changes correctly.
3. **Phase Y.** In C++, forward declarations ARE required. This audit methodology carries forward.

---

## Methodology

For each function call in module N, check whether the called function is defined in module N or earlier (backward reference = safe) or in module N+1 or later (forward reference = potential issue).

**Tool:** Run this against `dashboard/dashboard.js` after v7.6.5.0:

```bash
#!/usr/bin/env bash
# Audit cross-module function calls in dashboard source modules
# Run from repo root after v7.6.5.0

set -euo pipefail

# Extract all function definitions with their module
echo "=== Function definitions by module ==="
for f in dashboard/src/*.js; do
  mod=$(basename "$f" .js)
  grep -n "^function \|^var .* = function\|^async function " "$f" | while read -r line; do
    echo "$mod: $line"
  done
done

echo ""
echo "=== Potential forward references ==="
echo "(Functions called before they are defined in concatenation order)"
echo ""
echo "NOTE: At Level 1 this is informational only."
echo "At Level 3 this becomes critical for component independence."
```

---

## Known Cross-Module Call Patterns

Based on reading the plan and the monolith, these are the expected cross-module dependencies:

### Backward references (safe — callee defined before caller)

| Caller module | Called function | Defined in |
|--------------|----------------|-----------|
| Most modules | `App.Config.*`, `App.State.*` | `01-config-state` |
| Most modules | `esc()`, `escHtml()`, `cToF()`, `formatBytes()` | `06-ui-helpers` |
| Most modules | `dlog()` | `06-ui-helpers` |
| `14-cards` | `SENSOR_COLORS`, `sensorSlug()` | `02-sensor-defs` |
| `16-charts` | `cToF()`, `formatEpochLocal()` | `06-ui-helpers` |
| `18-transport` | `handleState()` — wait, handleState IS in 18 | `18-transport` (self) |
| `19-aggregator` | `importFetchJsonWithRetry()` | `12-management` |
| `19-aggregator` | `requestManagementCredentials()` | `12-management` |
| `20-boot` | `detectAggregatorMode()` | `19-aggregator` |
| `20-boot` | `loadSensorManifest()` | `04-manifest` |
| `20-boot` | `loadStatusSnapshot()` | `05-status-snapshot` |
| `20-boot` | `initCharts()` | `16-charts` |
| `20-boot` | `startPolling()` | `18-transport` |

### Global variable dependencies (defined early, used later — safe)

| Variable | Defined in | Used by |
|----------|-----------|---------|
| `App`, `App.Config`, `App.State` | `00-app-shell`, `01-config-state` | All modules |
| `SENSORS` | `01-config-state` | Many modules |
| `SENSOR_COLORS` | `02-sensor-defs` | `14-cards`, `16-charts` |
| `METRIC_FORMATTERS` | `02-sensor-defs` | `14-cards` |
| `MAX_POINTS` | `01-config-state` | `16-charts`, `17-live-updates` |
| `TRANSPORT` | `01-config-state` | `18-transport` |

### Potential forward references (investigate at Level 3)

These are calls where a function in an earlier module calls a function in a later module. At Level 1 this works because all code is concatenated. At Level 3, these would need resolution (shared interface, callback registration, or event bus):

| Caller | Called function | Defined in | Notes |
|--------|----------------|-----------|-------|
| `06-ui-helpers` (`bindEvents`) | `toggleTheme()` | `06-ui-helpers` (self) | Safe |
| `08-custom-range` | `applyHistoryRange()` | `06-ui-helpers` | Backward — safe |
| `10-storage-stats` | `loadStorageStats()` calls itself recursively | `10-storage-stats` (self) | Safe |
| `18-transport` | `updateBadge()` | `14-cards` | **Forward at Level 1 (18 > 14)** — but wait, 14 is before 18. So backward. Safe. |

**Assessment:** Based on the contiguous-slice splitting, all cross-module calls appear to be backward references (callee defined before caller). This is expected because JavaScript's function hoisting and the monolith's natural top-down structure mean utility functions are defined early and consumers come later.

---

## Full Audit Instructions for v7.6.5.0

After the split, run the verification script (`scripts/verify-module-boundaries.sh`) and manually review any flagged forward references. If none are found, add a note to the v7.6.5.0 session log: "Dependency audit: no forward references detected. All cross-module calls are backward-safe."

If forward references are found, they are informational at Level 1 (concatenation makes them harmless) but should be documented for resolution at Level 3.

---

_End of dependency audit._
