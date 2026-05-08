# Phase 8 — Notifications Plan

_Date: 2026-05-07 (multi-phase planning session)_
_Version range: v8.1.x_
_Depends on: Phase 7 (NVS infrastructure), Phase E (credential storage pattern)_

---

## Goal

Configurable threshold-based alerts via Telegram, ntfy.sh, and optionally email. Aggregator-first architecture — the aggregator monitors all satellite data and sends notifications centrally. TLS-capable standalone boards (C6, PSRAM boards) can send their own notifications.

## Architecture Decisions

| ID | Decision | Rationale |
|---|---|---|
| N-1 | Aggregator-first notification architecture | TLS heap cost (40 KB) paid once on PSRAM board, not on every satellite |
| N-2 | Telegram as primary channel | Simple HTTPS POST, free, reliable, rich formatting, no spam |
| N-3 | Notification rules stored in NVS (system partition) | Reuses Phase E credential storage pattern |
| N-4 | Per-rule cooldown (default 60 min) + global 10/hour hard limit | Prevents notification storms from stuck sensors |
| N-5 | ntfy.sh as second channel | Free, self-hostable, Android/iOS push, simpler than Telegram |
| N-6 | Email deferred to Phase 8.3 (optional) | SMTP complex, residential IPs blocked, low reliability |

## TLS Board Capability

TLS/notifications enabled **only** on PSRAM boards and C6:

| Board | free_heap | TLS viable? | Notifications? |
|---|---|---|---|
| C3 SuperMini | 58 KB | ❌ | No — 58-40=18 KB below WiFi minimum |
| WROOM-32D | 38 KB | ❌ | No — physically impossible |
| C6 SuperMini | 150 KB | ✅ | Yes — 110 KB remaining after TLS |
| S3 boards | PSRAM | ✅ | Yes |
| C5 WROOM-1U | PSRAM | ✅ | Yes |

Compile-time guard: `NOTIFICATIONS_ENABLED` in board profile. C3 and WROOM = 0.

## Step Breakdown

| Step | Version | Scope | Version bump? |
|---|---|---|---|
| 8.0 | — | Research: esp_tls heap measurement, Telegram Bot API, notification rule schema | No |
| 8.1 | v8.1.0.1 | Notification settings NVS schema + dashboard settings UI | Yes |
| 8.2 | v8.1.0.2 | Telegram channel: esp_tls POST, FreeRTOS task, rule evaluation | Yes |
| 8.3 | v8.1.1.1 | ntfy.sh channel (simpler HTTPS POST variant) | Yes |
| 8.4 | v8.1.2.1 | Email channel (optional — may skip) | Yes |
| 8.5 | v8.1.3.1 | Additional conditions: rate-of-change, offline detection, battery low | Yes |

## Memory/Flash Budget

| Component | Heap | Flash |
|---|---|---|
| Notification engine (rules, evaluation) | ~2 KB static | ~10-15 KB |
| TLS session (temporary, per notification) | ~40 KB peak (released after send) | ~0 (mbedTLS linked) |
| Notification FreeRTOS task | 4 KB stack | ~0 |
| Dashboard UI | ~0 | ~5-8 KB |
| **Total** | **~6 KB static + 40 KB peak** | **~20-25 KB** |

---

_End of Phase 8 plan._
