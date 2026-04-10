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

