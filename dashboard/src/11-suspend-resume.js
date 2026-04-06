function isImportActive() {
  return !!importState.active;
}

function stopPolling() {
  if (pollingLiveIntervalId) {
    clearInterval(pollingLiveIntervalId);
    pollingLiveIntervalId = null;
  }
  if (pollingDeviceIntervalId) {
    clearInterval(pollingDeviceIntervalId);
    pollingDeviceIntervalId = null;
  }
}

function stopStorageRefresh() {
  if (storageStatsIntervalId) {
    clearInterval(storageStatsIntervalId);
    storageStatsIntervalId = null;
  }
}

function stopStatusRefresh() {
  if (statusSnapshotIntervalId) {
    clearInterval(statusSnapshotIntervalId);
    statusSnapshotIntervalId = null;
  }
}

function suspendDashboardNetworkActivity(statusEl) {
  importState.active = true;
  importState.startedAt = Date.now();
  stopPolling();
  stopStorageRefresh();
  stopStatusRefresh();
  if (historyBootstrapTimerId) {
    clearTimeout(historyBootstrapTimerId);
    historyBootstrapTimerId = null;
  }
  if (evtSource) {
    // BUG-049: Null out all callbacks BEFORE calling close(). Firefox's Gecko
    // engine keeps the SSE TCP socket alive if callbacks are still attached,
    // causing browserContext.close() to hang during Playwright teardown.
    evtSource.onopen = null;
    evtSource.onerror = null;
    evtSource.onmessage = null;
    try { evtSource.close(); } catch (_e) {}
    evtSource = null;
  }
  if (statusEl) statusEl.textContent = 'Pausing dashboard refresh during import...';
}

function resumeDashboardNetworkActivity() {
  importState.active = false;
  if (TRANSPORT === 'sse') {
    try { connectSSE(); } catch (e) { logNonFatal('resume SSE after import', e); }
  } else {
    try { startPolling(); } catch (e2) { logNonFatal('resume polling after import', e2); }
  }
  // BUG-037 Fix 8: storage stats interval 120s (matching boot sequence)
  if (!storageStatsIntervalId) {
    storageStatsIntervalId = setInterval(function() {
      if (isImportActive()) return;
      loadStorageStats().catch(function(){});
    }, 120000);
  }
  // BUG-037 Fix 5: status interval only in polling mode (matching boot sequence)
  if (!statusSnapshotIntervalId && TRANSPORT !== 'sse') {
    statusSnapshotIntervalId = setInterval(function() {
      if (isImportActive()) return;
      loadStatusSnapshot().catch(function(){});
    }, 30000);
  }
}

function isTransientImportError(err) {
  var msg = (err && err.message ? err.message : String(err || '')).toLowerCase();
  if (!msg) return false;
  return /http\s+(502|503|504|520|522|524)\b/.test(msg) ||
    msg.indexOf('failed to fetch') >= 0 ||
    msg.indexOf('networkerror') >= 0 ||
    msg.indexOf('load failed') >= 0 ||
    msg.indexOf('bad gateway') >= 0 ||
    msg.indexOf('connection reset') >= 0;
}

