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

function buildNormalizedSensorRows(series) {
  var metricMaps = {};
  var seen = {};
  var timestamps = [];

  (series || []).forEach(function(metricSeries) {
    if (!metricSeries || !metricSeries.key) return;
    var metricMap = parseHistoryMetricLines(metricSeries.raw || '');
    metricMaps[metricSeries.key] = metricMap;
    Object.keys(metricMap).forEach(function(key) {
      var ts = parseInt(key, 10);
      if (isFinite(ts) && !seen[ts]) { seen[ts] = true; timestamps.push(ts); }
    });
  });

  timestamps.sort(function(a, b) { return a - b; });
  var metricKeys = Object.keys(metricMaps);

  return timestamps.map(function(ts) {
    var row = {
      timestamp: ts,
      datetime_utc: formatUtcForExport(ts)
    };
    metricKeys.forEach(function(key) {
      var value = metricMaps[key][ts];
      row[key] = (typeof value === 'number' && isFinite(value)) ? value : null;
    });

    var tC = row.temp;
    var hum = row.hum;
    if (metricMaps.temp) {
      row.temp_c = tC;
      row.temp_f = tC !== null ? (tC * 9 / 5 + 32) : null;
    }
    if (metricMaps.hum) row.humidity_pct = hum;
    if (metricMaps.temp && metricMaps.hum) {
      var dp = null;
      if (tC !== null && hum !== null) {
        var dpv = calcDewPoint(tC, hum);
        if (dpv !== null && isFinite(dpv)) dp = dpv;
      }
      row.dewpoint_c = dp;
    }
    return row;
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
    var metricColumns = getMetricColumnsForSensor(sensor, window._manifest);
    if (!metricColumns.length && (!series || !series.length)) return [];
    return buildNormalizedSensorRows(series);
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
  var metricColumns = getMetricColumnsForSensor(sensor, window._manifest);
  var lines = [getSingleSensorExportColumns(sensor).join(',')];
  var role = getExportRole(sensor, window._manifest);
  rows.forEach(function(row) {
    var rowOut = [
      csvEscape(meta.gatewayHost),
      csvEscape(meta.gatewayIp),
      csvEscape(role),
      row.timestamp,
      csvEscape(row.datetime_utc)
    ];
    metricColumns.forEach(function(column) {
      rowOut.push(formatMetricNumber(row ? row[column] : null));
    });
    lines.push(rowOut.join(','));
  });
  return lines.join('\n') + '\n';
}

function buildMergedSensorCsv(meta, sensors, sensorRowsList) {
  var header = getMergedExportColumns(sensors);
  var mergedRole = sensors.some(function(sensor) { return sensor && sensor._gwId && window._manifest && window._manifest.gateway && sensor._gwId !== window._manifest.gateway.id; }) ? 'satellite' : getExportRole(null, window._manifest);
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

  var sensorMetricColumns = sensors.map(function(sensor) {
    return getMetricColumnsForSensor(sensor, window._manifest);
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
      csvEscape(mergedRole),
      ts,
      csvEscape(entry.datetime_utc || formatUtcForExport(ts))
    ];
    sensors.forEach(function(sensor, idx) {
      var row = entry.sensorData[idx] || null;
      var metricColumns = sensorMetricColumns[idx];
      metricColumns.forEach(function(column) {
        rowOut.push(formatMetricNumber(row ? row[column] : null));
      });
    });
    lines.push(rowOut.join(','));
  });

  return lines.join('\n') + '\n';
}

function currentExportDateTag() {
  return new Date().toISOString().slice(0, 10);
}


