#!/usr/bin/env bash
# v7.7.1.2 check file: every gate and checkpoint of prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md, so that the
# agent types no check (PLAN-031). It also writes the scope list, inserts the three supplied texts of the prompt,
# measures the struct sizes on the compiler, and reads the two boards of the step.
# Written 2026-11-22 by the planning session for R5b (PLAN-044), corrected the same day for PLAN-045; do not edit it.
# Fenced texts of the prompt are taken from the prompt by a tool (the function fence below), never retyped.
#
#   bash /root/v7712/v7.7.1.2-checks.sh <sec2 | scope <PR#> <YYYY-MM-DD> | copy [verify] | insert <S1|T1|T2> | A | B | C | D | measure
#        | dev <IP> <version> [c3heap] | wroom24 <epoch> | E | prepr | inline <PR#> | body <PR#> [final]>
#
# Each block ends with one PASS line, or prints "⛔ CHECKPOINT FAILED - <block>: <reason>" and exits 1.
# The blocks dev and wroom24 read the login from $ESP_USER and $ESP_PASS inside one python3 process and print no
# value of it; no other block reads it. Temporary files go when the block ends.
set -u
REPO=/root/config/ESP32-GW-multi-sensor
SAVE=/root/v7712
BRANCH=feature/v7.7.1.2-per-device-structs
PROD=92d1260
GHREPO=GCV-Sleeper-Service/ESP32-GW-multi-sensor
ROUNDS="Inline|Review A|Review B"
CHECKS="preflight-and-compile|prompt-lint|pr-body-check|browser-tests=7"   # name=N: N distinct jobs of that name
P=prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md
CF=prompts/phase7/v7.7.1.2-checks.sh
DM=firmware/core/data-model.h
NV=firmware/core/nvs-persistence.h
RS=scripts/render_sensor_config.py
HDR=dashboard/sensor_history_multi.h
CS=CURRENT-STATE.md
POR=Docs/plan-of-record.md
CL=Docs/changelog.md
ARCH=Docs/v7.7-v7.8-persistence-architecture.md
C3YAML=firmware/esp32-c3-multi-sensor.yaml
C3BIN=firmware/.esphome/build/esp32-c3-multi/.pioenvs/esp32-c3-multi/firmware.bin
C3SLOT=1769472
NAME="${1:-}"
case "$NAME" in sec2) LABEL="§2" ;; prepr) LABEL="PRE-PR" ;; *) LABEL="$NAME" ;; esac
TMP="$(mktemp -d)" || { echo "⛔ CHECKPOINT FAILED - ${LABEL}: mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
fail() { echo "⛔ CHECKPOINT FAILED - ${LABEL}: $1"; exit 1; }
sha() { sha256sum < "$1" | cut -d' ' -f1; }
cnt() { grep -cE -- "$1" "$2"; }   # how many lines of $2 match the extended regex $1
COPY="49b78d0f2881d388e2dc26208060bf1acfa78103dccab4a53fd5500206a6d6b0 Docs/development-process-guide.md
63f3476770ea9a63a3336df44ccc8f29a6dffdc5971d0d3f869cd507570cfeaf prompts/producer-contract.md
eaf1c1d1d8961448f568c9d3064e7336c146218a585486b6483d6837b77d48de Docs/templates/prompt-audit-template.md
1a3ad6de306ef63c1ed9b80a2e95291ac963d557742aaaecf45f11ab72c47cd4 Docs/planner-start-here.md
017a11a9afd5b355c4cac2c997b37d0bd3263f890fe06d15daa50c94a4935fd0 Docs/decisions/decision-log.md
4434c32473002239b499082dcf9e6fccd0afdea2e40d98386160ef595204ceb2 Docs/plan-of-record.md
0e57963328ae80fbbcbd85c43db75de6f9aafd9f75beea25fa8c7a63ea80c423 prompts/phase7/v7.7.1.2-review.md
c807530d77b94cc29b2ba2a2084a1572ce3a5916b5d540ab0e35a62901abcb0f Docs/operator/R4-per-device-structs.md
ae64e7d21be022a07e5355e5e8f87e2fd86c3690aefabd535f94f9108a51e885 prompts/handoff/phase7/session-handoff-v7.7.1.2.md"   # the files of Task Group 0: <SHA-256> <path>, one per line
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
line_of() { awk -v p="$2" 'index($0, p) == 1 { print NR; exit }' "$1"; }   # first line that begins with $2
removed_ok() { # $1 file: every line removed since $PROD is allowed by the pattern $2 (an ERE), or none is removed
  local bad
  bad="$(git diff --no-color -U0 "$PROD" -- "$1" | grep -E '^-[^-]|^-$' | grep -vE -- "$2")"
  [ -z "$bad" ] || { echo "$bad" | head -3; return 1; }
}
supplied() { # $1 S1|T1|T2 -> $TMP/$1.txt, checked against its SHA-256
  local label want
  case "$1" in
    S1) label="Supplied text S1 — "; want=622fca950f8c45dbe02d205984212273fa96be8267af0bbc57ba5aa0814e8d17 ;;
    T1) label="Supplied text T1 — "; want=b7c01745519f6307ff1715e67a35d9c50ba0c436cfd95033a146c89482426578 ;;
    T2) label="Supplied text T2 — "; want=4ba97235b37c7bdd02b1291f813d46115fcfbc486e4e42b4abc086e34ec5f02c ;;
    *) fail "usage: insert <S1|T1|T2>" ;;
  esac
  fence "$P" "$label" "$TMP/$1.txt" || fail "$1: the prompt has no single supplied text $1"
  test "$(sha "$TMP/$1.txt")" = "$want" || fail "$1: the supplied text in $P differs from the bundle"
}
scope_list() { git rev-parse --git-path scope-allowed.txt; }
new_paths() { # the session log and the record, from the scope list
  local a; a="$(scope_list)" || return 1
  test -f "$a" || return 1
  grep -E '^Docs/session-log-[0-9]{4}-[0-9]{2}-[0-9]{2}-v7\.7\.1\.2\.md$|^prompts/phase7/v7\.7\.1\.2-PR[0-9]+-consolidated-audit-and-lessons\.md$' "$a"
}

