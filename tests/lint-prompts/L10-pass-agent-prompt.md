# Lint fixture: L10 passes (agent prompt)

Made-up text for scripts/lint-prompts.sh. This sentence names git checkout main outside a code block, so L10 does not count it.

```bash
git fetch origin main
git checkout -b feature/lint-fixture origin/main
test "$(git branch --show-current)" = "feature/lint-fixture" || exit 1
```
