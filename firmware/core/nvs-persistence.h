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

