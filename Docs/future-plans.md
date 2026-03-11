# Future Plans & Feature Roadmap

_Last updated: 2026-03-10 — aligned to v7.4.1.0_

This document is the high-level roadmap.
For the detailed implementation-level plans, see:

- `Docs/implementation-plan-next-features-7.4.1.x.md`
- `Docs/planning-v7.4.2.0-custom-date-range.md`

The guiding philosophy remains the same:

- Solve real problems
- Preserve stability
- Keep deployment simple
- Avoid over-engineering on a constrained ESP32-C3 target

---

## Roadmap Summary

| Release / Phase | Feature | Status | Notes |
|---|---|---|---|
| v7.4.0 | CSV import with validation | Complete | Shipped |
| v7.4.0.2 | Single-sensor merge import | Complete | Shipped |
| v7.4.1.0 | Dashboard minification pipeline | Complete | Shipped |
| v7.4.2.x | Custom date range selector | Next | Dashboard-first feature |
| v7.4.3.x | Playwright browser automation | Planned | Regression control |
| v7.4.4.x | Configurable sensor count (1–4) | Planned | Documentation + validation + compatibility handling |
| v7.5.x | Secrets/settings persistence review | Deferred | Reassess after notification/settings needs are clearer |
| v7.6.x | Encrypted secrets partition | Low priority / likely skip | Probably more complexity than value |

---

## 1. v7.4.2.x — Custom Date Range Selector

**Priority:** High

### Goal

Add a user-selectable custom start/end time range in addition to the existing fixed presets:

- 24h
- 7d
- 30d
- 45d

### Why this matters

The current fixed ranges are good for common cases, but they are limiting when the user wants to inspect:

- One weather event
- One day across a longer retention window
- One imported historical slice
- A partial-period trend that does not align with the preset buckets

### Scope assessment

- Primarily dashboard work
- Uses existing history endpoints
- Uses existing storage-stats metadata for bounds
- Should not require a backend protocol redesign

### Risk

Low-to-medium.
The main risk is UI complexity and making sure the range state does not break existing preset behavior, min/max summaries, or chart redraw logic.

---

## 2. v7.4.3.x — Playwright Browser Test Automation

**Priority:** High

### Goal

Add automated browser regression coverage so dashboard changes stop relying only on manual checks.

### Why this matters

The dashboard now has enough moving parts that regressions are easy to introduce:

- Event binding
- Transport mode differences
- Theme redraw behavior
- Import/export UI
- Future custom date range behavior

### Scope assessment

- Mock backend or fixture-driven approach
- Dedicated CI workflow separate from ESPHome compile
- Screenshots / traces on failure
- Coverage for Chrome/Chromium first, with room to extend later

### Risk

Medium.
The challenge is building a test harness that is useful without becoming fragile.
The value is high because the next planned work is dashboard-heavy.

---

## 3. v7.4.4.x — Configurable Sensor Count (1–4)

**Priority:** Medium

### Goal

Normalize the project so the supported sensor-count range is clearly documented and safely configurable from **1 to 4 sensors**.

### Why this matters

The repo currently overstates its out-of-the-box sensor count in some documentation.
The code structure is already designed around indexed sensor slots, but the full workflow still needs to be normalized:

- C++ config
- YAML config
- Preflight checks
- Persistence compatibility guidance
- Clear instructions for changing sensor count

### Scope assessment

This is not just a README tweak.
It needs:

- Documentation
- Preflight validation
- Explicit history compatibility rules
- Test coverage for 1, 2, 3, and 4-sensor configurations

### Risk

Medium.
The frontend is already flexible, but the persistence structure changes with sensor count.
That means the feature has to be treated carefully to avoid silent history corruption or user confusion.

---

## 4. Secrets / Settings Persistence Review (v7.5.x)

**Priority:** Low-to-medium

A later phase may introduce a small persistent settings model for management credentials and related options.
This should be revisited only when there is a concrete feature need, such as notifications or user-editable runtime settings.

The default recommendation remains:

- Do not add complexity before it solves a real problem
- Avoid partition churn without a strong reason

---

## 5. Encrypted Secrets Partition (v7.6.x)

**Priority:** Low

This remains technically feasible, but still looks like a weak value tradeoff for the project's real deployment model.
For a home-lab or hobby deployment, improving ingress protection and browser/session controls is usually higher value than at-rest flash encryption for a tiny settings partition.

Current recommendation: **do not prioritize this** unless the security model changes materially.

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

---


## Release Strategy Guidance

Recommended order from the current baseline:

1. **v7.4.2.x — Custom date range**
2. **v7.4.3.x — Playwright automation**
3. **v7.4.4.x — Configurable 1–4 sensor count**

This order is intentional:

- Custom date range delivers visible user value quickly
- Playwright then hardens the dashboard before more UI/configuration complexity lands
- Configurable sensor count comes after the dashboard test baseline is stronger

---

## Documentation Discipline for Future Releases

To prevent roadmap drift:

- `README.md` should never advertise a future capability as already shipped
- `future-plans.md` should summarize, not replace, detailed implementation design
- `implementation-plan-next-features-7.4.1.x.md` should stay the detailed active plan until superseded
- Feature-specific planning docs should complement, not contradict, the master implementation plan
