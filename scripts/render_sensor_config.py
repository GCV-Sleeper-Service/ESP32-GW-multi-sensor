#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Dict, List

from sensor_manifest_lib import ManifestError, fixture_manifest, load_aggregator_config, load_board_profile, load_gateway_config, load_manifest, manifest_v2

VERSION = "7.6.10.4"
ROOT = Path(__file__).resolve().parents[1]
GATEWAY_MANIFEST_H_PATH = ROOT / "src" / "gateway_manifest.h"
AGGREGATOR_CONFIG_H_PATH = ROOT / "src" / "aggregator_config.h"
AGGREGATOR_JSON_PATH = ROOT / "config" / "aggregator.json"
MANIFEST_PATH = ROOT / "config" / "sensors.json"
HEADER_PATH = ROOT / "dashboard" / "sensor_history_multi.h"
YAML_PATH = ROOT / "firmware" / "esp32-c3-multi-sensor.yaml"
JS_PATH = ROOT / "dashboard" / "dashboard.js"
FIXTURE_SENSORS_PATH = ROOT / "tests" / "fixtures" / "sensors.json"
FIXTURE_MANIFEST_PATH = ROOT / "tests" / "fixtures" / "manifest.json"
FIXTURE_STATUS_PATH = ROOT / "tests" / "fixtures" / "api-status.json"

# ── Aggregator scaling constants ─────────────────────────────────
SATELLITE_CAP_PSRAM = 8          # Max satellites for PSRAM-capable boards
AGG_MANIFEST_BUF_SIZE_BYTES = 8192  # Aggregator manifest buffer size in bytes

HEADER_BEGIN = "// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>"
HEADER_END = "// <<< SENSOR_MANIFEST:HEADER_END >>>"
JS_BEGIN = "// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_BEGIN >>>"
JS_END = "// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_END >>>"
YAML_AVG_BEGIN = " // <<< SENSOR_MANIFEST:AVERAGING_BEGIN >>>"
YAML_AVG_END = " // <<< SENSOR_MANIFEST:AVERAGING_END >>>"
YAML_GROUP_BEGIN = " # <<< SENSOR_MANIFEST:SORTING_GROUPS_BEGIN >>>"
YAML_GROUP_END = " # <<< SENSOR_MANIFEST:SORTING_GROUPS_END >>>"
YAML_THERMO_BEGIN = " # <<< SENSOR_MANIFEST:THERMOPRO_BEGIN >>>"
YAML_THERMO_END = " # <<< SENSOR_MANIFEST:THERMOPRO_END >>>"
YAML_RSSI_BEGIN = " # <<< SENSOR_MANIFEST:RSSI_BEGIN >>>"
YAML_RSSI_END = " # <<< SENSOR_MANIFEST:RSSI_END >>>"
YAML_TEXT_BEGIN = " # <<< SENSOR_MANIFEST:TEXT_SENSORS_BEGIN >>>"
YAML_TEXT_END = " # <<< SENSOR_MANIFEST:TEXT_SENSORS_END >>>"
YAML_PING_BOOT_BEGIN = " // <<< SENSOR_MANIFEST:PING_BOOT_BEGIN >>>"
YAML_PING_BOOT_END = " // <<< SENSOR_MANIFEST:PING_BOOT_END >>>"
ENTITY_BEGIN = "// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>"
ENTITY_END = "// <<< SENSOR_MANIFEST:ENTITY_END >>>"


class RenderError(Exception):
    pass


# Physical internal SRAM per ESP32 chip variant (datasheet values, KB).
# These are silicon constants - they do NOT vary at runtime.
# Source: Espressif datasheets.
#   ESP32    (WROOM/WROVER family) - 520 KB
#   ESP32-C3                       - 400 KB
#   ESP32-S3 (internal only; PSRAM reported separately) - 512 KB
SRAM_KB_BY_CHIP = {
    "esp32": "520 KB",
    "esp32c3": "400 KB",
    "esp32c5": "384 KB",
    "esp32c6": "512 KB",
    "esp32s3": "512 KB",
}


def _flash_size_to_kb_string(flash_size: str) -> str:
    """Convert a board profile flash_size value (e.g. '4MB', '16MB') to a 'NNNN KB' string.

    Used to emit the Flash Size text_sensor as a static per-chip value rather than
    a runtime lambda. Flash capacity is a silicon property - it does not change
    at runtime on any ESP32 variant we support.
    """
    s = flash_size.strip().upper()
    if s.endswith("MB"):
        return f"{int(s[:-2]) * 1024} KB"
    if s.endswith("KB"):
        return f"{int(s[:-2])} KB"
    # Defensive fallback - if a new board profile format appears, fail loud.
    raise ValueError(f"Unrecognised flash_size format: {flash_size!r}")


def _sram_size_for_chip(chip_variant: str) -> str:
    """Return the silicon SRAM size string for a given chip_variant."""
    if chip_variant not in SRAM_KB_BY_CHIP:
        # Defensive: if a new chip_variant is added to a board profile, fail loud
        # rather than silently emit a misleading value.
        raise ValueError(
            f"No SRAM constant for chip_variant={chip_variant!r}. "
            f"Add an entry to SRAM_KB_BY_CHIP."
        )
    return SRAM_KB_BY_CHIP[chip_variant]


def replace_marker_block(text: str, begin: str, end: str, body: str) -> str:
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), flags=re.S)
    block = begin + "\n" + body.rstrip() + "\n" + end
    if not pattern.search(text):
        raise RenderError(f"Marker pair not found: {begin} .. {end}")
    return pattern.sub(lambda _m: block, text, count=1)



def unwrap_marker_body(block: str, begin: str, end: str) -> str:
    prefix = begin + '\n'
    suffix = '\n' + end
    if block.startswith(prefix) and block.endswith(suffix):
        return block[len(prefix):-len(suffix)]
    return block

def render_header_block(sensors: List[Dict[str, str]]) -> str:
    lines = [
        "// SensorSlot removed in v7.5.3.8 — all runtime state in SensorEntity devices[].",
        "// NUM_ENV_SENSORS / NUM_SENSORS = persisted environmental-sensor count only (backward-compat alias for SegmentSnapshot / HistoryMeta).",
        "// NUM_DEVICES = total logical devices in manifest (environmental + network + system).",
    ]
    return "\n".join(lines)


