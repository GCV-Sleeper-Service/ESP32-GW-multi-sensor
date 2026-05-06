function importFetchJsonWithRetry(url, options, label, statusEl, attempt) {
  var tryNum = Number(attempt || 1);
  return authFetch(url, options)
    .then(safeJsonResponse)
    .catch(function(err) {
      if (!isTransientImportError(err) || tryNum >= 3) throw err;
      var waitMs = 500 * Math.pow(2, tryNum - 1);
      if (statusEl) {
        statusEl.textContent = 'Transient tunnel/origin error during ' + label +
          '; retrying in ' + waitMs + ' ms (attempt ' + (tryNum + 1) + '/3)...';
      }
      return delay(waitMs).then(function() {
        return importFetchJsonWithRetry(url, options, label, statusEl, tryNum + 1);
      });
    });
}

function requestManagementCredentials(actionLabel) {
  return new Promise(function(resolve, reject) {
    var modal = document.getElementById('authModal');
    var title = document.getElementById('authTitle');
    var subtitle = document.getElementById('authSubtitle');
    var userInput = document.getElementById('authUsername');
    var passInput = document.getElementById('authPassword');
    var toggleBtn = document.getElementById('authToggle');
    var errorEl = document.getElementById('authError');
    var cancelBtn = document.getElementById('authCancel');
    var submitBtn = document.getElementById('authSubmit');
    if (!modal || !title || !subtitle || !userInput || !passInput || !toggleBtn || !errorEl || !cancelBtn || !submitBtn) {
      reject(new Error('Authentication dialog is unavailable'));
      return;
    }

    title.textContent = 'Management authentication required';
    subtitle.textContent = 'Authentication required for ' + actionLabel + '. Enter the case-sensitive management credentials to continue.';
    userInput.value = '';
    passInput.value = '';
    passInput.type = 'password';
    toggleBtn.setAttribute('aria-label', 'Show password');
    toggleBtn.setAttribute('title', 'Show password');
    errorEl.textContent = '';
    modal.classList.remove('hidden');
    modal.setAttribute('aria-hidden', 'false');

    var settled = false;
    var verifying = false;
    var verifyController = null;
    function setVerifyUiState(isBusy) {
      verifying = !!isBusy;
      submitBtn.disabled = !!isBusy;
      toggleBtn.disabled = !!isBusy;
      userInput.disabled = !!isBusy;
      passInput.disabled = !!isBusy;
      cancelBtn.disabled = false;
    }
    function cleanup() {
      if (verifyController && typeof verifyController.abort === 'function') {
        try { verifyController.abort(); } catch (e) {}
      }
      verifyController = null;
      setVerifyUiState(false);
      toggleBtn.removeEventListener('click', onToggle);
      cancelBtn.removeEventListener('click', onCancel);
      submitBtn.removeEventListener('click', onSubmit);
      userInput.removeEventListener('keydown', onKeyDown);
      passInput.removeEventListener('keydown', onKeyDown);
      modal.removeEventListener('click', onBackdropClick);
      document.removeEventListener('keydown', onEscape, true);
      modal.classList.add('hidden');
      modal.setAttribute('aria-hidden', 'true');
    }
    function finish(value, isError) {
      if (settled) return;
      settled = true;
      cleanup();
      if (isError) reject(value);
      else resolve(value);
    }
    function onToggle() {
      if (verifying) return;
      var show = passInput.type === 'password';
      passInput.type = show ? 'text' : 'password';
      toggleBtn.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
      toggleBtn.setAttribute('title', show ? 'Hide password' : 'Show password');
      passInput.focus();
      try { passInput.setSelectionRange(passInput.value.length, passInput.value.length); } catch (e) {}
    }
    function validateAndSubmit() {
      if (verifying) return;
      var username = String(userInput.value || '').trim();
      var password = String(passInput.value || '');
      if (!username) {
        errorEl.textContent = 'Management username is required.';
        userInput.focus();
        return;
      }
      if (!password) {
        errorEl.textContent = 'Management password is required.';
        passInput.focus();
        return;
      }
      setVerifyUiState(true);
      errorEl.textContent = 'Verifying credentials...';
      var authHeader = 'Basic ' + btoa(username + ':' + password);
      verifyController = (typeof AbortController !== 'undefined') ? new AbortController() : null;
      var requestOptions = {
        cache: 'no-store',
        headers: { 'Authorization': authHeader }
      };
      if (verifyController) requestOptions.signal = verifyController.signal;
      fetch(ESP_HOST + '/api/status/full', requestOptions).then(function(resp) {
        if (resp.ok) {
          setAuthCredentials(username, password);
          finish({ username: username, password: password, authHeader: authHeader }, false);
          return;
        }
        return resp.json().catch(function() { return null; }).then(function(data) {
          var msg = data && data.message ? data.message : ('HTTP ' + resp.status);
          throw new Error(msg);
        });
      }).catch(function(err) {
        verifyController = null;
        if (settled || (err && err.name === 'AbortError')) return;
        setVerifyUiState(false);
        errorEl.textContent = err && err.message ? err.message : 'Authentication failed';
        passInput.focus();
        passInput.select();
      });
    }
    function onCancel() {
      if (verifyController && typeof verifyController.abort === 'function') {
        try { verifyController.abort(); } catch (e) {}
      }
      finish(null, false);
    }
    function onSubmit() { validateAndSubmit(); }
    function onKeyDown(ev) {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        validateAndSubmit();
      }
    }
    function onEscape(ev) {
      if (ev.key === 'Escape') {
        ev.preventDefault();
        if (verifyController && typeof verifyController.abort === 'function') {
          try { verifyController.abort(); } catch (e) {}
        }
        finish(null, false);
      }
    }
    function onBackdropClick(ev) {
      if (ev.target === modal) {
        if (verifyController && typeof verifyController.abort === 'function') {
          try { verifyController.abort(); } catch (e) {}
        }
        finish(null, false);
      }
    }

    toggleBtn.addEventListener('click', onToggle);
    cancelBtn.addEventListener('click', onCancel);
    submitBtn.addEventListener('click', onSubmit);
    userInput.addEventListener('keydown', onKeyDown);
    passInput.addEventListener('keydown', onKeyDown);
    modal.addEventListener('click', onBackdropClick);
    document.addEventListener('keydown', onEscape, true);
    window.setTimeout(function() { userInput.focus(); userInput.select(); }, 0);
  });
}

