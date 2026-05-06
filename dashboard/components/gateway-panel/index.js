function _aggregatorFetch(path, init) {
  var reqInit = Object.assign({}, init || {});
  reqInit.cache = reqInit.cache || 'no-store';
  return authFetch(ESP_HOST + path, reqInit);
}

function _aggregatorFetchWithReauth(path, init, actionLabel) {
  return _aggregatorFetch(path, init).then(function(resp) {
    if (resp.status !== 401 || !shouldPromptForAuth()) return resp;
    return requestAuth(actionLabel || 'aggregator dashboard').then(function(creds) {
      if (!creds || !isAuthenticated()) return resp;
      return _aggregatorFetch(path, init);
    });
  });
}

async function detectAggregatorMode() {
  try {
    var statusResp = await fetch(ESP_HOST + '/api/status', {cache: 'no-store'});
    if (!statusResp.ok) return false;

    var status = await statusResp.json();
    if (!status || status.role !== 'aggregator') return false;

    DASHBOARD_MODE = 'aggregator';
    window._aggregatorGateways = [];
    return true;
  } catch(e) { /* not aggregator ? satellite mode */ }
  return false;
}


function renderGatewaySelector(gateways) {
  var container = document.getElementById('gwSelectorContainer');
  var selectorHtml = '<div id="gwSelector" class="gw-selector">' +
    '<button class="gw-tab active" data-gw="all">All Gateways</button>';
  gateways.forEach(function(gw) {
    var statusClass = gw.reachable ? 'gw-online' : 'gw-offline';
    var displayName = gw.hostname || gw.name;
    // escAttr for attribute value; escHtml for button text content
    selectorHtml += '<button class="gw-tab ' + statusClass + '" data-gw="' + escAttr(gw.id) + '">' +
      escHtml(displayName) + '</button>';
  });
  // Settings tab — always last
  selectorHtml += '<button class="gw-tab gw-settings-tab" data-gw="settings">&#9881; Settings</button>';
  selectorHtml += '</div>';
  container.innerHTML = selectorHtml;
  // Use programmatic event binding (App.State.get/set pattern, not inline onclick)
  document.querySelectorAll('.gw-tab').forEach(function(tab) {
    tab.addEventListener('click', function() {
      document.querySelectorAll('.gw-tab').forEach(function(t) { t.classList.remove('active'); });
      tab.classList.add('active');
      var gwId = tab.getAttribute('data-gw');
      if (gwId === 'all') {
        _currentGwId = null; _currentGwSensors = null;
        renderAllGatewaysSummary(window._aggregatorGateways);
      } else if (gwId === 'settings') {
        _currentGwId = null; _currentGwSensors = null;
        renderSettingsPanel(window._aggregatorGateways);
      } else {
        renderGatewayDevices(gwId);
      }
    });
  });
}

function _getActiveGatewayTabId() {
  var activeTab = document.querySelector('.gw-tab.active');
  return activeTab ? activeTab.getAttribute('data-gw') : 'all';
}

function _gatewaySelectorNeedsRefresh(gateways) {
  var tabs = document.querySelectorAll('.gw-tab');
  var expectedCount = (gateways ? gateways.length : 0) + 2;
  if (tabs.length !== expectedCount) return true;
  if (!document.querySelector('.gw-tab[data-gw="all"]')) return true;
  if (!document.querySelector('.gw-tab[data-gw="settings"]')) return true;
  for (var i = 0; i < (gateways || []).length; i++) {
    var gw = gateways[i];
    if (!document.querySelector('.gw-tab[data-gw="' + gw.id + '"]')) return true;
  }
  return false;
}

function _syncGatewaySelector(gateways, preferredGwId) {
  var activeGwId = preferredGwId || _getActiveGatewayTabId();
  if (!_gatewaySelectorNeedsRefresh(gateways)) return;
  renderGatewaySelector(gateways || []);
  if (!activeGwId || activeGwId === 'all') return;
  var activeTab = document.querySelector('.gw-tab[data-gw="' + activeGwId + '"]');
  if (!activeTab) return;
  activeTab.click();
}

