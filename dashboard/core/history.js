function parseHistoryMetricLines(text) {
  var out = {};
  text.split(/\r?\n/).forEach(function(line) {
    if (!line) return;
    var c = line.indexOf(',');
    if (c < 0) return;
    var epoch = parseInt(line.substring(0, c).trim(), 10);
    if (!isFinite(epoch)) return;
    var raw = line.substring(c + 1).trim();
    if (!raw) {
      out[epoch] = '';
      return;
    }
    var num = parseFloat(raw);
    out[epoch] = isFinite(num) ? num : '';
  });
  return out;
}

function buildNormalizedSensorRows(tempText, humText) {
  var tempMap = parseHistoryMetricLines(tempText);
  var humMap = parseHistoryMetricLines(humText);
  var seen = {};
  var timestamps = [];
  Object.keys(tempMap).forEach(function(key) {
    var ts = parseInt(key, 10);
    if (isFinite(ts) && !seen[ts]) { seen[ts] = true; timestamps.push(ts); }
  });
  Object.keys(humMap).forEach(function(key) {
    var ts = parseInt(key, 10);
    if (isFinite(ts) && !seen[ts]) { seen[ts] = true; timestamps.push(ts); }
  });
  timestamps.sort(function(a, b) { return a - b; });

  return timestamps.map(function(ts) {
    var tC = (typeof tempMap[ts] === 'number' && isFinite(tempMap[ts])) ? tempMap[ts] : null;
    var hum = (typeof humMap[ts] === 'number' && isFinite(humMap[ts])) ? humMap[ts] : null;
    var tF = tC !== null ? (tC * 9 / 5 + 32) : null;
    var dp = null;
    if (tC !== null && hum !== null) {
      var dpv = calcDewPoint(tC, hum);
      if (dpv !== null && isFinite(dpv)) dp = dpv;
    }
    return {
      timestamp: ts,
      datetime_utc: formatUtcForExport(ts),
      temp_c: tC,
      temp_f: tF,
      humidity_pct: hum,
      dewpoint_c: dp
    };
  });
}