function postManagementAction(path, busyText, actionLabel) {
  var statusEl = document.getElementById('mgmt-status');
  return requestAuth(actionLabel)
    .then(function() {
      if (!isAuthenticated()) {
        if (statusEl) statusEl.textContent = 'Action cancelled';
        throw new Error('Authentication cancelled');
      }
      if (statusEl) statusEl.textContent = busyText;
      return authFetch(ESP_HOST + path, {
        method: 'POST',
        cache: 'no-store',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'a=1'
      }).then(function(r) {
        if (r.status !== 401) return r;
        return requestAuth(actionLabel).then(function(creds) {
          if (!creds || !isAuthenticated()) throw new Error('Authentication cancelled');
          return authFetch(ESP_HOST + path, {
            method: 'POST',
            cache: 'no-store',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: 'a=1'
          });
        });
      });
    })
    .then(function(r) {
      return r.json().catch(function(){ return {ok:false, message:'Invalid JSON response'}; }).then(function(data) {
        if (!r.ok || !data.ok) {
          var msg = data.message || ('HTTP ' + r.status);
          throw new Error(msg);
        }
        return data;
      });
    })
    .then(function(data) {
      if (statusEl) statusEl.textContent = data.message || 'Done';
      return data;
    })
    .catch(function(err) {
      if (statusEl) statusEl.textContent = err.message === 'Authentication cancelled' ? 'Action cancelled' : 'Action failed: ' + err.message;
      throw err;
    });
}

function rebootESP() {
  if (!confirm('Reboot this ESP32 gateway now? The dashboard connection will drop briefly.')) return;
  postManagementAction('/api/reboot', 'Scheduling reboot...', 'gateway reboot').catch(function(){});
}

function deleteHistoryData() {
  if (!confirm('Delete persisted sensor history from the dedicated history partition and clear RAM history on the ESP?')) return;
  postManagementAction('/api/delete-data', 'Deleting history...', 'history deletion').then(function() {
    resetHistoryVisuals();
    loadStorageStats().catch(function(){});
  }).catch(function(){});
}

// ═══════════════════════════════════════════════════════════════════
// Import v1 — CSV import into NVS history
// ═══════════════════════════════════════════════════════════════════
