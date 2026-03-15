#!/usr/bin/env python3
"""Helpers for the canonical sensor manifest used by the ESP32 gateway repo."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional

MAC_RE = re.compile(r"^([0-9A-F]{2}:){5}[0-9A-F]{2}$")
ID_RE = re.compile(r"^[a-z0-9_]{1,32}$")
NAME_MAX_LEN = 15
MIN_SENSORS = 1
MAX_SENSORS = 4

# ---------------------------------------------------------------------------
# Default v2 metadata applied when the config does not supply its own blocks
# ---------------------------------------------------------------------------

DEFAULT_GATEWAY: Dict[str, str] = {
    "id": "gw-main",
    "name": "Main Gateway",
    "role": "satellite",
    "hardware": "ESP32-C3",
}

DEFAULT_HISTORY: Dict[str, Any] = {
    "backend": "nvs",
    "retention_hours": 1080,
    "ram_window_hours": 24,
    "sample_interval_seconds": 900,
}

THERMOPRO_MEASUREMENTS: List[Dict[str, Any]] = [
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


def manifest_v2(
    sensors: List[Dict[str, Any]],
    version: str,
    source: str = "repo-fixture",
    gateway_meta: Optional[Dict[str, Any]] = None,
    history_meta: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Generate the full v2 manifest dict (for fixture or API response).

    *sensors* may be v1 objects ({id, name, mac}) or v2 objects
    ({id, name, category, adapter, measurements}). v1 objects are
    automatically promoted to ThermoPro defaults.
    """
    gw = gateway_meta if gateway_meta is not None else DEFAULT_GATEWAY
    hist = history_meta if history_meta is not None else DEFAULT_HISTORY
    return {
        "ok": True,
        "schema_version": 2,
        "source": source,
        "version": version,
        "gateway": gw,
        "history": hist,
        "sensor_count": len(sensors),
        "sensors": [
            {
                "id": s["id"],
                "name": s["name"],
                "category": s.get("category", "environmental"),
                "adapter": s.get("adapter", "thermopro_ble"),
                "measurements": s.get("measurements", THERMOPRO_MEASUREMENTS),
            }
            for s in sensors
        ],
    }


def load_manifest_v2(path: Path) -> Dict[str, Any]:
    """Load a v1 or v2 *config* manifest and return a dict with:

    - ``sensors``    -- canonical list of {id, name, mac} for C++ code generation
    - ``sensors_v2`` -- enriched list of {id, name, category, adapter, measurements}
    - ``gateway``    -- gateway metadata block (defaults if absent from file)
    - ``history``    -- history metadata block (defaults if absent from file)
    """
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ManifestError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Manifest is not valid JSON: {exc}") from exc

    if isinstance(payload, list):
        sensors_raw: List[Dict] = payload
        gateway_meta: Optional[Dict] = None
        history_meta: Optional[Dict] = None
    elif isinstance(payload, dict):
        sensors_raw = payload.get("sensors") or []
        gateway_meta = payload.get("gateway")
        history_meta = payload.get("history")
    else:
        raise ManifestError("Manifest root must be an object or an array.")

    canonical = canonicalize_sensors(sensors_raw)

    raw_by_id = {s["id"]: s for s in sensors_raw if isinstance(s, dict)}
    sensors_v2 = []
    for s in canonical:
        raw = raw_by_id.get(s["id"], {})
        sensors_v2.append(
            {
                "id": s["id"],
                "name": s["name"],
                "category": raw.get("category", "environmental"),
                "adapter": raw.get("adapter", "thermopro_ble"),
                "measurements": raw.get("measurements", THERMOPRO_MEASUREMENTS),
            }
        )

    return {
        "sensors": canonical,
        "sensors_v2": sensors_v2,
        "gateway": gateway_meta if gateway_meta is not None else DEFAULT_GATEWAY,
        "history": history_meta if history_meta is not None else DEFAULT_HISTORY,
    }


def to_manifest_v2(
    sensors: List[Dict[str, str]],
    gateway_meta: Optional[Dict[str, Any]] = None,
    history_meta: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Auto-promote v1 sensors ({id, name, mac}) to full v2 format using ThermoPro defaults."""
    canonical = canonicalize_sensors(sensors)
    return {
        "gateway": gateway_meta if gateway_meta is not None else DEFAULT_GATEWAY,
        "history": history_meta if history_meta is not None else DEFAULT_HISTORY,
        "sensors": [
            {
                "id": s["id"],
                "name": s["name"],
                "category": "environmental",
                "adapter": "thermopro_ble",
                "measurements": THERMOPRO_MEASUREMENTS,
            }
            for s in canonical
        ],
    }


def validate_sensors(sensors: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """Validate sensors; returns canonical list.  Alias for canonicalize_sensors."""
    return canonicalize_sensors(sensors)


def validate_v2_schema(manifest: Dict[str, Any]) -> bool:
    """Validate that a v2 manifest dict has all required top-level blocks."""
    if not isinstance(manifest, dict):
        raise ManifestError("Manifest must be a dict.")
    if manifest.get("schema_version") != 2:
        raise ManifestError("schema_version must be 2.")
    for key in ("gateway", "history", "sensors"):
        if key not in manifest:
            raise ManifestError(f"Missing required v2 key: '{key}'.")
    return True


def save_manifest(path: Path, sensors: List[Dict[str, str]], schema_version: int = 2) -> None:
    """Write *sensors* back to *path*.

    When schema_version >= 2 the existing gateway/history blocks are
    preserved (or defaults are used) and ThermoPro measurements are added
    for any sensor that does not already carry them.
    """
    path = Path(path)
    gateway: Optional[Dict] = None
    history: Optional[Dict] = None
    raw_sensors_by_id: Dict[str, Dict] = {}

    if path.exists():
        try:
            existing = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(existing, dict):
                gateway = existing.get("gateway")
                history = existing.get("history")
                for s in (existing.get("sensors") or []):
                    if isinstance(s, dict) and s.get("id"):
                        raw_sensors_by_id[s["id"]] = s
        except (json.JSONDecodeError, OSError):
            pass

    if schema_version >= 2:
        sensor_rows = []
        for s in sensors:
            raw = raw_sensors_by_id.get(s["id"], {})
            sensor_rows.append(
                {
                    "id": s["id"],
                    "name": s["name"],
                    "mac": s["mac"],
                    "category": raw.get("category", "environmental"),
                    "adapter": raw.get("adapter", "thermopro_ble"),
                    "measurements": raw.get("measurements", THERMOPRO_MEASUREMENTS),
                }
            )
        payload: Dict[str, Any] = {
            "schema_version": 2,
            "gateway": gateway if gateway is not None else DEFAULT_GATEWAY,
            "history": history if history is not None else DEFAULT_HISTORY,
            "sensors": sensor_rows,
        }
    else:
        payload = {
            "schema_version": 1,
            "sensors": [
                {"id": s["id"], "name": s["name"], "mac": s["mac"]} for s in sensors
            ],
        }

    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

