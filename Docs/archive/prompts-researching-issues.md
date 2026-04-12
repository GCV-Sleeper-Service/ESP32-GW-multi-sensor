Order and dependency notes
Session	Issues	Dependency
A	#144, #170, #143	Independent — start anytime
B	#166, #171	Independent — start anytime
C	#161, #162	Independent, but #162 answer depends on #161 diagnosis
D	#164, #165	Independent — but informs Session E
E	#163	Best after D — security auth cost analysis needs memory budget from #164
So the only real ordering constraint is D before E. A, B, C, and D can all run in any order or in parallel if you have multiple sessions open.


SESSION A PROMPT
Covers: #144, #170, #143 — Dashboard card DOM/JS issues
--
Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Current branch: main
Date: 2026-04-12

## Goal
Research and rewrite GitHub issues #144, #170, and #143 with accurate, specific, 
actionable content matching the quality standard of issues #136–139 and #143.
The rewritten issues must be detailed enough to write a coding agent prompt from 
directly, following the format and content used in `prompts/handoff/phaseY/phase-y-two-session-prompts-Claude.md`.

## Context
- Phase Y decomposed sensor_history_multi.h into 8 fragments in firmware/core/
- The assembled dashboard/sensor_history_multi.h is the live firmware file
- dashboard/dashboard.tmpl.html is the template; dashboard.html is generated
- The gateway card uses DEVICE_INFO_MAP populated via SSE state events (BUG-082 pattern)
- issue #136 (hardcoded C3 Flash/SRAM values) is the quality benchmark for specificity

## Step 1 — Read these files completely and in order

1. Read `dashboard/dashboard.tmpl.html`
   - Find the gateway card section (device info fields, DOM IDs, structure)
   - Find the satellite gateway card section (how satellites are rendered)
   - Find the footer section (version display, App.version reference)
   - Note all `id="di-*"` attributes in the gateway card
   - Note how the satellite card is currently built (static HTML? JS-generated?)

2. Read the dashboard JS module that handles SSE state events and populates DEVICE_INFO_MAP
   - Find where DEVICE_INFO_MAP is defined
   - Find the MAC address field entry — what is its `id` and where does it get data from?
   - Find where `App.version` is set and what value it gets
   - Find how satellite gateway cards are built/updated (pollAggregatorLive? template? innerHTML?)

3. Read `firmware/core/web-handler.h`
   - Find the `/api/manifest` handler — what fields does it return? Does it include device_name?
   - Find the SSE state event handler — what fields does it push? Does it include firmware version?
   - Find the aggregator `/api/aggregator/gateways` handler — what does a satellite entry contain?
     Specifically: does it include name/hostname? IP? any version field?

4. Read `prompts/prompt-index-and-workflow.md` §Critical Rules — note rules relevant to 
   dashboard template edits, SSE fields, and DEVICE_INFO_MAP changes.

## Step 2 — For each issue, answer these specific questions

### Issue #144 — Update gateway card
- Which exact DOM element currently shows MAC address? (`id="di-mac"` or similar?)
- Is there currently a firmware version field in DEVICE_INFO_MAP? If not, does the SSE 
  state event provide firmware version data? If not, what would need to change in firmware?
- Does /api/manifest currently include a device_name or friendly_name field?
- What are "ESPHome" and "Framework" fields currently — which DOM IDs, what SSE keys feed them?
- Is there a "Documentation section" in the current dashboard UI? If yes, what DOM structure?

### Issue #170 — Rework satellite gateway display card
- How is the satellite card currently rendered — is it a static template in dashboard.tmpl.html 
  or dynamically built via JS innerHTML?
- Does the /api/aggregator/gateways response currently include a satellite name/hostname?
  If yes, what is the field name? If no, where would it need to be added in firmware?
- Does it currently show IP? If yes, which element?
- What does the screenshot in the issue show is missing vs what should be there?

