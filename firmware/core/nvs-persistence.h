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

static constexpr uint32_t device_id_hash_(const char *id) {
  uint32_t hash = 0x811c9dc5u;
  if (id == nullptr) return hash;
  for (const char *p = id; *p != '\0'; p++) {
    hash ^= (uint8_t) *p;
    hash *= 0x01000193u;
  }
  return hash;
}

struct NvsKey { char s[16]; };

static constexpr NvsKey device_meta_key_(const char *device_id) {
  NvsKey key = {};
  if (device_id == nullptr || device_id[0] == '\0') return key;
  key.s[0] = 'd';
  key.s[1] = 'm';
  key.s[2] = '_';
  uint32_t hash = device_id_hash_(device_id);
  for (int i = 0; i < 8; i++) {
    key.s[3 + i] = "0123456789abcdef"[(hash >> (28 - 4 * i)) & 0xfu];
  }
  return key;
}

static constexpr NvsKey device_segment_key_(const char *device_id, int slot) {
  NvsKey key = {};
  if (device_id == nullptr || device_id[0] == '\0' ||
      slot < 0 || slot >= MAX_DEVICE_SLOTS) return key;
  key = device_meta_key_(device_id);
  key.s[1] = 's';
  key.s[11] = '_';
  for (int i = 0; i < 3; i++) {
    key.s[12 + i] = "0123456789abcdef"[(slot >> (8 - 4 * i)) & 0xf];
  }
  return key;
}

// ── Phase 7 compile-time test of the per-device keys (v7.7.1.2): a supplied test; do not change it ──
static constexpr bool p7_key_is_(const NvsKey &k, const char *want) {
  int i = 0;
  for (; i < 16 && want[i] != '\0'; i++) {
    if (k.s[i] != want[i]) return false;
  }
  return i < 16 && k.s[i] == '\0';
}
static_assert(sizeof(NvsKey) == 16, "an NVS key holds 15 characters and a NUL");
static_assert(device_id_hash_("") == 0x811c9dc5u, "FNV-1a of the empty string");
static_assert(device_id_hash_(nullptr) == 0x811c9dc5u, "nullptr hashes as the empty string");
static_assert(device_id_hash_("a") == 0xe40c292cu, "FNV-1a of a");
static_assert(device_id_hash_("foobar") == 0xbf9cf968u, "FNV-1a of foobar");
static_assert(device_id_hash_("office") == 0xaa8eba31u, "FNV-1a of office");
static_assert(device_id_hash_("first_floor") == 0x9ed41104u, "FNV-1a of first_floor");
static_assert(p7_key_is_(device_meta_key_("office"), "dm_aa8eba31"), "meta key of office");
static_assert(p7_key_is_(device_meta_key_("wan_ping"), "dm_7a81c392"), "meta key of wan_ping");
static_assert(p7_key_is_(device_segment_key_("office", 0), "ds_aa8eba31_000"), "segment key, slot 0");
static_assert(p7_key_is_(device_segment_key_("first_floor", 26), "ds_9ed41104_01a"), "segment key, slot 26");
static_assert(p7_key_is_(device_segment_key_("office", MAX_DEVICE_SLOTS - 1), "ds_aa8eba31_fff"), "segment key, last slot");
static_assert(p7_key_is_(device_segment_key_("office", MAX_DEVICE_SLOTS), ""), "a slot past the end has no key");
static_assert(p7_key_is_(device_segment_key_("office", -1), ""), "a negative slot has no key");
static_assert(p7_key_is_(device_meta_key_(""), ""), "an empty id has no key");
static_assert(p7_key_is_(device_meta_key_(nullptr), ""), "a null id has no key");
static_assert(p7_key_is_(device_segment_key_(nullptr, 0), ""), "a null id has no segment key");
static_assert(MAX_DEVICE_SLOTS == 4096, "three hex digits address 4096 slots");

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

// ═══════════════════════════════════════════════════════════════════
// Phase 7 — per-device persist write path (v7.7.1.3, PLAN-046)
//   Each hourly persist also writes one DeviceSegment per persistent
//   device (dual-write). Nothing reads these blobs until v7.7.1.4.
// ═══════════════════════════════════════════════════════════════════

// The ring of each device in this step: one day of hourly segments. v7.7.1.4
// replaces it by the retention budget (PLAN-046: the 360 slots of May 2026 do not fit).
static constexpr uint16_t DEV_PERSIST_PROVISIONAL_SLOTS = 24;
// A v2 write needs this many free NVS entries in the history partition, so that the
// old engine keeps room for its hourly overwrite: two pages of 126 entries.
static constexpr uint32_t DEV_PERSIST_MIN_FREE_ENTRIES = 252;

