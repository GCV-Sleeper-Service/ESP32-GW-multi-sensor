var _authHeader = null;
var _authPromptSuppressed = false;
var _authPromptPending = null;

function _copyAuthHeaders(headers) {
  var out = {};
  if (!headers) return out;
  if (typeof Headers !== 'undefined' && headers instanceof Headers) {
    headers.forEach(function(value, key) { out[key] = value; });
    return out;
  }
  if (Array.isArray(headers)) {
    headers.forEach(function(entry) {
      if (!entry || entry.length < 2) return;
      out[entry[0]] = entry[1];
    });
    return out;
  }
  Object.keys(headers).forEach(function(key) {
    out[key] = headers[key];
  });
  return out;
}

function setAuthCredentials(username, password) {
  _authHeader = 'Basic ' + btoa(String(username || '') + ':' + String(password || ''));
  _authPromptSuppressed = false;
  return _authHeader;
}

function setAuthHeader(header) {
  _authHeader = header || null;
  if (_authHeader) _authPromptSuppressed = false;
  return _authHeader;
}

function clearAuth() {
  _authHeader = null;
}

function cancelAuth() {
  _authHeader = null;
  _authPromptSuppressed = true;
}

function shouldPromptForAuth() {
  return !_authPromptSuppressed;
}

function isAuthenticated() {
  return _authHeader !== null;
}

function getAuthHeader() {
  return _authHeader;
}

function authFetch(url, opts) {
  var req = Object.assign({}, opts || {});
  var headers = _copyAuthHeaders(req.headers);
  if (_authHeader) headers.Authorization = _authHeader;
  if (Object.keys(headers).length) req.headers = headers;
  else delete req.headers;
  delete req.credentials;
  return fetch(url, req).then(function(resp) {
    if (resp.status === 401 && _authHeader) clearAuth();
    return resp;
  });
}

function probeAuth() {
  return fetch(ESP_HOST + '/api/status/full', {cache: 'no-store'})
    .then(function(resp) {
      if (resp.status === 401) return 'required';
      return 'not-required';
    })
    .catch(function() {
      return 'required';
    });
}

function requestAuth(actionLabel) {
  if (_authPromptPending) return _authPromptPending;
  _authPromptPending = Promise.resolve(requestManagementCredentials(actionLabel || 'dashboard access'))
    .then(function(creds) {
      if (!creds) {
        cancelAuth();
        return null;
      }
      if (creds.authHeader) setAuthHeader(creds.authHeader);
      else setAuthCredentials(creds.username, creds.password);
      return creds;
    });
  return _authPromptPending.then(function(result) {
    _authPromptPending = null;
    return result;
  }, function(err) {
    _authPromptPending = null;
    throw err;
  });
}