### Issue #143 — No visible version badge
- Where exactly is App.version set in the JS? What value (e.g. hardcoded string? from manifest?)
- What does the footer currently look like in dashboard.tmpl.html?
- Is there already a span/element for version, or is version only in lastUpdate span?
- Does App.version need to come from the manifest response or is it a compile-time constant?

## Step 3 — Rewrite each issue

For each of #144, #170, #143, produce a rewritten GitHub issue body that includes:
- **Current behaviour** — exact DOM IDs, JS variable names, or endpoint field names involved
- **Problem** — precisely what is wrong or missing, referencing specific code locations
- **Proposed fix** — step-by-step: which file changes, which new DOM IDs, which SSE/manifest 
  fields to add or repurpose, which JS functions to update
- **Acceptance criteria** — specific, testable (e.g. "di-device-name shows hostname from manifest")
- **Effort estimate** and **dependencies** (e.g. "depends on firmware manifest change")
- **Critical Rules** that apply

Keep the title of each issue unchanged. Output format: one fenced markdown block per issue.



SESSION B PROMPT
Covers: #166, #171 — Data export format + export logic location

--
Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Current branch: main
Date: 2026-04-12

## Goal
Research and rewrite GitHub issues #166 and #171 with accurate, specific, actionable 
content matching the quality standard of issues #136–139.
These two issues are tightly coupled: #171 (where does export logic live?) must be 
answered before #166 (what should the export format be?) can be fully specified.

## Context
- Issue #166: Fix data export format — defines desired CSV schema with hostname, ip, role,
  timestamp, datetime_utc, then per-sensor columns named {sensor_name}_{metric}_{unit}
- Issue #171: Data export logic — asks whether export is done on-board (firmware) or 
  client-side (dashboard JS), and proposes moving heavy lifting to dashboard
- Endpoints #14–18 (import/export cycle) are a known deferred bug: they crash ESP32-C3 
  on execution (pre-existing, noted in phaseY-results.md). This context matters for #171.
- Phase 7 (v7.7.2.0–v7.7.2.2) includes per-device CSV export/import — these issues 
  may need to align with or inform Phase 7 scope.

## Step 1 — Read these files completely and in order

1. Read `firmware/core/web-handler.h`
   - Find all export-related handlers — search for "export", "csv", "import", "begin", 
     "finish" to identify endpoints #14–18
   - For the export handler: what does it currently write? What fields/columns? 
     What HTTP response headers (Content-Type, Content-Disposition)?
   - For the import handlers (begin/data/finish): what is the expected input format?
     Does it expect the same column schema as export produces?
   - Note exact handler function names, endpoint paths, and HTTP method (GET/POST)

2. Read `firmware/core/nvs-persistence.h`
   - What does the history data structure look like? What fields are stored per entry?
     (timestamp, value, sensor index, etc.)
   - What is the current NVS key scheme — per-sensor? per-device?

3. Read the dashboard JS module that handles export (search for "export", "download", 
   "blob", "CSV" in dashboard source modules under dashboard/core/ or dashboard/components/)
   - Is there any client-side CSV generation logic?
   - Is there an export button handler? What endpoint does it call?
   - Does the dashboard do any format transformation or does it just relay the firmware response?

4. Read `Docs/v7.7-v7.8-persistence-architecture.md` §CSV export sections (v7.7.2.x)
   - What CSV format does Phase 7 plan to use?
   - Is there a per-device or per-sensor column scheme already specified?
   - How does the Phase 7 plan handle aggregator-level bundle export?

5. Read `prompts/prompt-index-and-workflow.md` — note Phase 7 v7.7.2.0–v7.7.2.2 step 
   descriptions and any export-related Critical Rules.

## Step 2 — Answer these questions

### For #171 — Export logic location
- Is export currently implemented on-board (firmware generates CSV) or client-side?
- If on-board: what does the firmware actually stream/send as the export response body?
- What is the crash condition on ESP32-C3 for endpoints #14–18 — is it the export GET 
  handler that crashes, or the import POST handlers, or both?
