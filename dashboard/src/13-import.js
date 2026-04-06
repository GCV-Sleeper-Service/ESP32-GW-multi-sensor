function importHistoryData() {
  var statusEl = document.getElementById('mgmt-status');
  var fileInput = document.getElementById('importFileInput');
  if (!fileInput) return;
  if (isImportActive()) {
    if (statusEl) statusEl.textContent = 'Import already in progress...';
    return;
  }

  // Reset file input so re-selecting the same file triggers change.
  fileInput.value = '';
  fileInput.onchange = function() {
    var file = fileInput.files && fileInput.files[0];
    if (!file) return;
    if (statusEl) statusEl.textContent = 'Reading file...';
    var reader = new FileReader();
    reader.onload = function(e) {
      processImportFile(e.target.result, file.name);
    };
    reader.onerror = function() {
      if (statusEl) statusEl.textContent = 'Failed to read file';
    };
    reader.readAsText(file);
  };
  fileInput.click();
}

function processImportFile(csvText, fileName) {
  var statusEl = document.getElementById('mgmt-status');
  if (statusEl) statusEl.textContent = 'Parsing CSV...';

  var result = parseImportCsv(csvText, fileName);
  if (result.error) {
    if (statusEl) statusEl.textContent = 'Import error: ' + result.error;
    return;
  }

  if (result.points.length === 0) {
    if (statusEl) statusEl.textContent = 'No valid data points found in file';
    return;
  }

  // Build segments from points.
  var batches = buildImportSegments(result.points);

  // Determine import mode: single-sensor or multi-sensor.
  var sensorNames = {};
  result.points.forEach(function(p) { sensorNames[p.sensor] = true; });
  var sensorIds = Object.keys(sensorNames);
  var isSingle = (sensorIds.length === 1);
  var targetSensorId = isSingle ? sensorIds[0] : '';

  var estimate = estimateImportDuration(batches.length);
  var msg = 'Import ' + result.points.length + ' data points (' + batches.length +
    ' batches) for sensor(s): ' + sensorIds.join(', ') +
    '.\nApproximate time: ~' + estimate.label + ' (' + estimate.mode + ').\n\n';

  if (isSingle) {
    msg += 'This will replace history for ' + targetSensorId + ' only.\n' +
      'Data from other sensors will be preserved.\nContinue?';
  } else {
    msg += 'This will REPLACE ALL existing history. Continue?';
  }

  if (!confirm(msg)) {
    if (statusEl) statusEl.textContent = 'Import cancelled';
    return;
  }

  executeImport(batches, statusEl, isSingle ? 'single' : 'multi', targetSensorId);
}

function parseImportCsv(csvText, fileName) {
  var lines = csvText.split(/\r?\n/).filter(function(l) { return l.trim() !== ''; });
  if (lines.length < 2) return { error: 'File too short (need header + data)', points: [] };

  var header = lines[0].split(',').map(function(h) { return h.trim().toLowerCase(); });
  var tsIdx = header.indexOf('timestamp');
  if (tsIdx < 0) return { error: 'Missing "timestamp" column in header', points: [] };

  // Detect format: single-sensor or merged.
  var detection = detectImportColumns(header, fileName);
  if (detection.error) {
    return { error: detection.error, points: [] };
  }
  var sensorColumns = detection.results;
  if (sensorColumns.length === 0) {
    return { error: 'Could not find temp_c / humidity_pct columns in header', points: [] };
  }

  var points = [];
  var rejected = 0;
  var now = Math.floor(Date.now() / 1000);

  for (var i = 1; i < lines.length; i++) {
    var cols = lines[i].split(',');
    var epochRaw = parseInt(cols[tsIdx], 10);
    if (!isFinite(epochRaw) || epochRaw < 946684800) { rejected++; continue; }  // Before year 2000
    if (epochRaw > now + 86400) { rejected++; continue; }  // More than 1 day in future

    for (var s = 0; s < sensorColumns.length; s++) {
      var sc = sensorColumns[s];
      var tempStr = (sc.tempIdx >= 0 && sc.tempIdx < cols.length) ? cols[sc.tempIdx].trim() : '';
      var humStr = (sc.humIdx >= 0 && sc.humIdx < cols.length) ? cols[sc.humIdx].trim() : '';

      var tempVal = parseFloat(tempStr);
      var humVal = parseFloat(humStr);
      var hasTemp = isFinite(tempVal) && tempVal > -50 && tempVal < 80;
      var hasHum = isFinite(humVal) && humVal >= 0 && humVal <= 100;

      if (hasTemp) {
        points.push({ sensor: sc.sensorId, series: 'temp', epoch: epochRaw, value: tempVal });
      }
      if (hasHum) {
        points.push({ sensor: sc.sensorId, series: 'hum', epoch: epochRaw, value: humVal });
      }
    }
  }

  // Sort by epoch.
  points.sort(function(a, b) { return a.epoch - b.epoch; });

  return { points: points, rejected: rejected, error: null };
}

