#!/usr/bin/env bash
# v7.7.1.3 check file: every gate and checkpoint of prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md, so that the
# agent types no check (PLAN-031). It also writes the scope list, inserts the two supplied texts of the prompt, runs the
# supplied host test H1, reads the three boards of the step, and writes the inputs of a manual review B (PLAN-046).
# Corrected the same day after the two internal audit rounds of the bundle (round 1: H1, M1, M3 to M5, L1, L3, L7 to L10;
# round 2: F1 to F4, F6, Q3), and again on 2026-11-25 after GPT Astra's audit and four comparison audits (PLAN-047).
# Written 2026-11-24 by the planning session for R6 (PLAN-044, PLAN-046); do not edit it.
# Fenced texts of the prompt are taken from the prompt by a tool (the function fence below), never retyped.
#
#   bash /root/v7713/v7.7.1.3-checks.sh <sec2 | scope <PR#> <YYYY-MM-DD> | copy [verify] | insert <S2|T3> | A | B | host
#        | C | D | E | dev <IP> <before | v7.7.1.3> [c3heap | floor] | v2 <IP> [before] | image <s3 | wroom> | wroom24 <epoch> | F
#        | prepr | inline <PR#> | body <PR#> [final] | reviewb <PR#> [answer]>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1; v2, wroom24
# and inline may also print a WAIT line and exit 0. The blocks dev, v2 and wroom24 read the login from $ESP_USER and $ESP_PASS
# inside one python3 process and print no value of it; no other block reads it. Temporary files go when the block ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/v7713
BRANCH=feature/v7.7.1.3-persist-write-path
PROD=a33a5cc
GHREPO=GCV-Sleeper-Service/ESP32-GW-multi-sensor
ROUNDS="Inline|Review A|Review C|Review B"
CHECKS="preflight-and-compile|prompt-lint|pr-body-check|browser-tests (3sensor)|browser-tests (1sensor)|browser-tests (2sensor)|browser-tests (4sensor)|browser-tests (mixed)|browser-tests (aggregator)|browser-tests (system)"   # the exact names of the required jobs; the latest run of each must end in success
CRITERIA=17   # the criteria of section 7 of the prompt
CLOSING="Fixes #215"   # the last line of the PR body (section 8)
EVIDENCE="r24-wroom24.txt|r24-v2-192.168.120.170.txt|r24-v2-192.168.120.189.txt"   # body final: the files in $SAVE that keep the PASS lines of the 24-hour readings of item 6.5
P=prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md
CF=prompts/phase7/v7.7.1.3-checks.sh
RF=prompts/phase7/v7.7.1.3-review.md
DM=firmware/core/data-model.h
NV=firmware/core/nvs-persistence.h
WH=firmware/core/web-handler.h
RS=scripts/render_sensor_config.py
HDR=dashboard/sensor_history_multi.h
CS=CURRENT-STATE.md
POR=Docs/plan-of-record.md
CL=Docs/changelog.md
ARCH=Docs/v7.7-v7.8-persistence-architecture.md
C3YAML=firmware/esp32-c3-multi-sensor.yaml
WRYAML=firmware/esp32-wroom-32d-gw.yaml
C3BIN=firmware/.esphome/build/esp32-c3-multi/.pioenvs/esp32-c3-multi/firmware.bin
WRBIN=firmware/.esphome/build/sat-esp32-4m-170/.pioenvs/sat-esp32-4m-170/firmware.bin
S3BIN=firmware/.esphome/build/sat-s3-4m-173/.pioenvs/sat-s3-4m-173/firmware.bin
SLOT=1769472   # ota_0 of the C3, WROOM and S3 4 MB partition tables, 0x1B0000
OLDMAC=DF:EB:DE:19:11:6C
NEWMAC=FA:2B:65:2C:98:39
CONFIGS="config/sensors.json config/sensors-sat-c5-8m-180.json.bak config/sensors-sat-c6-4m-184.json.bak config/sensors-sat-esp32-4m-170.json.bak config/sensors-sat-s3-4m-173.json.bak"
YCALL='              persist_all_devices_v2(now.timestamp);'
YANCHOR='              persist_hourly_segment(now.timestamp);'
GCALL='        lines.append("              persist_all_devices_v2(now.timestamp);")'
GANCHOR='        lines.append("              persist_hourly_segment(now.timestamp);")'
FUNCS='dev_ring_next_ dev_ring_valid_ find_device_index_ build_device_segment_ load_device_meta_ save_device_meta_ persist_device_segment_ persist_all_devices_v2'
NAME="${1:-}"
case "$NAME" in sec2) LABEL="§2" ;; prepr) LABEL="PRE-PR" ;; *) LABEL="$NAME" ;; esac
TMP="$(mktemp -d)" || { echo "⛔ CHECKPOINT FAILED - ${LABEL}: mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
fail() { echo "⛔ CHECKPOINT FAILED - ${LABEL}: $1"; exit 1; }
sha() { sha256sum < "$1" | cut -d' ' -f1; }
cnt() { grep -cE -- "$1" "$2"; }   # how many lines of $2 match the extended regex $1
COPY="4747f7ce43e5903a86929f21427a2209563b18760cde8acca101a7ed1a8bec57 prompts/phase7/consolidated-audit-template-phase7.md
35187f11ce3a4b091aa2d8faf7ecfaedc2cd0fca0a955914923509cc40c52fa5 Docs/development-process-guide.md
20c8b69d363bbe046efbedbd39f0fa0e7f56f17d81962464ca9e5c22d728db81 prompts/producer-contract.md
ad241c1476dfc5032c92d3220e6d618682da840357b532fd950356f45efd7c98 Docs/templates/prompt-audit-template.md
f86813cf12b9a1a4d9b4b7c0e348dce16392c76dae594c1cbf4a87e9519fd90e Docs/decisions/decision-log.md
225d1e5882521afe8981cfd2d1f0037f4cc3a30c63039ee49c24114fe5386370 Docs/plan-of-record.md
bb210cf77ad87c88f5f4fea8f06aa3762cb4db41e1876c63a3f8eba49b8bbed5 prompts/phase7/v7.7.1.3-review.md
9b53760dba8cd4079ad2dc4ef27afaf1e8bc0d7697d870f0f6f2473498acebd8 prompts/phase7/v7.7.1.3-audit.md
27d6fa33514e17c44886d2bae7cbbe758abe0ac5292a7bd5cb96b3a725694fc4 Docs/operator/R6-persist-write-path.md
9c34c0062e726646c1f7e008084fbd2e7c7ce31510c334a4226d44ee4e7af6b5 prompts/handoff/phase7/session-handoff-v7.7.1.3.md
a2d9f38b6e9b39d0230be67574d95c7b2a36302ae57bf7a1627814d6d11a96f7 prompts/handoff/phase7/phase7-batch2-assumption-audit.md
04853c067b031f05f6a1a4bd9d2eb9b8f13d90b6582dbe7dcac7f3083a293339 Docs/planner-start-here.md"   # the files of Task Group 0: <SHA-256> <path>, one per line
NEWFILES="prompts/phase7/v7.7.1.3-review.md prompts/phase7/v7.7.1.3-audit.md Docs/operator/R6-persist-write-path.md"
cd "$REPO" 2>/dev/null || fail "repository path $REPO"

# fence <file> <start of the line before the fence> <out>: the text between the next fence lines after that line.
fence() {
  python3 -I - "$1" "$2" "$3" <<'PYEOF'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
hits = [i for i, l in enumerate(lines) if l.startswith(sys.argv[2])]
if len(hits) != 1:
    sys.exit("%d lines begin with the label" % len(hits))
i = hits[0] + 1
while i < len(lines) and not lines[i].startswith("```"):
    i += 1
j = i + 1
while j < len(lines) and lines[j] != "```":
    j += 1
if i >= len(lines) or j >= len(lines):
    sys.exit("no fenced text after the label")
open(sys.argv[3], "w", encoding="utf-8").write("\n".join(lines[i + 1:j]) + "\n")
PYEOF
}
# contains <file> <text file>: how many times the lines of the text file occur in the file as one block
contains() {
  python3 -I - "$1" "$2" <<'PYEOF'
import sys
hay = open(sys.argv[1], encoding="utf-8").read().split("\n")
nee = open(sys.argv[2], encoding="utf-8").read().rstrip("\n").split("\n")
n = len(nee)
print(sum(1 for i in range(len(hay) - n + 1) if hay[i:i + n] == nee))
PYEOF
}
# first <file> <text file>: the line number where the block starts (0 if absent)
first() {
  python3 -I - "$1" "$2" <<'PYEOF'
import sys
hay = open(sys.argv[1], encoding="utf-8").read().split("\n")
nee = open(sys.argv[2], encoding="utf-8").read().rstrip("\n").split("\n")
n = len(nee)
print(next((i + 1 for i in range(len(hay) - n + 1) if hay[i:i + n] == nee), 0))
PYEOF
}
removed_ok() { # $1 file: every line removed since $PROD is allowed by the pattern $2 (an ERE), or none is removed
  local bad
  bad="$(git diff --no-color -U0 "$PROD" -- "$1" | grep -E '^-[^-]|^-$' | grep -vE -- "$2")"
  [ -z "$bad" ] || { echo "$bad" | head -3; return 1; }
}
supplied() { # $1 S2|T3|H1 -> $TMP/$1.txt, checked against its SHA-256
  local label want
  case "$1" in
    S2) label="Supplied text S2 — "; want=7f3c5d04889e0d9e9e32cb0339539573edcb05b2420a42c0a756cc512845f8e0 ;;
    T3) label="Supplied text T3 — "; want=32b30838d412c4590ee1d04e57a97eaff211fddbbcd4f0194b6a6c35bb30be52 ;;
    H1) label="Supplied text H1 — "; want=8d2fd5d568ce3ded2dfb512bf3e41dfbe611d40c728ac446e35626237a9502bc ;;
    *) fail "usage: insert <S2|T3>" ;;
  esac
  fence "$P" "$label" "$TMP/$1.txt" || fail "$1: the prompt has no single supplied text $1"
  test "$(sha "$TMP/$1.txt")" = "$want" || fail "$1: the supplied text in $P differs from the bundle"
}
last_text_line() { awk 'NF { n = NR } END { print n + 0 }' "$1"; }   # the number of the last line that is not empty
scope_list() { git rev-parse --git-path scope-allowed.txt; }
new_paths() { # the session log and the record, from the scope list
  local a; a="$(scope_list)" || return 1
  test -f "$a" || return 1
  grep -E '^Docs/session-log-[0-9]{4}-[0-9]{2}-[0-9]{2}-v7\.7\.1\.3\.md$|^prompts/phase7/v7\.7\.1\.3-PR[0-9]+-consolidated-audit-and-lessons\.md$' "$a"
}
same_as_prod() { test "$(git show "$PROD:$1" 2>/dev/null | sha256sum | cut -d' ' -f1)" = "$(sha "$1")"; }

b_sec2() {
  local f
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git fetch -q origin || fail "git fetch"
  test "$(git merge-base origin/main HEAD)" = "$(git rev-parse origin/main)" || fail "the branch does not start at origin/main: branch again from origin/main"
  test "$(git diff --name-only origin/main HEAD | sort | tr '\n' ' ')" = "$(printf '%s\n' "$P" "$CF" | sort | tr '\n' ' ')" || fail "the branch must change only $P and $CF (the commit of the setup file); it changes: $(git diff --name-only origin/main HEAD | head -n 4 | tr '\n' ' ')"
  test "$(cat VERSION)" = "7.7.1.2" || fail "VERSION is not 7.7.1.2"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P" "$SAVE/v7.7.1.3-agent-prompt-gpt-codex.md" || fail "$P differs from $SAVE/v7.7.1.3-agent-prompt-gpt-codex.md"
  cmp -s "$CF" "$SAVE/v7.7.1.3-checks.sh" || fail "$CF differs from $SAVE/v7.7.1.3-checks.sh"
  for f in python3 node npx git gh curl esphome g++ sha256sum; do command -v "$f" >/dev/null || fail "the tool $f is missing"; done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' || fail "python3 is older than 3.12"
  esphome version 2>/dev/null | grep -qx 'Version: 2026.4.1' || fail "esphome is not 2026.4.1 (PLAN-016)"
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing"
  gh auth status >/dev/null 2>&1 || fail "gh is not logged in"
  [ -n "${ESP_USER:-}" ] && [ -n "${ESP_PASS:-}" ] || fail "\$ESP_USER or \$ESP_PASS is not set in this shell"
  for f in "$DM" "$NV" "$WH" "$C3YAML" "$RS" "$CL" "$ARCH" $CONFIGS; do
    same_as_prod "$f" || fail "$f changed since $PROD: the planning session renders the prompt again"
  done
  while read -r _ f; do
    [ -n "$f" ] || continue
    test -f "$SAVE/files/$f" || fail "the supplied file $SAVE/files/$f is missing"
    if [[ " $NEWFILES " == *" $f "* ]]; then
      test ! -e "$f" || fail "$f exists already: the planning session renders the bundle again"
    else
      same_as_prod "$f" || fail "$f changed since $PROD: the planning session renders the bundle again"
    fi
  done <<< "$COPY"
  test "$(cnt 'DEV_PERSIST_PROVISIONAL_SLOTS|persist_all_devices_v2|g_dev_persist_status' "$NV")" = "0" || fail "$NV already holds a symbol of this step"
  test "$(cnt 'persist_v2|g_dev_persist_status' "$WH")" = "0" || fail "$WH already holds a symbol of this step"
  test "$(cnt 'persist_all_devices_v2' "$RS")" = "0" && test "$(cnt 'persist_all_devices_v2' "$C3YAML")" = "0" || fail "the call of 3.1 exists already"
  for f in $CONFIGS "$DM"; do
    test "$(grep -c -- "$OLDMAC" "$f")" = "1" || fail "1.1 anchor: $OLDMAC once in $f"
  done
  test "$(tail -n 2 "$NV" | head -n 1)" = "}" && test -z "$(tail -n 1 "$NV")" || fail "2.1 anchor: $NV ends with the line } of persist_hourly_segment() and one empty line"
  test "$(grep -cxF 'static void persist_hourly_segment(uint32_t saved_at_epoch = 0) {' "$NV")" = "1" || fail "2.1 anchor: persist_hourly_segment() in $NV"
  test "$(grep -n '^static void persist_hourly_segment(' "$NV" | cut -d: -f1)" -lt "$(last_text_line "$NV")" || fail "2.1 anchor: persist_hourly_segment() is the last function of $NV"
  test "$(grep -cxF 'static int export_latest_entries_(const HistoryBuffer &buf,' "$NV")" = "1" || fail "2.4 anchor: export_latest_entries_() in $NV"
  test "$(grep -cxF 'static void maybe_yield_nvs_scan_(int iteration) {' "$NV")" = "1" || fail "2.2 anchor: maybe_yield_nvs_scan_() in $NV"
  test "$(grep -cxF -- "$YANCHOR" "$C3YAML")" = "1" || fail "3.1 anchor: the call of persist_hourly_segment in $C3YAML"
  test "$(grep -cxF -- "$GANCHOR" "$RS")" = "1" || fail "3.1 anchor: the line of persist_hourly_segment in $RS"
  test "$(grep -cF '"\"last_persist_epoch\":%u,\"namespace_initialized\":%s}}",' "$WH")" = "1" || fail "4.1 anchor: the format string of handle_storage_stats_() in $WH"
  test "$(grep -cxF '## 7. Retention Budgeting' "$ARCH")" = "1" || fail "7.4 anchor: the heading of §7 in $ARCH"
  test "$(grep -cxF '## 10. Persist Flow' "$ARCH")" = "1" || fail "7.4 anchor: the heading of §10 in $ARCH"
  test "$(grep -c '^| 9 | R6 |' "$SAVE/files/$POR")" = "1" || fail "7.2 anchor: the row 9 of the ladder in the supplied $POR"
  test "$(grep -cxF '## 2. You are here' "$SAVE/files/$POR")" = "1" || fail "7.2 anchor: the heading '## 2. You are here' in the supplied $POR"
  test -f config/gateway-sat-s3-4m-173.json.bak || fail "6.1 anchor: config/gateway-sat-s3-4m-173.json.bak"
  sed -n 3p "$CS" | grep -q '^_Last verified: ' && sed -n 4p "$CS" | grep -q '^_Next action: ' || fail "7.1 anchor: lines 3 and 4 of $CS are '_Last verified: ...' and '_Next action: ...'"
  for x in '- **Current version:** 7.7.1.2' '## What Just Shipped (last 3 steps)' '1. **Produce the v7.7.1.3 bundle, then R6**' '| WROOM heap |' '## Phase 7 Device Validation Snapshot' \
           '_Observed on 2026-05-08 after flashing v7.7.1.1 production builds._' '| PR #246 review A Q3' '| PR #246 c3heap stop' '| Restart check 2026-11 | Firmware `.bin` size checkpoint' \
           '| sat-s3-4m-173 |' '| esp32-c3-multi |' '| sat-esp32-4m-170 |' '## Unimplemented Recommendations'; do
    test "$(grep -cF -- "$x" "$CS")" = "1" || fail "7.1 anchor: '$x' once in $CS"
  done
  for f in S2 T3 H1; do supplied "$f"; done
  echo "§2 PASS"
}