// The result of the last persist cycle of one device.
enum DevPersistResult : uint8_t {
  DEV_PERSIST_PENDING = 0,    // no cycle since the boot
  DEV_PERSIST_OK = 1,         // the segment and the meta are written
  DEV_PERSIST_DEDUP = 2,      // the newest point is already persisted
  DEV_PERSIST_EMPTY = 3,      // the device has no point to persist
  DEV_PERSIST_NVS_LOW = 4,    // fewer free entries than DEV_PERSIST_MIN_FREE_ENTRIES
  DEV_PERSIST_MISSING = 5,    // the id is not in devices[]
  DEV_PERSIST_COLLISION = 6,  // the meta blob of the key holds another device id
  DEV_PERSIST_ERROR = 7,      // an allocation, a metric mismatch or an NVS call failed
};

static constexpr const char *dev_persist_result_name_(uint8_t result) {
  return result == DEV_PERSIST_PENDING ? "pending"
       : result == DEV_PERSIST_OK ? "ok"
       : result == DEV_PERSIST_DEDUP ? "dedup"
       : result == DEV_PERSIST_EMPTY ? "empty"
       : result == DEV_PERSIST_NVS_LOW ? "nvs_low"
       : result == DEV_PERSIST_MISSING ? "missing"
       : result == DEV_PERSIST_COLLISION ? "collision"
       : result == DEV_PERSIST_ERROR ? "error" : "unknown";
}

// RAM only: the persist path writes it, /api/storage-stats reads it, on two tasks. Both take a copy of
// one device's status through the two functions below, never the array itself (PLAN-047).
struct DevicePersistStatus {
  uint32_t last_persist_epoch = 0;  // from the device's meta after the cycle
  uint32_t writes_ok = 0;           // results OK since the boot
  uint32_t writes_skipped = 0;      // results DEDUP, EMPTY and NVS_LOW since the boot
  uint32_t writes_failed = 0;       // results MISSING, COLLISION and ERROR since the boot
  uint16_t valid_segments = 0;      // from the device's meta after the cycle
  uint16_t next_slot = 0;           // from the device's meta after the cycle
  uint8_t last_result = DEV_PERSIST_PENDING;
};
static DevicePersistStatus g_dev_persist_status[PERSIST_DEVICE_ARRAY_LEN] = {};
static portMUX_TYPE g_dev_persist_status_mux = portMUX_INITIALIZER_UNLOCKED;

// A copy of the status of one persistent device, taken under a short critical section.
static DevicePersistStatus dev_persist_status_get_(int persist_index) {
  DevicePersistStatus status;
  if (persist_index < 0 || persist_index >= PERSIST_DEVICE_COUNT) return status;
  portENTER_CRITICAL(&g_dev_persist_status_mux);
  status = g_dev_persist_status[persist_index];
  portEXIT_CRITICAL(&g_dev_persist_status_mux);
  return status;
}

// Publishes the status of one persistent device, under the same critical section.
static void dev_persist_status_put_(int persist_index, const DevicePersistStatus &status) {
  if (persist_index < 0 || persist_index >= PERSIST_DEVICE_COUNT) return;
  portENTER_CRITICAL(&g_dev_persist_status_mux);
  g_dev_persist_status[persist_index] = status;
  portEXIT_CRITICAL(&g_dev_persist_status_mux);
}

static constexpr uint16_t dev_ring_next_(uint16_t slot, uint16_t max_slots) {
  return slot + 1 < max_slots ? slot + 1 : 0;
}

static constexpr uint16_t dev_ring_valid_(uint16_t valid, uint16_t max_slots) {
  return valid < max_slots ? valid + 1 : max_slots;
}

static int find_device_index_(const char *device_id) {
  if (device_id == nullptr) return -1;
  for (int i = 0; i < NUM_DEVICES; i++) {
    if (devices[i].id != nullptr && std::strcmp(devices[i].id, device_id) == 0) return i;
  }
  return -1;
}

static int build_device_segment_(int device_index, uint8_t metric_count, uint32_t saved_at_epoch, DeviceSegment *seg) {
  if (seg == nullptr) return -1;
  *seg = DeviceSegment();
  if (device_index < 0 || device_index >= NUM_DEVICES ||
      metric_count == 0 || metric_count > MAX_PERSIST_METRICS) return -1;
  seg->header.metric_count = metric_count;
  seg->header.points_per_segment = PERSIST_POINTS_PER_SEGMENT;
  seg->header.saved_at_epoch = saved_at_epoch;
  const SensorEntity &device = devices[device_index];
  int row = 0;
  int points = 0;
  for (int m = 0; m < device.metric_count && row < metric_count; m++) {
    const HistoryBuffer *history = device.metric_states[m].history;
    if (history == nullptr) continue;
    int count = export_latest_entries_(*history, seg->data[row], PERSIST_POINTS_PER_SEGMENT);
    seg->counts[row] = count;
    points += count;
    if (count > 0) {
      uint32_t first = seg->data[row][0].epoch;
      uint32_t last = seg->data[row][count - 1].epoch;
      if (first != 0 && (seg->header.first_epoch == 0 || first < seg->header.first_epoch)) {
        seg->header.first_epoch = first;
      }
      if (last > seg->header.last_epoch) seg->header.last_epoch = last;
    }
    row++;
  }
  return row == metric_count ? points : -1;
}