function estimateImportDuration(batchCount) {
  var isCloudflarePath = (!IS_FILE_MODE && window.location.protocol === 'https:') || /^https:/i.test(ESP_HOST);
  var secondsPerBatch = isCloudflarePath ? 1.9 : 1.25;
  var baseSeconds = isCloudflarePath ? 8 : 6;
  var totalSeconds = Math.max(8, Math.round(baseSeconds + (batchCount * secondsPerBatch)));
  return {
    seconds: totalSeconds,
    label: formatDurationLabel(totalSeconds),
    mode: isCloudflarePath ? 'Cloudflare / remote access estimate' : 'LAN / direct access estimate'
  };
}

function formatDurationLabel(totalSeconds) {
  totalSeconds = Math.max(0, Math.round(totalSeconds || 0));
  var minutes = Math.floor(totalSeconds / 60);
  var seconds = totalSeconds % 60;
  if (minutes <= 0) return seconds + ' sec';
  if (seconds === 0) return minutes + ' min';
  return minutes + ' min ' + seconds + ' sec';
}

function detectSensorIdFromImportFileName(fileName) {
  var knownSensors = (typeof SENSORS !== 'undefined') ? SENSORS : [];
  var normalized = sensorSlug((fileName || '').replace(/\.[^.]+$/, ''));
  if (!normalized) return '';

  var candidates = [];
  for (var si = 0; si < knownSensors.length; si++) {
    var sensor = knownSensors[si];
    var checks = [
      sensorSlug(sensor && sensor.id),
      sensorSlug(sensor && sensor.name),
      sensorSlug(getExportSensorPrefix(sensor))
    ].filter(Boolean);

    for (var ci = 0; ci < checks.length; ci++) {
      var token = checks[ci];
      if (normalized.indexOf(token) >= 0) {
        candidates.push(sensor.id);
        break;
      }
    }
  }

  if (candidates.length === 1) return candidates[0];
  return '';
}

function detectImportColumns(header, fileName) {
  var results = [];

  // Check for single-sensor legacy format: temp_c, humidity_pct directly.
  var tempIdx = header.indexOf('temp_c');
  var humIdx = header.indexOf('humidity_pct');
  if (tempIdx >= 0 || humIdx >= 0) {
    // Check if there are prefixed columns too (merged format or new single-sensor export).
    var hasPrefixed = false;
    for (var h = 0; h < header.length; h++) {
      if (header[h].match(/^.+_temp_c$/)) { hasPrefixed = true; break; }
    }

    if (!hasPrefixed) {
      var detectedSensorId = detectSensorIdFromImportFileName(fileName);
      if (!detectedSensorId) {
        return {
          results: [],
          error: 'Legacy single-sensor CSV detected (temp_c/humidity_pct), but the sensor could not be identified from the file name. Re-export from the updated dashboard or rename the file to include the sensor name (for example: outside, office, first_floor).'
        };
      }
      results.push({ sensorId: detectedSensorId, tempIdx: tempIdx, humIdx: humIdx });
      return { results: results, error: null };
    }
  }

  // Check for prefixed format: {prefix}_temp_c, {prefix}_humidity_pct
  var knownSensors = (typeof SENSORS !== 'undefined') ? SENSORS : [];
  for (var si = 0; si < knownSensors.length; si++) {
    var prefix = getExportSensorPrefix(knownSensors[si]).toLowerCase();
    var ti = header.indexOf(prefix + '_temp_c');
    var hi = header.indexOf(prefix + '_humidity_pct');
    if (ti >= 0 || hi >= 0) {
      results.push({ sensorId: knownSensors[si].id, tempIdx: ti, humIdx: hi });
    }
  }

  return { results: results, error: null };
}

