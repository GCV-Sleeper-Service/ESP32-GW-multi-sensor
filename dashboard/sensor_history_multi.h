#pragma once
// ═══════════════════════════════════════════════════════════════════
// sensor_history_multi-v7.5.6.0.h - hourly persistence with dedicated history NVS partition
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

static const char *const TAG = "history";

// ── Compile-time configuration ──────────────────────────────────
#ifndef HISTORY_HOURS
#define HISTORY_HOURS 24
#endif

#ifndef HISTORY_INTERVAL_MINUTES
#define HISTORY_INTERVAL_MINUTES 15
#endif

#ifndef PERSIST_DAYS
#define PERSIST_DAYS 45
#endif

static_assert(HISTORY_INTERVAL_MINUTES == 15,
              "This implementation assumes 15-minute buckets.");
static constexpr int HISTORY_POINTS_PER_SERIES =
    (HISTORY_HOURS * 60) / HISTORY_INTERVAL_MINUTES;
static constexpr uint32_t HISTORY_META_MAGIC = 0x48535636UL;      // "HSV6"
static constexpr uint16_t HISTORY_META_VERSION = 1;
static constexpr int HISTORY_SERIES_TEMP = 0;
static constexpr int HISTORY_SERIES_HUM = 1;
static constexpr uint32_t AUTH_FAILURE_DELAY_MS = 900;
static constexpr uint32_t AUTH_LOCKOUT_MS = 30000;
static constexpr uint8_t AUTH_MAX_FAILURES = 3;
static constexpr const char *AUTH_REALM = "ESP32 Gateway Management";


// ─── Ring buffer entry ──────────────────────────────────────────
struct HistEntry {
  uint32_t epoch;   // UTC seconds since 1970-01-01
  float    value;   // averaged reading, or NAN for gap
};


// ─── Ring buffer class ──────────────────────────────────────────
class HistoryBuffer {
 public:
  static constexpr int CAP = HISTORY_POINTS_PER_SERIES;

  void clear() {
    std::memset(buf_, 0, sizeof(buf_));
    head_ = 0;
    count_ = 0;
  }

  void add(uint32_t epoch, float value) {
    buf_[head_] = {epoch, value};
    head_ = (head_ + 1) % CAP;
    if (count_ < CAP) count_++;
  }

  void add_gap(uint32_t epoch) { add(epoch, NAN); }

  int count() const { return count_; }

  HistEntry at_logical(int logical_index) const {
    if (logical_index < 0 || logical_index >= count_) return {0, NAN};
    int start = (count_ < CAP) ? 0 : head_;
    int idx = (start + logical_index) % CAP;
    return buf_[idx];
  }

  uint32_t newest_epoch() const {
    if (count_ <= 0) return 0;
    return at_logical(count_ - 1).epoch;
  }

  int export_entries(HistEntry *out, int max_entries) const {
    if (out == nullptr || max_entries <= 0) return 0;
    int n = (count_ < max_entries) ? count_ : max_entries;
    for (int i = 0; i < n; i++) out[i] = at_logical(i);
    return n;
  }

  void load_from(const HistEntry *in, int n) {
    clear();
    if (in == nullptr || n <= 0) return;
    int limit = (n < CAP) ? n : CAP;
    for (int i = 0; i < limit; i++) {
      if (in[i].epoch > 0) add(in[i].epoch, in[i].value);
    }
  }

  // Stream compact "epoch,value\n" to HTTP response.
  // Gap entries -> "epoch,\n". Optional epoch filter avoids duplicates.
  void stream_to(AsyncResponseStream *stream,
                 uint32_t min_epoch_exclusive = 0) const {
    if (stream == nullptr) return;
    char line[48];

    for (int i = 0; i < count_; i++) {
      HistEntry entry = at_logical(i);
      if (entry.epoch == 0 || entry.epoch <= min_epoch_exclusive) continue;

      int len;
      if (std::isnan(entry.value)) {
        len = snprintf(line, sizeof(line), "%u,\n",
                       (unsigned) entry.epoch);
      } else {
        len = snprintf(line, sizeof(line), "%u,%.2f\n",
                       (unsigned) entry.epoch, entry.value);
      }
      if (len > 0 && len < (int) sizeof(line)) stream->print(line);
    }
  }

  // BUG-043 rev2: Append CSV to pre-reserved std::string instead of response stream.
  // This avoids the std::string reallocation cascade in beginResponseStream that
  // caused heap exhaustion when building large history responses (~24KB+ for 336 segments).
  void append_csv_to(std::string &csv,
                     uint32_t min_epoch_exclusive = 0) const {
    char line[48];

    for (int i = 0; i < count_; i++) {
      HistEntry entry = at_logical(i);
      if (entry.epoch == 0 || entry.epoch <= min_epoch_exclusive) continue;

      int len;
      if (std::isnan(entry.value)) {
        len = snprintf(line, sizeof(line), "%u,\n",
                       (unsigned) entry.epoch);
      } else {
        len = snprintf(line, sizeof(line), "%u,%.2f\n",
                       (unsigned) entry.epoch, entry.value);
      }
      if (len > 0 && len < (int) sizeof(line)) csv.append(line, len);
    }
  }

 private:
  HistEntry buf_[CAP] = {};
  int head_ = 0;
  int count_ = 0;
};


// ═══════════════════════════════════════════════════════════════════
// SensorSlot removed in v7.5.3.8 — all runtime state now in SensorEntity.
// ═══════════════════════════════════════════════════════════════════


// ── Phase 3: Generalized sensor model ──────────────────────────────────
// SensorEntity is the sole runtime model since v7.5.3.8.

#define MAX_METRICS_PER_DEVICE 4

struct MetricDef {
  const char* key;         // "temp_c", "humidity_pct", "ping_ms"
  const char* label;       // "Temperature", "Humidity"
  const char* unit;        // "°C", "%", "ms"
  uint8_t class_id;        // 0=analog, 1=binary, 2=counter, 3=metadata
  bool history_enabled;    // whether this metric has a HistoryBuffer
};

struct MetricState {
  float current_value;     // latest value or NAN
  float accumulator;       // for rolling average
  int sample_count;        // samples since last average
  bool valid;              // whether current_value is trustworthy
  uint32_t last_update_epoch;
  HistoryBuffer* history;  // nullptr if history_enabled == false
};

struct SensorEntity {
  // Identity (from manifest)
  const char* id;
  const char* name;
  uint8_t category_id;        // 0=environmental, 1=system, 2=network
  const char* adapter;         // "thermopro_ble", "icmp_ping"

  // Metrics (generated static arrays)
  const MetricDef* metric_defs;
  MetricState metric_states[MAX_METRICS_PER_DEVICE];
  uint8_t metric_count;       // actual metrics for this device (≤ MAX)

  // Adapter-specific fields
  const char* mac;             // non-null only for BLE devices
  int8_t last_rssi;
  uint32_t last_seen_epoch;

  // ── Formatted output (for text_sensor publish) ────────────────
  char temp_avg_str[32] = "";
  char hum_avg_str[16]  = "";
  char batt_str[16]     = "";
  bool temp_valid = false;
  bool hum_valid  = false;
  float batt_last = -1.0f;

  // Generic methods
  void add_sample(uint8_t metric_index, float value) {
    if (metric_index >= metric_count) return;
    auto& st = metric_states[metric_index];
    st.current_value = value;
    st.accumulator += value;
    st.sample_count++;
    st.valid = true;
    st.last_update_epoch = ::time(nullptr);
  }

  void compute_averages(uint32_t epoch) {
    for (uint8_t i = 0; i < metric_count; i++) {
      auto& st = metric_states[i];
      if (st.sample_count > 0 && st.history != nullptr) {
        float avg = st.accumulator / st.sample_count;
        st.history->add(epoch, avg);
      } else if (st.history != nullptr) {
        st.history->add_gap(epoch);
      }
      st.accumulator = 0;
      st.sample_count = 0;
    }
  }

  void compute_and_format(uint32_t epoch) {
    temp_valid = false;
    hum_valid  = false;

    // Temp is metric_states[0] for ThermoPro devices
    auto& ts = metric_states[0];
    if (ts.sample_count > 0 && ts.history != nullptr) {
      float avg = ts.accumulator / ts.sample_count;
      ts.history->add(epoch, avg);
      float avg_f = avg * 9.0f / 5.0f + 32.0f;
      snprintf(temp_avg_str, sizeof(temp_avg_str),
               "%.1f \xC2\xB0" "C / %.1f \xC2\xB0" "F", avg, avg_f);
      temp_valid = true;
      ESP_LOGI(TAG, "%s temp: %.1f\xC2\xB0" "C (%d samples, buf=%d)",
               name, avg, ts.sample_count, ts.history->count());
    } else {
      if (ts.history != nullptr) ts.history->add_gap(epoch);
      snprintf(temp_avg_str, sizeof(temp_avg_str), "NA");
      ESP_LOGW(TAG, "%s: no temp — gap inserted", name);
    }
    ts.accumulator = 0;
    ts.sample_count = 0;

    // Hum is metric_states[1] for ThermoPro devices
    auto& hs = metric_states[1];
    if (hs.sample_count > 0 && hs.history != nullptr) {
      float avg = hs.accumulator / hs.sample_count;
      hs.history->add(epoch, avg);
      snprintf(hum_avg_str, sizeof(hum_avg_str), "%.1f %%", avg);
      hum_valid = true;
      ESP_LOGI(TAG, "%s hum: %.1f%% (%d samples, buf=%d)",
               name, avg, hs.sample_count, hs.history->count());
    } else {
      if (hs.history != nullptr) hs.history->add_gap(epoch);
      snprintf(hum_avg_str, sizeof(hum_avg_str), "NA");
      ESP_LOGW(TAG, "%s: no hum — gap inserted", name);
    }
    hs.accumulator = 0;
    hs.sample_count = 0;

    // Reset remaining metric accumulators (batt, rssi)
    for (uint8_t i = 2; i < metric_count; i++) {
      metric_states[i].accumulator = 0;
      metric_states[i].sample_count = 0;
    }
  }

  void set_battery(float value) {
    if (!std::isnan(value) && value >= 0.0f && value <= 100.0f) {
      batt_last = value;
      snprintf(batt_str, sizeof(batt_str), "%.0f %%", value);
    }
  }

  void mark_seen(uint32_t epoch) {
    last_seen_epoch = epoch;
  }
};


// ═══════════════════════════════════════════════════════════════════
// Global sensor array — CONFIGURE SENSORS HERE
// ═══════════════════════════════════════════════════════════════════

// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>
// SensorSlot removed in v7.5.3.8 — all runtime state in SensorEntity devices[].
// NUM_DEVICES = all logical devices in manifest.
// NUM_SENSORS = persisted environmental sensor count only (backward-compat alias for SegmentSnapshot / HistoryMeta).
// <<< SENSOR_MANIFEST:HEADER_END >>>

// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>
// ── Generated SensorEntity arrays ──────────────────────────────────
// Generated by render_sensor_config.py from config/sensors.json
// Sole runtime model since v7.5.3.8 (SensorSlot removed)

static const MetricDef metrics_thermopro[] = {
  {"temp",  "Temperature", "\xC2\xB0""C", 0, true},
  {"hum",   "Humidity",    "%",            0, true},
  {"batt",  "Battery",     "%",            3, false},
  {"rssi",  "RSSI",        "dBm",          3, false}
};

static const MetricDef metrics_ping[] = {
  {"ping_ms",     "Latency", "ms", 0, true},
  {"success_pct", "Success", "%",  0, true}
};

static HistoryBuffer entity_hbuf_office_temp;
static HistoryBuffer entity_hbuf_office_hum;
static HistoryBuffer entity_hbuf_first_floor_temp;
static HistoryBuffer entity_hbuf_first_floor_hum;
static HistoryBuffer entity_hbuf_outside_temp;
static HistoryBuffer entity_hbuf_outside_hum;
static HistoryBuffer entity_hbuf_wan_ping_ping_ms;
static HistoryBuffer entity_hbuf_wan_ping_success_pct;

static constexpr int NUM_DEVICES = 4;
static constexpr int NUM_ENV_SENSORS = 3;
static constexpr int NUM_SENSORS = NUM_ENV_SENSORS;  // backward compat alias for persisted environmental history

#define PING_DEVICE_INDEX 3
#define PING_TARGET "8.8.8.8"

static SensorEntity devices[NUM_DEVICES] = {
  {
    .id = "office", .name = "Office",
    .category_id = 0, .adapter = "thermopro_ble",
    .metric_defs = metrics_thermopro,
    .metric_states = {
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_office_temp},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_office_hum},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}
    },
    .metric_count = 4,
    .mac = "DB:06:2C:58:8A:59",
    .last_rssi = 0, .last_seen_epoch = 0
  },
  {
    .id = "first_floor", .name = "First Floor",
    .category_id = 0, .adapter = "thermopro_ble",
    .metric_defs = metrics_thermopro,
    .metric_states = {
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_first_floor_temp},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_first_floor_hum},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}
    },
    .metric_count = 4,
    .mac = "D5:D8:4C:25:06:49",
    .last_rssi = 0, .last_seen_epoch = 0
  },
  {
    .id = "outside", .name = "Outside",
    .category_id = 0, .adapter = "thermopro_ble",
    .metric_defs = metrics_thermopro,
    .metric_states = {
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_outside_temp},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_outside_hum},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}
    },
    .metric_count = 4,
    .mac = "DF:EB:DE:19:11:6C",
    .last_rssi = 0, .last_seen_epoch = 0
  },
  {
    .id = "wan_ping", .name = "WAN Latency",
    .category_id = 2, .adapter = "icmp_ping",
    .metric_defs = metrics_ping,
    .metric_states = {
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_wan_ping_ping_ms},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_wan_ping_success_pct},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}
    },
    .metric_count = 2,
    .mac = "",
    .last_rssi = 0, .last_seen_epoch = 0
  },
};
// <<< SENSOR_MANIFEST:ENTITY_END >>>

// ═══════════════════════════════════════════════════════════════════
// ── SENSOR COUNT CONFIGURATION GUIDE (v7.5.6.0) ──
//
// Supported compile-time counts: 1, 2, 3 (default), 4
//
// To change count (recommended workflow):
//   1. Edit config/sensors.json OR run: python3 scripts/change_sensor_number.py
//   2. Run: python3 scripts/render_sensor_config.py --write
//   3. Back up retained history before flashing:
//      python3 scripts/history_backup.py export --host http://<esp-ip> --output backup.csv
//   4. Run: bash ./scripts/preflight.sh
//   5. Compile + flash the new firmware.
//   6. DELETE RETAINED HISTORY (layout is count-dependent).
//   7. Re-import the backup through the dashboard or history_backup.py.
//
// See Docs/configuring-sensors.md for the full procedure and manual fallback.
// NUM_DEVICES is set in the ENTITY_BEGIN block above; NUM_SENSORS is aliased
// to NUM_ENV_SENSORS (environmental-only count) for persisted-history backward compatibility.
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// Hourly NVS segment model
//   24h RAM ring buffers remain the live working set.
//   Flash persistence stores 1-hour segments (4 averaged points)
//   once per hour at :10 in a dedicated 'history' NVS partition.
//   This supports long retention without crowding the shared default NVS.
// ═══════════════════════════════════════════════════════════════════

#ifndef PERSIST_SEGMENT_HOURS
#define PERSIST_SEGMENT_HOURS 1
#endif

static_assert((PERSIST_SEGMENT_HOURS * 60) % HISTORY_INTERVAL_MINUTES == 0,
              "Persist segment must align to averaging interval");
static_assert(24 % PERSIST_SEGMENT_HOURS == 0,
              "Persist segment must divide 24 hours evenly");

static constexpr int PERSIST_POINTS_PER_SEGMENT =
    (PERSIST_SEGMENT_HOURS * 60) / HISTORY_INTERVAL_MINUTES;
static constexpr int RAM_SEGMENTS =
    HISTORY_POINTS_PER_SERIES / PERSIST_POINTS_PER_SEGMENT;
