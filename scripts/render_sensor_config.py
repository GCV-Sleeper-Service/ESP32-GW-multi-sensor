#!/usr/bin/env python3
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Callable, List, Dict

from sensor_manifest_lib import load_manifest, fixture_manifest, ManifestError

VERSION = '7.4.5.1'
ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / 'config' / 'sensors.json'
HEADER_PATH = ROOT / 'dashboard' / 'sensor_history_multi.h'
YAML_PATH = ROOT / 'firmware' / 'esp32-c3-multi-sensor.yaml'
JS_PATH = ROOT / 'dashboard' / 'dashboard.js'
FIXTURE_PATH = ROOT / 'tests' / 'fixtures' / 'sensors.json'

HEADER_BEGIN = '// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>'
HEADER_END = '// <<< SENSOR_MANIFEST:HEADER_END >>>'
JS_BEGIN = '// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_BEGIN >>>'
JS_END = '// <<< SENSOR_MANIFEST:DEFAULT_SENSOR_META_END >>>'
YAML_AVG_BEGIN = '              // <<< SENSOR_MANIFEST:AVERAGING_BEGIN >>>'
YAML_AVG_END = '              // <<< SENSOR_MANIFEST:AVERAGING_END >>>'
YAML_GROUP_BEGIN = '    # <<< SENSOR_MANIFEST:SORTING_GROUPS_BEGIN >>>'
YAML_GROUP_END = '    # <<< SENSOR_MANIFEST:SORTING_GROUPS_END >>>'
YAML_THERMO_BEGIN = '  # <<< SENSOR_MANIFEST:THERMOPRO_BEGIN >>>'
YAML_THERMO_END = '  # <<< SENSOR_MANIFEST:THERMOPRO_END >>>'
YAML_RSSI_BEGIN = '  # <<< SENSOR_MANIFEST:RSSI_BEGIN >>>'
YAML_RSSI_END = '  # <<< SENSOR_MANIFEST:RSSI_END >>>'
YAML_TEXT_BEGIN = '  # <<< SENSOR_MANIFEST:TEXT_SENSORS_BEGIN >>>'
YAML_TEXT_END = '  # <<< SENSOR_MANIFEST:TEXT_SENSORS_END >>>'


class RenderError(Exception):
    pass


def apply_marker_block(text: str, begin: str, end: str, body: str) -> str:
    block = begin + '\n' + body.rstrip() + '\n' + end
    if begin in text and end in text:
        pattern = re.escape(begin) + r'.*?' + re.escape(end)
        return re.sub(pattern, lambda _m: block, text, flags=re.S)
    raise RenderError(f'Marker pair not found: {begin} .. {end}')


def replace_between_anchors(text: str, start_pattern: str, end_pattern: str, replacement_block: str) -> str:
    pattern = re.compile(start_pattern + r'.*?' + end_pattern, flags=re.S)
    if not pattern.search(text):
        raise RenderError('Legacy replacement anchor not found.')
    return pattern.sub(replacement_block, text, count=1)


def render_header_block(sensors: List[Dict[str, str]]) -> str:
    lines = [
        HEADER_BEGIN,
        f'static constexpr int NUM_SENSORS = {len(sensors)};',
        '',
        'static SensorSlot sensors[NUM_SENSORS] = {',
    ]
    for sensor in sensors:
        lines.extend([
            '  {',
            f'    .id   = "{sensor["id"]}",',
            f'    .name = "{sensor["name"]}",',
            f'    .mac  = "{sensor["mac"]}"',
            '  },',
        ])
    lines.extend([
        '};',
        HEADER_END,
    ])
    return '\n'.join(lines)


def render_js_block(sensors: List[Dict[str, str]]) -> str:
    lines = [JS_BEGIN, 'var DEFAULT_SENSOR_META = [']
    for sensor in sensors:
        lines.append(f"  {{ id: '{sensor['id']}', name: '{sensor['name']}' }},")
    lines.append('];')
    lines.append(JS_END)
    return '\n'.join(lines)