b_scope() {
  local pr="${1:-}" day="${2:-}" a
  [[ "$pr" =~ ^[0-9]+$ ]] && [[ "$day" =~ ^20[0-9]{2}-[01][0-9]-[0-3][0-9]$ ]] || fail "usage: scope <PR#> <YYYY-MM-DD>"
  a="$(scope_list)" || fail "git rev-parse"
  cat > "$a" <<'EOF'
prompts/phase7/v7.7.1.3-agent-prompt-gpt-codex.md
prompts/phase7/v7.7.1.3-checks.sh
prompts/phase7/consolidated-audit-template-phase7.md
Docs/development-process-guide.md
prompts/producer-contract.md
Docs/templates/prompt-audit-template.md
Docs/decisions/decision-log.md
Docs/plan-of-record.md
prompts/phase7/v7.7.1.3-review.md
prompts/phase7/v7.7.1.3-audit.md
Docs/operator/R6-persist-write-path.md
prompts/handoff/phase7/session-handoff-v7.7.1.3.md
prompts/handoff/phase7/phase7-batch2-assumption-audit.md
Docs/planner-start-here.md
config/sensors.json
config/sensors-sat-c5-8m-180.json.bak
config/sensors-sat-c6-4m-184.json.bak
config/sensors-sat-esp32-4m-170.json.bak
config/sensors-sat-s3-4m-173.json.bak
firmware/core/data-model.h
firmware/core/nvs-persistence.h
firmware/core/web-handler.h
firmware/esp32-c3-multi-sensor.yaml
scripts/render_sensor_config.py
CURRENT-STATE.md
Docs/changelog.md
Docs/v7.7-v7.8-persistence-architecture.md
Docs/lessons/index.md
Docs/lessons/firmware.md
VERSION
dashboard/core/app-shell.js
dashboard/dashboard.h
dashboard/dashboard.html
dashboard/dashboard.js
dashboard/sensor_history_multi.h
firmware/core/config.h
src/gateway_manifest.h
tests/fixtures/generate-fixtures.js
tests/fixtures/manifest.json
tests/fixtures/variants/1sensor/manifest.json
tests/fixtures/variants/2sensor/manifest.json
tests/fixtures/variants/3sensor/manifest.json
tests/fixtures/variants/4sensor/manifest.json
tests/fixtures/variants/mixed/manifest.json
tests/fixtures/variants/system/manifest.json
EOF
  printf '%s\n' "Docs/session-log-$day-v7.7.1.3.md" "prompts/phase7/v7.7.1.3-PR$pr-consolidated-audit-and-lessons.md" >> "$a"
  test "$(grep -c . "$a")" = "47" || fail "the scope list does not hold 47 paths"
  echo "scope list written: 47 paths"
}

por_ok() { # the plan of record differs from its supplied text only as item 7.2 says: row 9 and section 2
  python3 -I - "$SAVE/files/$POR" "$POR" <<'PYEOF'
import sys
a = open(sys.argv[1], encoding="utf-8").read().split("\n")
b = open(sys.argv[2], encoding="utf-8").read().split("\n")
def row9(lines):
    r = [l for l in lines if l.startswith("| 9 | R6 |")]
    return [c.strip() for c in r[0].strip().strip("|").split("|")] if len(r) == 1 else None
def sec2(lines):
    out, on = [], False
    for l in lines:
        if l.startswith("## "):
            on = l.startswith("## 2. You are here")
        elif on:
            out.append(l)
    return "\n".join(out).strip()
ra, rb = row9(a), row9(b)
if rb is None or len(rb) != len(ra) or rb[:-1] != ra[:-1] or not rb[-1].startswith("Done"):
    sys.exit("row 9 (R6): only its status cell may change, to Done (item 7.2); the cell 'Actual (sessions)' stays empty")
s2 = sec2(b)
if s2 == sec2(a) or not all(w in s2 for w in ("R6", "v7.7.1.4", "R7")):
    sys.exit("section 2, 'You are here', must be rewritten as item 7.2 says: it names R6, v7.7.1.4 and R7")
def strip(lines):
    out, skip = [], False
    for l in lines:
        if l.startswith("## "):
            skip = l.startswith("## 2. You are here")
        if skip or l.startswith("| 9 | R6 |"):
            continue
        out.append(l)
    return out
if strip(a) != strip(b):
    x = next(i for i, (p, q) in enumerate(zip(strip(a) + [""], strip(b) + [""])) if p != q)
    sys.exit("first difference: " + (strip(b) + [""])[x][:120])
PYEOF
}

b_copy() { # copy [verify]: Task Group 0 copies the twelve supplied files; verify (PRE-PR) checks them again
  local mode="${1:-}" want f n=0
  [ -z "$mode" ] || [ "$mode" = "verify" ] || fail "usage: copy [verify]"
  while read -r want f; do
    [ -n "$f" ] || continue
    if [ "$mode" != "verify" ]; then
      test "$(sha "$SAVE/files/$f")" = "$want" || fail "the supplied file $SAVE/files/$f differs from the bundle"
    fi
    if [ -f "$f" ] && [ "$(sha "$f")" = "$want" ]; then
      n=$((n + 1)); continue
    fi
    if [ "$f" = "$POR" ] && por_ok > "$TMP/por.log" 2>&1; then
      n=$((n + 1)); continue   # copied before, then edited as item 7.2 says
    fi
    [ "$mode" != "verify" ] || fail "$f differs from its supplied text: a file that the block copy wrote was edited ($(tail -n 1 "$TMP/por.log" 2>/dev/null))"
    if [[ " $NEWFILES " == *" $f "* ]]; then
      test ! -e "$f" || fail "$f exists and is not its supplied text"
      mkdir -p "$(dirname "$f")" || fail "cannot create the folder of $f"
    else
      same_as_prod "$f" || fail "$f is neither the file of $PROD nor its supplied text"
    fi
    cp "$SAVE/files/$f" "$f" || fail "cannot write $f"
    test "$(sha "$f")" = "$want" || fail "$f does not equal its supplied text after the copy"
    n=$((n + 1))
  done <<< "$COPY"
  test "$n" = "12" || fail "the list of the block copy holds $n files, not 12"
  if [ "$mode" = "verify" ]; then echo "copy verify PASS: 12 files"; return; fi
  echo "copied 12 files"
  echo "CHECKPOINT 0 PASS"
}

b_insert() { # insert S2|T3: after the last line that is not empty, keeping the empty last line
  local what="${1:-}" n
  supplied "$what"
  n="$(contains "$NV" "$TMP/$what.txt")"
  if [ "$n" = "1" ]; then echo "inserted $what"; return; fi
  test "$n" = "0" || fail "$what occurs $n times in $NV"
  case "$what" in
    S2) test "$(sed -n "$(last_text_line "$NV")p" "$NV")" = "}" && same_as_prod "$NV" || fail "S2: $NV must still be the file of $PROD, ending with the line } of persist_hourly_segment()" ;;
    T3) supplied S2
        test "$(contains "$NV" "$TMP/S2.txt")" = "1" || fail "T3: S2 is not in $NV: run insert S2 first"
        test "$(cnt '^static void persist_all_devices_v2\(' "$NV")" = "1" || fail "T3: write the definitions of item 2.2 first" ;;
  esac
  python3 -I - "$NV" "$TMP/$what.txt" <<'PYEOF' || fail "$what: cannot write $NV"
import sys
p, t = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
s = open(p, encoding="utf-8").read().rstrip("\n")
open(p, "w", encoding="utf-8").write(s + "\n" + t.rstrip("\n") + "\n\n")
PYEOF
  test "$(contains "$NV" "$TMP/$what.txt")" = "1" || fail "$what: not in $NV after the insert"
  echo "inserted $what"
}

assembly_ok() {
  bash scripts/assemble-sensor-history.sh --check > "$TMP/asm.log" 2>&1 || fail "bash scripts/assemble-sensor-history.sh --check fails: $(tail -n 2 "$TMP/asm.log" | tr '\n' ' ')"
}
render_ok() {
  python3 scripts/render_sensor_config.py --check > "$TMP/rs.log" 2>&1 || fail "python3 scripts/render_sensor_config.py --check fails: $(head -n 2 "$TMP/rs.log" | tr '\n' ' ')"
}

b_A() {
  local f x
  for f in $CONFIGS "$DM"; do
    test "$(grep -c -- "$NEWMAC" "$f")" = "1" || fail "1.1 $NEWMAC must occur once in $f"
    test "$(grep -c -- "$OLDMAC" "$f")" = "0" || fail "1.1 $OLDMAC is still in $f"
  done
  for f in $CONFIGS; do
    test "$(git diff --no-color -U0 "$PROD" -- "$f" | grep -cE '^[-+][^-+]')" = "2" || fail "1.1 $f: exactly one line may change, the MAC"
  done
  x="$(git diff --no-color -U0 "$PROD" -- "$DM" | grep -E '^[-+][^-+]' | grep -vF -- "$OLDMAC" | grep -vF -- "$NEWMAC" | grep -v 'v7\.7\.1\.[23]')"
  test -z "$x" || fail "1.1 $DM: a line other than the MAC (and the version) changed: $(head -n 1 <<< "$x")"
  x="$(git grep -l -F -e "$OLDMAC" -- config firmware src dashboard tests scripts 2>/dev/null)"
  test -z "$x" || fail "1.2 $OLDMAC is still in: $(tr '\n' ' ' <<< "$x"): run python3 scripts/render_sensor_config.py --write, then the assembly"
  for f in "$HDR" src/gateway_manifest.h "$C3YAML"; do
    grep -qF -- "$NEWMAC" "$f" || fail "1.2 $f does not hold $NEWMAC: run python3 scripts/render_sensor_config.py --write"
  done
  render_ok
  assembly_ok
  echo "CHECKPOINT A PASS"
}

