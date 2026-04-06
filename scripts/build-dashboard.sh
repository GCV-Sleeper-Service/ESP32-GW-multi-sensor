#!/usr/bin/env bash
# Injects dashboard.js into dashboard.tmpl.html → dashboard.html
# Usage: build-dashboard.sh [--write|--check]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---write}"

python3 - "$ROOT/dashboard/dashboard.tmpl.html" "$ROOT/dashboard/dashboard.js" "$MODE" << 'PYEOF'
import sys, os
tmpl = open(sys.argv[1]).read()
js = open(sys.argv[2]).read()
if '{{JS_PLACEHOLDER}}' not in tmpl:
    print("ERROR: {{JS_PLACEHOLDER}} not found in template", file=sys.stderr)
    sys.exit(1)
out = tmpl.replace('{{JS_PLACEHOLDER}}', js, 1)
out_path = os.path.join(os.path.dirname(sys.argv[1]), 'dashboard.html')
mode = sys.argv[3]
if mode == '--check':
    existing = open(out_path).read()
    if existing == out:
        print("OK: dashboard.html matches template + JS")
    else:
        print("FAIL: dashboard.html out of sync with template + JS")
        sys.exit(1)
else:
    open(out_path, 'w').write(out)
    print(f"Built {out_path} ({len(out)} chars)")
PYEOF
