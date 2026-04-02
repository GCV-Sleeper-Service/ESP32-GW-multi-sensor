# web_server_idf local component override

## What
Two patches to `web_server_idf.cpp`, method `AsyncWebServer::begin()`:

**Patch 1 — Stack size (BUG-076):** `config.stack_size = 16384` after `HTTPD_DEFAULT_CONFIG()`

**Patch 2 — DELETE handler (BUG-079):** Register an `HTTP_DELETE` URI handler so
ESP-IDF httpd routes DELETE requests to the AsyncWebServer handler chain instead
of returning a plain-text 405 "Specified method is invalid for this resource".

## Why

### Patch 1 — Stack size
ESP-IDF's `HTTPD_DEFAULT_CONFIG()` hardcodes `.stack_size = 4096`.
ESPHome never overrides it. 4 KB is insufficient for any handler that
performs authentication + HTTP response formatting. Stack overflow crashes
with `StoreProhibited` in `vPortYieldFromInt`.

`CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` has zero runtime effect.

### Patch 2 — DELETE handler
Stock ESPHome's `AsyncWebServer::begin()` registers only GET, POST, and OPTIONS
URI handlers. When a DELETE request arrives, ESP-IDF httpd finds no registered
handler for that method and immediately returns its built-in plain-text 405,
before calling any `canHandle()` or `handleRequest()` on our handler objects.
Adding an explicit DELETE handler registration routes DELETE requests through the
same `request_handler` path as GET (no body to read).

## Reference
- BUG-075, BUG-076 (stack size)
- LESSON-OPS-100, LESSON-OPS-101 (stack size)
- Critical Rules 40, 41 (stack size)
- BUG-079 (DELETE handler)
- LESSON-OPS-108, LESSON-OPS-109 (DELETE handler)

## Upstream source
- ESPHome version: Version: 2026.2.1
- Source path: /opt/esphome/.venv/lib/python3.12/site-packages/esphome/components/web_server_idf
- Copied: 2026-03-31T00:00:05-07:00

## After ESPHome upgrade
Re-run: `bash scripts/patch-esphome-httpd-stack.sh`
