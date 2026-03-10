# Future Plans & Feature Roadmap

_Last updated: 2026-03-09_

This document captures the feature roadmap, prioritization, and feasibility assessment for the ESP32-C3 Multi-Sensor BLE Gateway. The guiding philosophy: **high utility, minimum barrier, no unnecessary complexity.**

---

## Near-Term (Next 3 releases)

### 7.4.0 — Import with Validation ✅

**Status: IMPLEMENTED — pending merge of PR #2**

Import CSV data into the history partition via `POST /api/import`.

**Scope:**
- Replacement-first model (imported data replaces existing for overlapping timestamps)
- Strong validation: sensor ID, timestamp ordering, value ranges, duplicates, storage impact
- JSON report: accepted/rejected rows with reasons
- Basic auth protected
- Dashboard UI: import button, file picker, validation report display

**Assessment:** Straightforward extension of the existing `/api/delete-data` and `/history/*` patterns. The validation logic is the bulk of the work. Flash writes use the same NVS segment model. Risk is low because it touches a well-understood code path.

**Estimated complexity:** Medium. ~2-3 sessions for endpoint + dashboard UI + testing.

---

### 7.4.1a — Sensor Selection for Import

**Priority: MEDIUM**

Allow selecting which sensor(s) to import data for, rather than requiring all-or-nothing.

**Assessment:** Natural extension of 7.4.0. The import endpoint already needs to validate sensor IDs, so adding a selector in the UI is a small incremental step.

---

### 7.4.1b — Custom Date Range Display

**Priority: MEDIUM**

Add a "Custom Range" button after the existing 24h/7d/30d/45d selectors. Date picker should be based on dates actually present in stored history.

**Assessment:** Dashboard-only change, no backend modifications needed. The `/api/storage-stats` endpoint already exposes retention information. The browser can query available date range and present a picker. Low risk.

---

## Mid-Term (Testing & Infrastructure)

### Playwright Browser Test Automation

**Priority: HIGH — Should happen alongside or immediately after 7.4.x**

Automated browser testing with a mock backend, running as a second CI workflow.

**Scope:**
- Mock backend serving dashboard HTML with synthetic data
- Tests: dashboard loads, theme toggle, export button, sensor cards render, import UI works
- Second workflow: `browser-tests.yml`
- Failure produces screenshots and traces

**Assessment:** This is important for regression prevention. The dashboard has accumulated enough complexity (chart redraw, theme switching, export serialization, event binding) that manual testing is no longer sufficient. The mock approach avoids coupling tests to live device availability.

---

### Configurable Sensor Count

**Priority: MEDIUM**

Document and implement a comment-based configuration for changing the number of active sensors (1–4) without breaking anything.

**Assessment:** Mostly documentation and testing work. The `SensorSlot` array already supports this; the task is ensuring YAML blocks, the C++ array, and the dashboard all stay synchronized when sensors are added or removed. Should include a preflight check.

---

## Longer-Term Features

### 7.5 — Secrets Partition (10 KiB)

**Priority: LOW-MEDIUM**

A small dedicated partition for storing management credentials and notification settings in flash, separate from the history partition.

**Assessment:** Feasible. The partition table has room. The question is whether this is worth the complexity compared to just keeping secrets in the YAML/secrets file. The real value emerges only when notifications (8.x) are implemented, because notification settings need to survive firmware updates.

**Recommendation:** Defer until notifications are designed. Then decide if a secrets partition is actually needed or if NVS in the default partition is sufficient for the small amount of settings data.

---

### 7.6 — Encrypted Secrets Partition

**Priority: LOW**

Encrypt the secrets partition contents.

**Assessment:** ESP-IDF supports NVS encryption, but it adds significant complexity (key management, secure boot considerations). For a LAN device with Basic auth, this is probably over-engineering. The physical attack vector (someone extracting the flash chip) is not a realistic threat for a home sensor gateway.

**Recommendation:** Skip unless there's a specific requirement. Cloudflare Access (external to the device) is a better security investment.

---

### 7.7 — Modular Architecture / Gateway Aggregation

**Priority: MEDIUM-HIGH (design phase), LOW (implementation)**

Enable multiple BLE gateways (e.g., one per building) to have their data aggregated by a central gateway's dashboard.

**Assessment:** This is the most architecturally significant feature on the list. There are several approaches:

1. **Pull model** — The aggregator gateway polls each satellite gateway's `/api/status` and `/history/*` endpoints and renders them in a tabbed dashboard. This is the simplest approach and reuses existing endpoints.

