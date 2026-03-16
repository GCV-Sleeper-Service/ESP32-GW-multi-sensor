#pragma once
// ═══════════════════════════════════════════════════════════════════
// sensor_history_multi-v7.5.3.3.h - hourly persistence with dedicated history NVS partition
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
#include <new>
#include <string>
#include <cctype>


#include "esphome/core/log.h"
#include "esphome/components/web_server_base/web_server_base.h"

// ── Dashboard payload ────────────────────────────────────────────
// DASHBOARD_HTML[] is defined in a separate dashboard header file
// (e.g. dashboard.h) which MUST be listed BEFORE this file
// in the YAML includes: block.  Keeping the dashboard as a separate
// include avoids duplicate-symbol errors when the dashboard version
// is bumped independently of the history backend.
//
// If the build fails with "undefined reference to DASHBOARD_HTML",
// ensure the YAML includes the dashboard header before this file.

#include <esp_err.h>
#include <nvs.h>
#include <nvs_flash.h>
#include <esp_system.h>
#include <esp_partition.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "gateway_manifest.h"

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

 private:
  HistEntry buf_[CAP] = {};
  int head_ = 0;
  int count_ = 0;
};


// ═══════════════════════════════════════════════════════════════════
// SensorSlot — all state for one physical BLE sensor
// ═══════════════════════════════════════════════════════════════════

struct SensorSlot {
  // ── Identity ──────────────────────────────────────────────────
  const char* id;     // URL slug: "office", "first_floor", "outside"
  const char* name;   // Display: "Office", "First Floor", "Outside"
  const char* mac;    // BLE MAC

  // ── 15-minute accumulators ────────────────────────────────────
  float temp_sum   = 0.0f;
  int   temp_count = 0;
  float hum_sum    = 0.0f;
  int   hum_count  = 0;
  float batt_last  = -1.0f;
  uint32_t last_seen_epoch = 0;

  // ── Retention ring buffers ────────────────────────────────────
  HistoryBuffer temp_history;
  HistoryBuffer hum_history;

  // ── Formatted output (set by compute_and_format / set_battery)
  char temp_avg_str[32] = "";
  char hum_avg_str[16]  = "";
  char batt_str[16]     = "";
  bool temp_valid = false;
  bool hum_valid  = false;

  void add_temp(float value) {
    if (!std::isnan(value) && value > -50.0f && value < 80.0f) {
      temp_sum += value;
      temp_count++;
    }
  }

  void add_hum(float value) {
    if (!std::isnan(value) && value >= 0.0f && value <= 100.0f) {
      hum_sum += value;
      hum_count++;
    }
  }

  void mark_seen(uint32_t epoch) {
    if (epoch > 0) last_seen_epoch = epoch;
  }

  void set_battery(float value) {
    if (!std::isnan(value) && value >= 0.0f && value <= 100.0f) {
      batt_last = value;
      snprintf(batt_str, sizeof(batt_str), "%.0f %%", value);
    }
  }

  // Called every 15 minutes from YAML lambda.
  void compute_and_format(uint32_t epoch) {
    temp_valid = false;
    hum_valid  = false;

    if (temp_count > 0) {
      float avg = temp_sum / (float) temp_count;
      temp_history.add(epoch, avg);
      float avg_f = avg * 9.0f / 5.0f + 32.0f;
      snprintf(temp_avg_str, sizeof(temp_avg_str),
               "%.1f \xC2\xB0" "C / %.1f \xC2\xB0" "F", avg, avg_f);
      temp_valid = true;
      ESP_LOGI(TAG, "%s temp: %.1f\xC2\xB0" "C (%d samples, buf=%d)",
               name, avg, temp_count, temp_history.count());
    } else {
      temp_history.add_gap(epoch);
      snprintf(temp_avg_str, sizeof(temp_avg_str), "NA");
      ESP_LOGW(TAG, "%s: no temp — gap inserted", name);
    }
    temp_sum = 0.0f;
    temp_count = 0;

    if (hum_count > 0) {
      float avg = hum_sum / (float) hum_count;
      hum_history.add(epoch, avg);
      snprintf(hum_avg_str, sizeof(hum_avg_str), "%.1f %%", avg);
      hum_valid = true;
      ESP_LOGI(TAG, "%s hum: %.1f%% (%d samples, buf=%d)",
               name, avg, hum_count, hum_history.count());
    } else {
      hum_history.add_gap(epoch);
      snprintf(hum_avg_str, sizeof(hum_avg_str), "NA");
      ESP_LOGW(TAG, "%s: no hum — gap inserted", name);
    }
    hum_sum = 0.0f;
    hum_count = 0;
  }
};


