#!/usr/bin/env bash
# Injects dashboard.js into dashboard.tmpl.html → dashboard.html
# Usage: build-dashboard.sh [--write|--check]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: build-dashboard.sh [--write|--check]" >&2
}

case "$#" in
  0)
    MODE="--write"
    ;;
  1)
    case "$1" in
      --write|--check)
        MODE="$1"
        ;;
      *)
        usage
        exit 2
        ;;
    esac
    ;;
  *)
    usage
    exit 2
    ;;
esac

python3 - "$ROOT/dashboard/dashboard.tmpl.html" "$ROOT/dashboard/dashboard.js" "$MODE" << 'PYEOF'
import sys, os
tmpl = open(sys.argv[1], 'rb').read()
js = open(sys.argv[2], 'rb').read()
placeholder = b'{{JS_PLACEHOLDER}}'
placeholder_count = tmpl.count(placeholder)
if placeholder_count != 1:
    print(
        f"ERROR: template must contain exactly one {{{{JS_PLACEHOLDER}}}} (found {placeholder_count})",
        file=sys.stderr,
    )
    sys.exit(1)
header = '<!-- GENERATED \u2014 Do not edit. Source: dashboard/dashboard.tmpl.html + dashboard/dashboard.js (bundled from dashboard/src/*.js) -->\n'.encode('utf-8')
out = header + tmpl.replace(placeholder, js, 1)
out_path = os.path.join(os.path.dirname(sys.argv[1]), 'dashboard.html')
mode = sys.argv[3]
if mode == '--check':
    existing = open(out_path, 'rb').read()
    if existing == out:
        print("OK: dashboard.html matches template + JS")
    else:
        print("FAIL: dashboard.html out of sync with template + JS")
        sys.exit(1)
else:
    open(out_path, 'wb').write(out)
    print(f"Built {out_path} ({len(out)} bytes)")
PYEOF
