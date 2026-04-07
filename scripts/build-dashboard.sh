#!/usr/bin/env bash
# Two-pass assembly: resolves {{COMPONENT:name}} markers then injects dashboard.js
# Pass 1: {{COMPONENT:name}} → dashboard/components/<name>/template.html
# Pass 2: {{JS_PLACEHOLDER}} → dashboard/dashboard.js → dashboard/dashboard.html
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
import sys, os, re
tmpl = open(sys.argv[1], 'rb').read()
js = open(sys.argv[2], 'rb').read()
components_dir = os.path.join(os.path.dirname(sys.argv[1]), 'components')

# Pass 1: resolve {{COMPONENT:name}} markers
assembled = tmpl
for m in re.finditer(rb'\{\{COMPONENT:([^}]+)\}\}', tmpl):
    name = m.group(1)
    marker_with_nl = b'{{COMPONENT:' + name + b'}}\n'
    comp_path = os.path.join(components_dir, name.decode(), 'template.html')
    if not os.path.exists(comp_path):
        print(f"ERROR: component template not found: {comp_path}", file=sys.stderr)
        sys.exit(1)
    if assembled.count(marker_with_nl) != 1:
        print(
            f"ERROR: marker {{{{COMPONENT:{name.decode()}}}}} must appear exactly once"
            f" (found {assembled.count(marker_with_nl)})",
            file=sys.stderr,
        )
        sys.exit(1)
    comp_content = open(comp_path, 'rb').read()
    assembled = assembled.replace(marker_with_nl, comp_content)

# Pass 2: inject JS at {{JS_PLACEHOLDER}}
placeholder = b'{{JS_PLACEHOLDER}}'
placeholder_count = assembled.count(placeholder)
if placeholder_count != 1:
    print(
        f"ERROR: template must contain exactly one {{{{JS_PLACEHOLDER}}}} (found {placeholder_count})",
        file=sys.stderr,
    )
    sys.exit(1)
header = '<!-- GENERATED \u2014 Do not edit. Source: dashboard/dashboard.tmpl.html + dashboard/dashboard.js (bundled from dashboard/core/*.js + dashboard/components/*/index.js) -->\n'.encode('utf-8')
out = header + assembled.replace(placeholder, js, 1)
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