b_B() {
  local s t e f n x prev=0
  supplied S2; supplied T3
  test "$(contains "$NV" "$TMP/S2.txt")" = "1" || fail "2.1 S2 must occur once in $NV, verbatim"
  test "$(contains "$NV" "$TMP/T3.txt")" = "1" || fail "2.3 T3 must occur once in $NV, verbatim"
  s="$(first "$NV" "$TMP/S2.txt")"; t="$(first "$NV" "$TMP/T3.txt")"
  e="$(grep -n '^static void persist_hourly_segment(' "$NV" | cut -d: -f1)"
  [ "$e" -lt "$s" ] && [ "$s" -lt "$t" ] || fail "2.1 S2 must come after persist_hourly_segment() and before T3"
  test "$((t + $(wc -l < "$TMP/T3.txt") - 1))" = "$(last_text_line "$NV")" && test -z "$(tail -n 1 "$NV")" || fail "2.3 T3 must end the file, followed by one empty line"
  fence "$P" "**2.2** " "$TMP/sig.txt" || fail "2.2 fenced text"
  for f in $FUNCS; do
    x="$(grep -E "^static [a-z0-9_ ]+ $f\(" "$TMP/sig.txt" | sed -E 's/;[[:space:]]*(\/\/.*)?$//')"
    [ -n "$x" ] || fail "2.2 the prompt has no signature of $f"
    test "$(grep -cE "^static [a-z0-9_ ]+ $f\(" "$NV")" = "1" || fail "2.2 one definition of $f in $NV"
    test "$(grep -cxF -- "$x {" "$NV")" = "1" || fail "2.2 the first line of $f must be '$x {'"
    n="$(grep -nxF -- "$x {" "$NV" | cut -d: -f1)"
    [ "$n" -gt "$s" ] && [ "$n" -lt "$t" ] && [ "$n" -gt "$prev" ] || fail "2.2 the definitions must stand between S2 and T3, in the order of the prompt ($f)"
    prev="$n"
  done
  python3 -I - "$NV" <<'PYEOF' || fail "2.2 the order of the calls (see the line above)"
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
def close(src, i):  # the index after the brace that closes the block opened just before i; skips strings, chars and comments
    depth = 1
    while depth and i < len(src):
        c = src[i]
        if c == "/" and src[i:i + 2] == "//":
            i = src.find("\n", i)
            i = len(src) if i < 0 else i
            continue
        if c in "\"'":
            j = i + 1
            while j < len(src) and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            i = j + 1
            continue
        depth += {"{": 1, "}": -1}.get(c, 0)
        i += 1
    return i
def body(name):
    m = re.search(r"(?m)^static [a-z0-9_ ]+ " + name + r"\(.*\{$", src)
    if not m:
        sys.exit("no definition of " + name)
    return src[m.end():close(src, m.end())]
p = body("persist_device_segment_")
stats = p.find("nvs_get_stats(HISTORY_PARTITION_LABEL")
guard = p.find("DEV_PERSIST_MIN_FREE_ENTRIES")
seg = re.search(r"nvs_set_blob\([^;]*sizeof\s*\(\s*(?:DeviceSegment|\*\s*seg)\s*\)", p, re.S)
meta = p.find("save_device_meta_(")
if stats < 0 or guard < 0 or seg is None or meta < 0:
    sys.exit("persist_device_segment_ needs nvs_get_stats(HISTORY_PARTITION_LABEL, DEV_PERSIST_MIN_FREE_ENTRIES, nvs_set_blob(... sizeof(DeviceSegment) or sizeof(*seg)) and save_device_meta_(")
if not (stats < seg.start() and guard < seg.start() and seg.start() < meta):
    sys.exit("persist_device_segment_: the guard must come before the segment write, and the segment write before save_device_meta_(")
for w in ("load_device_meta_(", "dev_persist_status_get_(", "dev_persist_status_put_("):
    if w not in p:
        sys.exit("persist_device_segment_ needs " + w)
a = body("persist_all_devices_v2")
for w in ("nvs_open_from_partition(HISTORY_PARTITION_LABEL, HISTORY_NAMESPACE, NVS_READWRITE", "maybe_yield_nvs_scan_(", "nvs_close(", "new (std::nothrow) DeviceSegment", "delete ", "persist_device_segment_(", "dev_persist_status_get_(", "dev_persist_status_put_("):
    if w not in a:
        sys.exit("persist_all_devices_v2 needs " + w)
PYEOF
  test "$(sed -n "$((s + $(wc -l < "$TMP/S2.txt"))),$((t - 1))p" "$NV" | sed 's://.*$::' | grep -c 'g_dev_persist_status\b')" = "0" || fail "2.2 the eight definitions name g_dev_persist_status: they use dev_persist_status_get_ and dev_persist_status_put_ of S2"
  sed -n "$s,\$p" "$NV" | sed 's://.*$::' > "$TMP/new.txt"
  test "$(cnt '\bvTaskDelay\b|\bmalloc\b|\bfree\(|std::string|std::vector|\bString\b|nvs_erase_key|nvs_erase_all|nvs_flash_erase_partition|nvs_flash_init_partition|open_history_nvs_|ensure_history_nvs_ready_' "$TMP/new.txt")" = "0" || fail "§5 the new code uses a word that §5 forbids: $(grep -m1 -E '\bvTaskDelay\b|\bmalloc\b|\bfree\(|std::string|std::vector|\bString\b|nvs_erase|nvs_flash_init|open_history_nvs_|ensure_history_nvs_ready_' "$TMP/new.txt")"
  test "$(cnt '^#include' "$TMP/new.txt")" = "0" || fail "an #include line was added"
  removed_ok "$NV" '^$^' || fail "a line of $NV on main was removed or changed (the lines above)"
  test "$(git grep -c 'persist_all_devices_v2(' -- 'firmware/core/*.h' | awk -F: '{ n += $2 } END { print n + 0 }')" = "$(grep -c 'persist_all_devices_v2(' "$NV")" || fail "2.2 a fragment other than $NV names persist_all_devices_v2"
  assembly_ok
  echo "CHECKPOINT B PASS"
}

b_host() { # host: the behaviour test of Task Group 2 (supplied test H1): g++ builds the write path of the checkout against a fake NVS
  command -v g++ >/dev/null || fail "g++ is missing on this host (operator page, 'Before you start')"
  python3 -I - "$DM" "$NV" "$TMP/h1" <<'PYEOF' || fail "the code of the host test cannot be taken from the fragments (an anchor of the prompt moved)"
import sys
dm = open(sys.argv[1], encoding="utf-8").read().split("\n")
nv = open(sys.argv[2], encoding="utf-8").read().split("\n")
def cut(lines, start, end, include_end=True):
    a = [i for i, l in enumerate(lines) if l == start]
    if len(a) != 1:
        sys.exit("%d lines equal %r" % (len(a), start))
    i = a[0]
    j = i
    while j < len(lines) and lines[j] != end:
        j += 1
    if j >= len(lines):
        sys.exit("no line %r after %r" % (end, start))
    return lines[i:j + 1] if include_end else lines[i:j]
types = ["#define MAX_METRICS_PER_DEVICE 4"]
types += cut(dm, "struct HistEntry {", "};")
types += cut(dm, "class HistoryBuffer {", "};")
types += cut(dm, "struct MetricDef {", "};")
types += cut(dm, "struct MetricState {", "};")
types += cut(dm, "struct SensorEntity {", "};")
types += cut(dm, "static constexpr uint32_t DEV_HIST_MAGIC = 0x44485632UL;  // \"DHV2\"", "struct EventEntry {", False)
funcs = cut(nv, "static int export_latest_entries_(const HistoryBuffer &buf,", "}")
funcs += cut(nv, "static constexpr uint32_t device_id_hash_(const char *id) {", "static void clear_runtime_histories_() {", False)
s2 = [i for i, l in enumerate(nv) if l == "// Phase 7 — per-device persist write path (v7.7.1.3, PLAN-046)"]
if len(s2) != 1:
    sys.exit("S2 is not in the fragment once")
funcs += nv[s2[0] - 1:]
open(sys.argv[3] + "_types.h", "w", encoding="utf-8").write("\n".join(types) + "\n")
open(sys.argv[3] + "_funcs.h", "w", encoding="utf-8").write("\n".join(funcs) + "\n")
PYEOF
  fence "$P" "Supplied text H1 — " "$TMP/h1_test.cpp" || fail "the prompt has no single supplied text H1"
  test "$(sha "$TMP/h1_test.cpp")" = "8d2fd5d568ce3ded2dfb512bf3e41dfbe611d40c728ac446e35626237a9502bc" || fail "H1: the supplied text in $P differs from the bundle"
  ( cd "$TMP" && g++ -std=gnu++20 -O0 -Wall -Wno-unused-function -Wno-unused-variable -o h1_run h1_test.cpp ) > "$TMP/h1.log" 2>&1 || { head -n 30 "$TMP/h1.log"; fail "the host test does not compile"; }
  "$TMP/h1_run" > "$TMP/h1.out" 2>&1 || { grep -E '^H1' "$TMP/h1.out" | head -n 20; fail "the host test failed: the write path does not do what Task Group 2 says"; }
  grep -E '^H1' "$TMP/h1.out"
  echo "host PASS"
}

b_C() {
  local w n
  test "$(grep -cxF -- "$YCALL" "$C3YAML")" = "1" || fail "3.1 the line '$YCALL' must occur once in $C3YAML"
  n="$(grep -nxF -- "$YANCHOR" "$C3YAML" | cut -d: -f1)"
  test "$(sed -n "$((n + 1))p" "$C3YAML")" = "$YCALL" || fail "3.1 the call must stand directly after the call of persist_hourly_segment in $C3YAML"
  test "$(grep -cxF -- "$GCALL" "$RS")" = "1" || fail "3.1 the line '$GCALL' must occur once in $RS"
  n="$(grep -nxF -- "$GANCHOR" "$RS" | cut -d: -f1)"
  test "$(sed -n "$((n + 1))p" "$RS")" = "$GCALL" || fail "3.1 the line must stand directly after the line of persist_hourly_segment in $RS"
  test "$(git diff --no-color -U0 "$PROD" -- "$RS" | grep -E '^[-+][^-+]' | grep -v '^+        lines.append("              persist_all_devices_v2(now.timestamp);")$' | grep -cv 'VERSION = "7\.7\.1\.[23]"')" = "0" || fail "3.1 $RS: a line other than the call (and the version) changed"
  render_ok
  # the WROOM configuration is rendered in a copy of the tracked files, so the checkout does not change
  mkdir -p "$TMP/wt" && git ls-files -z | xargs -0 cp --parents -t "$TMP/wt" 2>/dev/null || fail "cannot copy the tracked files to $TMP/wt"
  ln -s "$REPO/node_modules" "$TMP/wt/node_modules" || fail "cannot link node_modules into the copy"
  ( cd "$TMP/wt" && bash scripts/provision.sh wroom ) > "$TMP/pw.log" 2>&1 || fail "bash scripts/provision.sh wroom fails in the copy: $(tail -n 2 "$TMP/pw.log" | tr '\n' ' ')"
  w="$(grep -nxF -- "$YANCHOR" "$TMP/wt/$WRYAML" | cut -d: -f1)"
  [ -n "$w" ] && test "$(sed -n "$((w + 1))p" "$TMP/wt/$WRYAML")" = "$YCALL" || fail "3.2 the WROOM YAML of bash scripts/provision.sh wroom has no call of persist_all_devices_v2 directly after persist_hourly_segment"
  echo "CHECKPOINT C PASS"
}

b_D() {
  local x
  x="$(git diff --no-color -U0 "$PROD" -- "$WH" | grep -E '^-[^-]|^-$')"
  test "$(grep -c . <<< "$x")" = "1" && grep -qF '"\"last_persist_epoch\":%u,\"namespace_initialized\":%s}}",' <<< "$x" || fail "4.1 $WH may lose only the format string of the prompt; it loses: $(head -n 2 <<< "$x" | tr '\n' ' ')"
  python3 -I - "$WH" "$PROD" <<'PYEOF' || fail "4.1 (see the line above)"
import re, subprocess, sys
def close(src, i):  # the index after the brace that closes the block opened just before i; skips strings, chars and comments
    depth = 1
    while depth and i < len(src):
        c = src[i]
        if c == "/" and src[i:i + 2] == "//":
            i = src.find("\n", i)
            i = len(src) if i < 0 else i
            continue
        if c in "\"'":
            j = i + 1
            while j < len(src) and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            i = j + 1
            continue
        depth += {"{": 1, "}": -1}.get(c, 0)
        i += 1
    return i
def func(src):
    m = re.search(r"(?m)^  void handle_storage_stats_\(AsyncWebServerRequest \*request\) const \{$", src)
    if not m:
        sys.exit("no handle_storage_stats_() in the form of main")
    i = close(src, m.end())
    return m.start(), i, src[m.end():i]
def strip(src, blank=False):  # the code without // and /* */ comments; blank=True also empties string and char literals
    out, i, n = [], 0, len(src)
    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            out.append(" "); continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(" " + "\n" * src.count("\n", i, j)); i = j; continue
        c = src[i]
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            lit = src[i:j + 1]
            out.append(c + " " * max(len(lit) - 2, 0) + c if blank else lit); i = j + 1; continue
        out.append(c); i += 1
    return "".join(out)
new = open(sys.argv[1], encoding="utf-8").read()
old = subprocess.run(["git", "show", sys.argv[2] + ":" + sys.argv[1]], capture_output=True, text=True, check=True).stdout
a, b, fn = func(new)
oa, ob, ofn = func(old)
if new[:a] != old[:oa] or new[b:] != old[ob:]:
    sys.exit("a line outside handle_storage_stats_() changed")
# the handler of main up to its last resp->print(num);, with the format string changed, then the insertion, then the rest of main (re-audit 2, H07)
cut = ofn.rindex("request->send(resp);")
k = ofn.rindex("resp->print(num);", 0, cut) + len("resp->print(num);")
FMT, FMT2 = 'namespace_initialized\\":%s}}",', 'namespace_initialized\\":%s},",'
if ofn[:k].count(FMT) != 1:
    sys.exit("the format string of main is not in handle_storage_stats_() of main")
pre, suf = ofn[:k].replace(FMT, FMT2), ofn[cut:]
if not fn.startswith(pre) or not fn.endswith(suf) or len(fn) < len(pre) + len(suf):
    sys.exit("handle_storage_stats_() may change only the end of the format string to %s}, and add code after its last resp->print(num); and before request->send(resp); (item 4.1)")
region = fn[len(pre):len(fn) - len(suf)]
code, bare = strip(region), strip(region, blank=True)   # comments never count; bare: no literals either (re-audit 2, M04)
keys = ["persist_v2", "slots", "min_free_entries", "devices", "id", "meta_key", "result", "valid_segments", "next_slot",
        "last_persist_epoch", "writes_ok", "writes_skipped", "writes_failed"]
pos = 0
for k in keys:
    i = code.find('\\"' + k + '\\"', pos)
    if i < 0:
        sys.exit("the member %s of persist_v2 is missing or out of order" % k)
    pos = i + 1
for w in ("dev_persist_status_get_(", "PERSIST_DEVICE_IDS", "device_meta_key_(", "dev_persist_result_name_(", "DEV_PERSIST_PROVISIONAL_SLOTS", "DEV_PERSIST_MIN_FREE_ENTRIES"):
    if w not in bare:
        sys.exit("persist_v2 must come from " + w)
if re.search(r"g_dev_persist_status\b", bare):
    sys.exit("handle_storage_stats_() reads the status only through dev_persist_status_get_(), never g_dev_persist_status")
INTS = r"(?:unsigned(?:\s+(?:int|long))?|int|long|size_t|u?int(?:8|16|32)_t)"   # the integer types of the loop index and of a cast
CALLS = {"for", "if", "sizeof", "snprintf", "print", "dev_persist_status_get_", "device_meta_key_", "dev_persist_result_name_",
         "unsigned", "int", "long", "size_t", "uint8_t", "uint16_t", "uint32_t", "int8_t", "int16_t", "int32_t"}   # a functional cast is no call (internal round 3, L2)
calls = set(re.findall(r"([A-Za-z_]\w*)\s*\(", bare))
if calls - CALLS or re.search(r"(?<!resp->)\bprint\s*\(", bare):   # no NVS call, direct or through a helper (re-audit 2, H07)
    sys.exit("the added code calls only snprintf, resp->print, sizeof, dev_persist_status_get_, device_meta_key_ and dev_persist_result_name_ (item 4.1); it calls %s" % (", ".join(sorted(calls - CALLS)) or "print without resp->"))
if re.search(r"\bnew\b|\b(?:malloc|calloc|realloc|strdup)\b|std::string|\bString\b", bare):
    sys.exit("no new allocation in persist_v2")
# one loop over the persist indexes; each device's copy and id come from its own index (re-audit 2, H06)
loops = re.findall(r"\bfor\s*\(", bare)
m = re.search(r"\bfor\s*\(\s*" + INTS + r"\s+(\w+)\s*=\s*0\s*;\s*(\w+)\s*<\s*PERSIST_DEVICE_COUNT\s*;\s*(?:\+\+\s*(\w+)|(\w+)\s*\+\+)\s*\)\s*\{", bare)
if len(loops) != 1 or not m or len({m.group(1), m.group(2), m.group(3) or m.group(4)}) != 1:
    sys.exit("persist_v2 needs one loop 'for (int i = 0; i < PERSIST_DEVICE_COUNT; i++) {' (any name and integer type) over the devices (item 4.1)")
v, end = m.group(1), close(bare, m.end())
body = bare[m.end():end]
first = re.match(r"\s*(?:const\s+)?(?:DevicePersistStatus|auto)\s+\w+\s*=\s*dev_persist_status_get_\(\s*%s\s*\)\s*;" % v, body)
if bare.count("dev_persist_status_get_(") != 1 or not first:   # the copy is the loop's first statement (internal round 3, L2)
    sys.exit("handle_storage_stats_() takes one copy of each device's status: 'DevicePersistStatus <name> = dev_persist_status_get_(%s);' as the first statement of the loop" % v)
ids = re.findall(r"PERSIST_DEVICE_IDS\s*\[\s*([^\]]*?)\s*\]", bare)
if not ids or set(ids) != {v} or len(re.findall(r"PERSIST_DEVICE_IDS\s*\[", body)) != len(ids):
    sys.exit("each device's id is PERSIST_DEVICE_IDS[%s], inside the loop, with its index" % v)
if re.search(r"(?<![=!<>])\b%s\s*(?:[-+*/%%&|^]?=(?!=)|\+\+|--)|(?:\+\+|--)\s*%s\b" % (v, v), body):
    sys.exit("the loop index %s changes only in the loop's header" % v)
PYEOF
  assembly_ok
  echo "CHECKPOINT D PASS"
}

b_E() { # E [noimage]: the PRE-PR gate runs it without the image, which esphome clean of Task Group 6 removes
  local mode="${1:-}" size
  test "$(cat VERSION)" = "7.7.1.3" || fail "5.1 VERSION is not 7.7.1.3: run bash scripts/bump-version.sh 7.7.1.3"
  test "$(cnt '^VERSION = "7\.7\.1\.3"$' "$RS")" = "1" || fail "5.1 $RS does not say VERSION = \"7.7.1.3\""
  test "$(cnt "App\.version = 'v7\.7\.1\.3'" dashboard/core/app-shell.js)" = "1" || fail "5.1 dashboard/core/app-shell.js does not say v7.7.1.3"
  test "$(cnt 'v7\.7\.1\.3' "$C3YAML")" = "2" || fail "5.1 $C3YAML does not name v7.7.1.3 twice"
  assembly_ok
  if [ "$mode" = "noimage" ]; then echo "CHECKPOINT E PASS (without the image)"; return; fi
  test -f "$C3BIN" || fail "5.2 $C3BIN is missing: compile the C3 build first (esphome compile $C3YAML)"
  [ "$C3BIN" -nt "$HDR" ] || fail "5.2 $C3BIN is older than $HDR: compile again"
  size="$(stat -c %s "$C3BIN")" || fail "stat"
  echo "C3 image: $size B of the OTA slot of $SLOT B ($((size * 1000 / SLOT / 10)).$((size * 1000 / SLOT % 10)) %)"
  [ "$size" -le $((SLOT * 95 / 100)) ] || fail "5.2 the C3 image ($size B) is above 95 % of the OTA slot ($SLOT B), the stop of PLAN-047: STOP and report"
  [ "$size" -le $((SLOT * 90 / 100)) ] || echo "C3 image above 90 % of the OTA slot: the planning trigger of PLAN-047; say so in the PR body"
  echo "CHECKPOINT E PASS"
}

b_image() { # image <s3 | wroom>: the image of that build against its OTA slot
  local which="${1:-}" bin size
  case "$which" in s3) bin="$S3BIN" ;; wroom) bin="$WRBIN" ;; *) fail "usage: image <s3 | wroom>" ;; esac
  test -f "$bin" || fail "$bin is missing: compile the $which build first"
  [ "$bin" -nt "$HDR" ] || fail "$bin is older than $HDR: compile again"
  size="$(stat -c %s "$bin")" || fail "stat"
  echo "$which image: $size B of the OTA slot of $SLOT B ($((size * 1000 / SLOT / 10)).$((size * 1000 / SLOT % 10)) %)"
  [ "$size" -le $((SLOT * 95 / 100)) ] || fail "the $which image ($size B) is above 95 % of the OTA slot ($SLOT B), the stop of PLAN-047: STOP and report"
  [ "$size" -le $((SLOT * 90 / 100)) ] || echo "$which image above 90 % of the OTA slot: the planning trigger of PLAN-047; say so in the PR body"
  echo "image PASS"
}

status_full() { # $1 IP: prints version, uptime, free_heap, min_free_heap and the time of the reading; reads the login in this one process only
  python3 -I - "$1" <<'PYEOF'
import base64, json, os, sys, time, urllib.error, urllib.request
ip = sys.argv[1]
user, pw = os.environ.get("ESP_USER", ""), os.environ.get("ESP_PASS", "")
if not user or not pw:
    sys.exit("$ESP_USER or $ESP_PASS is not set")
req = urllib.request.Request("http://%s/api/status/full" % ip)
req.add_header("Authorization", "Basic " + base64.b64encode(("%s:%s" % (user, pw)).encode()).decode())
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        j = json.load(r)
except urllib.error.HTTPError as e:
    print("ERROR cannot read /api/status/full of %s: HTTP %d" % (ip, e.code)); sys.exit(0)
except Exception as e:
    print("ERROR cannot read /api/status/full of %s: %s" % (ip, type(e).__name__)); sys.exit(0)
print(j.get("version"), j.get("uptime_seconds"), j.get("free_heap"), j.get("min_free_heap"), int(time.time()))
PYEOF
}

b_dev() {
  local ip="${1:-}" want="${2:-}" mode="${3:-}" v up fh mh now out pre preboot boot
  case "$ip" in 192.168.120.173|192.168.120.189|192.168.120.170) ;; *) fail "usage: dev <192.168.120.173 | 192.168.120.189 | 192.168.120.170> <before | v7.7.1.3> [c3heap | floor]: this step reads no other board" ;; esac
  [[ "$want" =~ ^(v7\.7\.1\.3|before)$ ]] || fail "usage: dev <IP> <before | v7.7.1.3> [c3heap | floor]"
  case "$mode" in "") ;; c3heap) [ "$ip" = "192.168.120.189" ] && [ "$want" = "v7.7.1.3" ] || fail "c3heap applies to 192.168.120.189 on v7.7.1.3 only" ;;
    floor) [ "$ip" = "192.168.120.170" ] || fail "floor applies to 192.168.120.170 only" ;; *) fail "usage: dev <IP> <before | v7.7.1.3> [c3heap | floor]" ;; esac
  out="$(status_full "$ip" 2>&1)"
  [[ "$out" != ERROR* ]] || fail "${out#ERROR }"
  read -r v up fh mh now <<< "$out"
  [[ "$up" =~ ^[0-9]+$ ]] && [[ "$fh" =~ ^[0-9]+$ ]] && [[ "$mh" =~ ^[0-9]+$ ]] && [[ "$now" =~ ^[0-9]+$ ]] || fail "unexpected answer of $ip: $(head -c 200 <<< "$out")"
  boot=$((now - up))
  echo "dev $ip: version $v, uptime $up s, free_heap $fh B, min_free_heap $mh B, boot $boot"
  if [ "$want" = "before" ]; then   # the reading just before an upload: the board runs v7.7.1.2, or v7.7.1.3 when Task Group 6 runs again
    [[ "$v" =~ ^v7\.7\.1\.[23]$ ]] || fail "$ip reports $v, not v7.7.1.2 or v7.7.1.3"
  else
    test "$v" = "$want" || fail "$ip reports $v, not $want"
  fi
  if [ "$ip" = "192.168.120.170" ]; then   # PLAN-046: every reading of .170, before and after the upload
    [ "$mh" -ge 1024 ] || fail "min_free_heap of .170 is $mh B, below the floor of 1,024 B (PLAN-046): STOP and report"
  fi
  if [ "$want" = "v7.7.1.3" ]; then   # the board started again since the reading before the upload: the upload happened
    test -f "$SAVE/dev-$ip-before.txt" || fail "no reading before the upload: run dev $ip before, before the upload (Task Group 6)"
    read -r pre _ preboot _ < "$SAVE/dev-$ip-before.txt"
    [[ "$pre" =~ ^[0-9]+$ ]] && [[ "$preboot" =~ ^[0-9]+$ ]] || fail "the saved reading before the upload is unreadable"
    [ "$preboot" -lt $((boot - 30)) ] || fail "$ip has not started again since 'dev $ip before' (boot $boot, before $preboot): the upload did not happen, or the reading before it belongs to this boot. STOP and report"
  fi
  mkdir -p "$SAVE" && printf '%s %s %s %s\n' "$fh" "$mh" "$boot" "$now" > "$SAVE/dev-$ip-$want.txt" || fail "cannot write $SAVE/dev-$ip-$want.txt"
  if [ "$mode" = "c3heap" ]; then # PLAN-046: at an uptime of 180 s or more, the higher of two readings 30 s apart, against the reading before the upload
    local hi=0 k
    if [ "$up" -lt 180 ]; then echo "c3heap: the uptime is $up s; waiting $((180 - up)) s until 180 s"; sleep $((180 - up)); fi
    for k in 1 2; do
      [ "$k" = "1" ] || sleep 30
      out="$(status_full "$ip" 2>&1)"
      [[ "$out" != ERROR* ]] || fail "c3heap reading $k: ${out#ERROR }"
      read -r v up fh mh now <<< "$out"
      [[ "$up" =~ ^[0-9]+$ ]] && [[ "$fh" =~ ^[0-9]+$ ]] && [[ "$now" =~ ^[0-9]+$ ]] || fail "c3heap reading $k: unexpected answer of $ip: $(head -c 200 <<< "$out")"
      [ $((now - up)) -ge $((boot - 30)) ] && [ $((now - up)) -le $((boot + 30)) ] || fail "c3heap reading $k: the board started at $((now - up)), not within 30 s of $boot: it rebooted. STOP and report"
      echo "c3heap reading $k: uptime $up s, free_heap $fh B, min_free_heap $mh B"
      [ "$fh" -gt "$hi" ] && hi="$fh"
    done
    [ "$hi" -ge $((pre - 2048)) ] || fail "the higher free_heap, $hi B, is more than 2,048 B below $pre B, the reading before the upload (PLAN-046): STOP and report"
    echo "c3heap: the higher free_heap is $hi B; before the upload $pre B; no more than 2,048 B below it"
  fi
  echo "dev PASS"
}