function renderAllGatewaysSummary(gateways) {
  var grid = document.getElementById('gwGrid');
  grid.innerHTML = '';
  if (!gateways || gateways.length === 0) {
    grid.innerHTML = '<div class="gw-summary-card">No satellites configured.</div>';
    return;
  }
  var html = '';
  gateways.forEach(function(gw) {
    var statusClass = gw.reachable ? 'gw-status-online' : 'gw-status-offline';
    var statusText = gw.reachable ? '&#127002; Online' : '&#128308; Unreachable';
    var displayName = gw.hostname || gw.name;
    var ipAddress = gw.ip || '\u2014';
    var lastSeenStr = gw.last_seen ? new Date(gw.last_seen * 1000).toLocaleString() : '\u2014';
    var fwVersion = gw.firmware_version || '\u2014';
    var deviceCount = (gw.sensor_count !== undefined) ? gw.sensor_count :
      (gw.device_count !== undefined ? gw.device_count : '\u2014');
    html += '<div class="gw-summary-card' + (gw.reachable ? '' : ' gw-stale') + '">';
    html += '<div class="gw-summary-header"><span class="' + statusClass + '">' + statusText + '</span>' +
      ' <strong>' + escHtml(displayName) + '</strong>' +
      ' <span class="gw-summary-id">(' + escHtml(gw.id) + ')</span></div>';
    html += '<div class="gw-summary-details">';
    html += '<div><span class="gw-detail-label">IP:</span> ' + escHtml(ipAddress) + '</div>';
    html += '<div><span class="gw-detail-label">Last seen:</span> ' + escHtml(lastSeenStr) + '</div>';
    html += '<div><span class="gw-detail-label">Firmware:</span> ' + escHtml(fwVersion) + '</div>';
    html += '<div><span class="gw-detail-label">Devices:</span> ' + escHtml(String(deviceCount)) + '</div>';
    if (!gw.reachable) html += '<div class="gw-stale-overlay">Unreachable</div>';
    html += '</div>';
    html += '</div>';
  });
  grid.innerHTML = html;
}

function renderGatewayDevices(gwId) {
  var gw = null;
  if (window._aggregatorGateways) {
    for (var i = 0; i < window._aggregatorGateways.length; i++) {
      if (window._aggregatorGateways[i].id === gwId) { gw = window._aggregatorGateways[i]; break; }
    }
  }
  var grid = document.getElementById('gwGrid');
  grid.innerHTML = '';
  if (!gw) {
    grid.innerHTML = '<div class="gw-summary-card gw-stale"><div>Gateway not found: ' + escHtml(gwId) + '</div></div>';
    return;
  }
  if (!gw.reachable) {
    var lastSeenStr = gw.last_seen ? new Date(gw.last_seen * 1000).toLocaleString() : 'unknown';
    grid.innerHTML = '<div class="gw-summary-card gw-stale">' +
      '<div class="gw-status-offline">&#128308; Unreachable</div>' +
      '<div>Last seen: ' + escHtml(lastSeenStr) + '</div></div>';
    return;
  }
  // Parse manifest if available from /api/aggregator/gateways response
  var manifest = null;
  if (gw.manifest) {
    try { manifest = (typeof gw.manifest === 'string') ? JSON.parse(gw.manifest) : gw.manifest; } catch(e) {}
  }
  if (!manifest || !manifest.sensors || manifest.sensors.length === 0) {
    grid.innerHTML = '<div class="gw-summary-card"><div>No device data available for <strong>' +
      escHtml(gw.name) + '</strong>. Manifest not yet cached.</div></div>';
    return;
  }
  // Build sensor configs with namespaced IDs and render cards using existing CARD_RENDERERS
  var gwSensors = [];
  manifest.sensors.forEach(function(s, idx) {
    var cat = s.category || 'environmental';
    var nsId = gwId + '.' + s.id; // namespaced: avoids cross-gateway ID collisions
    // cfg.id is namespaced (for DOM element IDs); _deviceId is the original id (for API calls)
    var meta = { id: nsId, name: s.name, category: cat };
    var cfg;
    if (cat === 'environmental') {
      cfg = makeSensorConfig(meta, idx);
    } else {
      cfg = makeNetworkSensorConfig(meta, idx); // network, system, and unknown categories
    }
    // Store originals for proxy history routing and API lookups
    cfg._gwId = gwId;
    cfg._gwName = gw.name;
    cfg._gwDisplayName = gw.hostname || gw.name;
    cfg._deviceId = s.id;
    cfg._namespacedId = nsId; // kept for clarity
    gwSensors.push({ cfg: cfg, entry: s });
  });
  var html = '';
  gwSensors.forEach(function(item) {
    var s = item.cfg;
    var cat = s.category || 'environmental';
    var renderer = CARD_RENDERERS[cat] || CARD_RENDERERS._default;
    html += renderer(s, manifest);
  });
  grid.innerHTML = html;
  // Suppress min/max history for remote satellite cards — proxy history not yet implemented.
  // Show "—" instead of "calculating..." and hide the range toggle buttons.
  grid.querySelectorAll('.minmax-line .waiting').forEach(function(el) {
    el.textContent = '\u2014';
    el.classList.remove('waiting');
  });
  grid.querySelectorAll('.minmax-toggle').forEach(function(el) {
    el.style.display = 'none';
  });
  // Track current per-gateway view for pollAggregatorLive refresh (fix 2b)
  _currentGwId = gwId;
  _currentGwSensors = gwSensors;
  // Populate live values from /api/aggregator/live (in-flight guarded separately)
  _populateGatewayDeviceLive(gwId, gwSensors);
}