def render_entity_block(sensors: List[Dict]) -> str:
    thermopro = [s for s in sensors if s.get("adapter", "thermopro_ble") == "thermopro_ble"]
    ping = [s for s in sensors if s.get("adapter") == "icmp_ping"]
    system = [s for s in sensors if s.get("adapter") == "external_push"]

    lines = [
        "// ── Generated SensorEntity arrays ──────────────────────────────────",
        "// Generated by render_sensor_config.py from config/sensors.json",
        "// Sole runtime model since v7.5.3.8 (SensorSlot removed)",
        "",
        "static const MetricDef metrics_thermopro[] = {",
        '  {"temp",  "Temperature", "\\xC2\\xB0""C", 0, true},',
        '  {"hum",   "Humidity",    "%",            0, true},',
        '  {"batt",  "Battery",     "%",            3, false},',
        '  {"rssi",  "RSSI",        "dBm",          3, false}',
        "};",
        "",
    ]

    if ping:
        lines.extend([
            "static const MetricDef metrics_ping[] = {",
            '  {"ping_ms",     "Latency", "ms", 0, true},',
            '  {"success_pct", "Success", "%",  0, true}',
            "};",
            "",
        ])

    if system:
        lines.extend([
            "static const MetricDef metrics_system[] = {",
            '  {"cpu_pct",    "CPU Usage",  "%", 0, false},',
            '  {"ram_pct",    "RAM Usage",  "%", 0, false},',
            '  {"disk_pct",   "Disk Usage", "%", 0, false},',
            '  {"uptime_hrs", "Uptime",     "h", 3, false}',
            "};",
            "",
        ])

    for sensor in thermopro:
        sid = sensor["id"]
        lines.append(f"static HistoryBuffer entity_hbuf_{sid}_temp;")
        lines.append(f"static HistoryBuffer entity_hbuf_{sid}_hum;")

    for sensor in ping:
        sid = sensor["id"]
        lines.append(f"static HistoryBuffer entity_hbuf_{sid}_ping_ms;")
        lines.append(f"static HistoryBuffer entity_hbuf_{sid}_success_pct;")


    lines.extend([
        "",
        f"static constexpr int NUM_DEVICES = {len(sensors)};",
        f"static constexpr int NUM_ENV_SENSORS = {len(thermopro)};",
        "static constexpr int NUM_SENSORS = NUM_ENV_SENSORS;  // backward compat alias for persisted environmental history",
        "",
    ])

    # Emit PING_DEVICE_INDEX / PING_TARGET for the first icmp_ping device
    for i, s in enumerate(sensors):
        if s.get("adapter") == "icmp_ping":
            lines.extend([
                f"#define PING_DEVICE_INDEX {i}",
                f'#define PING_TARGET "{s["source"]["target"]}"',
                "",
            ])
            break

    lines.extend([
        "static SensorEntity devices[NUM_DEVICES] = {",
    ])

    for sensor in sensors:
        sid = sensor["id"]
        name = sensor["name"]
        adapter = sensor.get("adapter", "thermopro_ble")

        if adapter == "thermopro_ble":
            mac = sensor["mac"]
            lines.extend([
                "  {",
                f'    .id = "{sid}", .name = "{name}",',
                '    .category_id = 0, .adapter = "thermopro_ble",',
                "    .metric_defs = metrics_thermopro,",
                "    .metric_states = {",
                f"      {{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_{sid}_temp}},",
                f"      {{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_{sid}_hum}},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}",
                "    },",
                "    .metric_count = 4,",
                f'    .mac = "{mac}",',
                "    .last_rssi = 0, .last_seen_epoch = 0",
                "  },",
            ])
        elif adapter == "icmp_ping":
            lines.extend([
                "  {",
                f'    .id = "{sid}", .name = "{name}",',
                '    .category_id = 2, .adapter = "icmp_ping",',
                "    .metric_defs = metrics_ping,",
                "    .metric_states = {",
                f"      {{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_{sid}_ping_ms}},",
                f"      {{.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = &entity_hbuf_{sid}_success_pct}},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}",
                "    },",
                "    .metric_count = 2,",
                '    .mac = "",',
                "    .last_rssi = 0, .last_seen_epoch = 0",
                "  },",
            ])
        elif adapter == "external_push":
            lines.extend([
                "  {",
                f'    .id = "{sid}", .name = "{name}",',
                '    .category_id = 1, .adapter = "external_push",',
                "    .metric_defs = metrics_system,",
                "    .metric_states = {",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr},",
                "      {.current_value = NAN, .accumulator = 0, .sample_count = 0, .valid = false, .last_update_epoch = 0, .history = nullptr}",
                "    },",
                "    .metric_count = 4,",
                '    .mac = "",',
                "    .last_rssi = 0, .last_seen_epoch = 0",
                "  },",
            ])

    lines.append("};")
    return "\n".join(lines)


def render_js_block(sensors: List[Dict]) -> str:
    # DEFAULT_SENSOR_META only contains environmental (BLE) sensors
    env_sensors = [s for s in sensors if s.get("adapter", "thermopro_ble") == "thermopro_ble"]
    lines = ["var DEFAULT_SENSOR_META = ["]
    for sensor in env_sensors:
        lines.append(f"  {{ id: '{sensor['id']}', name: '{sensor['name']}' }},")
    lines.append("];\n")
    return "\n".join(lines)


def avg_lines(sensor: Dict, idx: int) -> List[str]:
    sid = sensor["id"]
    name = sensor["name"]
    return [
        f" // ── {name} ─────────────────────────────────────",
        f" devices[{idx}].compute_and_format(epoch);",
        f" id(avg_temp_{sid}).publish_state(devices[{idx}].temp_avg_str);",
        f" id(avg_hum_{sid}).publish_state(devices[{idx}].hum_avg_str);",
        f" if (devices[{idx}].batt_last >= 0) id(battery_{sid}).publish_state(devices[{idx}].batt_str);",
        "",
    ]


def render_yaml_averaging(sensors: List[Dict], all_sensors: List[Dict] = None) -> str:
    """Generate the interval averaging lambda.
    sensors     = ThermoPro-only list (existing behavior for compute_and_format calls).
    all_sensors = full device list; adds compute_averages() for non-ThermoPro history devices."""
    lines = [YAML_AVG_BEGIN]
    for idx, sensor in enumerate(sensors):
        lines.extend(avg_lines(sensor, idx))

    # Add compute_averages() for non-ThermoPro history devices
    if all_sensors:
        for i, s in enumerate(all_sensors):
            adapter = s.get("adapter")
            if adapter in ("icmp_ping", "external_push"):
                label = "network" if adapter == "icmp_ping" else "system"
                lines.extend([
                    f" // ── {s['name']} ({label}) ──────────────────────────────",
                    f" devices[{i}].compute_averages(epoch);",
                    "",
                ])

    while lines and lines[-1] == "":
        lines.pop()
    lines.append(YAML_AVG_END)
    return "\n".join(lines)


def render_yaml_sorting_groups(sensors: List[Dict[str, str]]) -> str:
    lines = [YAML_GROUP_BEGIN]
    for idx, sensor in enumerate(sensors, start=1):
        lines.extend(
            [
                f" - id: group_{sensor['id']}",
                f"   name: \"{sensor['name']}\"",
                f"   sorting_weight: {idx * 10}",
            ]
        )
    lines.append(YAML_GROUP_END)
    return "\n".join(lines)


def thermopro_block(sensor: Dict[str, str], idx: int) -> str:
    sid = sensor["id"]
    name = sensor["name"]
    mac = sensor["mac"]
    return f''' # ══════════════════════════════════════════════════════════════════
 # SENSOR {idx + 1}: {name.upper()} — MAC {mac}
 # ══════════════════════════════════════════════════════════════════
 - platform: thermopro_ble
   mac_address: "{mac}"
   temperature:
     id: raw_temp_{sid}
     name: "{name} Temp Raw"
     internal: true
     on_value:
       then:
         - lambda: |-
             devices[{idx}].add_sample(0, x);
             devices[{idx}].mark_seen(::time(nullptr));
             auto now = id(sntp_time).now();
             if (now.is_valid()) {{
               char seen_buf[20];
               snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d", now.hour, now.minute, now.second, now.month, now.day_of_month);
               id(last_seen_{sid}).publish_state(seen_buf);
             }}
             if (!isnan(x) && x > -50.0f && x < 80.0f) {{
               float f = x * 9.0f / 5.0f + 32.0f;
               char buf[32];
               snprintf(buf, sizeof(buf), "%.1f \\xC2\\xB0" "C / %.1f \\xC2\\xB0" "F", x, f);
               id(cur_temp_{sid}).publish_state(buf);
             }}
   humidity:
     id: raw_hum_{sid}
     name: "{name} Hum Raw"
     internal: true
     on_value:
       then:
         - lambda: |-
             devices[{idx}].add_sample(1, x);
             devices[{idx}].mark_seen(::time(nullptr));
             auto now = id(sntp_time).now();
             if (now.is_valid()) {{
               char seen_buf[20];
               snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d", now.hour, now.minute, now.second, now.month, now.day_of_month);
               id(last_seen_{sid}).publish_state(seen_buf);
             }}
             if (!isnan(x) && x >= 0.0f && x <= 100.0f) {{
               char buf[16];
               snprintf(buf, sizeof(buf), "%.1f %%", x);
               id(cur_hum_{sid}).publish_state(buf);
             }}
   battery_level:
     id: raw_batt_{sid}
     name: "{name} Battery Raw"
     internal: true
     on_value:
       then:
         - lambda: |-
             devices[{idx}].set_battery(x);
             devices[{idx}].mark_seen(::time(nullptr));
             auto now = id(sntp_time).now();
             if (now.is_valid()) {{
               char seen_buf[20];
               snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d", now.hour, now.minute, now.second, now.month, now.day_of_month);
               id(last_seen_{sid}).publish_state(seen_buf);
             }}
             if (devices[{idx}].batt_last >= 0) id(battery_{sid}).publish_state(devices[{idx}].batt_str);
'''


