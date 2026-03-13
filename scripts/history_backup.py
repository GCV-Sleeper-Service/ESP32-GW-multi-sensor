#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import csv
import json
import math
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


EXPORT_SHARED_COLUMNS = ['gateway_host', 'gateway_ip', 'timestamp', 'datetime_utc']
EXPORT_SENSOR_SUFFIXES = ['temp_c', 'temp_f', 'humidity_pct', 'dewpoint_c']
DEFAULT_TIMEOUT = 60


def sensor_slug(value: str) -> str:
    return ''.join(c if c.isalnum() else '_' for c in (value or '').strip().lower()).strip('_')


def request(method: str, url: str, *, auth: Tuple[str, str] | None = None, timeout: int = DEFAULT_TIMEOUT) -> bytes:
    req = urllib.request.Request(url, method=method)
    if auth:
        token = base64.b64encode(f'{auth[0]}:{auth[1]}'.encode('utf-8')).decode('ascii')
        req.add_header('Authorization', f'Basic {token}')
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode('utf-8', 'replace')
        raise RuntimeError(f'HTTP {exc.code} for {url}: {body[:200]}') from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f'Network error for {url}: {exc.reason}') from exc


def fetch_json(url: str, auth=None, timeout: int = DEFAULT_TIMEOUT):
    return json.loads(request('GET', url, auth=auth, timeout=timeout).decode('utf-8'))


def fetch_text(url: str, auth=None, timeout: int = DEFAULT_TIMEOUT):
    return request('GET', url, auth=auth, timeout=timeout).decode('utf-8')


def parse_history_metric_lines(text: str) -> Dict[int, float | None]:
    out: Dict[int, float | None] = {}
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw or ',' not in raw:
            continue
        left, right = raw.split(',', 1)
        try:
            epoch = int(left.strip())
        except ValueError:
            continue
        try:
            value = float(right.strip())
        except ValueError:
            value = None
        out[epoch] = value if value is None or math.isfinite(value) else None
    return out


def calc_dew_point(temp_c: float, humidity: float) -> float | None:
    if humidity <= 0 or humidity > 100:
        return None
    a = 17.62
    b = 243.12
    gamma = (a * temp_c / (b + temp_c)) + math.log(humidity / 100.0)
    return (b * gamma) / (a - gamma)


def format_metric(value):
    if value is None:
        return ''
    return f'{value:.2f}'.rstrip('0').rstrip('.') if isinstance(value, float) else str(value)


def format_utc(epoch: int) -> str:
    import datetime as _dt
    return _dt.datetime.fromtimestamp(epoch, _dt.UTC).strftime('%Y-%m-%d %H:%M:%S')


def build_normalized_rows(temp_text: str, hum_text: str) -> List[Dict[str, float | int | str | None]]:
    temp_map = parse_history_metric_lines(temp_text)
    hum_map = parse_history_metric_lines(hum_text)
    timestamps = sorted(set(temp_map) | set(hum_map))
    rows = []
    for ts in timestamps:
        t_c = temp_map.get(ts)
        hum = hum_map.get(ts)
        t_f = (t_c * 9 / 5 + 32) if isinstance(t_c, (int, float)) else None
        dp = calc_dew_point(t_c, hum) if isinstance(t_c, (int, float)) and isinstance(hum, (int, float)) else None
        rows.append({
            'timestamp': ts,
            'datetime_utc': format_utc(ts),
            'temp_c': t_c,
            'temp_f': t_f,
            'humidity_pct': hum,
            'dewpoint_c': dp,
        })
    return rows


def get_export_sensor_prefix(sensor: Dict[str, str]) -> str:
    return sensor_slug(sensor.get('id') or sensor.get('name') or '')


def build_single_sensor_csv(host_meta: Dict[str, str], sensor: Dict[str, str], rows: List[Dict]) -> str:
    prefix = get_export_sensor_prefix(sensor)
    header = EXPORT_SHARED_COLUMNS + [f'{prefix}_{suffix}' for suffix in EXPORT_SENSOR_SUFFIXES]
    lines = [','.join(header)]
    for row in rows:
        lines.append(','.join([
            host_meta['gateway_host'],
            host_meta['gateway_ip'],
            str(row['timestamp']),
            row['datetime_utc'],
            format_metric(row['temp_c']),
            format_metric(row['temp_f']),
            format_metric(row['humidity_pct']),
            format_metric(row['dewpoint_c']),
        ]))
    return '\n'.join(lines) + '\n'


