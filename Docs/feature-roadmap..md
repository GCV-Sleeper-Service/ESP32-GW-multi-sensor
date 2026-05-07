This document is the high-level roadmap and bulds on the early documents.

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
| v7.4.2.0 | Custom date range selector | Complete | Shipped |
| v7.4.3.x | Playwright browser automation | Complete | 28/28 PASS |
| v7.4.4.x | Configurable sensor count (1–4) | Complete| Documentation + validation + compatibility handling |
| v7.5.x | Modular Architecture / Gateway Aggregation | Complete | Documentation + validation + compatibility handling |

| vX.X.X | Modular Architecture / Gateway Aggregation | Complete | Documentation + validation + compatibility handling |

| vX.X.X | Dashboard Pane Extensibility | Complete | Done as manifest level but not expanded with different type of sensors yet |

| vX.X.X | Secrets/settings persistence review | Deferred | Reassess after notification/settings needs are clearer |
| vX.X.X | Encrypted secrets partition | Low priority / likely skip | Probably more complexity than value |
| vX.X.X | Provisioning captive portal |  |  |
| vX.X.X | Notifications/cloud data upload |  |  |
| vX.X.X | Dashboard resizing/multi-language interface |  |  |
| vX.X.X | Analytics/insights |  |  |

###  — Dashboard Pane Extensibility

**Priority: MEDIUM**

Add support for different sensor types (leak sensors, wind speed, etc.) as additional dashboard cards/panes.

**Assessment:** This requires abstracting the current ThermoPro-specific `SensorSlot` into a more generic sensor model with type-specific rendering. It's a substantial refactor of both the C++ backend and the JavaScript dashboard.

**Recommendation:** Design the abstraction when working on 7.5 (modular architecture), but implement it only when there's a concrete second sensor type to support. Don't build a generic framework speculatively.

---

### Secrets / Settings Persistence Review (v7.7.x) - DEFER

**Priority:** Low-to-medium

A later phase may introduce a small persistent settings model for management credentials and related options.
This should be revisited only when there is a concrete feature need, such as notifications or user-editable runtime settings.

The default recommendation remains:

- Do not add complexity before it solves a real problem
- Avoid partition churn without a strong reason

---

### Encrypted Secrets Partition (v7.8.x) - DEFER

**Priority:** Low

This remains technically feasible, but still looks like a weak value tradeoff for the project's real deployment model.
For a home-lab or hobby deployment, improving ingress protection and browser/session controls is usually higher value than at-rest flash encryption for a tiny settings partition.

Current recommendation: **do not prioritize this** unless the security model changes materially.

---

### 9.x — Notifications

**Priority: MEDIUM (valuable feature, but significant scope)**

Configurable alerts when sensor readings cross thresholds.

**Planned phases:**
- 9.0: Notification settings UI/conditions + storage
- 9.1: Telegram notifications (easiest, most reliable)
- 9.2: ntfy.sh push notifications
- 9.3: Email via SMTP relay (document the spam risk)
- 9.4: Additional notification conditions

**Assessment:**

- **Telegram** is the easiest and most reliable notification channel. No spam concerns, rich formatting, free, requires only a bot token and chat ID. Should be implemented first, not third.
- **Email** from an ESP32 is unreliable without a proper SMTP relay. Gmail/Outlook spam filters will almost certainly catch messages from a residential IP. Needs an external relay service. Higher complexity than Telegram.
- **Push via ntfy.sh** is excellent — free, open-source, self-hostable, works on Android/iOS without a dedicated app (can use the ntfy app for reliability). Second priority after Telegram.
- **Phone push without an app** is not practical. The user will need ntfy or a similar app.

---

### 9.5–9.9 — Cloud Data Upload

**Priority: LOW**

Upload sensor data to cloud services for long-term storage or external dashboards.

**Assessment per target:**

| Service | Complexity | Free Tier | Recommendation |
|---------|-----------|-----------|----------------|
| GitHub Pages | Low | Unlimited static hosting | Good for a public read-only dashboard snapshot. Not real-time. |
| Cloudflare Pages | Low | Same as above | Same use case as GitHub Pages. |
| InfluxDB Cloud | Medium | 30-day retention, 5 MB/5min | Best option for time-series. Natural fit for this data. |
| Grafana Cloud | Medium | 10k metrics, 50 GB logs | Good for dashboards on top of InfluxDB. |
| Azure/GCP/AWS | High | Varies | Over-engineered for this project. Only if enterprise deployment is needed. |

**Recommendation:** InfluxDB Cloud is the natural first target if cloud upload is desired. It speaks the right language (time-series), has a reasonable free tier, and can feed Grafana. But this entire feature set should wait until notifications are working — cloud upload without alerting is less useful than alerting without cloud upload.

**Planned phases:**
- 9.5: InfluxDB Cloud
- 9.6: GitHub Pages + Cloudflare Pages
- 9.7: Grafana Cloud
- 9.8: Cloud storage upload - Azure/GCP/AWS

---

### 10.0 — Dynamic Dashboard Sizing

**Priority: LOW-MEDIUM**

Responsive/auto-sizing dashboard layout with a dropdown to select fixed (current) or auto-sizing.

**Assessment:** Currently the dashboard uses a fixed layout that works well on desktop screens. Making it fully responsive requires significant CSS work but no backend changes. Could be done incrementally (starting with font scaling, then card layout, then chart sizing).

**Recommendation:** Worth doing eventually, but after the functional features (import, notifications) are complete. A pragmatic first step: add a CSS media query for mobile viewports.

---

### 10.1 — Multi-Language Interface

**Priority: LOW**

Support for 10 common languages.

**Assessment:** Requires extracting all user-visible strings into a translation table and adding a language selector. The dashboard is ~130 KiB of HTML+JS — adding 10 translation sets would increase size significantly. On the ESP32 with limited flash, this is a real constraint.

**Recommendation:** If pursued, limit to 3–5 languages initially and use a compact translation format. Consider loading translations on demand rather than embedding all of them. This is a nice-to-have, not a priority.

---

### 11.x — AI Analytics

**Priority: LOW (interesting but premature)**

Use AI to analyze sensor data for trends, patterns, and outliers.

**Assessment:** The ESP32 itself has no capacity to run AI inference. This would need to be either browser-side (lightweight JS statistics) or cloud-side (requires cloud upload first). Simple trend detection and anomaly flagging could be done in JavaScript without AI — moving averages, standard deviation alerts, rate-of-change detection.

**Recommendation:** Start with statistical analysis in the browser (no AI needed). If cloud upload (8.5+) is implemented, external analytics becomes possible. True AI/ML analytics should not be on the ESP32 roadmap.

---

## Ideas Assessment


### MQTT Bridge

**Assessment:** ESPHome has native MQTT support. Adding optional MQTT publish for each sensor reading would allow external systems (Grafana, InfluxDB, Home Assistant) to consume data without polling. Could be a compile-time flag.

**Recommendation:** Bundle this with the cloud upload features (9.x). If the user wants Home Assistant integration or external Grafana, MQTT is the cleanest path.


---


## Documentation Discipline for Future Releases

To prevent roadmap drift:

- `README.md` should never advertise a future capability as already shipped
- `future-roadmap.md` should summarize, not replace, detailed implementation design
- Feature-specific planning docs should complement, not contradict, the master implementation plan
