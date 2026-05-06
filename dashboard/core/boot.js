function updateBoardInfo() {
  var manifest = window._manifest;
  if (!manifest || !manifest.gateway) return;
  var hw = manifest.gateway.hardware || '';
  var isC3 = hw.indexOf('C3') !== -1;
  // Hide C3-specific content on non-C3 boards (Principle 4: no cross-board info leakage)
  if (!isC3) {
    // Hide C3 SuperMini SVG photo
    var pinout = document.getElementById('pinoutDiagram');
    if (pinout) pinout.style.display = 'none';
    // Hide GPIO pinout card (C3-specific pin table)
    var gpioCard = document.getElementById('gpioCard');
    if (gpioCard) gpioCard.style.display = 'none';
    // Update About card title to reflect actual board
    var aboutTitle = document.getElementById('aboutCardTitle');
    if (aboutTitle) aboutTitle.textContent = (manifest.gateway.name || hw || 'ESP32') + ' Gateway';
    // Hide C3-specific description
    var c3Desc = document.getElementById('c3DescriptionBlock');
    if (c3Desc) c3Desc.style.display = 'none';
  }
}

// ── Boot entrypoint (exported for testing) ─────────────────────
// v7.5.5.3-hotfix: Unified boot path. Per Principle 1 ("roles are capability tiers"),
// the aggregator runs the FULL satellite pipeline (local sensors, SSE/polling,
// storage stats, telemetry, history) and THEN overlays the aggregator UI.
App.Boot.start = function() {
  var modeStr = TRANSPORT === 'sse' ? (ESP_HOST === '' ? 'HOSTED' : 'SSE') : 'POLLING';
  document.getElementById('modeLabel').textContent = '[' + modeStr + ' mode]';
  detectAggregatorMode().then(function(isAggregator) {
    // Both satellite and aggregator share the same pipeline.
    // v7.5.3.0: sequence manifest v2 load before sensor manifest load
    // to ensure window._manifest is available when buildDeviceCards() runs
    loadManifestV2().then(function(manifest) {
      window._manifest = manifest;
      dlog('[manifest] v2 manifest stored (source: ' + (manifest.source || 'unknown') + ')', 'ok');
    }).catch(function(e) {
      dlog('[manifest] loadManifestV2 failed: ' + e.message, 'err');
      window._manifest = null;
    }).then(function() {
      // BUG-043-cont Fix 1: if v2 manifest already has sensor data, skip the second
      // /api/manifest fetch that loadSensorManifest() would issue. Fall back to
      // loadSensorManifest() only when the v2 manifest returned no sensor entries.
      if (window._manifest && window._manifest.sensors && window._manifest.sensors.length) {
        var meta = normalizeManifestSensors(window._manifest);
        applySensorMeta(meta);
        dlog('[manifest] Sensors loaded from v2 manifest cache (' + meta.length + ' sensors, no second fetch)', 'ok');
        return Promise.resolve();
      }
      return loadSensorManifest();
    }).then(function() {
      updateBoardInfo();
      dlog('init - ' + SENSORS.length + ' sensors, transport=' + TRANSPORT + ', host=' + (ESP_HOST || '(same-origin)'));
      buildSensorCards();
      try { initCharts(); setHistoryRange(24); } catch(e) { dlog('initCharts: ' + e.message, 'err'); showError('Chart init failed'); }
      // BUG-069: Hide environmental chart sections when no env sensors exist.
      // The aggregator with only WAN ping has no temperature/humidity data —
      // showing empty "waiting for sensor data..." charts is confusing UX.
      // Note: makeSensorConfig() does not set .category (environmental is implied
      // when absent). Only makeNetworkSensorConfig() sets it explicitly.
      var hasEnvSensors = SENSORS.some(function(s) { return !s.category || s.category === 'environmental'; });
      if (!hasEnvSensors) {
        ['hdr-realtime', 'body-realtime', 'divider-charts', 'hdr-averages', 'body-averages'].forEach(function(id) {
          var el = document.getElementById(id);
          if (el) el.style.display = 'none';
        });
      }
      // BUG-037: Startup request staggering — spread non-critical requests across 5s
      // to avoid overwhelming the ESP32-C3 HTTP server (~4-7 concurrent connections).
      // See Docs/dashboard-stability-remediation-plan.md for full rationale.

      probeAuth().then(function(authState) {
        if (authState !== 'required') return true;
        return requestAuth('dashboard access').then(function() { return true; }, function(err) {
          dlog('auth bootstrap failed: ' + err.message, 'err');
          return false;
        });
      }).then(function() {
        var firstStatusSnapshotPromise = Promise.resolve(false);
        historyBootstrapConsumed = false;

        // v7.5.4.2: Start /api/v2/live polling for network card live data updates.
        // Network devices do not appear in SSE state events, so a periodic poll is needed.
        setInterval(pollV2Live, 15000);
        pollV2Live(); // initial fetch

        // BUG-043-cont (PR2) Fix A: In SSE mode, start the event stream first, then defer the
        // status snapshot ~2s. SSE 'state' events already carry initial live state so an
        // immediate /api/status call is unnecessary and adds pressure during the fragile
        // connection-open window. Polling mode is unchanged — startPolling() handles its
        // own status fetch after the deferred sequential initial poll completes.
        if (TRANSPORT === 'sse') {
          try { connectSSE(); } catch(e) { dlog('SSE: ' + e.message, 'err'); showError('SSE failed'); }
          firstStatusSnapshotPromise = new Promise(function(resolve) {
            setTimeout(function() {
              resolve(loadStatusSnapshot().catch(function(){ return false; }));
            }, 2000);
          });
        } else {
          try { startPolling(); } catch(e) { dlog('Polling: ' + e.message, 'err'); showError('Polling failed'); }
          firstStatusSnapshotPromise = loadStatusSnapshot().catch(function(){ return false; });
        }

        // BUG-043-cont (PR2) Fix D: Defer storage stats from 3s to 5s — reduces overlap with
        // the sequential initial poll (which now takes ~7-8s at batch=1, 200ms gap).
        setTimeout(function() {
          if (isImportActive()) return;
          loadStorageStats().catch(function(){});
          // BUG-037 Fix 8: storage stats interval increased from 60s to 120s
          // (storage stats change only on NVS persist cycles, roughly every 60 minutes)
          storageStatsIntervalId = setInterval(function() {
            if (isImportActive()) return;
            loadStorageStats().catch(function(){});
          }, 120000);
        }, 5000);

        // BUG-037 Fix 5: 30s status interval only in polling mode — in SSE mode,
        // state is delivered via SSE events, so periodic /api/status polling is unnecessary
        if (TRANSPORT !== 'sse') {
          statusSnapshotIntervalId = setInterval(function() {
            if (isImportActive()) return;
            loadStatusSnapshot().catch(function(){});
          }, 30000);
        }

        // v7.6.9.4 (#139 partial): gate initial history load on first status snapshot.
        // Fixed 10 s timer was a worst-case estimate. Gating on loadStatusSnapshot()
        // gives a live signal the board is (a) responsive, (b) at post-boot heap,
        // (c) past the BLE/WiFi settle window. Preserves a 15 s fallback in case
        // /api/status/full is unreachable (auth mismatch, network drop).
        // loadHistory() is idempotent via _historyInFlight guard, so both triggers
        // firing is safe.
        var _v7_9_4_historyKicked = false;
        function _v7_9_4_kickHistoryOnce() {
          if (_v7_9_4_historyKicked || historyBootstrapConsumed || isImportActive()) return;
          _v7_9_4_historyKicked = true;
          historyBootstrapConsumed = true;
          Promise.resolve(loadHistory()).catch(function(){});
        }
        firstStatusSnapshotPromise.then(function() {
          setTimeout(_v7_9_4_kickHistoryOnce, 1000);
        }).catch(function(){});
        // Safety fallback: always fire by 15 s so the user sees charts even if
        // /api/status/full never returns.
        historyBootstrapTimerId = setTimeout(_v7_9_4_kickHistoryOnce, 15000);

        // Aggregator overlay: if this device is an aggregator, show the Gateways section
        // and start the aggregator polling loop. Local sensors are already running above.
        if (isAggregator) {
          initAggregatorDashboard();
        }
      });
    });
  });
};

document.addEventListener('DOMContentLoaded', function() {
  bindEvents();
  CustomRange.bindModalEvents();
  try { App.Features.emit('onBoot'); } catch(e) { logNonFatal('boot hook emit', e); }
  App.Boot.start();
});