storage_stats() { # $1 IP $2 out file: /api/storage-stats (public)
  python3 -I - "$1" "$2" <<'PYEOF'
import json, sys, urllib.request
try:
    with urllib.request.urlopen("http://%s/api/storage-stats" % sys.argv[1], timeout=15) as r:
        j = json.load(r)
except Exception as e:
    print("ERROR cannot read /api/storage-stats of %s: %s" % (sys.argv[1], type(e).__name__)); sys.exit(0)
json.dump(j, open(sys.argv[2], "w"))
print("OK")
PYEOF
}

b_v2() { # v2 <IP> before | v2 <IP> | v2 <IP> later: before the upload, after a persist cycle (6.1 to 6.4), the 24-hour reading (6.5)
  local ip="${1:-}" mode="${2:-}" out v up fh mh now boot
  case "$ip" in 192.168.120.173|192.168.120.189|192.168.120.170) ;; *) fail "usage: v2 <192.168.120.173 | 192.168.120.189 | 192.168.120.170> [before | later]" ;; esac
  [ -z "$mode" ] || [ "$mode" = "before" ] || [ "$mode" = "later" ] || fail "usage: v2 <IP> [before | later]"
  out="$(status_full "$ip" 2>&1)"
  [[ "$out" != ERROR* ]] || fail "${out#ERROR }"
  read -r v up fh mh now <<< "$out"
  [[ "$up" =~ ^[0-9]+$ ]] && [[ "$mh" =~ ^[0-9]+$ ]] && [[ "$now" =~ ^[0-9]+$ ]] || fail "unexpected answer of $ip: $(head -c 200 <<< "$out")"
  boot=$((now - up))
  if [ "$ip" = "192.168.120.170" ]; then   # PLAN-046: every reading of .170, before and after the upload
    [ "$mh" -ge 1024 ] || fail "min_free_heap of .170 is $mh B, below the floor of 1,024 B (PLAN-046): STOP and report"
  fi
  out="$(storage_stats "$ip" "$TMP/ss.json" 2>&1)"
  [ "$out" = "OK" ] || fail "${out#ERROR }"
  if [ "$mode" = "before" ]; then
    [[ "$v" =~ ^v7\.7\.1\.[23]$ ]] || fail "$ip reports $v, not v7.7.1.2 or v7.7.1.3"
    out="$(python3 -I - "$TMP/ss.json" <<'PYEOF'
import json, sys
j = json.load(open(sys.argv[1]))
n, h, lay = j.get("nvs_stats", {}), j.get("history", {}), j.get("layout", {})
if lay.get("history_bytes") != 524288 or not n.get("available"):
    print("ERROR the board has no history partition in use (history_bytes %s, nvs_stats available %s): STOP and report; for .173 the operator's USB flash of 'Before you start' is missing" % (lay.get("history_bytes"), n.get("available")))
else:
    # the ring of each device before the upload: -1 where it is not known (no persist_v2, or no cycle since the boot)
    pv = {d.get("id"): d for d in ((j.get("persist_v2") or {}).get("devices") or [])}
    # known only from a cycle that loaded the device's meta (ok or dedup); EMPTY, an error or pending leave it unknown (re-audit 2, M03)
    rings = [pv[i].get("valid_segments", -1) if i in pv and pv[i].get("result") in ("ok", "dedup") else -1 for i in ("office", "first_floor", "outside", "wan_ping")]
    print(n.get("used_entries"), n.get("free_entries"), h.get("valid_segments"), h.get("last_persist_epoch"), " ".join(str(int(x)) for x in rings))
