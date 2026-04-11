// ╔════════════════════════════════════════════════════════════════╗
// ║  Multi-Sensor Gateway Dashboard                               ║
// ║                                                                ║
// ║  Current dashboard features:                                   ║
// ║    • 24h/7d/30d/45d selectable Min/Max toggle per sensor card     ║
// ║    • BLE RSSI signal strength indicator (needs YAML sensor)    ║
// ║    • Comfort level estimate row (ASHRAE-55-inspired proxy)        ║
// ║    • Dew point calculation (Magnus formula, browser-side)      ║
// ║    • Dark/light mode toggle with CSS custom properties         ║
// ║    • Staleness indicator (yellow >2min, red >5min)             ║
// ║    • CSV history export with gateway metadata and merged Export All                    ║
// ║  Core behavior:                                                ║
// ║    • retained merged history, 0°C freezing line, embedded hosting     ║
// ║    • Transport auto-detection (hosted/SSE/polling)             ║
// ║    • Gateway mini cards under the gateway card, with auth-protected management actions                     ║
// ║                                                                ║
// ║  CONNECTION:                                                    ║
// ║    If opened from ESP (same-origin), ESP_HOST stays ''.        ║
// ║    If opened from disk, set FILE_FALLBACK_HOST below.         ║
// ║    Transport: http → SSE, https → polling, hosted → SSE.      ║
// ╚════════════════════════════════════════════════════════════════╝


// ── v7.3 dashboard structural enforcement: module boundaries + plugin hooks ──
//
// Goal (Step 1 + Step 2 of the re-architecture plan):
//   1) Introduce an App namespace with clear module boundaries.
//   2) Add a tiny plugin interface so new features can be isolated.
//      Each plugin runs in try/catch so one feature cannot blank the UI.
//
// NOTE: This phase intentionally preserves the working v7.2/v7.3 transport/init
// behavior. Phase 1 now adds two practical guardrails without broad rewrites:
//   1) primary shared-state writes go through App.State setters
//   2) inline dashboard handlers are replaced by a centralized bindEvents()
// The bulk of the logic still lives in existing functions so regression risk stays low.
// v7.5.2.0 (Phase 2 Step 1): adds loadManifestV2() + autoPromoteV1ToV2() for
// manifest v2 consumption; result stored in window._manifest. No rendering changes.
// v7.5.2.3 (Phase 2 Step 4): adds fetchDeviceHistory() — manifest-driven history URL
// resolution with fallback to legacy /history/{id}/temp and /history/{id}/hum.

var App = window.App || (window.App = {});
App.version = 'v7.6.6.7';
App.Config = App.Config || {};
App.State = App.State || {};
App.Util = App.Util || {};
App.API = App.API || {};
App.Transport = App.Transport || {};
App.Render = App.Render || {};
App.Charts = App.Charts || {};
App.Boot = App.Boot || {};
App.Features = App.Features || (function() {
  var api = { plugins: [] };

  api.register = function(plugin) {
    if (!plugin) return;
    api.plugins.push(plugin);
  };

  api.emit = function(hook) {
    var args = Array.prototype.slice.call(arguments, 1);
    for (var i = 0; i < api.plugins.length; i++) {
      var p = api.plugins[i];
      var fn = p && p[hook];
      if (typeof fn === 'function') {
        try { fn.apply(p, args); } catch (e) { logNonFatal('plugin hook ' + hook, e); }
      }
    }
  };

  return api;
})();

function logNonFatal(scope, err) {
  var msg = scope + ': ' + (err && err.message ? err.message : err);
  try { if (typeof console !== 'undefined' && console.warn) console.warn(msg, err); } catch (_e) {}
  try { if (typeof dlog === 'function') dlog(msg, 'err'); } catch (_e2) {}
}

// ── Connection ──────────────────────────────────────────────────
// For hosted mode (served directly by the ESP firmware), leave ESP_HOST empty.
// For LAN from disk: var FILE_FALLBACK_HOST = 'http://192.168.120.189';
// For Cloudflare:    var FILE_FALLBACK_HOST = 'https://esp32-2.high-lands.online';
