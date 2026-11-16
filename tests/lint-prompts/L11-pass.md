# Lint fixture: L11 passes

Made-up text for scripts/lint-prompts.sh. The login comes from the environment; no line holds a literal.

```bash
curl -s -u "$ESP_USER:$ESP_PASS" http://192.0.2.10/api/status/full
curl -s --user "${ESP_USER}:${ESP_PASS}" http://192.0.2.10/api/status/full
curl -s -H "Authorization: Basic $(printf '%s' "$ESP_USER:$ESP_PASS" | base64)" http://192.0.2.10/api/status/full
git push -u origin feature/lint-fixture
date -u +%H:%M:%S
```
