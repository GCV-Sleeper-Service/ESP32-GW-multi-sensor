# Feature Roadmap

_Last updated: 2026-05-07 — aligned to v7.6.10.4 (Phase VX complete)_

This document is the high-level roadmap and builds on the early feature planning documents.

The guiding philosophy remains the same:

- Solve real problems
- Preserve stability
- Keep deployment simple
- Avoid over-engineering on a constrained ESP32-C3 target
- Don't complicate things beyond necessity — only things that incrementally improve should be adopted

---

## Roadmap Summary

| Phase | Feature | Status | Notes |
|---|---|---|---|
| v7.4.0 | CSV import with validation | Complete | Shipped |
| v7.4.0.2 | Single-sensor merge import | Complete | Shipped |
| v7.4.1.0 | Dashboard minification pipeline | Complete | Shipped |
| v7.4.2.0 | Custom date range selector | Complete | Shipped |
| v7.4.3.x | Playwright browser automation | Complete | 370+ tests across 12 spec files |
| v7.4.4.x | Configurable sensor count (1–4) | Complete | Documentation + validation + compatibility handling |
| Phase 5-6 | Modular architecture / gateway aggregation | Complete | Pull model, satellite management, aggregator dashboard |
| Phase D | Aggregator implementation | Complete | 6-board fleet operational |
| Phase X | Dashboard modular refactor | Complete | 12 core modules, 9 components |
| Phase Y | Firmware modular refactor | Complete | 8 fragments in firmware/core/ |
| Phase V | Stabilization (capacity, httpd, auth) | Complete | 10 steps, BUG-075–084 |
| Phase VX | Board onboarding + auth refactor | Complete | ESPHome 2026.4.1, 6 board profiles, authFetch() |
| Phase VY | Methodology audit | Complete | Process guide, practitioner's handbook |
| **Phase 7** | **Per-device persistence engine** | **Next** | **Fixes BUG-082 (critical). Chunked streaming + new NVS key scheme** |
| Phase E | Captive portal provisioning | Planned | Runtime board detection, WiFi setup without pre-compiled credentials |
| Phase 8 | Notifications | Planned | Telegram first, then ntfy.sh, then email |
| Phase 9 | Cloud data upload | Planned | InfluxDB Cloud first |
| Phase 10 | Dashboard UI enhancements | Planned | Dynamic sizing, multi-language |
| Phase 11 | Analytics / insights | Planned | Browser-side statistics, not AI on ESP32 |

---

## Phase 7 — Per-Device Persistence Engine

**Priority: CRITICAL** — BUG-082 crashes C3 and WROOM dashboards after ~3 weeks of data.

**Scope:** Replace monolithic `SegmentSnapshot` with per-device NVS storage, implement chunked HTTP streaming for history endpoints, add health-check telemetry task.

**Key constraint:** Must work within existing 512KB history NVS partition. WROOM has only ~38KB free heap — chunked streaming eliminates the full-CSV-in-RAM pattern.

**Architecture:** See `Docs/v7.7-v7.8-persistence-architecture.md` (needs rewrite for current codebase — Phase Y/V/VX changed file structure fundamentally).

**Implementation plan:** See `Docs/v7.7-implementation-plan.md` (stale — written 2026-03-19, must be rewritten during multi-phase planning session).

---

## Phase E — Captive Portal Provisioning

**Priority: HIGH** (design phase), MEDIUM (implementation)

Runtime board resource inspection for automatic role assignment (satellite vs aggregator). WiFi credentials configured through a web-based captive portal instead of pre-compiled secrets. First-time setup experience without requiring ESPHome compilation knowledge.

**Scope:** To be defined in multi-phase planning session.

**Key constraint:** Must work on all 6 board profiles. PSRAM-equipped boards (S3, C5) can run aggregator role; non-PSRAM boards (C3, WROOM, C6) are satellite-only.

---

## Phase 8 — Notifications

**Priority: MEDIUM** (valuable feature, significant scope)

Configurable alerts when sensor readings cross thresholds.

**Planned sub-phases:**
- 8.0: Notification settings UI/conditions + storage in secrets partition
- 8.1: Telegram notifications (easiest, most reliable — bot token + chat ID)
- 8.2: ntfy.sh push notifications (free, self-hostable, Android/iOS)
- 8.3: Email via SMTP relay (document spam risk, needs external relay)
- 8.4: Additional notification conditions

**Assessment:**
- Telegram first — no spam concerns, rich formatting, free, most reliable
- ntfy.sh second — free, open-source, self-hostable
- Email last — unreliable without proper SMTP relay from residential IP

**Dependency:** Requires secrets/settings persistence (may be Phase 7's settings partition or a dedicated Phase E deliverable).

---

## Phase 9 — Cloud Data Upload

**Priority: LOW**

Upload sensor data to cloud services for long-term storage or external dashboards.

| Service | Complexity | Free Tier | Recommendation |
|---|---|---|---|
| InfluxDB Cloud | Medium | 30-day retention, 5 MB/5min | Best fit — native time-series |
| Grafana Cloud | Medium | 10k metrics, 50 GB logs | Dashboards on top of InfluxDB |
| GitHub/Cloudflare Pages | Low | Unlimited static hosting | Read-only dashboard snapshot |
| Azure/GCP/AWS | High | Varies | Over-engineered unless enterprise |

**Recommendation:** InfluxDB Cloud first. Cloud upload without alerting is less useful than alerting without cloud upload — implement after notifications.

**MQTT bridge:** Bundle with cloud upload. ESPHome has native MQTT support. Optional compile-time flag for Home Assistant / Grafana integration.

---

## Phase 10 — Dashboard UI Enhancements

**Priority: LOW-MEDIUM**

- 10.0: Dynamic/responsive dashboard sizing with dropdown selector
- 10.1: Multi-language interface (3-5 languages initially, compact translation format)

**Constraint:** Dashboard is ~130 KiB. Multiple translation sets increase flash usage significantly on 4MB boards.

---

## Phase 11 — Analytics / Insights

**Priority: LOW** (interesting but premature)

Browser-side statistical analysis: moving averages, standard deviation alerts, rate-of-change detection. No AI/ML on ESP32 — inference would need cloud-side (requires Phase 9 first).

**Recommendation:** Start with JavaScript statistics in the browser. Cloud-based analytics only after cloud upload is working.

---

## Deferred / Low Priority

| Item | Assessment | Recommendation |
|---|---|---|
| Secrets/settings persistence | Needed for notifications | Scope during Phase 7 or Phase E planning |
| Encrypted secrets partition | Weak value tradeoff for home-lab deployment | Do not prioritize unless security model changes |
| Dashboard pane extensibility | Done at manifest level, not expanded to new sensor types | Implement when a concrete second sensor type exists |
| Heat index calculation | Browser-side, no firmware cost | Low effort — add during a dashboard phase |
| Cloudflare Access (Zero Trust) | External to device, deployment guide only | Document setup steps, not a firmware feature |

---

## Documentation Discipline

- `README.md` should never advertise a future capability as already shipped
- This roadmap summarizes; detailed plans live in `Docs/v7.7-implementation-plan.md` etc.
- Feature-specific planning docs complement, not contradict, this master roadmap
- Phase numbering follows the convention: numeric for feature phases, letter-prefix for infrastructure/refactoring phases

---

_This document is updated during multi-phase planning sessions and phase closures._
