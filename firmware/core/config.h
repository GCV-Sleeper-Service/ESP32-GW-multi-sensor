#pragma once
// ═══════════════════════════════════════════════════════════════════
// config-v7.6.9.5.h - hourly persistence with dedicated history NVS partition
// Source fragment: firmware/core/config.h. Assembled output: dashboard/sensor_history_multi.h.
//
// v7.4.0.2: single-sensor import merges into existing segments without erasing
//   other sensors' data. Multi-sensor import still replaces all history.
// v7.4.0: adds CSV import via POST /api/import/{begin,d/,w/,finish}.
// Data is passed in the URL path for proxy compatibility (Cloudflare).
// Multi-sensor import is replacement-first: existing history is cleared before import.
// Single-sensor import is merge-first: existing segments are preserved and overlaid.
//
// PURPOSE:
//   Keeps 24 hours of 15-minute averages in RAM ring buffers for fast
//   reads and recent-history charting, persists one 1-hour segment
//   per hour into a dedicated history NVS partition, restores the
//   newest 24h worth of segments on boot, and serves merged history
//   (flash segments + newer RAM points) from the existing ESPHome
//   web server.
//
// Current behavior:
//   - 24h RAM retention (96 points per series)
//   - Hourly persistence to the dedicated history NVS partition
//   - Worst-case power-loss exposure of about one hour
//   - Dashboard endpoints: reboot + delete history (Basic-auth protected with lockout); dashboard UI keeps centralized bindEvents() wiring and App.State write chokepoints; v7.4.0 adds CSV import; v7.4.0.2 adds single-sensor merge import
//
// RETENTION MODEL:
//   RAM: 24h rolling window, written every 15 minutes
//   NVS: 45 days of circular hourly segments in a dedicated history partition
//   Effective user-visible history: about 45 days (flash + newest RAM overlap filtered)
//
// ENDPOINTS:
//   GET  /history/{id}/temp   -> "epoch,value\n" lines
//   GET  /history/{id}/hum    -> "epoch,value\n" lines
//   GET  /sensors.json        -> JSON array [{id, name}, ...]
//   GET  /dashboard.html      -> embedded dashboard
//   GET  /dashboard-download  -> embedded dashboard as attachment
//   POST /api/reboot          -> reboot the ESP (requires Basic auth)
//   POST /api/delete-data     -> erase persisted history and clear RAM (requires Basic auth)
//   POST /api/import/begin    -> clear history and prepare for multi-sensor CSV import (requires Basic auth)
//   POST /api/import/begin/single/<sensor_id> -> prepare for single-sensor merge import (requires Basic auth)
//   POST /api/import/d/<data> -> add data points to current segment (requires Basic auth)
//   POST /api/import/w/<data> -> add data points and write segment to NVS (requires Basic auth)
//   POST /api/import/finish   -> finalize import metadata and restore RAM (requires Basic auth)
//   GET  /api/storage-stats   -> partition sizes + live NVS usage + retained-history estimates (including retention_days from PERSIST_DAYS)
//   GET  /api/status          -> version, uptime, sensor status, heap (no auth)
//
// FRAMEWORK: ESPHome ESP-IDF via AsyncWebHandler + partition-specific NVS APIs
// ═══════════════════════════════════════════════════════════════════

#include <cstdio>
#include <ctime>
#include <cmath>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <new>
#include <string>
#include <cctype>


#include "esphome/core/log.h"
#include "esphome/components/web_server_base/web_server_base.h"

// ── Dashboard payload ────────────────────────────────────────────
// DASHBOARD_HTML_GZ[] (gzip-compressed) is defined in a separate
// dashboard header file (e.g. dashboard.h) which MUST be listed
// BEFORE this file in the YAML includes: block.  Keeping the
// dashboard as a separate include avoids duplicate-symbol errors
// when the dashboard version is bumped independently of the history
// backend.
//
// The dashboard is served with Content-Encoding: gzip — the browser
// decompresses transparently.  This reduces the HTTP transfer from
// ~190KB to ~45KB, cutting the transfer time from 2-4s to <1s and
// eliminating the primary BUG-043 crash trigger.
//
// If the build fails with "undefined reference to DASHBOARD_HTML_GZ",
// ensure the YAML includes the dashboard header before this file.

#include <esp_err.h>
#include <nvs.h>
#include <nvs_flash.h>
#include <esp_system.h>
#include <esp_partition.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/semphr.h>
#include <esp_wifi.h>
#include <lwip/ip_addr.h>
#include <lwip/netdb.h>
#include <ping/ping_sock.h>
#include "gateway_manifest.h"
#include "aggregator_config.h"