static constexpr int PERSIST_SLOTS =
    PERSIST_DAYS * (24 / PERSIST_SEGMENT_HOURS);

static const char *const HISTORY_NAMESPACE = "histv631";
// Namespace intentionally preserved from v6.3.1 so retained history survives
// an in-place v6.3.1 -> v6.4 / v6.5 upgrade. Storage schema is unchanged.
static const char *const HISTORY_PARTITION_LABEL = "history";

struct HistoryMeta {
  uint32_t magic = HISTORY_META_MAGIC;
  uint16_t version = HISTORY_META_VERSION;
  uint16_t num_sensors = NUM_SENSORS;
  uint16_t points_per_series = HISTORY_POINTS_PER_SERIES;
  uint16_t points_per_segment = PERSIST_POINTS_PER_SEGMENT;
  uint16_t valid_segments = 0;
  uint16_t next_slot = 0;
  uint16_t last_written_slot = 0xFFFF;
  uint32_t last_persist_epoch = 0;
};

struct SegmentSnapshotHeader {
  uint32_t magic = HISTORY_META_MAGIC;
  uint16_t version = HISTORY_META_VERSION;
  uint16_t num_sensors = NUM_SENSORS;
  uint16_t points_per_series = HISTORY_POINTS_PER_SERIES;
  uint16_t points_per_segment = PERSIST_POINTS_PER_SEGMENT;
  uint16_t reserved = 0;
  uint32_t saved_at_epoch = 0;
  uint32_t first_epoch = 0;
  uint32_t last_epoch = 0;
};

struct SegmentSnapshot {
  SegmentSnapshotHeader header;
  uint16_t temp_counts[NUM_SENSORS] = {};
  uint16_t hum_counts[NUM_SENSORS] = {};
  HistEntry temp[NUM_SENSORS][PERSIST_POINTS_PER_SEGMENT] = {};
  HistEntry hum[NUM_SENSORS][PERSIST_POINTS_PER_SEGMENT] = {};
};

static SegmentSnapshot *allocate_snapshot_() {
  auto *snapshot = new (std::nothrow) SegmentSnapshot();
  if (snapshot == nullptr) {
    ESP_LOGE(TAG, "Failed to allocate SegmentSnapshot (%u bytes)",
             (unsigned) sizeof(SegmentSnapshot));
  }
  return snapshot;
}

static bool g_history_restored_from_nvs = false;

static uint32_t find_partition_size_bytes_(const char *label,
                                           esp_partition_type_t type,
                                           esp_partition_subtype_t subtype) {
  if (label == nullptr) return 0;
  const esp_partition_t *part = esp_partition_find_first(type, subtype, label);
  return part ? (uint32_t) part->size : 0;
}


static void make_segment_key_(int slot, char *key, size_t key_len) {
  if (key == nullptr || key_len == 0) return;
  snprintf(key, key_len, "seg_%03d", slot % PERSIST_SLOTS);
}

static void clear_runtime_histories_() {
  for (int i = 0; i < NUM_DEVICES; i++) {
    for (uint8_t m = 0; m < devices[i].metric_count; m++) {
      if (devices[i].metric_states[m].history != nullptr) {
        devices[i].metric_states[m].history->clear();
      }
      devices[i].metric_states[m].accumulator = 0;
      devices[i].metric_states[m].sample_count = 0;
      devices[i].metric_states[m].valid = false;
    }
    devices[i].temp_valid = false;
    devices[i].hum_valid = false;
    snprintf(devices[i].temp_avg_str, sizeof(devices[i].temp_avg_str), "NA");
    snprintf(devices[i].hum_avg_str, sizeof(devices[i].hum_avg_str), "NA");
  }
  g_history_restored_from_nvs = false;
}

static esp_err_t ensure_history_nvs_ready_() {
  esp_err_t err = nvs_flash_init_partition(HISTORY_PARTITION_LABEL);
  if (err == ESP_OK || err == ESP_ERR_NVS_INVALID_STATE) {
    return ESP_OK;
  }

  if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_LOGW(TAG, "History partition '%s' needs erase/re-init: %s",
             HISTORY_PARTITION_LABEL, esp_err_to_name(err));
    esp_err_t erase_err = nvs_flash_erase_partition(HISTORY_PARTITION_LABEL);
    if (erase_err != ESP_OK) {
      ESP_LOGE(TAG, "nvs_flash_erase_partition(%s) failed: %s",
               HISTORY_PARTITION_LABEL, esp_err_to_name(erase_err));
      return erase_err;
    }
    err = nvs_flash_init_partition(HISTORY_PARTITION_LABEL);
    if (err == ESP_OK || err == ESP_ERR_NVS_INVALID_STATE) {
      return ESP_OK;
    }
  }

  if (err == ESP_ERR_NOT_FOUND || err == ESP_ERR_NVS_PART_NOT_FOUND) {
    ESP_LOGE(TAG, "History NVS partition '%s' not found in partition table",
             HISTORY_PARTITION_LABEL);
  } else {
    ESP_LOGE(TAG, "nvs_flash_init_partition(%s) failed: %s",
             HISTORY_PARTITION_LABEL, esp_err_to_name(err));
  }
  return err;
}

static bool open_history_nvs_(nvs_handle_t *handle, nvs_open_mode mode) {
  if (handle == nullptr) return false;
  esp_err_t err = ensure_history_nvs_ready_();
  if (err != ESP_OK) return false;

  err = nvs_open_from_partition(HISTORY_PARTITION_LABEL,
                                HISTORY_NAMESPACE,
                                mode,
                                handle);
  if (err == ESP_ERR_NVS_NOT_FOUND && mode == NVS_READONLY) {
    // Fresh boot before the first persist cycle. Treat as "no history yet"
    // instead of logging noisy errors on every dashboard request.
    return false;
  }
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "nvs_open_from_partition(%s,%s) failed: %s",
             HISTORY_PARTITION_LABEL, HISTORY_NAMESPACE, esp_err_to_name(err));
    return false;
  }
  return true;
}

static HistoryMeta default_history_meta_() {

  HistoryMeta meta;
  meta.magic = HISTORY_META_MAGIC;
  meta.version = HISTORY_META_VERSION;
  meta.num_sensors = NUM_SENSORS;
  meta.points_per_series = HISTORY_POINTS_PER_SERIES;
  meta.points_per_segment = PERSIST_POINTS_PER_SEGMENT;
  meta.valid_segments = 0;
  meta.next_slot = 0;
  meta.last_written_slot = 0xFFFF;
  meta.last_persist_epoch = 0;
  return meta;
}

static bool load_history_meta_(nvs_handle_t handle, HistoryMeta *meta,
                               bool *needs_nvs_persist = nullptr) {
  if (meta == nullptr) return false;
  if (needs_nvs_persist) *needs_nvs_persist = false;

  size_t sz = sizeof(HistoryMeta);
  esp_err_t err = nvs_get_blob(handle, "hist_meta", meta, &sz);
  if (err != ESP_OK) {
    *meta = default_history_meta_();
    return false;
  }

  // Full schema match — meta is valid as-is.
  bool valid = meta->magic == HISTORY_META_MAGIC &&
               meta->version == HISTORY_META_VERSION &&
               meta->num_sensors == NUM_SENSORS &&
               meta->points_per_series == HISTORY_POINTS_PER_SERIES &&
               meta->points_per_segment == PERSIST_POINTS_PER_SEGMENT &&
               meta->valid_segments <= PERSIST_SLOTS &&
               meta->next_slot < PERSIST_SLOTS;
  if (valid) return true;

  // BUG-046: Check for recoverable stale num_sensors from the temporary
  // NUM_SENSORS=4 build. All other schema fields must still match current
  // expectations — only num_sensors is allowed to differ.
  bool schema_ok = meta->magic == HISTORY_META_MAGIC &&
                   meta->version == HISTORY_META_VERSION &&
                   meta->points_per_series == HISTORY_POINTS_PER_SERIES &&
                   meta->points_per_segment == PERSIST_POINTS_PER_SEGMENT;
  if (schema_ok && meta->num_sensors != NUM_SENSORS) {
    ESP_LOGW(TAG, "BUG-046 migration: stale hist_meta num_sensors=%u, expected %u — correcting",
             (unsigned)meta->num_sensors, (unsigned)NUM_SENSORS);
    meta->num_sensors = NUM_SENSORS;
    // Preserve segment bookkeeping only if within valid bounds.
    if (meta->valid_segments > PERSIST_SLOTS) {
      ESP_LOGW(TAG, "  valid_segments %u out of range — resetting to 0",
               (unsigned)meta->valid_segments);
      meta->valid_segments = 0;
    }
    if (meta->next_slot >= PERSIST_SLOTS) {
      ESP_LOGW(TAG, "  next_slot %u out of range — resetting to 0",
               (unsigned)meta->next_slot);
      meta->next_slot = 0;
    }
    if (meta->last_written_slot != 0xFFFF && meta->last_written_slot >= PERSIST_SLOTS) {
      ESP_LOGW(TAG, "  last_written_slot %u out of range — resetting to 0xFFFF",
               (unsigned)meta->last_written_slot);
      meta->last_written_slot = 0xFFFF;
    }
    // last_persist_epoch preserved as-is.
    if (needs_nvs_persist) *needs_nvs_persist = true;
    return true;
  }

  // True corruption or incompatible schema — unrecoverable, reset to default.
  ESP_LOGW(TAG, "history meta corrupt or incompatible — resetting to default "
           "(magic=0x%08X version=%u sensors=%u pts_series=%u pts_seg=%u)",
           (unsigned)meta->magic, (unsigned)meta->version,
           (unsigned)meta->num_sensors, (unsigned)meta->points_per_series,
           (unsigned)meta->points_per_segment);
  *meta = default_history_meta_();
  if (needs_nvs_persist) *needs_nvs_persist = true;
  return false;
}

static bool save_history_meta_(nvs_handle_t handle, const HistoryMeta &meta) {
  esp_err_t err = nvs_set_blob(handle, "hist_meta", &meta, sizeof(meta));
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "nvs_set_blob(hist_meta) failed: %s", esp_err_to_name(err));
    return false;
  }
  err = nvs_commit(handle);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "nvs_commit(hist_meta) failed: %s", esp_err_to_name(err));
    return false;
  }
  return true;
}

static bool clear_persisted_history_() {
  esp_err_t err = nvs_flash_erase_partition(HISTORY_PARTITION_LABEL);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "nvs_flash_erase_partition(%s) failed: %s",
             HISTORY_PARTITION_LABEL, esp_err_to_name(err));
    return false;
  }
  err = ensure_history_nvs_ready_();
  if (err != ESP_OK) return false;

  clear_runtime_histories_();
  ESP_LOGW(TAG, "History partition '%s' cleared", HISTORY_PARTITION_LABEL);
  return true;
}