function buildImportSegments(points) {
  // Group points into 1-hour segments aligned to hour boundaries.
  // Each segment contains up to 4 points per sensor per series.
  // Each segment is split into URL-path-safe batches (max ~250 chars of data per batch)
  // to fit within the ESP32 URL buffer limit (512 bytes with /api/import/d/ prefix).
  var segmentMap = {};

  points.forEach(function(p) {
    var hourEpoch = p.epoch - (p.epoch % 3600);
    if (!segmentMap[hourEpoch]) segmentMap[hourEpoch] = [];
    segmentMap[hourEpoch].push(p);
  });

  var hourKeys = Object.keys(segmentMap).map(Number).sort(function(a, b) { return a - b; });
  var batches = [];

  hourKeys.forEach(function(hourEpoch) {
    var segPoints = segmentMap[hourEpoch];
    var counts = {};
    var lines = [];
    segPoints.forEach(function(p) {
      var countKey = p.sensor + ',' + p.series;
      if (!counts[countKey]) counts[countKey] = 0;
      if (counts[countKey] >= 4) return;
      counts[countKey]++;
      lines.push(p.sensor + ',' + p.series + ',' + p.epoch + ',' + p.value.toFixed(2));
    });

    // Split lines into batches that fit in ~440 chars (leaves room for URL path + params).
    var currentBatch = [];
    var currentLen = 0;
    for (var i = 0; i < lines.length; i++) {
      var lineLen = lines[i].length + 1;  // +1 for semicolon separator
      if (currentLen + lineLen > 250 && currentBatch.length > 0) {
        batches.push({ data: currentBatch.join(';'), pointCount: currentBatch.length, isLast: false });
        currentBatch = [];
        currentLen = 0;
      }
      currentBatch.push(lines[i]);
      currentLen += lineLen;
    }
    if (currentBatch.length > 0) {
      // Mark the last batch of this hourly segment with write flag.
      batches.push({ data: currentBatch.join(';'), pointCount: currentBatch.length, isLast: true });
    }
  });

  return batches;
}

function safeJsonResponse(r) {
  var status = r.status;
  return r.text().then(function(body) {
    if (!r.ok) throw new Error('HTTP ' + status + ': ' + body.substring(0, 100));
    try { return JSON.parse(body); }
    catch(e) { throw new Error('HTTP ' + status + ' non-JSON: ' + body.substring(0, 100)); }
  });
}