// fetchDeviceHistory — manifest-driven history URL resolution (v7.5.2.3)
// Derives history URLs from manifest measurements[].history_url when available.
// Falls back to legacy /history/{id}/temp and /history/{id}/hum when manifest data is absent.
// Returns Promise<Array<{key, raw}>> where raw is the raw CSV text.
function fetchDeviceHistory(sensor, manifest) {
  var historyMeasurements = [];

  // Use _deviceId (original manifest ID) when available — sensor.id may be namespaced in aggregator mode.
  var lookupId = sensor._deviceId || sensor.id;

  // Manifest-driven: look up this sensor's measurements and their history URLs
  if (manifest && manifest.sensors) {
    var manifestDevice = null;
    for (var i = 0; i < manifest.sensors.length; i++) {
      if (manifest.sensors[i].id === lookupId) { manifestDevice = manifest.sensors[i]; break; }
    }
    if (manifestDevice && manifestDevice.measurements) {
      manifestDevice.measurements.forEach(function(m) {
        var metricDef = null;
        if (manifest.metrics) {
          for (var j = 0; j < manifest.metrics.length; j++) {
            if (manifest.metrics[j].key === m.key) { metricDef = manifest.metrics[j]; break; }
          }
        }
        // Only include measurements that have history + chart enabled
        if (metricDef && metricDef.history && metricDef.display && metricDef.display.chart) {
          var url;
          if (sensor._gwId) {
            // Aggregator mode: route history through the proxy endpoint
            url = '/api/aggregator/proxy/' + sensor._gwId + '/history/' + lookupId + '/' + m.key;
          } else {
            url = m.history_url || ('/history/' + lookupId + '/' + (metricDef.history_suffix || m.key));
          }
          historyMeasurements.push({ key: m.key, url: url });
        }
      });
    }
  }

  // Fallback: if no manifest data available, use legacy temp/hum paths
  if (historyMeasurements.length === 0) {
    if (sensor._gwId) {
      // Aggregator fallback: proxy the standard history metrics
      historyMeasurements = [
        { key: 'temp', url: '/api/aggregator/proxy/' + sensor._gwId + '/history/' + lookupId + '/temp' },
        { key: 'hum',  url: '/api/aggregator/proxy/' + sensor._gwId + '/history/' + lookupId + '/hum'  }
      ];
    } else {
      historyMeasurements = [
        { key: 'temp', url: '/history/' + lookupId + '/temp' },
        { key: 'hum',  url: '/history/' + lookupId + '/hum'  }
      ];
    }
  }

  // BUG-043-cont Fix 2: fetch metrics sequentially with a 300ms gap between requests.
  // Concurrent fetches via Promise.all trigger simultaneous NVS scan loops in the firmware
  // that each block the HTTP server task for 0.5–2 seconds, starving BLE/WiFi/watchdog.
  var results = [];
  var chain = Promise.resolve();
  historyMeasurements.forEach(function(m) {
    var isAggregatorProxy = !!sensor._gwId;
    chain = chain.then(function() {
      var req;
      if (isAggregatorProxy && typeof _aggregatorFetch === 'function') {
        req = _aggregatorFetch(m.url, {cache: 'no-store'});
      } else {
        req = fetch(ESP_HOST + m.url, {cache:'no-store'});
      }

      return req
        .then(function(r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
        .then(function(raw) { results.push({key: m.key, raw: raw}); })
        .then(function() { return new Promise(function(res) { setTimeout(res, 300); }); });
    });
  });
  return chain.then(function() { return results; });
}

function fetchSensorHistoryRows(sensor) {
  return fetchDeviceHistory(sensor, window._manifest).then(function(series) {
    var temp = '', hum = '';
    series.forEach(function(s) {
      if (s.key === 'temp') temp = s.raw;
      else if (s.key === 'hum') hum = s.raw;
    });
    return buildNormalizedSensorRows(temp, hum);
  });
}

function fetchAllSensorHistoryRowsSequentially(sensors, onProgress) {
  var queue = Array.isArray(sensors) ? sensors.slice() : [];
  var results = new Array(queue.length);
  return queue.reduce(function(chain, sensor, idx) {
    return chain.then(function() {
      if (typeof onProgress === 'function') onProgress(idx, sensor, queue.length);
      return fetchSensorHistoryRows(sensor).then(function(rows) {
        results[idx] = rows;
      }).catch(function() {
        // BUG-046: tolerate per-sensor fetch failures (e.g. empty history after migration)
        results[idx] = [];
      });
    });
  }, Promise.resolve()).then(function() {
    return results;
  });
}

function buildSingleSensorCsv(meta, sensor, rows) {
  var lines = [getSingleSensorExportColumns(sensor).join(',')];
  rows.forEach(function(row) {
    lines.push([
      csvEscape(meta.gatewayHost),
      csvEscape(meta.gatewayIp),
      row.timestamp,
      csvEscape(row.datetime_utc),
      formatMetricNumber(row.temp_c),
      formatMetricNumber(row.temp_f),
      formatMetricNumber(row.humidity_pct),
      formatMetricNumber(row.dewpoint_c)
    ].join(','));
  });
  return lines.join('\n') + '\n';
}

function buildMergedSensorCsv(meta, sensors, sensorRowsList) {
  var header = getMergedExportColumns(sensors);
  var union = {};
  sensorRowsList.forEach(function(rows, idx) {
    if (!rows) return; // BUG-046: guard against undefined/null entries (empty [] iterates safely)
    rows.forEach(function(row) {
      if (!union[row.timestamp]) {
        union[row.timestamp] = { timestamp: row.timestamp, datetime_utc: row.datetime_utc, sensorData: {} };
      }
      union[row.timestamp].datetime_utc = row.datetime_utc;
      union[row.timestamp].sensorData[idx] = row;
    });
  });

  var timestamps = Object.keys(union)
    .map(function(k) { return parseInt(k, 10); })
    .filter(function(v) { return isFinite(v); })
    .sort(function(a, b) { return a - b; });
  var lines = [header.join(',')];

  timestamps.forEach(function(ts) {
    var entry = union[ts];
    var rowOut = [
      csvEscape(meta.gatewayHost),
      csvEscape(meta.gatewayIp),
      ts,
      csvEscape(entry.datetime_utc || formatUtcForExport(ts))
    ];
    sensors.forEach(function(_sensor, idx) {
      var row = entry.sensorData[idx] || null;
      rowOut.push(formatMetricNumber(row ? row.temp_c : null));
      rowOut.push(formatMetricNumber(row ? row.temp_f : null));
      rowOut.push(formatMetricNumber(row ? row.humidity_pct : null));
      rowOut.push(formatMetricNumber(row ? row.dewpoint_c : null));
    });
    lines.push(rowOut.join(','));
  });

  return lines.join('\n') + '\n';
}

function currentExportDateTag() {
  return new Date().toISOString().slice(0, 10);
}