// BUG-043 firmware fix: long NVS scan loops can block the ESP32-C3 HTTP task
// for hundreds of milliseconds, starving BLE/WiFi/API/watchdog-sensitive work.
// Yield to the FreeRTOS scheduler every NVS_SCAN_YIELD_INTERVAL iterations so
// other tasks (BLE, WiFi, ESPHome API) get CPU time during history reads.
// BUG-043 rev2: increased from 4-iteration/1ms to 2-iteration/5ms after
// observing continued crashes — the ESP32-C3 single core needs more breathing
// room for BLE/WiFi/API between NVS flash reads.
static constexpr int NVS_SCAN_YIELD_INTERVAL = 2;
static void maybe_yield_nvs_scan_(int iteration) {
  if (iteration > 0 && (iteration % NVS_SCAN_YIELD_INTERVAL == 0)) {
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

static bool load_snapshot_from_handle_(nvs_handle_t handle, int slot,
                                       SegmentSnapshot *snapshot) {
  if (snapshot == nullptr) return false;

  char key[12];
  make_segment_key_(slot, key, sizeof(key));

  size_t sz = sizeof(SegmentSnapshot);
  esp_err_t err = nvs_get_blob(handle, key, snapshot, &sz);
  if (err != ESP_OK) {
    // BUG-048: Segments written with a different NUM_SENSORS compile-time
    // constant have a physically different blob size (e.g. NUM_SENSORS=4 →
    // 298 bytes vs NUM_SENSORS=3 → 230 bytes).  nvs_get_blob returns
    // ESP_ERR_NVS_INVALID_LENGTH when the stored blob doesn't match the
    // provided buffer size.  This is unrecoverable without a complex cross-
    // schema deserializer, so we log it clearly and skip.
    if (err == ESP_ERR_NVS_INVALID_LENGTH) {
      ESP_LOGW(TAG, "snapshot %s size mismatch: stored=%u expected=%u — "
               "likely written with different NUM_SENSORS (BUG-048)",
               key, (unsigned)sz, (unsigned)sizeof(SegmentSnapshot));
    }
    return false;
  }

  bool valid = snapshot->header.magic == HISTORY_META_MAGIC &&
               snapshot->header.version == HISTORY_META_VERSION &&
               snapshot->header.num_sensors == NUM_SENSORS &&
               snapshot->header.points_per_series == HISTORY_POINTS_PER_SERIES &&
               snapshot->header.points_per_segment == PERSIST_POINTS_PER_SEGMENT;
  if (!valid) {
    ESP_LOGW(TAG, "snapshot %s schema mismatch — ignored", key);
    return false;
  }

  for (int i = 0; i < NUM_SENSORS; i++) {
    if (snapshot->temp_counts[i] > PERSIST_POINTS_PER_SEGMENT ||
        snapshot->hum_counts[i] > PERSIST_POINTS_PER_SEGMENT) {
      ESP_LOGW(TAG, "snapshot %s count overflow — ignored", key);
      return false;
    }
  }
  return true;
}

static int export_latest_entries_(const HistoryBuffer &buf,
                                  HistEntry *out,
                                  int max_entries) {
  if (out == nullptr || max_entries <= 0) return 0;
  int available = buf.count();
  if (available <= 0) return 0;
  int take = available < max_entries ? available : max_entries;
  int start = available - take;
  for (int i = 0; i < take; i++) {
    out[i] = buf.at_logical(start + i);
  }
  return take;
}

static bool build_segment_snapshot_(SegmentSnapshot *snapshot,
                                    uint32_t saved_at_epoch) {
  if (snapshot == nullptr) return false;

  std::memset(snapshot, 0, sizeof(SegmentSnapshot));
  snapshot->header.magic = HISTORY_META_MAGIC;
  snapshot->header.version = HISTORY_META_VERSION;
  snapshot->header.num_sensors = NUM_SENSORS;
  snapshot->header.points_per_series = HISTORY_POINTS_PER_SERIES;
  snapshot->header.points_per_segment = PERSIST_POINTS_PER_SEGMENT;
  snapshot->header.saved_at_epoch = saved_at_epoch;

  bool any = false;
  uint32_t first_epoch = 0;
  uint32_t last_epoch = 0;

  for (int i = 0; i < NUM_SENSORS; i++) {
    // Persistence shim: SensorEntity → SegmentSnapshot
    // metric_states[0] = temp, metric_states[1] = hum (ThermoPro devices)
    HistoryBuffer *temp_buf = devices[i].metric_states[0].history;
    HistoryBuffer *hum_buf  = devices[i].metric_states[1].history;
    snapshot->temp_counts[i] = temp_buf ? export_latest_entries_(
        *temp_buf, snapshot->temp[i], PERSIST_POINTS_PER_SEGMENT) : 0;
    snapshot->hum_counts[i] = hum_buf ? export_latest_entries_(
        *hum_buf, snapshot->hum[i], PERSIST_POINTS_PER_SEGMENT) : 0;

    if (snapshot->temp_counts[i] > 0) {
      uint32_t local_first = snapshot->temp[i][0].epoch;
      uint32_t local_last =
          snapshot->temp[i][snapshot->temp_counts[i] - 1].epoch;
      if (local_first > 0 && (first_epoch == 0 || local_first < first_epoch))
        first_epoch = local_first;
      if (local_last > last_epoch) last_epoch = local_last;
      any = true;
    }
    if (snapshot->hum_counts[i] > 0) {
      uint32_t local_first = snapshot->hum[i][0].epoch;
      uint32_t local_last =
          snapshot->hum[i][snapshot->hum_counts[i] - 1].epoch;
      if (local_first > 0 && (first_epoch == 0 || local_first < first_epoch))
        first_epoch = local_first;
      if (local_last > last_epoch) last_epoch = local_last;
      any = true;
    }
  }

  snapshot->header.first_epoch = first_epoch;
  snapshot->header.last_epoch = last_epoch;
  return any && last_epoch > 0;
}

static void append_snapshot_to_ram_(const SegmentSnapshot &snapshot) {
  for (int i = 0; i < NUM_SENSORS; i++) {
    // Persistence shim: SegmentSnapshot → SensorEntity
    HistoryBuffer *temp_buf = devices[i].metric_states[0].history;
    HistoryBuffer *hum_buf  = devices[i].metric_states[1].history;
    if (temp_buf) {
      for (int n = 0; n < snapshot.temp_counts[i]; n++) {
        const HistEntry &entry = snapshot.temp[i][n];
        if (entry.epoch > 0) temp_buf->add(entry.epoch, entry.value);
      }
    }
    if (hum_buf) {
      for (int n = 0; n < snapshot.hum_counts[i]; n++) {
        const HistEntry &entry = snapshot.hum[i][n];
        if (entry.epoch > 0) hum_buf->add(entry.epoch, entry.value);
      }
    }
  }
}

static void stream_snapshot_series_(AsyncResponseStream *stream,
                                    const SegmentSnapshot &snapshot,
                                    int sensor_idx,
                                    int series_kind) {
  if (stream == nullptr || sensor_idx < 0 || sensor_idx >= NUM_SENSORS) return;

  const HistEntry *entries = nullptr;
  int count = 0;
  if (series_kind == HISTORY_SERIES_TEMP) {
    entries = snapshot.temp[sensor_idx];
    count = snapshot.temp_counts[sensor_idx];
  } else {
    entries = snapshot.hum[sensor_idx];
    count = snapshot.hum_counts[sensor_idx];
  }

  char line[48];
  for (int i = 0; i < count; i++) {
    const HistEntry &entry = entries[i];
    if (entry.epoch == 0) continue;

    int len;
    if (std::isnan(entry.value)) {
      len = snprintf(line, sizeof(line), "%u,\n", (unsigned) entry.epoch);
    } else {
      len = snprintf(line, sizeof(line), "%u,%.2f\n",
                     (unsigned) entry.epoch, entry.value);
    }
    if (len > 0 && len < (int) sizeof(line)) stream->print(line);
  }
}

// BUG-043 rev2: Append snapshot series CSV to pre-reserved std::string.
// Same logic as stream_snapshot_series_ but writes to a string buffer
// instead of an AsyncResponseStream — avoids the heap-killing reallocation
// cascade of beginResponseStream for large history responses.
static void append_snapshot_series_csv_(std::string &csv,
                                        const SegmentSnapshot &snapshot,
                                        int sensor_idx,
                                        int series_kind) {
  if (sensor_idx < 0 || sensor_idx >= NUM_SENSORS) return;

  const HistEntry *entries = nullptr;
  int count = 0;
  if (series_kind == HISTORY_SERIES_TEMP) {
    entries = snapshot.temp[sensor_idx];
    count = snapshot.temp_counts[sensor_idx];
  } else {
    entries = snapshot.hum[sensor_idx];
    count = snapshot.hum_counts[sensor_idx];
  }

  char line[48];
  for (int i = 0; i < count; i++) {
    const HistEntry &entry = entries[i];
    if (entry.epoch == 0) continue;

    int len;
    if (std::isnan(entry.value)) {
      len = snprintf(line, sizeof(line), "%u,\n", (unsigned) entry.epoch);
    } else {
      len = snprintf(line, sizeof(line), "%u,%.2f\n",
                     (unsigned) entry.epoch, entry.value);
    }
    if (len > 0 && len < (int) sizeof(line)) csv.append(line, len);
  }
}

static bool restore_from_nvs() {
  nvs_handle_t handle;
  if (!open_history_nvs_(&handle, NVS_READONLY)) return false;

  HistoryMeta meta;
  bool needs_nvs_persist = false;
  bool have_meta = load_history_meta_(handle, &meta, &needs_nvs_persist);
  nvs_close(handle);

  // BUG-046: persist corrected/default meta back to NVS to break the
  // stale-meta loop where an old num_sensors=4 blob was never overwritten.
  if (needs_nvs_persist) {
    nvs_handle_t wh;
    if (open_history_nvs_(&wh, NVS_READWRITE)) {
      if (save_history_meta_(wh, meta)) {
        ESP_LOGI(TAG, "Persisted %s history meta to NVS",
                 have_meta ? "migrated" : "default");
      } else {
        ESP_LOGE(TAG, "Failed to persist corrected history meta to NVS");
      }
      nvs_close(wh);
    }
  }

  if (!have_meta || meta.valid_segments == 0) {
    ESP_LOGI(TAG, "No persisted history segments to restore");
    return false;
  }

  // Re-open read-only for snapshot restore loop.
  if (!open_history_nvs_(&handle, NVS_READONLY)) return false;

  SegmentSnapshot *snapshot = allocate_snapshot_();
  if (snapshot == nullptr) {
    nvs_close(handle);
    return false;
  }

  clear_runtime_histories_();

  int restore_segments = meta.valid_segments < RAM_SEGMENTS
                             ? meta.valid_segments
                             : RAM_SEGMENTS;
  int oldest_valid_slot = (meta.next_slot + PERSIST_SLOTS - meta.valid_segments) % PERSIST_SLOTS;
  int start_offset = meta.valid_segments > restore_segments
                         ? (meta.valid_segments - restore_segments)
                         : 0;
  int first_restore_slot = (oldest_valid_slot + start_offset) % PERSIST_SLOTS;

  int restored = 0;
  int skipped_size_mismatch = 0;
  for (int n = 0; n < restore_segments; n++) {
    maybe_yield_nvs_scan_(n);  // BUG-043: yield every 4 blobs to avoid HTTP task starvation
    int slot = (first_restore_slot + n) % PERSIST_SLOTS;
    if (!load_snapshot_from_handle_(handle, slot, snapshot)) {
      skipped_size_mismatch++;
      continue;
    }
    append_snapshot_to_ram_(*snapshot);
    restored++;
  }
  nvs_close(handle);
  delete snapshot;

  // BUG-048: If some segments in the restore window were unloadable (e.g.
  // written with a different NUM_SENSORS compile-time constant and thus a
  // different SegmentSnapshot byte size), the meta's valid_segments count is
  // inflated — it includes ghost references to incompatible blobs.  Recalibrate
  // valid_segments to match only the actually-restorable segments so that:
  //   (a) subsequent boots don't waste time retrying unloadable slots
  //   (b) the restore window calculation targets only readable segments
  //   (c) future persist_hourly_segment() calls correctly grow valid_segments
  //       from the recalibrated baseline as new compatible segments are written
  if (skipped_size_mismatch > 0 && restored < restore_segments) {
    ESP_LOGW(TAG, "BUG-048: %d of %d segments unloadable (size/schema mismatch) "
             "— recalibrating meta from valid_segments=%u to %d",
             skipped_size_mismatch, restore_segments,
             (unsigned)meta.valid_segments, restored);
    meta.valid_segments = restored;
    // next_slot remains correct — it points to where the next write goes.
    // The recalibrated valid_segments means the "valid window" now covers
    // only the most recent `restored` slots behind next_slot.
    nvs_handle_t wh;
    if (open_history_nvs_(&wh, NVS_READWRITE)) {
      if (save_history_meta_(wh, meta)) {
        ESP_LOGI(TAG, "BUG-048: persisted recalibrated meta "
                 "(valid_segments=%u, next_slot=%u)",
                 (unsigned)meta.valid_segments, (unsigned)meta.next_slot);
      } else {
        ESP_LOGE(TAG, "BUG-048: failed to persist recalibrated meta");
      }
      nvs_close(wh);
    }
  }

  if (restored <= 0) {
    ESP_LOGW(TAG, "Persisted history exists but nothing was restorable");
    return false;
  }

  g_history_restored_from_nvs = true;
  ESP_LOGI(TAG, "Restored %d persisted hourly segment(s) into RAM", restored);
  return true;
}

static void persist_hourly_segment(uint32_t saved_at_epoch = 0) {
  SegmentSnapshot *snapshot = allocate_snapshot_();
  if (snapshot == nullptr) return;

  if (!build_segment_snapshot_(snapshot, saved_at_epoch)) {
    delete snapshot;
    ESP_LOGW(TAG, "Persist skipped — not enough buffered history yet");
    return;
  }

  nvs_handle_t handle;
  if (!open_history_nvs_(&handle, NVS_READWRITE)) {
    delete snapshot;
    return;
  }

  HistoryMeta meta;
  load_history_meta_(handle, &meta);

  if (meta.last_persist_epoch == snapshot->header.last_epoch) {
    ESP_LOGI(TAG, "Persist skipped — latest epoch %u already saved",
             (unsigned) snapshot->header.last_epoch);
    nvs_close(handle);
    delete snapshot;
    return;
  }

  int slot = meta.next_slot % PERSIST_SLOTS;
  char key[12];
  make_segment_key_(slot, key, sizeof(key));

  esp_err_t err = nvs_set_blob(handle, key, snapshot, sizeof(*snapshot));
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "nvs_set_blob(%s) failed: %s", key, esp_err_to_name(err));
    nvs_close(handle);
    delete snapshot;
    return;
  }

  meta.last_written_slot = slot;
  meta.next_slot = (slot + 1) % PERSIST_SLOTS;
  if (meta.valid_segments < PERSIST_SLOTS) meta.valid_segments++;
  meta.last_persist_epoch = snapshot->header.last_epoch;

  if (!save_history_meta_(handle, meta)) {
    nvs_close(handle);
    delete snapshot;
    return;
  }

  nvs_close(handle);
  ESP_LOGI(TAG,
           "Persisted segment slot %03d (%u .. %u), segments=%u, size=%u bytes",
           slot,
           (unsigned) snapshot->header.first_epoch,
           (unsigned) snapshot->header.last_epoch,
           (unsigned) meta.valid_segments,
           (unsigned) sizeof(*snapshot));
  delete snapshot;
}

static void reboot_task_(void *param) {
  (void) param;
  vTaskDelay(pdMS_TO_TICKS(250));
  esp_restart();
  vTaskDelete(nullptr);
}

static void schedule_reboot_() {
  xTaskCreate(reboot_task_, "hist_reboot", 2048, nullptr, 1, nullptr);
}


// ═══════════════════════════════════════════════════════════════════
// PingAdapter — periodic ICMP ping probe as a low-priority RTOS task
//
// Pings the configured target every 60 seconds (3 probes, 200ms spacing).
// Computes average RTT (ms) and success rate (%) and feeds them into the
// corresponding SensorEntity via add_sample() / mark_seen().
//
// Single-core constraints (BUG-043 / LESSON-OPS-053):
//   - Task priority tskIDLE_PRIORITY+1 (lowest non-idle) — yields between pings
//   - Total ping cycle ≈ 600ms (3 × 200ms) — well within 60s interval
//   - No mutex held during vTaskDelay or ping waits
//   - WiFi-down check skips cycle gracefully (no crash, no stall)
// ═══════════════════════════════════════════════════════════════════

#ifdef PING_DEVICE_INDEX
class PingAdapter {
 public:
  // Call once from on_boot lambda. Spawns the background task.
  void start(int device_index, const char* target_host) {
    device_index_ = device_index;
    target_host_  = target_host;
    sem_ = xSemaphoreCreateBinary();
    if (!sem_) {
      ESP_LOGE(TAG, "PingAdapter: failed to create semaphore");
      return;
    }
    xTaskCreate(ping_task_, "ping_adapter", 4096, this,
                tskIDLE_PRIORITY + 1, nullptr);
  }

 private:
  int device_index_     = -1;
  const char* target_host_ = nullptr;
  SemaphoreHandle_t sem_ = nullptr;

  // Accumulated per-cycle counters (written by callbacks, read after semaphore)
  uint32_t total_time_ms_ = 0;
  uint32_t recv_count_    = 0;
  uint32_t send_count_    = 0;

  // ── ESP-IDF ping callbacks ──────────────────────────────────────

  static void on_ping_success_(esp_ping_handle_t hdl, void* args) {
    uint32_t elapsed_ms = 0;
    esp_ping_get_profile(hdl, ESP_PING_PROF_TIMEGAP, &elapsed_ms, sizeof(elapsed_ms));
    auto* self = static_cast<PingAdapter*>(args);
    self->total_time_ms_ += elapsed_ms;
  }

  static void on_ping_timeout_(esp_ping_handle_t /*hdl*/, void* /*args*/) {
    // Counted in on_ping_end_ via send_count - recv_count
  }

  static void on_ping_end_(esp_ping_handle_t hdl, void* args) {
    auto* self = static_cast<PingAdapter*>(args);
    esp_ping_get_profile(hdl, ESP_PING_PROF_REQUEST, &self->send_count_, sizeof(self->send_count_));
    esp_ping_get_profile(hdl, ESP_PING_PROF_REPLY,   &self->recv_count_, sizeof(self->recv_count_));
    xSemaphoreGive(self->sem_);
  }

  // ── Main task ──────────────────────────────────────────────────

