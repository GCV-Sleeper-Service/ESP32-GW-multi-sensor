# web_server_idf local component override

## What
Two patches to `web_server_idf.cpp`, method `AsyncWebServer::begin()`:

**Patch 1 - Stack size (BUG-076 + v7.6.9.5):** Conditional `config.stack_size` after `HTTPD_DEFAULT_CONFIG()`: 20480 for ESP32-C3 (RISC-V), 16384 for Xtensa targets (ESP32, ESP32-S3). RISC-V stack frames are ~4x larger than Xtensa due to register window differences.

**Patch 2 - DELETE handler (BUG-079):** Register an `HTTP_DELETE` URI handler so
ESP-IDF httpd routes DELETE requests to the AsyncWebServer handler chain instead
of returning a plain-text 405 "Specified method is invalid for this resource".

## Why

### Patch 1 - Stack size
ESP-IDF's `HTTPD_DEFAULT_CONFIG()` hardcodes `.stack_size = 4096`.
ESPHome never overrides it. 4 KB is insufficient for any handler that
performs authentication + HTTP response formatting. Stack overflow crashes
with `StoreProhibited` in `vPortYieldFromInt`.

`CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` has zero runtime effect.

v7.6.9.5 investigation found that the ESP32-C3 (RISC-V) uses ~15748 B of
httpd stack (watermark 636 B on 16 KB) while Xtensa boards use only ~3340 B
(watermark 13044 B). The RISC-V ABI pushes callee-saved registers per call
frame; Xtensa register windows keep them in hardware. Conditional sizing
avoids wasting 4 KB on heap-constrained Xtensa boards.

### Patch 2 - DELETE handler
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
