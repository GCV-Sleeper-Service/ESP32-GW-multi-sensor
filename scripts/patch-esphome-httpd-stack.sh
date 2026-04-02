#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# patch-esphome-httpd-stack.sh
#
# Creates a local ESPHome component override for web_server_idf that increases
# the httpd task stack from the hardcoded 4 KB to 16 KB.
#
# WHY:  ESP-IDF's HTTPD_DEFAULT_CONFIG() macro hardcodes .stack_size = 4096.
#       ESPHome's web_server_idf.cpp calls httpd_start() with that default and
#       never overrides it. Any HTTP handler doing auth + response formatting
#       overflows 4 KB, crashing with StoreProhibited in vPortYieldFromInt.
#       CONFIG_HTTPD_STACK_SIZE in sdkconfig_options has ZERO effect — it is
#       dead config.  See BUG-075/076, LESSON-OPS-100.
#
# HOW:  Copies ESPHome's installed web_server_idf component into the project
#       as a local override, then applies a single-line patch to set
#       config.stack_size = 16384 after HTTPD_DEFAULT_CONFIG().
#
# USAGE:
#       bash scripts/patch-esphome-httpd-stack.sh          # first time or after ESPHome upgrade
#       bash scripts/patch-esphome-httpd-stack.sh --check  # verify patch is applied, exit 0/1
#
# AFTER ESPHOME UPGRADE:
#       Re-run this script.  It copies the NEW upstream files and re-applies
#       the same one-line patch.  If the patch target changed (ESPHome rewrote
#       the begin() method), the script fails loudly so you can inspect.
#
# YAML: Each board profile or generated YAML must include:
#         external_components:
#           - source:
#               type: local
#               path: local_components
#             components: [web_server_idf]
#
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/firmware/local_components/web_server_idf"

# ── Locate ESPHome's installed component ──────────────────────────────────────
ESPHOME_COMPONENT=""
for candidate in \
    /opt/esphome/.venv/lib/python3.*/site-packages/esphome/components/web_server_idf \
    "$HOME/.local/lib/python3.*/site-packages/esphome/components/web_server_idf" \
    "$(python3 -c 'import esphome; import os; print(os.path.join(os.path.dirname(esphome.__file__), "components", "web_server_idf"))' 2>/dev/null || true)"
do
    # Expand globs
    for expanded in $candidate; do
        if [[ -f "$expanded/web_server_idf.cpp" ]]; then
            ESPHOME_COMPONENT="$expanded"
            break 2
        fi
    done
done

if [[ -z "$ESPHOME_COMPONENT" ]]; then
    echo "ERROR: Cannot find ESPHome's web_server_idf component."
    echo "       Is ESPHome installed?  Tried common paths and Python import."
    exit 1
fi

echo "Found ESPHome component: $ESPHOME_COMPONENT"

# ── Check mode ────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--check" ]]; then
    if [[ ! -f "$TARGET_DIR/web_server_idf.cpp" ]]; then
        echo "FAIL: Local override not found at $TARGET_DIR"
        exit 1
    fi
    FAIL=0
    if grep -q 'config\.stack_size = 16384;' "$TARGET_DIR/web_server_idf.cpp"; then
        ESPHOME_VERSION=$(esphome version 2>/dev/null || echo "unknown")
        echo "OK: httpd stack patch is applied (ESPHome $ESPHOME_VERSION)"
    else
        echo "FAIL: Stack size patch line is missing."
        FAIL=1
    fi
    if grep -q 'HTTP_DELETE' "$TARGET_DIR/web_server_idf.cpp"; then
        echo "OK: HTTP_DELETE handler registration patch is applied"
    else
        echo "FAIL: HTTP_DELETE handler registration is missing."
        FAIL=1
    fi
    if [[ "$FAIL" -eq 0 ]]; then
        echo "    $TARGET_DIR/web_server_idf.cpp"

        # Check for upstream drift — warn if installed copy differs from our
        # base (ignoring both patch lines)
        UPSTREAM="$ESPHOME_COMPONENT/web_server_idf.cpp"
        LOCAL="$TARGET_DIR/web_server_idf.cpp"
        DIFF_COUNT=$(diff \
            <(grep -v -e 'config\.stack_size = 16384;' -e 'HTTP_DELETE' -e 'handler_delete' -e 'BUG-079' "$LOCAL") \
            "$UPSTREAM" | grep -c '^[<>]' || true)
        if [[ "$DIFF_COUNT" -gt 0 ]]; then
            echo "WARNING: Upstream web_server_idf.cpp has diverged ($DIFF_COUNT line differences)."
            echo "         Re-run this script without --check to update."
        fi
        exit 0
    else
        exit 1
    fi
fi

# ── Copy upstream files ───────────────────────────────────────────────────────
echo "Copying upstream component to $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"