PYEOF
)"
    [[ "$out" != ERROR* ]] || fail "${out#ERROR }"
    read -r a b c d r1 r2 r3 r4 <<< "$out"
    mkdir -p "$SAVE" && echo "$a $b $c $d $boot $r1 $r2 $r3 $r4" > "$SAVE/v2-$ip.txt" && rm -f "$SAVE/v2-$ip-pass.txt" "$SAVE/r24-v2-$ip.txt" || fail "cannot write $SAVE/v2-$ip.txt"
    echo "v2 $ip before: version $v, used_entries $a, free_entries $b, old engine segments $c, last_persist_epoch $d, boot $boot, rings $r1 $r2 $r3 $r4 (-1: not known)"
    echo "v2 PASS (before)"
    return
  fi
  test "$v" = "v7.7.1.3" || fail "$ip reports $v, not v7.7.1.3"
  test -f "$SAVE/v2-$ip.txt" || fail "no reading before the upload: v2 $ip before belongs before the upload (Task Group 6)"
  out="$(python3 -I - "$TMP/ss.json" "$SAVE/v2-$ip.txt" "$ip" "$up" "$boot" "$SAVE/v2-$ip-pass.txt" "$now" "${mode:-cycle}" <<'PYEOF'
import json, os, re, sys
j = json.load(open(sys.argv[1]))
saved = open(sys.argv[2]).read().split()
if len(saved) != 9 or not all(re.fullmatch(r"-?[0-9]+", x) for x in saved):
    print("ERROR the saved reading of 'v2 %s before' is unreadable: run it again before the next upload" % sys.argv[3]); sys.exit()
used0, free0, seg0, last0, boot0 = [int(x) for x in saved[:5]]
rings0 = [int(x) for x in saved[5:9]]
ip, up, boot, passfile, now, mode = sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), sys.argv[6], int(sys.argv[7]), sys.argv[8]
# The persist cycle runs at minute 10 of each hour (the boards' time zone has whole-hour offsets, so it is minute 10 of the
# UTC hour too); a sample comes every 15 minutes. CYCLE is the latest cycle that has ended: 180 s after minute 10, a grace
# for the boards' SNTP clock against this host's clock (internal round 3, L1). A writer that ran in it persisted a point of
# this boot (the RAM of points before the boot is restored, not new) of at most 25 minutes before it: one sample may be
# missing (re-audit 2, H01).
base = now - 180
CYCLE = base - base % 3600 + 600
CYCLE = CYCLE if CYCLE <= base else CYCLE - 3600
SINCE = max(CYCLE - 1500, boot)
def recent(epoch):
    return SINCE <= (epoch or 0) <= now + 300
if not boot0 < boot - 30:
    print("ERROR %s has not started again since 'v2 %s before' (boot %d, before %d): the upload did not happen. STOP and report" % (ip, ip, boot, boot0)); sys.exit()
pf = open(passfile).read().split() if os.path.isfile(passfile) else None   # the first v2 PASS of this upload, if one is kept
if pf and abs(boot - int(pf[0])) > 30:   # before any WAIT (internal round 3, M1)
    print("ERROR %s started at %d, not within 30 s of %s, the boot of the first v2 PASS: it rebooted after the upload. STOP and report" % (ip, boot, pf[0])); sys.exit()
if mode == "later" and not pf:   # 6.5 compares with the first v2 PASS of 6.4 on this boot (re-audit 2, H02)
    print("ERROR no first v2 PASS of this boot is kept: the 24-hour reading needs the v2 PASS of 6.4 after the same upload. STOP and report"); sys.exit()
if mode == "later" and up < 86400:
    print("WAIT the uptime is %d s, below 86,400 s: 24 hours have not passed since the upload; run this block again later" % up); sys.exit()
first = up < 4500   # the first persist cycle after the boot comes within 3,600 s and may have no new point: the boot fell between minute 0 and minute 10
def fnv(s):
    h = 0x811c9dc5
    for c in s.encode():
        h = ((h ^ c) * 0x01000193) & 0xffffffff
    return "dm_%08x" % h
p = j.get("persist_v2")
if not isinstance(p, dict):
    print("ERROR /api/storage-stats has no object persist_v2"); sys.exit()
devs = p.get("devices") or []
ids = [d.get("id") for d in devs]
want = ["office", "first_floor", "outside", "wan_ping"]
if p.get("slots") != 24 or p.get("min_free_entries") != 252 or ids != want:
    print("ERROR persist_v2: slots %s (24), min_free_entries %s (252), devices %s (%s)" % (p.get("slots"), p.get("min_free_entries"), ids, want)); sys.exit()
lines = []
for d in devs:
    lines.append("v2 %s %s: %s, meta_key %s, valid_segments %s, next_slot %s, last_persist_epoch %s, writes ok %s skipped %s failed %s" % (
        ip, d.get("id"), d.get("result"), d.get("meta_key"), d.get("valid_segments"), d.get("next_slot"), d.get("last_persist_epoch"),
        d.get("writes_ok"), d.get("writes_skipped"), d.get("writes_failed")))
n, h = j.get("nvs_stats", {}), j.get("history", {})
used, last = n.get("used_entries", 0), h.get("last_persist_epoch", 0)
lines.append("v2 %s nvs: used_entries %s (before %d), free_entries %s, old engine segments %s, last_persist_epoch %s (before %d, %s s ago), uptime %d s" % (ip, used, used0, n.get("free_entries"), h.get("valid_segments"), last, last0, now - (last or 0), up))
print("\n".join(lines))
bad = [d["id"] for d in devs if d.get("meta_key") != fnv(d["id"])]
if bad:
    print("ERROR the meta_key of %s is not dm_ and the FNV-1a hash of its id" % bad); sys.exit()
if all(d.get("result") == "pending" for d in devs):
    if first:
        print("WAIT no persist cycle since the boot; it runs at minute 10 of the hour: run this block again a few minutes after it"); sys.exit()
    print("ERROR no persist cycle has run in %d s since the boot; one runs every hour at minute 10: STOP and report" % up); sys.exit()
bad = [d["id"] for d in devs if d.get("result") not in ("ok", "dedup", "empty", "pending") or (d.get("writes_failed") or 0) > 0]
if bad:
    print("ERROR the result of %s is not ok, dedup, empty or pending (missing, collision, error, nvs_low or unknown), or writes_failed is above 0: STOP and report" % bad); sys.exit()
good = [d for d in devs if d.get("result") in ("ok", "dedup") and (d.get("writes_ok") or 0) >= 1]
fresh = [d for d in good if recent(d.get("last_persist_epoch"))]   # the device persisted a point of this boot in the latest cycle
old_fresh = recent(last)
if first and (len(good) < 3 or not last > last0 or len(fresh) < 3 or not old_fresh):
    print("WAIT the first cycle after the boot (uptime %d s) had no new point: run this block again after minute 10 of the next hour" % up); sys.exit()
if len(good) < 3:
    print("ERROR %d devices have the result ok or dedup with writes_ok 1 or more; at least 3 must" % len(good)); sys.exit()
slots = p.get("slots", 24)
# a ring that grew since 'v2 before': not full now, or full now and not full before (its last free slot); a full ring overwrites: no new entries
growing = [d for d, r0 in zip(devs, rings0) if d in good and ((d.get("valid_segments") or 0) < slots or (0 <= r0 < slots))]
if growing and used - used0 < 7 * len(growing):
    print("ERROR used_entries grew by %d since 'v2 %s before', less than 7 for each of the %d devices whose ring grew" % (used - used0, ip, len(growing))); sys.exit()
if not last > last0:
    print("ERROR the old engine did not write since the upload: its last_persist_epoch is %s, before %d" % (last, last0)); sys.exit()
if not old_fresh:
    print("ERROR the old engine's newest persisted point, %s, is not a point of this boot between %d and %d (the cycle at %d): it did not write in the latest cycle, or the point is in the future. STOP and report" % (last, SINCE, now + 120, CYCLE)); sys.exit()
if len(fresh) < 3:
    print("ERROR %d devices persisted a point of this boot between %d and %d (the cycle at %d); at least 3 must: a writer did not write in the latest cycle. STOP and report" % (len(fresh), SINCE, now + 120, CYCLE)); sys.exit()
ok = [d.get("writes_ok") or 0 for d in devs]
if pf:   # the first v2 PASS of this boot is kept; a later reading shows progress since it
    pup, plast = int(pf[1]), int(pf[2])
    pok, pnow = [int(x) for x in pf[3:7]], int(pf[7])
    if CYCLE <= pnow:   # no persist cycle has ended since the first v2 PASS
        if mode == "later":
            print("WAIT no persist cycle since the first v2 PASS (at %d): run this block again a few minutes after minute 10 of the next hour" % pnow); sys.exit()
    else:
        grew = [d["id"] for d, a, b in zip(devs, ok, pok) if a > b]
        print("v2 %s since the first v2 PASS (uptime %d s): old engine last_persist_epoch %d -> %s; writes_ok grew for %s" % (ip, pup, plast, last, grew or "no device"))
        if not last > plast:
            print("ERROR the old engine did not write since the first v2 PASS: STOP and report"); sys.exit()
        if len(grew) < 3:
            print("ERROR writes_ok grew for %d devices since the first v2 PASS; at least 3 must: STOP and report" % len(grew)); sys.exit()
else:
    open(passfile, "w").write("%d %d %d %s %d\n" % (boot, up, last, " ".join(str(x) for x in ok), now))
if mode == "later":   # the evidence line of 6.5: the board, its boot and the progress since the first v2 PASS
    print("PASS since the first v2 PASS at %d: old engine last_persist_epoch %d -> %s, writes_ok grew for %s" % (pnow, plast, last, ", ".join(grew)))
else:
    print("PASS")
PYEOF
)"
  grep -v '^ERROR\|^WAIT\|^PASS' <<< "$out"
  if grep -q '^WAIT' <<< "$out"; then echo "v2 $(grep '^WAIT' <<< "$out")"; return; fi
  grep -q '^ERROR' <<< "$out" && fail "$(grep '^ERROR' <<< "$out" | head -n 1 | sed 's/^ERROR //')"
  [ "$ip" != "192.168.120.170" ] || echo "v2 $ip heap: free_heap $fh B, min_free_heap $mh B, uptime $up s"
  if [ "$mode" = "later" ]; then
    [[ "$(tail -n 1 <<< "$out")" == "PASS since "* ]] || fail "unexpected output of the check"
    out="v2 $ip PASS (later): boot $boot, uptime $up s, free_heap $fh B, min_free_heap $mh B, $(tail -n 1 <<< "$out" | sed 's/^PASS //')"
    printf '%s\n' "$out" > "$SAVE/r24-v2-$ip.txt" || fail "cannot write $SAVE/r24-v2-$ip.txt"
    echo "$out"
  else
    [ "$(tail -n 1 <<< "$out")" = "PASS" ] || fail "unexpected output of the check"
    echo "v2 PASS"
  fi
}

b_wroom24() { # wroom24 <boot epoch of the dev line of .170 after the upload>
  local boot="${1:-}" v up fh mh now out b
  [[ "$boot" =~ ^[0-9]{9,}$ ]] || fail "usage: wroom24 <epoch>: the number after 'boot' in the dev line of .170 after the upload"
  out="$(status_full 192.168.120.170 2>&1)"
  [[ "$out" != ERROR* ]] || fail "${out#ERROR }"
  read -r v up fh mh now <<< "$out"
  [[ "$up" =~ ^[0-9]+$ ]] && [[ "$mh" =~ ^[0-9]+$ ]] && [[ "$now" =~ ^[0-9]+$ ]] || fail "unexpected answer of .170: $(head -c 200 <<< "$out")"
  b=$((now - up))
  echo "wroom24 192.168.120.170: version $v, uptime $up s, free_heap $fh B, min_free_heap $mh B, boot $b"
  test "$v" = "v7.7.1.3" || fail ".170 reports $v, not v7.7.1.3"
  [ "$b" -ge $((boot - 30)) ] && [ "$b" -le $((boot + 30)) ] || fail "the board started at $b, not within 30 s of $boot: it rebooted after the upload. STOP and report"
  [ "$mh" -ge 1024 ] || fail "min_free_heap of .170 is $mh B, below the floor of 1,024 B (PLAN-046): STOP and report"
  if [ "$up" -lt 86400 ]; then echo "wroom24 WAIT: the uptime is $up s, below 86,400 s: 24 hours have not passed; run the block again later"; return; fi
  out="wroom24 PASS: 192.168.120.170, boot $b, uptime $up s, min_free_heap $mh B"
  mkdir -p "$SAVE" && printf '%s\n' "$out" > "$SAVE/r24-wroom24.txt" || fail "cannot write $SAVE/r24-wroom24.txt"
  echo "$out"
}

