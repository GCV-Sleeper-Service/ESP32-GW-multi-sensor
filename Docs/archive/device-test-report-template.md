# Device Test Report — v{VERSION}

**Tester:** {name}
**Date:** {YYYY-MM-DD}
**Firmware version:** v{VERSION}
**Commit:** {short hash}
**Flash method:** OTA / USB
**ESP device:** ESP32-C3 SuperMini
**Browser(s) tested:** {Chrome / Firefox / Safari / Edge / Mobile}

---

## Pre-flash checks

- [ ] CI workflow passed (green) for this commit
- [ ] Local preflight passed (`./scripts/preflight.sh`)
- [ ] Local compile succeeded (`esphome compile ...`)
- [ ] VERSION file matches firmware header comment

## Flash and boot

- [ ] Firmware flashed successfully
- [ ] Device rebooted and connected to WiFi
- [ ] ESPHome logs show normal startup (no crash loops)
- [ ] Dashboard accessible at device IP

## Core functionality

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Dashboard loads in browser | | |
| Sensor cards display for all sensors | | |
| Live temperature values updating | | |
| Live humidity values updating | | |
| BLE RSSI indicators visible | | |
| Dew point values shown | | |
| Staleness indicator works (sensor off) | | |

## History and charts

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Real-time chart renders | | |
| 24h history chart renders | | |
| 72h history chart renders | | |
| 7-day history (if applicable) | | |
| 30-day history (if applicable) | | |
| Chart data matches expected range | | |
| No gaps in chart where data expected | | |

## Theme and display

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Light mode renders correctly | | |
| Dark mode renders correctly | | |
| Theme toggle redraws charts (no stale colors) | | |
| Sensor color picker works | | |
| Color change updates line AND markers | | |
| 15-min chart markers correct size | | |

## Export

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Single sensor CSV export works | | |
| Export All works (no 502 error) | | |
| CSV timestamps are valid | | |
| CSV data matches chart visually | | |

## Management actions

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Reboot button requires auth | | |
| Reboot executes after auth | | |
| Delete history requires auth | | |
| Delete history clears data | | |
| Auth lockout after 3 failures | | |

## Storage and status

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| /api/storage-stats returns valid JSON | | |
| /api/status returns valid JSON | | |
| Storage panel shows partition info | | |
| NVS usage looks reasonable | | |
| Retention estimate displayed | | |

## Regression checks (from v7.3.4.2 hotfix list)

| Check | Pass/Fail | Notes |
|-------|-----------|-------|
| Export All does not cause HTTP 502 | | |
| Sensor recolor updates chart markers | | |
| 15-min markers not oversized | | |
| Theme switch does not need hard refresh | | |

## New feature checks (if applicable)

| Feature | Check | Pass/Fail | Notes |
|---------|-------|-----------|-------|
| {feature name} | {check description} | | |

## Access modes

| Mode | Pass/Fail | Notes |
|------|-----------|-------|
| LAN direct (http://device-ip) | | |
| Cloudflare reverse proxy (if configured) | | |
| Mobile browser | | |

## Issues found

{Describe any issues, with browser console errors if available.}

## Overall verdict

- [ ] **ACCEPT** — ready to tag and release
- [ ] **CONDITIONAL ACCEPT** — minor issues noted, non-blocking
- [ ] **REJECT** — blocking issues found, needs fix

## Notes

{Any additional observations, performance notes, or suggestions.}