def build_merged_csv(host_meta: Dict[str, str], sensors: List[Dict[str, str]], sensor_rows_list: List[List[Dict]]) -> str:
    header = EXPORT_SHARED_COLUMNS[:]
    for sensor in sensors:
        prefix = get_export_sensor_prefix(sensor)
        header.extend(f'{prefix}_{suffix}' for suffix in EXPORT_SENSOR_SUFFIXES)
    union: Dict[int, Dict] = {}
    for idx, rows in enumerate(sensor_rows_list):
        for row in rows:
            entry = union.setdefault(row['timestamp'], {'timestamp': row['timestamp'], 'datetime_utc': row['datetime_utc'], 'sensorData': {}})
            entry['sensorData'][idx] = row
    lines = [','.join(header)]
    for ts in sorted(union):
        entry = union[ts]
        out = [host_meta['gateway_host'], host_meta['gateway_ip'], str(ts), entry['datetime_utc']]
        for idx, _sensor in enumerate(sensors):
            row = entry['sensorData'].get(idx)
            out.extend([
                format_metric(row['temp_c']) if row else '',
                format_metric(row['temp_f']) if row else '',
                format_metric(row['humidity_pct']) if row else '',
                format_metric(row['dewpoint_c']) if row else '',
            ])
        lines.append(','.join(out))
    return '\n'.join(lines) + '\n'


def detect_import_columns(header: List[str], sensors: List[Dict[str, str]], file_name: str) -> List[Dict[str, int | str]]:
    results = []
    temp_idx = header.index('temp_c') if 'temp_c' in header else -1
    hum_idx = header.index('humidity_pct') if 'humidity_pct' in header else -1
    has_prefixed = any(h.endswith('_temp_c') for h in header)
    if (temp_idx >= 0 or hum_idx >= 0) and not has_prefixed:
        detected = detect_sensor_id_from_file_name(file_name, sensors)
        if not detected:
            raise RuntimeError('Legacy single-sensor CSV detected, but the sensor could not be identified from the file name.')
        return [{'sensorId': detected, 'tempIdx': temp_idx, 'humIdx': hum_idx}]
    for sensor in sensors:
        prefix = get_export_sensor_prefix(sensor).lower()
        ti = header.index(f'{prefix}_temp_c') if f'{prefix}_temp_c' in header else -1
        hi = header.index(f'{prefix}_humidity_pct') if f'{prefix}_humidity_pct' in header else -1
        if ti >= 0 or hi >= 0:
            results.append({'sensorId': sensor['id'], 'tempIdx': ti, 'humIdx': hi})
    return results


def legacy_name_phrases(file_name: str) -> set[str]:
    stem = Path(file_name).stem.lower()
    tokens = [tok for tok in re.split(r'[^a-z0-9]+', stem) if tok]
    phrases = set(tokens)
    for start in range(len(tokens)):
        for end in range(start + 2, len(tokens) + 1):
            phrases.add('_'.join(tokens[start:end]))
    phrases.add(sensor_slug(stem))
    return phrases


def detect_sensor_id_from_file_name(file_name: str, sensors: List[Dict[str, str]]) -> str:
    phrases = legacy_name_phrases(file_name)
    matches: List[tuple[int, str]] = []
    for sensor in sensors:
        checks = {
            sensor_slug(sensor.get('id', '')),
            sensor_slug(sensor.get('name', '')),
            sensor_slug(get_export_sensor_prefix(sensor)),
        }
        for token in checks:
            if token and token in phrases:
                matches.append((len(token), sensor['id']))
                break
    if not matches:
        return ''
    max_len = max(length for length, _sid in matches)
    winners = sorted({_sid for length, _sid in matches if length == max_len})
    return winners[0] if len(winners) == 1 else ''