// Current per-gateway view state (for pollAggregatorLive to refresh)
var _currentGwId = null;
var _currentGwSensors = null;

var _aggDeviceLiveInFlight = false;
function _populateGatewayDeviceLive(gwId, gwSensors) {
  if (_aggDeviceLiveInFlight) return;
  _aggDeviceLiveInFlight = true;
  _aggregatorFetchWithReauth('/api/aggregator/live', {cache: 'no-store'}, 'aggregator dashboard')
    .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
    .then(function(data) {
      if (!data || !data.gateways || !data.gateways[gwId]) return;
      var gwLive = data.gateways[gwId];
      if (!gwLive.reachable || !gwLive.live || !gwLive.live.devices) return;
      var devices = gwLive.live.devices;
      gwSensors.forEach(function(item) {
        var s = item.cfg;
        var deviceId = s._deviceId;
        var devData = devices[deviceId];
        if (!devData) return;
        var cat = s.category || 'environmental';
        if (cat === 'environmental') {
          // Temperature (raw float → format with unit)
          if (devData.temp !== undefined && devData.temp !== null) {
            var tempEl = document.getElementById('val-' + esc(s.tempId));
            if (tempEl) {
              var tC = devData.temp;
              sensorCurrentTemp[s.id] = tC;
              tempEl.textContent = formatMetricValue('temperature', tC, getMetricDef('temp'));
              tempEl.classList.remove('waiting');
            }
          }
          // Humidity
          if (devData.hum !== undefined && devData.hum !== null) {
            var humEl = document.getElementById('val-' + esc(s.humId));
            if (humEl) {
              var hV = devData.hum;
              sensorCurrentHum[s.id] = hV;
              humEl.textContent = formatMetricValue('humidity', hV, getMetricDef('hum'));
              humEl.classList.remove('waiting');
            }
          }
          // Derived values (dew point and comfort) once both temp and hum are available
          if (sensorCurrentTemp[s.id] !== undefined && sensorCurrentHum[s.id] !== undefined) {
            updateDewPoint(s.id);
            updateComfortLevel(s.id);
          }
          // Battery
          if (devData.batt !== undefined && devData.batt !== null) {
            updateBattery(s, String(devData.batt));
          }
          // Last seen
          var seenEl = document.getElementById('time-' + s.id);
          if (seenEl && devData.last_seen) {
            var d = new Date(devData.last_seen * 1000);
            seenEl.textContent = 'last: ' + d.toLocaleTimeString([], {hour12:false});
          }
        } else if (cat === 'network') {
          var pingEl = document.getElementById('net-ping-' + s.id);
          if (pingEl && devData.ping_ms !== undefined && devData.ping_ms !== null) {
            pingEl.textContent = METRIC_FORMATTERS.ping_latency(devData.ping_ms);
            pingEl.classList.remove('waiting');
          }
          var successEl = document.getElementById('net-success-' + s.id);
          if (successEl && devData.success_pct !== undefined && devData.success_pct !== null) {
            successEl.textContent = METRIC_FORMATTERS.success_rate(devData.success_pct);
            successEl.classList.remove('waiting');
          }
          var seenEl = document.getElementById('net-lastseen-' + s.id);
          if (seenEl && devData.last_seen) {
            var d = new Date(devData.last_seen * 1000);
            seenEl.textContent = 'last: ' + d.toLocaleTimeString([], {hour12:false});
          }
        } else if (cat === 'system') {
          _updateSystemCardDOM(s, devData);
        }
      });
    })
    .catch(function() { /* silent */ })
    .finally(function() { _aggDeviceLiveInFlight = false; });
}

