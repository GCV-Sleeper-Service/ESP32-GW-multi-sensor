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

