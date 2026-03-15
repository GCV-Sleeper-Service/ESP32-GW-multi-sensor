#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Dict, List

from sensor_manifest_lib import ManifestError, fixture_manifest, load_manifest, manifest_v2

VERSION = "7.5.0.1"
ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "config" / "sensors.json"
HEADER_PATH = ROOT / "dashboard" / "sensor_history_multi.h"
YAML_PATH = ROOT / "firmware" / "esp32-c3-multi-sensor.yaml"
JS_PATH = ROOT / "dashboard" / "dashboard.js"
FIXTURE_SENSORS_PATH = ROOT / "tests" / "fixtures" / "sensors.json"
FIXTURE_MANIFEST_PATH = ROOT / "tests" / "fixtures" / "manifest.json"
FIXTURE_STATUS_PATH = ROOT / "tests" / "fixtures" / "api-status.json"

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


class RenderError(Exception):
    pass


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
    lines = [f"static constexpr int NUM_SENSORS = {len(sensors)};", "", "static SensorSlot sensors[NUM_SENSORS] = {"]
    for sensor in sensors:
        lines.extend(
            [
                "  { .id = \"%s\", .name = \"%s\", .mac = \"%s\" },"
                % (sensor["id"], sensor["name"], sensor["mac"])
            ]
        )
    lines.append("};")
    return "\n".join(lines)


def render_js_block(sensors: List[Dict[str, str]]) -> str:
    lines = ["var DEFAULT_SENSOR_META = ["]
    for sensor in sensors:
        lines.append(f"  {{ id: '{sensor['id']}', name: '{sensor['name']}' }},")
    lines.append("];\n")
    return "\n".join(lines)


def avg_lines(sensor: Dict[str, str], idx: int) -> List[str]:
    sid = sensor["id"]
    name = sensor["name"]
    return [
        f" // ── {name} ─────────────────────────────────────",
        f" sensors[{idx}].compute_and_format(epoch);",
        f" id(avg_temp_{sid}).publish_state(sensors[{idx}].temp_avg_str);",
        f" id(avg_hum_{sid}).publish_state(sensors[{idx}].hum_avg_str);",
        f" if (sensors[{idx}].batt_last >= 0) id(battery_{sid}).publish_state(sensors[{idx}].batt_str);",
        "",
    ]


def render_yaml_averaging(sensors: List[Dict[str, str]]) -> str:
    lines = [YAML_AVG_BEGIN]
    for idx, sensor in enumerate(sensors):
        lines.extend(avg_lines(sensor, idx))
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
             sensors[{idx}].add_temp(x);
             auto now = id(sntp_time).now();
             if (now.is_valid()) {{
               sensors[{idx}].mark_seen(now.timestamp);
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
             sensors[{idx}].add_hum(x);
             auto now = id(sntp_time).now();
             if (now.is_valid()) {{
               sensors[{idx}].mark_seen(now.timestamp);
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
             sensors[{idx}].set_battery(x);
             auto now = id(sntp_time).now();
             if (now.is_valid()) {{
               sensors[{idx}].mark_seen(now.timestamp);
               char seen_buf[20];
               snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d", now.hour, now.minute, now.second, now.month, now.day_of_month);
               id(last_seen_{sid}).publish_state(seen_buf);
             }}
             if (sensors[{idx}].batt_last >= 0) id(battery_{sid}).publish_state(sensors[{idx}].batt_str);
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


def render_header_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"sensor_history_multi-v[0-9.]+\.h", f"sensor_history_multi-v{VERSION}.h", text)
    text = re.sub(
        r"// ── SENSOR COUNT CONFIGURATION GUIDE \(v[0-9.]+\) ──",
        f"// ── SENSOR COUNT CONFIGURATION GUIDE (v{VERSION}) ──",
        text,
    )
    return replace_marker_block(text, HEADER_BEGIN, HEADER_END, render_header_block(sensors))


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

def render_yaml_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"# ESP32-C3 Multi-Sensor Gateway - v[0-9.]+", f"# ESP32-C3 Multi-Sensor Gateway - v{VERSION}", text)
    text = re.sub(r'register_history_handler\((.*?), "v[0-9.]+"\);', rf'register_history_handler(\1, "v{VERSION}");', text, count=1)
    text = text.replace("v7.4.5.1", f"v{VERSION}")
    text = apply_yaml_marker_block(text, YAML_AVG_BEGIN, YAML_AVG_END, unwrap_marker_body(render_yaml_averaging(sensors), YAML_AVG_BEGIN, YAML_AVG_END))
    text = apply_yaml_marker_block(text, YAML_GROUP_BEGIN, YAML_GROUP_END, unwrap_marker_body(render_yaml_sorting_groups(sensors), YAML_GROUP_BEGIN, YAML_GROUP_END))
    text = apply_yaml_marker_block(text, YAML_THERMO_BEGIN, YAML_THERMO_END, unwrap_marker_body(render_yaml_thermopro(sensors), YAML_THERMO_BEGIN, YAML_THERMO_END))
    text = apply_yaml_marker_block(text, YAML_RSSI_BEGIN, YAML_RSSI_END, unwrap_marker_body(render_yaml_rssi(sensors), YAML_RSSI_BEGIN, YAML_RSSI_END))
    text = apply_yaml_marker_block(text, YAML_TEXT_BEGIN, YAML_TEXT_END, unwrap_marker_body(render_yaml_text_sensors(sensors), YAML_TEXT_BEGIN, YAML_TEXT_END))
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Render generated sensor-config sections from config/sensors.json")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true", help="Verify generated files are in sync")
    group.add_argument("--write", action="store_true", help="Rewrite generated files in place")
    args = parser.parse_args()

    try:
        sensors = load_manifest(MANIFEST_PATH)
    except ManifestError as exc:
        print(f"Manifest error: {exc}", file=sys.stderr)
        return 2

    expected_header = render_header_file(HEADER_PATH, sensors)
    expected_yaml = render_yaml_file(YAML_PATH, sensors)
    expected_js = render_js_file(JS_PATH, sensors)
    expected_fixture_sensors = json.dumps(fixture_manifest(sensors), indent=2) + "\n"
    expected_fixture_manifest = json.dumps(manifest_v2(sensors, f"v{VERSION}"), indent=2, ensure_ascii=False) + "\n"
    expected_fixture_status = json.dumps(
        {
            "ok": True,
            "version": f"v{VERSION}",
            "sensor_count": len(sensors),
            "sensors": fixture_manifest(sensors),
            "mode": "active-manifest",
            "connected": True,
        },
        indent=2,
    ) + "\n"

    expected = {
        HEADER_PATH: expected_header,
        YAML_PATH: expected_yaml,
        JS_PATH: expected_js,
        FIXTURE_SENSORS_PATH: expected_fixture_sensors,
        FIXTURE_MANIFEST_PATH: expected_fixture_manifest,
        FIXTURE_STATUS_PATH: expected_fixture_status,
    }

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
        if write_if_changed(path, content):
            changed.append(str(path.relative_to(ROOT)))
    if changed:
        print("Updated generated files:")
        for item in changed:
            print(f" - {item}")
    else:
        print("No generated-file changes were needed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