b_sec2() {
  local f
  test "$(git branch --show-current)" = "$BRANCH" || fail "the branch is not $BRANCH"
  git fetch -q origin || fail "git fetch"
  test "$(git merge-base origin/main HEAD)" = "$(git rev-parse origin/main)" || fail "the branch does not start at origin/main: branch again from origin/main"
  test "$(git diff --name-only origin/main HEAD | sort | tr '\n' ' ')" = "$(printf '%s\n' "$P" "$CF" | sort | tr '\n' ' ')" || fail "the branch must change only $P and $CF (the commit of the setup file); it changes: $(git diff --name-only origin/main HEAD | head -n 4 | tr '\n' ' ')"
  test "$(cat VERSION)" = "7.7.1.1" || fail "VERSION is not 7.7.1.1"
  test -z "$(git status --porcelain)" || fail "the working tree is not clean"
  cmp -s "$P" "$SAVE/v7.7.1.2-agent-prompt-gpt-codex.md" || fail "$P differs from $SAVE/v7.7.1.2-agent-prompt-gpt-codex.md"
  cmp -s "$CF" "$SAVE/v7.7.1.2-checks.sh" || fail "$CF differs from $SAVE/v7.7.1.2-checks.sh"
  for f in python3 node npx git gh curl esphome sha256sum; do command -v "$f" >/dev/null || fail "the tool $f is missing"; done
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' || fail "python3 is older than 3.12"
  esphome version 2>/dev/null | grep -qx 'Version: 2026.4.1' || fail "esphome is not 2026.4.1 (PLAN-016)"
  test -d node_modules/@playwright/test || fail "node_modules/@playwright/test is missing"
  gh auth status >/dev/null 2>&1 || fail "gh is not logged in"
  [ -n "${ESP_USER:-}" ] && [ -n "${ESP_PASS:-}" ] || fail "\$ESP_USER or \$ESP_PASS is not set in this shell"
  test "$(git show "$PROD:$DM" | sha256sum | cut -d' ' -f1)" = "$(sha "$DM")" || fail "$DM changed since $PROD: the planning session renders the prompt again"
  test "$(git show "$PROD:$NV" | sha256sum | cut -d' ' -f1)" = "$(sha "$NV")" || fail "$NV changed since $PROD"
  test "$(git show "$PROD:$RS" | sha256sum | cut -d' ' -f1)" = "$(sha "$RS")" || fail "$RS changed since $PROD"
  test "$(git show "$PROD:$ARCH" | sha256sum | cut -d' ' -f1)" = "$(sha "$ARCH")" || fail "$ARCH changed since $PROD"
  test "$(git show "$PROD:$CL" | sha256sum | cut -d' ' -f1)" = "$(sha "$CL")" || fail "$CL changed since $PROD"
  while read -r _ f; do
    test "$(git show "$PROD:$f" | sha256sum | cut -d' ' -f1)" = "$(sha "$f")" || fail "$f changed since $PROD: the planning session renders the bundle again"
    test -f "$SAVE/files/$f" || fail "the supplied file $SAVE/files/$f is missing"
  done <<< "$COPY"
  test "$(cnt 'DeviceHistoryMeta|EventLog|PersistPriority|PERSIST_DEVICE_COUNT|MAX_DEVICE_SLOTS' "$DM")" = "0" || fail "$DM already holds a Phase 7 symbol of this step"
  test "$(cnt 'device_id_hash_|NvsKey|device_meta_key_|device_segment_key_' "$NV")" = "0" || fail "$NV already holds a Phase 7 symbol of this step"
  test "$(cnt 'PERSIST_DEVICE_COUNT' "$RS")" = "0" || fail "$RS already writes PERSIST_DEVICE_COUNT"
  test "$(grep -cxF '// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>' "$DM")" = "1" || fail "1.1 anchor: one line '// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>' in $DM"
  test "$(tail -n 1 "$DM")" = 'static const char *const HISTORY_PARTITION_LABEL = "history";' || fail "1.2 anchor: the last line of $DM"
  test "$(grep -cxF 'static void make_segment_key_(int slot, char *key, size_t key_len) {' "$NV")" = "1" || fail "2.1 anchor: make_segment_key_() in $NV"
  test "$(grep -cxF 'static void clear_runtime_histories_() {' "$NV")" = "1" || fail "2.2 anchor: clear_runtime_histories_() in $NV"
  test "$(grep -cxF 'def render_entity_block(sensors: List[Dict]) -> str:' "$RS")" = "1" || fail "3.1 anchor: render_entity_block() in $RS"
  test "$(grep -cxF '## 5. Storage Model: Per-Device Segments' "$ARCH")" = "1" || fail "6.4 anchor: the heading of §5 in $ARCH"
  test "$(grep -cxF '## 6. NVS Key Scheme' "$ARCH")" = "1" || fail "6.4 anchor: the heading of §6 in $ARCH"
  test "$(grep -c '^| 8 | R4 |' "$POR")" = "1" || fail "6.2 anchor: the row 8 of the ladder in $POR"
  python3 -I - "$DM" "$HDR" <<'PYEOF' || fail "the generated blocks of $DM and $HDR differ on main"
import sys
def block(p):
    t = open(p, encoding="utf-8").read()
    return t[t.index("// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>"):t.index("// <<< SENSOR_MANIFEST:ENTITY_END >>>")]
sys.exit(0 if block(sys.argv[1]) == block(sys.argv[2]) else 1)
PYEOF
  for f in S1 T1 T2; do supplied "$f"; done
  echo "§2 PASS"
}