  static void ping_task_(void* arg) {
    auto* self = static_cast<PingAdapter*>(arg);
    while (true) {
      // ── 1. WiFi-down check ──────────────────────────────────────
      wifi_ap_record_t ap_info;
      if (esp_wifi_sta_get_ap_info(&ap_info) != ESP_OK) {
        ESP_LOGW(TAG, "PingAdapter: WiFi not connected, skipping cycle");
        vTaskDelay(pdMS_TO_TICKS(60000));
        continue;
      }

      // ── 2. DNS resolution ───────────────────────────────────────
      ip_addr_t target_addr;
      memset(&target_addr, 0, sizeof(target_addr));
      struct addrinfo hints = {};
      hints.ai_family = AF_INET;
      struct addrinfo* res = nullptr;
      int err = lwip_getaddrinfo(self->target_host_, nullptr, &hints, &res);
      if (err != 0 || res == nullptr) {
        ESP_LOGW(TAG, "PingAdapter: DNS resolution failed for %s, err=%d", self->target_host_, err);
        devices[self->device_index_].metric_states[0].valid = false;
        devices[self->device_index_].metric_states[1].valid = false;
        if (res) lwip_freeaddrinfo(res);
        vTaskDelay(pdMS_TO_TICKS(60000));
        continue;
      }
      auto* sa = reinterpret_cast<struct sockaddr_in*>(res->ai_addr);
      ip4_addr_set_u32(&target_addr, sa->sin_addr.s_addr);
      lwip_freeaddrinfo(res);

      // ── 3. Configure and run ping session ───────────────────────
      self->total_time_ms_ = 0;
      self->recv_count_    = 0;
      self->send_count_    = 0;

      esp_ping_config_t cfg     = ESP_PING_DEFAULT_CONFIG();
      cfg.target_addr            = target_addr;
      cfg.count                  = 3;
      cfg.interval_ms            = 200;
      cfg.timeout_ms             = 3000;
      cfg.task_stack_size        = 2048;
      cfg.task_prio              = tskIDLE_PRIORITY + 1;

      esp_ping_callbacks_t cbs  = {};
      cbs.on_ping_success        = on_ping_success_;
      cbs.on_ping_timeout        = on_ping_timeout_;
      cbs.on_ping_end            = on_ping_end_;
      cbs.cb_args                = self;

      esp_ping_handle_t hdl;
      if (esp_ping_new_session(&cfg, &cbs, &hdl) != ESP_OK) {
        ESP_LOGE(TAG, "PingAdapter: failed to create ping session");
        vTaskDelay(pdMS_TO_TICKS(60000));
        continue;
      }

      esp_ping_start(hdl);
      // Wait for on_ping_end_ semaphore (timeout: 3 pings × 3s + 3 × 0.2s ≈ 10s; use 15s)
      bool completed = (xSemaphoreTake(self->sem_, pdMS_TO_TICKS(15000)) == pdTRUE);
      esp_ping_stop(hdl);
      esp_ping_delete_session(hdl);

      if (!completed) {
        // Semaphore timed out — ping session did not report results; mark metrics invalid
        ESP_LOGW(TAG, "PingAdapter: ping session timed out, marking metrics invalid");
        devices[self->device_index_].metric_states[0].current_value  = NAN;
        devices[self->device_index_].metric_states[0].valid          = false;
        devices[self->device_index_].metric_states[0].last_update_epoch = ::time(nullptr);
        devices[self->device_index_].metric_states[1].current_value  = 0.0f;
        devices[self->device_index_].metric_states[1].valid          = false;
        devices[self->device_index_].metric_states[1].last_update_epoch = ::time(nullptr);
        vTaskDelay(pdMS_TO_TICKS(60000));
        continue;
      }

      // ── 4. Compute results and feed SensorEntity ────────────────
      float success_pct = (self->send_count_ > 0)
          ? static_cast<float>(self->recv_count_) / self->send_count_ * 100.0f
          : 0.0f;

      if (self->recv_count_ > 0) {
        float avg_rtt = static_cast<float>(self->total_time_ms_) / self->recv_count_;
        devices[self->device_index_].add_sample(0, avg_rtt);   // ping_ms
        ESP_LOGI(TAG, "PingAdapter: rtt=%.0fms success=%.0f%% (%u/%u)",
                 avg_rtt, success_pct, self->recv_count_, self->send_count_);
      } else {
        // All 3 pings timed out — mark ping_ms invalid, don't update accumulator
        devices[self->device_index_].metric_states[0].current_value  = NAN;
        devices[self->device_index_].metric_states[0].valid          = false;
        devices[self->device_index_].metric_states[0].last_update_epoch = ::time(nullptr);
        ESP_LOGW(TAG, "PingAdapter: all pings failed (0/%u), marking ping_ms invalid",
                 self->send_count_);
      }
      devices[self->device_index_].add_sample(1, success_pct); // success_pct
      devices[self->device_index_].mark_seen(::time(nullptr));

      // ── 5. Sleep 60s before next cycle ─────────────────────────
      vTaskDelay(pdMS_TO_TICKS(60000));
    }
  }
};
#endif  // PING_DEVICE_INDEX


// ═══════════════════════════════════════════════════════════════════
// Aggregator — satellite polling task and shared cache
// ═══════════════════════════════════════════════════════════════════
//
// Polls configured satellites on a schedule, caches their manifest,
// live, and status responses in RAM. Results are served by the
// aggregator API endpoints (v7.5.5.2).
//
// Thread safety: SatelliteCache structs are written by the polling
// task (RTOS context) and read by web handlers (ESPHome loop context).
// s_cache_mutex guards all reads and writes to the cache buffers.
// Torn-read prevention: fetch_to_buffer() writes into s_fetch_tmp
// (no mutex held during slow network I/O), then the completed result
// is copied into the cache under the mutex.
// ═══════════════════════════════════════════════════════════════════

#if AGGREGATOR_ENABLED
// Use lwIP BSD sockets for HTTP fetches — esp_http_client.h is not in
// ESPHome's IDF PRIV_REQUIRES; lwip/sockets.h is already available.
#include <lwip/sockets.h>

static const char* TAG_AGG = "aggregator";

struct SatelliteCache {
  const char* id;
  const char* name;
  const char* base_url;
  int poll_interval_seconds;

  // Cached responses (statically allocated — no malloc)
  char manifest_json[4096];     // cached /api/manifest response
  char live_json[2048];         // cached /api/v2/live response
  char status_json[512];        // cached /api/status response
  uint16_t manifest_len;
  uint16_t live_len;
  uint16_t status_len;

  // State
  uint32_t last_manifest_fetch;
  uint32_t last_live_fetch;
  uint32_t last_status_fetch;
  bool reachable;
  uint32_t last_seen_epoch;
  uint8_t consecutive_failures;

  void clear_cache() {
    manifest_json[0] = '\0'; manifest_len = 0;
    live_json[0] = '\0'; live_len = 0;
    status_json[0] = '\0'; status_len = 0;
    reachable = false;
    consecutive_failures = 0;
    last_manifest_fetch = 0;
    last_live_fetch = 0;
    last_status_fetch = 0;
    last_seen_epoch = 0;
  }
};

static SatelliteCache satellite_caches[MAX_SATELLITES];

static SemaphoreHandle_t s_cache_mutex = nullptr;

// MUST be called once before starting the polling task:
static void init_aggregator_mutex() {
  s_cache_mutex = xSemaphoreCreateMutex();
}

// Polling task: take mutex before updating cache, give after
#define AGG_LOCK()   xSemaphoreTake(s_cache_mutex, pdMS_TO_TICKS(200))
#define AGG_UNLOCK() xSemaphoreGive(s_cache_mutex)

// Web handlers (v7.5.5.2): take mutex before reading cache, give after
// Use timeout of 100ms — if lock unavailable, serve stale data rather than blocking

// Single static temp buffer, reused across all fetches.
// Safe because aggregator_poll_task is the only writer and fetches are sequential.
static char s_fetch_tmp[4096];

// Separate from s_fetch_tmp — the proxy runs in web handler context
// while the polling task runs in RTOS context. They must not share buffers.
// Only accessed by the web handler (ESPHome main loop, single-threaded).
static char s_proxy_tmp[32768];
static uint16_t s_proxy_len = 0;

// All socket operations use lwip_*() prefixed functions (not the BSD-compat
// aliases socket()/connect()/send()/recv()/close()) to avoid namespace
// collision with esphome::socket — see CI failure in PR #64.
//
// Minimal HTTP/1.0 GET using lwIP BSD sockets.
// Avoids esp_http_client.h, which is not in ESPHome's IDF PRIV_REQUIRES.
// Uses lwip/sockets.h and lwip/netdb.h (both already available).
// Returns true and sets *out_len on HTTP 200; false otherwise.
static bool fetch_to_buffer(const char* url, char* buf, uint16_t buf_size, uint16_t* out_len) {
  *out_len = 0;

  // ── Parse "http://host[:port]/path" ────────────────────────────
  if (strncmp(url, "http://", 7) != 0) return false;
  const char* host_start = url + 7;

  char host[128];
  char port_str[8];
  const char* path = "/";

  const char* slash = strchr(host_start, '/');
  const char* colon = strchr(host_start, ':');

  if (colon && (!slash || colon < slash)) {
    // host:port[/path]
    size_t host_len = (size_t)(colon - host_start);
    if (host_len == 0 || host_len >= sizeof(host)) return false;
    memcpy(host, host_start, host_len);
    host[host_len] = '\0';
    const char* port_end = slash ? slash : colon + strlen(colon);
    size_t port_len = (size_t)(port_end - colon - 1);
    if (port_len == 0 || port_len >= sizeof(port_str)) return false;
    memcpy(port_str, colon + 1, port_len);
    port_str[port_len] = '\0';
  } else {
    // host[/path]
    const char* host_end = slash ? slash : host_start + strlen(host_start);
    size_t host_len = (size_t)(host_end - host_start);
    if (host_len == 0 || host_len >= sizeof(host)) return false;
    memcpy(host, host_start, host_len);
    host[host_len] = '\0';
    strcpy(port_str, "80");
  }
  if (slash) path = slash;

  // ── DNS resolution ─────────────────────────────────────────────
  struct addrinfo hints = {};
  hints.ai_family   = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  struct addrinfo* res = nullptr;
  if (lwip_getaddrinfo(host, port_str, &hints, &res) != 0 || !res) return false;

  // ── Socket, timeout, connect ───────────────────────────────────
  int sock = lwip_socket(res->ai_family, res->ai_socktype, res->ai_protocol);
  if (sock < 0) { lwip_freeaddrinfo(res); return false; }

  struct timeval tv = {};
  tv.tv_sec = 5;
  lwip_setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  lwip_setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

  if (lwip_connect(sock, res->ai_addr, res->ai_addrlen) != 0) {
    lwip_close(sock); lwip_freeaddrinfo(res); return false;
  }
  lwip_freeaddrinfo(res);

  // ── Send HTTP/1.0 GET (no chunked encoding) ────────────────────
  char req[512];
  int req_len = snprintf(req, sizeof(req),
      "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", path, host);
  if (lwip_send(sock, req, req_len, 0) < 0) { lwip_close(sock); return false; }

  // ── Read response headers into small stack buffer ──────────────
  // Read one byte at a time until \r\n\r\n to find the header/body split.
  // Typical embedded server headers are <500 bytes, so this is bounded.
  char hdr[512];
  int  hdr_len = 0;
  bool hdr_done = false;
  while (!hdr_done && hdr_len < (int)(sizeof(hdr) - 1)) {
    int n = lwip_recv(sock, hdr + hdr_len, 1, 0);
    if (n <= 0) break;
    hdr_len++;
    if (hdr_len >= 4 &&
        hdr[hdr_len - 4] == '\r' && hdr[hdr_len - 3] == '\n' &&
        hdr[hdr_len - 2] == '\r' && hdr[hdr_len - 1] == '\n') {
      hdr_done = true;
    }
  }
  if (!hdr_done) { lwip_close(sock); return false; }

  // Check HTTP 200 status
  if (strncmp(hdr, "HTTP/", 5) != 0) { lwip_close(sock); return false; }
  const char* sp = (const char*)memchr(hdr, ' ', hdr_len < 20 ? hdr_len : 20);
  if (!sp || strncmp(sp + 1, "200", 3) != 0) { lwip_close(sock); return false; }

  // ── Read body directly into caller's buffer ────────────────────
  int total = 0;
  while (total < (int)(buf_size - 1)) {
    int n = lwip_recv(sock, buf + total, buf_size - 1 - total, 0);
    if (n <= 0) break;
    total += n;
  }
  lwip_close(sock);

  if (total > 0) {
    buf[total] = '\0';
    *out_len = (uint16_t)total;
    return true;
  }
  return false;
}

