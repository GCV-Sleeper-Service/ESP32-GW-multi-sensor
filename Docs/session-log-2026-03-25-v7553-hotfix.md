# Session Log — 2026-03-25 — v7.5.5.3 Hotfix

## Context

- **Starting state:** v7.5.5.3 on main (commit 3241d5f), CI failing, aggregator dashboard non-functional on device
- **Task:** Fix CI pipeline failure, fix aggregator dashboard boot path (5 device bugs), address board info leakage

## Issues Found

### CI Failure (commit 3241d5f)

**Root cause:** `config/aggregator.json` was updated (added second satellite) but was already tracked by Git despite being in `.gitignore`. The generated `src/aggregator_config.h` was not regenerated, causing `render_sensor_config.py --check` to fail.

**Fix:** Untrack the file with `git rm --cached`, regenerate derived artifacts.

### BUG-064 — Aggregator boot path skips satellite pipeline (2026-03-25)

**Root cause:** `App.Boot.start()` had a forked if/else: aggregator path loaded manifest and called `initAggregatorDashboard()` but skipped ALL satellite functions — no SSE/polling, no `connectSSE()`, no `loadStorageStats()`, no `loadStatusSnapshot()`, no `buildSensorCards()`, no `loadHistory()`, no `initCharts()`. This caused:
- Red dot "connecting" (no SSE or polling started)
- "loading..." on History Storage (no `loadStorageStats()` called)
- "waiting for telemetry" on Telemetry chart (no SSE data feeding the chart)
- No local sensor cards (WAN ping) rendered

This directly violated Principle 1 from the design document: "An aggregator is a satellite with aggregation enabled."

**Fix:** Unified boot path — both satellite and aggregator run the full pipeline (manifest → sensors → cards → charts → SSE/polling → storage stats → history). Aggregator then overlays the Gateways section via `initAggregatorDashboard()` at the end.

### BUG-065 — Gateway cards rendered inside SENSORS section (2026-03-25)

**Root cause:** `renderGatewaySelector()` inserted the tab bar before `#sensorGrid` and `renderAllGatewaysSummary()` / `renderGatewayDevices()` / `renderSettingsPanel()` all wrote to `sensorGrid.innerHTML`. The gateway UI lived inside the SENSORS collapsible section, mixing remote satellite views with local sensor cards.

**Fix:** New Gateways collapsible section (`#hdr-gateways` / `#body-gateways`) added above SENSORS in dashboard.html, hidden by default. Contains `#gwSelectorContainer` for tab bar and `#gwGrid` for gateway content. `initAggregatorDashboard()` unhides it. All aggregator render functions now target `gwGrid` instead of `sensorGrid`. Local sensors stay in SENSORS.

### BUG-066 — Remote satellite cards show "calculating..." for history (2026-03-25)

**Root cause:** Environmental card renderer includes min/max history sections that display "temp: calculating... / hum: calculating..." as placeholder text. This is populated by `loadHistory()` which fetches from local endpoints. For remote satellite devices rendered via `renderGatewayDevices()`, no proxy history fetch exists — the placeholders were never updated.

**Fix:** After rendering gateway device cards, `renderGatewayDevices()` replaces all `.minmax-line .waiting` elements with "—" and hides the range toggle buttons. Proxy history fetch is deferred to a future step.

### BUG-067 — C3-specific content shown on non-C3 boards (2026-03-25)

**Root cause:** `updateBoardInfo()` only hid the C3 SuperMini SVG (`#pinoutDiagram`). The About card title ("ESP32-C3 SuperMini Gateway"), the GPIO pinout table (C3-specific pin mapping), and the ThermoPro description paragraph were all hardcoded and always visible.

**Fix:** Added `id` attributes to the GPIO pinout card (`gpioCard`), About card title (`aboutCardTitle`), and description block (`c3DescriptionBlock`). Extended `updateBoardInfo()` to hide all C3-specific elements and update the title from the manifest's `gateway.name` or `gateway.hardware` when the board is not a C3.

## Changes Made

### dashboard/dashboard.js
- `renderGatewaySelector()` — targets `#gwSelectorContainer` instead of inserting before `#sensorGrid`
- `renderAllGatewaysSummary()` — targets `#gwGrid` instead of `#sensorGrid`
- `renderGatewayDevices()` — targets `#gwGrid`; adds post-render history suppression (minmax → "—")
- `renderSettingsPanel()` — targets `#gwGrid`
- `initAggregatorDashboard()` — unhides `#hdr-gateways` and `#body-gateways`
- `updateBoardInfo()` — extended to hide GPIO card, update About title, hide C3 description
- `App.Boot.start()` — unified boot path (satellite pipeline always runs; aggregator overlays at end)

### dashboard/dashboard.html
- Added Gateways section HTML before SENSORS section (hidden by default)
- Added `id="gpioCard"` to GPIO pinout card
- Added `id="aboutCardTitle"` to About card heading
- Added `id="c3DescriptionBlock"` to ThermoPro description
- All JS functions mirrored from dashboard.js (LESSON-OPS-043)

### Documentation
- `Docs/bugs-and-lessons-learned.md` — BUG-064 through BUG-067, LESSON-OPS-074
- `Docs/changelog.md` — v7.5.5.3 hotfix entry
- `Docs/session-log-2026-03-25-v7553-hotfix.md` — this file

## Satellite Impact

Zero. The Gateways section is `display:none` by default. `detectAggregatorMode()` returns false on satellites, so `initAggregatorDashboard()` is never called. The satellite boot path is byte-identical to pre-hotfix.

## Device Testing Required

### Aggregator (.191)
- [ ] Gateways section appears above SENSORS
- [ ] Gateway selector tabs work (All Gateways, per-satellite, Settings)
- [ ] Local WAN Ping card renders in SENSORS section with live data
- [ ] No "connecting" red dot — SSE/polling active
- [ ] History Storage and Telemetry sections load
- [ ] Remote satellite cards show "—" for min/max (not "calculating...")
- [ ] C3 About card title replaced with board-specific name
- [ ] C3 GPIO pinout card hidden
- [ ] C3 description paragraph hidden

### Satellite (.189)
- [ ] Dashboard unchanged — no Gateways section visible
- [ ] All sensors render with live data
- [ ] History, storage stats, telemetry all work
