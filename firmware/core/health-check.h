// ═══════════════════════════════════════════════════════════════════
// health-check.h — Periodic telemetry task (Phase 7 Step v7.7.1.0)
// Source fragment: firmware/core/health-check.h
// Assembled output: dashboard/sensor_history_multi.h
//
// Implements BUG-075/076 postmortem recommendation: periodic health
// logging of heap, stack watermarks, NVS stats, and uptime.
// Read-only telemetry — no NVS writes, no HTTP endpoints.
// ═══════════════════════════════════════════════════════════════════

#include <esp_heap_caps.h>

#ifndef HEALTH_CHECK_INTERVAL_S
#define HEALTH_CHECK_INTERVAL_S 60
#endif

static void health_check_task_(void *param) {
  (void) param;
  vTaskDelay(pdMS_TO_TICKS(30000));

  for (;;) {
    uint32_t free_internal = esp_get_free_internal_heap_size();
    uint32_t free_total = esp_get_free_heap_size();
    uint32_t min_free_internal =
        heap_caps_get_minimum_free_size(MALLOC_CAP_INTERNAL);
    uint32_t min_free_total = esp_get_minimum_free_heap_size();

    UBaseType_t hc_stack_wm = uxTaskGetStackHighWaterMark(nullptr);
    TaskHandle_t httpd_task = xTaskGetHandle("httpd");
    UBaseType_t httpd_stack_wm = 0;
    if (httpd_task != nullptr) {
      httpd_stack_wm = uxTaskGetStackHighWaterMark(httpd_task);
    }

    nvs_stats_t nvs_stats{};
    esp_err_t nvs_err = nvs_get_stats(HISTORY_PARTITION_LABEL, &nvs_stats);

    uint32_t uptime_s = (uint32_t) (esp_timer_get_time() / 1000000ULL);
    uint32_t uptime_h = uptime_s / 3600;
    uint32_t uptime_m = (uptime_s % 3600) / 60;

    ESP_LOGI(TAG, "HEALTH: heap_free=%u heap_free_total=%u "
                  "min_free=%u min_free_total=%u "
                  "uptime=%uh%02um",
             (unsigned) free_internal, (unsigned) free_total,
             (unsigned) min_free_internal, (unsigned) min_free_total,
             (unsigned) uptime_h, (unsigned) uptime_m);

    ESP_LOGI(TAG, "HEALTH: httpd_stack_wm=%u hc_stack_wm=%u",
             (unsigned) (httpd_stack_wm * sizeof(StackType_t)),
             (unsigned) (hc_stack_wm * sizeof(StackType_t)));

    if (nvs_err == ESP_OK) {
      ESP_LOGI(TAG, "HEALTH: nvs_used=%u nvs_free=%u nvs_total=%u "
                    "nvs_ns_count=%u",
               (unsigned) nvs_stats.used_entries,
               (unsigned) nvs_stats.free_entries,
               (unsigned) nvs_stats.total_entries,
               (unsigned) nvs_stats.namespace_count);
    } else {
      ESP_LOGW(TAG, "HEALTH: nvs_get_stats failed: %s",
               esp_err_to_name(nvs_err));
    }

    vTaskDelay(pdMS_TO_TICKS(HEALTH_CHECK_INTERVAL_S * 1000));
  }
}

static void start_health_check_task_() {
  BaseType_t ret = xTaskCreate(health_check_task_, "health_chk", 4096, nullptr, 1, nullptr);
  if (ret != pdPASS) {
    ESP_LOGE(TAG, "start_health_check_task_: xTaskCreate failed (ret=%d)",
             (int) ret);
  } else {
    ESP_LOGI(TAG, "Health-check task started (interval=%ds, stack=4096B)",
             HEALTH_CHECK_INTERVAL_S);
  }
}
