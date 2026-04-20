#!/usr/bin/env bash
# ?????????????????????????????????????????????????????????????????????????????
# patch-esphome-httpd-stack.sh
#
# Creates a local ESPHome component override for web_server_idf that increases
# the httpd task stack from the hardcoded 4 KB to 20 KB (RISC-V/C3) or 16 KB (Xtensa).
#
# WHY:  ESP-IDF's HTTPD_DEFAULT_CONFIG() macro hardcodes .stack_size = 4096.
#       ESPHome's web_server_idf.cpp calls httpd_start() with that default and
#       never overrides it. Any HTTP handler doing auth + response formatting
#       overflows 4 KB, crashing with StoreProhibited in vPortYieldFromInt.
#       CONFIG_HTTPD_STACK_SIZE in sdkconfig_options has ZERO effect - it is
#       dead config. See BUG-075/076, LESSON-OPS-100.
#
# HOW:  Copies ESPHome's installed web_server_idf component into the project
#       as a local override, then applies an architecture-conditional patch to set
#       config.stack_size = 20480 for RISC-V targets and 16384 for Xtensa targets
#       after HTTPD_DEFAULT_CONFIG().
#
# USAGE:
#       bash scripts/patch-esphome-httpd-stack.sh          # first time or after ESPHome upgrade
#       bash scripts/patch-esphome-httpd-stack.sh --check  # verify patch is applied, exit 0/1
#
# AFTER ESPHOME UPGRADE:
#       Re-run this script. It copies the NEW upstream files and re-applies
#       the same conditional patch. If the patch target changed (ESPHome rewrote
#       the begin() method), the script fails loudly so you can inspect.
#
# YAML: Each board profile or generated YAML must include:
#         external_components:
#           - source:
#               type: local
#               path: local_components
#             components: [web_server_idf]
#
# ?????????????????????????????????????????????????????????????????????????????
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/firmware/local_components/web_server_idf"

# ?? Locate ESPHome's installed component ??????????????????????????????????????
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
    echo "       Is ESPHome installed? Tried common paths and Python import."
    exit 1
fi

echo "Found ESPHome component: $ESPHOME_COMPONENT"

