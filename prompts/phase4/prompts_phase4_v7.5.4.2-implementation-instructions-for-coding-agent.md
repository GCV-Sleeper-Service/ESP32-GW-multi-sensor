# v7.5.4.2 — Add Network Card Renderer to Dashboard (Coding Agent Prompt)

_Full self-contained implementation instructions for the coding agent_
_Date: 2026-03-18_

---

## 1. Repository & Setup

```
Clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
```

---

## 2. Required Reading (MUST complete before any changes)

Read these files **completely** — do not skim:

1. `Docs/phase4-implementation-plan.md` — v7.5.4.2 section (network card renderer scope)
2. `Docs/bugs-and-lessons-learned.md` — ALL entries, especially:
   - **BUG-045** — `NUM_SENSORS` must alias `NUM_ENV_SENSORS`, never `NUM_DEVICES`
   - **BUG-043** — dashboard request fanout, gzip requirement, beginResponseStream prohibition
   - LESSON-OPS-043 — `dashboard.js` changes MUST be mirrored to `dashboard.html`
   - LESSON-OPS-050 through LESSON-OPS-059
3. `Docs/changelog.md` — recent entries for v7.5.4.0, v7.5.4.1
4. `Docs/v7.5-v7.6-architecture-plan.md` — Section 7.2 (Card renderer registry), Section 7.3 (Measurement formatters)
5. `dashboard/dashboard.js` — understand:
   - `CARD_RENDERERS` object and `buildEnvironmentalCard()` function
   - `METRIC_FORMATTERS` object
   - `handleState()` function and SSE/polling state update flow
   - `buildDeviceCards()` and how it dispatches by category
   - `normalizeManifestSensors()` which filters to environmental-only SENSORS
   - `applySensorMeta()` which calls `App.State.setSensors()`
6. `dashboard/dashboard.html` — understand CSS structure, existing card styles, and the JS mirror requirement
7. `tests/browser/dashboard.spec.js` — understand `loadDashboard()` helper (should already be fixed in v7.5.4.1), Group 14 tests, and teardown patterns
8. `tests/browser/manifest.spec.js` — understand current state
9. `tests/browser/sensor-count.spec.js` — understand current state
10. `config/sensors.json` — current v2 manifest with wan_ping device

---

## 3. Current Status

- v7.5.4.1 complete and merged (ICMP ping adapter running, producing real data)
- Firefox Playwright regressions from PR #51 fixed in v7.5.4.1 (confirm ALL Firefox tests pass before starting)
- Device test: `/api/v2/live` shows real `ping_ms` and `success_pct` values (confirm)
- Heap stable after 10+ minutes with ping task running (confirm)
- main is green, ALL Playwright tests pass on Chromium AND Firefox
- Current date: <INSERT_DATE>

**⚠️ PRE-CONDITION CHECK**: Before making ANY changes, verify that the Firefox Playwright fixes from v7.5.4.1 are in place:
1. `loadDashboard()` in `dashboard.spec.js` waits for `App.State.getSensors().length > 0`
2. `afterEach` does NOT use `page.goto('about:blank')`
3. `sensor-count.spec.js` has exactly ONE `afterEach` (no duplicates)
4. Run `npx playwright test --project=firefox` — ALL tests must pass before proceeding

---

## 4. Exact Scope — Network Card Renderer

Add `CARD_RENDERERS.network` to the dashboard to render the WAN ping probe as a network card.

### Step-by-step implementation:

#### 4a. Implement `buildNetworkCard(device, manifest)` in `dashboard.js`

Create the network card renderer function:
- Card header: device name (e.g., "WAN Latency") — use same `.sensor-card-header` class
- Current latency value with unit (e.g., "12 ms") — element id: `val-ping-{id}-latency`
- Success rate percentage (e.g., "100%") — element id: `val-ping-{id}-success`
- Target host display (from manifest `source.target`) — e.g., "Target: 8.8.8.8"
- Last seen indicator — same pattern as environmental cards
- Card wrapper: use class `.sensor-card .network-card` for category-specific styling
- Keep card dimensions consistent with environmental cards
- Visually distinguish from environmental cards (different accent color or network icon)

#### 4b. Register the renderer

```js
CARD_RENDERERS.network = buildNetworkCard;
```

#### 4c. Add metric formatters

