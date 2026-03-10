#!/usr/bin/env bash
# scripts/minify-dashboard.sh
# Minify dashboard/dashboard.html into dashboard/dashboard.min.html
# Uses html-minifier-terser (for HTML/CSS) and terser (for inline JS)
#
# Usage:
#   ./scripts/minify-dashboard.sh [input] [output]
#
# Defaults:
#   input  = dashboard/dashboard.html
#   output = dashboard/dashboard.min.html
#
# The output file is a build artifact — it is listed in .gitignore and
# must NOT be committed. Only dashboard.html (source) and dashboard.h
# (generated header, committed) belong in the repo.
#
# Part of the v7.4.1.0 minification pipeline.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

INPUT="${1:-dashboard/dashboard.html}"
OUTPUT="${2:-dashboard/dashboard.min.html}"

if [[ ! -f "$INPUT" ]]; then
  echo "ERROR: Input file not found: $INPUT"
  exit 1
fi

# Verify html-minifier-terser is available
if ! command -v html-minifier-terser &>/dev/null; then
  echo "ERROR: html-minifier-terser not found."
  echo "Install with: npm install -g html-minifier-terser"
  echo "Or (if package.json present): npm install"
  exit 1
fi

ORIG=$(wc -c < "$INPUT")

html-minifier-terser \
  --collapse-whitespace \
  --remove-comments \
  --remove-optional-tags \
  --remove-redundant-attributes \
  --remove-script-type-attributes \
  --remove-tag-whitespace \
  --use-short-doctype \
  --minify-css true \
  --minify-js '{"compress":{"dead_code":true,"drop_console":false,"passes":2},"mangle":true}' \
  --input-path "$INPUT" \
  --output-path "$OUTPUT"

MINI=$(wc -c < "$OUTPUT")
SAVED=$((ORIG - MINI))
PCT=$(( SAVED * 100 / ORIG ))

echo "Minified: ${ORIG} bytes → ${MINI} bytes  (saved ${SAVED} bytes, ${PCT}%)"
echo "Output:   $OUTPUT"