// ── Phase 3: Generalized sensor model (v7.5.3.1) ──────────────────────
// These structs coexist with SensorSlot during the migration.
// SensorSlot will be removed once SensorEntity is fully wired.

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
      }
      st.accumulator = 0;
      st.sample_count = 0;
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
static constexpr int NUM_SENSORS = 3;

static SensorSlot sensors[NUM_SENSORS] = {
  { .id = "office", .name = "Office", .mac = "DB:06:2C:58:8A:59" },
  { .id = "first_floor", .name = "First Floor", .mac = "D5:D8:4C:25:06:49" },
  { .id = "outside", .name = "Outside", .mac = "DF:EB:DE:19:11:6C" },
};
// <<< SENSOR_MANIFEST:HEADER_END >>>

// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>
// ── Generated SensorEntity arrays (Phase 3) ──────────────────────────
// Generated by render_sensor_config.py from config/sensors.json
// COEXISTS with SensorSlot arrays during migration

static const MetricDef metrics_thermopro[] = {
  {"temp",  "Temperature", "\xC2\xB0""C", 0, true},
  {"hum",   "Humidity",    "%",            0, true},
  {"batt",  "Battery",     "%",            3, false},
  {"rssi",  "RSSI",        "dBm",          3, false}
};

static HistoryBuffer entity_hbuf_office_temp;
static HistoryBuffer entity_hbuf_office_hum;
static HistoryBuffer entity_hbuf_first_floor_temp;
static HistoryBuffer entity_hbuf_first_floor_hum;
static HistoryBuffer entity_hbuf_outside_temp;
static HistoryBuffer entity_hbuf_outside_hum;

static constexpr int NUM_DEVICES = 3;

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
};
// <<< SENSOR_MANIFEST:ENTITY_END >>>