function renderSettingsPanel(gateways) {
  var grid = document.getElementById('gwGrid');
  grid.innerHTML = '';
  var html = '<div class="settings-panel">';
  html += '<h3 class="settings-title">Satellite Configuration</h3>';
  // Add Satellite form
  html += '<div class="settings-add-form">';
  html += '<div class="settings-add-row">';
  html += '<input type="text" class="settings-input" id="sat-url-input" placeholder="http://192.168.x.x">';
  html += '<input type="text" class="settings-input settings-input-name" id="sat-name-input" placeholder="Friendly name (optional)">';
  html += '</div>';
  html += '<div class="settings-add-actions">';
  html += '<button class="settings-btn settings-btn-test" id="sat-test-btn">Test</button>';
  html += '<button class="settings-btn settings-btn-add" id="sat-add-btn">Add</button>';
  html += '</div>';
  html += '<div class="settings-status" id="sat-add-status"></div>';
  html += '</div>';
  // Satellite cards
  if (!gateways || gateways.length === 0) {
    html += '<p class="settings-empty">No satellites configured.</p>';
  } else {
    gateways.forEach(function(gw) {
      var statusDot = gw.reachable ? '\uD83D\uDFE2' : '\uD83D\uDD34';
      var displayName = gw.hostname || gw.name;
      var hostname = gw.hostname || '\u2014';
      var ipAddress = gw.ip || '\u2014';
      var fwVersion = '\u2014';
      var deviceCount = '\u2014';
      if (gw.firmware_version) fwVersion = gw.firmware_version;
      if (gw.device_count !== undefined && gw.device_count !== null) deviceCount = String(gw.device_count);
      else if (gw.sensor_count !== undefined && gw.sensor_count !== null) deviceCount = String(gw.sensor_count);
      var lastSeenStr = (gw.last_seen !== undefined && gw.last_seen !== null)
        ? new Date(gw.last_seen * 1000).toLocaleString() : '\u2014';
      html += '<div class="settings-satellite-card">';
      html += '<div class="settings-sat-header">' + statusDot + ' ' + escHtml(displayName) +
        ' <span class="settings-sat-id">(' + escHtml(gw.id) + ')</span></div>';
      html += '<div class="settings-sat-details">';
      html += '<div>Hostname: ' + escHtml(hostname) + '</div>';
      html += '<div>IP: ' + escHtml(ipAddress) + '</div>';
      html += '<div>URL: <code>' + escHtml(gw.base_url || '\u2014') + '</code></div>';
      html += '<div>Firmware: ' + escHtml(fwVersion) + '</div>';
      html += '<div>Devices: ' + escHtml(deviceCount) + '</div>';
      html += '<div>Status: ' + (gw.reachable ? 'Online' : 'Unreachable') + '</div>';
      html += '<div>Last seen: ' + escHtml(lastSeenStr) + '</div>';
      if (gw.consecutive_failures !== undefined && gw.consecutive_failures !== null && gw.consecutive_failures > 0) {
        html += '<div class="settings-warning">Failures: ' + escHtml(String(gw.consecutive_failures)) + '</div>';
      }
      html += '</div>';
      html += '<button class="settings-btn settings-btn-remove" data-sat-id="' + escAttr(gw.id) + '" data-sat-name="' + escAttr(displayName) + '">Remove</button>';
      html += '<div class="settings-status" id="sat-status-' + escAttr(gw.id) + '"></div>';
      html += '</div>';
    });
  }
  html += '</div>';
  grid.innerHTML = html;
  // Bind Test button
  var testBtn = document.getElementById('sat-test-btn');
  if (testBtn) {
    testBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      var urlInput = document.getElementById('sat-url-input');
      var statusEl = document.getElementById('sat-add-status');
      _handleTestSatellite(urlInput, statusEl);
    });
  }
  // Bind Add button
  var addBtn = document.getElementById('sat-add-btn');
  if (addBtn) {
    addBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      var urlInput = document.getElementById('sat-url-input');
      var nameInput = document.getElementById('sat-name-input');
      var statusEl = document.getElementById('sat-add-status');
      _handleAddSatellite(urlInput, nameInput, statusEl);
    });
  }
  // Bind Remove buttons
  document.querySelectorAll('.settings-btn-remove').forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      e.stopPropagation();
      var satId = btn.getAttribute('data-sat-id');
      var satName = btn.getAttribute('data-sat-name');
      var statusEl = document.getElementById('sat-status-' + satId);
      _handleRemoveSatellite(satId, satName, statusEl);
    });
  });
}

