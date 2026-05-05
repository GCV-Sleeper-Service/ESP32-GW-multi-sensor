#pragma once
// ═══════════════════════════════════════════════════════════════════
// config-v7.6.10.1.h - hourly persistence with dedicated history NVS partition
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
// NUM_ENV_SENSORS / NUM_SENSORS = persisted environmental-sensor count only (backward-compat alias for SegmentSnapshot / HistoryMeta).
// NUM_DEVICES = total logical devices in manifest (environmental + network + system).
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

static const MetricDef metrics_system[] = {
  {"cpu_pct",    "CPU Usage",  "%", 0, false},
  {"ram_pct",    "RAM Usage",  "%", 0, false},
  {"disk_pct",   "Disk Usage", "%", 0, false},
  {"uptime_hrs", "Uptime",     "h", 3, false}
};

static HistoryBuffer entity_hbuf_office_temp;
static HistoryBuffer entity_hbuf_office_hum;
static HistoryBuffer entity_hbuf_first_floor_temp;
static HistoryBuffer entity_hbuf_first_floor_hum;
static HistoryBuffer entity_hbuf_outside_temp;
static HistoryBuffer entity_hbuf_outside_hum;
static HistoryBuffer entity_hbuf_wan_ping_ping_ms;
static HistoryBuffer entity_hbuf_wan_ping_success_pct;

static constexpr int NUM_DEVICES = 5;
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
  {
    .id = "nas01", .name = "NAS Health",
    .category_id = 1, .adapter = "external_push",
    .metric_defs = metrics_system,
    .metric_states = {
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},
      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}
    },
    .metric_count = 4,
    .mac = "",
    .last_rssi = 0, .last_seen_epoch = 0
  },
};
// <<< SENSOR_MANIFEST:ENTITY_END >>>

// ═══════════════════════════════════════════════════════════════════
// ── SENSOR COUNT CONFIGURATION GUIDE (v7.6.10.1) ──
//
// NUM_ENV_SENSORS = number of environmental (ThermoPro BLE) sensors.
// Supported environmental sensor counts: 1, 2, 3 (default), 4.
//
// NUM_DEVICES = total logical devices in manifest (environmental + network + system).
// NUM_DEVICES can exceed NUM_ENV_SENSORS when non-environmental devices
// (icmp_ping, external_push) are present. Currently: NUM_DEVICES = 5
// (3 environmental + 1 network + 1 system).
//
// NUM_SENSORS = NUM_ENV_SENSORS (backward-compat alias for persisted-history
// segment layout). NEVER set NUM_SENSORS to NUM_DEVICES (BUG-045).
//
// To change environmental sensor count (recommended workflow):
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

// BUG-043 rev2: Append snapshot series CSV to pre-reserved std::string.
// Writes to a string buffer
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

// ── Deferred management task: delete-data ─────────────────────────────────
// Runs NVS erase on its own stack so the httpd task (hardcoded 4 KB by
// ESPHome/ESP-IDF) is never exposed to NVS frames.
// Pattern mirrors the existing schedule_reboot_() / reboot_task_ pair.

static volatile bool s_delete_data_in_progress = false;

static void delete_data_task_(void *) {
  bool ok = clear_persisted_history_();
  if (!ok) {
    ESP_LOGE(TAG, "delete_data task: clear_persisted_history_() failed");
  }
  s_delete_data_in_progress = false;
  vTaskDelete(nullptr);
}