static void aggregator_poll_task(void* arg) {
  // Initialize caches — id/name/base_url point to static string literals (safe lifetime)
  for (int i = 0; i < MAX_SATELLITES; i++) {
    satellite_caches[i].id = SATELLITE_IDS[i];
    satellite_caches[i].name = SATELLITE_NAMES[i];
    satellite_caches[i].base_url = SATELLITE_URLS[i];
    satellite_caches[i].poll_interval_seconds = SATELLITE_POLL_INTERVALS[i];
    satellite_caches[i].clear_cache();
  }

  // Initial delay — wait for WiFi and local boot to settle
  vTaskDelay(pdMS_TO_TICKS(10000));

  while (true) {
    // Monotonic uptime for interval tracking — no SNTP dependency.
    // ::time(nullptr) returns 0 before SNTP sync, which breaks interval
    // math and backoff seeding (BUG-058). esp_timer_get_time() counts
    // from boot and is always nonzero after the 10s initial delay.
    uint32_t uptime_s = (uint32_t)(esp_timer_get_time() / 1000000ULL);
    // Wall-clock epoch — only for last_seen_epoch (API display).
    // May be 0 before SNTP sync; that's fine for display purposes.
    uint32_t epoch_now = (uint32_t)::time(nullptr);

    for (int i = 0; i < MAX_SATELLITES; i++) {
      SatelliteCache& sat = satellite_caches[i];
      // Back off unreachable satellites to 5-minute polling (saves CPU on C3)
      uint32_t effective_interval = sat.reachable
          ? (uint32_t)sat.poll_interval_seconds
          : 300;  // 5 min for unreachable
      bool any_failed = false;

      char url_buf[256];
      uint16_t tmp_len;

      // ── Fetch /api/v2/live (every poll_interval_seconds) ──
      bool live_due = (sat.last_live_fetch == 0) ||
                      (uptime_s - sat.last_live_fetch >= effective_interval);
      if (live_due) {
        snprintf(url_buf, sizeof(url_buf), "%s/api/v2/live", sat.base_url);
        tmp_len = 0;
        if (fetch_to_buffer(url_buf, s_fetch_tmp, (uint16_t)sizeof(sat.live_json), &tmp_len)
            && tmp_len > 0) {
          if (AGG_LOCK() == pdTRUE) {
            bool was_unreachable = !sat.reachable;
            memcpy(sat.live_json, s_fetch_tmp, tmp_len + 1);
            sat.live_len = tmp_len;
            sat.last_live_fetch = uptime_s;
            sat.reachable = true;
            sat.consecutive_failures = 0;
            sat.last_seen_epoch = epoch_now;
            AGG_UNLOCK();
            if (was_unreachable) {
              ESP_LOGI(TAG_AGG, "[%s] recovered (was unreachable)", sat.id);
            }
          }
          ESP_LOGI(TAG_AGG, "[%s] live: %u bytes", sat.id, (unsigned)tmp_len);
        } else {
          any_failed = true;
          ESP_LOGW(TAG_AGG, "[%s] live fetch failed", sat.id);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
      }

      // ── Fetch /api/status (every poll_interval_seconds) ──
      bool status_due = (sat.last_status_fetch == 0) ||
                        (uptime_s - sat.last_status_fetch >= effective_interval);
      if (status_due) {
        snprintf(url_buf, sizeof(url_buf), "%s/api/status", sat.base_url);
        tmp_len = 0;
        if (fetch_to_buffer(url_buf, s_fetch_tmp, (uint16_t)sizeof(sat.status_json), &tmp_len)
            && tmp_len > 0) {
          if (AGG_LOCK() == pdTRUE) {
            memcpy(sat.status_json, s_fetch_tmp, tmp_len + 1);
            sat.status_len = tmp_len;
            sat.last_status_fetch = uptime_s;
            AGG_UNLOCK();
          }
          ESP_LOGI(TAG_AGG, "[%s] status: %u bytes", sat.id, (unsigned)tmp_len);
        } else {
          any_failed = true;
          ESP_LOGW(TAG_AGG, "[%s] status fetch failed", sat.id);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
      }

      // ── Fetch /api/manifest (every 5 minutes) ──
      bool manifest_due = (sat.last_manifest_fetch == 0) ||
                          (uptime_s - sat.last_manifest_fetch >= 300);
      if (manifest_due) {
        snprintf(url_buf, sizeof(url_buf), "%s/api/manifest", sat.base_url);
        tmp_len = 0;
        if (fetch_to_buffer(url_buf, s_fetch_tmp, (uint16_t)sizeof(sat.manifest_json), &tmp_len)
            && tmp_len > 0) {
          if (AGG_LOCK() == pdTRUE) {
            memcpy(sat.manifest_json, s_fetch_tmp, tmp_len + 1);
            sat.manifest_len = tmp_len;
            sat.last_manifest_fetch = uptime_s;
            AGG_UNLOCK();
          }
          ESP_LOGI(TAG_AGG, "[%s] manifest: %u bytes", sat.id, (unsigned)tmp_len);
        } else {
          any_failed = true;
          ESP_LOGW(TAG_AGG, "[%s] manifest fetch failed", sat.id);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
      }

      // ── Update reachability after fetch failures ──
      if (any_failed) {
        uint8_t failures = 0;
        if (AGG_LOCK() == pdTRUE) {
          sat.consecutive_failures++;
          failures = sat.consecutive_failures;
          if (failures >= 3) {
            sat.reachable = false;
            // BUG-058: Seed timestamps for never-fetched endpoints so the
            // 300s backoff interval starts counting. Only after 3 failures
            // (satellite declared unreachable) — not on transient failures
            // which should retry at normal frequency to handle boot-order
            // races where the satellite comes up seconds after the aggregator.
            if (sat.last_live_fetch == 0)     sat.last_live_fetch = uptime_s;
            if (sat.last_status_fetch == 0)   sat.last_status_fetch = uptime_s;
            if (sat.last_manifest_fetch == 0) sat.last_manifest_fetch = uptime_s;
          }
          AGG_UNLOCK();
        }
        if (failures >= 3) {
          ESP_LOGW(TAG_AGG, "[%s] unreachable (failures=%u)",
                   sat.id, (unsigned)failures);
        }
      }

      // Stagger between satellites to avoid simultaneous connections
      if (i + 1 < MAX_SATELLITES) {
        vTaskDelay(pdMS_TO_TICKS(2000));
      }
    }

    // Sleep until next poll cycle
    vTaskDelay(pdMS_TO_TICKS(5000));
  }
}

static void start_aggregator_task() {
  init_aggregator_mutex();
  if (!s_cache_mutex) {
    ESP_LOGE(TAG_AGG, "Failed to create aggregator mutex");
    return;
  }
  xTaskCreate(aggregator_poll_task, "agg_poll", 10240, nullptr,
              tskIDLE_PRIORITY + 2, nullptr);
  ESP_LOGI(TAG_AGG, "Aggregator polling task started (%d satellites)", MAX_SATELLITES);
}

#endif  // AGGREGATOR_ENABLED


// ═══════════════════════════════════════════════════════════════════
// HistoryWebHandler — custom endpoints on ESPHome web server
// ═══════════════════════════════════════════════════════════════════

class HistoryWebHandler : public AsyncWebHandler {
 public:
  HistoryWebHandler(std::string username, std::string password, std::string version)
      : mgmt_username_(std::move(username)),
        mgmt_password_(std::move(password)),
        firmware_version_(std::move(version)) {}

  bool canHandle(AsyncWebServerRequest *request) const override {
    char url_buf[AsyncWebServerRequest::URL_BUF_SIZE];
    auto url = request->url_to(url_buf);
    const char *p = url.c_str();
    size_t len = url.size();
    if (len > 12 && strncmp(p, "/api/ingest/", 12) == 0) return true;

    if (request->method() == HTTP_GET) {
      if (len >= 11 && strncmp(p, "/history/", 9) == 0) return true;
      if (len == 13 && memcmp(p, "/sensors.json", 13) == 0) return true; if (strcmp(p, "/api/manifest") == 0) return true;
      if (strcmp(p, "/dashboard") == 0) return true;
      if (strcmp(p, "/dashboard.html") == 0) return true;
      if (strcmp(p, "/dashboard-download") == 0) return true;
      if (strcmp(p, "/api/storage-stats") == 0) return true;
      if (strcmp(p, "/api/status") == 0) return true;
      if (strcmp(p, "/api/v2/live") == 0) return true;
      if (len >= 20 && strncmp(p, "/api/v2/history/", 16) == 0) return true;
      if (strcmp(p, "/favicon.ico") == 0) return true;
#if AGGREGATOR_ENABLED
      if (strcmp(p, "/api/aggregator/gateways") == 0) return true;
      if (strcmp(p, "/api/aggregator/live") == 0) return true;
      if (len > 22 && strncmp(p, "/api/aggregator/proxy/", 22) == 0) return true;
#endif
      return false;
    }

    if (request->method() == HTTP_POST || request->method() == HTTP_OPTIONS) {
      if (strcmp(p, "/api/reboot") == 0) return true;
      if (strcmp(p, "/api/delete-data") == 0) return true;
      if (strcmp(p, "/api/import/begin") == 0) return true;
      if (strncmp(p, "/api/import/begin/single/", 25) == 0) return true;
      if (strncmp(p, "/api/import/d/", 14) == 0) return true;
      if (strncmp(p, "/api/import/w/", 14) == 0) return true;
      if (strcmp(p, "/api/import/finish") == 0) return true;
#if AGGREGATOR_ENABLED
      if (strncmp(p, "/api/aggregator/add-satellite", 29) == 0) return true;
      if (strncmp(p, "/api/aggregator/test-satellite", 30) == 0) return true;
#endif
      return false;
    }

#if AGGREGATOR_ENABLED
    if (request->method() == HTTP_DELETE) {
      if (strncmp(p, "/api/aggregator/satellite/", 26) == 0) return true;
    }
#endif

    return false;
  }

  void handleRequest(AsyncWebServerRequest *request) override {
    char url_buf[AsyncWebServerRequest::URL_BUF_SIZE];
    auto url = request->url_to(url_buf);
    const char *p = url.c_str();

    if (request->method() == HTTP_OPTIONS) {
      handle_options_(request);
      return;
    }

    if (strncmp(p, "/api/ingest/", 12) == 0) {
      handle_api_ingest_(request);
      return;
    }

    if (request->method() == HTTP_POST) {
      if (strcmp(p, "/api/reboot") == 0) {
        handle_reboot_(request);
        return;
      }
      if (strcmp(p, "/api/delete-data") == 0) {
        handle_delete_data_(request);
        return;
      }
      if (strcmp(p, "/api/import/begin") == 0) {
        handle_import_begin_(request, false, -1);
        return;
      }
      if (strncmp(p, "/api/import/begin/single/", 25) == 0) {
        const char *sid = p + 25;
        int idx = resolve_import_sensor_index_(sid);
        if (idx < 0) {
          send_json_error_(request, 400, "Unknown sensor ID in import path");
          return;
        }
        handle_import_begin_(request, true, idx);
        return;
      }
      if (strncmp(p, "/api/import/d/", 14) == 0) {
        handle_import_data_(request, p + 14, false);
        return;
      }
      if (strncmp(p, "/api/import/w/", 14) == 0) {
        handle_import_data_(request, p + 14, true);
        return;
      }
      if (strcmp(p, "/api/import/finish") == 0) {
        handle_import_finish_(request);
        return;
      }
#if AGGREGATOR_ENABLED
      if (strncmp(p, "/api/aggregator/add-satellite", 29) == 0) {
        handle_aggregator_stub_501_(request);
        return;
      }
      if (strncmp(p, "/api/aggregator/test-satellite", 30) == 0) {
        handle_aggregator_stub_501_(request);
        return;
      }
#endif
      request->send(404);
      return;
    }

#if AGGREGATOR_ENABLED
    if (request->method() == HTTP_DELETE) {
      if (strncmp(p, "/api/aggregator/satellite/", 26) == 0) {
        handle_aggregator_stub_501_(request);
        return;
      }
      request->send(404);
      return;
    }
#endif
    if (strcmp(p, "/favicon.ico") == 0) {
      request->send(204);
      return;
    }
    if (strcmp(p, "/dashboard") == 0 || strcmp(p, "/dashboard.html") == 0) {
      handle_dashboard_(request, false);
      return;
    }
    if (strcmp(p, "/dashboard-download") == 0) {
      handle_dashboard_(request, true);
      return;
    }
    if (strcmp(p, "/api/storage-stats") == 0) {
      handle_storage_stats_(request);
      return;
    }
    if (strcmp(p, "/api/status") == 0) {
      handle_status_(request);
      return;
    } if (strcmp(p, "/api/manifest") == 0) { handle_api_manifest_(request); return; }
    if (strcmp(p, "/api/v2/live") == 0) {
      handle_api_v2_live_(request);
      return;
    }
    if (strncmp(p, "/api/v2/history/", 16) == 0) {
      handle_api_v2_history_(request, p + 16);
      return;
    }
#if AGGREGATOR_ENABLED
    if (strcmp(p, "/api/aggregator/gateways") == 0) {
      handle_aggregator_gateways_(request);
      return;
    }
    if (strcmp(p, "/api/aggregator/live") == 0) {
      handle_aggregator_live_(request);
      return;
    }
    if (strncmp(p, "/api/aggregator/proxy/", 22) == 0) {
      handle_aggregator_proxy_(request, p + 22);
      return;
    }
#endif
    if (strcmp(p, "/sensors.json") == 0) {
      handle_manifest_(request);
      return;
    }
    if (strncmp(p, "/history/", 9) == 0) {
      handle_history_(request, p + 9);
      return;
    }

    request->send(404);
  }

 private:
  std::string mgmt_username_;
  std::string mgmt_password_;
  std::string firmware_version_;
  mutable uint8_t failed_auth_count_{0};
  mutable int64_t lockout_until_ms_{0};

  // ── Import state ──────────────────────────────────────────────
  mutable bool import_active_{false};
  mutable uint16_t import_segments_written_{0};
  mutable HistoryMeta import_meta_;
  mutable SegmentSnapshot *import_snapshot_{nullptr};

  // ── Single-sensor import state ────────────────────────────────
  mutable bool import_single_mode_{false};
  mutable int import_target_sensor_{-1};
  struct EpochSlotEntry { uint32_t hour_epoch; uint16_t slot; };
  mutable EpochSlotEntry *import_epoch_map_{nullptr};
  mutable uint16_t import_epoch_map_size_{0};

  static int64_t now_ms_() {
    return esp_timer_get_time() / 1000;
  }

  static std::string trim_copy_(const std::string &input) {
    size_t start = 0;
    while (start < input.size() && std::isspace(static_cast<unsigned char>(input[start]))) start++;
    size_t end = input.size();
    while (end > start && std::isspace(static_cast<unsigned char>(input[end - 1]))) end--;
    return input.substr(start, end - start);
  }

  static int base64_value_(unsigned char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
  }

  static bool base64_decode_(const std::string &input, std::string *output) {
    if (output == nullptr) return false;
    output->clear();
    int value = 0;
    int bits = -8;
    for (unsigned char c : input) {
      if (std::isspace(c)) continue;
      if (c == '=') break;
      int decoded = base64_value_(c);
      if (decoded < 0) return false;
      value = (value << 6) | decoded;
      bits += 6;
      if (bits >= 0) {
        output->push_back(static_cast<char>((value >> bits) & 0xFF));
        bits -= 8;
      }
    }
    return true;
  }

  static bool secure_equals_(const std::string &a, const std::string &b) {
    size_t max_len = a.size() > b.size() ? a.size() : b.size();
    unsigned char diff = static_cast<unsigned char>(a.size() ^ b.size());
    for (size_t i = 0; i < max_len; i++) {
      unsigned char ac = i < a.size() ? static_cast<unsigned char>(a[i]) : 0;
      unsigned char bc = i < b.size() ? static_cast<unsigned char>(b[i]) : 0;
      diff |= static_cast<unsigned char>(ac ^ bc);
    }
    return diff == 0;
  }

  void add_common_headers_(AsyncWebServerResponse *resp) const {
    resp->addHeader("Cache-Control", "no-store");
    resp->addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    resp->addHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  }

  void send_json_error_(AsyncWebServerRequest *request, int status_code,
                        const char *message,
                        uint32_t retry_after_sec = 0) const {
    char body[192];
    snprintf(body, sizeof(body),
             "{\"ok\":false,\"message\":\"%s\",\"status\":%d}",
             message, status_code);
    auto *resp = request->beginResponse(status_code, "application/json", std::string(body));
    add_common_headers_(resp);
    if (status_code == 401) {
      resp->addHeader("WWW-Authenticate", "Basic realm=\"ESP32 Gateway Management\"");
    }
    if (retry_after_sec > 0) {
      char retry_after_buf[16];
      snprintf(retry_after_buf, sizeof(retry_after_buf), "%u", static_cast<unsigned>(retry_after_sec));
      resp->addHeader("Retry-After", retry_after_buf);
    }
    request->send(resp);
  }

  bool extract_basic_auth_(AsyncWebServerRequest *request,
                           std::string *username,
                           std::string *password) const {
    auto header = request->get_header("Authorization");
    if (!header.has_value()) return false;
    std::string auth = trim_copy_(header.value());
    if (auth.size() < 6) return false;
    if (!(auth.rfind("Basic ", 0) == 0 || auth.rfind("basic ", 0) == 0)) return false;
    std::string encoded = trim_copy_(auth.substr(6));
    std::string decoded;
    if (!base64_decode_(encoded, &decoded)) return false;
    size_t sep = decoded.find(':');
    if (sep == std::string::npos) return false;
    if (username != nullptr) *username = decoded.substr(0, sep);
    if (password != nullptr) *password = decoded.substr(sep + 1);
    return true;
  }

  bool authenticate_management_(AsyncWebServerRequest *request) const {
    int64_t now = now_ms_();
    if (lockout_until_ms_ > now) {
      uint32_t retry_after = static_cast<uint32_t>((lockout_until_ms_ - now + 999) / 1000);
      send_json_error_(request, 429, "Too many failed authentication attempts", retry_after);
      return false;
    }

    std::string username;
    std::string password;
    if (!extract_basic_auth_(request, &username, &password)) {
      send_json_error_(request, 401, "Management authentication required");
      return false;
    }

    bool ok = secure_equals_(username, mgmt_username_) && secure_equals_(password, mgmt_password_);
    if (!ok) {
      vTaskDelay(pdMS_TO_TICKS(AUTH_FAILURE_DELAY_MS));
      failed_auth_count_++;
      if (failed_auth_count_ >= AUTH_MAX_FAILURES) {
        failed_auth_count_ = 0;
        lockout_until_ms_ = now_ms_() + AUTH_LOCKOUT_MS;
        send_json_error_(request, 429, "Too many failed authentication attempts", AUTH_LOCKOUT_MS / 1000);
      } else {
        send_json_error_(request, 401, "Authentication failed");
      }
      return false;
    }

    failed_auth_count_ = 0;
    lockout_until_ms_ = 0;
    return true;
  }

  void handle_options_(AsyncWebServerRequest *request) const {
    auto *resp = request->beginResponse(204, "text/plain");
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_dashboard_(AsyncWebServerRequest *request,
                         bool as_attachment) const {
    // BUG-043 fix: serve gzip-compressed dashboard (~45KB vs ~190KB raw).
    // Reduces HTTP task blocking from 2-4s to <1s, eliminating the primary
    // crash trigger on ESP32-C3.  Content-Encoding: gzip tells the browser
    // to decompress transparently — both viewing and "Save As" work correctly.
    auto *resp = request->beginResponse(
        200, "text/html; charset=utf-8", DASHBOARD_HTML_GZ, DASHBOARD_HTML_GZ_LEN);

    resp->addHeader("Cache-Control", "no-store");
    resp->addHeader("Content-Encoding", "gzip");
    if (as_attachment) {
      resp->addHeader("Content-Disposition",
                      "attachment; filename=\"dashboard.html\"");
    }
    request->send(resp);
  }

  void handle_manifest_(AsyncWebServerRequest *request) const {
    auto *resp = request->beginResponseStream("application/json");
    resp->addHeader("Cache-Control", "no-store");
    resp->print("[");
    bool first = true;
    for (int i = 0; i < NUM_DEVICES; i++) {
      if (devices[i].category_id != 0) continue;  // v1 projection: environmental only
      if (!first) resp->print(",");
      first = false;
      char entry[96];
      snprintf(entry, sizeof(entry),
               "{\"id\":\"%s\",\"name\":\"%s\"}",
               devices[i].id, devices[i].name);
      resp->print(entry);
    }
    resp->print("]");
    request->send(resp);
  } void handle_api_manifest_(AsyncWebServerRequest *request) const { auto *resp = request->beginResponseStream("application/json"); add_common_headers_(resp); resp->print(GATEWAY_MANIFEST_JSON); request->send(resp); }

  void handle_api_v2_live_(AsyncWebServerRequest *request) const {
    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    resp->print("{\"timestamp\":");
    resp->print((unsigned long)::time(nullptr));
    resp->print(",\"devices\":{");
    for (int d = 0; d < NUM_DEVICES; d++) {
      if (d > 0) resp->print(",");
      resp->printf("\"%s\":{", devices[d].id);
      for (int m = 0; m < devices[d].metric_count; m++) {
        if (m > 0) resp->print(",");
        resp->printf("\"%s\":", devices[d].metric_defs[m].key);
        if (devices[d].metric_states[m].valid) {
          resp->printf("%.1f", devices[d].metric_states[m].current_value);
        } else {
          resp->print("null");
        }
      }
      resp->printf(",\"last_seen\":%lu", (unsigned long)devices[d].last_seen_epoch);
      resp->print("}");
    }
    resp->print("}}");
    request->send(resp);
  }

  void handle_api_v2_history_(AsyncWebServerRequest *request, const char *rest) const {
    // Parse: rest = "device_id/metric_key"
    const char *slash = strchr(rest, '/');
    if (slash == nullptr) {
      request->send(404);
      return;
    }

    size_t id_len = slash - rest;
    const char *metric_key = slash + 1;

    // Look up device by id
    int dev_idx = -1;
    for (int d = 0; d < NUM_DEVICES; d++) {
      if (strlen(devices[d].id) == id_len &&
          strncmp(devices[d].id, rest, id_len) == 0) {
        dev_idx = d;
        break;
      }
    }
    if (dev_idx < 0) {
      request->send(404);
      return;
    }

    // Find metric index by matching metric_defs[].key
    int metric_idx = -1;
    for (int m = 0; m < devices[dev_idx].metric_count; m++) {
      if (strcmp(devices[dev_idx].metric_defs[m].key, metric_key) == 0) {
        metric_idx = m;
        break;
      }
    }
    if (metric_idx < 0) {
      request->send(404);
      return;
    }

    // Check history_enabled and history buffer
    if (!devices[dev_idx].metric_defs[metric_idx].history_enabled ||
        devices[dev_idx].metric_states[metric_idx].history == nullptr) {
      request->send(404);
      return;
    }

    HistoryBuffer *buf = devices[dev_idx].metric_states[metric_idx].history;

    // Use pre-reserved string pattern (LESSON-OPS-056)
    std::string csv;
    csv.reserve(buf->count() * 20 + 64);
    buf->append_csv_to(csv);

    auto *resp = request->beginResponse(
        200, "text/plain",
        reinterpret_cast<const uint8_t *>(csv.data()), csv.size());
    resp->addHeader("Cache-Control", "no-store");
    request->send(resp);
  }

  void handle_api_ingest_(AsyncWebServerRequest *request) const {
    if (request->method() != HTTP_POST) {
      send_json_error_(request, 405, "Method not allowed");
      return;
    }

    char url_buf[AsyncWebServerRequest::URL_BUF_SIZE];
    auto url = request->url_to(url_buf);
    const char *p = url.c_str();
    const char *rest = p + 12;  // "/api/ingest/"
    const char *slash = strchr(rest, '/');
    if (!slash) {
      send_json_error_(request, 400, "Missing metric key");
      return;
    }

    size_t id_len = static_cast<size_t>(slash - rest);
    const char *metric_key = slash + 1;

    int dev_idx = -1;
    for (int d = 0; d < NUM_DEVICES; d++) {
      if (strlen(devices[d].id) == id_len &&
          strncmp(devices[d].id, rest, id_len) == 0) {
        dev_idx = d;
        break;
      }
    }
    if (dev_idx < 0) {
      send_json_error_(request, 404, "Unknown device");
      return;
    }

    int metric_idx = -1;
    for (int m = 0; m < devices[dev_idx].metric_count; m++) {
      if (strcmp(devices[dev_idx].metric_defs[m].key, metric_key) == 0) {
        metric_idx = m;
        break;
      }
    }
    if (metric_idx < 0) {
      send_json_error_(request, 404, "Unknown metric");
      return;
    }

    if (!request->hasParam("val")) {
      send_json_error_(request, 400, "Missing val parameter");
      return;
    }
    String val_str = request->getParam("val")->value();
    char *endptr = nullptr;
    float value = strtof(val_str.c_str(), &endptr);
    if (endptr == val_str.c_str() || *endptr != '\0' || !std::isfinite(value)) {
      send_json_error_(request, 400, "Invalid value");
      return;
    }

    devices[dev_idx].add_sample(metric_idx, value);
    devices[dev_idx].mark_seen(::time(nullptr));

    auto *resp = request->beginResponse(200, "application/json", "{\"ok\":true}");
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_reboot_(AsyncWebServerRequest *request) const {
    if (!authenticate_management_(request)) return;
    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    resp->print("{\"ok\":true,\"message\":\"Reboot scheduled\"}");
    request->send(resp);
    schedule_reboot_();
  }

  void handle_delete_data_(AsyncWebServerRequest *request) const {
    if (!authenticate_management_(request)) return;
    bool ok = clear_persisted_history_();
    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    if (ok) {
      resp->print("{\"ok\":true,\"message\":\"Persisted and RAM history cleared\"}");
    } else {
      resp->print("{\"ok\":false,\"message\":\"Failed to clear history\"}");
    }
    request->send(resp);
  }


  // ── Import v1/v2 handlers ──────────────────────────────────────
  //
  //   POST /api/import/begin                  — multi: clear history, allocate buffer
  //   POST /api/import/begin/single/<sensor>  — single: build epoch map, allocate buffer (no erase)
  //   POST /api/import/d/<data>               — add data points (no NVS write)
  //   POST /api/import/w/<data>               — add data points AND write segment to NVS
  //   POST /api/import/finish                 — finalize metadata, restore RAM, free buffers
  //
  //   Data is encoded in the URL path as semicolon-delimited lines:
  //     sensor_id,series,epoch,value  (series is "temp" or "hum")
  //   The URL path is always preserved by all proxies including Cloudflare.
  //   /d/ adds data to the in-memory snapshot without writing.
  //   /w/ adds data then commits the snapshot to NVS (use for last batch of each segment).
  //
  //   Multi-sensor mode: erases all history, writes new segments sequentially.
  //   Single-sensor mode: preserves other sensors' data, merges into existing
  //   segments where they share the same hour epoch, creates new segments otherwise.

  int resolve_import_sensor_index_(const char *sensor_id) const {
    if (sensor_id == nullptr || sensor_id[0] == '\0') return -1;
    for (int i = 0; i < NUM_DEVICES; i++) {
      if (strcmp(devices[i].id, sensor_id) == 0) return i;
    }
    return -1;
  }

  int find_epoch_slot_(uint32_t hour_epoch) const {
    for (int i = 0; i < import_epoch_map_size_; i++) {
      if (import_epoch_map_[i].hour_epoch == hour_epoch) return (int) import_epoch_map_[i].slot;
    }
    return -1;
  }

  uint32_t get_snapshot_hour_epoch_(int sensor_idx) const {
    if (import_snapshot_ == nullptr || sensor_idx < 0) return 0;
    uint32_t min_epoch = UINT32_MAX;
    for (int n = 0; n < import_snapshot_->temp_counts[sensor_idx]; n++) {
      uint32_t e = import_snapshot_->temp[sensor_idx][n].epoch;
      if (e > 0 && e < min_epoch) min_epoch = e;
    }
    for (int n = 0; n < import_snapshot_->hum_counts[sensor_idx]; n++) {
      uint32_t e = import_snapshot_->hum[sensor_idx][n].epoch;
      if (e > 0 && e < min_epoch) min_epoch = e;
    }
    return (min_epoch == UINT32_MAX) ? 0 : (min_epoch - (min_epoch % 3600));
  }

  // Recalculate snapshot header first/last epoch from all sensor data.
  void recalculate_snapshot_epochs_(SegmentSnapshot *snap) const {
    uint32_t first = UINT32_MAX, last = 0;
    for (int i = 0; i < NUM_SENSORS; i++) {
      for (int n = 0; n < snap->temp_counts[i]; n++) {
        uint32_t e = snap->temp[i][n].epoch;
        if (e > 0 && e < first) first = e;
        if (e > last) last = e;
      }
      for (int n = 0; n < snap->hum_counts[i]; n++) {
        uint32_t e = snap->hum[i][n].epoch;
        if (e > 0 && e < first) first = e;
        if (e > last) last = e;
      }
    }
    snap->header.first_epoch = (first == UINT32_MAX) ? 0 : first;
    snap->header.last_epoch = last;
  }

  bool build_import_epoch_map_() {
    import_epoch_map_ = new (std::nothrow) EpochSlotEntry[PERSIST_SLOTS];
    if (import_epoch_map_ == nullptr) {
      ESP_LOGE(TAG, "Failed to allocate epoch-to-slot map (%u bytes)",
               (unsigned)(PERSIST_SLOTS * sizeof(EpochSlotEntry)));
      return false;
    }
    import_epoch_map_size_ = 0;

    nvs_handle_t handle;
    if (!open_history_nvs_(&handle, NVS_READONLY)) {
      delete[] import_epoch_map_;
      import_epoch_map_ = nullptr;
      return false;
    }

    HistoryMeta meta;
    if (!load_history_meta_(handle, &meta) || meta.valid_segments == 0) {
      nvs_close(handle);
      import_meta_ = meta;  // Use existing (possibly empty) meta as starting point.
      return true;
    }

    import_meta_ = meta;

    SegmentSnapshot *temp = allocate_snapshot_();
    if (temp == nullptr) {
      nvs_close(handle);
      return false;
    }

    int oldest_slot = (meta.next_slot + PERSIST_SLOTS - meta.valid_segments) % PERSIST_SLOTS;
    for (int i = 0; i < meta.valid_segments; i++) {
      maybe_yield_nvs_scan_(i);  // BUG-043: yield every 4 blobs to avoid HTTP task starvation
      int slot = (oldest_slot + i) % PERSIST_SLOTS;
      if (load_snapshot_from_handle_(handle, slot, temp)) {
        uint32_t hour_epoch = 0;
        if (temp->header.first_epoch > 0) {
          hour_epoch = temp->header.first_epoch - (temp->header.first_epoch % 3600);
        }
        if (hour_epoch > 0 && import_epoch_map_size_ < PERSIST_SLOTS) {
          import_epoch_map_[import_epoch_map_size_].hour_epoch = hour_epoch;
          import_epoch_map_[import_epoch_map_size_].slot = (uint16_t) slot;
          import_epoch_map_size_++;
        }
      }
    }

    delete temp;
    nvs_close(handle);
    ESP_LOGI(TAG, "Built epoch map: %u entries from %u valid segments",
             (unsigned) import_epoch_map_size_, (unsigned) meta.valid_segments);
    return true;
  }

  void cleanup_import_state_() {
    import_active_ = false;
    import_single_mode_ = false;
    import_target_sensor_ = -1;
    if (import_snapshot_ != nullptr) {
      delete import_snapshot_;
      import_snapshot_ = nullptr;
    }
    if (import_epoch_map_ != nullptr) {
      delete[] import_epoch_map_;
      import_epoch_map_ = nullptr;
    }
    import_epoch_map_size_ = 0;
  }

  void finalize_import_snapshot_header_(uint32_t now_epoch) {
    if (import_snapshot_ == nullptr) return;
    recalculate_snapshot_epochs_(import_snapshot_);
    import_snapshot_->header.magic = HISTORY_META_MAGIC;
    import_snapshot_->header.version = HISTORY_META_VERSION;
    import_snapshot_->header.num_sensors = NUM_SENSORS;
    import_snapshot_->header.points_per_series = HISTORY_POINTS_PER_SERIES;
    import_snapshot_->header.points_per_segment = PERSIST_POINTS_PER_SEGMENT;
    import_snapshot_->header.saved_at_epoch = now_epoch > 0 ? now_epoch
        : import_snapshot_->header.last_epoch;
  }

  void handle_import_begin_(AsyncWebServerRequest *request,
                            bool single_mode, int target_sensor) {
    if (!authenticate_management_(request)) return;

    // Clean up any leftover import state.
    cleanup_import_state_();

    import_single_mode_ = single_mode;
    import_target_sensor_ = target_sensor;

    if (single_mode) {
      // Single-sensor mode: do NOT erase. Build epoch-to-slot map.
      if (!build_import_epoch_map_()) {
        cleanup_import_state_();
        send_json_error_(request, 500, "Failed to build segment index for merge");
        return;
      }
    } else {
      // Multi-sensor mode: erase all history (original behavior).
      bool ok = clear_persisted_history_();
      if (!ok) {
        send_json_error_(request, 500, "Failed to clear history partition");
        return;
      }
      import_meta_ = default_history_meta_();
    }

    import_snapshot_ = allocate_snapshot_();
    if (import_snapshot_ == nullptr) {
      cleanup_import_state_();
      send_json_error_(request, 500, "Failed to allocate import buffer");
      return;
    }
    std::memset(import_snapshot_, 0, sizeof(SegmentSnapshot));

    import_active_ = true;
    import_segments_written_ = 0;

    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    if (single_mode) {
      char msg[128];
      snprintf(msg, sizeof(msg),
               "{\"ok\":true,\"mode\":\"single\",\"sensor\":\"%s\","
               "\"existing_segments\":%u,\"message\":\"Ready for single-sensor import\"}",
               devices[target_sensor].id, (unsigned) import_epoch_map_size_);
      resp->print(msg);
      ESP_LOGI(TAG, "Import begun (single-sensor: %s) — %u existing segments indexed",
               devices[target_sensor].id, (unsigned) import_epoch_map_size_);
    } else {
      resp->print("{\"ok\":true,\"mode\":\"multi\",\"message\":\"History cleared, ready for import\"}");
      ESP_LOGI(TAG, "Import begun (multi) — history partition cleared");
    }
    request->send(resp);
  }

  void handle_import_data_(AsyncWebServerRequest *request,
                           const char *path_data, bool do_write) {
    if (!authenticate_management_(request)) return;

    if (!import_active_ || import_snapshot_ == nullptr) {
      send_json_error_(request, 409, "No import in progress. Call /api/import/begin first.");
      return;
    }

    if (path_data == nullptr || path_data[0] == '\0') {
      send_json_error_(request, 400, "No data in URL path");
      return;
    }

    const char *d_param = path_data;

    // Get current epoch for validation.
    uint32_t now_epoch = 0;
    {
      time_t t = ::time(nullptr);
      if (t > 1700000000) now_epoch = (uint32_t) t;
    }

    int accepted = 0;
    int rejected = 0;

    // Parse semicolon-delimited data lines from header.
    // Each line: sensor_id,series,epoch,value
    const char *pos = d_param;
    while (pos != nullptr && *pos != '\0') {
      // Extract one line (until ; or end).
      char line[80] = {};
      const char *sep = pos;
      while (*sep != '\0' && *sep != ';') sep++;
      size_t line_len = sep - pos;
      if (line_len >= sizeof(line)) line_len = sizeof(line) - 1;
      std::memcpy(line, pos, line_len);
      line[line_len] = '\0';

      // Advance past separator.
      if (*sep == ';') pos = sep + 1;
      else pos = sep;  // Stop at end.

      // Skip empty lines.
      if (line[0] == '\0') continue;

      // Parse: sensor_id,series,epoch,value
      char sid[32] = {};
      char ser[8] = {};
      unsigned int epoch = 0;
      float value = 0.0f;
      int parsed = sscanf(line, "%31[^,],%7[^,],%u,%f", sid, ser, &epoch, &value);

      if (parsed < 3) { rejected++; continue; }

      // Resolve sensor index.
      int sensor_idx = -1;
      for (int i = 0; i < NUM_DEVICES; i++) {
        if (strcmp(devices[i].id, sid) == 0) { sensor_idx = i; break; }
      }
      if (sensor_idx < 0) { rejected++; continue; }

      // Validate epoch.
      if (epoch == 0 || (now_epoch > 0 && epoch > now_epoch + 86400)) {
        rejected++; continue;
      }

      // Determine series.
      bool is_temp = (strcmp(ser, "temp") == 0);
      bool is_hum = (strcmp(ser, "hum") == 0);
      if (!is_temp && !is_hum) { rejected++; continue; }

      // Validate value ranges.
      if (parsed >= 4) {
        if (is_temp && (value < -50.0f || value > 80.0f)) { rejected++; continue; }
        if (is_hum && (value < 0.0f || value > 100.0f)) { rejected++; continue; }
      }

      // Place into snapshot.
      float store_value = (parsed >= 4) ? value : NAN;
      if (is_temp) {
        int idx = import_snapshot_->temp_counts[sensor_idx];
        if (idx < PERSIST_POINTS_PER_SEGMENT) {
          import_snapshot_->temp[sensor_idx][idx] = {epoch, store_value};
          import_snapshot_->temp_counts[sensor_idx]++;
          accepted++;
        } else { rejected++; }
      } else {
        int idx = import_snapshot_->hum_counts[sensor_idx];
        if (idx < PERSIST_POINTS_PER_SEGMENT) {
          import_snapshot_->hum[sensor_idx][idx] = {epoch, store_value};
          import_snapshot_->hum_counts[sensor_idx]++;
          accepted++;
        } else { rejected++; }
      }
    }

    // If write flag is set, commit this snapshot to NVS.
    int slot_written = -1;
    if (do_write && accepted > 0) {

      if (import_single_mode_ && import_target_sensor_ >= 0) {
        // ── Single-sensor merge write ──
        uint32_t hour_epoch = get_snapshot_hour_epoch_(import_target_sensor_);
        int existing_slot = (hour_epoch > 0) ? find_epoch_slot_(hour_epoch) : -1;

        nvs_handle_t handle;
        if (open_history_nvs_(&handle, NVS_READWRITE)) {
          if (existing_slot >= 0) {
            // Merge into existing segment: read, overlay target sensor, write back.
            SegmentSnapshot *existing = allocate_snapshot_();
            if (existing != nullptr) {
              if (load_snapshot_from_handle_(handle, existing_slot, existing)) {
                int si = import_target_sensor_;
                existing->temp_counts[si] = import_snapshot_->temp_counts[si];
                existing->hum_counts[si] = import_snapshot_->hum_counts[si];
                std::memcpy(existing->temp[si], import_snapshot_->temp[si],
                            sizeof(existing->temp[si]));
                std::memcpy(existing->hum[si], import_snapshot_->hum[si],
                            sizeof(existing->hum[si]));
                recalculate_snapshot_epochs_(existing);
                existing->header.saved_at_epoch = now_epoch > 0 ? now_epoch
                    : existing->header.last_epoch;

                char key[12];
                make_segment_key_(existing_slot, key, sizeof(key));
                esp_err_t err = nvs_set_blob(handle, key, existing, sizeof(*existing));
                if (err == ESP_OK) {
                  nvs_commit(handle);
                  import_segments_written_++;
                  slot_written = existing_slot;
                  if (existing->header.last_epoch > import_meta_.last_persist_epoch) {
                    import_meta_.last_persist_epoch = existing->header.last_epoch;
                  }
                }
              }
              delete existing;
            }
          } else {
            // New segment — no existing data at this hour. Write to next_slot.
            finalize_import_snapshot_header_(now_epoch);
            int slot = import_meta_.next_slot % PERSIST_SLOTS;
            char key[12];
            make_segment_key_(slot, key, sizeof(key));
            esp_err_t err = nvs_set_blob(handle, key, import_snapshot_,
                                          sizeof(*import_snapshot_));
            if (err == ESP_OK) {
              nvs_commit(handle);
              import_meta_.last_written_slot = slot;
              import_meta_.next_slot = (slot + 1) % PERSIST_SLOTS;
              if (import_meta_.valid_segments < PERSIST_SLOTS) import_meta_.valid_segments++;
              import_meta_.last_persist_epoch = import_snapshot_->header.last_epoch;
              import_segments_written_++;
              slot_written = slot;
              // Add to epoch map so subsequent segments at this hour can merge.
              if (hour_epoch > 0 && import_epoch_map_ != nullptr
                  && import_epoch_map_size_ < PERSIST_SLOTS) {
                import_epoch_map_[import_epoch_map_size_].hour_epoch = hour_epoch;
                import_epoch_map_[import_epoch_map_size_].slot = (uint16_t) slot;
                import_epoch_map_size_++;
              }
            }
          }
          nvs_close(handle);
        }

      } else {
        // ── Multi-sensor write (original behavior) ──
        finalize_import_snapshot_header_(now_epoch);

        nvs_handle_t handle;
        if (open_history_nvs_(&handle, NVS_READWRITE)) {
          int slot = import_meta_.next_slot % PERSIST_SLOTS;
          char key[12];
          make_segment_key_(slot, key, sizeof(key));

          esp_err_t err = nvs_set_blob(handle, key, import_snapshot_,
                                        sizeof(*import_snapshot_));
          if (err == ESP_OK) {
            nvs_commit(handle);
            import_meta_.last_written_slot = slot;
            import_meta_.next_slot = (slot + 1) % PERSIST_SLOTS;
            if (import_meta_.valid_segments < PERSIST_SLOTS) import_meta_.valid_segments++;
            import_meta_.last_persist_epoch = import_snapshot_->header.last_epoch;
            import_segments_written_++;
            slot_written = slot;
          }
          nvs_close(handle);
        }
      }

      // Clear snapshot for next segment.
      std::memset(import_snapshot_, 0, sizeof(SegmentSnapshot));
    }

    // Send response.
    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    char num[64];
    resp->print("{\"ok\":true,");
    snprintf(num, sizeof(num), "\"accepted\":%d,\"rejected\":%d", accepted, rejected);
    resp->print(num);
    if (slot_written >= 0) {
      snprintf(num, sizeof(num), ",\"slot\":%d", slot_written);
      resp->print(num);
    }
    resp->print("}");
    request->send(resp);
  }

  void handle_import_finish_(AsyncWebServerRequest *request) {
    if (!authenticate_management_(request)) return;

    if (!import_active_) {
      send_json_error_(request, 409, "No import in progress");
      return;
    }

    uint16_t segs = import_segments_written_;
    bool was_single = import_single_mode_;

    // Free working buffers (snapshot, epoch map).
    if (import_snapshot_ != nullptr) {
      delete import_snapshot_;
      import_snapshot_ = nullptr;
    }
    if (import_epoch_map_ != nullptr) {
      delete[] import_epoch_map_;
      import_epoch_map_ = nullptr;
    }
    import_epoch_map_size_ = 0;

    if (segs == 0) {
      import_active_ = false;
      import_single_mode_ = false;
      import_target_sensor_ = -1;
      auto *resp = request->beginResponseStream("application/json");
      add_common_headers_(resp);
      resp->print("{\"ok\":true,\"segments_written\":0,\"message\":\"Import finished with no segments\"}");
      request->send(resp);
      return;
    }

    // Save the accumulated metadata to NVS.
    nvs_handle_t handle;
    if (!open_history_nvs_(&handle, NVS_READWRITE)) {
      import_active_ = false;
      import_single_mode_ = false;
      import_target_sensor_ = -1;
      send_json_error_(request, 500, "Failed to open NVS to finalize metadata");
      return;
    }
    bool meta_ok = save_history_meta_(handle, import_meta_);
    nvs_close(handle);

    if (!meta_ok) {
      import_active_ = false;
      import_single_mode_ = false;
      import_target_sensor_ = -1;
      send_json_error_(request, 500, "Failed to write import metadata");
      return;
    }

    // Restore newest segments into RAM so charts work immediately.
    restore_from_nvs();

    import_active_ = false;
    import_single_mode_ = false;
    import_target_sensor_ = -1;

    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    char num[64];
    resp->print("{\"ok\":true,");
    snprintf(num, sizeof(num), "\"segments_written\":%u,", (unsigned) segs);
    resp->print(num);
    if (was_single) {
      resp->print("\"mode\":\"single\",");
    }
    resp->print("\"message\":\"Import complete, history restored to RAM\"}");
    request->send(resp);
    ESP_LOGI(TAG, "Import finished (%s) — %u segments written, RAM restored",
             was_single ? "single-sensor merge" : "multi-sensor replace",
             (unsigned) segs);
  }


  void handle_storage_stats_(AsyncWebServerRequest *request) const {
    uint32_t nvs_size = find_partition_size_bytes_(
        "nvs", ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_NVS);
    uint32_t otadata_size = find_partition_size_bytes_(
        "otadata", ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_OTA);
    uint32_t phy_size = find_partition_size_bytes_(
        "phy_init", ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_PHY);
    uint32_t ota0_size = find_partition_size_bytes_(
        "ota_0", ESP_PARTITION_TYPE_APP, ESP_PARTITION_SUBTYPE_APP_OTA_0);
    uint32_t ota1_size = find_partition_size_bytes_(
        "ota_1", ESP_PARTITION_TYPE_APP, ESP_PARTITION_SUBTYPE_APP_OTA_1);
    uint32_t history_size = find_partition_size_bytes_(
        HISTORY_PARTITION_LABEL, ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_NVS);
    uint32_t coredump_size = find_partition_size_bytes_(
        "coredump", ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_COREDUMP);

    HistoryMeta meta = default_history_meta_();
    bool namespace_initialized = false;
    nvs_handle_t handle;
    if (open_history_nvs_(&handle, NVS_READONLY)) {
      namespace_initialized = true;
      load_history_meta_(handle, &meta);
      nvs_close(handle);
    }

    nvs_stats_t nvs_stats{};
    esp_err_t nvs_stats_err = nvs_get_stats(HISTORY_PARTITION_LABEL, &nvs_stats);
    bool nvs_stats_ok = (nvs_stats_err == ESP_OK);

    uint32_t segment_size = (uint32_t) sizeof(SegmentSnapshot);
    uint32_t payload_bytes = (uint32_t) meta.valid_segments * segment_size;
    uint32_t payload_free_bytes =
        history_size > payload_bytes ? (history_size - payload_bytes) : 0;

    auto *resp = request->beginResponseStream("application/json");
    resp->addHeader("Cache-Control", "no-store");

    char num[160];
    resp->print("{\"ok\":true,\"layout\":{");

    snprintf(num, sizeof(num),
             "\"nvs_bytes\":%u,\"otadata_bytes\":%u,\"phy_init_bytes\":%u,",
             (unsigned) nvs_size,
             (unsigned) otadata_size,
             (unsigned) phy_size);
    resp->print(num);

    snprintf(num, sizeof(num),
             "\"ota_0_bytes\":%u,\"ota_1_bytes\":%u,\"history_bytes\":%u,\"coredump_bytes\":%u},",
             (unsigned) ota0_size,
             (unsigned) ota1_size,
             (unsigned) history_size,
             (unsigned) coredump_size);
    resp->print(num);

    resp->print("\"nvs_stats\":{");
    if (nvs_stats_ok) {
      snprintf(num, sizeof(num),
               "\"available\":true,\"used_entries\":%u,\"free_entries\":%u,\"total_entries\":%u,\"namespace_count\":%u},",
               (unsigned) nvs_stats.used_entries,
               (unsigned) nvs_stats.free_entries,
               (unsigned) nvs_stats.total_entries,
               (unsigned) nvs_stats.namespace_count);
    } else {
      snprintf(num, sizeof(num),
               "\"available\":false,\"used_entries\":0,\"free_entries\":0,\"total_entries\":0,\"namespace_count\":0},");
    }
    resp->print(num);

    resp->print("\"history\":{");

    snprintf(num, sizeof(num),
             "\"partition_label\":\"%s\",\"namespace\":\"%s\",",
             HISTORY_PARTITION_LABEL,
             HISTORY_NAMESPACE);
    resp->print(num);

    snprintf(num, sizeof(num),
             "\"partition_size_bytes\":%u,\"retention_days\":%u,\"segment_hours\":%u,",
             (unsigned) history_size,
             (unsigned) PERSIST_DAYS,
             (unsigned) PERSIST_SEGMENT_HOURS);
    resp->print(num);

    snprintf(num, sizeof(num),
             "\"points_per_segment\":%u,\"segment_size_bytes\":%u,\"meta_size_bytes\":%u,",
             (unsigned) PERSIST_POINTS_PER_SEGMENT,
             (unsigned) segment_size,
             (unsigned) sizeof(HistoryMeta));
    resp->print(num);

    snprintf(num, sizeof(num),
             "\"valid_segments\":%u,\"capacity_segments\":%u,",
             (unsigned) meta.valid_segments,
             (unsigned) PERSIST_SLOTS);
    resp->print(num);

    snprintf(num, sizeof(num),
             "\"estimated_payload_bytes\":%u,\"estimated_free_payload_bytes\":%u,",
             (unsigned) payload_bytes,
             (unsigned) payload_free_bytes);
    resp->print(num);

    snprintf(num, sizeof(num),
             "\"last_persist_epoch\":%u,\"namespace_initialized\":%s}}",
             (unsigned) meta.last_persist_epoch,
             namespace_initialized ? "true" : "false");
    resp->print(num);
    request->send(resp);
  }

  void handle_status_(AsyncWebServerRequest *request) const {
    auto *resp = request->beginResponseStream("application/json");
    resp->addHeader("Cache-Control", "no-store");

    int64_t uptime_us = esp_timer_get_time();
    uint32_t uptime_s = (uint32_t) (uptime_us / 1000000LL);
    uint32_t free_heap_internal = esp_get_free_internal_heap_size();
    uint32_t free_heap_total = esp_get_free_heap_size();

    // Keep each snprintf well under 64 bytes to avoid silent truncation.
    char num[96];

    resp->print("{\"ok\":true,\"version\":\"");
    resp->print(firmware_version_.c_str());
    resp->print("\",");

    snprintf(num, sizeof(num), "\"uptime_seconds\":%u,\"sensor_count\":%d,",
             (unsigned) uptime_s, NUM_DEVICES);
    resp->print(num);

    resp->print("\"sensors\":[");
    for (int i = 0; i < NUM_DEVICES; i++) {
      if (i > 0) resp->print(",");
      resp->print("{\"id\":\"");
      resp->print(devices[i].id);
      resp->print("\",\"name\":\"");
      resp->print(devices[i].name);
      // Category label
      const char *cat = "unknown";
      if (devices[i].category_id == 0) cat = "environmental";
      else if (devices[i].category_id == 1) cat = "system";
      else if (devices[i].category_id == 2) cat = "network";
      resp->print("\",\"category\":\"");
      resp->print(cat);
      snprintf(num, sizeof(num), "\",\"last_seen\":%u",
               (unsigned) devices[i].last_seen_epoch);
      resp->print(num);
      // Category-specific validity fields
      if (devices[i].category_id == 0) {
        snprintf(num, sizeof(num), ",\"temp_valid\":%s,\"hum_valid\":%s",
                 devices[i].temp_valid ? "true" : "false",
                 devices[i].hum_valid ? "true" : "false");
        resp->print(num);
      }
      resp->print("}");
    }
    resp->print("],");

    // Each field printed separately to stay within the 96-byte buffer.
    snprintf(num, sizeof(num), "\"ram_history_points_per_series\":%d,",
             HISTORY_POINTS_PER_SERIES);
    resp->print(num);

    snprintf(num, sizeof(num), "\"persist_days\":%d,", PERSIST_DAYS);
    resp->print(num);

    // free_heap reports internal SRAM only for cross-board comparability (BUG-062).
    // On C3 (no PSRAM), free_heap == free_heap_internal == free_heap_total.
    // On S3 (PSRAM), free_heap_total includes ~8MB PSRAM which distorts monitoring.
    // free_heap is kept as internal-only for backward compatibility.
    snprintf(num, sizeof(num), "\"free_heap\":%u,", (unsigned) free_heap_internal);
    resp->print(num);
    snprintf(num, sizeof(num), "\"free_heap_internal\":%u,", (unsigned) free_heap_internal);
    resp->print(num);
    snprintf(num, sizeof(num), "\"free_heap_total\":%u}", (unsigned) free_heap_total);
    resp->print(num);

    request->send(resp);
  }

  void handle_history_(AsyncWebServerRequest *request,
                       const char *rest) const {
    const char *slash = strchr(rest, '/');
    if (slash == nullptr) {
      request->send(404);
      return;
    }

    size_t id_len = slash - rest;
    const char *type = slash + 1;

    int sensor_idx = -1;
    for (int i = 0; i < NUM_DEVICES; i++) {
      if (strlen(devices[i].id) == id_len &&
          strncmp(devices[i].id, rest, id_len) == 0) {
        sensor_idx = i;
        break;
      }
    }
    if (sensor_idx < 0) {
      request->send(404);
      return;
    }

    // Legacy /history/{id}/temp and /history/{id}/hum paths are environmental-only.
    // Non-environmental devices use /api/v2/history/{device}/{metric} instead.
    if (devices[sensor_idx].category_id != 0) {
      request->send(404);
      return;
    }

    int series_kind = -1;
    HistoryBuffer *buf = nullptr;
    if (strcmp(type, "temp") == 0) {
      series_kind = HISTORY_SERIES_TEMP;
      buf = devices[sensor_idx].metric_states[0].history;
    } else if (strcmp(type, "hum") == 0) {
      series_kind = HISTORY_SERIES_HUM;
      buf = devices[sensor_idx].metric_states[1].history;
    } else {
      request->send(404);
      return;
    }

    if (buf == nullptr) {
      request->send(404);
      return;
    }

    // BUG-043 rev2: Build the CSV into a pre-reserved std::string instead of
    // using beginResponseStream().  The streaming approach grows its internal
    // std::string through many reallocations — when going from 16KB to 32KB,
    // it temporarily holds BOTH the old and new buffer (48KB).  With SSE active
    // and TCP buffers allocated, this exceeds the ESP32-C3's ~70KB free heap
    // and causes the crash.
    //
    // Pre-reserving to the estimated size makes a single allocation upfront.
    // Each CSV line is at most ~20 bytes ("1773766800,25.50\n").
    // Upper bound: (NVS segments × points_per_segment + RAM buffer count) × 20.

    int nvs_segments = 0;
    uint32_t latest_flash_epoch = 0;
    nvs_handle_t handle;
    bool have_nvs = open_history_nvs_(&handle, NVS_READONLY);
    HistoryMeta meta = {};
    if (have_nvs) {
      if (load_history_meta_(handle, &meta) && meta.valid_segments > 0) {
        nvs_segments = meta.valid_segments;
      }
    }

    size_t est_points = (size_t)nvs_segments * PERSIST_POINTS_PER_SEGMENT
                      + (size_t)buf->count();
    size_t est_bytes  = est_points * 20 + 128;  // 20 bytes/line + margin

    std::string csv;
    csv.reserve(est_bytes);

    // Read persisted NVS segments into the pre-reserved string
    SegmentSnapshot *snapshot = nullptr;
    if (have_nvs && nvs_segments > 0) {
      snapshot = allocate_snapshot_();
      if (snapshot != nullptr) {
        int oldest_slot =
            (meta.next_slot + PERSIST_SLOTS - meta.valid_segments) % PERSIST_SLOTS;

        for (int n = 0; n < nvs_segments; n++) {
          maybe_yield_nvs_scan_(n);
          int slot = (oldest_slot + n) % PERSIST_SLOTS;
          if (!load_snapshot_from_handle_(handle, slot, snapshot)) continue;
          append_snapshot_series_csv_(csv, *snapshot, sensor_idx, series_kind);
          if (snapshot->header.last_epoch > latest_flash_epoch) {
            latest_flash_epoch = snapshot->header.last_epoch;
          }
        }
      }
    }
    if (have_nvs) nvs_close(handle);
    if (snapshot != nullptr) delete snapshot;

    // Append RAM ring buffer entries (newer than persisted data)
    buf->append_csv_to(csv, latest_flash_epoch);

    ESP_LOGD(TAG, "History response for sensor %d/%s: %u bytes, est %u",
             sensor_idx, type, (unsigned)csv.size(), (unsigned)est_bytes);

    // Send as a complete response using the raw-bytes overload (same pattern as
    // gzip dashboard serving).  This avoids the string-copy overhead of the
    // const char* overload — csv.data() stays valid until send() returns.
    auto *resp = request->beginResponse(
        200, "text/plain",
        reinterpret_cast<const uint8_t *>(csv.data()), csv.size());
    resp->addHeader("Cache-Control", "no-store");
    request->send(resp);
  }

#if AGGREGATOR_ENABLED
  // ── Aggregator API endpoints (v7.5.5.2) ──────────────────────────
  //
  // GET /api/aggregator/gateways — satellite list with cached status
  // GET /api/aggregator/live     — unified live values from all satellites
  // GET /api/aggregator/proxy/{gw_id}/history/{device}/{metric} — on-demand proxy
  //
  // All endpoints read from satellite_caches[] under AGG_LOCK()/AGG_UNLOCK().
  // The proxy endpoint fetches from the satellite on-demand using fetch_to_buffer()
  // into s_proxy_tmp (separate from s_fetch_tmp used by the polling task).
  // ─────────────────────────────────────────────────────────────────

  void handle_aggregator_gateways_(AsyncWebServerRequest *request) const {
    if (xSemaphoreTake(s_cache_mutex, pdMS_TO_TICKS(100)) != pdTRUE) {
      request->send(503);
      return;
    }
    // LESSON-OPS-056: pre-reserve string to avoid reallocation
    // Manifest JSON can be up to 4096 bytes per satellite; account for it in the reserve.
    std::string out;
    size_t reserve_size = 32;
    for (int ri = 0; ri < MAX_SATELLITES; ri++) {
      reserve_size += 512 + satellite_caches[ri].manifest_len;
    }
    out.reserve(reserve_size);
    out += "{\"gateways\":[";
    for (int i = 0; i < MAX_SATELLITES; i++) {
      if (i > 0) out += ",";
      const SatelliteCache& sat = satellite_caches[i];
      char tmp[128];
      out += "{\"id\":\"";   out += sat.id;
      out += "\",\"name\":\""; out += sat.name;
      out += "\",\"reachable\":";
      out += sat.reachable ? "true" : "false";
      snprintf(tmp, sizeof(tmp), ",\"last_seen\":%u,\"consecutive_failures\":%u",
               (unsigned)sat.last_seen_epoch, (unsigned)sat.consecutive_failures);
      out += tmp;
      out += ",\"manifest_cached\":";
      out += (sat.manifest_len > 0) ? "true" : "false";
      out += ",\"live_cached\":";
      out += (sat.live_len > 0) ? "true" : "false";
      // Extract firmware_version from cached status_json using strstr (no JSON lib)
      const char* ver_ptr = strstr(sat.status_json, "\"version\":\"");
      if (ver_ptr) {
        ver_ptr += 11;  // skip past "\"version\":\""
        const char* ver_end = strchr(ver_ptr, '"');
        if (ver_end && (ver_end - ver_ptr) < 32) {
          out += ",\"firmware_version\":\"";
          out.append(ver_ptr, (size_t)(ver_end - ver_ptr));
          out += "\"";
        }
      }
      // Extract sensor_count from cached status_json
      const char* sc_ptr = strstr(sat.status_json, "\"sensor_count\":");
      if (sc_ptr) {
        sc_ptr += 15;  // skip past "\"sensor_count\":"
        char* sc_end = nullptr;
        long sc_val = strtol(sc_ptr, &sc_end, 10);
        if (sc_end != sc_ptr && sc_val >= 0 && sc_val <= 1000) {
          snprintf(tmp, sizeof(tmp), ",\"sensor_count\":%ld", sc_val);
          out += tmp;
        }
      }
      // Extract free_heap from cached status_json
      const char* fh_ptr = strstr(sat.status_json, "\"free_heap\":");
      if (fh_ptr) {
        fh_ptr += 12;  // skip past "\"free_heap\":"
        snprintf(tmp, sizeof(tmp), ",\"free_heap\":%lu",
                 (unsigned long)strtoul(fh_ptr, nullptr, 10));
        out += tmp;
      }
      // Include base_url for settings panel display.
      // JSON-escape backslash and double-quote. Control chars (0x00-0x1F) are not escaped
      // because base_url is validated at config load time to start with "http://" and is
      // a plain ASCII URL — control characters cannot appear in valid HTTP URLs.
      out += ",\"base_url\":\"";
      for (const char* bp = sat.base_url; *bp != '\0'; ++bp) {
        if (*bp == '\\') { out += "\\\\"; }
        else if (*bp == '"') { out += "\\\""; }
        else { out += *bp; }
      }
      out += "\"";
      // Include cached manifest JSON for per-gateway device rendering
      if (sat.manifest_len > 0) {
        out += ",\"manifest\":";
        out.append(sat.manifest_json, sat.manifest_len);
      }
      out += "}";
    }
    out += "]}";
    xSemaphoreGive(s_cache_mutex);
    auto *resp = request->beginResponse(200, "application/json", out);
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_aggregator_live_(AsyncWebServerRequest *request) const {
    if (xSemaphoreTake(s_cache_mutex, pdMS_TO_TICKS(100)) != pdTRUE) {
      request->send(503);
      return;
    }
    // LESSON-OPS-056: pre-reserve string (MAX_SATELLITES * live_json max ~2048)
    std::string out;
    out.reserve(MAX_SATELLITES * 2304 + 64);
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "{\"timestamp\":%u,\"gateways\":{",
             (unsigned)::time(nullptr));
    out += tmp;
    for (int i = 0; i < MAX_SATELLITES; i++) {
      if (i > 0) out += ",";
      const SatelliteCache& sat = satellite_caches[i];
      out += "\""; out += sat.id; out += "\":{";
      out += "\"reachable\":";
      out += sat.reachable ? "true" : "false";
      out += ",\"live\":";
      if (sat.live_len > 0) {
        out.append(sat.live_json, sat.live_len);
      } else {
        out += "null";
      }
      out += "}";
    }
    out += "}}";
    xSemaphoreGive(s_cache_mutex);
    auto *resp = request->beginResponse(200, "application/json", out);
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_aggregator_proxy_(AsyncWebServerRequest *request,
                                const char *rest) const {
    // rest = "{gw_id}/history/{device}/{metric}"
    // Extract gw_id (up to first '/')
    const char* slash1 = strchr(rest, '/');
    if (!slash1) { request->send(404); return; }
    char gw_id[64];
    size_t gw_id_len = (size_t)(slash1 - rest);
    if (gw_id_len == 0 || gw_id_len >= sizeof(gw_id)) {
      request->send(404);
      return;
    }
    memcpy(gw_id, rest, gw_id_len);
    gw_id[gw_id_len] = '\0';

    // Verify sub-path starts with "history/"
    const char* after_gw = slash1 + 1;
    if (strncmp(after_gw, "history/", 8) != 0) { request->send(404); return; }
    const char* device_start = after_gw + 8;
    const char* slash2 = strchr(device_start, '/');
    if (!slash2) { request->send(404); return; }
    char device[64];
    size_t device_len = (size_t)(slash2 - device_start);
    if (device_len == 0 || device_len >= sizeof(device)) {
      request->send(404);
      return;
    }
    memcpy(device, device_start, device_len);
    device[device_len] = '\0';

    const char* metric = slash2 + 1;
    if (*metric == '\0') { request->send(404); return; }

    // Find the satellite by gw_id — take mutex briefly to read base_url
    char base_url[128];
    bool found = false;
    if (xSemaphoreTake(s_cache_mutex, pdMS_TO_TICKS(100)) != pdTRUE) {
      request->send(503);
      return;
    }
    bool url_too_long = false;
    for (int i = 0; i < MAX_SATELLITES; i++) {
      if (strcmp(satellite_caches[i].id, gw_id) == 0) {
        size_t blen = strlen(satellite_caches[i].base_url);
        if (blen < sizeof(base_url)) {
          memcpy(base_url, satellite_caches[i].base_url, blen + 1);
          found = true;
        } else {
          url_too_long = true;
        }
        break;
      }
    }
    xSemaphoreGive(s_cache_mutex);

    if (url_too_long) { request->send(500); return; }
    if (!found) { request->send(404); return; }

    // Build satellite URL and fetch on-demand into s_proxy_tmp.
    // Use /api/v2/history/ which handles all device categories (env, ping, RSSI, etc.)
    char url[256];
    int url_fmt_len = snprintf(url, sizeof(url), "%s/api/v2/history/%s/%s", base_url, device, metric);
    if (url_fmt_len < 0 || static_cast<size_t>(url_fmt_len) >= sizeof(url)) {
      request->send(414);
      return;
    }

    // s_proxy_tmp is only used in web handler context (single-threaded ESPHome loop)
    // The polling task never touches s_proxy_tmp — no mutex needed here.
    s_proxy_len = 0;
    static_assert(sizeof(s_proxy_tmp) <= 65535,
                  "s_proxy_tmp size must fit into uint16_t for fetch_to_buffer");
    if (!fetch_to_buffer(url, s_proxy_tmp,
                         static_cast<uint16_t>(sizeof(s_proxy_tmp)),
                         &s_proxy_len)
        || s_proxy_len == 0) {
      request->send(502);
      return;
    }

    // Detect truncation: if the buffer is completely full, the upstream response was
    // likely larger than 32KB and was silently cut off by fetch_to_buffer().
    // Return 502 rather than serving corrupted/incomplete data to the dashboard.
    if (s_proxy_len >= sizeof(s_proxy_tmp) - 1) {
      auto *resp = request->beginResponse(
          502, "application/json",
          "{\"error\":\"upstream_response_too_large\",\"max_bytes\":32768}");
      add_common_headers_(resp);
      request->send(resp);
      return;
    }

    // LESSON-OPS-056: zero-copy from static buffer — NEVER beginResponseStream
    auto *resp = request->beginResponse(
        200, "text/plain",
        reinterpret_cast<const uint8_t*>(s_proxy_tmp), s_proxy_len);
    add_common_headers_(resp);
    request->send(resp);
  }

  // ── Stubbed management endpoints (v7.5.5.3) — reserved for v7.6 runtime mgmt ──
  // Returns 501 to signal "planned but not yet implemented".
  void handle_aggregator_stub_501_(AsyncWebServerRequest *request) const {
    auto *resp = request->beginResponse(501, "application/json",
        "{\"error\":\"not implemented\","
        "\"message\":\"Runtime satellite management is planned for v7.6\"}");
    add_common_headers_(resp);
    request->send(resp);
  }
#endif  // AGGREGATOR_ENABLED
};


// ═══════════════════════════════════════════════════════════════════
// Handler Registration — called from YAML on_boot lambda
// ═══════════════════════════════════════════════════════════════════

static void register_history_handler(
    esphome::web_server_base::WebServerBase *base,
    const char *mgmt_username,
    const char *mgmt_password,
    const char *firmware_version = "unknown") {

  if (base == nullptr) {
    ESP_LOGE(TAG, "WebServerBase is null — cannot register endpoints");
    return;
  }

  restore_from_nvs();

  static auto *handler = new HistoryWebHandler(
      mgmt_username == nullptr ? std::string() : std::string(mgmt_username),
      mgmt_password == nullptr ? std::string() : std::string(mgmt_password),
      firmware_version == nullptr ? std::string("unknown") : std::string(firmware_version));
  base->add_handler(handler);

  ESP_LOGI(TAG,
           "handler registered (%d devices, %dh RAM, %d hourly slots in '%s', %d pts/segment)",
           NUM_DEVICES, HISTORY_HOURS, PERSIST_SLOTS,
           HISTORY_PARTITION_LABEL,
           PERSIST_POINTS_PER_SEGMENT);
  for (int i = 0; i < NUM_DEVICES; i++) {
    ESP_LOGI(TAG, "  [%d] %s -> /history/%s/{temp,hum}",
             i, devices[i].name, devices[i].id);
  }
  ESP_LOGI(TAG, "  management -> POST /api/reboot, POST /api/delete-data (Basic auth)");
  ESP_LOGI(TAG, "  import     -> POST /api/import/{begin,segment,finish} (Basic auth)");
  ESP_LOGI(TAG, "  storage    -> GET /api/storage-stats");
  ESP_LOGI(TAG, "  status     -> GET /api/status");
  ESP_LOGI(TAG, "  manifest -> GET /api/manifest (v2)");
  ESP_LOGI(TAG, "  storage -> dedicated NVS partition: %s / namespace: %s",
           HISTORY_PARTITION_LABEL, HISTORY_NAMESPACE);
}