def render_yaml_thermopro(sensors: List[Dict[str, str]]) -> str:
    parts = [YAML_THERMO_BEGIN]
    for idx, sensor in enumerate(sensors):
        parts.append(thermopro_block(sensor, idx).rstrip())
        parts.append("")
    while parts and parts[-1] == "":
        parts.pop()
    parts.append(YAML_THERMO_END)
    return "\n".join(parts)


def rssi_block(sensor: Dict[str, str]) -> str:
    sid = sensor["id"]
    name = sensor["name"]
    mac = sensor["mac"]
    return f'''- platform: ble_rssi
  mac_address: "{mac}"
  name: "{name} RSSI"
  id: {sid}_rssi
  icon: "mdi:signal"
  filters:
    - exponential_moving_average:
        alpha: 0.3
        send_every: 3
        send_first_at: 1
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 16'''


def render_yaml_rssi(sensors: List[Dict[str, str]]) -> str:
    parts = [YAML_RSSI_BEGIN]
    for sensor in sensors:
        parts.append(rssi_block(sensor))
        parts.append("")
    while parts and parts[-1] == "":
        parts.pop()
    parts.append(YAML_RSSI_END)
    return "\n".join(parts)


def text_sensor_block(sensor: Dict[str, str]) -> str:
    sid = sensor["id"]
    name = sensor["name"]
    return f'''# ══════════════════════════════════════════════════════════════════
# {name.upper()} — current readings + 15m averages + battery + last seen
# ══════════════════════════════════════════════════════════════════
- platform: template
  name: "{name} Temperature"
  id: cur_temp_{sid}
  icon: "mdi:thermometer"
  update_interval: never
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 1
- platform: template
  name: "{name} Humidity"
  id: cur_hum_{sid}
  icon: "mdi:water-percent"
  update_interval: never
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 2
- platform: template
  name: "{name} Temp (15m avg)"
  id: avg_temp_{sid}
  icon: "mdi:chart-line"
  update_interval: never
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 3
- platform: template
  name: "{name} Humidity (15m avg)"
  id: avg_hum_{sid}
  icon: "mdi:chart-line"
  update_interval: never
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 4
- platform: template
  name: "{name} Battery"
  id: battery_{sid}
  icon: "mdi:battery"
  update_interval: never
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 5
- platform: template
  name: "{name} Last Seen"
  id: last_seen_{sid}
  icon: "mdi:clock-check-outline"
  update_interval: never
  web_server:
    sorting_group_id: group_{sid}
    sorting_weight: 6'''


def render_yaml_text_sensors(sensors: List[Dict[str, str]]) -> str:
    parts = [YAML_TEXT_BEGIN]
    for sensor in sensors:
        parts.append(text_sensor_block(sensor))
        parts.append("")
    while parts and parts[-1] == "":
        parts.pop()
    parts.append(YAML_TEXT_END)
    return "\n".join(parts)


def render_yaml_ping_boot(sensors: List[Dict]) -> str:
    """Generate the on_boot priority-600 lambda body for icmp_ping adapter initialization.
    The lambda is emitted only when an icmp_ping device is present; otherwise it is empty."""
    ping_devices = [s for s in sensors if s.get("adapter") == "icmp_ping"]
    lines = [YAML_PING_BOOT_BEGIN]
    if ping_devices:
        lines.extend([
            " #ifdef PING_DEVICE_INDEX",
            " static PingAdapter ping_adapter;",
            " ping_adapter.start(PING_DEVICE_INDEX, PING_TARGET);",
            " #endif",
        ])
    lines.append(YAML_PING_BOOT_END)
    return "\n".join(lines)


def render_header_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"sensor_history_multi-v[0-9.]+\.h", f"sensor_history_multi-v{VERSION}.h", text)
    text = re.sub(r"config-v[0-9.]+\.h", f"config-v{VERSION}.h", text)
    text = re.sub(
        r"// ── SENSOR COUNT CONFIGURATION GUIDE \(v[0-9.]+\) ──",
        f"// ── SENSOR COUNT CONFIGURATION GUIDE (v{VERSION}) ──",
        text,
    )
    text = replace_marker_block(text, HEADER_BEGIN, HEADER_END, render_header_block(sensors))
    text = replace_marker_block(text, ENTITY_BEGIN, ENTITY_END, render_entity_block(sensors))
    return text


def render_js_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"App\.version = 'v[0-9.]+'", f"App.version = 'v{VERSION}'", text)
    return replace_marker_block(text, JS_BEGIN, JS_END, render_js_block(sensors))



def apply_yaml_marker_block(text: str, begin: str, end: str, body: str) -> str:
    begin_core = begin.lstrip()
    end_core = end.lstrip()

    marker_match = re.search(
        rf'^(?P<indent>[ \t]*){re.escape(begin_core)}[ \t]*$',
        text,
        flags=re.M,
    )
    if not marker_match:
        raise RenderError(f'YAML marker pair not found: {begin} .. {end}')

    indent = marker_match.group("indent")

    body_lines = body.rstrip().splitlines()
    nonblank = [line for line in body_lines if line.strip()]
    if nonblank:
        min_indent = min(len(re.match(r'[ \t]*', line).group(0)) for line in nonblank)
        body_lines = [line[min_indent:] if line.strip() else '' for line in body_lines]

    indented_body = "\n".join((indent + line) if line.strip() else '' for line in body_lines)
    block = indent + begin_core + "\n" + indented_body.rstrip() + "\n" + indent + end_core

    pattern = re.compile(
        rf'^[ \t]*{re.escape(begin_core)}[ \t]*$.*?^[ \t]*{re.escape(end_core)}[ \t]*$',
        flags=re.M | re.S,
    )
    if not pattern.search(text):
        raise RenderError(f'YAML marker block not found: {begin} .. {end}')
    return pattern.sub(lambda _m: block, text, count=1)

def render_yaml_file(path: Path, sensors: List[Dict]) -> str:
    # YAML blocks only cover ThermoPro BLE sensors; filter other adapters
    ble_sensors = [s for s in sensors if s.get("adapter", "thermopro_ble") == "thermopro_ble"]
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"# ESP32-C3 Multi-Sensor Gateway - v[0-9.]+", f"# ESP32-C3 Multi-Sensor Gateway - v{VERSION}", text)
    text = re.sub(r'register_history_handler\((.*?), "v[0-9.]+"\);', rf'register_history_handler(\1, "v{VERSION}");', text, count=1)
    text = text.replace("v7.4.5.1", f"v{VERSION}")
    text = apply_yaml_marker_block(text, YAML_AVG_BEGIN, YAML_AVG_END, unwrap_marker_body(render_yaml_averaging(ble_sensors, all_sensors=sensors), YAML_AVG_BEGIN, YAML_AVG_END))
    text = apply_yaml_marker_block(text, YAML_GROUP_BEGIN, YAML_GROUP_END, unwrap_marker_body(render_yaml_sorting_groups(ble_sensors), YAML_GROUP_BEGIN, YAML_GROUP_END))
    text = apply_yaml_marker_block(text, YAML_THERMO_BEGIN, YAML_THERMO_END, unwrap_marker_body(render_yaml_thermopro(ble_sensors), YAML_THERMO_BEGIN, YAML_THERMO_END))
    text = apply_yaml_marker_block(text, YAML_RSSI_BEGIN, YAML_RSSI_END, unwrap_marker_body(render_yaml_rssi(ble_sensors), YAML_RSSI_BEGIN, YAML_RSSI_END))
    text = apply_yaml_marker_block(text, YAML_TEXT_BEGIN, YAML_TEXT_END, unwrap_marker_body(render_yaml_text_sensors(ble_sensors), YAML_TEXT_BEGIN, YAML_TEXT_END))
    text = apply_yaml_marker_block(text, YAML_PING_BOOT_BEGIN, YAML_PING_BOOT_END, unwrap_marker_body(render_yaml_ping_boot(sensors), YAML_PING_BOOT_BEGIN, YAML_PING_BOOT_END))
    return text