def avg_lines(sensor: Dict[str, str], idx: int) -> List[str]:
    sid = sensor['id']
    name = sensor['name']
    return [
        f'              // ── {name} ─────────────────────────────────────',
        f'              sensors[{idx}].compute_and_format(epoch);',
        f'              id(avg_temp_{sid}).publish_state(sensors[{idx}].temp_avg_str);',
        f'              id(avg_hum_{sid}).publish_state(sensors[{idx}].hum_avg_str);',
        f'              if (sensors[{idx}].batt_last >= 0)',
        f'                id(battery_{sid}).publish_state(sensors[{idx}].batt_str);',
        '',
    ]


def render_yaml_averaging(sensors: List[Dict[str, str]]) -> str:
    lines = [YAML_AVG_BEGIN]
    for idx, sensor in enumerate(sensors):
        lines.extend(avg_lines(sensor, idx))
    if lines[-1] == '':
        lines.pop()
    lines.append(YAML_AVG_END)
    return '\n'.join(lines)


def render_yaml_sorting_groups(sensors: List[Dict[str, str]]) -> str:
    lines = [YAML_GROUP_BEGIN]
    for idx, sensor in enumerate(sensors, start=1):
        lines.extend([
            f'    - id: group_{sensor["id"]}',
            f'      name: "{sensor["name"]}"',
            f'      sorting_weight: {idx * 10}',
        ])
    lines.append(YAML_GROUP_END)
    return '\n'.join(lines)


def thermopro_block(sensor: Dict[str, str], idx: int) -> str:
    sid = sensor['id']
    name = sensor['name']
    mac = sensor['mac']
    return f'''  # ══════════════════════════════════════════════════════════════════
  # SENSOR {idx}: {name.upper()} — MAC {mac}
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
                snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d",
                         now.hour, now.minute, now.second,
                         now.month, now.day_of_month);
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
                snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d",
                         now.hour, now.minute, now.second,
                         now.month, now.day_of_month);
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
                snprintf(seen_buf, sizeof(seen_buf), "%02d:%02d:%02d %02d/%02d",
                         now.hour, now.minute, now.second,
                         now.month, now.day_of_month);
                id(last_seen_{sid}).publish_state(seen_buf);
              }}
              if (sensors[{idx}].batt_last >= 0)
                id(battery_{sid}).publish_state(sensors[{idx}].batt_str);
'''


def render_yaml_thermopro(sensors: List[Dict[str, str]]) -> str:
    chunks = [YAML_THERMO_BEGIN]
    for idx, sensor in enumerate(sensors):
        chunks.append(thermopro_block(sensor, idx).rstrip())
        chunks.append('')
    if chunks[-1] == '':
        chunks.pop()
    chunks.append(YAML_THERMO_END)
    return '\n'.join(chunks)


def rssi_block(sensor: Dict[str, str]) -> str:
    sid = sensor['id']
    name = sensor['name']
    mac = sensor['mac']
    return f'''  - platform: ble_rssi
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
    chunks = [YAML_RSSI_BEGIN]
    for sensor in sensors:
        chunks.append(rssi_block(sensor))
        chunks.append('')
    if chunks[-1] == '':
        chunks.pop()
    chunks.append(YAML_RSSI_END)
    return '\n'.join(chunks)


def text_sensor_block(sensor: Dict[str, str]) -> str:
    sid = sensor['id']
    name = sensor['name']
    return f'''  # ══════════════════════════════════════════════════════════════════
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
    chunks = [YAML_TEXT_BEGIN]
    for sensor in sensors:
        chunks.append(text_sensor_block(sensor))
        chunks.append('')
    if chunks[-1] == '':
        chunks.pop()
    chunks.append(YAML_TEXT_END)
    return '\n'.join(chunks)


def update_versions(text: str, patterns: List[tuple[str, str]]) -> str:
    for pattern, repl in patterns:
        text = re.sub(pattern, repl, text)
    return text


def render_header_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding='utf-8')
    text = update_versions(text, [
        (r'sensor_history_multi-v[0-9.]+\.h', f'sensor_history_multi-v{VERSION}.h'),
        (r'// ── SENSOR COUNT CONFIGURATION GUIDE \(v[0-9.]+\) ──', f'// ── SENSOR COUNT CONFIGURATION GUIDE (v{VERSION}) ──'),
    ])
    block = render_header_block(sensors)
    if HEADER_BEGIN in text:
        return apply_marker_block(text, HEADER_BEGIN, HEADER_END, block[len(HEADER_BEGIN)+1:-(len(HEADER_END)+1)])
    pattern = re.compile(r'static constexpr int NUM_SENSORS = \d+;\n\nstatic SensorSlot sensors\[NUM_SENSORS\] = \{.*?\n\};', re.S)
    if not pattern.search(text):
        raise RenderError('Could not find header sensor config block.')
    return pattern.sub(lambda _m: block, text, count=1)