static int load_device_meta_(nvs_handle_t handle, const char *device_id, DeviceHistoryMeta *meta) {
  const NvsKey key = device_meta_key_(device_id);
  if (meta == nullptr || key.s[0] == '\0') {
    ESP_LOGE(TAG, "V2 meta read: invalid destination or id");
    return -1;
  }
  DeviceHistoryMeta loaded;
  size_t size = sizeof(loaded);
  esp_err_t err = nvs_get_blob(handle, key.s, &loaded, &size);
  if (err == ESP_ERR_NVS_NOT_FOUND || err == ESP_ERR_NVS_INVALID_LENGTH) return 0;
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "V2 nvs_get_blob(%s) failed: %s", key.s, esp_err_to_name(err));
    return -1;
  }
  if (size != sizeof(loaded) || loaded.magic != DEV_HIST_MAGIC ||
      loaded.version != DEV_HIST_VERSION) return 0;
  *meta = loaded;
  return 1;
}

static bool save_device_meta_(nvs_handle_t handle, const char *device_id, const DeviceHistoryMeta &meta) {
  const NvsKey key = device_meta_key_(device_id);
  if (key.s[0] == '\0') {
    ESP_LOGE(TAG, "V2 meta write: invalid id");
    return false;
  }
  esp_err_t err = nvs_set_blob(handle, key.s, &meta, sizeof(meta));
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "V2 nvs_set_blob(%s) failed: %s", key.s, esp_err_to_name(err));
    return false;
  }
  err = nvs_commit(handle);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "V2 nvs_commit(%s) failed: %s", key.s, esp_err_to_name(err));
    return false;
  }
  return true;
}

static uint8_t persist_device_segment_(nvs_handle_t handle, int persist_index, uint32_t saved_at_epoch, DeviceSegment *seg) {
  if (persist_index < 0 || persist_index >= PERSIST_DEVICE_COUNT) return DEV_PERSIST_ERROR;
  const char *id = PERSIST_DEVICE_IDS[persist_index];
  const uint8_t metric_count = PERSIST_METRIC_COUNTS[persist_index];
  DevicePersistStatus status = dev_persist_status_get_(persist_index);
  DeviceHistoryMeta meta;
  bool have_meta = false;
  uint8_t result = DEV_PERSIST_ERROR;
  do {
    int device_index = find_device_index_(id);
    if (device_index < 0) {
      result = DEV_PERSIST_MISSING;
      break;
    }
    int points = build_device_segment_(device_index, metric_count, saved_at_epoch, seg);
    if (points < 0) break;
    if (points == 0 || seg->header.last_epoch == 0) {
      result = DEV_PERSIST_EMPTY;
      break;
    }
    int loaded = load_device_meta_(handle, id, &meta);
    if (loaded < 0) break;
    if (loaded == 1 && std::strncmp(meta.device_id, id, sizeof(meta.device_id)) != 0) {
      result = DEV_PERSIST_COLLISION;
      break;
    }
    if (loaded == 0 || meta.metric_count != metric_count ||
        meta.points_per_segment != PERSIST_POINTS_PER_SEGMENT ||
        meta.max_slots != DEV_PERSIST_PROVISIONAL_SLOTS) {
      meta = DeviceHistoryMeta();
      meta.metric_count = metric_count;
      meta.points_per_segment = PERSIST_POINTS_PER_SEGMENT;
      meta.max_slots = DEV_PERSIST_PROVISIONAL_SLOTS;
      std::strncpy(meta.device_id, id, DEVICE_ID_MAX_LEN);
      meta.device_id[DEVICE_ID_MAX_LEN] = '\0';
    }
    have_meta = true;
    if (meta.last_persist_epoch == seg->header.last_epoch) {
      result = DEV_PERSIST_DEDUP;
      break;
    }
    nvs_stats_t stats{};
    if (nvs_get_stats(HISTORY_PARTITION_LABEL, &stats) != ESP_OK ||
        stats.free_entries < DEV_PERSIST_MIN_FREE_ENTRIES) {
      result = DEV_PERSIST_NVS_LOW;
      break;
    }
    uint16_t slot = meta.next_slot < meta.max_slots ? meta.next_slot : 0;
    const NvsKey key = device_segment_key_(id, slot);
    esp_err_t err = nvs_set_blob(handle, key.s, seg, sizeof(*seg));
    if (err != ESP_OK) {
      ESP_LOGE(TAG, "V2 nvs_set_blob(%s) failed: %s", key.s, esp_err_to_name(err));
      break;
    }
    DeviceHistoryMeta written = meta;
    written.last_written_slot = slot;
    written.next_slot = dev_ring_next_(slot, meta.max_slots);
    written.valid_segments = dev_ring_valid_(meta.valid_segments, meta.max_slots);
    written.last_persist_epoch = seg->header.last_epoch;
    if (!save_device_meta_(handle, id, written)) break;
    meta = written;
    result = DEV_PERSIST_OK;
  } while (false);

  if (have_meta) {
    status.valid_segments = meta.valid_segments;
    status.next_slot = meta.next_slot;
    status.last_persist_epoch = meta.last_persist_epoch;
  }
  status.last_result = result;
  if (result == DEV_PERSIST_OK) status.writes_ok++;
  else if (result == DEV_PERSIST_DEDUP || result == DEV_PERSIST_EMPTY || result == DEV_PERSIST_NVS_LOW) status.writes_skipped++;
  else status.writes_failed++;
  dev_persist_status_put_(persist_index, status);
  if (result != DEV_PERSIST_OK && result != DEV_PERSIST_DEDUP) {
    ESP_LOGW(TAG, "V2 persist %s: %s", id, dev_persist_result_name_(result));
  }
  return result;
}