function executeImport(batches, statusEl, importMode, targetSensorId) {
  if (isImportActive()) {
    if (statusEl) statusEl.textContent = 'Import already in progress...';
    return;
  }

  var isSingle = (importMode === 'single');
  if (statusEl) statusEl.textContent = 'Authenticating...';

  requestManagementCredentials('history import').then(function(creds) {
    if (!creds) {
      if (statusEl) statusEl.textContent = 'Import cancelled';
      return;
    }

    var authHeader = 'Basic ' + btoa(creds.username + ':' + creds.password);
    var pacing = {
      pauseBeforeBeginMs: 250,
      dataBatchGapMs: 120,
      writeBatchGapMs: 320,
      postFinishReloadDelayMs: 500
    };

    importState.authHeader = authHeader;
    importState.mode = importMode || 'multi';
    importState.targetSensor = targetSensorId || '';
    suspendDashboardNetworkActivity(statusEl);

    var beginUrl = ESP_HOST + '/api/import/begin';
    if (isSingle && targetSensorId) {
      beginUrl = ESP_HOST + '/api/import/begin/single/' + encodeURIComponent(targetSensorId);
    }
    var beginStatusText = isSingle
      ? 'Preparing single-sensor import for ' + targetSensorId + '...'
      : 'Clearing history for import...';

    return delay(pacing.pauseBeforeBeginMs)
      .then(function() {
        if (statusEl) statusEl.textContent = beginStatusText;
        return importFetchJsonWithRetry(
          beginUrl,
          {
            method: 'POST',
            cache: 'no-store',
            headers: {
              'Authorization': authHeader,
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: 'a=1'
          },
          'begin',
          statusEl
        );
      })
      .then(function(data) {
        if (!data.ok) throw new Error(data.message || 'Begin failed');

        var totalAccepted = 0;
        var totalRejected = 0;

        var estimate = estimateImportDuration(batches.length);
        return batches.reduce(function(chain, batch, idx) {
          return chain.then(function() {
            if (statusEl) {
              var remainingBatches = Math.max(0, batches.length - (idx + 1));
              var remainingSeconds = Math.round((estimate.seconds / Math.max(1, batches.length)) * remainingBatches);
              statusEl.textContent = 'Importing batch ' + (idx + 1) + ' / ' + batches.length +
                ' (' + batch.pointCount + ' points, ~' + formatDurationLabel(remainingSeconds) + ' left)...';
            }

            var pathPrefix = batch.isLast ? '/api/import/w/' : '/api/import/d/';
            return importFetchJsonWithRetry(
              ESP_HOST + pathPrefix + batch.data,
              {
                method: 'POST',
                cache: 'no-store',
                headers: {
                  'Authorization': authHeader,
                  'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: 'a=1'
              },
              'batch ' + (idx + 1) + ' of ' + batches.length,
              statusEl
            )
            .then(function(result) {
              if (!result.ok) throw new Error(result.message || 'Data write failed at batch ' + (idx + 1));
              totalAccepted += (result.accepted || 0);
              totalRejected += (result.rejected || 0);
              return delay(batch.isLast ? pacing.writeBatchGapMs : pacing.dataBatchGapMs);
            });
          });
        }, Promise.resolve()).then(function() {
          return { accepted: totalAccepted, rejected: totalRejected };
        });
      })
      .then(function(totals) {
        if (statusEl) statusEl.textContent = 'Finalizing import...';
        return importFetchJsonWithRetry(
          ESP_HOST + '/api/import/finish',
          {
            method: 'POST',
            cache: 'no-store',
            headers: {
              'Authorization': authHeader,
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: 'a=1'
          },
          'finish',
          statusEl
        )
        .then(function(data) {
          if (!data.ok) throw new Error(data.message || 'Finish failed');
          var msg = 'Import complete: ' + data.segments_written + ' segments, ' +
            totals.accepted + ' accepted';
          if (totals.rejected > 0) msg += ', ' + totals.rejected + ' rejected';
          if (statusEl) statusEl.textContent = msg + ' \u2714';
          resetHistoryVisuals();
          return delay(pacing.postFinishReloadDelayMs).then(function() {
            resumeDashboardNetworkActivity();
            loadHistory();
            loadStorageStats().catch(function(){});
          });
        });
      })
      .catch(function(err) {
        if (statusEl) statusEl.textContent = 'Import failed: ' + err.message;
        throw err;
      })
      .then(function(result) {
        if (isImportActive()) resumeDashboardNetworkActivity();
        importState.authHeader = '';
        importState.mode = '';
        importState.targetSensor = '';
        return result;
      }, function(err) {
        if (isImportActive()) resumeDashboardNetworkActivity();
        importState.authHeader = '';
        importState.mode = '';
        importState.targetSensor = '';
        throw err;
      });
  }).catch(function(err) {
    if (err && err.message === 'Authentication cancelled') {
      if (statusEl) statusEl.textContent = 'Import cancelled';
      return;
    }
    if (statusEl && err && err.message && statusEl.textContent.indexOf('Import failed:') !== 0) {
      statusEl.textContent = 'Import failed: ' + err.message;
    }
  });
}

