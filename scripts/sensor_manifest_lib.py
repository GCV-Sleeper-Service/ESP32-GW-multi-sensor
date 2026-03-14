#!/usr/bin/env python3
"""Helpers for the canonical sensor manifest used by the ESP32 gateway repo."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Dict, List

MAC_RE = re.compile(r"^([0-9A-F]{2}:){5}[0-9A-F]{2}$")
ID_RE = re.compile(r"^[a-z0-9_]{1,32}$")
NAME_MAX_LEN = 15
MIN_SENSORS = 1
MAX_SENSORS = 4


class ManifestError(Exception):
    pass


def slugify_name(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", (name or "").strip().lower())
    slug = re.sub(r"_+", "_", slug).strip("_")
    return slug


def normalize_mac(mac: str) -> str:
    return (mac or "").strip().replace("-", ":").upper()


def canonicalize_sensors(sensors: List[Dict[str, str]]) -> List[Dict[str, str]]:
    if not isinstance(sensors, list):
        raise ManifestError("Manifest sensors field must be a list.")

    count = len(sensors)
    if count < MIN_SENSORS or count > MAX_SENSORS:
        raise ManifestError(
            f"Sensor count must be between {MIN_SENSORS} and {MAX_SENSORS}; got {count}."
        )

    normalized: List[Dict[str, str]] = []
    seen_ids = set()
    seen_names = set()
    seen_macs = set()

    for idx, sensor in enumerate(sensors, start=1):
        if not isinstance(sensor, dict):
            raise ManifestError(f"Sensor #{idx} must be an object.")

        sid = (sensor.get("id") or "").strip()
        name = (sensor.get("name") or "").strip()
        mac = normalize_mac(sensor.get("mac") or "")

        if not sid:
            raise ManifestError(f"Sensor #{idx} is missing id.")
        if not ID_RE.match(sid):
            raise ManifestError(
                f'Sensor id "{sid}" is invalid. Use lowercase letters, digits, and underscores only.'
            )
        if sid in seen_ids:
            raise ManifestError(f'Duplicate sensor id: "{sid}".')

        if not name:
            raise ManifestError(f"Sensor #{idx} is missing name.")
        if len(name) > NAME_MAX_LEN:
            raise ManifestError(
                f'Sensor name "{name}" is too long ({len(name)} > {NAME_MAX_LEN}).'
            )
        if name in seen_names:
            raise ManifestError(f'Duplicate sensor name: "{name}".')

        if not mac:
            raise ManifestError(f'Sensor "{name}" is missing mac.')
        if not MAC_RE.match(mac):
            raise ManifestError(
                f'Sensor "{name}" has invalid MAC "{mac}". Expected AA:BB:CC:DD:EE:FF.'
            )
        if mac in seen_macs:
            raise ManifestError(f'Duplicate sensor MAC: "{mac}".')

        suggested = slugify_name(name)
        if sid != suggested:
            raise ManifestError(
                f'Sensor id "{sid}" does not match the canonical slug for name "{name}". '
                f'Expected "{suggested}".'
            )

        normalized.append({"id": sid, "name": name, "mac": mac})
        seen_ids.add(sid)
        seen_names.add(name)
        seen_macs.add(mac)

    return normalized


def load_manifest(path: Path) -> List[Dict[str, str]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ManifestError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Manifest is not valid JSON: {exc}") from exc

    if isinstance(payload, list):
        sensors = payload
    elif isinstance(payload, dict):
        sensors = payload.get("sensors")
    else:
        raise ManifestError("Manifest root must be an object or an array.")

    return canonicalize_sensors(sensors)


def fixture_manifest(sensors: List[Dict[str, str]]) -> List[Dict[str, str]]:
    return [{"id": sensor["id"], "name": sensor["name"]} for sensor in sensors]


def manifest_v2(sensors: List[Dict[str, str]], version: str) -> Dict[str, object]:
    shared_metrics = [
        {
            "key": "temp",
            "name": "Temperature",
            "unit": "celsius",
            "unit_symbol": "°C",
            "bounds": {"min": -50, "max": 80},
            "history_suffix": "temp",
        },
        {
            "key": "hum",
            "name": "Humidity",
            "unit": "percent",
            "unit_symbol": "%",
            "bounds": {"min": 0, "max": 100},
            "history_suffix": "hum",
        },
    ]
    return {
        "ok": True,
        "schema_version": 2,
        "source": "repo-fixture",
        "version": version,
        "sensor_count": len(sensors),
        "metrics": shared_metrics,
        "sensors": [
            {
                "id": sensor["id"],
                "name": sensor["name"],
                "metrics": [
                    {"key": "temp", "history": f"/history/{sensor['id']}/temp"},
                    {"key": "hum", "history": f"/history/{sensor['id']}/hum"},
                ],
            }
            for sensor in sensors
        ],
    }
