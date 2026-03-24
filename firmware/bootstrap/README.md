# Bootstrap YAML Files

These are minimal ESPHome configurations used for initial board flashing only.
They contain just enough to get a board online (WiFi, OTA, web server) but do NOT
include the full gateway firmware (dashboard, sensors, persistence, aggregator).

After initial flash, use `render_sensor_config.py` with `config/gateway.json` to
generate the full firmware YAML for each board.

These files should NOT be used for production deployment.
