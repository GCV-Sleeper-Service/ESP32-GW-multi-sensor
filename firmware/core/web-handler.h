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

  // send_snapshot_series_chunk_ formats one persisted snapshot series and sends
  // it via httpd_resp_send_chunk() without building a full response string.
  static esp_err_t flush_chunk_buffer_(httpd_req_t *req, char *buf, int *buf_pos) {
    if (buf_pos == nullptr || *buf_pos <= 0) return ESP_OK;
    esp_err_t err = httpd_resp_send_chunk(req, buf, *buf_pos);
    if (err == ESP_OK) *buf_pos = 0;
    return err;
  }

  static esp_err_t append_csv_line_chunk_(httpd_req_t *req, char *buf,
                                          size_t buf_size, int *buf_pos,
                                          const HistEntry &entry) {
    if (buf == nullptr || buf_pos == nullptr) return ESP_ERR_INVALID_ARG;

    char line[96];
    int len;
    if (std::isnan(entry.value)) {
      len = snprintf(line, sizeof(line), "%u,\n", (unsigned) entry.epoch);
    } else {
      len = snprintf(line, sizeof(line), "%u,%.2f\n",
                     (unsigned) entry.epoch, entry.value);
    }

    if (len <= 0) return ESP_OK;
    if (len >= (int) sizeof(line) || len > (int) buf_size) {
      return ESP_ERR_INVALID_SIZE;
    }

    if (*buf_pos + len > (int) buf_size) {
      esp_err_t err = flush_chunk_buffer_(req, buf, buf_pos);
      if (err != ESP_OK) return err;
    }

    memcpy(buf + *buf_pos, line, len);
    *buf_pos += len;
    return ESP_OK;
  }

  static void finalize_chunked_response_(httpd_req_t *req, const char *context,
                                         esp_err_t prior_err = ESP_OK) {
    esp_err_t err = httpd_resp_send_chunk(req, nullptr, 0);
    if (err != ESP_OK) {
      if (prior_err == ESP_ERR_HTTPD_RESP_SEND && err == ESP_ERR_HTTPD_RESP_SEND) {
        ESP_LOGD(TAG, "%s final chunk skipped after client disconnect", context);
      } else {
        ESP_LOGW(TAG, "%s final chunk failed: %s",
                 context, esp_err_to_name(err));
      }
    }
  }

  static esp_err_t send_snapshot_series_chunk_(httpd_req_t *req,
                                               const SegmentSnapshot &snapshot,
                                               int sensor_idx,
                                               int series_kind) {
    if (sensor_idx < 0 || sensor_idx >= NUM_SENSORS) return ESP_OK;

    const HistEntry *entries = nullptr;
    int count = 0;
    if (series_kind == HISTORY_SERIES_TEMP) {
      entries = snapshot.temp[sensor_idx];
      count = snapshot.temp_counts[sensor_idx];
    } else {
      entries = snapshot.hum[sensor_idx];
      count = snapshot.hum_counts[sensor_idx];
    }

    char buf[512];
    int buf_pos = 0;

    for (int i = 0; i < count; i++) {
      const HistEntry &entry = entries[i];
      if (entry.epoch == 0) continue;

      esp_err_t err = append_csv_line_chunk_(req, buf, sizeof(buf), &buf_pos, entry);
      if (err != ESP_OK) return err;
    }

    return flush_chunk_buffer_(req, buf, &buf_pos);
  }

  // send_history_buffer_chunk_ formats RAM history entries and sends them via
  // httpd_resp_send_chunk() with the same CSV wire format.
  static esp_err_t send_history_buffer_chunk_(
      httpd_req_t *req, const HistoryBuffer &buf,
      uint32_t min_epoch_exclusive = 0) {
    char line_buf[512];
    int buf_pos = 0;

    for (int i = 0; i < buf.count(); i++) {
      HistEntry entry = buf.at_logical(i);
      if (entry.epoch == 0 || entry.epoch <= min_epoch_exclusive) continue;

      esp_err_t err = append_csv_line_chunk_(req, line_buf, sizeof(line_buf),
                                             &buf_pos, entry);
      if (err != ESP_OK) return err;
    }

    return flush_chunk_buffer_(req, line_buf, &buf_pos);
  }

  void handle_api_v2_history_(AsyncWebServerRequest *request, const char *rest) const {
    // Public history endpoint used by dashboard charts and aggregator proxy.
    // Phase 7 v7.7.1.1: Chunked HTTP streaming for consistency with
    // handle_history_() and future-proofing for per-device NVS reads.

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

    if (!devices[dev_idx].metric_defs[metric_idx].history_enabled ||
        devices[dev_idx].metric_states[metric_idx].history == nullptr) {
      request->send(404);
      return;
    }

    HistoryBuffer *buf = devices[dev_idx].metric_states[metric_idx].history;

    httpd_req_t *raw_req = static_cast<httpd_req_t *>(*request);
    httpd_resp_set_type(raw_req, "text/plain");
    httpd_resp_set_hdr(raw_req, "Cache-Control", "no-store");

    esp_err_t err = send_history_buffer_chunk_(raw_req, *buf);
    if (err != ESP_OK) {
      ESP_LOGW(TAG, "V2 history chunked send failed: %s", esp_err_to_name(err));
      finalize_chunked_response_(raw_req, "V2 history", err);
      return;
    }

    finalize_chunked_response_(raw_req, "V2 history");
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
    // Phase 7 v7.7.1.1: Chunked HTTP streaming (BUG-082 fix).
    // Streams NVS segments directly to the response without building
    // a full std::string in RAM. Peak heap: ~744 bytes vs ~40 KB.

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

    uint32_t latest_flash_epoch = 0;
    nvs_handle_t handle;
    bool have_nvs = open_history_nvs_(&handle, NVS_READONLY);
    HistoryMeta meta = {};
    httpd_req_t *raw_req = static_cast<httpd_req_t *>(*request);

    httpd_resp_set_type(raw_req, "text/plain");
    httpd_resp_set_hdr(raw_req, "Cache-Control", "no-store");

    if (have_nvs) {
      if (load_history_meta_(handle, &meta) && meta.valid_segments > 0) {
        SegmentSnapshot *snapshot = allocate_snapshot_();
        if (snapshot != nullptr) {
          int oldest_slot =
              (meta.next_slot + PERSIST_SLOTS - meta.valid_segments) % PERSIST_SLOTS;

          for (int n = 0; n < meta.valid_segments; n++) {
            maybe_yield_nvs_scan_(n);
            int slot = (oldest_slot + n) % PERSIST_SLOTS;
            if (!load_snapshot_from_handle_(handle, slot, snapshot)) continue;

            esp_err_t err = send_snapshot_series_chunk_(
                raw_req, *snapshot, sensor_idx, series_kind);
            if (err != ESP_OK) {
              ESP_LOGW(TAG, "Chunked send failed at segment %d: %s",
                       n, esp_err_to_name(err));
              delete snapshot;
              nvs_close(handle);
              finalize_chunked_response_(raw_req, "History stream", err);
              return;
            }

            if (snapshot->header.last_epoch > latest_flash_epoch) {
              latest_flash_epoch = snapshot->header.last_epoch;
            }
          }
          delete snapshot;
        } else {
          ESP_LOGE(TAG, "History stream: failed to allocate snapshot buffer");
        }
      }
      nvs_close(handle);
    }

    esp_err_t err = send_history_buffer_chunk_(raw_req, *buf, latest_flash_epoch);
    if (err != ESP_OK) {
      ESP_LOGW(TAG, "Chunked send failed for RAM buffer: %s",
               esp_err_to_name(err));
      finalize_chunked_response_(raw_req, "History stream", err);
      return;
    }

    finalize_chunked_response_(raw_req, "History stream");

    ESP_LOGD(TAG, "History streamed for sensor %d/%s (%d NVS segments + RAM)",
             sensor_idx, type, have_nvs ? meta.valid_segments : 0);
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