var _satTestInFlight = false;
function _handleTestSatellite(urlInput, statusEl) {
  if (_satTestInFlight) {
    var liveStatusEl = document.getElementById('sat-add-status');
    if (statusEl) statusEl.textContent = 'Test already in progress...';
    if (liveStatusEl && liveStatusEl !== statusEl) liveStatusEl.textContent = 'Test already in progress...';
    return;
  }
  // Capture URL value synchronously before any async work
  var capturedUrl = String(urlInput ? urlInput.value || '' : '').trim();
  if (!capturedUrl) {
    if (statusEl) statusEl.textContent = 'Enter a URL to test.';
    return;
  }
  _satTestInFlight = true;
  if (statusEl) statusEl.textContent = 'Authenticating...';
  requestAuth('satellite test')
    .then(function() {
      // Re-query status element by stable id — panel may have been re-rendered since click (R1 fix)
      var liveStatusEl = document.getElementById('sat-add-status');
      if (!isAuthenticated()) {
        if (liveStatusEl) liveStatusEl.textContent = 'Test cancelled';
        return Promise.reject(new Error('AUTH_CANCELLED'));
      }
      if (liveStatusEl) liveStatusEl.textContent = 'Testing...';
      return _aggregatorFetch('/api/aggregator/test-satellite?url=' + encodeURIComponent(capturedUrl), {
        method: 'POST',
        cache: 'no-store',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'a=1'
      })
      .then(safeJsonResponse)
      .then(function(data) {
        var liveStatusEl = document.getElementById('sat-add-status');
        var gw = data.gateway || {};
        var deviceCount = '\u2014';
        if (gw.device_count !== undefined && gw.device_count !== null) deviceCount = String(gw.device_count);
        else if (gw.sensor_count !== undefined && gw.sensor_count !== null) deviceCount = String(gw.sensor_count);
        if (liveStatusEl) liveStatusEl.innerHTML = '\u2713 Found: ' + escHtml(gw.name || '\u2014') +
          ' (' + escHtml(gw.hardware || '\u2014') + ', ' + escHtml(deviceCount) + ' devices)';
      });
    })
    .catch(function(err) {
      var liveStatusEl = document.getElementById('sat-add-status');
      if (liveStatusEl && err.message !== 'AUTH_CANCELLED') liveStatusEl.innerHTML = '\u2717 ' + escHtml(err.message || 'Test failed');
    })
    .finally(function() { _satTestInFlight = false; });
}

var _satAddInFlight = false;
function _handleAddSatellite(urlInput, nameInput, statusEl) {
  if (_satAddInFlight) return;
  var url = String(urlInput ? urlInput.value || '' : '').trim();
  var name = String(nameInput ? nameInput.value || '' : '').trim();
  if (!url) {
    if (statusEl) statusEl.textContent = 'Enter a URL to add.';
    return;
  }
  _satAddInFlight = true;
  if (statusEl) statusEl.textContent = 'Authenticating...';

  requestAuth('satellite add')
  .then(function() {
    if (!isAuthenticated()) throw new Error('AUTH_CANCELLED');
    if (statusEl) statusEl.textContent = 'Adding...';
    var query = 'url=' + encodeURIComponent(url);
    if (name) query += '&name=' + encodeURIComponent(name);
    return _aggregatorFetch('/api/aggregator/add-satellite?' + query, {
      method: 'POST',
      cache: 'no-store',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'a=1'
    });
  })
  .then(safeJsonResponse)
  .then(function() {
    if (urlInput) urlInput.value = '';
    if (nameInput) nameInput.value = '';
    if (statusEl) statusEl.textContent = 'Satellite added.';
    _refreshSettingsPanel();
  })
  .catch(function(err) {
    if (!statusEl) return;
    if (err.message === 'AUTH_CANCELLED') {
      statusEl.textContent = 'Add cancelled';
    } else {
      statusEl.innerHTML = '✗ ' + escHtml(err.message || 'Add failed');
    }
  })
  .finally(function() { _satAddInFlight = false; });
}