- What would "moving heavy lifting to dashboard" concretely mean — 
  fetch raw JSON history from existing /api/v2/history/<sensor> endpoint and 
  format CSV in JS? Or something else?
- Is this a pre-Phase-7 fix or should it be deferred to Phase 7 v7.7.2.x?

### For #166 — Export format
- What does the current export CSV actually contain (columns, header row, date format)?
- Does the desired schema in issue #166 (hostname, ip, role, timestamp, datetime_utc, 
  sensor columns) match or conflict with anything in the Phase 7 persistence architecture plan?
- For aggregator exports: does the /api/aggregator/gateways response provide enough data
  to prepend satellite name to column headers, or does the aggregator need to fetch from 
  each satellite's export endpoint?
- What is the current column naming convention vs the proposed {sensor_name}_{metric}_{unit}?

## Step 3 — Rewrite each issue

For each of #171 and #166, produce a rewritten GitHub issue body that includes:
- **Current behaviour** — exact endpoint paths, function names, what the firmware currently does
- **Problem** — precisely what is wrong, with specific code references
- **Proposed fix** — concrete steps: which file changes, new/modified endpoints, 
  JS changes, format specification with example CSV header row
- **Relationship to Phase 7** — does this need to land before Phase 7, or is it Phase 7 scope?
- **Acceptance criteria** — specific and testable
- **Effort and dependencies**
- **Critical Rules** that apply (especially Rules 8, 38, 39 re: POST handling)

Keep the title of each issue unchanged. Output format: one fenced markdown block per issue.
For each issue, provide rewritten issue body for each issue as a separate downloadable markdown file

SESSION C PROMPT
Covers: #161, #162 — Aggregator history proxy bug + architectural decision

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Current branch: main
Date: 2026-04-12

## Goal
Research and rewrite GitHub issues #161 and #162 with accurate, specific, actionable content.
#161 is a confirmed bug (empty body from history proxy). #162 is an architectural decision
that depends on understanding #161 first.

## Context
- #161 is a known deferred gap from Phase Y: "History proxy (GET /api/aggregator/proxy/…) 
  returns empty body. First seen in v7.6.6.6." This means a diagnosis may already exist 
  in the v7.6.6.6 audit document.
- The proxy endpoint path is: GET /api/aggregator/proxy/{satellite_ip}/history/{room}/{metric}
- Critical Rule 8: Never use beginResponseStream for responses >10KB
- Critical Rule 27: ESPHome IDF socket calls must use lwip_* prefixed functions
- Critical Rule 24: esp_get_free_heap_size() includes PSRAM — report both separately

## Step 1 — Read these files completely and in order

1. Check if the Phase Y v7.6.6.6 audit document exists and read it:
   `prompts/phaseY/v7.6.6.6-PR*-consolidated-audit-and-lessons.md`
   (the exact PR number is unknown — list the directory to find it)
   - Look for any diagnosis of the history proxy empty body bug
   - Was a root cause identified? Was a fix attempted and reverted?

2. Read `firmware/core/aggregator-runtime.h`
   - Find the proxy handler for `/api/aggregator/proxy/...`
   - Understand exactly what it does: does it open a TCP connection to the satellite?
     Does it use lwip_* socket calls? Does it use beginResponseStream or chunked transfer?
   - What does "returns empty body" most likely mean at the code level — 
     is the response started but body never written? Handler returns before writing? 
     Socket read fails silently?
   - Find `SatelliteCache` — does it cache history data? Could the proxy be trying to 
     serve from cache when cache is empty?

3. Read `firmware/core/web-handler.h`
   - Find the satellite history endpoint handler (`/api/v2/history/<sensor>`) 
   - What does it return — chunked? single response? what size can it be?
   - How does this compare to what the proxy handler tries to forward?

