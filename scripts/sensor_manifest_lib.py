#!/usr/bin/env python3
"""Helpers for the canonical sensor manifest used by the ESP32 gateway repo."""
from __future__ import annotations

import ipaddress
import json
import re
from pathlib import Path
from typing import Dict, List

import yaml

MAC_RE = re.compile(r"^([0-9A-F]{2}:){5}[0-9A-F]{2}$")
ID_RE = re.compile(r"^[a-z0-9_]{1,32}$")

BOARDS_DIR = Path(__file__).resolve().parent.parent / 'firmware' / 'boards'

AGGREGATOR_MIN_POLL = 10
AGGREGATOR_MAX_POLL = 300
AGGREGATOR_MAX_SATELLITES = 10
NAME_MAX_LEN = 15
MIN_SENSORS = 1
MAX_SENSORS = 4
VALID_CATEGORIES = {"environmental", "network", "system"}

# Metrics defined per adapter type
_PING_METRICS = [
    {
        "key": "ping_ms",
        "name": "Latency",
        "unit": "ms",
        "unit_symbol": "ms",
        "class": "analog_numeric",
        "data_type": "float",
        "bounds": {"min": 0, "max": 10000},
        "history": True,
        "history_suffix": "ping_ms",
        "display": {"precision": 0, "chart": True},
    },
    {
        "key": "success_pct",
        "name": "Success Rate",
        "unit": "percent",
        "unit_symbol": "%",
        "class": "analog_numeric",
        "data_type": "float",
        "bounds": {"min": 0, "max": 100},
        "history": True,
        "history_suffix": "success_pct",
        "display": {"precision": 0, "chart": True},
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


def canonicalize_sensors(sensors: List[Dict], allow_empty: bool = False) -> List[Dict]:
    if not isinstance(sensors, list):
        raise ManifestError("Manifest sensors field must be a list.")

    count = len(sensors)
    min_count = 0 if allow_empty else MIN_SENSORS
    if count < min_count or count > MAX_SENSORS:
        raise ManifestError(
            f"Sensor count must be between {min_count} and {MAX_SENSORS}; got {count}."
        )

    normalized: List[Dict] = []
    seen_ids = set()
    seen_names = set()
    seen_macs = set()

    for idx, sensor in enumerate(sensors, start=1):
        if not isinstance(sensor, dict):
            raise ManifestError(f"Sensor #{idx} must be an object.")

        sid = (sensor.get("id") or "").strip()
        name = (sensor.get("name") or "").strip()
        adapter = (sensor.get("adapter") or "thermopro_ble").strip()
        category = (sensor.get("category") or "environmental").strip()

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

        if category not in VALID_CATEGORIES:
            raise ManifestError(
                f'Sensor "{name}" has invalid category "{category}". '
                f'Must be one of: {", ".join(sorted(VALID_CATEGORIES))}.'
            )

        entry: Dict = {"id": sid, "name": name, "category": category, "adapter": adapter}

        if adapter == "thermopro_ble":
            mac = normalize_mac(sensor.get("mac") or "")
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

            entry["mac"] = mac
            seen_macs.add(mac)

        elif adapter == "icmp_ping":
            source = sensor.get("source") or {}
            if not source.get("target"):
                raise ManifestError(
                    f'Ping device "{name}" requires source.target (e.g. "8.8.8.8").'
                )
            entry["source"] = {"target": source["target"]}

        seen_ids.add(sid)
        seen_names.add(name)
        normalized.append(entry)

    return normalized


def load_manifest(path: Path, allow_empty: bool = False) -> List[Dict]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ManifestError(f"Manifest not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Manifest is not valid JSON: {exc}") from exc

    if isinstance(payload, list):
        sensors = payload
    elif isinstance(payload, dict):
        # NOTE: The architecture plan uses "devices" but the implementation uses "sensors"
        # for backward compatibility. The names are functionally equivalent. Migration to
        # "devices" is deferred to a future major version if needed.
        sensors = payload.get("sensors")
    else:
        raise ManifestError("Manifest root must be an object or an array.")

    return canonicalize_sensors(sensors, allow_empty=allow_empty)


def fixture_manifest(sensors: List[Dict]) -> List[Dict]:
    """Legacy v1 fixture — only environmental (BLE) sensors, id/name only."""
    return [
        {"id": s["id"], "name": s["name"]}
        for s in sensors
        if s.get("adapter", "thermopro_ble") == "thermopro_ble"
    ]


def manifest_v2(
    sensors: List[Dict],
    version: str,
    gateway_meta: Dict[str, str] | None = None,
    history_meta: Dict[str, object] | None = None,
) -> Dict[str, object]:
    """Generate full v2 manifest response with gateway/history blocks."""

    if gateway_meta is None:
        gateway_meta = {
            "id": "gw-main",
            "name": "Main Gateway",
            "role": "satellite",
            "hardware": "ESP32-C3",
        }

    if history_meta is None:
        history_meta = {
            "backend": "nvs",
            "retention_hours": 1080,  # 45 days
            "ram_window_hours": 24,
            "sample_interval_seconds": 900,  # 15 min
        }

    env_metrics = [
        {
            "key": "temp",
            "name": "Temperature",
            "unit": "celsius",
            "unit_symbol": "°C",
            "class": "analog_numeric",
            "data_type": "float",
            "bounds": {"min": -50, "max": 80},
            "history": True,
            "history_suffix": "temp",
            "display": {"precision": 1, "chart": True},
        },
        {
            "key": "hum",
            "name": "Humidity",
            "unit": "percent",
            "unit_symbol": "%",
            "class": "analog_numeric",
            "data_type": "float",
            "bounds": {"min": 0, "max": 100},
            "history": True,
            "history_suffix": "hum",
            "display": {"precision": 1, "chart": True},
        },
    ]

    sensor_entries = []
    for s in sensors:
        adapter = s.get("adapter", "thermopro_ble")
        if adapter == "thermopro_ble":
            sensor_entries.append({
                "id": s["id"],
                "name": s["name"],
                "category": s.get("category", "environmental"),
                "adapter": adapter,
                "source": {"mac": s["mac"]},
                "measurements": [
                    {"key": m["key"], "history_url": f"/history/{s['id']}/{m['history_suffix']}"}
                    for m in env_metrics
                ],
            })
        elif adapter == "icmp_ping":
            sensor_entries.append({
                "id": s["id"],
                "name": s["name"],
                "category": s.get("category", "network"),
                "adapter": adapter,
                "source": s.get("source", {}),
                "measurements": [
                    {"key": m["key"], "history_url": f"/api/v2/history/{s['id']}/{m['history_suffix']}"}
                    for m in _PING_METRICS
                ],
            })
        else:
            sensor_entries.append({
                "id": s["id"],
                "name": s["name"],
                "category": s.get("category", "unknown"),
                "adapter": adapter,
                "measurements": [],
            })

    return {
        "ok": True,
        "schema_version": 2,
        "source": "active-manifest",
        "version": version,
        "gateway": {
            **gateway_meta,
            "firmware_version": version,
            "api_version": "v2",
        },
        "history": history_meta,
        "sensor_count": len(sensors),
        "metrics": env_metrics,
        "sensors": sensor_entries,
    }


def validate_aggregator_config(config: Dict) -> Dict:
    """Validate aggregator config. Returns normalized config or raises ManifestError."""
    if not isinstance(config, dict):
        raise ManifestError("Aggregator config must be an object.")

    if config.get("schema_version") != 1:
        raise ManifestError("Aggregator config schema_version must be 1.")

    if config.get("role") != "aggregator":
        raise ManifestError('Aggregator config role must be "aggregator".')

    satellites = config.get("satellites", [])
    if not isinstance(satellites, list) or len(satellites) < 1:
        raise ManifestError("Aggregator config must have at least 1 satellite.")
    if len(satellites) > AGGREGATOR_MAX_SATELLITES:
        raise ManifestError(f"Aggregator config supports max {AGGREGATOR_MAX_SATELLITES} satellites.")

    seen_ids: set = set()
    seen_urls: set = set()
    for i, sat in enumerate(satellites, start=1):
        sid = (sat.get("id") or "").strip()
        # Gateway IDs allow hyphens (e.g. "gw-main"); normalize hyphens to underscores
        # before matching ID_RE which covers letters/digits/underscores only.
        if not sid or not ID_RE.match(sid.replace("-", "_")):
            raise ManifestError(f"Satellite #{i} has invalid id.")
        if sid in seen_ids:
            raise ManifestError(f"Duplicate satellite id: {sid}")

        url = (sat.get("base_url") or "").strip().rstrip("/")
        if not url.startswith("http://"):
            if url.startswith("https://"):
                raise ManifestError(
                    f'Satellite "{sid}" base_url uses https:// which is not supported by the '
                    f'current firmware. Use http:// for local-network satellite polling. '
                    f'HTTPS support is planned for a future version.')
            raise ManifestError(f'Satellite "{sid}" base_url must start with http://')
        if url in seen_urls:
            raise ManifestError(f"Duplicate satellite base_url: {url}")

        poll = sat.get("poll_interval_seconds", 30)
        if not isinstance(poll, int) or poll < AGGREGATOR_MIN_POLL or poll > AGGREGATOR_MAX_POLL:
            raise ManifestError(
                f'Satellite "{sid}" poll_interval_seconds must be {AGGREGATOR_MIN_POLL}–{AGGREGATOR_MAX_POLL}'
            )

        seen_ids.add(sid)
        seen_urls.add(url)

    return config


def load_aggregator_config(path: Path) -> Dict | None:
    """Load aggregator config. Returns None if file doesn't exist (satellite mode)."""
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Aggregator config is not valid JSON: {exc}") from exc
    return validate_aggregator_config(payload)


def load_board_profile(board_id: str) -> Dict:
    """Load a board profile from firmware/boards/{board_id}.yaml.
    Returns dict or raises ManifestError."""
    profile_path = BOARDS_DIR / f"{board_id}.yaml"
    if not profile_path.is_file():
        raise ManifestError(f"Board profile not found: {profile_path}")
    try:
        with open(profile_path, 'r', encoding='utf-8') as f:
            profile = yaml.safe_load(f)
    except yaml.YAMLError as exc:
        raise ManifestError(f"Board profile {board_id} is not valid YAML: {exc}") from exc
    if not isinstance(profile, dict):
        raise ManifestError(f"Board profile {board_id} must be a YAML mapping, got {type(profile).__name__}")
    required_keys = ['board_id', 'chip_variant', 'esphome_board', 'flash_size',
                     'partitions', 'framework']
    for key in required_keys:
        if key not in profile:
            raise ManifestError(f"Board profile {board_id} missing required key: {key}")
    if profile['board_id'] != board_id:
        raise ManifestError(f"Board profile board_id mismatch: file={board_id}, content={profile['board_id']}")
    return profile


def load_gateway_config() -> Dict | None:
    """Load config/gateway.json if it exists. Returns dict or None."""
    gw_path = Path(__file__).resolve().parent.parent / 'config' / 'gateway.json'
    if not gw_path.is_file():
        return None
    try:
        with open(gw_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
    except json.JSONDecodeError as exc:
        raise ManifestError(f"Gateway config is not valid JSON: {exc}") from exc
    validate_gateway_config(config)
    return config


def validate_gateway_config(config: Dict) -> None:
    """Validate gateway config schema. Raises ManifestError on failure."""
    if 'board' not in config:
        raise ManifestError("gateway.json missing 'board'")
    if 'esphome_name' not in config:
        raise ManifestError("gateway.json missing 'esphome_name'")
    if 'wifi_address' not in config:
        raise ManifestError("gateway.json missing 'wifi_address'")
    # Validate board reference
    load_board_profile(config['board'])  # will raise if not found
    # Validate name format (ESPHome requires lowercase, hyphens, digits)
    name = config['esphome_name']
    if not re.match(r'^[a-z0-9][a-z0-9-]*$', name):
        raise ManifestError(f"esphome_name must be lowercase alphanumeric with hyphens: {name}")
    # Validate IP format
    try:
        ipaddress.IPv4Address(config['wifi_address'])
    except ValueError:
        raise ManifestError(f"wifi_address must be a valid IPv4 address: {config['wifi_address']}")
    # Validate optional manual_ip
    manual_ip = config.get('manual_ip')
    if manual_ip is not None:
        if not isinstance(manual_ip, dict):
            raise ManifestError("manual_ip must be an object with static_ip, gateway, subnet")
        for field in ('static_ip', 'gateway', 'subnet'):
            val = manual_ip.get(field)
            if not val:
                raise ManifestError(f"manual_ip.{field} is required when manual_ip is present")
            if not isinstance(val, str):
                raise ManifestError(f"manual_ip.{field} must be a string, got {type(val).__name__}")
            try:
                ipaddress.IPv4Address(val)
            except ValueError:
                raise ManifestError(f"manual_ip.{field} must be a valid IPv4 address: {val}")
        # Optional dns1 field — validated if present
        dns1 = manual_ip.get('dns1')
        if dns1 is not None:
            if not isinstance(dns1, str):
                raise ManifestError(f"manual_ip.dns1 must be a string, got {type(dns1).__name__}")
            try:
                ipaddress.IPv4Address(dns1)
            except ValueError:
                raise ManifestError(f"manual_ip.dns1 must be a valid IPv4 address: {dns1}")
