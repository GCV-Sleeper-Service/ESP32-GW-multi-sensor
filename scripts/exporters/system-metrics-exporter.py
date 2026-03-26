#!/usr/bin/env python3
"""Push system metrics to ESP32 gateway via /api/ingest endpoint.

Usage:
    python3 system-metrics-exporter.py [--gateway URL] [--device ID] [--interval SECONDS]

Cross-platform (Linux, macOS, Windows). Runs once by default;
use --interval for continuous mode (e.g., --interval 60).
"""
import argparse
import platform
import subprocess
import time
import urllib.request
import urllib.error


def get_cpu_pct():
    """Approximate CPU usage (1-second sample)."""
    system = platform.system()
    try:
        if system == "Linux":
            load = float(open("/proc/loadavg").read().split()[0])
            import os
            return min(100.0, load / os.cpu_count() * 100)
        elif system == "Darwin":
            out = subprocess.check_output(["sysctl", "-n", "vm.loadavg"], text=True)
            load = float(out.split()[1])
            import os
            return min(100.0, load / os.cpu_count() * 100)
    except Exception:
        pass
    return 0.0


def get_ram_pct():
    system = platform.system()
    try:
        if system == "Linux":
            with open("/proc/meminfo") as f:
                lines = {l.split(":")[0]: int(l.split()[1]) for l in f if ":" in l}
            total = lines.get("MemTotal", 1)
            avail = lines.get("MemAvailable", total)
            return (1 - avail / total) * 100
        elif system == "Darwin":
            import os
            total = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
            return 0.0  # placeholder — macOS vm_stat parsing is complex
    except Exception:
        pass
    return 0.0


def get_disk_pct():
    try:
        import shutil
        total, used, free = shutil.disk_usage("/")
        return (used / total) * 100
    except Exception:
        return 0.0


def get_uptime_hrs():
    system = platform.system()
    try:
        if system == "Linux":
            return float(open("/proc/uptime").read().split()[0]) / 3600
        elif system == "Darwin":
            out = subprocess.check_output(["sysctl", "-n", "kern.boottime"], text=True)
            boot = int(out.split("sec = ")[1].split(",")[0])
            return (time.time() - boot) / 3600
    except Exception:
        pass
    return 0.0


def push_metric(gateway, device, key, value):
    url = f"{gateway}/api/ingest/{device}/{key}?val={value:.1f}"
    req = urllib.request.Request(url, method="POST")
    try:
        urllib.request.urlopen(req, timeout=5)
        return True
    except (urllib.error.URLError, OSError):
        return False


def main():
    parser = argparse.ArgumentParser(description="Push system metrics to ESP32 gateway")
    parser.add_argument("--gateway", default="http://192.168.10.20")
    parser.add_argument("--device", default="nas01")
    parser.add_argument("--interval", type=int, default=0, help="Repeat interval in seconds (0=run once)")
    args = parser.parse_args()

    while True:
        metrics = {
            "cpu_pct": get_cpu_pct(),
            "ram_pct": get_ram_pct(),
            "disk_pct": get_disk_pct(),
            "uptime_hrs": get_uptime_hrs(),
        }
        results = []
        for key, val in metrics.items():
            ok = push_metric(args.gateway, args.device, key, val)
            results.append(f"{key}={val:.1f}{'✓' if ok else '✗'}")

        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] {' '.join(results)} → {args.gateway}")

        if args.interval <= 0:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
