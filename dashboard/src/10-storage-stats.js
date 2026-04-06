function applyStorageStats(data) {
  var statusEl = document.getElementById('storage-status');
  if (!data || !data.ok || !data.history || !data.layout) {
    if (statusEl) statusEl.textContent = 'Storage statistics unavailable';
    return;
  }
  var h = data.history, l = data.layout, ns = data.nvs_stats || {};
  var layoutText = 'nvs ' + formatBytes(l.nvs_bytes) +
                   ' | otadata ' + formatBytes(l.otadata_bytes) +
                   ' | phy ' + formatBytes(l.phy_init_bytes) +
                   ' | ota_0 ' + formatBytes(l.ota_0_bytes) +
                   ' | ota_1 ' + formatBytes(l.ota_1_bytes) +
                   ' | history ' + formatBytes(l.history_bytes) +
                   ' | coredump ' + formatBytes(l.coredump_bytes);
  var set = function(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  };
  var nvsUsage = 'unavailable';
  var nvsFree = 'unavailable';
  var nvsNs = 'unavailable';
  if (ns.available && ns.total_entries > 0) {
    var pct = ((ns.used_entries * 100) / ns.total_entries).toFixed(1) + '%';
    nvsUsage = String(ns.used_entries) + ' / ' + String(ns.total_entries) + ' entries (' + pct + ')';
    nvsFree = String(ns.free_entries) + ' entries';
    nvsNs = String(ns.namespace_count);
  }
  set('st-layout', layoutText);
  set('st-history-size', formatBytes(h.partition_size_bytes));
  set('st-nvs-usage', nvsUsage);
  set('st-nvs-free', nvsFree);
  set('st-nvs-ns', nvsNs);
  set('st-segments', String(h.valid_segments) + ' / ' + String(h.capacity_segments));
  set('st-segment-size', formatBytes(h.segment_size_bytes));
  set('st-retained', formatBytes(h.estimated_payload_bytes));
  set('st-free', formatBytes(h.estimated_free_payload_bytes));
  set('st-target', String(h.retention_days) + ' days (' + String(h.segment_hours) + 'h snapshots, from firmware)');
  set('st-cadence', 'Every ' + String(h.segment_hours) + ' hour(s)');
  set('st-last-persist', formatEpochLocal(h.last_persist_epoch));
  if (statusEl) {
    if (!ns.available) {
      statusEl.textContent = 'Live NVS entry statistics are unavailable on this build. Partition size and retained payload values are still shown.';
    } else if (h.namespace_initialized) {
      statusEl.textContent = 'Last persist: ' + formatEpochLocal(h.last_persist_epoch);
    } else {
      statusEl.textContent = 'Awaiting first hourly persist cycle.';
    }
  }
}

// BUG-037: in-flight guard prevents concurrent /api/storage-stats requests;
// internal retries (attempt > 0) bypass the guard since they are sequential (LESSON-OPS-050)
var _storageStatsInFlight = false;

function loadStorageStats(attempt) {
  if (isImportActive()) return Promise.resolve(null);
  var tryNum = Number(attempt || 0);
  if (_storageStatsInFlight && tryNum === 0) return Promise.resolve(null);
  _storageStatsInFlight = true;
  var statusEl = document.getElementById('storage-status');
  if (statusEl) {
    statusEl.textContent = tryNum === 0
      ? 'Refreshing storage statistics...'
      : 'Retrying storage statistics (' + (tryNum + 1) + '/3)...';
  }
  return fetch(ESP_HOST + '/api/storage-stats', {cache:'no-store'})
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) { _storageStatsInFlight = false; applyStorageStats(data); return data; })
    .catch(function(err) {
      if (tryNum < 2) {
        return new Promise(function(resolve) {
          setTimeout(resolve, 600 * (tryNum + 1));
        }).then(function() {
          return loadStorageStats(tryNum + 1);
        });
      }
      _storageStatsInFlight = false;
      if (statusEl) {
        var hint = (window.location.protocol === 'file:')
          ? ' Check fallback host and CORS headers.'
          : '';
        statusEl.textContent = 'Storage stats failed: ' + err.message + hint;
      }
      throw err;
    });
}


var importState = {
  active: false,
  authHeader: '',
  startedAt: 0,
  mode: '',        // 'multi' or 'single'
  targetSensor: '' // sensor ID for single mode
};
var pollingLiveIntervalId = null;
var pollingDeviceIntervalId = null;
var storageStatsIntervalId = null;
var statusSnapshotIntervalId = null;
var historyBootstrapTimerId = null;