```js
METRIC_FORMATTERS.ping_latency = function(value, unit) {
  if (value === null || isNaN(value)) return '—';
  return value.toFixed(0) + ' ' + (unit || 'ms');
};
METRIC_FORMATTERS.success_rate = function(value) {
  if (value === null || isNaN(value)) return '—';
  return value.toFixed(0) + '%';
};
```

#### 4d. Update state handling

Update `handleState()` or the state update flow to recognize non-environmental polling state updates for the network device. The existing SSE/polling flow carries state events with entity IDs — the ping device's metrics (`ping_ms`, `success_pct`) need DOM update handlers similar to how ThermoPro temp/hum updates work.

Specifically:
- When a state event arrives for a ping metric, find the DOM element by id and update its text
- Handle the `last_seen` field for staleness indication

#### 4e. Network card CSS

Add styles for `.network-card`:
- Same card dimensions and spacing as `.sensor-card`
- Dark/light mode compatible (use CSS custom properties)
- Different accent color from environmental cards (e.g., blue/teal for network vs amber for climate)
- Responsive layout matching existing cards

#### 4f. Handle network devices in SENSORS filtering

Currently `normalizeManifestSensors()` filters to `category === 'environmental'` only. The `SENSORS` array therefore contains only ThermoPro devices. The network card is rendered by `buildDeviceCards()` which iterates `SENSORS` and dispatches by category.

**Important**: You need to decide whether to:
- (A) Include network devices in the `SENSORS` array (change the filter) and let `buildDeviceCards()` dispatch, OR
- (B) Keep `SENSORS` as environmental-only and have `buildDeviceCards()` separately iterate network devices from `window._manifest.sensors`

