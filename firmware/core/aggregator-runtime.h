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
static bool recv_exact_(int sock, char *dst, int len) {
  int total = 0;
  while (total < len) {
    int n = lwip_recv(sock, dst + total, len - total, 0);
    if (n <= 0) return false;
    total += n;
  }
  return true;
}

static bool recv_crlf_line_(int sock, char *dst, size_t dst_size, int *out_len) {
  if (dst == nullptr || dst_size < 3 || out_len == nullptr) return false;

  int total = 0;
  while (total < static_cast<int>(dst_size - 1)) {
    int n = lwip_recv(sock, dst + total, 1, 0);
    if (n <= 0) return false;
    total += n;
    if (total >= 2 && dst[total - 2] == '\r' && dst[total - 1] == '\n') {
      dst[total] = '\0';
      *out_len = total;
      return true;
    }
  }
  return false;
}

static bool read_chunked_body_(int sock, char *buf, uint16_t buf_size, uint16_t *out_len) {
  if (buf == nullptr || out_len == nullptr || buf_size == 0) return false;

  int total = 0;
  char line[64];
  for (;;) {
    int line_len = 0;
    if (!recv_crlf_line_(sock, line, sizeof(line), &line_len)) return false;

    char *end = nullptr;
    long chunk_size = strtol(line, &end, 16);
    if (end == line || chunk_size < 0) return false;

    if (chunk_size == 0) {
      do {
        if (!recv_crlf_line_(sock, line, sizeof(line), &line_len)) return false;
      } while (!(line_len == 2 && line[0] == '\r' && line[1] == '\n'));
      break;
    }

    if (total >= static_cast<int>(buf_size - 1)) {
      *out_len = static_cast<uint16_t>(buf_size - 1);
      buf[buf_size - 1] = '\0';
      return true;
    }

    int remaining = static_cast<int>(buf_size - 1) - total;
    if (chunk_size > remaining) {
      if (!recv_exact_(sock, buf + total, remaining)) return false;
      total += remaining;
      *out_len = static_cast<uint16_t>(total);
      buf[total] = '\0';
      return true;
    }

    if (!recv_exact_(sock, buf + total, static_cast<int>(chunk_size))) return false;
    total += static_cast<int>(chunk_size);

    char crlf[2];
    if (!recv_exact_(sock, crlf, sizeof(crlf))) return false;
    if (crlf[0] != '\r' || crlf[1] != '\n') return false;
  }

  buf[total] = '\0';
  *out_len = static_cast<uint16_t>(total);
  return true;
}

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
  hdr[hdr_len] = '\0';

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

  bool is_chunked = strstr(hdr, "\r\nTransfer-Encoding: chunked\r\n") != nullptr;
  if (is_chunked) {
    bool ok = read_chunked_body_(sock, buf, buf_size, out_len);
    lwip_close(sock);
    return ok;
  }

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
