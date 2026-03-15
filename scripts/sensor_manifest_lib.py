#!/usr/bin/env python3
"""Helpers for the canonical sensor manifest used by the ESP32 gateway repo."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Dict, List, Optional

MAC_RE = re.compile(r"^([0-9A-F]{2}:){5}[0-9A-F]{2}$")
ID_RE = re.compile(r"^[a-z0-9_]{1,32}$")
NAME_MAX_LEN = 15
MIN_SENSORS = 1
MAX_SENSORS = 4

DEFAULT_GATEWAY_META: Dict = {
    "id": "gw-main",
    "name": "Main Gateway",
    "role": "satellite",
    "hardware": "ESP32-C3",
}

DEFAULT_HISTORY_META: Dict = {
    "backend": "nvs",
    "retention_hours": 1080,
    "ram_window_hours": 24,
    "sample_interval_seconds": 900,
}


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
    """Load sensor list from a v1 or v2 manifest; returns canonical [{id,name,mac}] list."""
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


def validate_v2_schema(manifest: Dict) -> None:
    """Validate that a dict has the required v2 manifest fields."""
    if not isinstance(manifest, dict):
        raise ManifestError("v2 manifest root must be an object.")
    if manifest.get("schema_version") != 2:
        raise ManifestError("v2 manifest must have schema_version: 2.")
    if "sensors" not in manifest:
        raise ManifestError("v2 manifest must have a sensors field.")


def load_manifest_v2(path: Path) -> Dict:
    """Load and return the full v2 manifest dict without stripping extra fields."""
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ManifestError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Manifest is not valid JSON: {exc}") from exc
    validate_v2_schema(payload)
    return payload


def save_manifest(path: Path, sensors: List[Dict[str, str]], schema_version: int = 2) -> None:
    """Write sensors back to a manifest file, preserving gateway/history blocks for v2."""
    existing: Dict = {}
    if path.exists():
        try:
            existing = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            pass

    bare = [{"id": s["id"], "name": s["name"], "mac": s["mac"]} for s in sensors]

    if schema_version == 1:
        payload: Dict = {"schema_version": 1, "sensors": bare}
    else:
        payload = {
            "schema_version": 2,
            "gateway": existing.get("gateway", DEFAULT_GATEWAY_META),
            "history": existing.get("history", DEFAULT_HISTORY_META),
            "sensors": bare,
        }
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def validate_sensors(sensors: List[Dict[str, str]]) -> None:
    """Validate a sensor list; raises ManifestError on failure."""
    canonicalize_sensors(sensors)


def to_manifest_v2(
    sensors: List[Dict[str, str]],
    gateway_meta: Optional[Dict] = None,
    history_meta: Optional[Dict] = None,
) -> Dict:
    """Auto-promote a v1 sensor list to a full v2 manifest dict with ThermoPro defaults."""
    return {
        "schema_version": 2,
        "gateway": gateway_meta or DEFAULT_GATEWAY_META,
        "history": history_meta or DEFAULT_HISTORY_META,
        "sensors": [
            {
                "id": sensor["id"],
                "name": sensor["name"],
                "mac": sensor["mac"],
                "category": "environmental",
                "adapter": "thermopro_ble",
                "measurements": [
                    {
                        "key": "temp",
                        "name": "Temperature",
                        "class": "analog_numeric",
                        "data_type": "float",
                        "unit": "celsius",
                        "unit_symbol": "°C",
                        "bounds": {"min": -50, "max": 80},
                        "history": True,
                        "history_suffix": "temp",
                        "display": {"precision": 1, "chart": True},
                    },
                    {
                        "key": "hum",
                        "name": "Humidity",
                        "class": "analog_numeric",
                        "data_type": "float",
                        "unit": "percent",
                        "unit_symbol": "%",
                        "bounds": {"min": 0, "max": 100},
                        "history": True,
                        "history_suffix": "hum",
                        "display": {"precision": 1, "chart": True},
                    },
                ],
            }
            for sensor in sensors
        ],
    }


def fixture_manifest(sensors: List[Dict[str, str]]) -> List[Dict[str, str]]:
    return [{"id": sensor["id"], "name": sensor["name"]} for sensor in sensors]


def manifest_v2(
    sensors: List[Dict[str, str]],
    version: str,
    gateway_meta: Optional[Dict] = None,
    history_meta: Optional[Dict] = None,
) -> Dict:
    shared_metrics = [
        {
            "key": "temp",
            "name": "Temperature",
            "class": "analog_numeric",
            "data_type": "float",
            "unit": "celsius",
            "unit_symbol": "°C",
            "bounds": {"min": -50, "max": 80},
            "history": True,
            "history_suffix": "temp",
            "display": {"precision": 1, "chart": True},
        },
        {
            "key": "hum",
            "name": "Humidity",
            "class": "analog_numeric",
            "data_type": "float",
            "unit": "percent",
            "unit_symbol": "%",
            "bounds": {"min": 0, "max": 100},
            "history": True,
            "history_suffix": "hum",
            "display": {"precision": 1, "chart": True},
        },
    ]
    return {
        "ok": True,
        "schema_version": 2,
        "source": "active-manifest",
        "version": version,
        "sensor_count": len(sensors),
        "gateway": gateway_meta or DEFAULT_GATEWAY_META,
        "history": history_meta or DEFAULT_HISTORY_META,
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