b_F() {
  local log rec pr x
  log="$(new_paths | grep '^Docs/')" && rec="$(new_paths | grep '^prompts/')" || fail "run the block scope first"
  pr="$(sed -E 's/.*-PR([0-9]+)-.*/\1/' <<< "$rec")"
  grep -q '^- \*\*Current version:\*\* 7\.7\.1\.3$' "$CS" || fail "7.1 $CS: '- **Current version:** 7.7.1.3'"
  sed -n 3p "$CS" | grep -q '^_Last verified: 20[0-9-]* .*v7\.7\.1\.3' || fail "7.1 $CS line 3: '_Last verified: <date> ...' naming v7.7.1.3"
  grep -q "^| v7\.7\.1\.3 | #$pr |" "$CS" || fail "7.1 $CS: a row '| v7.7.1.3 | #$pr |' in What Just Shipped"
  sed -n 4p "$CS" | grep -q 'v7\.7\.1\.4' && [ "$(sed -n 4p "$CS")" != "$(git show origin/main:"$CS" | sed -n 4p)" ] || fail "7.1 $CS line 4: a new next action that names v7.7.1.4"
  test "$(grep -E '^\| (esp32-c3-multi|sat-esp32-4m-170|sat-s3-4m-173) \|' "$CS" | grep -c 'v7\.7\.1\.3')" = "3" || fail "7.1 $CS: firmware_now of .173, .189 and .170 is v7.7.1.3"
  grep -E '^\| sat-s3-4m-173 \|' "$CS" | grep -qi 'partition table' || fail "7.1 $CS: the row of .173 notes the USB flash with the project's partition table"
  [ "$(grep '^| WROOM heap |' "$CS")" != "$(git show origin/main:"$CS" | grep '^| WROOM heap |')" ] || fail "7.1 $CS: the row 'WROOM heap' must hold the readings of v7.7.1.3"
  grep -E '^_Observed on 20[0-9-]+ on \.189, before and after the upload of v7\.7\.1\.3 \(PLAN-046\); before the upload it ran v7\.7\.1\.[23]\. The May 2026 baseline of 52,080 B no longer applies\._$' "$CS" > /dev/null || fail "7.1 $CS: the italic line of 'Phase 7 Device Validation Snapshot', as item 7.1 gives it"
  grep -qF '| Metric | Before the upload | v7.7.1.3 (c3heap, the higher reading) | Delta |' "$CS" || fail "7.1 $CS: the columns of the snapshot table"
  sed -n '/^## Phase 7 Device Validation Snapshot/,/^## /p' "$CS" > "$TMP/snap.txt"
  local NUM='[0-9]{1,3}(,[0-9]{3})*'   # a number with thousands commas (re-audit 2, L01)
  for x in free_heap min_free_heap; do
    test "$(grep -cE "^\| \`$x\` \| $NUM B \| $NUM B \| ([+-]$NUM|0) B \|$" "$TMP/snap.txt")" = "1" || fail "7.1 $CS: the snapshot row of $x, as item 7.1 gives its form (thousands commas; the delta with its sign)"
  done
  grep -qF '1. **Produce the v7.7.1.4 bundle, then R7**' "$CS" && ! grep -qF 'Produce the v7.7.1.3 bundle' "$CS" || fail "7.1 $CS: item 1 of What's Next names the v7.7.1.4 bundle and R7"
  grep -F '| Operator decision 2026-11-24 (PLAN-047) | C6 test board .184' "$P" | head -n 1 > "$TMP/c6.txt"
  test -s "$TMP/c6.txt" && test "$(grep -cxFf "$TMP/c6.txt" "$CS")" = "1" || fail "7.1 $CS: the row of the C6 test board in Unimplemented Recommendations, as item 7.1 gives it"
  grep '^| PR #246 review A Q3' "$CS" | grep -q 'Implemented in v7.7.1.3' && grep '^| PR #246 review A Q3' "$CS" | grep -q 'Decided' || fail "7.1 $CS: the row of PR #246 review A Q3–Q5 (Implemented in v7.7.1.3; Decided)"
  grep '^| PR #246 c3heap stop' "$CS" | grep -q 'Implemented in v7.7.1.3' || fail "7.1 $CS: the row of the c3heap stop"
  grep -F '| Restart check 2026-11 | Firmware `.bin` size checkpoint' "$CS" | grep -q 'Implemented in v7.7.1.3' || fail "7.1 $CS: the row of the .bin size checkpoint"
  grep '^| 9 | R6 |' "$POR" | grep -q "Done.*#$pr" || fail "7.2 $POR: row 9 says Done with #$pr"
  test "$(grep -c '^## \[v7\.7\.1\.3\]' "$CL")" = "1" || fail "7.3 $CL: one heading '## [v7.7.1.3]'"
  [ "$(grep -n '^## \[v7\.7\.1\.3\]' "$CL" | cut -d: -f1)" -lt "$(grep -n '^## \[v7\.7\.1\.2' "$CL" | head -n 1 | cut -d: -f1)" ] || fail "7.3 $CL: the entry of v7.7.1.3 comes before the one of v7.7.1.2"
  sed -n '/^## \[v7\.7\.1\.3\]/,/^## \[v7\.7\.1\.2/p' "$CL" > "$TMP/entry.txt"
  for x in $FUNCS DeviceSegment persist_v2 24 252 "$NEWMAC" "no read path yet" PLAN-046 PLAN-047 PLAN-048; do
    grep -qF -- "$x" "$TMP/entry.txt" || fail "7.3 the changelog entry does not name $x"
  done
  python3 -I - "$P" "$TMP/n7.txt" "$TMP/n10.txt" <<'PYEOF' || fail "7.4 fenced texts"
import sys
l = open(sys.argv[1], encoding="utf-8").read().split("\n")
i = [k for k, x in enumerate(l) if x.startswith("**7.4** ")][0]
f = [k for k in range(i, len(l)) if l[k].startswith("```")]
open(sys.argv[2], "w", encoding="utf-8").write(l[f[0] + 1] + "\n")
open(sys.argv[3], "w", encoding="utf-8").write(l[f[2] + 1] + "\n")
PYEOF
  for x in "## 7. Retention Budgeting|n7" "## 10. Persist Flow|n10"; do
    test "$(awk -v h="${x%|*}" '$0 == h { getline a; getline b; print a "|" b; exit }' "$ARCH")" = "$(head -n 1 "$TMP/${x#*|}.txt")|" \
      || fail "7.4 $ARCH: the note right after '${x%|*}', then one empty line"
  done
  test -f "$log" || fail "7.5 $log is missing"
  for x in 'RAM:' 'Flash:' 'host PASS' 'dev 192.168.120.173: version v7.7.1.3' 'dev 192.168.120.189: version v7.7.1.3' 'dev 192.168.120.170: version v7.7.1.3' 'v2 PASS' 'image: '; do
    grep -qF -- "$x" "$log" || fail "7.5 $log has no line with '$x'"
  done
  test -f "$rec" || fail "7.6 $rec is missing"
  python3 -I - "$rec" "$CS" <<'PYEOF' || fail "7.6 the record (see the line above)"
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
cs = open(sys.argv[2], encoding="utf-8").read()
sec = cs.split("\n## Unimplemented Recommendations", 1)[1].split("\n## ", 1)[0] if "\n## Unimplemented Recommendations" in cs else ""
rows = {l.strip().strip("|").split("|")[0].strip() for l in sec.split("\n") if l.startswith("| ")}
for name in re.findall(r'CURRENT-STATE\.md, row "([^"\n]+)"', t):   # each routed recommendation names a row that exists (re-audit 2, L03)
    if name.strip() not in rows:
        sys.exit('the record routes a recommendation to CURRENT-STATE.md, row "%s", which is no row of Unimplemented Recommendations' % name[:80])
heads = re.findall(r"(?m)^## (§[1-7]) ", t)
if heads != ["§1", "§2", "§3", "§4", "§5", "§6", "§7"]:
    sys.exit("the record needs the headings ## §1 to ## §7 of the template, each once, in order; found " + " ".join(heads))
for m in ("Producer sessions for this step's prompt", "Audit sessions for this step's prompt",
          "Fix-cycle commits after the first review round", "Defects that escaped the prompt gates into agent execution",
          "Defects that escaped to devices"):
    rows = [l for l in t.split("\n") if l.lower().startswith("| " + m.lower())]
    if len(rows) != 1 or len([c for c in rows[0].strip().strip("|").split("|")]) < 2 or not rows[0].strip().strip("|").split("|")[1].strip():
        sys.exit("one row with a value for the metric '%s'" % m)
if "[NN]" in t or "v7.7.X.Y" in t:
    sys.exit("a fill-in of the template is left: [NN] or v7.7.X.Y")
PYEOF
  echo "CHECKPOINT F PASS"
}

b_prepr() {
  local base rc n
  local -a f
  git fetch -q origin || fail "git fetch"
  python3 scripts/scope-gate.py --allowed "$(scope_list)" --target origin/main \
    || { rc=$?; echo "PRE-PR GATE FAILED (scope-gate exit $rc) - STOP"; exit "$rc"; }
  test -z "$(git status --porcelain)" || fail "uncommitted changes: commit before this gate"
  base="$(git merge-base origin/main HEAD)" || fail "merge-base"
  test "$(git diff --name-status --no-renames "$base" HEAD | grep -vc '^[MA]')" = "0" || fail "a file was deleted or changed its type"
  test "$(ls firmware/core/*.h | wc -l)" = "9" || fail "the number of fragments is not 9"
  cmp -s "$P" "$SAVE/v7.7.1.3-agent-prompt-gpt-codex.md" || fail "the prompt differs from the saved one"
  cmp -s "$CF" "$SAVE/v7.7.1.3-checks.sh" || fail "the check file differs from the saved one"
  ( b_copy verify ) || exit 1
  ( b_A ) || exit 1
  ( b_B ) || exit 1
  ( b_host ) || exit 1
  ( b_C ) || exit 1
  ( b_D ) || exit 1
  ( b_E noimage ) || exit 1
  ( b_F ) || exit 1
  mapfile -t f < <(git diff --name-only --no-renames --diff-filter=d "$base" HEAD)
  bash scripts/lint-prompts.sh --baseline origin/main "${f[@]}" > "$TMP/lint.log" 2>&1; rc=$?
  n="$(grep -v '^EXISTING' "$TMP/lint.log" | grep -c 'L11')"
  test "$n" = "0" || fail "rule L11 finds a new login literal in a changed file ($n lines)"
  test "$rc" = "0" || fail "lint of the changed files ended with exit $rc: $(grep -m2 -E 'ERROR|L[0-9]+' "$TMP/lint.log" | tr '\n' '|')"
  bash scripts/preflight.sh || fail "preflight"
  test -z "$(git status --porcelain)" || fail "preflight changed files in the tree: $(git status --porcelain | tr '\n' ' ')"
  echo "PRE-PR PASS at $(git rev-parse HEAD)"
}
# --- review round: the blocks inline and body (PLAN-043; F2 of review A on PR #244 fixed in R5b, PLAN-044;
#     Copilot and Gemini only, PLAN-045; body final names the head, PLAN-046) ---
# They read the PR through `gh api` and change nothing. GHREPO, ROUNDS, CHECKS, CRITERIA and CLOSING are set at the top of the file.
# body: R6 after GPT Astra's audit and re-audit (PLAN-047): each required job by its exact name, its latest run in success;
# a filled review row needs a posted review that begins with its heading and names the commit of the row; body final also
# needs each criterion of section 7 of the prompt once, ticked, and the closing line.

b_inline() { # inline <PR#>: waits for Copilot and Gemini, at most 5 minutes per run and 30 minutes in all; names a post of Codex
  local pr="${1:-}" t0 now out rc
  [[ "$pr" =~ ^[0-9]+$ ]] || fail "usage: inline <PR#>"
  t0="$(date -u +%s)" || fail "date"
  while :; do
    gh api "repos/$GHREPO/pulls/$pr" > "$TMP/pull.json" 2> "$TMP/gh.err" \
      && gh api "repos/$GHREPO/pulls/$pr/reviews?per_page=100" > "$TMP/reviews.json" 2>> "$TMP/gh.err" \
      && gh api "repos/$GHREPO/issues/$pr/comments?per_page=100" > "$TMP/comments.json" 2>> "$TMP/gh.err" \
      || fail "gh api cannot read PR #$pr: $(head -c 200 "$TMP/gh.err" | tr '\n' ' ')"
    now="$(date -u +%s)" || fail "date"
    out="$(python3 -I - "$TMP" "$now" <<'PYEOF'
import json, re, sys
from datetime import datetime, timezone
d, now = sys.argv[1], int(sys.argv[2])
pull = json.load(open(d + "/pull.json", encoding="utf-8"))
reviews = json.load(open(d + "/reviews.json", encoding="utf-8"))
comments = json.load(open(d + "/comments.json", encoding="utf-8"))
def t(s):
    return int(datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())
def who(x):
    return (x.get("user") or {}).get("login", "")
if pull.get("draft"):
    print("the PR is still a draft: run gh pr ready first"); sys.exit(2)
starts = [t(c["created_at"]) for c in comments if (c.get("body") or "").strip() == "/gemini review"]
if not starts:
    print("no comment '/gemini review' on the PR: post it first"); sys.exit(2)
if len(reviews) >= 100 or len(comments) >= 100:
    print("the PR has 100 or more reviews or comments: this block reads only the first 100"); sys.exit(2)
start, head = max(starts), pull["head"]["sha"]
posted = {}
def seen(name, commit, when, text):
    # A review of the head counts. A review of another commit counts as history when it came before
    # '/gemini review' and stops the block when it came after it: then a commit was pushed during the round.
    if commit and not head.startswith(commit):
        if when < start or name == "Codex":  # Codex is not waited for (PLAN-045): a post of another commit is skipped
            return
        print("%s reviewed %s, not the head %s: a commit was pushed during the inline round" % (name, commit, head)); sys.exit(2)
    posted.setdefault(name, text)
for r in reviews:
    if r.get("state") == "PENDING" or not r.get("submitted_at"):
        continue
    name = {"gemini-code-assist[bot]": "Gemini", "copilot-pull-request-reviewer[bot]": "Copilot",
            "chatgpt-codex-connector[bot]": "Codex"}.get(who(r))
    if not name or (name == "Gemini" and t(r["submitted_at"]) < start):
        continue
    note = " (incomplete: Copilot could not complete its review, PLAN-032)" if name == "Copilot" and "unable to complete" in (r.get("body") or "") else ""
    seen(name, r.get("commit_id") or "", t(r["submitted_at"]), "%s: review %s on %s%s" % (name, r["id"], (r.get("commit_id") or "")[:7], note))
for c in comments:
    b = c.get("body") or ""
    if who(c) != "chatgpt-codex-connector[bot]":
        continue
    if "<!-- codex-review-receipt" in b:
        m = re.search(r"Reviewed commit:\*\* `([0-9a-f]{7,40})`", b)
        seen("Codex", m.group(1) if m else "", t(c["created_at"]), "Codex: receipt comment %s" % c["id"])
    m = re.search(r"<!-- codex-review-state:v1 (\{.*?\}) -->", b)
    if m:
        try:
            cr = json.loads(m.group(1)).get("code_review") or {}
        except ValueError:
            cr = {}
        if cr.get("status") == "completed" and cr.get("commit_sha") and head.startswith(cr["commit_sha"]):
            # the status comment counts on the head only and never stops the block: Codex edits it in place
            posted.setdefault("Codex", "Codex: status comment %s, completed on %s" % (c["id"], cr["commit_sha"][:7]))
for n in ("Copilot", "Gemini"):
    print(posted.get(n, "%s: not posted" % n))
print(posted.get("Codex", "Codex: not posted (no longer asked, PLAN-045)"))
need = [n for n in ("Copilot", "Gemini") if n in posted]
left = 30 - (now - start) // 60
if len(need) == 2:
    sys.exit(0)
if left <= 0:
    print("30 minutes have passed since '/gemini review'; the reviewers that did not post are named above"); sys.exit(0)
print("%d of 2 posted; %d minutes left" % (len(need), left)); sys.exit(3)
PYEOF
)"; rc=$?
    case "$rc" in
      0) echo "$out"; echo "inline PASS"; return 0 ;;
      3) if [ $((now - t0)) -ge 300 ]; then echo "$out"; echo "inline WAIT: run this block again"; return 0; fi
         echo "inline: waiting, $(tail -n 1 <<< "$out")"
         sleep 30 ;;
      *) fail "$out" ;;
    esac
  done
}