def parse_import_csv(path: Path, sensors: List[Dict[str, str]]) -> List[Dict[str, str | int | float]]:
    with path.open('r', encoding='utf-8', newline='') as handle:
        reader = csv.reader(handle)
        rows = list(reader)
    if len(rows) < 2:
        raise RuntimeError('CSV file is too short; expected header plus data rows.')
    header = [c.strip().lower() for c in rows[0]]
    if 'timestamp' not in header:
        raise RuntimeError('Missing timestamp column.')
    ts_idx = header.index('timestamp')
    sensor_columns = detect_import_columns(header, sensors, path.name)
    if not sensor_columns:
        raise RuntimeError('Could not find importable temp/humidity columns for currently configured sensors.')
    points: List[Dict[str, str | int | float]] = []
    for cols in rows[1:]:
        if ts_idx >= len(cols):
            continue
        try:
            epoch = int(cols[ts_idx].strip())
        except ValueError:
            continue
        for sc in sensor_columns:
            temp_s = cols[sc['tempIdx']].strip() if sc['tempIdx'] >= 0 and sc['tempIdx'] < len(cols) else ''
            hum_s = cols[sc['humIdx']].strip() if sc['humIdx'] >= 0 and sc['humIdx'] < len(cols) else ''
            try:
                temp_v = float(temp_s) if temp_s else None
            except ValueError:
                temp_v = None
            try:
                hum_v = float(hum_s) if hum_s else None
            except ValueError:
                hum_v = None
            if temp_v is not None and -50 < temp_v < 80:
                points.append({'sensor': sc['sensorId'], 'series': 'temp', 'epoch': epoch, 'value': temp_v})
            if hum_v is not None and 0 <= hum_v <= 100:
                points.append({'sensor': sc['sensorId'], 'series': 'hum', 'epoch': epoch, 'value': hum_v})
    points.sort(key=lambda item: int(item['epoch']))
    return points


def build_import_batches(points: Iterable[Dict[str, str | int | float]]) -> List[Dict[str, object]]:
    segments: Dict[int, List[Dict]] = defaultdict(list)
    for point in points:
        epoch = int(point['epoch'])
        hour_epoch = epoch - (epoch % 3600)
        segments[hour_epoch].append(point)
    batches: List[Dict[str, object]] = []
    for hour_epoch in sorted(segments):
        counts: Dict[Tuple[str, str], int] = defaultdict(int)
        lines: List[str] = []
        for point in segments[hour_epoch]:
            key = (str(point['sensor']), str(point['series']))
            if counts[key] >= 4:
                continue
            counts[key] += 1
            lines.append(f"{point['sensor']},{point['series']},{int(point['epoch'])},{float(point['value']):.2f}")
        current: List[str] = []
        current_len = 0
        for line in lines:
            line_len = len(line) + 1
            if current and current_len + line_len > 250:
                batches.append({'data': ';'.join(current), 'pointCount': len(current), 'isLast': False})
                current = []
                current_len = 0
            current.append(line)
            current_len += line_len
        if current:
            batches.append({'data': ';'.join(current), 'pointCount': len(current), 'isLast': True})
    return batches


def confirm_erase_first_import(path: str, sensor_ids: List[str], assume_yes: bool) -> None:
    if assume_yes:
        return
    print('WARNING: this CSV contains data for multiple sensors and will use the erase-first import path.')
    print('Existing retained history on the device will be cleared before the import is rebuilt from the CSV.')
    print(f'Input file: {path}')
    print(f'Sensors in import: {", ".join(sensor_ids)}')
    response = input('Type ERASE-IMPORT to continue: ').strip()
    if response != 'ERASE-IMPORT':
        raise RuntimeError('Import aborted by user.')


