# web_server_idf local component override

## What
One-line patch: `config.stack_size = 16384` after `HTTPD_DEFAULT_CONFIG()`
in `web_server_idf.cpp`, method `AsyncWebServer::begin()`.

## Why
ESP-IDF's `HTTPD_DEFAULT_CONFIG()` hardcodes `.stack_size = 4096`.
ESPHome never overrides it. 4 KB is insufficient for any handler that
performs authentication + HTTP response formatting. Stack overflow crashes
with `StoreProhibited` in `vPortYieldFromInt`.

`CONFIG_HTTPD_STACK_SIZE` in `sdkconfig_options` has zero runtime effect.

## Reference
- BUG-075, BUG-076
- LESSON-OPS-100, LESSON-OPS-101
- Critical Rules 40, 41

## Upstream source
- ESPHome version: Version: 2026.2.1
- Source path: /opt/esphome/.venv/lib/python3.12/site-packages/esphome/components/web_server_idf
- Copied: 2026-03-31T00:00:05-07:00

## After ESPHome upgrade
Re-run: `bash scripts/patch-esphome-httpd-stack.sh`
