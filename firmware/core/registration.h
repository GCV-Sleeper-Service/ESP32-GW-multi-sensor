
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