def do_export(args) -> int:
    host = args.host.rstrip('/')
    sensors = fetch_json(host + '/sensors.json', timeout=args.timeout)
    if args.sensor:
        sensors = [s for s in sensors if s['id'] == args.sensor]
        if not sensors:
            raise RuntimeError(f'Sensor id not found on device: {args.sensor}')
    rows_per_sensor = []
    for sensor in sensors:
        temp = fetch_text(f"{host}/history/{sensor['id']}/temp", timeout=args.timeout)
        hum = fetch_text(f"{host}/history/{sensor['id']}/hum", timeout=args.timeout)
        rows_per_sensor.append(build_normalized_rows(temp, hum))
    parsed = urllib.parse.urlparse(host)
    meta = {'gateway_host': parsed.hostname or host, 'gateway_ip': parsed.hostname or host}
    if len(sensors) == 1 and args.sensor:
        csv_text = build_single_sensor_csv(meta, sensors[0], rows_per_sensor[0])
    else:
        csv_text = build_merged_csv(meta, sensors, rows_per_sensor)
    Path(args.output).write_text(csv_text, encoding='utf-8')
    print(f'Exported {len(sensors)} sensor(s) to {args.output}')
    return 0


def do_import(args) -> int:
    host = args.host.rstrip('/')
    auth = (args.username, args.password)
    sensors = fetch_json(host + '/sensors.json', timeout=args.timeout)
    points = parse_import_csv(Path(args.input), sensors)
    if args.single_sensor:
        points = [p for p in points if str(p['sensor']) == args.single_sensor]
        if not points:
            raise RuntimeError(f'No importable points found for requested sensor id: {args.single_sensor}')
    if not points:
        raise RuntimeError('No valid import points found in the CSV file.')
    sensor_ids = sorted({str(p['sensor']) for p in points})
    is_single = len(sensor_ids) == 1
    if not is_single:
        confirm_erase_first_import(args.input, sensor_ids, args.yes)
    begin = host + '/api/import/begin'
    if is_single:
        begin += '/single/' + urllib.parse.quote(sensor_ids[0], safe='')
    begin_resp = json.loads(request('POST', begin, auth=auth, timeout=args.timeout).decode('utf-8'))
    if not begin_resp.get('ok'):
        raise RuntimeError(f'Begin failed: {begin_resp}')
    batches = build_import_batches(points)
    total_accepted = 0
    total_rejected = 0
    for idx, batch in enumerate(batches, start=1):
        path_prefix = '/api/import/w/' if batch['isLast'] else '/api/import/d/'
        url = host + path_prefix + str(batch['data'])
        resp = json.loads(request('POST', url, auth=auth, timeout=args.timeout).decode('utf-8'))
        if not resp.get('ok'):
            raise RuntimeError(f'Batch {idx} failed: {resp}')
        total_accepted += int(resp.get('accepted', 0))
        total_rejected += int(resp.get('rejected', 0))
    finish_resp = json.loads(request('POST', host + '/api/import/finish', auth=auth, timeout=args.timeout).decode('utf-8'))
    if not finish_resp.get('ok'):
        raise RuntimeError(f'Finish failed: {finish_resp}')
    print(f"Import complete: {finish_resp.get('segments_written', 0)} segments, {total_accepted} accepted, {total_rejected} rejected")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description='Export or restore retained history without using the browser dashboard.')
    sub = parser.add_subparsers(dest='cmd', required=True)

    exp = sub.add_parser('export', help='Export retained history to CSV.')
    exp.add_argument('--host', required=True, help='ESP host, for example http://192.168.120.189')
    exp.add_argument('--output', required=True, help='Output CSV path')
    exp.add_argument('--sensor', help='Optional single sensor id to export')
    exp.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT, help=f'HTTP timeout in seconds (default: {DEFAULT_TIMEOUT})')

    imp = sub.add_parser('import', help='Import retained history from CSV.')
    imp.add_argument('--host', required=True, help='ESP host, for example http://192.168.120.189')
    imp.add_argument('--input', required=True, help='Input CSV path')
    imp.add_argument('--username', required=True, help='Management API username')
    imp.add_argument('--password', required=True, help='Management API password')
    imp.add_argument('--single-sensor', help='Import only one sensor id from the CSV and use the single-sensor merge route when possible')
    imp.add_argument('--yes', action='store_true', help='Skip the erase-first confirmation prompt for multi-sensor imports')
    imp.add_argument('--timeout', type=int, default=DEFAULT_TIMEOUT, help=f'HTTP timeout in seconds (default: {DEFAULT_TIMEOUT})')

    args = parser.parse_args()
    try:
        if args.cmd == 'export':
            return do_export(args)
        return do_import(args)
    except Exception as exc:
        print(f'history_backup: FAIL — {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
