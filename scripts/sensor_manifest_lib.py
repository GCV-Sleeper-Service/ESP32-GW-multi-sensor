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
        if payload.get("schema_version") == 2:
            # v2: extract {id, name, mac} for backward compat
            raw = payload.get("sensors", [])
            sensors = [{"id": s["id"], "name": s["name"], "mac": s.get("mac", "")} for s in raw]
        else:
            sensors = payload.get("sensors")
    else:
        raise ManifestError("Manifest root must be an object or an array.")

    return canonicalize_sensors(sensors)


def fixture_manifest(sensors: List[Dict[str, str]]) -> List[Dict[str, str]]:
    return [{"id": sensor["id"], "name": sensor["name"]} for sensor in sensors]


THERMOPRO_MEASUREMENTS = [
    {
        "key": "temp",
        "name": "Temperature",
        "class": "analog_numeric",
        "data_type": "float",
        "unit": "celsius",
        "unit_symbol": "\u00b0C",
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

DEFAULT_GATEWAY = {
    "id": "gw-main",
    "name": "Main Gateway",
    "role": "satellite",
    "hardware": "ESP32-C3",
}

DEFAULT_HISTORY = {
    "backend": "nvs",
    "retention_hours": 1080,
    "ram_window_hours": 24,
    "sample_interval_seconds": 900,
}


def validate_sensors(sensors):
    """Validate a sensor list. Alias for canonicalize_sensors."""
    return canonicalize_sensors(sensors)


def save_manifest(path, sensors, schema_version=2):
    """Write sensors to a manifest JSON file."""
    if schema_version >= 2:
        existing = {}
        if path.exists():
            try:
                existing = json.loads(path.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, FileNotFoundError):
                pass

        gateway = existing.get("gateway", DEFAULT_GATEWAY)
        history = existing.get("history", DEFAULT_HISTORY)

        v2_sensors = []
        for s in sensors:
            v2_sensors.append({
                "id": s["id"],
                "name": s["name"],
                "mac": s["mac"],
                "category": "environmental",
                "adapter": "thermopro_ble",
                "measurements": THERMOPRO_MEASUREMENTS,
            })

        payload = {
            "schema_version": 2,
            "gateway": gateway,
            "history": history,
            "sensors": v2_sensors,
        }
    else:
        payload = {
            "schema_version": 1,
            "sensors": [{"id": s["id"], "name": s["name"], "mac": s["mac"]} for s in sensors],
        }

    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def to_manifest_v2(sensors, version, gateway_meta=None, history_meta=None, source="firmware"):
    """Build a full v2 manifest dict from a sensor list."""
    gw = gateway_meta or dict(DEFAULT_GATEWAY)
    hist = history_meta or dict(DEFAULT_HISTORY)

    v2_sensors = []
    for s in sensors:
        v2_sensors.append({
            "id": s["id"],
            "name": s["name"],
            "category": "environmental",
            "adapter": "thermopro_ble",
            "measurements": THERMOPRO_MEASUREMENTS,
        })

    return {
        "ok": True,
        "schema_version": 2,
        "source": source,
        "version": version,
        "gateway": gw,
        "history": hist,
        "sensor_count": len(sensors),
        "sensors": v2_sensors,
    }


def manifest_v2(sensors: List[Dict[str, str]], version: str) -> Dict[str, object]:
    return to_manifest_v2(sensors, version)


def validate_v2_schema(manifest):
    """Validate that a manifest dict conforms to v2 schema requirements."""
    errors = []
    if not isinstance(manifest, dict):
        raise ManifestError("Manifest must be a dict")
    if manifest.get("schema_version") != 2:
        errors.append("schema_version must be 2")
    if "gateway" not in manifest or not isinstance(manifest.get("gateway"), dict):
        errors.append("Missing or invalid 'gateway' block")
    if "history" not in manifest or not isinstance(manifest.get("history"), dict):
        errors.append("Missing or invalid 'history' block")
    if "sensors" not in manifest or not isinstance(manifest.get("sensors"), list):
        errors.append("Missing or invalid 'sensors' list")
    else:
        for i, s in enumerate(manifest["sensors"]):
            if "measurements" not in s or not isinstance(s.get("measurements"), list):
                errors.append(f"Sensor #{i+1} missing 'measurements' array")
    if errors:
        raise ManifestError("v2 schema validation failed: " + "; ".join(errors))
    return True


def load_manifest_v2(path):
    """Load a manifest file and return the full v2 dict. Auto-promotes v1."""
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ManifestError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Manifest is not valid JSON: {exc}") from exc

    if isinstance(payload, dict) and payload.get("schema_version") == 2:
        return payload

    # Auto-promote v1
    sensors = load_manifest(path)
    return to_manifest_v2(sensors, "0.0.0")