var _satRemoveInFlight = false;
function _handleRemoveSatellite(satId, satName, statusEl) {
  if (_satRemoveInFlight) return;
  if (!confirm('Remove satellite ' + satName + '? This cannot be undone.')) return;
  _satRemoveInFlight = true;
  if (statusEl) statusEl.textContent = 'Authenticating...';
  requestAuth('satellite removal')
    .then(function() {
      if (!isAuthenticated()) {
        if (statusEl) statusEl.textContent = 'Remove cancelled';
        return null;
      }
      if (statusEl) statusEl.textContent = 'Removing...';
      return _aggregatorFetch('/api/aggregator/satellite/' + encodeURIComponent(satId), {
        method: 'DELETE',
        cache: 'no-store'
      })
      .then(safeJsonResponse)
      .then(function() { _refreshSettingsPanel(); });
    })
    .catch(function(err) {
      var msg = err.message || 'Remove failed';
      if (msg.indexOf('404') !== -1) {
        if (statusEl) statusEl.textContent = 'Satellite not found';
      } else {
        if (statusEl) statusEl.innerHTML = '\u2717 ' + escHtml(msg);
      }
    })
    .finally(function() { _satRemoveInFlight = false; });
}

function _refreshSettingsPanel() {
  _aggregatorFetchWithReauth('/api/aggregator/gateways', {cache: 'no-store'}, 'aggregator dashboard')
    .then(safeJsonResponse)
    .then(function(data) {
      if (data && data.gateways) {
        window._aggregatorGateways = data.gateways;
        renderGatewaySelector(window._aggregatorGateways);
        document.querySelectorAll('.gw-tab').forEach(function(t) { t.classList.remove('active'); });
        var settingsTab = document.querySelector('.gw-tab[data-gw="settings"]');
        if (settingsTab) settingsTab.classList.add('active');
        renderSettingsPanel(window._aggregatorGateways);
      }
    })
    .catch(function() { /* silent */ });
}

async function initAggregatorDashboard() {
  // Show the Gateways section (hidden by default in HTML)
  var gwHdr = document.getElementById('hdr-gateways');
  var gwBody = document.getElementById('body-gateways');
  if (gwHdr) gwHdr.style.display = '';
  if (gwBody) gwBody.style.display = '';
  window._aggregatorReady = false;
  renderGatewaySelector(window._aggregatorGateways);
  // Render "All Gateways" as the default active view
  renderAllGatewaysSummary(window._aggregatorGateways);
  // Start periodic aggregator polling — 15s interval, in-flight guarded
  setInterval(pollAggregatorLive, 15000);
  pollAggregatorLive();
}

var _aggLiveInFlight = false;
function pollAggregatorLive() {
  if (_aggLiveInFlight) return;
  _aggLiveInFlight = true;
  return _aggregatorFetchWithReauth('/api/aggregator/gateways', {cache: 'no-store'}, 'aggregator dashboard')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data && data.gateways) {
        var activeGwId = _getActiveGatewayTabId();
        window._aggregatorGateways = data.gateways;
        _syncGatewaySelector(window._aggregatorGateways, activeGwId);
        // Update gateway selector tab status indicators
        data.gateways.forEach(function(gw) {
          var tab = document.querySelector('.gw-tab[data-gw="' + gw.id + '"]');
          if (tab) {
            tab.classList.toggle('gw-online', !!gw.reachable);
            tab.classList.toggle('gw-offline', !gw.reachable);
          }
        });
        var activeTab = document.querySelector('.gw-tab.active');
        if (activeTab) {
          var gwId = activeTab.getAttribute('data-gw');
          if (gwId === 'all') renderAllGatewaysSummary(data.gateways);
          else if (gwId === 'settings') {
            // Guard: skip re-render while any satellite settings async op is in-flight
            // or while the settings inputs are being edited.
            var urlInput  = document.getElementById('sat-url-input');
            var nameInput = document.getElementById('sat-name-input');
            var inputFocused = (document.activeElement === urlInput ||
                                document.activeElement === nameInput);
            var settingsOpInFlight = !!(_satTestInFlight || _satAddInFlight || _satRemoveInFlight);
            if (!settingsOpInFlight && !inputFocused) {
              renderSettingsPanel(data.gateways);
            }
          }
          else if (gwId && _currentGwId === gwId && _currentGwSensors) {
            // Refresh live values for the currently displayed per-gateway device view
            _populateGatewayDeviceLive(gwId, _currentGwSensors);
          }
        }
        window._aggregatorReady = true;
      }
    })
    .catch(function() { /* silent */ })
    .finally(function() { _aggLiveInFlight = false; });
}