2. **Push model** — Each gateway pushes data to a central endpoint (MQTT broker, REST API, or cloud service). More complex but more scalable.

3. **Iframe/embed model** — The aggregator dashboard embeds each gateway's dashboard in iframes. Simplest to implement but limited in integration depth.

**Recommendation:** Start with the **pull model** in a future version. It requires no changes to the satellite gateways (they already expose everything needed). The aggregator just needs a multi-gateway dashboard that fetches from multiple IPs. This could be a separate project/firmware or a mode in the existing firmware.

Design the data contract now (the `/api/status` endpoint is already a good starting point), but defer implementation until after the near-term features are complete.

---

### 7.8 — Dashboard Pane Extensibility

**Priority: LOW**

Add support for different sensor types (leak sensors, wind speed, etc.) as additional dashboard cards/panes.

**Assessment:** This requires abstracting the current ThermoPro-specific `SensorSlot` into a more generic sensor model with type-specific rendering. It's a substantial refactor of both the C++ backend and the JavaScript dashboard.

**Recommendation:** Design the abstraction when working on 7.7 (modular architecture), but implement it only when there's a concrete second sensor type to support. Don't build a generic framework speculatively.

---

### 8.x — Notifications

**Priority: MEDIUM (valuable feature, but significant scope)**

Configurable alerts when sensor readings cross thresholds.

**Planned phases:**
- 8.0: Notification UI — card for setting thresholds per sensor
- 8.1: Email notifications (avoiding spam filters is non-trivial)
- 8.2: Telegram bot notifications
- 8.3: Push notifications (requires a relay app — ntfy.sh is free and open-source)
- 8.4: Additional condition types

**Assessment:**

- **Telegram** is the easiest and most reliable notification channel. No spam concerns, rich formatting, free, requires only a bot token and chat ID. Should be implemented first, not third.
- **Email** from an ESP32 is unreliable without a proper SMTP relay. Gmail/Outlook spam filters will almost certainly catch messages from a residential IP. Needs an external relay service. Higher complexity than Telegram.
- **Push via ntfy.sh** is excellent — free, open-source, self-hostable, works on Android/iOS without a dedicated app (can use the ntfy app for reliability). Second priority after Telegram.
- **Phone push without an app** is not practical. The user will need ntfy or a similar app.

**Revised recommendation for notification order:**
1. 8.0: Notification settings UI + storage
2. 8.1: Telegram notifications (easiest, most reliable)
3. 8.2: ntfy.sh push notifications
4. 8.3: Email via SMTP relay (document the spam risk)

---

### 8.5–8.9 — Cloud Data Upload

**Priority: LOW**

Upload sensor data to cloud services for long-term storage or external dashboards.

**Assessment per target:**

| Service | Complexity | Free Tier | Recommendation |
|---------|-----------|-----------|----------------|
| GitHub Pages | Low | Unlimited static hosting | Good for a public read-only dashboard snapshot. Not real-time. |
| Cloudflare Pages | Low | Same as above | Same use case as GitHub Pages. |
| InfluxDB Cloud | Medium | 30-day retention, 5 MB/5min | Best option for time-series. Natural fit for this data. |
| Grafana Cloud | Medium | 10k metrics, 50 GB logs | Good for dashboards on top of InfluxDB. |
| ThingSpeak | Low | 8 channels, 3-min interval | Simple but limited. 3-minute minimum interval is restrictive. |
| Azure/GCP/AWS | High | Varies | Over-engineered for this project. Only if enterprise deployment is needed. |

**Recommendation:** InfluxDB Cloud is the natural first target if cloud upload is desired. It speaks the right language (time-series), has a reasonable free tier, and can feed Grafana. But this entire feature set should wait until notifications are working — cloud upload without alerting is less useful than alerting without cloud upload.

---

### 9.0 — Dynamic Dashboard Sizing

**Priority: LOW-MEDIUM**

Responsive/auto-sizing dashboard layout with a dropdown to select fixed (current) or auto-sizing.

**Assessment:** Currently the dashboard uses a fixed layout that works well on desktop screens. Making it fully responsive requires significant CSS work but no backend changes. Could be done incrementally (starting with font scaling, then card layout, then chart sizing).

**Recommendation:** Worth doing eventually, but after the functional features (import, notifications) are complete. A pragmatic first step: add a CSS media query for mobile viewports.

---

### 9.1 — Multi-Language Interface

**Priority: LOW**

Support for 10 common languages.