b_scope() {
  local pr="${1:-}" day="${2:-}" a
  [[ "$pr" =~ ^[0-9]+$ ]] && [[ "$day" =~ ^20[0-9]{2}-[01][0-9]-[0-3][0-9]$ ]] || fail "usage: scope <PR#> <YYYY-MM-DD>"
  a="$(scope_list)" || fail "git rev-parse"
  cat > "$a" <<'EOF'
prompts/phase7/v7.7.1.2-agent-prompt-gpt-codex.md
prompts/phase7/v7.7.1.2-checks.sh
firmware/core/data-model.h
firmware/core/nvs-persistence.h
scripts/render_sensor_config.py
scripts/sensor_manifest_lib.py
CURRENT-STATE.md
Docs/plan-of-record.md
Docs/changelog.md
Docs/v7.7-v7.8-persistence-architecture.md
Docs/lessons/index.md
Docs/lessons/firmware.md
Docs/development-process-guide.md
prompts/producer-contract.md
Docs/templates/prompt-audit-template.md
Docs/planner-start-here.md
Docs/decisions/decision-log.md
prompts/phase7/v7.7.1.2-review.md
Docs/operator/R4-per-device-structs.md
prompts/handoff/phase7/session-handoff-v7.7.1.2.md
VERSION
dashboard/core/app-shell.js
dashboard/dashboard.h
dashboard/dashboard.html
dashboard/dashboard.js
dashboard/sensor_history_multi.h
firmware/core/config.h
firmware/esp32-c3-multi-sensor.yaml
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
  printf '%s\n' "Docs/session-log-$day-v7.7.1.2.md" "prompts/phase7/v7.7.1.2-PR$pr-consolidated-audit-and-lessons.md" >> "$a"
  test "$(grep -c . "$a")" = "39" || fail "the scope list does not hold 39 paths"
  echo "scope list written: 39 paths"
}

por_ok() { # the plan of record differs from its supplied text only as item 6.2 says: row 8 and section 2
  python3 -I - "$SAVE/files/$POR" "$POR" <<'PYEOF'
import sys
a = open(sys.argv[1], encoding="utf-8").read().split("\n")
b = open(sys.argv[2], encoding="utf-8").read().split("\n")
def row8(lines):
    r = [l for l in lines if l.startswith("| 8 | R4 |")]
    return [c.strip() for c in r[0].strip().strip("|").split("|")] if len(r) == 1 else None
def sec2(lines):
    out, on = [], False
    for l in lines:
        if l.startswith("## "):
            on = l.startswith("## 2. You are here")
        elif on:
            out.append(l)
    return "\n".join(out).strip()
ra, rb = row8(a), row8(b)
if rb is None or len(rb) != len(ra) or rb[:-1] != ra[:-1] or not rb[-1].startswith("Done"):
    sys.exit("row 8 (R4): only its status cell may change, to Done (item 6.2); the cell 'Actual (sessions)' stays pending")
s2 = sec2(b)
if s2 == sec2(a) or not all(w in s2 for w in ("R4", "v7.7.1.3", "R6")):
    sys.exit("section 2, 'You are here', must be rewritten as item 6.2 says: it names R4, v7.7.1.3 and R6")
def strip(lines):
    out, skip = [], False
    for l in lines:
        if l.startswith("## "):
            skip = l.startswith("## 2. You are here")
        if skip or l.startswith("| 8 | R4 |"):
            continue
        out.append(l)
    return out
if strip(a) != strip(b):
    x = next(i for i, (p, q) in enumerate(zip(strip(a) + [""], strip(b) + [""])) if p != q)
    sys.exit("first difference: " + (strip(b) + [""])[x][:120])
PYEOF
}

b_copy() { # copy [verify]: Task Group 0 copies the nine supplied files; verify (PRE-PR) checks them again
  local mode="${1:-}" want f n=0
  [ -z "$mode" ] || [ "$mode" = "verify" ] || fail "usage: copy [verify]"
  while read -r want f; do
    [ -n "$f" ] || continue
    if [ "$mode" != "verify" ]; then
      test "$(sha "$SAVE/files/$f")" = "$want" || fail "the supplied file $SAVE/files/$f differs from the bundle"
    fi
    if [ "$(sha "$f")" = "$want" ]; then
      n=$((n + 1)); continue
    fi
    if [ "$f" = "$POR" ] && por_ok > "$TMP/por.log" 2>&1; then
      n=$((n + 1)); continue   # copied before, then edited as item 6.2 says
    fi
    [ "$mode" != "verify" ] || fail "$f differs from its supplied text: a file that the block copy wrote was edited ($(tail -n 1 "$TMP/por.log" 2>/dev/null))"
    test "$(git show "$PROD:$f" | sha256sum | cut -d' ' -f1)" = "$(sha "$f")" || fail "$f is neither the file of $PROD nor its supplied text"
    cp "$SAVE/files/$f" "$f" || fail "cannot write $f"
    test "$(sha "$f")" = "$want" || fail "$f does not equal its supplied text after the copy"
    n=$((n + 1))
  done <<< "$COPY"
  test "$n" = "9" || fail "the list of the block copy holds $n files, not 9"
  if [ "$mode" = "verify" ]; then echo "copy verify PASS: 9 files"; return; fi
  echo "copied 9 files"
  echo "CHECKPOINT 0 PASS"
}