# ?? Check mode ????????????????????????????????????????????????????????????????
if [[ "${1:-}" == "--check" ]]; then
    if [[ ! -f "$TARGET_DIR/web_server_idf.cpp" ]]; then
        echo "FAIL: Local override not found at $TARGET_DIR"
        exit 1
    fi
    FAIL=0
    if grep -q 'CONFIG_IDF_TARGET_ARCH_RISCV' "$TARGET_DIR/web_server_idf.cpp" && \
       grep -q 'config\.stack_size = 20480;' "$TARGET_DIR/web_server_idf.cpp" && \
       grep -q 'config\.stack_size = 16384;' "$TARGET_DIR/web_server_idf.cpp"; then
        ESPHOME_VERSION=$(esphome version 2>/dev/null || echo "unknown")
        echo "OK: httpd stack patch is applied - conditional: C3=20480, Xtensa=16384 (ESPHome $ESPHOME_VERSION)"
    else
        echo "FAIL: Conditional stack size patch is missing or incomplete."
        FAIL=1
    fi
    if grep -q 'httpd_register_uri_handler(this->server_, &handler_delete);' "$TARGET_DIR/web_server_idf.cpp"; then
        echo "OK: HTTP_DELETE handler registration patch is applied"
    else
        echo "FAIL: HTTP_DELETE handler registration is missing."
        FAIL=1
    fi
    if [[ "$FAIL" -eq 0 ]]; then
        echo "    $TARGET_DIR/web_server_idf.cpp"

        # Check for upstream drift - warn if installed copy differs from our
        # base (ignoring both patch lines)
        UPSTREAM="$ESPHOME_COMPONENT/web_server_idf.cpp"
        LOCAL="$TARGET_DIR/web_server_idf.cpp"
        DIFF_COUNT=$(diff \
            <(sed -e '/config\.stack_size = /d' \
                  -e '/CONFIG_IDF_TARGET_ARCH_RISCV/d' \
                  -e '/RISC-V.*stack frames\|peak usage.*watermark/d' \
                  -e '/PATCH2-BEGIN/,/PATCH2-END/d' "$LOCAL") \
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

# ?? Copy upstream files ???????????????????????????????????????????????????????
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

# ?? Apply patches ?????????????????????????????????????????????????????????????
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

# ?? Patch 1: Stack size ????????????????????????????????????????????????????????
if grep -q 'CONFIG_IDF_TARGET_ARCH_RISCV' "$CPP_FILE"; then
    echo "Patch 1 (conditional stack size) already present - skipping."
else
    # Remove any old single-line stack_size patch (from pre-v7.6.9.5 runs)
    sed -i '/config\.stack_size = 16384;.*PATCHED: BUG-076/d' "$CPP_FILE"

    python3 - "$CPP_FILE" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

anchor = '  httpd_config_t config = HTTPD_DEFAULT_CONFIG();'
new_block = """
  // PATCHED: BUG-076 + v7.6.9.5 - RISC-V (C3/C6/C5) needs larger stack frames than Xtensa (ESP32/S3)
  // C3 peak usage ~15748 B (watermark 636 B on 16 KB) vs Xtensa ~3340 B (watermark 13044 B)
#if defined(CONFIG_IDF_TARGET_ARCH_RISCV)
  config.stack_size = 20480;   // 20 KB - RISC-V: conventional ABI, ~80 B per frame (C3, C6, C5, H2)
#else
  config.stack_size = 16384;   // 16 KB - Xtensa: register windows, ~24 B per frame (ESP32, S2, S3)
#endif"""

if anchor not in content:
    print("ERROR: HTTPD_DEFAULT_CONFIG anchor not found", file=sys.stderr)
    sys.exit(1)

content = content.replace(anchor, anchor + new_block, 1)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch 1 (conditional stack size) applied successfully.")
PYEOF

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Patch 1 (conditional stack size) application failed."
        exit 1
    fi
fi

# ?? Patch 2: HTTP_DELETE handler registration (BUG-079) ???????????????????????
# Stock ESPHome only registers GET, POST, OPTIONS. DELETE requests are blocked
# at the ESP-IDF httpd layer (plain-text 405) unless we register a handler.
if grep -q 'httpd_register_uri_handler(this->server_, &handler_delete);' "$CPP_FILE"; then
    echo "Patch 2 (HTTP_DELETE handler) already present - skipping."
else
    # Insert the DELETE handler block after the OPTIONS handler registration line.
    # Use a Python script for reliable multi-line insertion.
    python3 - "$CPP_FILE" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

anchor = '    httpd_register_uri_handler(this->server_, &handler_options);'
new_block = """

    // PATCH2-BEGIN: BUG-079 HTTP_DELETE registration
    // PATCHED: BUG-079 - Register DELETE so ESP-IDF httpd routes DELETE requests
    // to our handler chain instead of returning plain-text 405.
    // DELETE requests have no body, so they use the same request_handler as GET.
    const httpd_uri_t handler_delete = {
        .uri = "",
        .method = HTTP_DELETE,
        .handler = AsyncWebServer::request_handler,
        .user_ctx = this,
    };
    httpd_register_uri_handler(this->server_, &handler_delete);
    // PATCH2-END: BUG-079 HTTP_DELETE registration"""

if anchor not in content:
    print("ERROR: anchor not found", file=sys.stderr)
    sys.exit(1)

content = content.replace(anchor, anchor + new_block, 1)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch 2 (HTTP_DELETE handler) applied successfully.")
PYEOF

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Patch 2 (HTTP_DELETE handler) application failed."
        exit 1
    fi
fi

# ?? Record metadata ???????????????????????????????????????????????????????????
ESPHOME_VERSION=$(esphome version 2>/dev/null || echo "unknown")
cat > "$TARGET_DIR/PATCH_INFO.md" << EOF2
# web_server_idf local component override

## What
Two patches to \
`web_server_idf.cpp`, method \
`AsyncWebServer::begin()`:

**Patch 1 - Stack size (BUG-076 + v7.6.9.5):** Conditional \
`config.stack_size` after \
`HTTPD_DEFAULT_CONFIG()`: 20480 for ESP32-C3 (RISC-V), 16384 for Xtensa targets (ESP32, ESP32-S3). RISC-V stack frames are ~4x larger than Xtensa due to register window differences.

**Patch 2 - DELETE handler (BUG-079):** Register an \
`HTTP_DELETE` URI handler so ESP-IDF httpd routes DELETE requests to the AsyncWebServer handler chain instead of returning a plain-text 405 "Specified method is invalid for this resource".

## Why

### Patch 1 - Stack size
ESP-IDF's \
`HTTPD_DEFAULT_CONFIG()` hardcodes \
`.stack_size = 4096`.
ESPHome never overrides it. 4 KB is insufficient for any handler that performs authentication + HTTP response formatting. Stack overflow crashes with \
`StoreProhibited` in \
`vPortYieldFromInt`.

\`CONFIG_HTTPD_STACK_SIZE\` in \`sdkconfig_options\` has zero runtime effect.

v7.6.9.5 investigation found that the ESP32-C3 (RISC-V) uses ~15748 B of
httpd stack (watermark 636 B on 16 KB) while Xtensa boards use only ~3340 B
(watermark 13044 B). The RISC-V ABI pushes callee-saved registers per call
frame; Xtensa register windows keep them in hardware. Conditional sizing
avoids wasting 4 KB on heap-constrained Xtensa boards.

### Patch 2 - DELETE handler
Stock ESPHome's \
`AsyncWebServer::begin()` registers only GET, POST, and OPTIONS URI handlers. When a DELETE request arrives, ESP-IDF httpd finds no registered handler for that method and immediately returns its built-in plain-text 405, before calling any \
`canHandle()` or \
`handleRequest()` on our handler objects. Adding an explicit DELETE handler registration routes DELETE requests through the same \
`request_handler` path as GET (no body to read).

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
Re-run: \
`bash scripts/patch-esphome-httpd-stack.sh`
EOF2

echo ""
echo "Done. Metadata written to $TARGET_DIR/PATCH_INFO.md"
echo ""
echo "IMPORTANT - each board YAML needs this block:"
echo ""
echo "  external_components:"
echo "    - source:"
echo "        type: local"
echo "        path: local_components"
echo "      components: [web_server_idf]"
echo ""
echo "Then: esphome clean <yaml> && esphome run <yaml>"