**Assessment:** Requires extracting all user-visible strings into a translation table and adding a language selector. The dashboard is ~130 KiB of HTML+JS — adding 10 translation sets would increase size significantly. On the ESP32 with limited flash, this is a real constraint.

**Recommendation:** If pursued, limit to 3–5 languages initially and use a compact translation format. Consider loading translations on demand rather than embedding all of them. This is a nice-to-have, not a priority.

---

### 10.x — AI Analytics

**Priority: LOW (interesting but premature)**

Use AI to analyze sensor data for trends, patterns, and outliers.

**Assessment:** The ESP32 itself has no capacity to run AI inference. This would need to be either browser-side (lightweight JS statistics) or cloud-side (requires cloud upload first). Simple trend detection and anomaly flagging could be done in JavaScript without AI — moving averages, standard deviation alerts, rate-of-change detection.

**Recommendation:** Start with statistical analysis in the browser (no AI needed). If cloud upload (8.5+) is implemented, external analytics becomes possible. True AI/ML analytics should not be on the ESP32 roadmap.

---

## Ideas Assessment

### ESP-NOW

**What it is:** Espressif peer-to-peer wireless protocol for battery-powered ESP32 nodes to transmit data without joining WiFi.

**Use case:** If you wanted battery-powered remote sensor nodes that report to this gateway (instead of BLE ThermoPro sensors), ESP-NOW would be the transport.

**Assessment:** Not useful for this project. The ThermoPro sensors already use BLE, and ESP-NOW would require custom sensor hardware (additional ESP32 boards). Only relevant if expanding beyond ThermoPro to custom-built sensors.

**Recommendation:** Skip. Revisit only if building custom sensor nodes.

---

### Snapshot Integrity Checks (CRC/Checksum)

**Assessment:** Adding CRC per saved segment would increase flash wear slightly (each write would be marginally larger). The current NVS implementation already handles corruption at the partition level. The risk of silent data corruption in a home environment is very low.

**Recommendation:** Not worth the added complexity. If data integrity becomes an actual problem, implement then.

---

### Dashboard Minification

**Assessment:** Running HTML through a minifier before generating the `.h` file could save ~20–25 KiB of flash. At 87.5% flash usage, this is meaningful headroom.

**Recommendation:** Worth doing as a build step, especially before adding new features that increase code size. Add a `scripts/minify-dashboard.sh` step before `generate-header.sh`. Use a simple HTML/JS minifier (terser for JS, html-minifier for HTML).

---

### Heat Index Calculation

**Assessment:** Browser-side calculation with no firmware cost. Useful for the "Outside" sensor in warm climates.

**Recommendation:** Easy to add alongside dew point. Low priority but low effort. Good candidate for a "while we're in the dashboard" addition during another feature.

---

### MQTT Bridge

**Assessment:** ESPHome has native MQTT support. Adding optional MQTT publish for each sensor reading would allow external systems (Grafana, InfluxDB, Home Assistant) to consume data without polling. Could be a compile-time flag.

**Recommendation:** Bundle this with the cloud upload features (8.x). If the user wants Home Assistant integration or external Grafana, MQTT is the cleanest path.

---

### WebSocket Alternative to SSE

**Assessment:** ESPHome doesn't natively support WebSocket on the web server. Custom implementation would be complex and fragile. The current SSE + polling fallback covers all practical access patterns.

**Recommendation:** Not needed. The polling mode already handles the Cloudflare SSE buffering issue.

---

### Cloudflare Access (Zero Trust)

**Assessment:** External to the device, requires Cloudflare configuration only. Provides authentication without any ESP32 changes.

**Recommendation:** Document the setup steps but implement it as a deployment guide, not a firmware feature. Should be addressed when the gateway is deployed for internet access.

---

## Recommended Implementation Order

Based on value, risk, and dependencies:

1. **7.4.0 — Import v1** (high value, well-scoped, next immediate)
2. **Custom date range** (small, dashboard-only, can ship with or right after import)
3. **Playwright automation** (investment in quality, prevents regressions for everything after)
4. **Configurable sensor count** (documentation + testing, modest effort)
5. **Dashboard minification** (build optimization, creates flash headroom for future features)
6. **7.7 — Gateway aggregation design** (design only, not implementation)
7. **8.0–8.2 — Notifications** (Telegram first, then ntfy.sh)
8. **Cloud upload** (InfluxDB Cloud as first target)
9. **Dynamic sizing** (responsive layout)
10. **Everything else** (multi-language, AI analytics, etc.)