# Copy all source files (.cpp, .h, .py)
for ext in cpp h py; do
    for src in "$ESPHOME_COMPONENT"/*."$ext"; do
        [[ -f "$src" ]] || continue
        cp "$src" "$TARGET_DIR/"
        echo "  copied $(basename "$src")"
    done
done

# ── Apply patches ─────────────────────────────────────────────────────────────
CPP_FILE="$TARGET_DIR/web_server_idf.cpp"

# Verify the patch targets exist
if ! grep -q 'httpd_config_t config = HTTPD_DEFAULT_CONFIG();' "$CPP_FILE"; then
    echo "ERROR: Cannot find HTTPD_DEFAULT_CONFIG() in $CPP_FILE"
    echo "       ESPHome may have changed the httpd init code."
    echo "       Manual inspection required."
    exit 1
fi

if ! grep -q 'httpd_register_uri_handler(this->server_, &handler_options);' "$CPP_FILE"; then
    echo "ERROR: Cannot find handler_options registration anchor in $CPP_FILE"
    echo "       ESPHome may have changed the URI handler registration code."
    echo "       Manual inspection required."
    exit 1
fi

# ── Patch 1: Stack size ────────────────────────────────────────────────────────
# Check if already patched (re-run after copy means it's not)
if grep -q 'config\.stack_size = 16384;' "$CPP_FILE"; then
    echo "Patch 1 (stack size) already present — skipping."
else
    sed -i '/httpd_config_t config = HTTPD_DEFAULT_CONFIG();/a\  config.stack_size = 16384;  // PATCHED: BUG-076 — ESPHome default 4KB overflows with any non-trivial handler' \
        "$CPP_FILE"

    if grep -q 'config\.stack_size = 16384;' "$CPP_FILE"; then
        echo "Patch 1 (stack size) applied successfully."
    else
        echo "ERROR: Patch 1 (stack size) application failed — sed did not produce expected output."
        exit 1
    fi
fi

# ── Patch 2: HTTP_DELETE handler registration (BUG-079) ───────────────────────
# Stock ESPHome only registers GET, POST, OPTIONS. DELETE requests are blocked
# at the ESP-IDF httpd layer (plain-text 405) unless we register a handler.
if grep -q 'HTTP_DELETE' "$CPP_FILE"; then
    echo "Patch 2 (HTTP_DELETE handler) already present — skipping."
else
    # Insert the DELETE handler block after the OPTIONS handler registration line.
    # Use a Python script for reliable multi-line insertion.
    python3 - "$CPP_FILE" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

anchor = '    httpd_register_uri_handler(this->server_, &handler_options);'
new_block = """

    // PATCHED: BUG-079 — Register DELETE so ESP-IDF httpd routes DELETE requests
    // to our handler chain instead of returning plain-text 405.
    // DELETE requests have no body, so they use the same request_handler as GET.
    const httpd_uri_t handler_delete = {
        .uri = "",
        .method = HTTP_DELETE,
        .handler = AsyncWebServer::request_handler,
        .user_ctx = this,
    };
    httpd_register_uri_handler(this->server_, &handler_delete);"""

if anchor not in content:
    print("ERROR: anchor not found", file=sys.stderr)
    sys.exit(1)

content = content.replace(anchor, anchor + new_block, 1)
with open(path, 'w') as f:
    f.write(content)
print("Patch 2 (HTTP_DELETE handler) applied successfully.")
PYEOF

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Patch 2 (HTTP_DELETE handler) application failed."
        exit 1
    fi
fi

# ── Record metadata ───────────────────────────────────────────────────────────
ESPHOME_VERSION=$(esphome version 2>/dev/null || echo "unknown")
cat > "$TARGET_DIR/PATCH_INFO.md" << EOF
# web_server_idf local component override

## What
Two patches to \`web_server_idf.cpp\`, method \`AsyncWebServer::begin()\`:

**Patch 1 — Stack size (BUG-076):** \`config.stack_size = 16384\` after \`HTTPD_DEFAULT_CONFIG()\`

**Patch 2 — DELETE handler (BUG-079):** Register an \`HTTP_DELETE\` URI handler so
ESP-IDF httpd routes DELETE requests to the AsyncWebServer handler chain instead
of returning a plain-text 405 "Specified method is invalid for this resource".

## Why

### Patch 1 — Stack size
ESP-IDF's \`HTTPD_DEFAULT_CONFIG()\` hardcodes \`.stack_size = 4096\`.
ESPHome never overrides it. 4 KB is insufficient for any handler that
performs authentication + HTTP response formatting. Stack overflow crashes
with \`StoreProhibited\` in \`vPortYieldFromInt\`.

\`CONFIG_HTTPD_STACK_SIZE\` in \`sdkconfig_options\` has zero runtime effect.

### Patch 2 — DELETE handler
Stock ESPHome's \`AsyncWebServer::begin()\` registers only GET, POST, and OPTIONS
URI handlers. When a DELETE request arrives, ESP-IDF httpd finds no registered
handler for that method and immediately returns its built-in plain-text 405,
before calling any \`canHandle()\` or \`handleRequest()\` on our handler objects.
Adding an explicit DELETE handler registration routes DELETE requests through the
same \`request_handler\` path as GET (no body to read).

## Reference
- BUG-075, BUG-076 (stack size)
- LESSON-OPS-100, LESSON-OPS-101 (stack size)
- Critical Rules 40, 41 (stack size)
- BUG-079 (DELETE handler)
- LESSON-OPS-108, LESSON-OPS-109 (DELETE handler)

## Upstream source
- ESPHome version: ${ESPHOME_VERSION}
- Source path: ${ESPHOME_COMPONENT}
- Copied: $(date -Iseconds)

## After ESPHome upgrade
Re-run: \`bash scripts/patch-esphome-httpd-stack.sh\`
EOF

echo ""
echo "Done. Metadata written to $TARGET_DIR/PATCH_INFO.md"
echo ""
echo "IMPORTANT — each board YAML needs this block:"
echo ""
echo "  external_components:"
echo "    - source:"
echo "        type: local"
echo "        path: local_components"
echo "      components: [web_server_idf]"
echo ""
echo "Then: esphome clean <yaml> && esphome run <yaml>"