b_insert() {
  local what="${1:-}" n
  supplied "$what"
  case "$what" in
    S1)
      n="$(contains "$DM" "$TMP/S1.txt")"
      if [ "$n" = "1" ]; then echo "inserted S1"; return; fi
      test "$n" = "0" || fail "S1 occurs $n times in $DM"
      test "$(tail -n 1 "$DM")" = 'static const char *const HISTORY_PARTITION_LABEL = "history";' || fail "S1: the last line of $DM is not the anchor"
      cat "$TMP/S1.txt" >> "$DM" || fail "S1: cannot write $DM"
      test "$(contains "$DM" "$TMP/S1.txt")" = "1" || fail "S1: not in $DM after the insert" ;;
    T1)
      n="$(contains "$DM" "$TMP/T1.txt")"
      if [ "$n" = "1" ]; then echo "inserted T1"; return; fi
      test "$n" = "0" || fail "T1 occurs $n times in $DM"
      fence "$P" "Supplied text S1 — " "$TMP/S1.txt" || fail "S1"
      test "$(contains "$DM" "$TMP/S1.txt")" = "1" || fail "T1: S1 is not in $DM: run insert S1 first"
      test "$(cnt '^class EventLog\b' "$DM")" = "1" || fail "T1: write the class EventLog (item 1.3) first"
      cat "$TMP/T1.txt" >> "$DM" || fail "T1: cannot write $DM"
      test "$(contains "$DM" "$TMP/T1.txt")" = "1" || fail "T1: not in $DM after the insert" ;;
    T2)
      n="$(contains "$NV" "$TMP/T2.txt")"
      if [ "$n" = "1" ]; then echo "inserted T2"; return; fi
      test "$n" = "0" || fail "T2 occurs $n times in $NV"
      python3 -I - "$NV" "$TMP/T2.txt" <<'PYEOF' || fail "T2: cannot insert it before 'static void clear_runtime_histories_() {'"
import sys
p, t = sys.argv[1], open(sys.argv[2], encoding="utf-8").read()
s = open(p, encoding="utf-8").read()
a = "static void clear_runtime_histories_() {\n"
if s.count(a) != 1:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(a, t + a))
PYEOF
      test "$(contains "$NV" "$TMP/T2.txt")" = "1" || fail "T2: not in $NV after the insert" ;;
  esac
  echo "inserted $what"
}

assembly_ok() {
  bash scripts/assemble-sensor-history.sh --check > "$TMP/asm.log" 2>&1 || fail "bash scripts/assemble-sensor-history.sh --check fails: $(tail -n 2 "$TMP/asm.log" | tr '\n' ' ')"
}

b_A() {
  local s t e x
  fence "$P" "**1.1** " "$TMP/enum.txt" || fail "1.1 fenced text"
  for x in S1 T1; do supplied "$x"; done
  test "$(contains "$DM" "$TMP/enum.txt")" = "1" || fail "1.1 the block of 1.1 must occur once in $DM, verbatim"
  e="$(first "$DM" "$TMP/enum.txt")"; s="$(line_of "$DM" '// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>')"
  [ -n "$s" ] && [ "$e" -lt "$s" ] || fail "1.1 the block of 1.1 must come before '// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>'"
  x=$((e + $(wc -l < "$TMP/enum.txt")))
  [ "$x" -le "$s" ] && { [ "$x" = "$s" ] || test -z "$(sed -n "$x,$((s - 1))p" "$DM" | grep -v '^$')"; } || fail "1.1 only empty lines may stand between the block of 1.1 and the line '// <<< SENSOR_MANIFEST:HEADER_BEGIN >>>'"
  test "$(contains "$DM" "$TMP/S1.txt")" = "1" || fail "1.2 S1 must occur once in $DM, verbatim"
  test "$(contains "$DM" "$TMP/T1.txt")" = "1" || fail "1.4 T1 must occur once in $DM, verbatim"
  test "$(cnt '^class EventLog\b' "$DM")" = "1" || fail "1.3 one 'class EventLog' in $DM"
  s="$(first "$DM" "$TMP/S1.txt")"; t="$(first "$DM" "$TMP/T1.txt")"; e="$(grep -nE '^class EventLog\b' "$DM" | cut -d: -f1)"
  [ "$s" -lt "$e" ] && [ "$e" -lt "$t" ] || fail "1.3 the order must be S1, class EventLog, T1"
  test "$(sed -n "$((s - 1))p" "$DM")" = 'static const char *const HISTORY_PARTITION_LABEL = "history";' || fail "1.2 S1 must follow the line HISTORY_PARTITION_LABEL directly"
  test "$(cnt '\bmemset\b|\bsnprintf\b|std::|\bmalloc\b|\bnew\b' <(sed -n "$s,\$p" "$DM" | sed 's://.*$::'))" = "0" || fail "1.3 the new code uses memset, snprintf, std::, malloc or new"
  test "$(cnt '^#include' <(sed -n "$s,\$p" "$DM"))" = "0" || fail "an #include line was added"
  removed_ok "$DM" '^-// ── SENSOR COUNT CONFIGURATION GUIDE \(v7\.7\.1\.1\) ──$' || fail "a line of $DM on main was removed or changed (the lines above)"
  assembly_ok
  echo "CHECKPOINT A PASS"
}