4. Read `firmware/core/nvs-persistence.h` briefly — 
   understand the max size of a history response for one sensor 
   (how many entries × how many bytes each)

5. Read `Docs/lessons/firmware.md` and `Docs/lessons/operations.md`
   - Search for any proxy-related bugs or socket-related lessons
   - Note any LESSON entries about HTTP forwarding, response streaming, or socket calls

## Step 2 — Answer these questions

### For #161 — Fix aggregator history proxy
- What is the proxy handler doing, specifically? (socket connect → read → write to response?)
- What is the most likely root cause of empty body?
  Option A: lwip socket calls — was this fixed with lwip_* in other handlers but missed here?
  Option B: Response size exceeds beginResponseStream limit (Rule 8)?
  Option C: History endpoint on satellite returns chunked/streamed response that the proxy 
             doesn't handle correctly?
  Option D: Something else found in the code?
- Is there already a diagnosis in the v7.6.6.6 audit?
- What is the minimal fix vs the correct fix?

### For #162 — Architectural decision on satellite history
- Given the proxy bug diagnosis from #161, which option makes more sense:
  Option 1 (iframe embed) or Option 2 (copy/sync data to aggregator)?
- What are the concrete memory implications of Option 2 given issue #139 
  (history loading causes C3 heap exhaustion) and the C3's 400KB SRAM?