Option (A) is cleaner and matches the architecture plan. If you go this route, ensure:
- `normalizeManifestSensors()` returns ALL categories (not just environmental)
- `makeSensorConfig()` handles network devices gracefully (doesn't try to build ThermoPro-specific IDs)
- All existing tests that assert `SENSORS.length === 3` are updated or use environmental-specific checks

Option (B) is safer for regression risk. Document whichever approach you choose.

#### 4g. Mirror to dashboard.html (LESSON-OPS-043 — CRITICAL)

Copy ALL changes from `dashboard.js` into `dashboard.html`. This includes:
- The `buildNetworkCard()` function
- The `CARD_RENDERERS.network` registration
- The metric formatters
- Any `handleState()` changes
- The network card CSS

#### 4h. Regenerate dashboard.h

Run `bash scripts/generate-header.sh` to produce gzip-compressed `dashboard.h`.

### Critical regression constraint:

**Environmental cards must be PIXEL-IDENTICAL to pre-Phase-4.** ThermoPro card layout, values, formatting, dew point, comfort estimate, min/max, battery, RSSI — all unchanged. If you change `normalizeManifestSensors()`, verify that environmental card rendering is completely unaffected.

---

## 5. Playwright Test Updates

### Existing tests that may need updates:

If you changed the SENSORS filtering (option A above):
- Group 2 (`three sensor cards are rendered`) — may need to expect 4 cards (3 environmental + 1 network), OR assert `.sensor-card:not(.network-card)` count is 3
- Group 14 scenario 1 (`sensor cards render correctly`) — update card count expectation
- Any test that asserts `App.State.getSensors().length === 3` — update to account for network devices

If you kept SENSORS as environmental-only (option B):
- Existing tests should pass unchanged
- You may need new assertions for the network card in a new test group

### Add new tests for the network card:

Add to an appropriate group (or create a new group) in `dashboard.spec.js`:
1. Network card renders when manifest contains a network device
2. Network card displays latency value element
3. Network card displays success rate element
4. Environmental cards are unaffected by network card presence
5. `CARD_RENDERERS.network` is registered and callable

### Firefox stability verification:

After all changes, verify:
- `loadDashboard()` still uses the robust `App.State.getSensors().length > 0` check
- `afterEach` still uses safe non-navigation teardown
- ALL Group 14 tests pass in Firefox
- ALL new network card tests pass in Firefox

---

## 6. Do NOT

- Modify `sensor_history_multi.h` (unless the state update path requires a small accessor change)
- Change `SegmentSnapshot` format or NVS persistence
- Change any ThermoPro card rendering logic
- Add chart rendering for network device (chart support comes later)
- Use `beginResponseStream` for any new response (LESSON-OPS-056)
- Change `NUM_SENSORS` aliasing
- Proceed to v7.5.4.3

---

## 7. Critical Rules

1. Use `bash scripts/bump-version.sh 7.5.4.2` for version bump
2. Run `python3 scripts/render_sensor_config.py --write` to regenerate
3. Run `bash scripts/generate-header.sh` to regenerate dashboard.h (gzip — LESSON-OPS-055)
4. Run `bash scripts/preflight.sh` — must pass
5. **Mirror ALL `dashboard.js` changes to `dashboard.html`** (LESSON-OPS-043)
6. **Run full Playwright suite on BOTH browsers:**
   - `npx playwright test --project=chromium` — ALL tests must pass
   - `npx playwright test --project=firefox` — ALL tests must pass
7. Never alias `NUM_SENSORS = NUM_DEVICES` (BUG-045)
8. Environmental cards must be pixel-identical to pre-Phase-4

---

## 8. Documentation Updates (mandatory)

1. **`Docs/changelog.md`** — Add v7.5.4.2 entry covering:
   - Network card renderer implementation (function, CSS, state handling)
   - SENSORS filtering approach chosen (A or B) and rationale
   - Test updates
   - All files changed
2. **`Docs/bugs-and-lessons-learned.md`** — Add entries for any bugs discovered
3. **`prompts/phase3-prompt-templates-updated.md`** — Update Step Index: mark v7.5.4.2 as complete

---

## 9. Review Checklist (verify before creating PR)

- [ ] `buildNetworkCard()` function implemented and renders correctly
- [ ] `CARD_RENDERERS.network` registered
- [ ] Metric formatters for ping_latency and success_rate added
- [ ] State update flow handles network device metric updates
- [ ] Network card CSS works in dark and light mode
- [ ] Environmental cards are PIXEL-IDENTICAL (visual check)
- [ ] `dashboard.js` changes fully mirrored to `dashboard.html`
- [ ] `dashboard.h` regenerated (gzip)
- [ ] `loadDashboard()` still uses robust `App.State.getSensors().length > 0` check
- [ ] `afterEach` in ALL spec files uses safe non-navigation teardown
- [ ] New Playwright tests for network card added and passing
- [ ] `npx playwright test --project=chromium` — all pass
- [ ] `npx playwright test --project=firefox` — all pass
- [ ] `bash scripts/preflight.sh` — all pass
- [ ] `Docs/changelog.md` updated
- [ ] Version is `7.5.4.2` everywhere

---

## 10. Device Testing (for human, after merge)

### Prerequisites — pull, compile, flash

```bash
cd /config/ESP32-GW-multi-sensor
git pull origin main

cat VERSION
# Expected: 7.5.4.2

esphome compile firmware/esp32-c3-multi-sensor.yaml
esphome run firmware/esp32-c3-multi-sensor.yaml
```

### Verification

```bash
# 1. Open dashboard in browser: http://192.168.120.189
# Expected:
#   - 3 ThermoPro environmental cards (Office, First Floor, Outside) — IDENTICAL to before
#   - 1 NEW network card (WAN Latency) showing latency value and success rate
#   - Network card should display real ping data (not null)
#   - Dark mode renders correctly for both card types
#   - Light mode renders correctly for both card types (toggle theme)

# 2. Visual regression check for environmental cards:
# Card layout, values, dew point, comfort, min/max, battery, RSSI — all must be identical.
# Take a screenshot for the record.

# 3. Verify heap stability:
curl -s http://192.168.120.189/api/status | grep free_heap
# Expected: Similar to v7.5.4.1 baseline

# 4. F5 refresh stability — press F5 3 times with 30-second intervals:
curl -s http://192.168.120.189/api/status | grep free_heap
# Expected: Heap recovers to baseline after each refresh

# 5. Let dashboard run for 10+ minutes:
# Expected: No crash, values update, network card shows live ping data

# 6. Verify via Cloudflare tunnel (if configured):
# Expected: Same as above — both card types render
```

### Report results

Record: heap value, screenshot of both card types, F5 stability. ANY environmental card regression is a blocker.

---

## 11. Post-merge tag

```bash
git pull origin main
git tag -a v7.5.4.2 -m "Phase 4 Step 2: Add network card renderer to dashboard"
git push origin v7.5.4.2
```