b_B() {
  local s e t c n
  supplied T2
  n=0
  for re in '^static constexpr uint32_t device_id_hash_\(const char \*id\)[[:space:]]*(\{.*)?$' \
            '^struct NvsKey\b' \
            '^static constexpr NvsKey device_meta_key_\(const char \*device_id\)[[:space:]]*(\{.*)?$' \
            '^static constexpr NvsKey device_segment_key_\(const char \*device_id, int slot\)[[:space:]]*(\{.*)?$'; do
    n=$((n + 1))
    test "$(cnt "$re" "$NV")" = "1" || fail "2.1 definition $n of 4 (device_id_hash_, NvsKey, device_meta_key_, device_segment_key_) must occur once, with the signature of the prompt"
  done
  test "$(contains "$NV" "$TMP/T2.txt")" = "1" || fail "2.2 T2 must occur once in $NV, verbatim"
  s="$(grep -nxF 'static void make_segment_key_(int slot, char *key, size_t key_len) {' "$NV" | cut -d: -f1)"
  e="$(awk -v s="$s" 'NR > s && $0 == "}" { print NR; exit }' "$NV")"
  t="$(first "$NV" "$TMP/T2.txt")"; c="$(grep -nxF 'static void clear_runtime_histories_() {' "$NV" | cut -d: -f1)"
  test "$((t + $(wc -l < "$TMP/T2.txt")))" = "$c" || fail "2.2 T2 must stand directly before 'static void clear_runtime_histories_() {'"
  for re in 'device_id_hash_\(const char' '^struct NvsKey\b' 'NvsKey device_meta_key_\(' 'NvsKey device_segment_key_\('; do
    n="$(grep -nE -- "$re" "$NV" | head -n 1 | cut -d: -f1)"
    [ "$n" -gt "$e" ] && [ "$n" -lt "$t" ] || fail "2.1 the four definitions must stand between the end of make_segment_key_() and T2"
  done
  test "$(cnt 'snprintf' <(sed -n "$((e + 1)),$((t - 1))p" "$NV"))" = "0" || fail "2.1 the new code uses snprintf"
  test "$(cnt '^#include' <(sed -n "$((e + 1)),$((c - 1))p" "$NV"))" = "0" || fail "an #include line was added"
  removed_ok "$NV" '^$^' || fail "a line of $NV on main was removed or changed (the lines above)"
  assembly_ok
  echo "CHECKPOINT B PASS"
}

b_C() {
  fence "$P" "The generated lines for " "$TMP/gen.txt" || fail "3.1 fenced text"
  python3 -I - "$TMP/gen.txt" <<'PYEOF' || fail "3.1 the generated lines (see the line above)"
import json, sys
sys.path.insert(0, "scripts")
import render_sensor_config as r
from sensor_manifest_lib import canonicalize_sensors
main = open(sys.argv[1], encoding="utf-8").read().rstrip("\n").split("\n")
def tail(sensors):
    return r.render_entity_block(sensors).split("\n")
def expect(ids, counts, prios):
    n = len(ids)
    a = ", ".join('"%s"' % i for i in ids) if n else "nullptr"
    b = ", ".join(str(c) for c in counts) if n else "0"
    c = ", ".join("PERSIST_PRIORITY_" + p for p in prios) if n else "PERSIST_PRIORITY_HIGH"
    return main[:2] + ["static constexpr int PERSIST_DEVICE_COUNT = %d;" % n, main[3],
            "static const char *const PERSIST_DEVICE_IDS[PERSIST_DEVICE_ARRAY_LEN] = {%s};" % a,
            "static constexpr uint8_t PERSIST_METRIC_COUNTS[PERSIST_DEVICE_ARRAY_LEN] = {%s};" % b,
            "static constexpr PersistPriority PERSIST_PRIORITIES[PERSIST_DEVICE_ARRAY_LEN] = {%s};" % c]
def check(name, sensors, want):
    got = tail(sensors)
    k = len(want)
    if got[-k:] != want or got[-k - 1] != "" or got[-k - 2] != "};":
        sys.exit("%s: the block does not end with the line '};', one empty line and the lines expected; it ends with: %s" % (name, " / ".join(got[-k - 2:])))
live = canonicalize_sensors(json.load(open("config/sensors.json", encoding="utf-8"))["sensors"])
if expect(["office", "first_floor", "outside", "wan_ping"], [2, 2, 2, 2], ["HIGH", "HIGH", "HIGH", "LOW"]) != main:
    sys.exit("the prompt's lines for config/sensors.json do not follow the rules of 3.1")
check("config/sensors.json", live, main)
ping = [s for s in live if s["adapter"] == "icmp_ping"]
office = [s for s in live if s["id"] == "office"]
system = [s for s in live if s["adapter"] == "external_push"]
check("no device", [], expect([], [], []))
check("only a system device", system, expect([], [], []))
check("only a network device", ping, expect(["wan_ping"], [2], ["LOW"]))
check("network before environmental", ping + office, expect(["wan_ping", "office"], [2, 2], ["LOW", "HIGH"]))
PYEOF
  python3 -I - "$DM" "$HDR" <<'PYEOF' || fail "3.2 the generated blocks of $DM and $HDR differ"
import sys
def block(p):
    t = open(p, encoding="utf-8").read()
    return t[t.index("// <<< SENSOR_MANIFEST:ENTITY_BEGIN >>>"):t.index("// <<< SENSOR_MANIFEST:ENTITY_END >>>")]
sys.exit(0 if block(sys.argv[1]) == block(sys.argv[2]) else 1)
PYEOF
  test "$(cnt '^static constexpr int PERSIST_DEVICE_COUNT = 4;$' "$HDR")" = "1" || fail "3.2 run python3 scripts/render_sensor_config.py --write: $HDR has no PERSIST_DEVICE_COUNT = 4"
  python3 scripts/render_sensor_config.py --check > "$TMP/rs.log" 2>&1 || fail "python3 scripts/render_sensor_config.py --check fails: $(head -n 2 "$TMP/rs.log" | tr '\n' ' ')"
  test -z "$(git diff "$PROD" -- scripts/sensor_manifest_lib.py)" || echo "note: scripts/sensor_manifest_lib.py changed (SOFT, §3): record it in §4 of the record"
  assembly_ok
  echo "CHECKPOINT C PASS"
}

