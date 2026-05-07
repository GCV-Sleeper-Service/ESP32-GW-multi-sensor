---
applyTo: "firmware/boards/**"
---
Every board YAML MUST include the external_components block for web_server_idf.
Without it, the 16KB httpd stack override is not compiled and the board crashes under load.
Board profiles are consumed by render_sensor_config.py — changes here affect generated configs.