def unified_diff(old: str, new: str, label: str) -> str:
    return "".join(
        difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            fromfile=f"{label} (current)",
            tofile=f"{label} (expected)",
        )
    )


def write_if_changed(path: Path, content: str) -> bool:
    old = path.read_text(encoding="utf-8") if path.exists() else None
    if old == content:
        return False
    path.write_text(content, encoding="utf-8")
    return True


def generate_gateway_manifest_h(sensors: List[Dict[str, str]], version: str, gateway_meta: Dict[str, str] | None = None) -> str:
    """Generate gateway_manifest.h with v2 manifest as C raw string literal."""
    manifest = manifest_v2(sensors, f"v{version}", gateway_meta=gateway_meta)
    manifest_json = json.dumps(manifest, indent=2, ensure_ascii=False)
    return f'''#pragma once
// gateway_manifest.h — Auto-generated v2 manifest JSON
// Generated by scripts/render_sensor_config.py from config/sensors.json
// DO NOT EDIT — regenerate via: python3 scripts/render_sensor_config.py --write

static const char GATEWAY_MANIFEST_JSON[] = R"MANIFEST(
{manifest_json}
)MANIFEST";
'''


def generate_aggregator_config_h(aggregator_config: Dict | None, board_profile: Dict | None = None) -> str:
    """Generate src/aggregator_config.h from config/aggregator.json (or disabled stub).

    Args:
        aggregator_config: Parsed aggregator.json, or None if no aggregator config.
        board_profile: Parsed board profile YAML with capabilities.psram field.
            If None, defaults to no-PSRAM (aggregator disabled).

    Design decision: Aggregator role REQUIRES PSRAM. Boards without PSRAM are
    satellite-only, even if aggregator.json is present. See
    Docs/architecture-forward-looking-notes.md §1.
    """
    has_psram = False
    if board_profile is not None:
        has_psram = board_profile.get("capabilities", {}).get("psram", False)

    if aggregator_config is None:
        return (
            "#pragma once\n"
            "// Generated by render_sensor_config.py — no aggregator.json present\n"
            "#define AGGREGATOR_ENABLED 0\n"
        )

    # Aggregator config exists — check if the board can run aggregator role
    if not has_psram:
        print("WARNING: aggregator.json is present but this board has no PSRAM. "
              "Aggregator role requires PSRAM — generating AGGREGATOR_ENABLED 0 "
              "(satellite-only mode). See Docs/architecture-forward-looking-notes.md §1.",
              file=sys.stderr)
        return (
            "#pragma once\n"
            "// Generated by render_sensor_config.py\n"
            "// aggregator.json exists but board has no PSRAM — aggregator disabled.\n"
            "// Aggregator role requires PSRAM for safe operation at scale.\n"
            "#define AGGREGATOR_ENABLED 0\n"
        )

    satellites = aggregator_config.get("satellites", [])
    n = len(satellites)

    # PSRAM-aware satellite cap (v7.5.7.0 / Issue #85)
    # Current boards: S3 N16R8 has 8MB PSRAM → cap at 8.
    # Future boards with smaller PSRAM (e.g., 2MB) may warrant a lower cap.
    # For now, any PSRAM = cap at 8.
    board_cap = SATELLITE_CAP_PSRAM
    if n > board_cap:
        print(f"WARNING: aggregator.json lists {n} satellites but board cap is {board_cap}. "
              f"Capping at {board_cap}.",
              file=sys.stderr)
        n = board_cap

    ids_literal = ", ".join(f'"{s["id"]}"' for s in satellites[:n])
    names_literal = ", ".join(f'"{s["name"]}"' for s in satellites[:n])
    urls_literal = ", ".join(f'"{s["base_url"].rstrip("/")}"' for s in satellites[:n])
    polls_literal = ", ".join(str(s.get("poll_interval_seconds", 30)) for s in satellites[:n])

    return (
        "#pragma once\n"
        "// Generated by render_sensor_config.py — do not edit manually\n"
        f"#define AGGREGATOR_ENABLED 1\n"
        f"#define MAX_SATELLITES {n}\n"
        f"#define AGG_MANIFEST_BUF_SIZE {AGG_MANIFEST_BUF_SIZE_BYTES}\n"
        "#define AGGREGATOR_POLL_INTERVAL_DEFAULT 30\n"
        "\n"
        f"static const char* SATELLITE_IDS[] = {{{ids_literal}}};\n"
        f"static const char* SATELLITE_NAMES[] = {{{names_literal}}};\n"
        f"static const char* SATELLITE_URLS[] = {{{urls_literal}}};\n"
        f"static const int SATELLITE_POLL_INTERVALS[] = {{{polls_literal}}};\n"
    )


def get_yaml_output_path(board_profile: Dict, gateway_config: Dict | None) -> Path:
    """Determine the output YAML path based on the board profile."""
    board_id = board_profile['board_id']
    if board_id == 'esp32-c3-supermini' and gateway_config is None:
        return YAML_PATH  # backward compat: no gateway.json → modify existing C3 YAML
    if board_id == 'esp32-c3-supermini' and gateway_config is not None:
        # C3 with gateway.json → generate a named YAML to avoid overwriting the template
        esphome_name = gateway_config.get('esphome_name', 'esp32-c3-gw')
        return ROOT / "firmware" / f"{esphome_name}-gw.yaml"
    return ROOT / "firmware" / f"{board_id}-gw.yaml"


