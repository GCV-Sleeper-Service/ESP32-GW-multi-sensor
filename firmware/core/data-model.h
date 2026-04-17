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
// ── SENSOR COUNT CONFIGURATION GUIDE (v7.6.9.1) ──
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