- Does the aggregator S3 have enough flash/PSRAM to cache satellite history?
  (S3: 16MB flash, 8MB PSRAM from issue #138)
- What does Phase 7 v7.7.2.2 ("Multi-device bundle export/import") imply about 
  the intended long-term architecture?

## Step 3 — Rewrite each issue

For #161, produce a rewritten issue body that includes:
- **Current behaviour** — exact curl command that fails, exact endpoint path
- **Root cause** — specific code location and mechanism (after reading the proxy handler)
- **Proposed fix** — exact code change needed (function name, what to change)
- **Acceptance criteria** — `curl -s "http://{agg_ip}/api/aggregator/proxy/{sat_ip}/history/{room}/{metric}"` 
  returns populated JSON matching direct satellite endpoint
- **Critical Rules** that apply
- **Effort** and whether this blocks anything

For #162, produce a rewritten issue body that includes:
- **Problem statement** — clear framing of the architectural tension
- **Option analysis** — concrete pros/cons of each option given actual code constraints 
  (not just general tradeoffs), referencing #139, #161, flash/PSRAM sizes
- **Recommended path** — a specific recommendation with rationale, or a specific 
  decision gate if more information is needed first
- **Relationship to Phase 7** — how this aligns with or should inform v7.7.2.x planning
- **Acceptance criteria** — what "resolved" looks like (may be a decision record, not code)

Output format: one fenced markdown block per issue.
For each issue, provide rewritten issue body for each issue as a separate downloadable markdown file



SESSION D PROMPT
Covers: #164, #165 — Memory footprint on satellites + Code optimization

Note: These two are combined. Memory footprint (#164) and code optimization (#165) share the same investigative ground — both require reading all 8 fragments looking for allocations, dead weight, and reduction opportunities. Running them separately would mean reading the same files twice.

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Current branch: main
Date: 2026-04-12

## Goal
Research and rewrite GitHub issues #164 (memory footprint on satellites) and #165 
(code optimization) with accurate, specific, actionable content matching the quality 
standard of issues #136–139.

These two issues share investigative ground and are combined into one research session.

## Context
- ESP32-C3 SuperMini: 400 KB SRAM, no PSRAM. Free heap on fresh boot = ~55KB (was >75KB 
  several releases ago — regression of >20KB over recent phases)
- Critical Rule 24: esp_get_free_heap_size() includes PSRAM — report internal and total 
  heap separately. On C3 there is no PSRAM so they are the same.
- Critical Rule 8: Never use beginResponseStream for responses >10KB — indicates 
  response buffering is already a known heap pressure point
- Critical Rule 9: dashboard.h must be gzip-compressed — HTML is served compressed, 
  but the httpd task still needs to buffer and stream it
- Critical Rule 42: All board profiles must include external_components block for patched 
  web_server_idf component — the httpd task stack is relevant to heap accounting
- Phase Y fragments are now in firmware/core/ — each fragment can be read independently

## Step 1 — Read these files completely and in order

1. Read `firmware/core/config.h` (95 lines)
   - What compile-time constants are defined?
   - Are there any buffer size constants, queue depths, or task stack sizes?
   - Are there any C3-specific vs S3-specific conditional blocks?

2. Read `firmware/core/data-model.h` (460 lines)
   - What are the runtime data structures? What is their sizeof footprint?
   - How many entries in the history buffer per sensor? What is the struct size per entry?
   - Is the history buffer statically allocated (global array) or heap-allocated?
   - Are there any arrays sized by NUM_SENSORS or NUM_DEVICES that scale with config?

3. Read `firmware/core/nvs-persistence.h` (614 lines)
   - Are there any large stack-local buffers in NVS scan functions?
   - Does restore_from_nvs() allocate heap temporarily? How much?
   - Does persist_hourly_segment() allocate heap? Is it freed promptly?
   - Any static buffers or global allocations?

4. Read `firmware/core/aggregator-runtime.h` (891 lines)
   - Note: this is aggregator-only (AGGREGATOR_ENABLED guard). Satellite builds exclude this.
   - Confirm the #if AGGREGATOR_ENABLED guard is present so none of this lands on C3.
   - What is the SatelliteCache size? Is it PSRAM-allocated?

5. Read `firmware/core/web-handler.h` (2006 lines) — focus on:
   - The HTTP server initialization: how many simultaneous connections? What is the 
     send/receive buffer size per connection?
   - The SSE handler: does it keep an open connection? Does it allocate a persistent buffer?
   - The dashboard.h serve handler: how is the gzip blob served? 
     Is it streamed in chunks or sent as one response?
   - The history handler (/api/v2/history/<sensor>): how is the JSON response built?
     Is it assembled in a heap-allocated string or streamed?
   - Any response buffers that are statically allocated vs stack-local vs heap-allocated
   - Look for any `static char buf[]` or `static uint8_t[]` globals — these consume SRAM 
     permanently regardless of whether a request is in flight

6. Read `firmware/core/ping-adapter.h` (168 lines)
   - Does PingAdapter allocate heap? Keep any persistent state?
   - Is it guarded by #ifdef PING_DEVICE_INDEX so it's zero-cost when not configured?

7. Read `firmware/core/deferred-management.h` (50 lines)
   - Task stack sizes for deferred reboot/delete tasks
   - Are these tasks created at boot (permanent stack cost) or on-demand?

8. Read `firmware/core/registration.h` (41 lines)
   - What is wired at boot? How many tasks are started?

9. Read both board YAML configs to understand task/heap configuration:
   - `firmware/esp32-c3-multi-sensor.yaml` (committed C3 config)
   - Look for: esp32_ble_tracker config (BLE scanning stack/buffer), 
     web_server config, logger config, any custom task stacks

10. Read `Docs/lessons/firmware.md`
    - Find all heap/memory related lessons and bugs
    - Note any specific regression points that increased heap usage

11. Read `Docs/lessons/operations.md`  
    - Find LESSON-OPS entries related to memory, buffers, response sizing

## Step 2 — Build a heap consumption inventory

Produce a table with every identified SRAM consumer on the C3 satellite, categorized as:
- **Static/global** — allocated at link time, always present
- **Task stack** — allocated at boot, permanent
- **Runtime heap** — allocated during operation (HTTP request handling, NVS ops, etc.)
- **ESPHome runtime** — BLE scanner, WiFi stack, ESPHome core (estimate from lessons/known values)

For each item, note: size (if determinable from code), whether it is C3-specific or shared,
and whether it existed before Phase D (i.e. pre-regression baseline).

## Step 3 — Identify optimization candidates

For each of the following categories, identify specific, concrete opportunities:
1. **Response buffer reduction** — any handler building a response in a large heap string 
   that could be streamed in chunks instead (respecting Rule 8)
2. **Static buffer elimination** — any `static char[]` that could be stack-local or eliminated
3. **Task stack right-sizing** — any task with an oversized stack allocation
4. **Compile-conditional dead code** — any code included in C3 satellite build that is 
   never reachable (e.g. aggregator paths not guarded, ping paths not guarded)
5. **Dashboard HTML size** — is the gzip-compressed dashboard.h smaller than the pre-Phase-X 
   monolith? If dashboard size increased, that affects HTTP serve time and httpd buffer pressure
6. **ESPHome config knobs** — logger level, BLE scan window, connection count limits

## Step 4 — Rewrite each issue

### For #164 — Memory footprint on satellites
Produce a rewritten issue body including:
- **Current state** — free heap at boot = ~55KB, regression from >75KB
- **Heap consumption inventory** — the table from Step 2 (top consumers identified)
- **Regression source** — which phase(s) introduced the >20KB regression, if identifiable
- **Proposed investigation steps** — specific measurements to take on device to confirm 
  the inventory (e.g. specific esp_get_free_internal_heap_size() calls at boot stages)
- **Proposed fixes** — ranked by effort vs expected gain, with specific file/function targets
- **Acceptance criteria** — target free heap value (e.g. ">70KB free internal heap at 
  dashboard open with 3 sensors configured")
- **Dependencies** — does this block or relate to #139 (history loading crash)?

### For #165 — Code optimization
Produce a rewritten issue body including:
- **Scope** — what "optimization" means concretely for this codebase (memory, not CPU)
- **Specific opportunities** — the list from Step 3, with file:line references
- **Prioritized action list** — which optimizations give the most heap back for least risk
- **Out of scope** — what NOT to do (e.g. do not touch fragment boundaries, Rule 62)
- **Relationship to #164** — these are complementary; suggest which to tackle first
- **Acceptance criteria**

Output format: one fenced markdown block per issue.
For each issue, provide rewritten issue body for each issue as a separate downloadable markdown file



SESSION E PROMPT
Covers: #163 — Security hardening

Repo — https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
Current branch: main
Date: 2026-04-12

## Goal
Research and rewrite GitHub issue #163 (security hardening) with accurate, specific, 
actionable content. The output must be detailed enough to write a coding agent prompt 
from directly, following the format used in the Phase Y two-session prompts.

## Context
- The aggregator (S3) is more frequently exposed to the internet — this is the primary 
  threat surface
- The satellite (C3) has 400KB SRAM — any auth mechanism must be evaluated for 
  heap cost impact (see issue #164)
- Critical Rule 38: all dashboard fetch() POST calls use Content-Type: 
  application/x-www-form-urlencoded — auth headers must be compatible with this
- Critical Rule 39: all curl POST commands use -d 'a=1' — same constraint
- Known issue: endpoints #14–18 (import/export) crash ESP32-C3 — a crash from a bare 
  curl command is the exact scenario issue #163 wants to prevent
- ESPHome web_server component already has basic auth support — this may already be 
  partially implemented

## Step 1 — Read these files completely and in order

1. Read `firmware/core/web-handler.h` — do a complete auth audit:
   - Which handlers currently check for authentication before executing?
   - What is the current auth mechanism? (HTTP Basic Auth? token? ESPHome built-in?)
   - What is the exact code path for auth checking — is it a shared function or 
     duplicated per handler?
   - Which handlers are UNAUTHENTICATED (GET endpoints accessible without credentials)?
     List every one: path, method, what it exposes
   - Which handlers are AUTHENTICATED (require credentials)?
     List every one: path, method, what auth mechanism
   - Are there any handlers that perform destructive operations (reboot, delete-data, 
     reset-satellites, add/remove satellite) without auth?
   - Is there any rate limiting, request throttling, or DOS protection?
   - Is there any input validation on POST body parameters that could prevent 
     malformed requests from crashing the handler?

2. Read both board YAML configs:
   - `firmware/esp32-c3-multi-sensor.yaml`
   - Check: is `web_server: auth:` configured? What username/password is set?
   - Is there any `api:` encryption configured?
   - Is there any firewall/access list in ESPHome config?

3. Read `firmware/boards/` directory listing — check if board-specific security 
   config exists in any board profile YAML

4. Read `Docs/lessons/firmware.md` and `Docs/lessons/operations.md`
   - Find any security-related bugs or lessons
   - Find any lessons about crash-inducing requests or input validation failures

5. Read `Docs/architecture-overview.md`
   - What is the documented network topology? Is the aggregator directly internet-exposed 
     or behind a router/NAT?
   - Is there any existing security architecture described?

## Step 2 — Produce the auth/exposure audit table

Build a complete table of all HTTP endpoints across both board types:

| Path | Method | Board | Authenticated? | Destructive? | Exposes sensitive data? | Notes |
|------|--------|-------|---------------|-------------|------------------------|-------|

Flag every unauthenticated+destructive combination as HIGH RISK.
Flag every unauthenticated endpoint that exposes sensor data or device info as MEDIUM RISK.

## Step 3 — Answer the specific questions from issue #163

1. **Should all API calls be authenticated?**
   - What is the heap cost of HTTP Basic Auth per request on C3? 
     (base64 decode, string compare — is this measurable?)
   - What is the impact on the dashboard's SSE connection if auth is required?
     (SSE is a long-lived connection — does it re-authenticate?)
   - What is the impact on the aggregator's satellite polling if satellites require auth?
     (aggregator makes HTTP requests to satellites — does it need to supply credentials?)
   - Recommendation: which endpoints MUST be authenticated vs which CAN be public?

2. **How to prevent crashing boards with simple curl commands?**
   - Which specific endpoints currently crash on ESP32-C3? (from #161, #139, known issues)
   - Is the crash from: (a) unauthenticated access allowing the handler to run, 
     (b) the handler logic itself crashing regardless of auth, or (c) both?
   - What input validation would prevent crash-inducing requests from reaching the 
     crash-prone code paths?

3. **What else?**
   - Should the aggregator's satellite management endpoints (add/remove/reset) be 
     additionally protected beyond basic auth? (e.g. confirm token, rate limit)
   - Is HTTPS feasible on ESP32-C3/S3 given memory constraints?
   - Is there a lightweight alternative (e.g. pre-shared key in custom header)?

## Step 4 — Rewrite issue #163

Produce a rewritten issue body that includes:
- **Threat model** — who is the attacker, what is the attack surface 
  (LAN vs internet-exposed aggregator), what are the realistic threats
- **Current state audit** — the endpoint table from Step 2, highlighting HIGH/MEDIUM risks
- **Specific vulnerabilities** — ranked by severity, with exact endpoint paths and 
  handler function names
- **Proposed fixes** — broken into:
  - Quick wins (auth already partially implemented — extend coverage)
  - Medium effort (input validation, rate limiting)
  - Longer term (HTTPS, per-endpoint ACL)
- **Memory cost analysis** — impact of each fix on C3 free heap
- **Aggregator-satellite interaction** — how auth on satellites affects aggregator polling
- **Acceptance criteria** — what "hardened" means concretely
- **Out of scope** — what is explicitly deferred (e.g. HTTPS if memory-prohibitive)
- **Dependencies** — #164 (memory budget must be known before adding auth overhead)
- **Critical Rules** that apply (38, 39, 40, 8)

Output format: one fenced markdown block.
For each issue, provide rewritten issue body for each issue as a separate downloadable markdown file