def render_js_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding='utf-8')
    text = update_versions(text, [(r"App\.version = 'v[0-9.]+'", f"App.version = 'v{VERSION}'")])
    block = render_js_block(sensors)
    pattern = re.compile(r'var DEFAULT_SENSOR_META = \[.*?\];', re.S)
    if JS_BEGIN in text:
        return apply_marker_block(text, JS_BEGIN, JS_END, block[len(JS_BEGIN)+1:-(len(JS_END)+1)])
    if not pattern.search(text):
        raise RenderError('Could not find DEFAULT_SENSOR_META block.')
    return pattern.sub(lambda _m: block, text, count=1)


def render_yaml_file(path: Path, sensors: List[Dict[str, str]]) -> str:
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'^# ESP32-C3 Multi-Sensor Gateway - v[0-9.]+', f'# ESP32-C3 Multi-Sensor Gateway - v{VERSION}', text, count=1, flags=re.M)
    text = re.sub(r'register_history_handler\((.*?), "v[0-9.]+"\);', rf'register_history_handler(\1, "v{VERSION}");', text, count=1)
    text = re.sub(r'live dashboard\. v[0-9.]+:', f'live dashboard. v{VERSION}:', text, count=1)
    text = re.sub(r'# /dashboard-download\. v[0-9.]+ adds', f'# /dashboard-download. v{VERSION} adds', text, count=1)
    text = re.sub(r'# ║  BLE Sensors — \d+× ThermoPro TP357', f'# ║  BLE Sensors — {len(sensors)}× ThermoPro TP357', text, count=1)

    avg_block = render_yaml_averaging(sensors)
    if YAML_AVG_BEGIN in text:
        text = apply_marker_block(text, YAML_AVG_BEGIN, YAML_AVG_END, avg_block[len(YAML_AVG_BEGIN)+1:-(len(YAML_AVG_END)+1)])
    else:
        avg_pattern = re.compile(r'(?ms)(\s+uint32_t epoch = now.timestamp;\n)(.*?)(\n\s+// ── Shared clock update ────────────────────────)')
        m = avg_pattern.search(text)
        if not m:
            raise RenderError('Could not locate averaging lambda sensor block.')
        text = text[:m.start(2)] + avg_block + m.group(3) + text[m.end(3):]

    groups_block = render_yaml_sorting_groups(sensors)
    if YAML_GROUP_BEGIN in text:
        text = apply_marker_block(text, YAML_GROUP_BEGIN, YAML_GROUP_END, groups_block[len(YAML_GROUP_BEGIN)+1:-(len(YAML_GROUP_END)+1)])
    else:
        group_pattern = re.compile(r'(?ms)(\s+- id: group_dashboard\n\s+name: "Dashboard Access"\n\s+sorting_weight: 5\n)(.*?)(\s+- id: group_diag\n\s+name: "Diagnostics-Info"\n\s+sorting_weight: \d+)')
        m = group_pattern.search(text)
        if not m:
            raise RenderError('Could not locate sorting_groups sensor block.')
        text = text[:m.start(2)] + groups_block + '\n' + m.group(3) + text[m.end(3):]
    text = re.sub(r'(\s+- id: group_diag\n\s+name: "Diagnostics-Info"\n\s+sorting_weight: )\d+', r'\g<1>90', text)

    thermo_block = render_yaml_thermopro(sensors)
    if YAML_THERMO_BEGIN in text:
        text = apply_marker_block(text, YAML_THERMO_BEGIN, YAML_THERMO_END, thermo_block[len(YAML_THERMO_BEGIN)+1:-(len(YAML_THERMO_END)+1)])
    else:
        thermo_pattern = re.compile(r'(?ms)(sensor:\n\n)(.*?)(\n\s+- platform: wifi_signal)')
        m = thermo_pattern.search(text)
        if not m:
            raise RenderError('Could not locate thermopro sensor block.')
        text = text[:m.start(2)] + thermo_block + '\n\n' + m.group(3).lstrip('\n') + text[m.end(3):]

    rssi_block = render_yaml_rssi(sensors)
    if YAML_RSSI_BEGIN in text:
        text = apply_marker_block(text, YAML_RSSI_BEGIN, YAML_RSSI_END, rssi_block[len(YAML_RSSI_BEGIN)+1:-(len(YAML_RSSI_END)+1)])
    else:
        rssi_pattern = re.compile(r'(?ms)(\s+# ── BLE RSSI per sensor ────────────────────────────────────────\n\s+# Uses ESPHome\'s built-in ble_rssi platform to track passive signal\n\s+# strength from each ThermoPro BLE advertisement for dashboard bars\.\n)(.*?)(\n\n# ╔══════════════════════════════════════════════════════════════════╗\n# ║  Text Sensors)')
        m = rssi_pattern.search(text)
        if not m:
            raise RenderError('Could not locate BLE RSSI block.')
        text = text[:m.start(2)] + rssi_block + text[m.start(3):]

    text_block = render_yaml_text_sensors(sensors)
    if YAML_TEXT_BEGIN in text:
        text = apply_marker_block(text, YAML_TEXT_BEGIN, YAML_TEXT_END, text_block[len(YAML_TEXT_BEGIN)+1:-(len(YAML_TEXT_END)+1)])
    else:
        text_pattern = re.compile(r'(?ms)(\s+- platform: template\n\s+name: "Dashboard Paths".*?sorting_weight: 1\n)(.*?)(\n\s+# ── Device diagnostics / About section ─────────────────────────)')
        m = text_pattern.search(text)
        if not m:
            raise RenderError('Could not locate text_sensor sensor block.')
        text = text[:m.end(1)] + '\n\n' + text_block + m.group(3) + text[m.end(3):]

    return text


