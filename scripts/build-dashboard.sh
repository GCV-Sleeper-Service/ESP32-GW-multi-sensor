#!/usr/bin/env bash
# Three-pass assembly: injects CSS, resolves component markers, injects dashboard.js
# Pass 0: concatenate core/base.css + components/*/styles.css → replace {{CSS_PLACEHOLDER}}
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
dashboard_dir = os.path.dirname(sys.argv[1])
components_dir = os.path.realpath(os.path.join(dashboard_dir, 'components'))
component_name_re = re.compile(r'^[a-z0-9-]+$')

# Pass 0: concatenate CSS files → replace {{CSS_PLACEHOLDER}}
CSS_FILES = [
    os.path.join(dashboard_dir, 'core', 'base.css'),
    os.path.join(components_dir, 'device-info',    'styles.css'),
    os.path.join(components_dir, 'settings-panel', 'styles.css'),
    os.path.join(components_dir, 'live-view',       'styles.css'),
    os.path.join(components_dir, 'sensor-cards',    'styles.css'),
    os.path.join(components_dir, 'charts',          'styles.css'),
    os.path.join(components_dir, 'auth-modal',      'styles.css'),
    os.path.join(components_dir, 'custom-range',    'styles.css'),
    os.path.join(components_dir, 'gateway-panel',   'styles.css'),
]
css_placeholder = b'{{CSS_PLACEHOLDER}}'
css_placeholder_count = tmpl.count(css_placeholder)
if css_placeholder_count != 1:
    print(
        f"ERROR: template must contain exactly one {{{{CSS_PLACEHOLDER}}}} (found {css_placeholder_count})",
        file=sys.stderr,
    )
    sys.exit(1)
css_bytes = b''.join(open(f, 'rb').read() for f in CSS_FILES)
# Strip one trailing newline so replacement produces exact inline CSS (no extra blank line)
if css_bytes.endswith(b'\n'):
    css_bytes = css_bytes[:-1]
assembled = re.sub(rb'\{\{CSS_PLACEHOLDER\}\}\r?\n', css_bytes + b'\n', tmpl, count=1)

# Pass 1: resolve {{COMPONENT:name}} markers (tolerates LF and CRLF)
for m in re.finditer(rb'\{\{COMPONENT:([^}]+)\}\}', assembled):
    name = m.group(1)
    name_str = name.decode('utf-8')
    if not component_name_re.fullmatch(name_str):
        print(f"ERROR: invalid component name: {name_str}", file=sys.stderr)
        sys.exit(1)
    comp_path = os.path.realpath(os.path.join(components_dir, name_str, 'template.html'))
    if os.path.commonpath([components_dir, comp_path]) != components_dir:
        print(f"ERROR: component path escapes components directory: {name_str}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(comp_path):
        print(f"ERROR: component template not found: {comp_path}", file=sys.stderr)
        sys.exit(1)
    # Match marker + optional CR + required LF (tolerates CRLF and LF)
    marker_pattern = rb'\{\{COMPONENT:' + name + rb'\}\}\r?\n'
    occurrences = len(re.findall(marker_pattern, assembled))
    if occurrences != 1:
        print(
            f"ERROR: marker {{{{COMPONENT:{name_str}}}}} must appear exactly once"
            f" (found {occurrences})",
            file=sys.stderr,
        )
        sys.exit(1)
    comp_content = open(comp_path, 'rb').read()
    assembled = re.sub(marker_pattern, comp_content, assembled, count=1)

# Pass 2: inject JS at {{JS_PLACEHOLDER}}
placeholder = b'{{JS_PLACEHOLDER}}'
placeholder_count = assembled.count(placeholder)
if placeholder_count != 1:
    print(
        f"ERROR: template must contain exactly one {{{{JS_PLACEHOLDER}}}} (found {placeholder_count})",
        file=sys.stderr,
    )
    sys.exit(1)
header = '<!-- GENERATED \u2014 Do not edit. Source: dashboard/dashboard.tmpl.html + dashboard/components/*/template.html + dashboard/dashboard.js (bundled from dashboard/core/*.js + dashboard/components/*/index.js) -->\n'.encode('utf-8')
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