b_body() { # body <PR#> [final]: the PR body after a round, or before the merge
  local pr="${1:-}" mode="${2:-}" out head
  [[ "$pr" =~ ^[0-9]+$ ]] || fail "usage: body <PR#> [final]"
  [ -z "$mode" ] || [ "$mode" = "final" ] || fail "usage: body <PR#> [final]"
  gh api "repos/$GHREPO/pulls/$pr" > "$TMP/pull.json" 2> "$TMP/gh.err" \
    && gh api "repos/$GHREPO/issues/$pr/comments?per_page=100" > "$TMP/comments.json" 2>> "$TMP/gh.err" \
    || fail "gh api cannot read PR #$pr: $(head -c 200 "$TMP/gh.err" | tr '\n' ' ')"
  echo '{"check_runs": []}' > "$TMP/checks.json"
  : > "$TMP/r24.txt"; : > "$TMP/log.md"; : > "$TMP/rec.md"
  if [ "$mode" = "final" ]; then
    local log rec x
    head="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["head"]["sha"])' "$TMP/pull.json")" || fail "the head of PR #$pr"
    gh api "repos/$GHREPO/commits/$head/check-runs?per_page=100" > "$TMP/checks.json" 2>> "$TMP/gh.err" \
      || fail "gh api cannot read the check runs of $head: $(head -c 200 "$TMP/gh.err" | tr '\n' ' ')"
    # the 24-hour readings of 6.5 (re-audit 2, H03): the PASS lines that the blocks saved, in the body, the session log and the record at the head
    log="$(new_paths | grep '^Docs/')" && rec="$(new_paths | grep '^prompts/')" || fail "run the block scope first"
    git cat-file -e "$head^{commit}" 2> /dev/null || fail "the head $head is not in this clone: git fetch origin, then run this block again"
    git show "$head:$log" > "$TMP/log.md" 2> /dev/null || fail "the head $head has no session log $log"
    git show "$head:$rec" > "$TMP/rec.md" 2> /dev/null || fail "the head $head has no record $rec"
    for x in ${EVIDENCE//|/ }; do
      test -s "$SAVE/$x" || fail "$SAVE/$x is missing: run the 24-hour readings of item 6.5 (wroom24, then v2 <IP> later for .170 and .189) on this upload first"
      head -n 1 "$SAVE/$x" >> "$TMP/r24.txt"
    done
    for x in 192.168.120.170 192.168.120.189; do
      test -s "$SAVE/dev-$x-v7.7.1.3.txt" || fail "$SAVE/dev-$x-v7.7.1.3.txt is missing: the reading of Task Group 6 after the upload of $x"
      echo "dev $x $(cut -d' ' -f3 "$SAVE/dev-$x-v7.7.1.3.txt")" >> "$TMP/r24.txt"
    done
  fi
  out="$(python3 -I - "$TMP" "$mode" "$ROUNDS" "$CHECKS" "$CRITERIA" "$CLOSING" "$P" <<'PYEOF'
import json, re, sys
d, mode, rounds, checks = sys.argv[1], sys.argv[2], sys.argv[3].split("|"), sys.argv[4].split("|")
criteria, closing, prompt = int(sys.argv[5]), sys.argv[6], sys.argv[7]
norm = lambda t: re.sub(r"\s+", " ", t).strip()
sec7 = open(prompt, encoding="utf-8").read().split("\n## §7 — ", 1)[1].split("\n## §8 — ", 1)[0]
canon = [norm(l[6:]) for l in sec7.split("\n") if l.startswith("- [ ] ")]
if len(canon) != criteria:
    bad0 = ["section 7 of %s holds %d criteria, not %d" % (prompt, len(canon), criteria)]
else:
    bad0 = []
pull = json.load(open(d + "/pull.json", encoding="utf-8"))
comments = json.load(open(d + "/comments.json", encoding="utf-8"))
runs = json.load(open(d + "/checks.json", encoding="utf-8")).get("check_runs") or []
body, head, bad = (pull.get("body") or "").replace("\r\n", "\n"), pull["head"]["sha"], bad0
if len(comments) >= 100:
    bad.append("the PR has 100 or more comments: this block reads only the first 100")
heads = [h for h in re.findall(r"(?m)^## (.+?)\s*$", body)]
want = ["Pre-Implementation Verification", "Per-Item Verification", "Acceptance Criteria", "Files Modified", "Round Summary"]
got = [h for h in heads if h in want]
if got[:5] != want or len(got) != 5:
    bad.append("the body needs the headings ## " + ", ## ".join(want) + ", each once, in this order; found: " + ", ".join(got))
pre = re.findall(r"PRE-PR PASS at ([0-9a-f]{40})", body)
if not pre or pre[-1] != head:
    bad.append("the last 'PRE-PR PASS at <commit>' of the body is %s, not the head %s" % (pre[-1] if pre else "missing", head))
for l in body.split("\n"):
    if re.match(r"^\s*[-*] \[[xX]\]", l) and "pending" in l.lower():
        bad.append("a ticked criterion says pending: " + l.strip()[:120])
    if mode == "final" and re.match(r"^\s*[-*] \[ \]", l):
        bad.append("a criterion is not ticked: " + l.strip()[:120])
ac = re.search(r"(?ms)^## Acceptance Criteria\s*$(.*?)(?=^## |\Z)", body)
boxes = [norm(re.sub(r"^\s*[-*] \[[xX]\]", "", l)) for l in (ac.group(1) if ac else "").split("\n") if re.match(r"^\s*[-*] \[[xX]\]", l)]
if mode == "final":
    for c in canon:   # each criterion of section 7, as the prompt writes it, once and ticked; evidence may follow it
        n = sum(1 for b in boxes if b.startswith(c))
        if n != 1:
            bad.append("the section Acceptance Criteria holds the criterion %d time(s) ticked, not once: %s" % (n, c[:100]))
if mode == "final":   # the 24-hour readings of 6.5, as the blocks printed and saved them, for the upload of Task Group 6 (re-audit 2, H03)
    r24 = [l.rstrip("\n") for l in open(d + "/r24.txt", encoding="utf-8")]
    lines, boots = r24[:3], {l.split()[1]: int(l.split()[2]) for l in r24[3:]}
    forms = [r"wroom24 PASS: (192\.168\.120\.170), boot ([0-9]+), uptime ([0-9]+) s, min_free_heap [0-9]+ B",
             r"v2 (192\.168\.120\.170) PASS \(later\): boot ([0-9]+), uptime ([0-9]+) s, .*, writes_ok grew for [a-z_]+, [a-z_]+, [a-z_]+.*",
             r"v2 (192\.168\.120\.189) PASS \(later\): boot ([0-9]+), uptime ([0-9]+) s, .*, writes_ok grew for [a-z_]+, [a-z_]+, [a-z_]+.*"]
    docs = {"the PR body": body, "the session log at the head": open(d + "/log.md", encoding="utf-8").read(),
            "the record at the head": open(d + "/rec.md", encoding="utf-8").read()}
    for line, form in zip(lines, forms):
        m = re.fullmatch(form, line)
        if not m:
            bad.append("the saved line is not a PASS line of 6.5: " + line[:120]); continue
        if abs(int(m.group(2)) - boots[m.group(1)]) > 30 or int(m.group(3)) < 86400:
            bad.append("the line '%s' is not a reading at 24 hours or more after the upload of Task Group 6 (boot %d)" % (line[:60], boots[m.group(1)]))
        for name, t in docs.items():
            if line not in [x.strip().strip("`").strip() for x in t.replace("\r\n", "\n").split("\n")]:
                bad.append("%s holds no line '%s' (item 6.5)" % (name, line[:60]))
if [l for l in body.rstrip().split("\n") if l.strip()][-1:] != [closing]:
    bad.append("the last line of the body is not '%s'" % closing)
m = re.search(r"(?ms)^## Round Summary\s*$(.*?)(?=^## |\Z)", body)
rows = {}
for l in (m.group(1) if m else "").split("\n"):
    for r in rounds:
        if l.startswith("| %s |" % r):
            rows.setdefault(r, []).append(l)
def reviews_of(r):   # the posted reviews of round r: a comment whose first line is '## Review X - ...' (or a dash or colon)
    return [(c.get("body") or "").replace("\r\n", "\n").lstrip() for c in comments
            if re.match(r"## %s\s*[-\u2013\u2014:]" % re.escape(r), (c.get("body") or "").lstrip())]
def reviewed(t):   # the field Head reviewed of the table that opens a review (rule 9 of the review file): a commit of 7 to 40 hex, or None
    rows, k, l = [], 1, t.split("\n")
    while k < len(l) and not l[k].strip():
        k += 1
    while k < len(l) and l[k].strip().startswith("|"):
        rows.append([c.strip() for c in l[k].strip().strip("|").split("|")]); k += 1
    v = [c[1].strip("`* ") for c in rows if len(c) >= 2 and c[0].strip("`* ") == "Head reviewed"]
    return v[0] if len(v) == 1 and re.fullmatch(r"[0-9a-f]{7,40}", v[0]) else None   # a short commit counts too (internal round 3, L6)
posted = {"Inline": not pull.get("draft"), "Review A": bool(reviews_of("Review A")), "Review B": bool(reviews_of("Review B")),
          "Review C": bool(reviews_of("Review C"))}
for r in rounds:
    if len(rows.get(r, [])) != 1:
        bad.append("the Round Summary needs one row that begins '| %s |'; found %d" % (r, len(rows.get(r, []))))
        continue
    cells = [c.strip() for c in rows[r][0].strip().strip("|").split("|")]
    commits = [x for x in re.findall(r"\b[0-9a-f]{7,40}\b", cells[2] if len(cells) > 2 else "") if not (x.isdigit() and len(x) >= 9)]
    if any(c.lower() == "pending" for c in cells[1:]):
        if mode == "final" or posted.get(r):
            bad.append("the Round Summary row of %s still says pending" % r)
    elif len(cells) < 5 or not commits:
        bad.append("the Round Summary row of %s names no commit in its column 'Head reviewed' (a review or comment id is not one)" % r)
    elif not posted.get(r):
        bad.append("the Round Summary row of %s is filled, but %s" % (r, "the PR is still a draft" if r == "Inline" else "no comment begins '## %s - '" % r))
    elif r != "Inline":   # the field Head reviewed of a posted review's opening table is the commit of the row (re-audit 2, H04)
        named = [h for h in (reviewed(t) for t in reviews_of(r)) if h]
        if len(commits) != 1 or not any(h.startswith(commits[0]) or commits[0].startswith(h) for h in named):
            bad.append("the Round Summary row of %s names %s in 'Head reviewed'; it must name one commit, the field Head reviewed of a posted '## %s' review (found %s)" % (r, ", ".join(commits), r, ", ".join(h[:12] for h in named) or "none"))
if mode == "final":
    if len(runs) >= 100:
        bad.append("the head has 100 or more check runs: this block reads only the first 100")
    for name in checks:   # each required job by its exact name
        if not [x for x in runs if x.get("name") == name]:
            bad.append("no check run '%s' on the head %s" % (name, head[:7]))
    latest = {}
    for x in runs:  # a name can have several runs on one head (each edit of the body starts pr-body-check): the latest counts
        k = x.get("name") or ""
        key = (x.get("started_at") or "9999", x.get("id") or 0)  # a queued run has no start yet: it counts as the latest
        if k not in latest or key >= latest[k][0]:
            latest[k] = (key, x)
    latest = {k: v[1] for k, v in latest.items()}
    for k, x in sorted(latest.items()):
        mandatory = k in checks
        if x.get("status") != "completed":
            bad.append("the latest check run '%s' on the head is %s" % (k, x.get("status")))
        elif x.get("conclusion") not in (("success",) if mandatory else ("success", "skipped", "neutral")):
            bad.append("the latest check run '%s' on the head ended %s%s" % (k, x.get("conclusion"), ", and a required check must succeed" if mandatory else ""))
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PYEOF
)" || fail "$(printf '%s' "$out" | tr '\n' '|')"
  if [ "$mode" = "final" ]; then echo "body final PASS at $head"; else echo "body PASS"; fi
}
# --- review B in Google Antigravity (PLAN-047): the operator runs this block on the build host ---
b_reviewb() { # reviewb <PR#>: checks the PR and writes the one line for review B, with the head commit, to $SAVE/reviewb-<PR#>/message.txt
  # reviewb <PR#> answer: checks the saved answer.md (header, head, login and key screen, length) and writes comment.md, cleaned as the runner cleans its comment
  local pr="${1:-}" mode="${2:-}" out want_rf want_p
  [[ "$pr" =~ ^[0-9]+$ ]] && [[ "$mode" =~ ^(|answer)$ ]] || fail "usage: reviewb <PR#> [answer]"
  git show origin/main:scripts/external-review.py > "$TMP/external-review.py" 2>/dev/null || fail "cannot read scripts/external-review.py of origin/main"   # the runner's code of main, never the PR's
  cat > "$TMP/keyscreen.py" <<'PYEOF'
import re
# A key, password or token literal (PLAN-047): a quoted value of 4 or more characters without a space after a password-like name; a quoted
# value of 16 or more after a key-, token- or secret-like name; an unquoted whole-line YAML value after such a name; a long
# mixed value after a credential name; a GitHub token. A reference ($VAR, !secret, <placeholder>, {template}) is no literal.
KEY = re.compile(r"""\w*(?:password|passwd|pass|pwd)["']?\s*[:=]\s*["'](?![!$<{])[^"'\s]{4,}"""
                 r"""|\w*(?:key|token|secret)["']?\s*[:=]\s*["'](?![!$<{])[A-Za-z0-9+/=_.-]{16,}"""
                 r"""|^[-+ ]?\s*\w*(?:password|passwd|pass|pwd)\s*:\s*(?![!$<{"'#])\S{4,}\s*$"""
                 r"""|^[-+ ]?\s*\w*(?:key|token|secret)\s*:\s*(?![!$<{])[A-Za-z0-9+/=_.-]{16,}\s*$"""
                 r"""|\w*(?:api[_-]?key|password|passwd|pass|token|secret)\s*[:=]\s*(?=[A-Za-z0-9+/=_.-]*[0-9])(?=[A-Za-z0-9+/=_.-]*[A-Za-z])[A-Za-z0-9+/=_.-]{20,}"""
                 r"""|\bgh[pousr]_[A-Za-z0-9]{30,}|\bgithub_pat_[A-Za-z0-9_]{40,}""", re.I)
def hits(name, text):
    return ["%s line %d" % (name, n) for n, line in enumerate(text.split("\n"), 1) if KEY.search(line)]
def discussion(gh, pages, rn, repo, pr, pull):
    """The PR text and discussion that review B may read: title, body, reviews, review comments, comments."""
    reviews = pages("repos/%s/pulls/%s/reviews" % (repo, pr))
    review_comments = pages("repos/%s/pulls/%s/comments" % (repo, pr))
    comments = pages("repos/%s/issues/%s/comments" % (repo, pr))
    return [("pr-title", pull["title"]), ("pr-body", pull.get("body") or ""),
            ("reviews", "\n\n".join("%s %s: %s" % (r["user"]["login"], r["state"], r.get("body") or "") for r in reviews)),
            ("review-comments", "\n\n".join(rn.review_comment(c) for c in review_comments)),
            ("comments", "\n\n".join("%s: %s" % (c["user"]["login"], c.get("body") or "") for c in comments))]
def refused(rn, data, diff=None):
    """The first refusal of the runner's screen or of the key screen, or None."""
    try:
        if diff is not None:
            rn.screen("diff", diff, diff=True)
        for name, content in data:
            rn.screen(name, content)
    except (rn.Refused, rn.Failed) as e:
        return "%s" % e
    for name, content in ([("diff", diff)] if diff is not None else []) + data:
        bad = hits(name, content)
        if bad:
            return "%s: a key, password or token literal" % bad[0]
    return None
def digest(data):
    import hashlib
    return hashlib.sha256("\n\0".join(c for _, c in data).encode("utf-8")).hexdigest()
PYEOF
  if [ "$mode" = "answer" ]; then
    rm -f "$SAVE/reviewb-$pr/comment.md"   # a failed run leaves no candidate of an earlier run (re-audit 2, H05)
    out="$(python3 -I - "$GHREPO" "$pr" "$SAVE/reviewb-$pr" "$TMP/external-review.py" "$TMP/keyscreen.py" <<'PYEOF'
import hashlib, importlib.util, json, os, re, subprocess, sys
repo, pr, outdir, runner, keyscreen = sys.argv[1:6]
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
rn, ks = load("runner", runner), load("keyscreen", keyscreen)
for name in ("expect.txt", "answer.md"):
    if not os.path.isfile(os.path.join(outdir, name)):
        print("ERROR %s/%s is missing: run reviewb <PR#> first, and save the file that review B returned as answer.md" % (outdir, name)); sys.exit()
expect = open(os.path.join(outdir, "expect.txt"), encoding="utf-8").read().split()
head, screened = expect[0], expect[3]
norm = lambda t: "\n".join(l.rstrip() for l in t.replace("\r\n", "\n").replace("\r", "\n").strip().split("\n"))
answer = norm(open(os.path.join(outdir, "answer.md"), encoding="utf-8").read())
try:
    rn.screen("answer", answer, answer=True)
except (rn.Failed, rn.Refused) as e:
    print("ERROR refused: %s: do not post it; send this line to the planning session" % e); sys.exit()
bad = ks.hits("answer", answer)
if bad:
    print("ERROR refused: %s: a key, password or token literal: do not post it; send this line to the planning session" % bad[0]); sys.exit()
lines = answer.split("\n")
if not lines[0].startswith("## Review B"):
    print("ERROR answer.md does not begin with a line '## Review B': save the whole file that review B returned"); sys.exit()
table = {}
for l in lines[1:]:
    if l.startswith("### "):
        break
    m = re.match(r"^\|\s*([^|]+?)\s*\|\s*(.*?)\s*\|$", l)
    if m and not set(m.group(1)) <= set("-: "):
        table[m.group(1)] = m.group(2)
need = ["Pull request", "Head reviewed", "Model", "Context window", "Reasoning effort", "Tokens", "Compaction"]
missing = [k for k in need if not table.get(k)]
if missing:
    print("ERROR the header table of answer.md lacks %s (the review file, common part, rule 9): ask review B, in the same session, for its file with that header" % ", ".join(missing)); sys.exit()
if table["Pull request"].strip().lstrip("#") != pr:
    print("ERROR the field Pull request of the header is not #%s" % pr); sys.exit()
if table["Head reviewed"].strip().strip("`") != head:
    print("ERROR the field Head reviewed of the header is not %s, the commit of the one line: give the line of message.txt to a new session" % head); sys.exit()
comment = rn.clean(answer) + "\n"
try:   # the text that would be posted passes the same screens (GPT Astra's re-audit, R2-M4)
    rn.screen("comment", comment, answer=True)
except (rn.Failed, rn.Refused) as e:
    print("ERROR refused: %s: do not post it; send this line to the planning session" % e); sys.exit()
bad = ks.hits("comment", comment)
if bad:
    print("ERROR refused: %s: a key, password or token literal: do not post it; send this line to the planning session" % bad[0]); sys.exit()
if len(comment) > 65000:
    print("ERROR comment.md would have %d characters, more than the 65,000 of one GitHub comment: ask review B, in the same session, for a shorter file" % len(comment)); sys.exit()
changed = sum(1 for x, y in zip(answer.split("\n"), comment.rstrip("\n").split("\n")) if x != y)
def gh(path):
    r = subprocess.run(["gh", "api", path], capture_output=True, text=True)
    if r.returncode != 0:
        print("ERROR gh api %s: %s" % (path, r.stderr.strip()[:200])); sys.exit()
    return r.stdout
def pages(path):
    out, page = [], 1
    while True:
        chunk = json.loads(gh("%s?per_page=100&page=%d" % (path, page)))
        out += chunk
        if len(chunk) < 100:
            return out
        page += 1
pull = json.loads(gh("repos/%s/pulls/%s" % (repo, pr)))
now = pull["head"]["sha"]
data = ks.discussion(gh, pages, rn, repo, pr, pull)   # what review B may have read on GitHub since the block wrote its line
why = ks.refused(rn, data)
if why:
    print("ERROR refused: %s: the PR text or discussion now holds it; do not post the answer; send this line to the planning session" % why); sys.exit()
again = json.loads(gh("repos/%s/pulls/%s" % (repo, pr)))   # read twice: a change while the block reads is a stop (re-audit 2, H05)
if again["head"]["sha"] != now or ks.digest(ks.discussion(gh, pages, rn, repo, pr, again)) != ks.digest(data):
    print("ERROR the PR's head, text or discussion changed while the block read it: run 'reviewb %s answer' again" % pr); sys.exit()
open(os.path.join(outdir, "comment.md"), "w", encoding="utf-8").write(comment)
print("reviewb answer: the header names PR #%s and the head %s; no login and no key literal found; %d line(s) cleaned as the runner cleans (a line that starts with / is marked, @ becomes (at))" % (pr, head, changed))
if now != head:
    print("reviewb answer: the head of the PR is now %s; the review names %s, the commit it read" % (now, head))
if ks.digest(data) != screened:   # the residual risk that the operator accepted (PLAN-048): what review B read between the two reads is not known
    print("reviewb answer: the PR text or discussion changed after 'reviewb %s'; the new text passed both screens; what review B read in between is not known: say so to the planning session" % pr)
print("%s/comment.md: %d characters, SHA-256 %s" % (outdir, len(comment), hashlib.sha256(comment.encode("utf-8")).hexdigest()))
print("PASS")
PYEOF
)"
    grep -v '^ERROR\|^PASS$' <<< "$out"
    grep -q '^ERROR' <<< "$out" && fail "$(grep '^ERROR' <<< "$out" | head -n 1 | sed 's/^ERROR //')"
    [ "$(tail -n 1 <<< "$out")" = "PASS" ] || fail "unexpected output of the block"
    echo "reviewb answer PASS"
    return
  fi
  want_rf="$(grep " $RF\$" <<< "$COPY" | cut -d' ' -f1)"
  want_p="$(sha "$SAVE/v7.7.1.3-agent-prompt-gpt-codex.md" 2>/dev/null)"
  [[ "$want_rf" =~ ^[0-9a-f]{64}$ ]] && [[ "$want_p" =~ ^[0-9a-f]{64}$ ]] || fail "the SHA-256 of the supplied review file or of $SAVE/v7.7.1.3-agent-prompt-gpt-codex.md"
  mkdir -p "$SAVE/reviewb-$pr" || fail "cannot create $SAVE/reviewb-$pr"
  rm -f "$SAVE/reviewb-$pr/message.txt" "$SAVE/reviewb-$pr/expect.txt" "$SAVE/reviewb-$pr/comment.md"
  out="$(python3 -I - "$GHREPO" "$pr" "$P" "$RF" "$SAVE/reviewb-$pr" "$TMP/external-review.py" "$TMP/keyscreen.py" "$want_p" "$want_rf" <<'PYEOF'