static void schedule_delete_data_() {
  BaseType_t ret = xTaskCreate(delete_data_task_, "hist_delete", 8192, nullptr, 1, nullptr);
  if (ret != pdPASS) {
    ESP_LOGE(TAG, "schedule_delete_data_: xTaskCreate failed (ret=%d)", (int)ret);
    s_delete_data_in_progress = false;
  }
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

// Ping task stack watermark — updated every cycle, read by /api/status.
// Declared outside #ifdef so web-handler.h can always reference it
// (reads 0 when ping is not configured — no #ifdef needed in status handler).
static volatile uint32_t g_ping_stack_watermark_bytes = 0;
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
      // ── Stack watermark telemetry (v7.6.7.3) ──────────────────
      g_ping_stack_watermark_bytes =
          (uint32_t)(uxTaskGetStackHighWaterMark(nullptr) * sizeof(StackType_t));
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
#ifndef AGG_MANIFEST_BUF_SIZE
// Maximum buffer size for cached satellite manifest JSON.
// Must accommodate the largest manifest a satellite can produce.
// A satellite with 5+ sensors and system devices generates ~5–6KB manifests.
// Truncation detection: if manifest_len >= AGG_MANIFEST_BUF_SIZE - 1,
// the manifest was likely truncated by fetch_to_buffer().
static constexpr uint16_t AGG_MANIFEST_BUF_SIZE = 8192;
#endif
static constexpr const char AGGREGATOR_TEST_SATELLITE_ROUTE[] =
    "/api/aggregator/test-satellite";
static constexpr size_t AGGREGATOR_TEST_SATELLITE_ROUTE_LEN =
    sizeof(AGGREGATOR_TEST_SATELLITE_ROUTE) - 1;
static constexpr size_t AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN =
    sizeof("/api/aggregator/satellite/") - 1;

struct SatelliteCache {
  const char* id;
  const char* name;
  const char* base_url;
  int poll_interval_seconds;

  // ── Owned string storage for NVS-loaded satellites (v7.6.0.0) ──
  // When loaded from NVS, id/name/base_url point to these buffers.
  // When loaded from compile-time arrays, they point to static literals.
  char id_buf[32];       // max satellite ID length (NVS s{i}_id max 31 chars)
  char name_buf[64];     // max friendly name (NVS s{i}_name max 63 chars)
  char url_buf[128];     // max base URL (NVS s{i}_url max 127 chars)

  // Cached responses (statically allocated — no malloc)
  char manifest_json[AGG_MANIFEST_BUF_SIZE];  // cached /api/manifest response
  char live_json[2048];         // cached /api/v2/live response
  char status_json[2048];       // cached /api/status/full response
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

  void set_identity(const char* new_id, const char* new_name, const char* new_url, int poll_s) {
    strncpy(id_buf, new_id, sizeof(id_buf) - 1);
    id_buf[sizeof(id_buf) - 1] = '\0';
    strncpy(name_buf, new_name, sizeof(name_buf) - 1);
    name_buf[sizeof(name_buf) - 1] = '\0';
    strncpy(url_buf, new_url, sizeof(url_buf) - 1);
    url_buf[sizeof(url_buf) - 1] = '\0';
    id = id_buf;
    name = name_buf;
    base_url = url_buf;
    poll_interval_seconds = poll_s;
  }
};

static SatelliteCache satellite_caches[MAX_SATELLITES];
static int runtime_satellite_count = 0;   // actual count at runtime (≤ MAX_SATELLITES)
static uint32_t satellite_config_generation = 0;  // Incremented on add/delete/reset to detect config changes

// Snapshot structure for safe NVS writes from deferred task
struct SatelliteNVSSnapshot {
  int count;
  struct {
    char id[32];
    char name[64];
    char url[128];
    uint16_t poll_interval_seconds;
  } satellites[MAX_SATELLITES];
};

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
static char s_fetch_tmp[AGG_MANIFEST_BUF_SIZE];

// Separate from s_fetch_tmp — the proxy runs in web handler context
// while the polling task runs in RTOS context. They must not share buffers.
// Only accessed by the web handler (ESPHome main loop, single-threaded).
static char s_proxy_tmp[32768];
static uint16_t s_proxy_len = 0;

static char s_status_basic_auth_b64[192] = {0};

static void set_aggregator_poll_basic_auth_(const char *username,
                                            const char *password) {
  s_status_basic_auth_b64[0] = '\0';
  if (username == nullptr || password == nullptr) return;
  if (username[0] == '\0' || password[0] == '\0') return;
  // Build user:pass in stack storage to avoid heap allocation in polling paths.
  constexpr size_t kMaxUserInfoLen = 128;
  char user_info[kMaxUserInfoLen];
  size_t user_len = strlen(username);
  size_t pass_len = strlen(password);
  size_t user_info_len = user_len + 1 + pass_len;
  if (user_info_len >= kMaxUserInfoLen) {
    s_status_basic_auth_b64[0] = '\0';
    return;
  }

  memcpy(user_info, username, user_len);
  user_info[user_len] = ':';
  memcpy(user_info + user_len + 1, password, pass_len);

  static constexpr char kBase64Table[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  size_t out = 0;
  for (size_t i = 0; i < user_info_len; i += 3) {
    if (out + 4 >= sizeof(s_status_basic_auth_b64)) {
      s_status_basic_auth_b64[0] = '\0';
      return;
    }
    uint32_t octet_a = static_cast<uint8_t>(user_info[i]);
    uint32_t octet_b = (i + 1 < user_info_len) ? static_cast<uint8_t>(user_info[i + 1]) : 0;
    uint32_t octet_c = (i + 2 < user_info_len) ? static_cast<uint8_t>(user_info[i + 2]) : 0;
    uint32_t triple = (octet_a << 16) | (octet_b << 8) | octet_c;

    size_t remain = user_info_len - i;
    s_status_basic_auth_b64[out++] = kBase64Table[(triple >> 18) & 0x3F];
    s_status_basic_auth_b64[out++] = kBase64Table[(triple >> 12) & 0x3F];
    s_status_basic_auth_b64[out++] = (remain > 1) ? kBase64Table[(triple >> 6) & 0x3F] : '=';
    s_status_basic_auth_b64[out++] = (remain > 2) ? kBase64Table[triple & 0x3F] : '=';
  }

  s_status_basic_auth_b64[out] = '\0';
}

// All socket operations use lwip_*() prefixed functions (not the BSD-compat
// aliases socket()/connect()/send()/recv()/close()) to avoid namespace
// collision with esphome::socket — see CI failure in PR #64.
//
// Minimal HTTP/1.0 GET using lwIP BSD sockets.
// Avoids esp_http_client.h, which is not in ESPHome's IDF PRIV_REQUIRES.
// Uses lwip/sockets.h and lwip/netdb.h (both already available).
// Returns true and sets *out_len on HTTP 200; false otherwise.
static bool fetch_to_buffer(const char* url, char* buf, uint16_t buf_size, uint16_t* out_len,
                            int timeout_s = 5, int* out_http_status = nullptr,
                            const char* basic_auth = nullptr) {
  *out_len = 0;
  if (out_http_status != nullptr) *out_http_status = 0;

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
  tv.tv_sec = timeout_s;
  tv.tv_usec = 0;
  lwip_setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  lwip_setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

  if (lwip_connect(sock, res->ai_addr, res->ai_addrlen) != 0) {
    lwip_close(sock); lwip_freeaddrinfo(res); return false;
  }
  lwip_freeaddrinfo(res);

  // ── Send HTTP/1.0 GET (no chunked encoding) ────────────────────
  char auth_header[320];
  auth_header[0] = '\0';
  if (basic_auth != nullptr && basic_auth[0] != '\0') {
    int auth_len = snprintf(auth_header, sizeof(auth_header),
                            "Authorization: Basic %s\r\n", basic_auth);
    if (auth_len < 0 || (size_t)auth_len >= sizeof(auth_header)) {
      lwip_close(sock);
      return false;
    }
  }

  char req[768];
  int req_len = snprintf(req, sizeof(req),
      "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n%s\r\n",
      path, host, auth_header);
  if (req_len < 0 || (size_t)req_len >= sizeof(req)) { lwip_close(sock); return false; }
  if (lwip_send(sock, req, (size_t)req_len, 0) < 0) { lwip_close(sock); return false; }

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

  // Parse and check HTTP status (bounded; no reliance on NUL terminator).
  if (strncmp(hdr, "HTTP/", 5) != 0) { lwip_close(sock); return false; }
  const char* hdr_end = hdr + hdr_len;
  const char* sp = (const char*)memchr(hdr, ' ', hdr_len);
  if (!sp) { lwip_close(sock); return false; }
  const char* status = sp + 1;
  while (status < hdr_end && *status == ' ') status++;
  if ((hdr_end - status) < 3) { lwip_close(sock); return false; }
  if (status[0] < '0' || status[0] > '9' ||
      status[1] < '0' || status[1] > '9' ||
      status[2] < '0' || status[2] > '9') {
    lwip_close(sock); return false;
  }
  int http_status_code = (status[0] - '0') * 100 +
                         (status[1] - '0') * 10 +
                         (status[2] - '0');
  if (out_http_status != nullptr) *out_http_status = http_status_code;
  if (http_status_code != 200) { lwip_close(sock); return false; }

  // ── Read body directly into caller's buffer ────────────────────
  int total = 0;
  while (total < (int)(buf_size - 1)) {
    int n = lwip_recv(sock, buf + total, buf_size - 1 - total, 0);
    if (n <= 0) break;
    total += n;
  }
  lwip_close(sock);

  buf[total] = '\0';
  *out_len = (uint16_t)total;
  return true;
}

// ── Satellite manifest probe helper (v7.6.0.1) ─────────────────────────────
// Probe a satellite URL by fetching /api/manifest.
// On success, extracts gateway.id and gateway.name into provided buffers.
// Returns true on success, false on failure (unreachable, non-200, or unparseable manifest).
//
// MUST be called from web handler context only (uses s_proxy_tmp).
// NOT safe to call from the polling task.
static bool probe_satellite_manifest_(
    const char* base_url,
    char* out_id,   size_t id_size,
    char* out_name, size_t name_size)
{
  char url_buf[256];
  int url_len = snprintf(url_buf, sizeof(url_buf), "%s/api/manifest", base_url);
  if (url_len < 0 || (size_t)url_len >= sizeof(url_buf)) return false;

  uint16_t resp_len = 0;
  // Use s_proxy_tmp (web handler context only — single-threaded ESPHome loop)
  if (!fetch_to_buffer(url_buf, s_proxy_tmp, (uint16_t)(sizeof(s_proxy_tmp) - 1), &resp_len)
      || resp_len == 0) {
    ESP_LOGW(TAG_AGG, "probe_satellite_manifest_: unreachable or non-200 at %s", url_buf);
    return false;
  }
  s_proxy_tmp[resp_len] = '\0';

  // Extract gateway.id and gateway.name from the gateway object.
  // Simple strstr parsing (no JSON library on ESP32)
  out_id[0] = '\0';
  out_name[0] = '\0';

  const char* gw = strstr(s_proxy_tmp, "\"gateway\"");
  if (!gw) return false;

  // Find the closing brace of the gateway object to bound searches.
  // We look for the next '}' after the "gateway" key — simple but sufficient
  // for this project's manifest structure (gateway object is shallow).
  const char* gw_end = strchr(gw + 9, '}');  // 9 = strlen("\"gateway\"")
  if (!gw_end) gw_end = s_proxy_tmp + resp_len;  // fallback: end of buffer

  // --- Extract "id" ---
  const char* id_key = strstr(gw, "\"id\"");
  if (id_key && id_key < gw_end) {
    const char* p = id_key + 4;  // skip past "id"
    while (p < gw_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
    if (p < gw_end && *p == ':') {
      ++p;
      while (p < gw_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
      if (p < gw_end && *p == '"') {
        const char* id_val = p + 1;
        const char* id_end = strchr(id_val, '"');
        if (id_end && id_end < gw_end + 32) {  // allow small overshoot for closing quote
          size_t len = (size_t)(id_end - id_val);
          if (len >= id_size) len = id_size - 1;
          memcpy(out_id, id_val, len);
          out_id[len] = '\0';
        }
      }
    }
  }

  // --- Extract "name" ---
  const char* name_key = strstr(gw, "\"name\"");
  if (name_key && name_key < gw_end) {
    const char* p = name_key + 6;  // skip past "name"
    while (p < gw_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
    if (p < gw_end && *p == ':') {
      ++p;
      while (p < gw_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
      if (p < gw_end && *p == '"') {
        const char* name_val = p + 1;
        const char* name_end = strchr(name_val, '"');
        if (name_end && name_end < gw_end + 32) {
          size_t len = (size_t)(name_end - name_val);
          if (len >= name_size) len = name_size - 1;
          memcpy(out_name, name_val, len);
          out_name[len] = '\0';
        }
      }
    }
  }

  // Must have at least an ID to be a valid manifest
  if (out_id[0] == '\0') {
    ESP_LOGW(TAG_AGG, "probe_satellite_manifest_: no gateway.id found in manifest at %s", base_url);
  }
  return out_id[0] != '\0';
}

// ── NVS satellite persistence (v7.6.0.0) ───────────────────────────────────
// Namespace: "agg_sats" (9 chars — under the 15-char NVS key limit)
// Key scheme: count (u8), s{i}_id (str), s{i}_name (str), s{i}_url (str), s{i}_poll (u16)

// Returns the number of satellites loaded, or 0 if NVS is empty/corrupt.
static int load_satellites_from_nvs_() {
  nvs_handle_t nvs;
  esp_err_t err = nvs_open("agg_sats", NVS_READONLY, &nvs);
  if (err != ESP_OK) {
    ESP_LOGW(TAG_AGG, "NVS agg_sats: open failed (%s) — will use compile-time defaults",
             esp_err_to_name(err));
    return 0;
  }

  uint8_t count = 0;
  err = nvs_get_u8(nvs, "count", &count);
  if (err != ESP_OK || count == 0 || count > MAX_SATELLITES) {
    if (err == ESP_ERR_NVS_NOT_FOUND) {
      ESP_LOGI(TAG_AGG, "NVS agg_sats: no 'count' key — first boot, using compile-time defaults");
    } else if (count > MAX_SATELLITES) {
      ESP_LOGW(TAG_AGG, "NVS agg_sats: count=%u exceeds MAX_SATELLITES=%d — using compile-time defaults",
               (unsigned)count, MAX_SATELLITES);
    }
    nvs_close(nvs);
    return 0;
  }

  int loaded = 0;
  for (int i = 0; i < (int)count; i++) {
    char key_id[16], key_name[16], key_url[16], key_poll[16];
    snprintf(key_id,   sizeof(key_id),   "s%d_id",   i);
    snprintf(key_name, sizeof(key_name), "s%d_name", i);
    snprintf(key_url,  sizeof(key_url),  "s%d_url",  i);
    snprintf(key_poll, sizeof(key_poll), "s%d_poll", i);

    char id_tmp[32] = {0};
    char name_tmp[64] = {0};
    char url_tmp[128] = {0};
    size_t id_len = sizeof(id_tmp);
    size_t name_len = sizeof(name_tmp);
    size_t url_len = sizeof(url_tmp);

    if (nvs_get_str(nvs, key_id, id_tmp, &id_len) != ESP_OK ||
        nvs_get_str(nvs, key_name, name_tmp, &name_len) != ESP_OK ||
        nvs_get_str(nvs, key_url, url_tmp, &url_len) != ESP_OK) {
      ESP_LOGE(TAG_AGG, "NVS agg_sats: corrupt entry at index %d — falling back to compile-time defaults", i);
      nvs_close(nvs);
      return 0;
    }

    uint16_t poll_s = 30;
    nvs_get_u16(nvs, key_poll, &poll_s);  // optional — default 30 if missing

    satellite_caches[i].set_identity(id_tmp, name_tmp, url_tmp, (int)poll_s);
    loaded++;
    ESP_LOGI(TAG_AGG, "NVS satellite[%d]: id=%s url=%s poll=%us",
             i, satellite_caches[i].id, satellite_caches[i].base_url, (unsigned)poll_s);
  }

  nvs_close(nvs);
  return loaded;
}

// Rewrites ALL satellite keys from scratch. Called after add, delete, or factory reset reload.
static bool save_satellites_to_nvs_() {
  nvs_handle_t nvs;
  esp_err_t err = nvs_open("agg_sats", NVS_READWRITE, &nvs);
  if (err != ESP_OK) {
    ESP_LOGE(TAG_AGG, "NVS agg_sats: open for write failed (%s)", esp_err_to_name(err));
    return false;
  }

  // Erase all keys first to avoid stale entries after delete+compact
  nvs_erase_all(nvs);

  err = nvs_set_u8(nvs, "count", (uint8_t)runtime_satellite_count);
  if (err != ESP_OK) {
    ESP_LOGE(TAG_AGG, "NVS agg_sats: failed to write count (%s)", esp_err_to_name(err));
    nvs_close(nvs);
    return false;
  }

  bool all_ok = true;
  for (int i = 0; i < runtime_satellite_count; i++) {
    char key_id[16], key_name[16], key_url[16], key_poll[16];
    snprintf(key_id,   sizeof(key_id),   "s%d_id",   i);
    snprintf(key_name, sizeof(key_name), "s%d_name", i);
    snprintf(key_url,  sizeof(key_url),  "s%d_url",  i);
    snprintf(key_poll, sizeof(key_poll), "s%d_poll", i);

    const SatelliteCache& sat = satellite_caches[i];
    if (nvs_set_str(nvs, key_id, sat.id) != ESP_OK ||
        nvs_set_str(nvs, key_name, sat.name) != ESP_OK ||
        nvs_set_str(nvs, key_url, sat.base_url) != ESP_OK ||
        nvs_set_u16(nvs, key_poll, (uint16_t)sat.poll_interval_seconds) != ESP_OK) {
      ESP_LOGE(TAG_AGG, "NVS agg_sats: write failed for satellite %d", i);
      all_ok = false;
      // Continue writing remaining satellites — partial save is better than none
    }
  }

  err = nvs_commit(nvs);
  if (err != ESP_OK) {
    ESP_LOGE(TAG_AGG, "NVS agg_sats: commit failed (%s)", esp_err_to_name(err));
    all_ok = false;
  }
  nvs_close(nvs);

  if (all_ok) {
    ESP_LOGI(TAG_AGG, "NVS agg_sats: saved %d satellites", runtime_satellite_count);
  }
  return all_ok;
}

// Write satellite config snapshot to NVS — used by deferred task
static bool save_satellites_snapshot_to_nvs_(const SatelliteNVSSnapshot* snapshot) {
  if (!snapshot) return false;

  nvs_handle_t nvs;
  esp_err_t err = nvs_open("agg_sats", NVS_READWRITE, &nvs);
  if (err != ESP_OK) {
    ESP_LOGE(TAG_AGG, "NVS agg_sats: open for write failed (%s)", esp_err_to_name(err));
    return false;
  }

  // Erase all keys first to avoid stale entries after delete+compact
  nvs_erase_all(nvs);

  err = nvs_set_u8(nvs, "count", (uint8_t)snapshot->count);
  if (err != ESP_OK) {
    ESP_LOGE(TAG_AGG, "NVS agg_sats: failed to write count (%s)", esp_err_to_name(err));
    nvs_close(nvs);
    return false;
  }

  bool all_ok = true;
  for (int i = 0; i < snapshot->count; i++) {
    char key_id[16], key_name[16], key_url[16], key_poll[16];
    snprintf(key_id,   sizeof(key_id),   "s%d_id",   i);
    snprintf(key_name, sizeof(key_name), "s%d_name", i);
    snprintf(key_url,  sizeof(key_url),  "s%d_url",  i);
    snprintf(key_poll, sizeof(key_poll), "s%d_poll", i);

    const auto& sat = snapshot->satellites[i];
    if (nvs_set_str(nvs, key_id, sat.id) != ESP_OK ||
        nvs_set_str(nvs, key_name, sat.name) != ESP_OK ||
        nvs_set_str(nvs, key_url, sat.url) != ESP_OK ||
        nvs_set_u16(nvs, key_poll, sat.poll_interval_seconds) != ESP_OK) {
      ESP_LOGE(TAG_AGG, "NVS agg_sats: write failed for satellite %d", i);
      all_ok = false;
      // Continue writing remaining satellites — partial save is better than none
    }
  }

  err = nvs_commit(nvs);
  if (err != ESP_OK) {
    ESP_LOGE(TAG_AGG, "NVS agg_sats: commit failed (%s)", esp_err_to_name(err));
    all_ok = false;
  }
  nvs_close(nvs);

  if (all_ok) {
    ESP_LOGI(TAG_AGG, "NVS agg_sats: saved %d satellites from snapshot", snapshot->count);
  }
  return all_ok;
}

// Optimization for add — writes one satellite entry + count without erasing all
static bool save_single_satellite_to_nvs_(int index) {
  if (index < 0 || index >= runtime_satellite_count) return false;

  nvs_handle_t nvs;
  if (nvs_open("agg_sats", NVS_READWRITE, &nvs) != ESP_OK) return false;

  char key_id[16], key_name[16], key_url[16], key_poll[16];
  snprintf(key_id,   sizeof(key_id),   "s%d_id",   index);
  snprintf(key_name, sizeof(key_name), "s%d_name", index);
  snprintf(key_url,  sizeof(key_url),  "s%d_url",  index);
  snprintf(key_poll, sizeof(key_poll), "s%d_poll", index);

  const SatelliteCache& sat = satellite_caches[index];
  bool ok = (nvs_set_u8(nvs, "count", (uint8_t)runtime_satellite_count) == ESP_OK &&
             nvs_set_str(nvs, key_id, sat.id) == ESP_OK &&
             nvs_set_str(nvs, key_name, sat.name) == ESP_OK &&
             nvs_set_str(nvs, key_url, sat.base_url) == ESP_OK &&
             nvs_set_u16(nvs, key_poll, (uint16_t)sat.poll_interval_seconds) == ESP_OK &&
             nvs_commit(nvs) == ESP_OK);

  nvs_close(nvs);
  if (!ok) ESP_LOGE(TAG_AGG, "NVS agg_sats: single save failed for satellite %d", index);
  return ok;
}

// Initialise satellite_caches[] — try NVS first, fall back to compile-time arrays.
// Called at the start of aggregator_poll_task().
static void init_satellite_caches_() {
  int nvs_count = load_satellites_from_nvs_();
  if (nvs_count > 0) {
    runtime_satellite_count = nvs_count;
    ESP_LOGI(TAG_AGG, "Loaded %d satellites from NVS", nvs_count);
  } else {
    // Compile-time fallback
    for (int i = 0; i < MAX_SATELLITES; i++) {
      satellite_caches[i].set_identity(
          SATELLITE_IDS[i], SATELLITE_NAMES[i],
          SATELLITE_URLS[i], SATELLITE_POLL_INTERVALS[i]);
    }
    runtime_satellite_count = MAX_SATELLITES;
    ESP_LOGI(TAG_AGG, "Using %d compile-time satellites (NVS empty)", MAX_SATELLITES);
    if (!save_satellites_to_nvs_()) {
      ESP_LOGW(TAG_AGG, "NVS agg_sats: failed to persist compile-time defaults (non-fatal)");
    }
  }

  // Clear cached response buffers for all active satellites
  for (int i = 0; i < runtime_satellite_count; i++) {
    satellite_caches[i].clear_cache();
  }
}

static void aggregator_poll_task(void* arg) {
  init_satellite_caches_();   // replaces the old inline init loop

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

    for (int i = 0; i < runtime_satellite_count; i++) {
      // Capture satellite info and generation under lock
      char sat_id[32];
      char sat_base_url[128];
      int sat_poll_interval;
      bool sat_reachable;
      uint32_t sat_last_live;
      uint32_t sat_last_status;
      uint32_t sat_last_manifest;
      uint32_t config_gen;

      if (AGG_LOCK() == pdTRUE) {
        if (i >= runtime_satellite_count) {
          AGG_UNLOCK();
          break;  // Config changed, index no longer valid
        }
        SatelliteCache& sat = satellite_caches[i];
        strncpy(sat_id, sat.id, sizeof(sat_id) - 1);
        sat_id[sizeof(sat_id) - 1] = '\0';
        strncpy(sat_base_url, sat.base_url, sizeof(sat_base_url) - 1);
        sat_base_url[sizeof(sat_base_url) - 1] = '\0';
        sat_poll_interval = sat.poll_interval_seconds;
        sat_reachable = sat.reachable;
        sat_last_live = sat.last_live_fetch;
        sat_last_status = sat.last_status_fetch;
        sat_last_manifest = sat.last_manifest_fetch;
        config_gen = satellite_config_generation;
        AGG_UNLOCK();
      } else {
        continue;  // Couldn't get lock, skip this satellite
      }

      // Back off unreachable satellites to 5-minute polling (saves CPU on C3)
      uint32_t effective_interval = sat_reachable
          ? (uint32_t)sat_poll_interval
          : 300;  // 5 min for unreachable
      bool any_failed = false;

      char url_buf[256];
      uint16_t tmp_len;

      // ── Fetch /api/v2/live (every poll_interval_seconds) ──
      bool live_due = (sat_last_live == 0) ||
                      (uptime_s - sat_last_live >= effective_interval);
      if (live_due) {
        snprintf(url_buf, sizeof(url_buf), "%s/api/v2/live", sat_base_url);
        tmp_len = 0;
        if (fetch_to_buffer(url_buf, s_fetch_tmp, 2048, &tmp_len)
            && tmp_len > 0) {
          if (AGG_LOCK() == pdTRUE) {
            // Verify config unchanged and find satellite by ID
            if (config_gen == satellite_config_generation) {
              int idx = -1;
              for (int j = 0; j < runtime_satellite_count; j++) {
                if (strcmp(satellite_caches[j].id, sat_id) == 0) {
                  idx = j;
                  break;
                }
              }
              if (idx >= 0) {
                SatelliteCache& sat = satellite_caches[idx];
                bool was_unreachable = !sat.reachable;
                memcpy(sat.live_json, s_fetch_tmp, tmp_len + 1);
                sat.live_len = tmp_len;
                sat.last_live_fetch = uptime_s;
                sat.reachable = true;
                sat.consecutive_failures = 0;
                sat.last_seen_epoch = epoch_now;
                if (was_unreachable) {
                  ESP_LOGI(TAG_AGG, "[%s] recovered (was unreachable)", sat_id);
                }
                ESP_LOGI(TAG_AGG, "[%s] live: %u bytes", sat_id, (unsigned)tmp_len);
              } else {
                ESP_LOGW(TAG_AGG, "[%s] satellite removed during fetch, discarding live data", sat_id);
              }
            } else {
              ESP_LOGW(TAG_AGG, "[%s] config changed during fetch (gen %u->%u), discarding live data",
                       sat_id, config_gen, satellite_config_generation);
            }
            AGG_UNLOCK();
          }
        } else {
          any_failed = true;
          ESP_LOGW(TAG_AGG, "[%s] live fetch failed", sat_id);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
      }

      // ── Fetch /api/status (every poll_interval_seconds) ──
      bool status_due = (sat_last_status == 0) ||
                        (uptime_s - sat_last_status >= effective_interval);
      if (status_due) {
        const char *status_basic_auth =
            (s_status_basic_auth_b64[0] != '\0') ? s_status_basic_auth_b64 : nullptr;
        snprintf(url_buf, sizeof(url_buf), "%s/api/status/full", sat_base_url);
        tmp_len = 0;
        if (fetch_to_buffer(url_buf, s_fetch_tmp, static_cast<uint16_t>(sizeof(satellite_caches[0].status_json)), &tmp_len,
                            5, nullptr, status_basic_auth)
            && tmp_len > 0) {
          if (AGG_LOCK() == pdTRUE) {
            // Verify config unchanged and find satellite by ID
            if (config_gen == satellite_config_generation) {
              int idx = -1;
              for (int j = 0; j < runtime_satellite_count; j++) {
                if (strcmp(satellite_caches[j].id, sat_id) == 0) {
                  idx = j;
                  break;
                }
              }
              if (idx >= 0) {
                SatelliteCache& sat = satellite_caches[idx];
                memcpy(sat.status_json, s_fetch_tmp, tmp_len + 1);
                sat.status_len = tmp_len;
                sat.last_status_fetch = uptime_s;
                ESP_LOGI(TAG_AGG, "[%s] status: %u bytes", sat_id, (unsigned)tmp_len);
              } else {
                ESP_LOGW(TAG_AGG, "[%s] satellite removed during fetch, discarding status data", sat_id);
              }
            } else {
              ESP_LOGW(TAG_AGG, "[%s] config changed during fetch, discarding status data", sat_id);
            }
            AGG_UNLOCK();
          }
        } else {
          any_failed = true;
          ESP_LOGW(TAG_AGG, "[%s] status fetch failed", sat_id);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
      }

      // ── Fetch /api/manifest (every 5 minutes) ──
      bool manifest_due = (sat_last_manifest == 0) ||
                          (uptime_s - sat_last_manifest >= 300);
      if (manifest_due) {
        snprintf(url_buf, sizeof(url_buf), "%s/api/manifest", sat_base_url);
        tmp_len = 0;
        if (fetch_to_buffer(url_buf, s_fetch_tmp, (uint16_t)AGG_MANIFEST_BUF_SIZE, &tmp_len)
            && tmp_len > 0) {
          if (AGG_LOCK() == pdTRUE) {
            // Verify config unchanged and find satellite by ID
            if (config_gen == satellite_config_generation) {
              int idx = -1;
              for (int j = 0; j < runtime_satellite_count; j++) {
                if (strcmp(satellite_caches[j].id, sat_id) == 0) {
                  idx = j;
                  break;
                }
              }
              if (idx >= 0) {
                SatelliteCache& sat = satellite_caches[idx];
                memcpy(sat.manifest_json, s_fetch_tmp, tmp_len + 1);
                sat.manifest_len = tmp_len;
                sat.last_manifest_fetch = uptime_s;
                ESP_LOGI(TAG_AGG, "[%s] manifest: %u bytes", sat_id, (unsigned)tmp_len);
              } else {
                ESP_LOGW(TAG_AGG, "[%s] satellite removed during fetch, discarding manifest data", sat_id);
              }
            } else {
              ESP_LOGW(TAG_AGG, "[%s] config changed during fetch, discarding manifest data", sat_id);
            }
            AGG_UNLOCK();
          }
        } else {
          any_failed = true;
          ESP_LOGW(TAG_AGG, "[%s] manifest fetch failed", sat_id);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
      }

      // ── Update reachability after fetch failures ──
      if (any_failed) {
        uint8_t failures = 0;
        if (AGG_LOCK() == pdTRUE) {
          // Verify config unchanged and find satellite by ID
          if (config_gen == satellite_config_generation) {
            int idx = -1;
            for (int j = 0; j < runtime_satellite_count; j++) {
              if (strcmp(satellite_caches[j].id, sat_id) == 0) {
                idx = j;
                break;
              }
            }
            if (idx >= 0) {
              SatelliteCache& sat = satellite_caches[idx];
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
              if (failures >= 3) {
                ESP_LOGW(TAG_AGG, "[%s] unreachable (failures=%u)",
                         sat_id, (unsigned)failures);
              }
            }
          }
          AGG_UNLOCK();
        }
      }

      // Stagger between satellites to avoid simultaneous connections
      if (i + 1 < runtime_satellite_count) {
        vTaskDelay(pdMS_TO_TICKS(2000));
      }
    }

    // Sleep until next poll cycle
    vTaskDelay(pdMS_TO_TICKS(5000));
  }
}

// ── Deferred management task: reset-satellites ────────────────────────────
// Runs NVS-heavy satellite reset on its own 8 KB stack so the httpd task
// (hardcoded 4 KB by ESPHome/ESP-IDF) is never exposed to NVS frames.

static volatile bool s_reset_satellites_in_progress = false;
static volatile bool s_nvs_save_in_progress = false;

static void reset_satellites_task_(void *) {
  // Erase the NVS satellite namespace
  nvs_handle_t nvs;
  esp_err_t err = nvs_open("agg_sats", NVS_READWRITE, &nvs);
  if (err == ESP_OK) {
    err = nvs_erase_all(nvs);
    if (err == ESP_OK) nvs_commit(nvs);
    nvs_close(nvs);
    if (err != ESP_OK) {
      ESP_LOGE(TAG_AGG, "reset_sats task: NVS erase/commit failed (%s)",
               esp_err_to_name(err));
    }
  } else {
    ESP_LOGE(TAG_AGG, "reset_sats task: NVS open failed (%s)",
             esp_err_to_name(err));
  }

  // Reload compile-time defaults under mutex
  if (AGG_LOCK() == pdTRUE) {
    for (int i = 0; i < MAX_SATELLITES; i++) {
      satellite_caches[i].set_identity(
          SATELLITE_IDS[i], SATELLITE_NAMES[i],
          SATELLITE_URLS[i], SATELLITE_POLL_INTERVALS[i]);
      satellite_caches[i].clear_cache();
    }
    runtime_satellite_count = MAX_SATELLITES;
    satellite_config_generation++;  // Config changed — invalidate in-flight poll operations
    if (!save_satellites_to_nvs_()) {
      ESP_LOGW(TAG_AGG, "reset_sats task: failed to persist defaults (non-fatal)");
    }
    AGG_UNLOCK();
  } else {
    ESP_LOGE(TAG_AGG, "reset_sats task: failed to acquire AGG_LOCK");
  }

  ESP_LOGI(TAG_AGG, "Factory reset complete: %d compile-time satellites restored",
           MAX_SATELLITES);
  s_reset_satellites_in_progress = false;
  vTaskDelete(nullptr);
}

static void schedule_reset_satellites_() {
  BaseType_t ret = xTaskCreate(reset_satellites_task_, "agg_reset_sats", 8192, nullptr, 1, nullptr);
  if (ret != pdPASS) {
    ESP_LOGE(TAG_AGG, "schedule_reset_satellites_: xTaskCreate failed (ret=%d)", (int)ret);
    s_reset_satellites_in_progress = false;
  }
}

static void save_satellites_nvs_task_(void *param) {
  SatelliteNVSSnapshot* snapshot = static_cast<SatelliteNVSSnapshot*>(param);
  if (snapshot) {
    save_satellites_snapshot_to_nvs_(snapshot);
    delete snapshot;
  }
  s_nvs_save_in_progress = false;
  vTaskDelete(nullptr);
}

static void schedule_save_satellites_nvs_() {
  if (s_nvs_save_in_progress) {
    ESP_LOGW(TAG_AGG, "schedule_save_satellites_nvs_: save already in progress, skipping");
    return;
  }
  s_nvs_save_in_progress = true;

  // Capture snapshot under lock
  SatelliteNVSSnapshot* snapshot = new SatelliteNVSSnapshot();
  if (!snapshot) {
    ESP_LOGE(TAG_AGG, "schedule_save_satellites_nvs_: failed to allocate snapshot");
    s_nvs_save_in_progress = false;
    return;
  }

  if (AGG_LOCK() == pdTRUE) {
    snapshot->count = runtime_satellite_count;
    for (int i = 0; i < runtime_satellite_count; i++) {
      strncpy(snapshot->satellites[i].id, satellite_caches[i].id, sizeof(snapshot->satellites[i].id) - 1);
      snapshot->satellites[i].id[sizeof(snapshot->satellites[i].id) - 1] = '\0';
      strncpy(snapshot->satellites[i].name, satellite_caches[i].name, sizeof(snapshot->satellites[i].name) - 1);
      snapshot->satellites[i].name[sizeof(snapshot->satellites[i].name) - 1] = '\0';
      strncpy(snapshot->satellites[i].url, satellite_caches[i].base_url, sizeof(snapshot->satellites[i].url) - 1);
      snapshot->satellites[i].url[sizeof(snapshot->satellites[i].url) - 1] = '\0';
      snapshot->satellites[i].poll_interval_seconds = satellite_caches[i].poll_interval_seconds;
    }
    AGG_UNLOCK();
  } else {
    ESP_LOGE(TAG_AGG, "schedule_save_satellites_nvs_: failed to acquire lock");
    delete snapshot;
    s_nvs_save_in_progress = false;
    return;
  }

  BaseType_t ret = xTaskCreate(save_satellites_nvs_task_, "agg_nvs_save", 8192, snapshot, 1, nullptr);
  if (ret != pdPASS) {
    ESP_LOGE(TAG_AGG, "schedule_save_satellites_nvs_: xTaskCreate failed (ret=%d)", (int)ret);
    delete snapshot;
    s_nvs_save_in_progress = false;
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
  ESP_LOGI(TAG_AGG, "Aggregator polling task started (init pending)");
}

#endif  // AGGREGATOR_ENABLED


// ═══════════════════════════════════════════════════════════════════
// HistoryWebHandler — custom endpoints on ESPHome web server
// ═══════════════════════════════════════════════════════════════════

static volatile bool s_import_ready = false;

#if AGGREGATOR_ENABLED
static constexpr int MAX_PROBE_COOLDOWN = MAX_SATELLITES;
static uint32_t s_last_probe_fail_epoch[MAX_PROBE_COOLDOWN] = {};
static char s_last_probe_fail_url[MAX_PROBE_COOLDOWN][128] = {};
#endif

class HistoryWebHandler : public AsyncWebHandler {
 public:
  HistoryWebHandler(std::string username, std::string password, std::string version)
      : mgmt_username_(std::move(username)),
        mgmt_password_(std::move(password)),
        firmware_version_(std::move(version)) {}

  bool is_management_post_route_(const char *p) const {
    if (strcmp(p, "/api/reboot") == 0) return true;
    if (strcmp(p, "/api/delete-data") == 0) return true;
#if AGGREGATOR_ENABLED
    if (strcmp(p, "/api/system/reset-satellites") == 0) return true;
    if (strncmp(p, "/api/aggregator/add-satellite", sizeof("/api/aggregator/add-satellite") - 1) == 0) return true;
    if (strncmp(p, "/api/aggregator/test-satellite", sizeof("/api/aggregator/test-satellite") - 1) == 0) return true;
#endif
    return false;
  }

  bool is_post_or_options_route_(const char *p) const {
    if (is_management_post_route_(p)) return true;
    if (strcmp(p, "/api/import/begin") == 0) return true;
    if (strncmp(p, "/api/import/begin/single/", sizeof("/api/import/begin/single/") - 1) == 0) return true;
    if (strncmp(p, "/api/import/d/", sizeof("/api/import/d/") - 1) == 0) return true;
    if (strncmp(p, "/api/import/w/", sizeof("/api/import/w/") - 1) == 0) return true;
    if (strcmp(p, "/api/import/finish") == 0) return true;
#if AGGREGATOR_ENABLED
    // DELETE routes also need OPTIONS for CORS preflight
    if (strncmp(p, "/api/aggregator/satellite/", sizeof("/api/aggregator/satellite/") - 1) == 0) return true;
#endif
    return false;
  }

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
      if (strcmp(p, "/api/status/full") == 0) return true;
      if (strcmp(p, "/api/status") == 0) return true;
      if (strcmp(p, "/api/import/status") == 0) return true;
      if (strcmp(p, "/api/v2/live") == 0) return true;
      if (len >= 20 && strncmp(p, "/api/v2/history/", 16) == 0) return true;
      if (strcmp(p, "/favicon.ico") == 0) return true;
#if AGGREGATOR_ENABLED
      if (strcmp(p, "/api/aggregator/gateways") == 0) return true;
      if (strcmp(p, "/api/aggregator/live") == 0) return true;
      if (len > 22 && strncmp(p, "/api/aggregator/proxy/", 22) == 0) return true;
      // Accept GET so handler can return 405 Method Not Allowed (BUG-078 T4 fix)
      if (strncmp(p, "/api/aggregator/add-satellite", sizeof("/api/aggregator/add-satellite") - 1) == 0) return true;
      if (strncmp(p, AGGREGATOR_TEST_SATELLITE_ROUTE, AGGREGATOR_TEST_SATELLITE_ROUTE_LEN) == 0) return true;
      if (strncmp(p, "/api/aggregator/satellite/",
                  AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN) == 0) return true;
#endif
      return false;
    }

    if (request->method() == HTTP_OPTIONS) {
      return is_post_or_options_route_(p);
    }

    if (request->method() == HTTP_POST) {
#if AGGREGATOR_ENABLED
      // Accept POST on DELETE-only route so handler can return 405
      if (strncmp(p, "/api/aggregator/satellite/",
                  AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN) == 0) return true;
#endif
      return is_post_or_options_route_(p);
    }

#if AGGREGATOR_ENABLED
    if (request->method() == HTTP_DELETE) {
      if (strncmp(p, "/api/aggregator/satellite/",
                  AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN) == 0) return true;
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
      if (is_management_post_route_(p) && request->contentLength() == 0) {
        send_json_error_(request, 400, "Non-empty body required for management POST");
        return;
      }
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
      if (strcmp(p, "/api/system/reset-satellites") == 0) {
        handle_reset_satellites_(request);
        return;
      }
      if (strncmp(p, "/api/aggregator/add-satellite", 29) == 0) {
        handle_add_satellite_(request);
        return;
      }
      if (strncmp(p, AGGREGATOR_TEST_SATELLITE_ROUTE,
                  AGGREGATOR_TEST_SATELLITE_ROUTE_LEN) == 0) {
        handle_test_satellite_(request);
        return;
      }
      if (strncmp(p, "/api/aggregator/satellite/",
                  AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN) == 0) {
        handle_delete_satellite_(request);
        return;
      }
#endif
      request->send(404);
      return;
    }

#if AGGREGATOR_ENABLED
    if (request->method() == HTTP_DELETE) {
      if (strncmp(p, "/api/aggregator/satellite/",
                  AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN) == 0) {
        handle_delete_satellite_(request);
        return;
      }
      request->send(404);
      return;
    }
#endif
    // Route GET to POST-only aggregator endpoints — handlers return 405 (BUG-078 T4)
#if AGGREGATOR_ENABLED
      if (strncmp(p, "/api/aggregator/add-satellite", 29) == 0) {
        handle_add_satellite_(request);
        return;
      }
      if (strncmp(p, AGGREGATOR_TEST_SATELLITE_ROUTE,
                  AGGREGATOR_TEST_SATELLITE_ROUTE_LEN) == 0) {
        handle_test_satellite_(request);
        return;
      }
      if (strncmp(p, "/api/aggregator/satellite/",
                  AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN) == 0) {
      handle_delete_satellite_(request);
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
    if (strcmp(p, "/api/status/full") == 0) {
      handle_status_full_(request);
      return;
    }
    if (strcmp(p, "/api/status") == 0) {
      handle_status_(request);
      return;
    }
    if (strcmp(p, "/api/import/status") == 0) {
      const bool ready = import_active_ && s_import_ready && !import_prepare_active_;
      std::string body = ready ? "{\"ready\":true}" : "{\"ready\":false}";
      auto *resp = request->beginResponse(200, "application/json", body);
      add_common_headers_(resp);
      request->send(resp);
      return;
    }
    if (strcmp(p, "/api/manifest") == 0) {
      handle_api_manifest_(request);
      return;
    }
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
  mutable volatile bool import_prepare_active_{false};

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
    resp->addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS, DELETE");
    resp->addHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  }

  static std::string json_escape_(const char *value) {
    std::string escaped;
    if (value == nullptr) return escaped;
    for (const char *p = value; *p != '\0'; ++p) {
      switch (*p) {
        case '"': escaped += "\\\""; break;
        case '\\': escaped += "\\\\"; break;
        case '\b': escaped += "\\b"; break;
        case '\f': escaped += "\\f"; break;
        case '\n': escaped += "\\n"; break;
        case '\r': escaped += "\\r"; break;
        case '\t': escaped += "\\t"; break;
        default: escaped += *p; break;
      }
    }
    return escaped;
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

  bool extract_basic_auth_(const std::string &auth_header,
                           std::string *username,
                           std::string *password) const {
    std::string auth = trim_copy_(auth_header);
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
    // Fast-path: reject requests with no Authorization header before
    // any string allocation or lockout checks to minimize httpd stack usage.
    auto auth_header = request->get_header("Authorization");
    if (!auth_header.has_value()) {
      send_json_error_(request, 401, "Management authentication required");
      return false;
    }

    int64_t now = now_ms_();
    if (lockout_until_ms_ > now) {
      uint32_t retry_after = static_cast<uint32_t>((lockout_until_ms_ - now + 999) / 1000);
      send_json_error_(request, 429, "Too many failed authentication attempts", retry_after);
      return false;
    }

    std::string username;
    std::string password;
    if (!extract_basic_auth_(auth_header.value(), &username, &password)) {
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
    // Public history endpoint used by dashboard charts and aggregator proxy paths.

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
    size_t est_bytes = (size_t)buf->count() * 20 + 64;
    // v7.6.9.4 (#139 partial): heap-adaptive cap replaces fixed 60 KB.
    // Fixed cap (v7.6.8.1 V2-E) was sized for C3 ~68 KB free heap budget.
    // On WROOM with ~30-40 KB free, a 60 KB reserve exceeds running heap and
    // crashes the board. Clamp to free_heap/3 with a 12 KB floor and the
    // original 60 KB ceiling preserved for healthy boards. Dashboard tolerates
    // truncated CSV gracefully (parseCompactHistory processes line-by-line).
    size_t free_now = esp_get_free_heap_size();
    size_t adaptive_cap = free_now / 3;
    if (adaptive_cap < 12000) adaptive_cap = 12000;
    if (adaptive_cap > 60000) adaptive_cap = 60000;

    std::string csv;
    csv.reserve(std::min(est_bytes, adaptive_cap));
    buf->append_csv_to(csv);

    auto *resp = request->beginResponse(
        200, "text/plain",
        reinterpret_cast<const uint8_t *>(csv.data()), csv.size());
    resp->addHeader("Cache-Control", "no-store");
    request->send(resp);
  }

  void handle_api_ingest_(AsyncWebServerRequest *request) const {
    // Auth: REQUIRED - write endpoint, prevents unauthenticated data injection (SEC-01)
    if (!authenticate_management_(request)) return;
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

    if (id_len == 0) {
      send_json_error_(request, 400, "Empty device ID");
      return;
    }
    if (metric_key[0] == '\0') {
      send_json_error_(request, 400, "Empty metric key");
      return;
    }

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
    std::string val_str = request->getParam("val")->value();
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

    if (s_delete_data_in_progress) {
      send_json_error_(request, 409, "Delete already in progress");
      return;
    }
    s_delete_data_in_progress = true;

    // Respond immediately — NVS erase deferred to delete_data_task_
    auto *resp = request->beginResponseStream("application/json");
    add_common_headers_(resp);
    resp->print("{\"ok\":true,\"message\":\"History clearing scheduled\"}");
    request->send(resp);

    schedule_delete_data_();
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
    import_prepare_active_ = false;
    s_import_ready = false;
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

  static void import_epoch_map_task_(void *arg) {
    auto *handler = static_cast<HistoryWebHandler*>(arg);
    if (handler == nullptr) {
      s_import_ready = false;
      vTaskDelete(nullptr);
      return;
    }

    if (!handler->build_import_epoch_map_()) {
      handler->cleanup_import_state_();
      handler->import_prepare_active_ = false;
      s_import_ready = false;
      ESP_LOGE(TAG, "Failed to build segment index for merge");
      vTaskDelete(nullptr);
      return;
    }

    handler->import_prepare_active_ = false;
    s_import_ready = true;
    ESP_LOGI(TAG, "Import epoch map ready");
    vTaskDelete(nullptr);
  }

  // import_snapshot_ (~6,710 B = sizeof(SegmentSnapshot)) is allocated on first call
  // to handle_import_begin_() and held until cleanup_import_state_() is called. If the
  // import session is abandoned (browser closed), this allocation is held until the
  // next /api/import/begin call or a reboot. This is accepted behaviour — the
  // allocation is bounded and a single session at a time is the expected pattern.
  // See Docs/decisions/SEC-ADR-001-residual-vulnerabilities.md RV-05 for rationale.
  void handle_import_begin_(AsyncWebServerRequest *request,
                            bool single_mode, int target_sensor) {
    if (!authenticate_management_(request)) return;

    if (import_prepare_active_) {
      send_json_error_(request, 409, "Import preparation already in progress");
      return;
    }

    // Clean up any leftover import state.
    cleanup_import_state_();
    s_import_ready = false;

    import_single_mode_ = single_mode;
    import_target_sensor_ = target_sensor;

    if (!single_mode) {
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

    if (single_mode) {
      import_prepare_active_ = true;
      BaseType_t created = xTaskCreate(import_epoch_map_task_, "imp_epoch",
                                       8192, (void*)this, 5, nullptr);
      if (created != pdPASS) {
        import_prepare_active_ = false;
        cleanup_import_state_();
        std::string err = "{\"ok\":false,\"message\":\"Failed to create import task\"}";
        auto *resp = request->beginResponse(500, "application/json", err.c_str());
        add_common_headers_(resp);
        request->send(resp);
        return;
      }
      ESP_LOGI(TAG, "Import begun (single-sensor: %s) - epoch map queued",
               devices[target_sensor].id);
    } else {
      s_import_ready = true;
      ESP_LOGI(TAG, "Import begun (multi) - history partition cleared");
    }

    std::string body = "{\"ok\":true,\"status\":\"queued\"}";
    auto *resp = request->beginResponse(200, "application/json", body.c_str());
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_import_data_(AsyncWebServerRequest *request,
                           const char *path_data, bool do_write) {
    if (!authenticate_management_(request)) return;

    if (!s_import_ready) {
      send_json_error_(request, 409, "Import not ready - poll /api/import/status");
      return;
    }

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

    if (import_prepare_active_) {
      send_json_error_(request, 409, "Import preparation in progress - poll /api/import/status");
      return;
    }

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
      import_prepare_active_ = false;
      s_import_ready = false;
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
      import_prepare_active_ = false;
      s_import_ready = false;
      send_json_error_(request, 500, "Failed to open NVS to finalize metadata");
      return;
    }
    bool meta_ok = save_history_meta_(handle, import_meta_);
    nvs_close(handle);

    if (!meta_ok) {
      import_active_ = false;
      import_single_mode_ = false;
      import_target_sensor_ = -1;
      import_prepare_active_ = false;
      s_import_ready = false;
      send_json_error_(request, 500, "Failed to write import metadata");
      return;
    }

    // Restore newest segments into RAM so charts work immediately.
    restore_from_nvs();

    import_active_ = false;
    import_single_mode_ = false;
    import_target_sensor_ = -1;
    import_prepare_active_ = false;
    s_import_ready = false;

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
    // Auth: NOT REQUIRED - public health check; sensitive fields moved to /api/status/full
    const char *role = "satellite";
#if AGGREGATOR_ENABLED
    role = "aggregator";
#endif

    std::string body;
    body.reserve(128);
    body += R"({"ok":true,"role":")";
    body += role;
    body += R"(","id":")";
    body += App.get_name().c_str();
    body += R"("})";

    auto *resp = request->beginResponse(200, "application/json", body);
    resp->addHeader("Cache-Control", "no-store");
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_status_full_(AsyncWebServerRequest *request) const {
    // Auth: REQUIRED - full status with heap, version, uptime, telemetry (SEC-04)
    if (!authenticate_management_(request)) return;

    const char *role = "satellite";
#if AGGREGATOR_ENABLED
    role = "aggregator";
#endif

    uint32_t uptime_s = (uint32_t) (esp_timer_get_time() / 1000000LL);
    uint32_t free_heap_internal = esp_get_free_internal_heap_size();
    uint32_t free_heap_total = esp_get_free_heap_size();
    uint32_t min_heap_bytes = esp_get_minimum_free_heap_size();
    UBaseType_t httpd_wm = uxTaskGetStackHighWaterMark(nullptr);
    uint32_t httpd_wm_bytes = (uint32_t) (httpd_wm * sizeof(StackType_t));

    std::string json;
    json.reserve(1024);
    char num[96];

    json += R"({"ok":true,"role":")";
    json += role;
    json += R"(","id":")";
    json += App.get_name().c_str();
    json += R"(","version":")";
    json += firmware_version_;
    json += R"(",)";

    snprintf(num, sizeof(num), R"("uptime_seconds":%u,"sensor_count":%d,)",
             (unsigned) uptime_s, NUM_DEVICES);
    json += num;

    json += R"("sensors":[)";
    for (int i = 0; i < NUM_DEVICES; i++) {
      if (i > 0) json += ",";
      json += R"({"id":")";
      json += devices[i].id;
      json += R"(","name":")";
      json += devices[i].name;
      const char *cat = "unknown";
      if (devices[i].category_id == 0) cat = "environmental";
      else if (devices[i].category_id == 1) cat = "system";
      else if (devices[i].category_id == 2) cat = "network";
      json += R"(","category":")";
      json += cat;
      snprintf(num, sizeof(num), R"(","last_seen":%u)",
               (unsigned) devices[i].last_seen_epoch);
      json += num;
      if (devices[i].category_id == 0) {
        snprintf(num, sizeof(num), R"(,"temp_valid":%s,"hum_valid":%s)",
                 devices[i].temp_valid ? "true" : "false",
                 devices[i].hum_valid ? "true" : "false");
        json += num;
      }
      json += "}";
    }
    json += "],";

    snprintf(num, sizeof(num), R"("ram_history_points_per_series":%d,)",
             HISTORY_POINTS_PER_SERIES);
    json += num;
    snprintf(num, sizeof(num), R"("persist_days":%d,)", PERSIST_DAYS);
    json += num;
    snprintf(num, sizeof(num), R"("free_heap":%u,)", (unsigned) free_heap_internal);
    json += num;
    snprintf(num, sizeof(num), R"("free_heap_internal":%u,)", (unsigned) free_heap_internal);
    json += num;
    snprintf(num, sizeof(num), R"("free_heap_total":%u,)", (unsigned) free_heap_total);
    json += num;
    snprintf(num, sizeof(num), R"("min_free_heap":%u,)", (unsigned) min_heap_bytes);
    json += num;
    snprintf(num, sizeof(num), R"("httpd_stack_watermark_bytes":%u,)", (unsigned) httpd_wm_bytes);
    json += num;
    snprintf(num, sizeof(num), R"("ping_stack_watermark_bytes":%u})",
             (unsigned) g_ping_stack_watermark_bytes);
    json += num;

    auto *resp = request->beginResponse(200, "application/json", json);
    resp->addHeader("Cache-Control", "no-store");
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_history_(AsyncWebServerRequest *request, const char *rest) const {
    // Public history endpoint used by the embedded dashboard.

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
    // v7.6.9.4 (#139 partial): heap-adaptive cap replaces fixed 60 KB.
    // Fixed cap (v7.6.8.1 V2-E) was sized for C3 ~68 KB free heap budget.
    // On WROOM with ~30-40 KB free, a 60 KB reserve exceeds running heap and
    // crashes the board. Clamp to free_heap/3 with a 12 KB floor and the
    // original 60 KB ceiling preserved for healthy boards. Dashboard tolerates
    // truncated CSV gracefully (parseCompactHistory processes line-by-line).
    size_t free_now = esp_get_free_heap_size();
    size_t adaptive_cap = free_now / 3;
    if (adaptive_cap < 12000) adaptive_cap = 12000;
    if (adaptive_cap > 60000) adaptive_cap = 60000;

    std::string csv;
    csv.reserve(std::min(est_bytes, adaptive_cap));

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
    // Auth: REQUIRED - topology disclosure prevention (SEC-03)
    if (!authenticate_management_(request)) return;
    if (xSemaphoreTake(s_cache_mutex, pdMS_TO_TICKS(100)) != pdTRUE) {
      request->send(503);
      return;
    }
    // LESSON-OPS-056: pre-reserve string to avoid reallocation
    // Manifest JSON can be up to AGG_MANIFEST_BUF_SIZE bytes per satellite.
    std::string out;
    size_t reserve_size = 32;
    for (int ri = 0; ri < runtime_satellite_count; ri++) {
      reserve_size += 512 + satellite_caches[ri].manifest_len;
    }
    out.reserve(reserve_size);
    out += "{\"gateways\":[";
    for (int i = 0; i < runtime_satellite_count; i++) {
      if (i > 0) out += ",";
      const SatelliteCache& sat = satellite_caches[i];
      char tmp[128];
      char hostname[64] = "";
      char ip[48] = "";
      const char* gw_obj = strstr(sat.manifest_json, "\"gateway\"");
      if (gw_obj) {
        const char* gw_end = strchr(gw_obj + 9, '}');
        if (!gw_end) gw_end = sat.manifest_json + sat.manifest_len;

        const char* id_key = strstr(gw_obj, "\"id\"");
        if (id_key && id_key < gw_end) {
          const char* p = id_key + 4;
          while (p < gw_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
          if (p < gw_end && *p == ':') {
            ++p;
            while (p < gw_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
            if (p < gw_end && *p == '"') {
              const char* id_val = p + 1;
              const char* id_end = strchr(id_val, '"');
              if (id_end && id_end <= gw_end &&
                  (id_end - id_val) < static_cast<ptrdiff_t>(sizeof(hostname))) {
                memcpy(hostname, id_val, static_cast<size_t>(id_end - id_val));
                hostname[id_end - id_val] = '\0';
              }
            }
          }
        }
      }
      if (strncmp(sat.base_url, "http://", 7) == 0) {
        const char* host_start = sat.base_url + 7;
        const char* host_end = strpbrk(host_start, ":/");
        size_t ip_len = host_end ? static_cast<size_t>(host_end - host_start) : strlen(host_start);
        if (ip_len < sizeof(ip)) {
          memcpy(ip, host_start, ip_len);
          ip[ip_len] = '\0';
        }
      }
      out += "{\"id\":\"";   out += sat.id;
      out += "\",\"name\":\""; out += sat.name;
      out += "\",\"hostname\":\""; out += json_escape_(hostname);
      out += "\",\"ip\":\""; out += json_escape_(ip);
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
      // Include cached manifest JSON for per-gateway device rendering.
      // BUG-074: detect truncated manifests — if manifest_len >= AGG_MANIFEST_BUF_SIZE - 1,
      // the JSON was likely cut off by fetch_to_buffer() and is not valid JSON.
      if (sat.manifest_len > 0) {
        if (sat.manifest_len >= AGG_MANIFEST_BUF_SIZE - 1) {
          ESP_LOGW(TAG_AGG, "Satellite %s manifest truncated (%u bytes >= %u limit), omitting",
                   sat.id, (unsigned)sat.manifest_len, (unsigned)AGG_MANIFEST_BUF_SIZE);
          out += ",\"manifest\":null";
        } else {
          out += ",\"manifest\":";
          out.append(sat.manifest_json, sat.manifest_len);
        }
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
    // Auth: REQUIRED - aggregator live sensor data protection (SEC-03)
    if (!authenticate_management_(request)) return;
    if (xSemaphoreTake(s_cache_mutex, pdMS_TO_TICKS(100)) != pdTRUE) {
      request->send(503);
      return;
    }
    // LESSON-OPS-056: pre-reserve string (runtime_satellite_count * live_json max ~2048)
    std::string out;
    out.reserve(runtime_satellite_count * 2304 + 64);
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "{\"timestamp\":%u,\"gateways\":{",
             (unsigned)::time(nullptr));
    out += tmp;
    for (int i = 0; i < runtime_satellite_count; i++) {
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
    // Auth: REQUIRED - proxy history data protection (SEC-03)
    if (!authenticate_management_(request)) return;
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
    for (int i = 0; i < runtime_satellite_count; i++) {
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
    int satellite_http_status = 0;
    static_assert(sizeof(s_proxy_tmp) <= 65535,
                  "s_proxy_tmp size must fit into uint16_t for fetch_to_buffer");
    const char *proxy_basic_auth =
        (s_status_basic_auth_b64[0] != '\0') ? s_status_basic_auth_b64 : nullptr;
    if (!fetch_to_buffer(url, s_proxy_tmp,
                         static_cast<uint16_t>(sizeof(s_proxy_tmp)),
                         &s_proxy_len,
                         15,
                         &satellite_http_status,
                         proxy_basic_auth)) {
      ESP_LOGW(TAG, "Proxy fetch failed for %s (HTTP %d)", url, satellite_http_status);
      std::string err_body = std::string("{\"error\":\"upstream_fetch_failed\",\"url\":\"") +
                             json_escape_(url) + "\",\"http_status\":" +
                             std::to_string(satellite_http_status) + "}";
      auto *resp = request->beginResponse(502, "application/json", err_body);
      add_common_headers_(resp);
      request->send(resp);
      return;
    }

    // Satellite returned 200 but has no history data.
    if (s_proxy_len == 0) {
      auto *resp = request->beginResponse(200, "text/plain", "");
      add_common_headers_(resp);
      request->send(resp);
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

  // POST /api/aggregator/add-satellite (v7.6.0.1)
  void handle_add_satellite_(AsyncWebServerRequest *request) const {
    // Auth: REQUIRED - topology-modifying write endpoint (SEC-02)
    if (!authenticate_management_(request)) return;
    if (request->method() != HTTP_POST) {
      send_json_error_(request, 405, "Method not allowed");
      return;
    }

    // 1. Parse query params
    if (!request->hasParam("url")) {
      send_json_error_(request, 400, "Missing url parameter");
      return;
    }
    std::string url_param = request->getParam("url")->value();
    const char* url_str = url_param.c_str();

    // 2. Validate URL format
    if (strncmp(url_str, "http://", 7) != 0) {
      send_json_error_(request, 400, "URL must start with http://");
      return;
    }

    // Validate URL length fits the destination buffer (url_buf[128])
    if (strlen(url_str) >= 128) {
      send_json_error_(request, 400, "URL too long (max 127 characters)");
      return;
    }

    // Per-URL probe cooldown: repeated failures for the same URL must wait 60s.
    uint32_t now = (uint32_t)::time(nullptr);
    for (int i = 0; i < MAX_PROBE_COOLDOWN; i++) {
      if (s_last_probe_fail_url[i][0] == '\0') continue;
      if (strcmp(s_last_probe_fail_url[i], url_str) != 0) continue;
      uint32_t elapsed = now - s_last_probe_fail_epoch[i];
      if (elapsed < 60) {
        send_json_error_(request, 429,
                         "Too many requests for this URL",
                         static_cast<uint32_t>(60 - elapsed));
        return;
      }
    }

    // 3. Probe the candidate
    char probe_id[32] = {0};
    char probe_name[64] = {0};
    if (!probe_satellite_manifest_(url_str, probe_id, sizeof(probe_id),
                                    probe_name, sizeof(probe_name))) {
      int slot = -1;
      int empty_slot = -1;
      int oldest_slot = -1;
      uint32_t oldest_epoch = 0xFFFFFFFFu;
      for (int i = 0; i < MAX_PROBE_COOLDOWN; i++) {
        if (s_last_probe_fail_url[i][0] != '\0' &&
            strcmp(s_last_probe_fail_url[i], url_str) == 0) {
          slot = i;
          break;
        }
        if (s_last_probe_fail_url[i][0] == '\0') {
          if (empty_slot < 0) empty_slot = i;
          continue;
        }
        if (s_last_probe_fail_epoch[i] < oldest_epoch) {
          oldest_epoch = s_last_probe_fail_epoch[i];
          oldest_slot = i;
        }
      }
      if (slot < 0) {
        slot = (empty_slot >= 0) ? empty_slot : oldest_slot;
      }
      if (slot >= 0) {
        s_last_probe_fail_epoch[slot] = now;
        strncpy(s_last_probe_fail_url[slot], url_str, sizeof(s_last_probe_fail_url[slot]) - 1);
        s_last_probe_fail_url[slot][sizeof(s_last_probe_fail_url[slot]) - 1] = '\0';
      }
      send_json_error_(request, 400, "Satellite unreachable or invalid manifest");
      return;
    }

    // 4. Determine name: request param > manifest > derived from URL host[:port]
    char final_name[64];
    if (request->hasParam("name") && request->getParam("name")->value().length() > 0) {
      strncpy(final_name, request->getParam("name")->value().c_str(), sizeof(final_name) - 1);
      final_name[sizeof(final_name) - 1] = '\0';
    } else if (probe_name[0] != '\0') {
      strncpy(final_name, probe_name, sizeof(final_name) - 1);
      final_name[sizeof(final_name) - 1] = '\0';
    } else {
      // URL-derived fallback: extract host[:port] from "http://host[:port][/path][?query][#fragment]"
      constexpr size_t kHttpPrefixLen = sizeof("http://") - 1;
      const char* host_start = url_str + kHttpPrefixLen;  // URL format validated above
      const char* host_end = host_start + strlen(host_start);
      const char* slash = strchr(host_start, '/');
      const char* qmark = strchr(host_start, '?');
      const char* hash  = strchr(host_start, '#');
      if (slash && slash < host_end) host_end = slash;
      if (qmark && qmark < host_end) host_end = qmark;
      if (hash  && hash  < host_end) host_end = hash;
      size_t host_len = (size_t)(host_end - host_start);
      if (host_len == 0) {
        strncpy(final_name, "Satellite", sizeof(final_name) - 1);
        final_name[sizeof(final_name) - 1] = '\0';
      } else {
        if (host_len >= sizeof(final_name)) host_len = sizeof(final_name) - 1;
        memcpy(final_name, host_start, host_len);
        final_name[host_len] = '\0';
      }
    }

    // 5. Parse poll interval
    int poll_s = 30;
    if (request->hasParam("poll")) {
      long p = strtol(request->getParam("poll")->value().c_str(), nullptr, 10);
      if (p >= 10 && p <= 3600) poll_s = (int)p;
    }

    // 6. Add under mutex
    int new_idx = -1;
    if (AGG_LOCK() == pdTRUE) {
      // Re-validate capacity and duplicate under lock (TOCTOU protection)
      if (runtime_satellite_count >= MAX_SATELLITES) {
        AGG_UNLOCK();
        send_json_error_(request, 409, "Satellite list full");
        return;
      }
      for (int i = 0; i < runtime_satellite_count; i++) {
        if (strcmp(satellite_caches[i].base_url, url_str) == 0) {
          AGG_UNLOCK();
          send_json_error_(request, 409, "URL already configured");
          return;
        }
      }
      // Safe to proceed
      new_idx = runtime_satellite_count;
      satellite_caches[new_idx].set_identity(probe_id, final_name, url_str, poll_s);
      satellite_caches[new_idx].clear_cache();
      runtime_satellite_count++;
      satellite_config_generation++;  // Config changed — invalidate in-flight poll operations
      AGG_UNLOCK();
    } else {
      send_json_error_(request, 503, "Mutex timeout");
      return;
    }

    // 7. Persist to NVS (outside mutex — NVS operations can be slow)
    if (!save_single_satellite_to_nvs_(new_idx)) {
      ESP_LOGE(TAG_AGG, "Failed to persist satellite[%d] to NVS — rolling back", new_idx);
      // Roll back the runtime state: clear the slot and decrement count
      if (AGG_LOCK() == pdTRUE) {
        satellite_caches[new_idx].clear_cache();
        satellite_caches[new_idx].set_identity("", "", "", 30);
        runtime_satellite_count--;
        satellite_config_generation++;  // Config changed — invalidate in-flight poll operations
        AGG_UNLOCK();
      }
      send_json_error_(request, 500, "Failed to persist satellite to NVS");
      return;
    }

    ESP_LOGI(TAG_AGG, "Added satellite[%d]: id=%s name=%s url=%s poll=%ds",
             new_idx, probe_id, final_name, url_str, poll_s);

    // 8. Success response
    // Buffer sized for worst-case: framing(50) + id(31) + name(63) + url(127) + poll(4) + margin
    char body[512];
    snprintf(body, sizeof(body),
             "{\"ok\":true,\"satellite\":{\"id\":\"%s\",\"name\":\"%s\",\"url\":\"%s\",\"poll\":%d}}",
             satellite_caches[new_idx].id,
             satellite_caches[new_idx].name,
             satellite_caches[new_idx].base_url,
             poll_s);
    auto *resp = request->beginResponse(200, "application/json", body);
    add_common_headers_(resp);
    request->send(resp);
  }

  void handle_delete_satellite_(AsyncWebServerRequest *request) {
    if (request->method() != HTTP_DELETE) {
      send_json_error_(request, 405, "Method not allowed");
      return;
    }

    if (!authenticate_management_(request)) return;

    char url_buf[AsyncWebServerRequest::URL_BUF_SIZE];
    auto url = request->url_to(url_buf);
    const char* p = url.c_str();
    const char* id_start = p + AGGREGATOR_SATELLITE_ROUTE_PREFIX_LEN;
    if (*id_start == '\0') {
      send_json_error_(request, 400, "Missing satellite ID");
      return;
    }

    int del_idx = -1;
    if (AGG_LOCK() == pdTRUE) {
      for (int i = 0; i < runtime_satellite_count; i++) {
        if (strcmp(satellite_caches[i].id, id_start) == 0) {
          del_idx = i;
          break;
        }
      }

      if (del_idx < 0) {
        AGG_UNLOCK();
        send_json_error_(request, 404, "Unknown satellite ID");
        return;
      }

      ESP_LOGI(TAG_AGG, "Deleting satellite[%d]: id=%s", del_idx, satellite_caches[del_idx].id);

      for (int j = del_idx; j < runtime_satellite_count - 1; j++) {
        satellite_caches[j].set_identity(
            satellite_caches[j + 1].id,
            satellite_caches[j + 1].name,
            satellite_caches[j + 1].base_url,
            satellite_caches[j + 1].poll_interval_seconds);
        memcpy(satellite_caches[j].manifest_json, satellite_caches[j + 1].manifest_json,
               satellite_caches[j + 1].manifest_len + 1);
        satellite_caches[j].manifest_len = satellite_caches[j + 1].manifest_len;
        memcpy(satellite_caches[j].live_json, satellite_caches[j + 1].live_json,
               satellite_caches[j + 1].live_len + 1);
        satellite_caches[j].live_len = satellite_caches[j + 1].live_len;
        memcpy(satellite_caches[j].status_json, satellite_caches[j + 1].status_json,
               satellite_caches[j + 1].status_len + 1);
        satellite_caches[j].status_len = satellite_caches[j + 1].status_len;
        satellite_caches[j].last_manifest_fetch = satellite_caches[j + 1].last_manifest_fetch;
        satellite_caches[j].last_live_fetch = satellite_caches[j + 1].last_live_fetch;
        satellite_caches[j].last_status_fetch = satellite_caches[j + 1].last_status_fetch;
        satellite_caches[j].reachable = satellite_caches[j + 1].reachable;
        satellite_caches[j].last_seen_epoch = satellite_caches[j + 1].last_seen_epoch;
        satellite_caches[j].consecutive_failures = satellite_caches[j + 1].consecutive_failures;
      }

      int last = runtime_satellite_count - 1;
      satellite_caches[last].id_buf[0] = '\0';
      satellite_caches[last].name_buf[0] = '\0';
      satellite_caches[last].url_buf[0] = '\0';
      satellite_caches[last].id = satellite_caches[last].id_buf;
      satellite_caches[last].name = satellite_caches[last].name_buf;
      satellite_caches[last].base_url = satellite_caches[last].url_buf;
      satellite_caches[last].poll_interval_seconds = 0;
      satellite_caches[last].clear_cache();

      runtime_satellite_count--;
      satellite_config_generation++;  // Config changed — invalidate in-flight poll operations
      AGG_UNLOCK();
    } else {
      send_json_error_(request, 503, "Mutex timeout");
      return;
    }

    auto *resp = request->beginResponse(200, "application/json", "{\"ok\":true}");
    add_common_headers_(resp);
    request->send(resp);

    schedule_save_satellites_nvs_();
  }

  // POST /api/aggregator/test-satellite (v7.6.0.3)
  // Probe a candidate URL without adding it — no side effects, no NVS writes.
  void handle_test_satellite_(AsyncWebServerRequest *request) const {
    if (request->method() != HTTP_POST) {
      send_json_error_(request, 405, "Method not allowed");
      return;
    }
    if (!authenticate_management_(request)) return;

    if (!request->hasParam("url")) {
      send_json_error_(request, 400, "Missing url parameter");
      return;
    }
    std::string url_param(request->getParam("url")->value().c_str());
    const char* url_str = url_param.c_str();

    if (strncmp(url_str, "http://", 7) != 0) {
      send_json_error_(request, 400, "URL must start with http://");
      return;
    }
    if (strlen(url_str) > 200) {  // 200 + strlen(\"/api/manifest\") < sizeof(url_buf) in probe
      send_json_error_(request, 400, "URL too long");
      return;
    }

    // Probe — no side effects
    char probe_id[32] = {0};
    char probe_name[64] = {0};
    if (!probe_satellite_manifest_(url_str, probe_id, sizeof(probe_id),
                                    probe_name, sizeof(probe_name))) {
      send_json_error_(request, 400, "Satellite unreachable or invalid manifest");
      return;
    }

    // s_proxy_tmp still contains the manifest — extract additional fields
    /*
     * s_proxy_tmp is safe to read here without a mutex — ESP-IDF's httpd task
     * processes requests sequentially (single-threaded). The buffer was populated
     * by probe_satellite_manifest_() above and will not be modified until the
     * next request is dispatched.
     */
    char hw_str[32] = "unknown";
    const char* manifest_end = s_proxy_tmp + strlen(s_proxy_tmp);
    const char* hw_key = strstr(s_proxy_tmp, "\"hardware\"");
    if (hw_key) {
      const char* p = hw_key + 10;  // skip past "hardware"
      while (p < manifest_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
      if (p < manifest_end && *p == ':') {
        ++p;
        while (p < manifest_end && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) ++p;
        if (p < manifest_end && *p == '"') {
          const char* hw_val = p + 1;
          const char* hw_end = strchr(hw_val, '"');
          if (hw_end) {
            size_t len = (size_t)(hw_end - hw_val);
            if (len >= sizeof(hw_str)) len = sizeof(hw_str) - 1;
            memcpy(hw_str, hw_val, len);
            hw_str[len] = '\0';
          }
        }
      }
    }

    // --- sensor_count (whitespace-tolerant) ---
    int sensor_count = 0;
    const char *sc_key = strstr(s_proxy_tmp, "\"sensor_count\"");
    if (sc_key) {
      sc_key += 14;  // skip past "sensor_count"
      while (*sc_key == ' ' || *sc_key == '\t' || *sc_key == '\n' || *sc_key == '\r') sc_key++;
      if (*sc_key == ':') {
        sc_key++;
        while (*sc_key == ' ' || *sc_key == '\t' || *sc_key == '\n' || *sc_key == '\r') sc_key++;
        sensor_count = (int)strtol(sc_key, nullptr, 10);
      }
    }

    // Build response — no mutation, no NVS
    /*
     * NOTE: probe_id, probe_name, and hw_str are not JSON-escaped.
     * Satellite names follow the project naming convention (alphanumeric +
     * hyphens only), so special characters are not expected. If the naming
     * convention changes, add json_escape() here.
     */
    char body[256];
    int body_len = snprintf(body, sizeof(body),
                            "{\"ok\":true,\"gateway\":{\"id\":\"%s\",\"name\":\"%s\","
                            "\"hardware\":\"%s\",\"sensor_count\":%d}}",
                            probe_id, probe_name, hw_str, sensor_count);
    if (body_len < 0 || static_cast<size_t>(body_len) >= sizeof(body)) {
      send_json_error_(request, 500, "Response too large");
      return;
    }

    auto *resp = request->beginResponse(200, "application/json", body);
    add_common_headers_(resp);
    request->send(resp);
  }

  // POST /api/system/reset-satellites — erase NVS satellite namespace and reload compile-time defaults
  void handle_reset_satellites_(AsyncWebServerRequest *request) const {
    if (request->method() != HTTP_POST) {
      send_json_error_(request, 405, "Method not allowed");
      return;
    }
    if (!authenticate_management_(request)) return;

    if (s_reset_satellites_in_progress) {
      send_json_error_(request, 409, "Satellite reset already in progress");
      return;
    }
    s_reset_satellites_in_progress = true;

    // Respond immediately — NVS work is deferred to reset_satellites_task_
    // which runs on its own 8 KB stack (httpd task stack is hardcoded 4 KB
    // by ESPHome and cannot be increased via sdkconfig).
    char body[128];
    snprintf(body, sizeof(body),
             "{\"ok\":true,\"message\":\"Satellite reset scheduled\","
             "\"satellite_count\":%d}",
             MAX_SATELLITES);
    auto *resp = request->beginResponse(200, "application/json", body);
    add_common_headers_(resp);
    request->send(resp);

    schedule_reset_satellites_();
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

#if AGGREGATOR_ENABLED
  set_aggregator_poll_basic_auth_(mgmt_username, mgmt_password);
#endif

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