static void persist_all_devices_v2(uint32_t saved_at_epoch = 0) {
  if (PERSIST_DEVICE_COUNT == 0) return;
  DeviceSegment *seg = new (std::nothrow) DeviceSegment();
  nvs_handle_t handle;
  esp_err_t err = ESP_FAIL;
  if (seg != nullptr) {
    err = nvs_open_from_partition(HISTORY_PARTITION_LABEL, HISTORY_NAMESPACE, NVS_READWRITE, &handle);
  }
  if (seg == nullptr || err != ESP_OK) {
    for (int i = 0; i < PERSIST_DEVICE_COUNT; i++) {
      DevicePersistStatus status = dev_persist_status_get_(i);
      status.last_result = DEV_PERSIST_ERROR;
      status.writes_failed++;
      dev_persist_status_put_(i, status);
    }
    ESP_LOGE(TAG, "V2 persist allocation or open failed: %s", esp_err_to_name(err));
    delete seg;
    return;
  }
  unsigned written = 0;
  unsigned skipped = 0;
  unsigned failed = 0;
  for (int i = 0; i < PERSIST_DEVICE_COUNT; i++) {
    maybe_yield_nvs_scan_(i);
    uint8_t result = persist_device_segment_(handle, i, saved_at_epoch, seg);
    if (result == DEV_PERSIST_OK) written++;
    else if (result == DEV_PERSIST_DEDUP || result == DEV_PERSIST_EMPTY || result == DEV_PERSIST_NVS_LOW) skipped++;
    else failed++;
  }
  nvs_close(handle);
  delete seg;
  ESP_LOGI(TAG, "V2 persist: %u written, %u skipped, %u failed", written, skipped, failed);
}

// ── Phase 7 compile-time test of the write path (v7.7.1.3): a supplied test; do not change it ──
static_assert(dev_ring_next_(0, 24) == 1, "the cursor moves to the next slot");
static_assert(dev_ring_next_(22, 24) == 23, "the cursor moves to the last slot");
static_assert(dev_ring_next_(23, 24) == 0, "the cursor wraps after the last slot");
static_assert(dev_ring_next_(30, 24) == 0, "a cursor outside the ring restarts at 0");
static_assert(dev_ring_next_(0, 1) == 0, "a ring of one slot stays at 0");
static_assert(dev_ring_next_(5, 0) == 0, "a ring of no slot stays at 0");
static_assert(dev_ring_valid_(0, 24) == 1, "one more valid segment");
static_assert(dev_ring_valid_(23, 24) == 24, "the ring becomes full");
static_assert(dev_ring_valid_(24, 24) == 24, "valid_segments stops at max_slots");
static_assert(dev_ring_valid_(30, 24) == 24, "valid_segments never passes max_slots");
static_assert(dev_ring_valid_(0, 0) == 0, "a ring of no slot has no valid segment");
static_assert(DEV_PERSIST_PROVISIONAL_SLOTS >= 1 && DEV_PERSIST_PROVISIONAL_SLOTS <= MAX_DEVICE_SLOTS, "the ring fits the 3-hex-digit slot suffix");
static_assert(dev_persist_result_name_(DEV_PERSIST_OK)[0] == 'o' && dev_persist_result_name_(DEV_PERSIST_NVS_LOW)[0] == 'n', "result names");
static_assert(dev_persist_result_name_(200)[0] == 'u', "an unknown result has a name");