// ═══════════════════════════════════════════════════════════════════
// ── SENSOR COUNT CONFIGURATION GUIDE (v7.5.3.3) ──
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
//
// ── 1-sensor template ────────────────────────────────────────────
// static constexpr int NUM_SENSORS = 1;
// static SensorSlot sensors[NUM_SENSORS] = {
//   { .id = "office", .name = "Office", .mac = "DB:06:2C:58:8A:59" },
// };
//
// ── 2-sensor template ────────────────────────────────────────────
// static constexpr int NUM_SENSORS = 2;
// static SensorSlot sensors[NUM_SENSORS] = {
//   { .id = "office",      .name = "Office",      .mac = "DB:06:2C:58:8A:59" },
//   { .id = "first_floor", .name = "First Floor", .mac = "D5:D8:4C:25:06:49" },
// };
//
// ── 4-sensor template ────────────────────────────────────────────
// static constexpr int NUM_SENSORS = 4;
// static SensorSlot sensors[NUM_SENSORS] = {
//   { .id = "office",      .name = "Office",      .mac = "DB:06:2C:58:8A:59" },
//   { .id = "first_floor", .name = "First Floor", .mac = "D5:D8:4C:25:06:49" },
//   { .id = "outside",     .name = "Outside",     .mac = "DF:EB:DE:19:11:6C" },
//   { .id = "garage",      .name = "Garage",      .mac = "XX:XX:XX:XX:XX:XX" },
// };
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
  for (int i = 0; i < NUM_SENSORS; i++) {
    sensors[i].temp_history.clear();
    sensors[i].hum_history.clear();
    sensors[i].temp_sum = 0.0f;
    sensors[i].temp_count = 0;
    sensors[i].hum_sum = 0.0f;
    sensors[i].hum_count = 0;
    sensors[i].temp_valid = false;
    sensors[i].hum_valid = false;
    snprintf(sensors[i].temp_avg_str, sizeof(sensors[i].temp_avg_str), "NA");
    snprintf(sensors[i].hum_avg_str, sizeof(sensors[i].hum_avg_str), "NA");
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

static bool load_history_meta_(nvs_handle_t handle, HistoryMeta *meta) {
  if (meta == nullptr) return false;

  size_t sz = sizeof(HistoryMeta);
  esp_err_t err = nvs_get_blob(handle, "hist_meta", meta, &sz);
  if (err != ESP_OK) {
    *meta = default_history_meta_();
    return false;
  }

  bool valid = meta->magic == HISTORY_META_MAGIC &&
               meta->version == HISTORY_META_VERSION &&
               meta->num_sensors == NUM_SENSORS &&
               meta->points_per_series == HISTORY_POINTS_PER_SERIES &&
               meta->points_per_segment == PERSIST_POINTS_PER_SEGMENT &&
               meta->valid_segments <= PERSIST_SLOTS &&
               meta->next_slot < PERSIST_SLOTS;
  if (!valid) {
    ESP_LOGW(TAG, "history meta invalid or schema mismatch — resetting");
    *meta = default_history_meta_();
    return false;
  }
  return true;
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

static bool load_snapshot_from_handle_(nvs_handle_t handle, int slot,
                                       SegmentSnapshot *snapshot) {
  if (snapshot == nullptr) return false;

  char key[12];
  make_segment_key_(slot, key, sizeof(key));

  size_t sz = sizeof(SegmentSnapshot);
  esp_err_t err = nvs_get_blob(handle, key, snapshot, &sz);
  if (err != ESP_OK) return false;

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
    snapshot->temp_counts[i] = export_latest_entries_(
        sensors[i].temp_history, snapshot->temp[i], PERSIST_POINTS_PER_SEGMENT);
    snapshot->hum_counts[i] = export_latest_entries_(
        sensors[i].hum_history, snapshot->hum[i], PERSIST_POINTS_PER_SEGMENT);

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
    for (int n = 0; n < snapshot.temp_counts[i]; n++) {
      const HistEntry &entry = snapshot.temp[i][n];
      if (entry.epoch > 0) sensors[i].temp_history.add(entry.epoch, entry.value);
    }
    for (int n = 0; n < snapshot.hum_counts[i]; n++) {
      const HistEntry &entry = snapshot.hum[i][n];
      if (entry.epoch > 0) sensors[i].hum_history.add(entry.epoch, entry.value);
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

static bool restore_from_nvs() {
  nvs_handle_t handle;
  if (!open_history_nvs_(&handle, NVS_READONLY)) return false;

  HistoryMeta meta;
  bool have_meta = load_history_meta_(handle, &meta);
  if (!have_meta || meta.valid_segments == 0) {
    nvs_close(handle);
    ESP_LOGI(TAG, "No persisted history segments to restore");
    return false;
  }

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
  for (int n = 0; n < restore_segments; n++) {
    int slot = (first_restore_slot + n) % PERSIST_SLOTS;
    if (!load_snapshot_from_handle_(handle, slot, snapshot)) continue;
    append_snapshot_to_ram_(*snapshot);
    restored++;
  }
  nvs_close(handle);
  delete snapshot;

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

    if (request->method() == HTTP_GET) {
      if (len >= 11 && strncmp(p, "/history/", 9) == 0) return true;
      if (len == 13 && memcmp(p, "/sensors.json", 13) == 0) return true; if (strcmp(p, "/api/manifest") == 0) return true;
      if (strcmp(p, "/dashboard") == 0) return true;
      if (strcmp(p, "/dashboard.html") == 0) return true;
      if (strcmp(p, "/dashboard-download") == 0) return true;
      if (strcmp(p, "/api/storage-stats") == 0) return true;
      if (strcmp(p, "/api/status") == 0) return true;
      if (strcmp(p, "/favicon.ico") == 0) return true;
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
      return false;
    }

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
      request->send(404);
      return;
    }

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
    const size_t dashboard_len = sizeof(DASHBOARD_HTML) - 1;
    const auto *dashboard_bytes =
        reinterpret_cast<const uint8_t *>(DASHBOARD_HTML);

    auto *resp = request->beginResponse(
        200, "text/html; charset=utf-8", dashboard_bytes, dashboard_len);

    resp->addHeader("Cache-Control", "no-store");
    resp->addHeader("Content-Encoding", "identity");
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
    for (int i = 0; i < NUM_SENSORS; i++) {
      if (i > 0) resp->print(",");
      char entry[96];
      snprintf(entry, sizeof(entry),
               "{\"id\":\"%s\",\"name\":\"%s\"}",
               sensors[i].id, sensors[i].name);
      resp->print(entry);
    }
    resp->print("]");
    request->send(resp);
  } void handle_api_manifest_(AsyncWebServerRequest *request) const { auto *resp = request->beginResponseStream("application/json"); add_common_headers_(resp); resp->print(GATEWAY_MANIFEST_JSON); request->send(resp); }

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
    for (int i = 0; i < NUM_SENSORS; i++) {
      if (strcmp(sensors[i].id, sensor_id) == 0) return i;
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
               sensors[target_sensor].id, (unsigned) import_epoch_map_size_);
      resp->print(msg);
      ESP_LOGI(TAG, "Import begun (single-sensor: %s) — %u existing segments indexed",
               sensors[target_sensor].id, (unsigned) import_epoch_map_size_);
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
      for (int i = 0; i < NUM_SENSORS; i++) {
        if (strcmp(sensors[i].id, sid) == 0) { sensor_idx = i; break; }
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
    uint32_t free_heap = esp_get_free_heap_size();

    // Keep each snprintf well under 64 bytes to avoid silent truncation.
    char num[64];

    resp->print("{\"ok\":true,\"version\":\"");
    resp->print(firmware_version_.c_str());
    resp->print("\",");

    snprintf(num, sizeof(num), "\"uptime_seconds\":%u,\"sensor_count\":%d,",
             (unsigned) uptime_s, NUM_SENSORS);
    resp->print(num);

    resp->print("\"sensors\":[");
    for (int i = 0; i < NUM_SENSORS; i++) {
      if (i > 0) resp->print(",");
      resp->print("{\"id\":\"");
      resp->print(sensors[i].id);
      resp->print("\",\"name\":\"");
      resp->print(sensors[i].name);
      snprintf(num, sizeof(num),
               "\",\"last_seen\":%u,\"temp_valid\":%s,\"hum_valid\":%s}",
               (unsigned) sensors[i].last_seen_epoch,
               sensors[i].temp_valid ? "true" : "false",
               sensors[i].hum_valid ? "true" : "false");
      resp->print(num);
    }
    resp->print("],");

    // Each field printed separately to stay within the 64-byte buffer.
    snprintf(num, sizeof(num), "\"ram_history_points_per_series\":%d,",
             HISTORY_POINTS_PER_SERIES);
    resp->print(num);

    snprintf(num, sizeof(num), "\"persist_days\":%d,", PERSIST_DAYS);
    resp->print(num);

    snprintf(num, sizeof(num), "\"free_heap\":%u}", (unsigned) free_heap);
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
    for (int i = 0; i < NUM_SENSORS; i++) {
      if (strlen(sensors[i].id) == id_len &&
          strncmp(sensors[i].id, rest, id_len) == 0) {
        sensor_idx = i;
        break;
      }
    }
    if (sensor_idx < 0) {
      request->send(404);
      return;
    }

    int series_kind = -1;
    HistoryBuffer *buf = nullptr;
    if (strcmp(type, "temp") == 0) {
      series_kind = HISTORY_SERIES_TEMP;
      buf = &sensors[sensor_idx].temp_history;
    } else if (strcmp(type, "hum") == 0) {
      series_kind = HISTORY_SERIES_HUM;
      buf = &sensors[sensor_idx].hum_history;
    } else {
      request->send(404);
      return;
    }

    auto *resp = request->beginResponseStream("text/plain");
    resp->addHeader("Cache-Control", "no-store");

    uint32_t latest_flash_epoch = 0;
    nvs_handle_t handle;
    SegmentSnapshot *snapshot = nullptr;
    if (open_history_nvs_(&handle, NVS_READONLY)) {
      HistoryMeta meta;
      if (load_history_meta_(handle, &meta) && meta.valid_segments > 0) {
        snapshot = allocate_snapshot_();
        if (snapshot != nullptr) {
          int oldest_slot =
              (meta.next_slot + PERSIST_SLOTS - meta.valid_segments) % PERSIST_SLOTS;

          for (int n = 0; n < meta.valid_segments; n++) {
            int slot = (oldest_slot + n) % PERSIST_SLOTS;
            if (!load_snapshot_from_handle_(handle, slot, snapshot)) continue;
            stream_snapshot_series_(resp, *snapshot, sensor_idx, series_kind);
            if (snapshot->header.last_epoch > latest_flash_epoch) {
              latest_flash_epoch = snapshot->header.last_epoch;
            }
          }
        }
      }
      nvs_close(handle);
    }
    if (snapshot != nullptr) delete snapshot;

    buf->stream_to(resp, latest_flash_epoch);
    request->send(resp);
  }
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
           "handler registered (%d sensors, %dh RAM, %d hourly slots in '%s', %d pts/segment)",
           NUM_SENSORS, HISTORY_HOURS, PERSIST_SLOTS,
           HISTORY_PARTITION_LABEL,
           PERSIST_POINTS_PER_SEGMENT);
  for (int i = 0; i < NUM_SENSORS; i++) {
    ESP_LOGI(TAG, "  [%d] %s -> /history/%s/{temp,hum}",
             i, sensors[i].name, sensors[i].id);
  }
  ESP_LOGI(TAG, "  management -> POST /api/reboot, POST /api/delete-data (Basic auth)");
  ESP_LOGI(TAG, "  import     -> POST /api/import/{begin,segment,finish} (Basic auth)");
  ESP_LOGI(TAG, "  storage    -> GET /api/storage-stats");
  ESP_LOGI(TAG, "  status     -> GET /api/status");
  ESP_LOGI(TAG, "  manifest -> GET /api/manifest (v2)");
  ESP_LOGI(TAG, "  storage -> dedicated NVS partition: %s / namespace: %s",
           HISTORY_PARTITION_LABEL, HISTORY_NAMESPACE);
}