def diff_message(path: Path, old: str, new: str) -> str:
    diff = difflib.unified_diff(old.splitlines(), new.splitlines(), fromfile=str(path), tofile=str(path), lineterm='')
    return '\n'.join(list(diff)[:200])


def main() -> int:
    parser = argparse.ArgumentParser(description='Render generated sensor configuration from config/sensors.json')
    parser.add_argument('--check', action='store_true', help='Verify generated files are up to date without writing.')
    parser.add_argument('--write', action='store_true', help='Write generated changes to disk.')
    args = parser.parse_args()
    mode_check = args.check and not args.write

    try:
        sensors = load_manifest(MANIFEST_PATH)
    except (OSError, json.JSONDecodeError, ManifestError) as exc:
        print(f'render_sensor_config: FAIL — {exc}', file=sys.stderr)
        return 1

    files = {
        HEADER_PATH: render_header_file(HEADER_PATH, sensors),
        JS_PATH: render_js_file(JS_PATH, sensors),
        YAML_PATH: render_yaml_file(YAML_PATH, sensors),
        FIXTURE_PATH: fixture_manifest(sensors),
    }

    drift = []
    for path, new_text in files.items():
        old_text = path.read_text(encoding='utf-8') if path.exists() else ''
        if old_text != new_text:
            drift.append((path, old_text, new_text))

    if mode_check:
        if drift:
            print('render_sensor_config: FAIL — generated files are out of sync with config/sensors.json. Run: python3 scripts/render_sensor_config.py --write', file=sys.stderr)
            for path, old_text, new_text in drift:
                print(diff_message(path, old_text, new_text), file=sys.stderr)
            return 1
        print(f'render_sensor_config: PASS ({len(sensors)} sensors)')
        return 0

    if not args.write:
        print('render_sensor_config: no action requested. Use --write or --check.', file=sys.stderr)
        return 1

    for path, _, new_text in drift:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(new_text, encoding='utf-8')
        print(f'updated: {path.relative_to(ROOT)}')
    if not drift:
        print('render_sensor_config: nothing changed')
    else:
        print(f'render_sensor_config: wrote {len(drift)} file(s) from config/sensors.json ({len(sensors)} sensors)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
