#!/usr/bin/env python3
"""Shared helpers for canonical sensor manifest handling.

Validation is intentionally side-effect free. Use ``canonicalize_sensors()`` when you
want normalized ``id``/``name``/``mac`` output suitable for saving or rendering.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import List, Dict

MAC_RE = re.compile(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$')
ID_RE = re.compile(r'^[a-z0-9_]{1,32}$')
NAME_MAX_LEN = 15
MIN_SENSORS = 1
MAX_SENSORS = 4


class ManifestError(Exception):
    pass


def slugify_name(name: str) -> str:
    slug = re.sub(r'[^a-z0-9]+', '_', (name or '').strip().lower())
    slug = re.sub(r'_+', '_', slug).strip('_')
    return slug


def normalize_mac(mac: str) -> str:
    mac = (mac or '').strip().replace('-', ':').upper()
    return mac


def canonicalize_sensors(sensors: List[Dict[str, str]]) -> List[Dict[str, str]]:
    if not isinstance(sensors, list):
        raise ManifestError('Manifest sensors field must be a list.')
    count = len(sensors)
    if count < MIN_SENSORS or count > MAX_SENSORS:
        raise ManifestError(f'Sensor count must be between {MIN_SENSORS} and {MAX_SENSORS}; got {count}.')

    seen_ids = set()
    seen_macs = set()
    seen_names = set()
    normalized: List[Dict[str, str]] = []
    for idx, sensor in enumerate(sensors):
        if not isinstance(sensor, dict):
            raise ManifestError(f'Sensor #{idx + 1} must be an object.')
        sid = (sensor.get('id') or '').strip()
        name = (sensor.get('name') or '').strip()
        mac = normalize_mac(sensor.get('mac') or '')
        if not sid:
            raise ManifestError(f'Sensor #{idx + 1} is missing id.')
        if not ID_RE.match(sid):
            raise ManifestError(f'Sensor id "{sid}" is invalid. Use lowercase letters, digits, and underscores only.')
        if not name:
            raise ManifestError(f'Sensor #{idx + 1} is missing name.')
        if len(name) > NAME_MAX_LEN:
            raise ManifestError(f'Sensor name "{name}" exceeds {NAME_MAX_LEN} characters.')
        expected_slug = slugify_name(name)
        if sid != expected_slug:
            raise ManifestError(f'Sensor id "{sid}" does not match the canonical slug for "{name}" ({expected_slug}).')
        if not MAC_RE.match(mac):
            raise ManifestError(f'Sensor "{name}" has invalid MAC address "{sensor.get("mac")}".')
        if sid in seen_ids:
            raise ManifestError(f'Duplicate sensor id: {sid}')
        if mac in seen_macs:
            raise ManifestError(f'Duplicate MAC address: {mac}')
        if name.lower() in seen_names:
            raise ManifestError(f'Duplicate sensor name: {name}')
        seen_ids.add(sid)
        seen_macs.add(mac)
        seen_names.add(name.lower())
        normalized.append({'id': sid, 'name': name, 'mac': mac})
    return normalized


def load_manifest(path: str | Path) -> List[Dict[str, str]]:
    payload = json.loads(Path(path).read_text(encoding='utf-8'))
    if isinstance(payload, dict):
        sensors = payload.get('sensors', [])
    elif isinstance(payload, list):
        sensors = payload
    else:
        raise ManifestError('Manifest must be a JSON object with a sensors array or a top-level array.')
    return canonicalize_sensors(sensors)


def save_manifest(path: str | Path, sensors: List[Dict[str, str]]) -> None:
    payload = {
        'schema_version': 1,
        'sensors': canonicalize_sensors(sensors),
    }
    Path(path).write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')


def validate_sensors(sensors: List[Dict[str, str]]) -> None:
    canonicalize_sensors(sensors)


def fixture_manifest(sensors: List[Dict[str, str]]) -> str:
    sensors = canonicalize_sensors(sensors)
    return json.dumps([{'id': s['id'], 'name': s['name']} for s in sensors], indent=2) + '\n'
