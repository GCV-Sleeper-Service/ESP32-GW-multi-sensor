#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from sensor_manifest_lib import (
    MAX_SENSORS,
    MIN_SENSORS,
    ManifestError,
    canonicalize_sensors,
    load_manifest,
    normalize_mac,
    save_manifest,
    slugify_name,
    validate_sensors,
)

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / 'config' / 'sensors.json'
RENDERER = ROOT / 'scripts' / 'render_sensor_config.py'


def print_sensors(sensors):
    print('\nConfigured sensors:')
    for idx, sensor in enumerate(sensors, start=1):
        print(f'  {idx}. {sensor["name"]:<15} {sensor["mac"]}  [{sensor["id"]}]')


def ask_choice(prompt, valid):
    valid = {str(v) for v in valid}
    while True:
        value = input(prompt).strip()
        if value in valid:
            return value
        print(f'Please enter one of: {", ".join(sorted(valid))}')


def run_renderer() -> None:
    subprocess.run([sys.executable, str(RENDERER), '--write'], check=True, cwd=ROOT)


def print_history_warning() -> None:
    print('\nIMPORTANT: sensor-count changes still invalidate retained history on the device.')
    print('Before flashing the new firmware, export/backup retained history from the current device.')
    print('Recommended CLI backup command:')
    print('  python3 scripts/history_backup.py export --host http://<esp-ip> --output backup-before-sensor-change.csv')
    print('You can also use the dashboard Export All button.')


def remove_sensor_flow(sensors):
    print_history_warning()
    print_sensors(sensors)
    choice = int(ask_choice('\nSelect sensor number to remove: ', range(1, len(sensors) + 1))) - 1
    target = sensors[choice]
    print('\nSelected sensor for removal:')
    print(f'  Name: {target["name"]}')
    print(f'  ID  : {target["id"]}')
    print(f'  MAC : {target["mac"]}')
    confirm = input('Type REMOVE to confirm: ').strip()
    if confirm != 'REMOVE':
        print('Aborted.')
        return None
    return sensors[:choice] + sensors[choice + 1:]


def add_sensor_flow(sensors):
    print_history_warning()
    print_sensors(sensors)
    while True:
        name = input('\nEnter new sensor name (1-15 chars): ').strip()
        if not name:
            print('Name cannot be empty.')
            continue
        if len(name) > 15:
            print('Name is too long; maximum is 15 characters.')
            continue
        new_id = slugify_name(name)
        if not new_id:
            print('Could not derive a valid id from that name.')
            continue
        if any(s['id'] == new_id for s in sensors):
            print(f'A sensor with id "{new_id}" already exists. Pick a different name.')
            continue
        break

    while True:
        mac = normalize_mac(input('Enter MAC address (AA:BB:CC:DD:EE:FF): '))
        try:
            candidate = sensors + [{'id': new_id, 'name': name, 'mac': mac}]
            validate_sensors(candidate)
            candidate = canonicalize_sensors(candidate)
            mac = candidate[-1]['mac']
            break
        except ManifestError as exc:
            print(exc)

    print('\nSensor to add:')
    print(f'  Name: {name}')
    print(f'  ID  : {new_id}')
    print(f'  MAC : {mac}')
    confirm = input('Type ADD to confirm: ').strip()
    if confirm != 'ADD':
        print('Aborted.')
        return None
    return canonicalize_sensors(sensors + [{'id': new_id, 'name': name, 'mac': mac}])


def print_next_steps(new_count):
    print('\nConfiguration updated successfully.')
    print(f'New sensor count: {new_count}')
    print('\nBefore flashing the new firmware, back up retained history from the current device if you have not already done so.')
    print('Recommended backup command:')
    print('  python3 scripts/history_backup.py export --host http://<esp-ip> --output backup-before-sensor-change.csv')
    print('\nThen validate and flash:')
    print('  bash ./scripts/preflight.sh')
    print('  esphome compile firmware/esp32-c3-multi-sensor.yaml')
    print('  esphome run firmware/esp32-c3-multi-sensor.yaml')
    print('\nAfter flashing, reset old retained history and restore the backup:')
    print('  curl -u "<user>:<pass>" -X POST http://<esp-ip>/api/delete-data')
    print('  python3 scripts/history_backup.py import --host http://<esp-ip> --input backup-before-sensor-change.csv --username <user> --password <pass>')
    print('\nIf you prefer the browser UI, you can export/import from the dashboard instead.')


def main() -> int:
    if not MANIFEST_PATH.exists():
        print(f'Manifest not found: {MANIFEST_PATH}', file=sys.stderr)
        return 1
    try:
        sensors = load_manifest(MANIFEST_PATH)
    except Exception as exc:
        print(f'Failed to load manifest: {exc}', file=sys.stderr)
        return 1

    count = len(sensors)
    print('ESP32 BLE Gateway — sensor configuration manager')
    print(f'Current number of sensors in the system: {count}')
    print_sensors(sensors)

    options = {}
    next_idx = 1
    if count < MAX_SENSORS:
        options[str(next_idx)] = 'add'
        print(f'  {next_idx}. Add sensor')
        next_idx += 1
    if count > MIN_SENSORS:
        options[str(next_idx)] = 'remove'
        print(f'  {next_idx}. Remove sensor')
        next_idx += 1
    options[str(next_idx)] = 'exit'
    print(f'  {next_idx}. Exit')

    action = options[ask_choice('\nChoose an action: ', options.keys())]
    if action == 'exit':
        print('No changes made.')
        return 0

    new_sensors = add_sensor_flow(sensors) if action == 'add' else remove_sensor_flow(sensors)
    if new_sensors is None:
        return 0

    backup_path = MANIFEST_PATH.with_suffix('.json.bak')
    shutil.copy2(MANIFEST_PATH, backup_path)
    success = False
    try:
        save_manifest(MANIFEST_PATH, new_sensors)
        run_renderer()
        success = True
    except Exception as exc:
        restore_ok = False
        rerender_ok = False
        restore_error = None
        rerender_error = None
        try:
            shutil.copy2(backup_path, MANIFEST_PATH)
            restore_ok = True
        except Exception as restore_exc:
            restore_error = restore_exc
        if restore_ok:
            try:
                subprocess.run([sys.executable, str(RENDERER), '--write'], cwd=ROOT, check=True)
                rerender_ok = True
            except Exception as rerender_exc:
                rerender_error = rerender_exc

        print(f'Change failed. Original error: {exc}', file=sys.stderr)
        if restore_ok and rerender_ok:
            print(f'Previous manifest restored and generated files re-rendered. Backup kept at {backup_path}.', file=sys.stderr)
        else:
            print('Automatic rollback may be incomplete.', file=sys.stderr)
            if restore_error:
                print(f'  Restore error: {restore_error}', file=sys.stderr)
            if rerender_error:
                print(f'  Re-render error: {rerender_error}', file=sys.stderr)
            print(f'  Recovery backup preserved at: {backup_path}', file=sys.stderr)
            print('  Recommended manual recovery:', file=sys.stderr)
            print(f'    cp {backup_path} {MANIFEST_PATH}', file=sys.stderr)
            print(f'    {sys.executable} {RENDERER} --write', file=sys.stderr)
            print('  Or discard repo changes with git checkout / git restore as appropriate.', file=sys.stderr)
        return 1

    if success:
        try:
            backup_path.unlink()
        except FileNotFoundError:
            pass
    print_next_steps(len(new_sensors))
    return 0


if __name__ == '__main__':
    sys.exit(main())