import base64, hashlib, importlib.util, json, subprocess, sys
repo, pr, ppath, rpath, outdir, runner, keyscreen, want_p, want_rf = sys.argv[1:10]
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
rn, ks = load("runner", runner), load("keyscreen", keyscreen)   # the runner's own screen and review_comment functions
def gh(path, accept=None):
    cmd = ["gh", "api", path]
    if accept:
        cmd[2:2] = ["-H", "Accept: " + accept]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("ERROR gh api %s: %s" % (path, r.stderr.strip()[:200])); sys.exit()
    return r.stdout
def pages(path):
    out, page = [], 1
    while True:
        chunk = json.loads(gh("%s?per_page=100&page=%d" % (path, page)))
        out += chunk
        if len(chunk) < 100:
            return out
        page += 1
sha = lambda s: hashlib.sha256(s.encode("utf-8")).hexdigest()
pull = json.loads(gh("repos/%s/pulls/%s" % (repo, pr)))
head, base, base_ref = pull["head"]["sha"], pull["base"]["sha"], pull["base"]["ref"]
def at_head(path):
    obj = json.loads(gh("repos/%s/contents/%s?ref=%s" % (repo, path, head)))
    return base64.b64decode(obj["content"].replace("\n", "")).decode("utf-8")
prompt, review = at_head(ppath), at_head(rpath)
if sha(review) != want_rf:
    print("ERROR the review file at the head %s is not its supplied text (SHA-256 %s): run no review B; send this line to the planning session" % (head, sha(review))); sys.exit()
if sha(prompt) != want_p:
    print("ERROR the agent prompt at the head %s is not the prompt of the setup file (SHA-256 %s): run no review B; send this line to the planning session" % (head, sha(prompt))); sys.exit()
diff = gh("repos/%s/compare/%s...%s" % (repo, base, head), accept="application/vnd.github.diff")
files = pages("repos/%s/pulls/%s/files" % (repo, pr))
if len(files) < pull["changed_files"]:
    print("ERROR incomplete file list: %d of %d" % (len(files), pull["changed_files"])); sys.exit()
changed = "\n".join("renamed %s -> %s" % (f["previous_filename"], f["filename"]) if f["status"] == "renamed"
                    else "%s %s" % (f["status"], f["filename"]) for f in files)
data = ks.discussion(gh, pages, rn, repo, pr, pull)
why = ks.refused(rn, data + [("changed-files", changed)], diff=diff)
if why:
    print("ERROR refused: %s: run no review B on this pull request, in any Gemini session or on the runner; send this line to the planning session" % why); sys.exit()
again = json.loads(gh("repos/%s/pulls/%s" % (repo, pr)))
if again["head"]["sha"] != head or again["base"]["sha"] != base:
    print("ERROR the head or the base of PR #%s moved while the block read it (head %s, now %s): run the block again" % (pr, head, again["head"]["sha"])); sys.exit()
if ks.digest(ks.discussion(gh, pages, rn, repo, pr, again)) != ks.digest(data):
    print("ERROR the PR text or discussion changed while the block read it: run the block again"); sys.exit()
url = "https://github.com/%s/blob/%s/%s" % (repo, head, rpath)
line = ("Review B of pull request #%s of %s, at the commit %s. Read %s: its common part, its checks of this step and part B, "
        "and follow them exactly. You are review B. Read the pull request only at that commit. Change nothing on GitHub. "
        "Return your review as one downloadable Markdown file." % (pr, repo, head, url))
open("%s/message.txt" % outdir, "w", encoding="utf-8").write(line + "\n")
open("%s/expect.txt" % outdir, "w", encoding="utf-8").write("%s %s %s %s\n" % (head, base, base_ref, ks.digest(data)))
print("reviewb PR #%s: head %s, base %s (%s)" % (pr, head, base, base_ref))
print("agent prompt at the head: SHA-256 %s, the prompt of the setup file" % sha(prompt))
print("review file at the head: SHA-256 %s, its supplied text" % sha(review))
print("no login and no key literal in the diff, the PR text, the reviews and the comments; start review B now, and let nobody post on the PR until its answer is checked")
print("the line for review B, also in %s/message.txt:" % outdir)
print(line)
print("PASS")
PYEOF
)"
  grep -v '^ERROR\|^PASS$' <<< "$out"
  grep -q '^ERROR' <<< "$out" && fail "$(grep '^ERROR' <<< "$out" | head -n 1 | sed 's/^ERROR //')"
  [ "$(tail -n 1 <<< "$out")" = "PASS" ] || fail "unexpected output of the block"
  echo "reviewb PASS"
}
case "$NAME" in
  sec2) b_sec2 ;;
  scope) b_scope "${2:-}" "${3:-}" ;;
  copy) b_copy "${2:-}" ;;
  insert) b_insert "${2:-}" ;;
  A|B|C|D|F) "b_$NAME" ;;
  E) b_E ;;
  host) b_host ;;
  image) b_image "${2:-}" ;;
  dev) b_dev "${2:-}" "${3:-}" "${4:-}" ;;
  v2) b_v2 "${2:-}" "${3:-}" ;;
  wroom24) b_wroom24 "${2:-}" ;;
  prepr) b_prepr ;;
  inline) b_inline "${2:-}" ;;
  body) b_body "${2:-}" "${3:-}" ;;
  reviewb) b_reviewb "${2:-}" "${3:-}" ;;
  *) echo "usage: bash $0 <sec2 | scope <PR#> <YYYY-MM-DD> | copy [verify] | insert <S2|T3> | A | B | host | C | D | E | image <s3|wroom> | dev <IP> <before | v7.7.1.3> [c3heap | floor] | v2 <IP> [before] | wroom24 <epoch> | F | prepr | inline <PR#> | body <PR#> [final] | reviewb <PR#> [answer]>"; exit 2 ;;
esac