b_D() { # D [noimage]: the PRE-PR gate runs it without the image, which esphome clean of Task Group 5 removes
  local mode="${1:-}" x t n size
  test "$(cat VERSION)" = "7.7.1.2" || fail "4.1 VERSION is not 7.7.1.2: run bash scripts/bump-version.sh 7.7.1.2"
  test "$(cnt '^VERSION = "7\.7\.1\.2"$' "$RS")" = "1" || fail "4.1 $RS does not say VERSION = \"7.7.1.2\""
  test "$(cnt "App\.version = 'v7\.7\.1\.2'" dashboard/core/app-shell.js)" = "1" || fail "4.1 dashboard/core/app-shell.js does not say v7.7.1.2"
  test "$(cnt 'v7\.7\.1\.2' "$C3YAML")" = "2" || fail "4.1 $C3YAML does not name v7.7.1.2 twice"
  supplied T1
  t="$(first "$DM" "$TMP/T1.txt")"; t=$((t + $(wc -l < "$TMP/T1.txt")))
  for x in DeviceHistoryMeta DeviceSegmentHeader DeviceSegment EventEntry EventLog; do
    test "$(cnt "^static_assert\(sizeof\($x\) == [1-9][0-9]*, \"" "$DM")" = "1" || fail "4.3 one size assertion of $x with a number, in the form of the prompt"
    n="$(grep -nE "^static_assert\(sizeof\($x\) == " "$DM" | cut -d: -f1)"
    [ "$n" -ge "$t" ] || fail "4.3 the size assertion of $x must come after T1"
  done
  test -z "$(sed -n "$t,\$p" "$DM" | grep -v '^$' | grep -vE '^static_assert\(sizeof\((DeviceHistoryMeta|DeviceSegmentHeader|DeviceSegment|EventEntry|EventLog)\) == [1-9][0-9]*, "')" || fail "4.3 nothing but the five size assertions may follow T1"
  test "$(cnt '<MEASURED>' "$DM")" = "0" || fail "4.3 <MEASURED> is left in $DM"
  assembly_ok
  if [ "$mode" = "noimage" ]; then echo "CHECKPOINT D PASS (without the image)"; return; fi
  test -f "$C3BIN" || fail "4.4 $C3BIN is missing: compile the C3 build first (esphome compile $C3YAML)"
  [ "$C3BIN" -nt "$HDR" ] || fail "4.4 $C3BIN is older than $HDR: compile again"
  size="$(stat -c %s "$C3BIN")" || fail "stat"
  [ "$size" -le "$C3SLOT" ] || fail "4.4 the C3 image ($size B) does not fit the OTA slot ($C3SLOT B)"
  echo "C3 image: $size B of the OTA slot of $C3SLOT B ($((size * 1000 / C3SLOT / 10)).$((size * 1000 / C3SLOT % 10)) %)"
  echo "CHECKPOINT D PASS"
}

b_measure() {
  local w="$TMP/wt" x
  test -z "$(git status --porcelain)" || fail "commit first: the block measures the last commit"
  mkdir -p "$w" && git archive HEAD | tar -x -C "$w" || fail "git archive"
  printf '%s\n' 'wifi_ssid: "placeholder"' 'wifi_password: "placeholder"' 'gateway_mgmt_username: "placeholder"' 'gateway_mgmt_password: "placeholder"' > "$w/firmware/secrets.yaml"
  for x in DeviceHistoryMeta DeviceSegmentHeader DeviceSegment EventEntry EventLog; do
    printf 'static_assert(sizeof(%s) == 1, "p7-measure %s");\n' "$x" "$x" >> "$w/$HDR"
  done
  echo "measure: compiling a copy of $(git rev-parse --short HEAD) for the C3; this takes a few minutes"
  ( cd "$w" && esphome compile "$C3YAML" ) > "$TMP/measure.log" 2>&1
  python3 -I - "$TMP/measure.log" <<'PYEOF' || fail "the compiler did not report the five sizes: $(grep -m3 -E 'error' "$TMP/measure.log" | tr '\n' ' ' | head -c 400)"
import re, sys
log = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", open(sys.argv[1], encoding="utf-8", errors="replace").read()).split("\n")
want = ["DeviceHistoryMeta", "DeviceSegmentHeader", "DeviceSegment", "EventEntry", "EventLog"]
got = {}
for i, l in enumerate(log):
    m = re.search(r"static assertion failed: p7-measure (\w+)", l)
    if m:
        for k in log[i + 1:i + 7]:
            n = re.search(r"the comparison reduces to '\((\d+) == 1\)'", k)
            if n:
                got.setdefault(m.group(1), int(n.group(1)))
                break
if sorted(got) != sorted(want):
    sys.exit(1)
for w in want:
    print("sizeof %s = %d" % (w, got[w]))
PYEOF
  echo "measure PASS"
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
  local ip="${1:-}" want="${2:-}" mode="${3:-}" v up fh mh now out
  case "$ip" in 192.168.120.189|192.168.120.170) ;; *) fail "usage: dev <192.168.120.189 | 192.168.120.170> <version> [c3heap]: this step reads no other board" ;; esac
  [[ "$want" =~ ^v7\.7\.1\.[12]$ ]] || fail "usage: dev <IP> <v7.7.1.1 | v7.7.1.2> [c3heap]"
  [ -z "$mode" ] || { [ "$mode" = "c3heap" ] && [ "$ip" = "192.168.120.189" ]; } || fail "c3heap applies to 192.168.120.189 only"
  out="$(status_full "$ip" 2>&1)"
  [[ "$out" != ERROR* ]] || fail "${out#ERROR }"
  read -r v up fh mh now <<< "$out"
  [[ "$up" =~ ^[0-9]+$ ]] && [[ "$fh" =~ ^[0-9]+$ ]] && [[ "$mh" =~ ^[0-9]+$ ]] && [[ "$now" =~ ^[0-9]+$ ]] || fail "unexpected answer of $ip: $(head -c 200 <<< "$out")"
  echo "dev $ip: version $v, uptime $up s, free_heap $fh B, min_free_heap $mh B, boot $((now - up))"
  test "$v" = "$want" || fail "$ip reports $v, not $want"
  if [ "$mode" = "c3heap" ]; then # PLAN-045: at an uptime of 180 s or more, the higher of two readings 30 s apart
    local boot=$((now - up)) hi=0 k
    if [ "$up" -lt 180 ]; then echo "c3heap: the uptime is $up s; waiting $((180 - up)) s until 180 s"; sleep $((180 - up)); fi
    for k in 1 2; do
      [ "$k" = "1" ] || sleep 30
      out="$(status_full "$ip" 2>&1)"
      [[ "$out" != ERROR* ]] || fail "c3heap reading $k: ${out#ERROR }"
      read -r v up fh mh now <<< "$out"
      [[ "$up" =~ ^[0-9]+$ ]] && [[ "$fh" =~ ^[0-9]+$ ]] && [[ "$now" =~ ^[0-9]+$ ]] || fail "c3heap reading $k: unexpected answer of $ip: $(head -c 200 <<< "$out")"
      [ $((now - up)) -ge $((boot - 30)) ] && [ $((now - up)) -le $((boot + 30)) ] || fail "c3heap reading $k: the board started at $((now - up)), not within 30 s of $boot: it rebooted. STOP and report"
      echo "c3heap reading $k: uptime $up s, free_heap $fh B"
      [ "$fh" -gt "$hi" ] && hi="$fh"
    done
    [ "$hi" -ge 50032 ] || fail "the higher free_heap, $hi B, is more than 2,048 B below 52,080 B (CURRENT-STATE.md, v7.7.1.1 C3 value): STOP and report"
    echo "c3heap: the higher free_heap is $hi B, no more than 2,048 B below 52,080 B"
  fi
  echo "dev PASS"
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
  test "$v" = "v7.7.1.2" || fail ".170 reports $v, not v7.7.1.2"
  [ "$b" -ge $((boot - 120)) ] && [ "$b" -le $((boot + 120)) ] || fail "the board started at $b, not within 120 s of $boot: it rebooted after the upload. STOP and report"
  [ "$up" -ge 86400 ] || fail "the uptime is $up s, below 86,400 s: 24 hours have not passed; wait and run the block again"
  echo "wroom24 PASS"
}