def generate_board_yaml(
    board_profile: Dict,
    gateway_config: Dict,
    sensors: List[Dict],
    aggregator_config: Dict | None,
    version: str,
) -> str:
    """Generate a complete ESPHome YAML for a board from the board profile and sensors."""
    ble_sensors = [s for s in sensors if s.get("adapter", "thermopro_ble") == "thermopro_ble"]
    ping_sensors = [s for s in sensors if s.get("adapter") == "icmp_ping"]
    has_env_sensors = len(ble_sensors) > 0
    has_any_sensors = len(sensors) > 0

    board_id = board_profile['board_id']
    chip_variant = board_profile['chip_variant']
    esphome_board = board_profile['esphome_board']
    flash_size = board_profile['flash_size']
    partitions = board_profile['partitions']
    framework = board_profile['framework']
    sdkconfig = board_profile.get('sdkconfig_options', {})
    psram_config = board_profile.get('psram')
    ext_components = board_profile.get('external_components')
    friendly_name = gateway_config.get('friendly_name', f'{board_id} Gateway')
    esphome_name = gateway_config['esphome_name']
    wifi_address = gateway_config['wifi_address']

    lines = []
    lines.append(f"# {friendly_name} - v{version}")
    lines.append("#")
    lines.append(f"# Generated by render_sensor_config.py for board: {board_id}")
    lines.append(f"# Board profile: firmware/boards/{board_id}.yaml")
    lines.append(f"# Gateway config: config/gateway.json")
    lines.append("#")
    lines.append("# Required files")
    yaml_output_filename = (
        f"{esphome_name}-gw.yaml" if "c3" in board_id.lower() else f"{board_id}-gw.yaml"
    )
    lines.append(f"# - firmware/{yaml_output_filename}")
    lines.append("# - ../dashboard/dashboard.h")
    lines.append("# - ../dashboard/sensor_history_multi.h")
    lines.append(f"# - {partitions}")
    lines.append("# - ../secrets.yaml")
    lines.append("")
    lines.append("# ─── Hourly persistence schedule ──")
    lines.append("substitutions:")
    lines.append('  persist_minute: "10"')
    lines.append("  mgmt_auth_username: !secret gateway_mgmt_username")
    lines.append("  mgmt_auth_password: !secret gateway_mgmt_password")
    lines.append("")

    # ─── Core ESPHome configuration ─────────────────────────────────
    lines.append("# ─── Core ESPHome configuration ─────────────────────────────────")
    lines.append("esphome:")
    lines.append(f'  name: "{esphome_name}"')
    lines.append(f'  friendly_name: "{friendly_name}"')
    lines.append("  min_version: 2025.11.0")
    lines.append("  name_add_mac_suffix: false")
    lines.append("  includes:")
    lines.append("    - ../dashboard/dashboard.h")
    lines.append("    - ../dashboard/sensor_history_multi.h")
    lines.append("    - ../src/gateway_manifest.h")
    lines.append("    - ../src/aggregator_config.h")
    lines.append("  on_boot:")

    # Priority -100: register history handler
    lines.append("    - # Priority -100: run after web server is fully initialized.")
    lines.append('      priority: -100')
    lines.append("      then:")
    lines.append("        - lambda: |-")
    lines.append(f'            register_history_handler(id(web_base), "${{mgmt_auth_username}}", "${{mgmt_auth_password}}", "v{version}");')
    lines.append('            id(dashboard_link).publish_state(')
    lines.append('              "Dashboard: /dashboard or /dashboard.html — Download: /dashboard-download");')

    # Priority 600: ping adapter (only if ping sensors exist)
    if ping_sensors:
        lines.append("    - # Priority 600: run after WiFi and SNTP are available.")
        lines.append("      priority: 600")
        lines.append("      then:")
        lines.append("        - lambda: |-")
        lines.append("            // <<< SENSOR_MANIFEST:PING_BOOT_BEGIN >>>")
        lines.append("            #ifdef PING_DEVICE_INDEX")
        lines.append("            static PingAdapter ping_adapter;")
        lines.append("            ping_adapter.start(PING_DEVICE_INDEX, PING_TARGET);")
        lines.append("            #endif")
        lines.append("            // <<< SENSOR_MANIFEST:PING_BOOT_END >>>")

    # Priority 600: aggregator task
    if aggregator_config is not None:
        lines.append("    - # Priority 600: run after WiFi and SNTP are available.")
        lines.append("      # Starts the aggregator polling task (aggregator role only).")
        lines.append("      priority: 600")
        lines.append("      then:")
        lines.append("        - lambda: |-")
        lines.append("            #if AGGREGATOR_ENABLED")
        lines.append("            start_aggregator_task();")
        lines.append("            #endif")

    lines.append("")

    # ─── Chip and framework ─────────────────────────────────────────
    lines.append("# ─── Chip and framework ─────────────────────────────────────────")
    lines.append("esp32:")
    lines.append(f"  board: {esphome_board}")
    lines.append(f"  variant: {chip_variant}")
    lines.append(f"  flash_size: {flash_size}")
    lines.append(f"  partitions: {partitions}")
    lines.append("  framework:")
    lines.append(f"    type: {framework['type']}")
    if 'advanced' in framework:
        lines.append("    advanced:")
        for k, v in framework['advanced'].items():
            lines.append(f'      {k}: "{v}"')
    if sdkconfig:
        lines.append("    sdkconfig_options:")
        for k, v in sdkconfig.items():
            lines.append(f'      {k}: "{v}"')

    lines.append("")

    # PSRAM (if present in profile)
    if psram_config:
        lines.append("psram:")
        lines.append(f"  mode: {psram_config['mode']}")
        lines.append(f"  speed: {psram_config['speed']}")
        lines.append("")


    # External components (if present in profile)
    if ext_components:
        lines.append("external_components:")
        for ec in ext_components:
            source = ec.get("source", {})
            lines.append("  - source:")
            for sk, sv in source.items():
                lines.append(f"      {sk}: {sv}")
            if "components" in ec:
                comp_list = ec["components"]
                lines.append(f"    components: {comp_list}")
        lines.append("")

    # Logger
    logger_config = board_profile.get('logger', {})
    lines.append("logger:")
    if 'baud_rate' in logger_config:
        lines.append(f"  baud_rate: {logger_config['baud_rate']}")
    lines.append("  level: INFO")
    lines.append("  logs:")
    lines.append("    wifi: WARN")
    lines.append("    api: WARN")
    lines.append("")

    # Debug
    lines.append("# ─── Debug component ─────────────────────────────────────────────")
    lines.append("debug:")
    lines.append("  update_interval: 30s")
    lines.append("")

    # OTA
    lines.append("ota:")
    lines.append("  - platform: esphome")
    lines.append("")

    # API
    lines.append("# ─── Home Assistant API ──────────────────────────────────────────")
    lines.append("api:")
    lines.append("  encryption:")
    lines.append('    key: "6+Hp4ywnRtYt7IEjB/BpsKbjsI9guOoJeSXJ47ya3/k="')
    lines.append("  reboot_timeout: 0s")
    lines.append("")

    # WiFi
    lines.append("# ─── WiFi ────────────────────────────────────────────────────────")
    lines.append("wifi:")
    lines.append("  ssid: !secret wifi_ssid")
    lines.append("  password: !secret wifi_password")
    lines.append(f"  use_address: {wifi_address}")
    manual_ip = gateway_config.get('manual_ip')
    if manual_ip:
        lines.append("  manual_ip:")
        lines.append(f"    static_ip: {manual_ip['static_ip']}")
        lines.append(f"    gateway: {manual_ip['gateway']}")
        lines.append(f"    subnet: {manual_ip['subnet']}")
        if 'dns1' in manual_ip:
            lines.append(f"    dns1: {manual_ip['dns1']}")
    lines.append("")

    # Time + averaging + persistence
    lines.append("# ─── Time synchronization ───────────────────────────────────────")
    lines.append("time:")
    lines.append("  - platform: sntp")
    lines.append("    id: sntp_time")
    lines.append('    timezone: "America/Los_Angeles"')

    if has_any_sensors:
        lines.append("    on_time:")
        lines.append("      - seconds: 0")
        lines.append("        minutes: /15")
        lines.append("        then:")
        lines.append("          - lambda: |-")
        lines.append("              // 15-minute averaging lambda")
        lines.append("              auto now = id(sntp_time).now();")
        lines.append("              if (!now.is_valid()) return;")
        lines.append("              uint32_t epoch = now.timestamp;")
        lines.append("              // <<< SENSOR_MANIFEST:AVERAGING_BEGIN >>>")
        # ThermoPro averaging lines
        for idx, sensor in enumerate(ble_sensors):
            sid = sensor['id']
            name = sensor['name']
            lines.append(f"              // ── {name} ─────────────────────────────────────")
            lines.append(f"              devices[{idx}].compute_and_format(epoch);")
            lines.append(f"              id(avg_temp_{sid}).publish_state(devices[{idx}].temp_avg_str);")
            lines.append(f"              id(avg_hum_{sid}).publish_state(devices[{idx}].hum_avg_str);")
            lines.append(f"              if (devices[{idx}].batt_last >= 0) id(battery_{sid}).publish_state(devices[{idx}].batt_str);")
            lines.append("")
        # Non-ThermoPro averaging lines
        for i, s in enumerate(sensors):
            adapter = s.get("adapter")
            if adapter in ("icmp_ping", "external_push"):
                label = "network" if adapter == "icmp_ping" else "system"
                lines.append(f"              // ── {s['name']} ({label}) ──────────────────────────────")
                lines.append(f"              devices[{i}].compute_averages(epoch);")
        lines.append("              // <<< SENSOR_MANIFEST:AVERAGING_END >>>")
        lines.append("")
        lines.append("              // ── Shared clock update ────────────────────────")
        lines.append("              char time_buf[20];")
        lines.append('              snprintf(time_buf, sizeof(time_buf), "%02d:%02d %02d/%02d",')
        lines.append("                       now.hour, now.minute, now.month, now.day_of_month);")
        lines.append("              id(current_time).publish_state(time_buf);")
        lines.append("")

    if has_any_sensors:
        # on_time already opened by has_any_sensors block above
        lines.append("      - seconds: 0")
        lines.append("        minutes: ${persist_minute}")
        lines.append("        then:")
        lines.append("          - lambda: |-")
        lines.append("              auto now = id(sntp_time).now();")
        lines.append("              if (!now.is_valid()) return;")
        lines.append("              persist_hourly_segment(now.timestamp);")

    lines.append("")
    lines.append("")

    # Web server
    lines.append("# ─── Web server ──────────────────────────────────────────────────")
    lines.append("web_server_base:")
    lines.append("  id: web_base")
    lines.append("")
    lines.append("web_server:")
    lines.append("  port: 80")
    lines.append("  version: 3")
    lines.append("  log: false")
    lines.append("  sorting_groups:")
    lines.append("    - id: group_about")
    lines.append('      name: "About This Gateway"')
    lines.append("      sorting_weight: 1")
    lines.append("    - id: group_dashboard")
    lines.append('      name: "Dashboard Access"')
    lines.append("      sorting_weight: 5")
    # Per-sensor sorting groups
    lines.append("    # <<< SENSOR_MANIFEST:SORTING_GROUPS_BEGIN >>>")
    for idx, sensor in enumerate(ble_sensors, start=1):
        lines.append(f"    - id: group_{sensor['id']}")
        lines.append(f'      name: "{sensor["name"]}"')
        lines.append(f"      sorting_weight: {idx * 10}")
    lines.append("    # <<< SENSOR_MANIFEST:SORTING_GROUPS_END >>>")
    lines.append("")
    lines.append("    - id: group_diag")
    lines.append('      name: "Diagnostics-Info"')
    lines.append("      sorting_weight: 90")
    lines.append("")

    # BLE tracker (only if there are BLE sensors)
    if ble_sensors:
        lines.append("")
        lines.append("# ─── BLE tracker ─────────────────────────────────────────────────")
        lines.append("esp32_ble_tracker:")
        lines.append("")

    # Sensor section
    lines.append("")
    lines.append("sensor:")
    lines.append("")

    # ThermoPro BLE sensors
    if ble_sensors:
        lines.append("  # <<< SENSOR_MANIFEST:THERMOPRO_BEGIN >>>")
        for idx, sensor in enumerate(ble_sensors):
            # thermopro_block() uses 1-space base indent (designed for C3 marker
            # replacement where the block sits inside an existing 2-space context).
            # Generated YAML needs 2-space indent under sensor: to match
            # wifi_signal/debug/uptime items. Add 1 space to each non-empty line.
            block = thermopro_block(sensor, idx).rstrip()
            for line in block.split('\n'):
                lines.append((' ' + line) if line.strip() else '')
            lines.append("")
        # Remove trailing blank
        while lines and lines[-1] == "":
            lines.pop()
        lines.append("  # <<< SENSOR_MANIFEST:THERMOPRO_END >>>")
        lines.append("")

    # Standard diagnostic sensors
    lines.append("  - platform: wifi_signal")
    lines.append('    name: "WiFi Signal"')
    lines.append('    icon: "mdi:wifi"')
    lines.append("    update_interval: 30s")
    lines.append("    web_server:")
    lines.append("      sorting_group_id: group_diag")
    lines.append("      sorting_weight: 33")
    lines.append("")
    lines.append("  - platform: debug")
    lines.append("    free:")
    lines.append('      name: "Free Heap"')
    lines.append("      id: free_heap")
    lines.append('      icon: "mdi:memory"')
    lines.append("      web_server:")
    lines.append("        sorting_group_id: group_diag")
    lines.append("        sorting_weight: 36")
    lines.append("    loop_time:")
    lines.append('      name: "Loop Time"')
    lines.append("      id: loop_time")
    lines.append('      icon: "mdi:timer-sand"')
    lines.append("      web_server:")
    lines.append("        sorting_group_id: group_diag")
    lines.append("        sorting_weight: 38")
    lines.append("")
    lines.append("  - platform: uptime")
    lines.append('    name: "Uptime"')
    lines.append("    id: uptime_sensor")
    lines.append("    type: seconds")
    lines.append("    update_interval: 30s")
    lines.append('    icon: "mdi:clock-outline"')
    lines.append("    web_server:")
    lines.append("      sorting_group_id: group_diag")
    lines.append("      sorting_weight: 37")
    lines.append("")

    # RSSI sensors (only for BLE sensors)
    if ble_sensors:
        lines.append("  # <<< SENSOR_MANIFEST:RSSI_BEGIN >>>")
        for sensor in ble_sensors:
            lines.append("  " + rssi_block(sensor).replace("\n", "\n  "))
            lines.append("")
        while lines and lines[-1] == "":
            lines.pop()
        lines.append("  # <<< SENSOR_MANIFEST:RSSI_END >>>")
        lines.append("")

    # Text sensors section
    lines.append("text_sensor:")
    lines.append("")
    lines.append("  # ── About ──────────────────────────────────────────────────────")
    lines.append("  - platform: template")
    lines.append('    name: "Description"')
    lines.append("    id: about_description")
    lines.append('    icon: "mdi:information-outline"')
    lines.append("    update_interval: never")
    lines.append("    web_server:")
    lines.append("      sorting_group_id: group_about")
    lines.append("      sorting_weight: 1")
    lines.append("")
    lines.append("  # ── Shared ─────────────────────────────────────────────────────")
    lines.append("  - platform: template")
    lines.append('    name: "Current Time"')
    lines.append("    id: current_time")
    lines.append('    icon: "mdi:timeline-clock"')
    lines.append("    update_interval: never")
    lines.append("    web_server:")
    lines.append("      sorting_group_id: group_about")
    lines.append("      sorting_weight: 2")
    lines.append("")


    # Flash Size is a silicon constant; emit as a static string from the board profile.
    # board_profile['flash_size'] is e.g. "4MB" or "16MB" - convert to "KB" for consistency
    # with the prior display format (operator expectations).
    flash_kb_str = _flash_size_to_kb_string(flash_size)
    lines.append("  - platform: template")
    lines.append('    name: "Flash Size"')
    lines.append("    id: flash_size")
    lines.append("    lambda: |-")
    lines.append(f"      return std::string(\"{flash_kb_str}\");")
    lines.append("    update_interval: 60s")
    lines.append("")

    # SRAM is a silicon constant per chip variant. Emit as a static string.
    # These values are the physical internal SRAM on the die (datasheet values),
    # NOT the heap allocator budget. A prior runtime call to
    # heap_caps_get_total_size(...) returned the allocator's
    # usable pool (~255 KB on C3), which is correct-but-misleading relative to
    # the 'SRAM' label. Operators expect the die value.
    sram_kb_str = _sram_size_for_chip(chip_variant)
    lines.append("  - platform: template")
    lines.append('    name: "SRAM Size"')
    lines.append("    id: sram_size")
    lines.append("    lambda: |-")
    lines.append(f"      return std::string(\"{sram_kb_str}\");")
    lines.append("    update_interval: 60s")
    lines.append("")

    lines.append("  - platform: template")
    lines.append('    name: "PSRAM"')
    lines.append("    id: psram_status")
    lines.append("    lambda: |-")
    if psram_config:
        lines.append("      size_t psram_bytes = heap_caps_get_total_size(MALLOC_CAP_SPIRAM);")
        lines.append("      if (psram_bytes == 0) return std::string(\"Unknown\");")
        lines.append("      char buf[32];")
        lines.append("      snprintf(buf, sizeof(buf), \"%u KB\", (unsigned) (psram_bytes / 1024));")
        lines.append("      return std::string(buf);")
    else:
        lines.append("      return std::string(\"None\");")
    lines.append("    update_interval: 60s")
    lines.append("")
    lines.append("  # ── Dashboard Access ───────────────────────────────────────────")
    lines.append("  - platform: template")
    lines.append('    name: "Dashboard Paths"')
    lines.append("    id: dashboard_link")
    lines.append('    icon: "mdi:monitor-dashboard"')
    lines.append("    update_interval: never")
    lines.append("    web_server:")
    lines.append("      sorting_group_id: group_dashboard")
    lines.append("      sorting_weight: 1")
    lines.append("")

    # Per-sensor text sensors
    if ble_sensors:
        lines.append("")
        lines.append("  # <<< SENSOR_MANIFEST:TEXT_SENSORS_BEGIN >>>")
        for sensor in ble_sensors:
            lines.append("  " + text_sensor_block(sensor).replace("\n", "\n  "))
            lines.append("")
        while lines and lines[-1] == "":
            lines.pop()
        lines.append("  # <<< SENSOR_MANIFEST:TEXT_SENSORS_END >>>")
        lines.append("")

    # Debug text sensors (diagnostics)
    lines.append("  # ── Device diagnostics / About section ─────────────────────────")
    lines.append("  - platform: debug")
    lines.append("    device:")
    lines.append("      id: debug_device_raw")
    lines.append("      internal: true")
    lines.append("      on_value:")
    lines.append("        then:")
    lines.append("          - lambda: |-")
    lines.append("              std::string info = x;")
    lines.append("              size_t p, e;")
    lines.append("")
    lines.append('              p = info.find("Chip:");')
    lines.append("              if (p != std::string::npos) {")
    lines.append('                e = info.find("CPU Frequency:");')
    lines.append("                std::string chip_block;")
    lines.append("                if (e != std::string::npos) {")
    lines.append("                  chip_block = info.substr(p + 6, e - p - 6);")
    lines.append("                  while (!chip_block.empty() && (chip_block.back() == '|' || chip_block.back() == ' '))")
    lines.append("                    chip_block.pop_back();")
    lines.append("                } else {")
    lines.append("                  e = info.find('|', p);")
    lines.append("                  chip_block = info.substr(p + 6,")
    lines.append("                    (e != std::string::npos) ? e - p - 6 : std::string::npos);")
    lines.append("                }")
    lines.append("")
    lines.append('                size_t feat_pos = chip_block.find("Features:");')
    lines.append("                if (feat_pos != std::string::npos) {")
    lines.append("                  std::string model = chip_block.substr(0, feat_pos);")
    lines.append("                  while (!model.empty() && model.back() == ' ')")
    lines.append("                    model.pop_back();")
    lines.append("                  id(diag_chip).publish_state(model);")
    lines.append("                } else {")
    lines.append("                  id(diag_chip).publish_state(chip_block);")
    lines.append("                }")
    lines.append("")
    lines.append('                size_t core_pos = chip_block.find("Cores:");')
    lines.append("                if (feat_pos != std::string::npos) {")
    lines.append("                  size_t start = feat_pos + 9;")
    lines.append("                  if (start < chip_block.size() && chip_block[start] == ' ')")
    lines.append("                    start++;")
    lines.append("                  std::string features;")
    lines.append("                  if (core_pos != std::string::npos)")
    lines.append("                    features = chip_block.substr(start, core_pos - start);")
    lines.append("                  else")
    lines.append("                    features = chip_block.substr(start);")
    lines.append("                  while (!features.empty() && features.back() == ' ')")
    lines.append("                    features.pop_back();")
    lines.append("                  id(diag_features).publish_state(features);")
    lines.append("                }")
    lines.append("")
    lines.append('                size_t rev_pos = chip_block.find("Revision:");')
    lines.append("                if (core_pos != std::string::npos) {")
    lines.append("                  size_t start = core_pos + 6;")
    lines.append("                  if (start < chip_block.size() && chip_block[start] == ' ')")
    lines.append("                    start++;")
    lines.append("                  std::string cores;")
    lines.append("                  if (rev_pos != std::string::npos)")
    lines.append("                    cores = chip_block.substr(start, rev_pos - start);")
    lines.append("                  else")
    lines.append("                    cores = chip_block.substr(start);")
    lines.append("                  while (!cores.empty() && cores.back() == ' ')")
    lines.append("                    cores.pop_back();")
    lines.append("                  id(diag_cores).publish_state(cores);")
    lines.append("                }")
    lines.append("")
    lines.append("                if (rev_pos != std::string::npos) {")
    lines.append("                  size_t start = rev_pos + 9;")
    lines.append("                  if (start < chip_block.size() && chip_block[start] == ' ')")
    lines.append("                    start++;")
    lines.append("                  std::string rev = chip_block.substr(start);")
    lines.append("                  while (!rev.empty() && rev.back() == ' ')")
    lines.append("                    rev.pop_back();")
    lines.append("                  id(diag_revision).publish_state(rev);")
    lines.append("                }")
    lines.append("              }")
    lines.append("")
    lines.append('              p = info.find("CPU Frequency:");')
    lines.append("              if (p != std::string::npos) {")
    lines.append("                e = info.find('|', p);")
    lines.append("                std::string cpu = info.substr(p + 15,")
    lines.append("                  (e != std::string::npos) ? e - p - 15 : std::string::npos);")
    lines.append("                while (!cpu.empty() && cpu.back() == ' ')")
    lines.append("                  cpu.pop_back();")
    lines.append("                id(diag_cpu).publish_state(cpu);")
    lines.append("              }")
    lines.append("")
    lines.append('              p = info.find("Framework:");')
    lines.append("              if (p != std::string::npos) {")
    lines.append("                e = info.find('|', p);")
    lines.append("                std::string fw = info.substr(p + 11,")
    lines.append("                  (e != std::string::npos) ? e - p - 11 : std::string::npos);")
    lines.append("                while (!fw.empty() && fw.back() == ' ')")
    lines.append("                  fw.pop_back();")
    lines.append("")
    lines.append('                size_t p2 = info.find("ESP-IDF:");')
    lines.append("                if (p2 != std::string::npos) {")
    lines.append("                  size_t e2 = info.find('|', p2);")
    lines.append("                  std::string idf = info.substr(p2 + 8,")
    lines.append("                    (e2 != std::string::npos) ? e2 - p2 - 8 : std::string::npos);")
    lines.append("                  while (!idf.empty() && idf.back() == ' ')")
    lines.append("                    idf.pop_back();")
    lines.append('                  fw += " | IDF " + idf;')
    lines.append("                }")
    lines.append("                id(diag_framework).publish_state(fw);")
    lines.append("              }")
    lines.append("    reset_reason:")
    lines.append('      name: "Reset Reason"')
    lines.append('      icon: "mdi:restart"')
    lines.append("      web_server:")
    lines.append("        sorting_group_id: group_diag")
    lines.append("        sorting_weight: 35")
    lines.append("")

    # Diagnostic template text sensors
    diag_templates = [
        ("Chip", "diag_chip", "mdi:chip", 3),
        ("Features", "diag_features", "mdi:format-list-bulleted", 4),
        ("Cores", "diag_cores", "mdi:cpu-64-bit", 5),
        ("Revision", "diag_revision", "mdi:tag", 6),
        ("CPU Frequency", "diag_cpu", "mdi:speedometer", 7),
        ("Framework", "diag_framework", "mdi:code-braces", 8),
    ]
    for name, tid, icon, weight in diag_templates:
        lines.append("  - platform: template")
        lines.append(f'    name: "{name}"')
        lines.append(f"    id: {tid}")
        lines.append(f'    icon: "{icon}"')
        lines.append("    update_interval: never")
        lines.append("    web_server:")
        lines.append("      sorting_group_id: group_diag")
        lines.append(f"      sorting_weight: {weight}")
        lines.append("")

    lines.append("  - platform: version")
    lines.append('    name: "ESPHome Version"')
    lines.append('    icon: "mdi:package-variant"')
    lines.append("    web_server:")
    lines.append("      sorting_group_id: group_diag")
    lines.append("      sorting_weight: 9")
    lines.append("")
    lines.append("  - platform: wifi_info")
    lines.append("    ip_address:")
    lines.append('      name: "IP Address"')
    lines.append('      icon: "mdi:ip-network"')
    lines.append("      web_server:")
    lines.append("        sorting_group_id: group_diag")
    lines.append("        sorting_weight: 10")
    lines.append("    mac_address:")
    lines.append('      name: "MAC Address"')
    lines.append('      icon: "mdi:network"')
    lines.append("      web_server:")
    lines.append("        sorting_group_id: group_diag")
    lines.append("        sorting_weight: 11")
    lines.append("")

    # Intervals
    lines.append("")
    lines.append("interval:")
    lines.append("  # Clock display refresh (every 10 seconds)")
    lines.append("  - interval: 10s")
    lines.append("    then:")
    lines.append("      - lambda: |-")
    lines.append("          auto now = id(sntp_time).now();")
    lines.append("          if (now.is_valid()) {")
    lines.append("            char buf[20];")
    lines.append('            snprintf(buf, sizeof(buf), "%02d:%02d:%02d %02d/%02d",')
    lines.append("                     now.hour, now.minute, now.second,")
    lines.append("                     now.month, now.day_of_month);")
    lines.append("            id(current_time).publish_state(buf);")
    lines.append("          }")
    lines.append("")

    # About description
    sensor_desc_parts = []
    if ble_sensors:
        names = ", ".join(s["name"] for s in ble_sensors)
        sensor_desc_parts.append(f"{len(ble_sensors)}x ThermoPro TP357 ({names})")
    if ping_sensors:
        sensor_desc_parts.append("WAN ping monitor")
    system_sensors = [s for s in sensors if s.get("adapter") == "external_push"]
    if system_sensors:
        names = ", ".join(s["name"] for s in system_sensors)
        sensor_desc_parts.append(f"{len(system_sensors)}x system health monitor ({names})")
    sensor_desc = " + ".join(sensor_desc_parts) if sensor_desc_parts else "Pure aggregator (no local sensors)"

    lines.append("  # One-time About description (5 seconds after boot)")
    lines.append("  - interval: 5s")
    lines.append("    then:")
    lines.append("      - lambda: |-")
    lines.append("          static bool published = false;")
    lines.append("          if (!published) {")
    lines.append("            id(about_description).publish_state(")
    lines.append(f'              "{friendly_name} — {sensor_desc}. "')
    lines.append('              "15-min averages, 24h RAM + 45-day flash history. "')
    lines.append('              "Embedded dashboard with charts, CSV export/import, and device management.");')
    lines.append("            published = true;")
    lines.append("          }")
    lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Render generated sensor-config sections from config/sensors.json")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true", help="Verify generated files are in sync")
    group.add_argument("--write", action="store_true", help="Rewrite generated files in place")
    args = parser.parse_args()

    # Load gateway config (optional — absent means C3 default)
    try:
        gateway_config = load_gateway_config()
    except ManifestError as exc:
        print(f"Gateway config error: {exc}", file=sys.stderr)
        return 2

    # Load board profile
    try:
        if gateway_config:
            board_profile = load_board_profile(gateway_config['board'])
        else:
            board_profile = load_board_profile('esp32-c3-supermini')
    except ManifestError as exc:
        print(f"Board profile error: {exc}", file=sys.stderr)
        return 2

    # Allow empty sensors when gateway config is present (pure aggregator mode)
    allow_empty = gateway_config is not None

    # Determine sensor manifest path — gateway config can override the default
    manifest_path = MANIFEST_PATH
    if gateway_config:
        sensors_file = gateway_config.get("sensors_file")
        if isinstance(sensors_file, str) and sensors_file:
            manifest_path = ROOT / sensors_file

    try:
        sensors = load_manifest(manifest_path, allow_empty=allow_empty)
    except ManifestError as exc:
        print(f"Manifest error: {exc}", file=sys.stderr)
        return 2

    try:
        aggregator_config = load_aggregator_config(AGGREGATOR_JSON_PATH)
    except ManifestError as exc:
        print(f"Aggregator config error: {exc}", file=sys.stderr)
        return 2

    expected_header = render_header_file(HEADER_PATH, sensors)
    expected_js = render_js_file(JS_PATH, sensors)

    # Build gateway_meta from board profile and gateway config (BUG-068)
    chip_to_hw = {"esp32c3": "ESP32-C3", "esp32s3": "ESP32-S3", "esp32": "ESP32",
                  "esp32c5": "ESP32-C5", "esp32c6": "ESP32-C6"}
    hw_string = chip_to_hw.get(board_profile.get("chip_variant", "esp32c3"), "ESP32-C3")
    gw_name = gateway_config.get("friendly_name", "Main Gateway") if gateway_config else "Main Gateway"
    gw_id = gateway_config.get("esphome_name", "gw-main") if gateway_config else "gw-main"
    gw_role = "aggregator" if aggregator_config else "satellite"
    gateway_meta = {
        "id": gw_id,
        "name": gw_name,
        "role": gw_role,
        "hardware": hw_string,
    }

    expected_fixture_sensors = json.dumps(fixture_manifest(sensors), indent=2) + "\n"
    expected_fixture_manifest = json.dumps(manifest_v2(sensors, f"v{VERSION}", gateway_meta=gateway_meta), indent=2, ensure_ascii=False) + "\n"
    expected_fixture_status = json.dumps(
        {
            "ok": True,
            "role": gw_role,
            "id": gw_id,
        },
        indent=2,
    ) + "\n"
    expected_gateway_manifest_h = generate_gateway_manifest_h(sensors, VERSION, gateway_meta=gateway_meta)
    expected_aggregator_config_h = generate_aggregator_config_h(aggregator_config, board_profile)

    expected = {
        HEADER_PATH: expected_header,
        JS_PATH: expected_js,
        FIXTURE_SENSORS_PATH: expected_fixture_sensors,
        FIXTURE_MANIFEST_PATH: expected_fixture_manifest,
        FIXTURE_STATUS_PATH: expected_fixture_status,
        GATEWAY_MANIFEST_H_PATH: expected_gateway_manifest_h,
        AGGREGATOR_CONFIG_H_PATH: expected_aggregator_config_h,
    }

    # Determine YAML output path and content based on gateway config
    yaml_output_path = get_yaml_output_path(board_profile, gateway_config)

    if gateway_config:
        # Gateway config present — use full generation for ALL boards (including C3).
        # This applies esphome_name, friendly_name, and wifi_address from gateway.json.
        # Without this, a C3 gateway.json would be silently ignored and multiple C3
        # deployments would collide on hostname/address.
        expected_yaml = generate_board_yaml(board_profile, gateway_config, sensors, aggregator_config, VERSION)
    else:
        # No gateway config — C3 default: modify existing YAML in place (backward compatible).
        # This preserves all comments, formatting, and manual tweaks in the C3 YAML.
        expected_yaml = render_yaml_file(YAML_PATH, sensors)

    expected[yaml_output_path] = expected_yaml

    if args.check:
        diffs: List[str] = []
        for path, content in expected.items():
            current = path.read_text(encoding="utf-8") if path.exists() else ""
            if current != content:
                diffs.append(unified_diff(current, content, str(path.relative_to(ROOT))))
        if diffs:
            sys.stderr.write("Generated files are out of sync with config/sensors.json.\n")
            sys.stderr.write("Run: python3 scripts/render_sensor_config.py --write\n\n")
            sys.stderr.write("\n".join(diffs))
            return 1
        print("render_sensor_config: PASS")
        return 0

    changed = []
    for path, content in expected.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        if write_if_changed(path, content):
            changed.append(str(path.relative_to(ROOT)))
    if changed:
        print("Updated generated files:")
        for item in changed:
            print(f" - {item}")
    else:
        print("No generated-file changes were needed.")

    # Print build instructions for the target board (LESSON-OPS-090)
    yaml_rel = str(yaml_output_path.relative_to(ROOT))
    board_id = board_profile.get("board_id", "unknown")
    print("")
    print("=" * 60)
    print(f"  Build target: {yaml_rel}")
    print(f"  Board:        {board_id} ({hw_string})")
    print(f"  Role:         {gw_role}")
    if gateway_config:
        wifi_addr = gateway_config.get("wifi_address", "unknown")
        print(f"  WiFi address: {wifi_addr}")
    print("-" * 60)
    print(f"  esphome clean {yaml_rel}")
    print(f"  esphome run   {yaml_rel}")
    if gateway_config and gateway_config.get("wifi_address"):
        wifi_addr = gateway_config["wifi_address"]
        print(f"  # OTA target: {wifi_addr}")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