b_E() {
  local log rec pr
  log="$(new_paths | grep '^Docs/')" && rec="$(new_paths | grep '^prompts/')" || fail "run the block scope first"
  pr="$(sed -E 's/.*-PR([0-9]+)-.*/\1/' <<< "$rec")"
  grep -q '^- \*\*Current version:\*\* 7\.7\.1\.2$' "$CS" || fail "6.1 $CS: '- **Current version:** 7.7.1.2'"
  sed -n 3p "$CS" | grep -q '^_Last verified: 20[0-9-]* .*v7\.7\.1\.2' || fail "6.1 $CS line 3: '_Last verified: <date> ...' naming v7.7.1.2"
  grep -q "^| v7\.7\.1\.2 | #$pr |" "$CS" || fail "6.1 $CS: a row '| v7.7.1.2 | #$pr |' in What Just Shipped"
  sed -n 4p "$CS" | grep -q 'v7\.7\.1\.3' && [ "$(sed -n 4p "$CS")" != "$(git show origin/main:"$CS" | sed -n 4p)" ] || fail "6.1 $CS line 4: a new next action that names v7.7.1.3"
  test "$(grep -E '^\| (esp32-c3-multi|sat-esp32-4m-170) \|' "$CS" | grep -c 'v7\.7\.1\.2')" = "2" || fail "6.1 $CS: firmware_now of .189 and .170 is v7.7.1.2"
  [ "$(grep '^| WROOM heap |' "$CS")" != "$(git show origin/main:"$CS" | grep '^| WROOM heap |')" ] || fail "6.1 $CS: the row 'WROOM heap' must hold the two readings of v7.7.1.2"
  [ "$(grep '^| `Docs/v7.7-v7.8-persistence-architecture.md` |' "$CS")" != "$(git show origin/main:"$CS" | grep '^| `Docs/v7.7-v7.8-persistence-architecture.md` |')" ] || fail "6.1 $CS: the row of the architecture doc in Stale Documents must change"
  grep '^| 8 | R4 |' "$POR" | grep -q "Done.*#$pr" || fail "6.2 $POR: row 8 says Done with #$pr"
  test "$(grep -c '^## \[v7\.7\.1\.2\]' "$CL")" = "1" || fail "6.3 $CL: one heading '## [v7.7.1.2]'"
  [ "$(grep -n '^## \[v7\.7\.1\.2\]' "$CL" | cut -d: -f1)" -lt "$(grep -n '^## \[v7\.7\.1\.1' "$CL" | head -n 1 | cut -d: -f1)" ] || fail "6.3 $CL: the entry of v7.7.1.2 comes before the one of v7.7.1.1"
  sed -n '/^## \[v7\.7\.1\.2\]/,/^## \[v7\.7\.1\.1/p' "$CL" > "$TMP/entry.txt"
  for x in $(grep -oE '^static_assert\(sizeof\([A-Za-z]+\) == [0-9]+' "$DM" | grep -oE '[0-9]+$'); do
    grep -qw -- "$x" "$TMP/entry.txt" || fail "6.3 the changelog entry does not give the measured size $x of $DM"
  done
  fence "$P" "**6.4** " "$TMP/n5.txt" || fail "6.4 fenced text 1"
  python3 -I - "$P" "$TMP/n6.txt" <<'PYEOF' || fail "6.4 fenced text 2"
import sys
l = open(sys.argv[1], encoding="utf-8").read().split("\n")
i = [k for k, x in enumerate(l) if x.startswith("**6.4** ")][0]
f = [k for k in range(i, len(l)) if l[k].startswith("```")]
open(sys.argv[2], "w", encoding="utf-8").write(l[f[2] + 1] + "\n")
PYEOF
  for x in "## 5. Storage Model: Per-Device Segments|n5" "## 6. NVS Key Scheme|n6"; do
    test "$(awk -v h="${x%|*}" '$0 == h { getline a; getline b; print a "|" b; exit }' "$ARCH")" = "$(head -n 1 "$TMP/${x#*|}.txt")|" \
      || fail "6.4 $ARCH: the note right after '${x%|*}', then one empty line"
  done
  test -f "$log" || fail "6.5 $log is missing"
  for x in 'RAM:' 'Flash:' 'sizeof DeviceSegment = ' 'dev 192.168.120.189: version v7.7.1.2' 'dev 192.168.120.170: version v7.7.1.2'; do
    grep -qF -- "$x" "$log" || fail "6.5 $log has no line with '$x'"
  done
  test -f "$rec" || fail "6.6 $rec is missing"
  python3 -I - "$rec" <<'PYEOF' || fail "6.6 the record (see the line above)"
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
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
  echo "CHECKPOINT E PASS"
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
  cmp -s "$P" "$SAVE/v7.7.1.2-agent-prompt-gpt-codex.md" || fail "the prompt differs from the saved one"
  cmp -s "$CF" "$SAVE/v7.7.1.2-checks.sh" || fail "the check file differs from the saved one"
  ( b_copy verify ) || exit 1
  ( b_A ) || exit 1
  ( b_B ) || exit 1
  ( b_C ) || exit 1
  ( b_D noimage ) || exit 1
  ( b_E ) || exit 1
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
#     Copilot and Gemini only, PLAN-045) ---
# They read the PR through `gh api` and change nothing. GHREPO, ROUNDS and CHECKS are set at the top of the file.

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
  if [ "$mode" = "final" ]; then
    head="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["head"]["sha"])' "$TMP/pull.json")" || fail "the head of PR #$pr"
    gh api "repos/$GHREPO/commits/$head/check-runs?per_page=100" > "$TMP/checks.json" 2>> "$TMP/gh.err" \
      || fail "gh api cannot read the check runs of $head: $(head -c 200 "$TMP/gh.err" | tr '\n' ' ')"
  fi
  out="$(python3 -I - "$TMP" "$mode" "$ROUNDS" "$CHECKS" <<'PYEOF'
import json, re, sys
d, mode, rounds, checks = sys.argv[1], sys.argv[2], sys.argv[3].split("|"), sys.argv[4].split("|")
pull = json.load(open(d + "/pull.json", encoding="utf-8"))
comments = json.load(open(d + "/comments.json", encoding="utf-8"))
runs = json.load(open(d + "/checks.json", encoding="utf-8")).get("check_runs") or []
body, head, bad = (pull.get("body") or "").replace("\r\n", "\n"), pull["head"]["sha"], []
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
m = re.search(r"(?ms)^## Round Summary\s*$(.*?)(?=^## |\Z)", body)
rows = {}
for l in (m.group(1) if m else "").split("\n"):
    for r in rounds:
        if l.startswith("| %s |" % r):
            rows.setdefault(r, []).append(l)
posted = {"Inline": not pull.get("draft"),
          "Review A": any((c.get("body") or "").lstrip().startswith("## Review A") for c in comments),
          "Review B": any((c.get("body") or "").lstrip().startswith("## Review B") for c in comments),
          "Review C": any((c.get("body") or "").lstrip().startswith("## Review C") for c in comments)}
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
if mode == "final":
    if len(runs) >= 100:
        bad.append("the head has 100 or more check runs: this block reads only the first 100")
    for entry in checks:
        name, _, need = entry.partition("=")
        mine = [x for x in runs if x.get("name") == name or (x.get("name") or "").startswith(name + " (")]
        if not mine:
            bad.append("no check run '%s' on the head %s" % (name, head[:7]))
        elif need and len({x.get("name") for x in mine}) < int(need):
            bad.append("%d distinct jobs '%s (...)' on the head %s, not %s" % (len({x.get("name") for x in mine}), name, head[:7], need))
    latest = {}
    for x in runs:  # a name can have several runs on one head (each edit of the body starts pr-body-check): the latest counts
        k = x.get("name") or ""
        key = (x.get("started_at") or "9999", x.get("id") or 0)  # a queued run has no start yet: it counts as the latest
        if k not in latest or key >= latest[k][0]:
            latest[k] = (key, x)
    latest = {k: v[1] for k, v in latest.items()}
    for k, x in sorted(latest.items()):
        if x.get("status") != "completed":
            bad.append("the latest check run '%s' on the head is %s" % (k, x.get("status")))
        elif x.get("conclusion") not in ("success", "skipped", "neutral"):
            bad.append("the latest check run '%s' on the head ended %s" % (k, x.get("conclusion")))
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PYEOF
)" || fail "$(printf '%s' "$out" | tr '\n' '|')"
  [ "$mode" = "final" ] && echo "body final PASS" || echo "body PASS"
}

case "$NAME" in
  sec2) b_sec2 ;;
  scope) b_scope "${2:-}" "${3:-}" ;;
  copy) b_copy "${2:-}" ;;
  insert) b_insert "${2:-}" ;;
  A|B|C|D|E) "b_$NAME" ;;
  measure) b_measure ;;
  dev) b_dev "${2:-}" "${3:-}" "${4:-}" ;;
  wroom24) b_wroom24 "${2:-}" ;;
  prepr) b_prepr ;;
  inline) b_inline "${2:-}" ;;
  body) b_body "${2:-}" "${3:-}" ;;
  *) echo "usage: bash $0 <sec2 | scope <PR#> <YYYY-MM-DD> | copy [verify] | insert <S1|T1|T2> | A | B | C | D | measure | dev <IP> <version> [c3heap] | wroom24 <epoch> | E | prepr | inline <PR#> | body <PR#> [final]>"; exit 2 ;;
esac
