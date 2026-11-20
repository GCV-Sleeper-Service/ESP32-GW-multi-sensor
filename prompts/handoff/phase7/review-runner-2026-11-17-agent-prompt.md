# Review-runner PR (R5r) — review B by a runner on Agent Platform, reviews A, B and C in the documents (GPT/Codex Agent Prompt)

_Intent, interface contracts and acceptance criteria (MEDIUM tier)_
_Date: 2026-11-17; reconciled with audit rounds 1 to 3 on 2026-11-18_
_Prerequisite: `main` contains `640906f` (PR #239, R5c); `VERSION` 7.7.1.1_
_Risk: MEDIUM — one new workflow that signs in to Google Cloud and posts a PR comment, one new script, documents; no firmware source, no partition, no version bump, no board, no generated file_
_Doctrinal precedence: where this prompt and `Docs/development-process-guide.md` conflict, the process guide governs, except for the two exemptions of §5: no changelog entry, and no change of "Last verified" or "What Just Shipped" in `CURRENT-STATE.md`._

---

## ⚠️ Universal Execution Preamble

1. Do NOT optimise, restructure, or "improve" these instructions. Execute them literally.
2. Do NOT remove safety constraints, even if they seem redundant.
3. Do NOT make changes to files not listed in §3.
4. If an instruction seems wrong, STOP and flag it — do not silently fix it.
5. If you run out of context, STOP at the last completed checkpoint and report what remains.

## ⚠️ Lessons that shape this step

- Every gate and every checkpoint is in the check file `/root/r5r/review-runner-2026-11-17-checks.sh`. The setup block has checked its SHA-256 and committed a copy as `prompts/handoff/phase7/review-runner-2026-11-17-checks.sh`. Run each one exactly as this prompt writes it, for example `bash /root/r5r/review-runner-2026-11-17-checks.sh A`. Never type a check by hand, never retype a check from this prompt, and never edit the check file (PLAN-031).
- The check file also writes the scope list (`... scope`) and copies the supplied files (`... copy 1`, `... copy 3`). Never open a supplied file in an editor, and never change one: the tests, the template, the planner page, the process guide, the operator page, the review file and the audit file are fixed texts.
- This prompt is MEDIUM: it prescribes the interfaces and the tests, and you write the code of the script and the workflow. The supplied tests are the contract of the script; CHECKPOINT B is the contract of the workflow. If a test or a check seems wrong, STOP and flag it; never change a test to make it pass.
- If one of your own commands fails, repair it and repeat the step. Run no checkpoint while an edit before it is missing (PR #234, stop 1).
- Run one test command at a time: no second preflight, Playwright run, mock server or test run while one is running (PR #234, stop 2). The PRE-PR gate runs preflight once.
- Every edit of Task Group 3 is verbatim and anchored by quoted text, never by a line number. Text between a pair of fence lines is literal: copy it exactly, blank lines and indentation included; the fence lines themselves are not part of it.
- A check prints `⛔ CHECKPOINT FAILED - <block>: <reason>` and exits non-zero on a mismatch. Then post the checkpoint-failure comment from `Docs/development-process-guide.md` §3.2 and stop. Never edit a check or an expected value to make it pass.
- This step needs no login, calls no board and calls no Google service. The tests run the script against stubs on `127.0.0.1`. Never print, echo or write `$ESP_USER` or `$ESP_PASS`. Never write a real project ID, provider name or service account of the operator's Google Cloud into a file: they live as variables of the GitHub environment `external-review`, which the operator creates. The tests use made-up values such as `example-project-1`.

---

## §1 — Repository & Required Reading

The setup block has already created your feature branch `tooling/r5r-2026-11` and committed this prompt and its check file. The §2 gate checks the branch.

Read completely, in this order:
0. `CURRENT-STATE.md` — every section; Task Group 3 edits five places.
1. `Docs/development-process-guide.md` — §2.2 to §2.5, §3.1, §3.2 and §7.
2. `AGENTS.md` — every section.
3. `Docs/plan-of-record.md` — sections 2, 3, 5 (the blocks of R5, R5c and R5r), 6 and 7.
4. `Docs/decisions/decision-log.md` — the rows PLAN-017, PLAN-019, PLAN-022, PLAN-023, PLAN-034.
5. After `copy 1`: `Docs/templates/external-review-template.md` and `tests/external-review/test_external_review.py`, whole files.
6. `.github/workflows/ci.yml` and `.github/workflows/pr-body-check.yml` — for the house style of a workflow.
7. `scripts/lint-prompts.sh` — the function `l11_literal` (rule L11), which item 2.1 reuses.

## §2 — Pre-Implementation Verification Gate

Run this BEFORE any edit:

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh sec2
```

It must end with `§2 PASS`. It checks the branch, that `640906f` is an ancestor, `VERSION`, a clean tree, the saved prompt and check file, the tools (`python3` 3.12 or later, a Python with PyYAML that imports it under `-I`, `node_modules` with Playwright, the `en_US.UTF-8` locale), that no new path of §3 exists yet, every anchor of Task Group 3, and that each file this step changes is still byte-identical to `main` at `640906f`. On any other output STOP and post the checkpoint-failure comment.

## §3 — Scope Boundary

Files you MAY modify (complete list, 17 paths; nothing else).

CHANGED (7):
- `CURRENT-STATE.md`
- `Docs/plan-of-record.md`
- `Docs/decisions/decision-log.md`
- `Docs/development-process-guide.md`
- `Docs/planner-start-here.md`
- `Docs/templates/prompt-audit-template.md`
- `prompts/phase7/consolidated-audit-template-phase7.md`

NEW (10):
- `.github/workflows/external-review.yml`
- `scripts/external-review.py`
- `Docs/templates/external-review-template.md`
- `tests/external-review/test_external_review.py`
- `Docs/operator/R5r-review-runner.md`
- `prompts/handoff/phase7/review-runner-2026-11-17-review.md`
- `prompts/handoff/phase7/review-runner-2026-11-17-audit.md`
- `prompts/handoff/phase7/review-runner-2026-11-17-agent-prompt.md`
- `prompts/handoff/phase7/review-runner-2026-11-17-checks.sh`
- `prompts/handoff/phase7/review-runner-2026-11-17.md`

Write the list to the file that `git rev-parse --git-path scope-allowed.txt` names; it sits inside `.git`. The PRE-PR gate checks every changed path against it with `scripts/scope-gate.py`:

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh scope
```

It must print `scope list written: 17 paths`.

Files you MUST NOT modify: anything under `firmware/`, `src/`, `partitions/`, `config/`, `dashboard/`; every other file under `scripts/`, `tests/`, `.github/` and `prompts/`; `package.json`, `package-lock.json`, `playwright.config.js`; `AGENTS.md`, `CLAUDE.md`, `README.md`, `VERSION`, `Docs/changelog.md`; every other file under `Docs/`. If the pipeline that `AGENTS.md` asks for before a commit changes `dashboard/dashboard.h` or another generated file, STOP: R5 made the header reproducible, so a change there is a finding.

You MUST NOT: run `bash scripts/bump-version.sh`; run `esphome compile`, `esphome upload` or `esphome run`; contact any board; call any Google service; start a workflow by hand; create a GitHub environment, variable or secret; create, close or edit issues or milestones; change branch protection; delete a file; merge.

## §4 — Critical Rules Checklist

- Rule 4 — no generated file is edited, by hand or by the pipeline: this step changes none.
- Rules 62/63 — checkpoints are queries with expected values; on mismatch STOP, do not fix.
- PLAN-022 — `workflow_dispatch` only; environment `external-review`; no stored key; PR text is data; posts one comment as `github-actions[bot]`; models from an allow-list in the script on `main`.
- SEC-003 — no login, key or token in any command, file or PR text; no real project ID, provider name or service account in any file or PR text (PLAN-036: they appear only in the Actions log of a run).
- Workflow security: no `${{ ... }}` expression inside any `run:` block; inputs reach the scripts through `env:` only. No `secrets.` reference anywhere in the new workflow.

## §5 — DO-NOT List

- Do NOT check out, fetch or run code of the pull request under review in the workflow: the script reads its files through the GitHub API.
- Do NOT add a dependency: the script uses the Python standard library only; the workflow uses `actions/checkout` and `google-github-actions/auth`, each pinned to the commit that item 2.2 names, and no other action.
- Do NOT add a trigger to the new workflow other than `workflow_dispatch`.
- Do NOT write turn texts or rules for the model into the script: they come from `Docs/templates/external-review-template.md`.
- Do NOT reword, reformat or move text around an edit of Task Group 3.
- Do NOT bump the version or add a changelog entry. The changelog entry of process guide §2.5 does not apply to this step, because `VERSION` does not change; §3 and this section govern here.
- Do NOT change the line "_Last verified: ..." or the table "What Just Shipped" of `CURRENT-STATE.md`. Process guide §2.5 item 2 asks for both, but neither applies here: "Last verified" records the operator's check of the boards, and "What Just Shipped" lists versioned steps (R5 and R5c changed neither). Task Group 3 is the whole change of `CURRENT-STATE.md` in this step.
- Do NOT change `AGENTS.md`, `CLAUDE.md` or a Copilot instruction file.

## §6 — Implementation Steps

Commit after each checkpoint that passes, with a message that names the task group, and push.

### Task Group 1 — The supplied texts: template and tests

**1.1** Copy the two supplied files: `Docs/templates/external-review-template.md` (the system text and the three turn texts, built from the review files of R5 and R5c) and `tests/external-review/test_external_review.py` (31 black-box tests of the script, with a stub GitHub API that answers with the fields of real responses, a stub model endpoint and a stub `gcloud`). It must print `copied 2 files`.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh copy 1
```

⛔ **CHECKPOINT A** — the two files are the supplied ones, and every one of the 31 tests fails as long as the script does not exist, and for that reason.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh A
```

### Task Group 2 — The runner: `scripts/external-review.py` and `.github/workflows/external-review.yml` (PLAN-022, PLAN-036)

Intent: the operator starts review B by hand from the Actions tab, on `main`. The job signs in to Google Cloud without a stored key, reads the step's agent prompt and review file at the head of the pull request, runs the three turns of the template on a Gemini model through Agent Platform, and posts turn 3 as one comment, or in a dry run writes all three turns to the run summary and posts nothing.

**2.1** Write `scripts/external-review.py` to this contract. The tests in `tests/external-review/test_external_review.py` encode it; read them.

- Python 3.12 standard library only. Run as `python3 -I scripts/external-review.py`, from the repository root or from any other directory. It reads `Docs/templates/external-review-template.md` relative to its own file (`../Docs/templates/` from `scripts/`) and takes the one `text` block under each of the headings `## System`, `## Turn 1`, `## Turn 2` and `## Turn 3`, word for word.
- Inputs, all from the environment: `GITHUB_REPOSITORY`, `GITHUB_TOKEN`, `GITHUB_API_URL` (default `https://api.github.com`), `GITHUB_STEP_SUMMARY` (append to it; skip it when unset), `ER_PR`, `ER_PROMPT_PATH`, `ER_REVIEW_PATH` (empty: no review file), `ER_MODEL`, `ER_THINKING_LEVEL`, `ER_DRY_RUN`, `ER_PROJECT_ID`, `ER_PROFILE`, `ER_ENDPOINT` (default `https://aiplatform.googleapis.com`). The tests point the two URLs at stubs on `127.0.0.1`.
- Refusals: exit code 2; stderr holds exactly one line, and the summary gets the same line; it begins `external-review: refused:`; nothing is posted. Before any request: `ER_PR` not of the form `[1-9][0-9]{0,6}` in ASCII digits; `ER_PROMPT_PATH` empty; a path that is not a plain relative path (segments of `A-Za-z0-9._-` joined by single `/`; no empty segment, no `.` or `..` segment, no `/` at the start or the end); `ER_MODEL` not an enabled model of the allow-list; `ER_THINKING_LEVEL` not a level of that model; `ER_DRY_RUN` other than `true` or `false`; `ER_PROJECT_ID` not of the form `[a-z][a-z0-9-]{4,28}[a-z0-9]`; `ER_PROFILE` not of the form `[a-z][a-z0-9_]{0,19}`; `GITHUB_REPOSITORY` not `owner/repo`; `GITHUB_API_URL` or `ER_ENDPOINT` that is neither its default nor `http://127.0.0.1:<port>`. After the reads and before any model call, in this order: the prompt or the review file not found at the head (the line says "not found"), not a file that the Contents API returns with `encoding` `base64`, not valid base64 (the line says "not valid base64"), or not UTF-8 text (the line says "not UTF-8 text"); a file list with fewer entries than the pull request's `changed_files`; a data block that holds a login literal (below); data above the limit (below).
- Allow-list: a dictionary in the script, each model name a string literal. Enabled: `gemini-4-hydrogen` with the thinking levels `LOW`, `MEDIUM`, `HIGH` and `XHIGH`; `gemini-4-argon` and `gemini-4-carbon` with `LOW`, `MEDIUM` and `HIGH` (Google's model pages list no `XHIGH` for them). Listed and switched off: `claude-opus-5-5` and `claude-sonnet-5-5` (models of another vendor on Agent Platform). Switching one on is a pull request to `main`.
- GitHub reads, each with `Authorization: Bearer $GITHUB_TOKEN` and a timeout of 60 seconds: the pull request (`/repos/{repo}/pulls/{n}`: number, title, state, body, `head.sha`, `base.ref`, `base.sha`, `changed_files`); its diff (the same URL with `Accept: application/vnd.github.diff`); the lists `/pulls/{n}/files`, `/pulls/{n}/reviews`, `/pulls/{n}/comments` and `/issues/{n}/comments`, each with `per_page=100` on every page, following `Link: rel="next"` only to the scheme, host and port of `GITHUB_API_URL` (a next link elsewhere ends the run, exit code 1, the line says "next"; a next link to a URL already read ends it too, the line says "already read"); the agent prompt and the review file through `/repos/{repo}/contents/{path}?ref={head sha}`, whose `content` is base64 broken into lines, as GitHub sends it. The script decodes it strictly: the line breaks removed, then base64 with validation, then UTF-8 with no replacement; the SHA-256 of a file is that of its decoded bytes.
- Redirects: the script follows no HTTP redirect to another scheme, host or port, for GitHub and for the model alike; such a redirect ends the run with exit code 1, and the line says "redirect". A redirect within the same origin may be followed.
- The pull request: the script reads the pull request object at the start (its `head.sha` is the head and its `base.sha` the base), once more after all data is read and before the first model call, and, in a posting run only, once more before it posts; no other read of the object. If the head, the base commit or the base branch changed, exit code 1, the line says "the pull request moved" and names the old and the new values, and nothing is sent or posted after it.
- Generated files: a diff section is left out when both paths of its line `diff --git a/<old> b/<new>` are generated files, that is one of `dashboard/sensor_history_multi.h`, `dashboard/dashboard.js`, `dashboard/dashboard.html`, `dashboard/dashboard.h` and `src/gateway_manifest.h` (a change, an addition or a deletion has the same path twice). A section with one generated and one ordinary path, a rename across the line, stays whole, so that no ordinary code is hidden. The sections before and after a left-out section stay.
- Data blocks: each piece of data stands between the line `<<<BEGIN UNTRUSTED DATA: <name> sha256=<SHA-256 of the content as read>>>>` and the line `<<<END UNTRUSTED DATA: <name>>>>`. Inside, a line that begins with `<<<` gets one space in front and is otherwise kept. Turn 1: `agent-prompt`, then `review-file` (absent when there is none). Turn 2: `pr-metadata` (number, title, state, base ref and base commit, head), `pr-body`, `changed-files` (one line per file, `<status> <filename>`, or `renamed <previous_filename> -> <filename>`; never the `patch` field of the list), `diff` (without the generated sections), `reviews` (each review with its author's login, state and text), `review-comments`, `comments` (each with its author's login and text). The entries of `review-comments` are separated by one blank line, and each is `<id> <login> on <path> <where> side <side> commit <commit_id> original commit <original_commit_id>`, then ` reply to <in_reply_to_id>` when it is a reply, then `: ` and its text. `<where>` is `file` for a comment on the whole file (`subject_type` `file`, or neither `line` nor `original_line`); `lines <start_line> to <line>` when `start_line` is set; `line <line>`; or `outdated, original line <original_line>` when `line` is empty. Turn 3 has no data.
- Login literals: before any model call the script checks every line of every data block, and every line of the whole diff before the generated sections are left out, with the definition of rule L11 of `scripts/lint-prompts.sh`: a value after `-u` or `--user` whose user part is a plain name (letters, digits, `.`, `_`, `@`, `-`), or whose user part is a variable and whose password part is not; or a value after `Authorization: Basic` that does not start with `$`, `{`, `<`, `.` or `*`. A line of the diff is checked without its first character (the `+`, `-` or space of the diff). This check runs before the limit, so that a refusal for size implies that no login literal was found. On a hit the run is refused; the line names the block and the line number and says "login literal", and never shows the value. Each answer of the model is checked the same way before it goes into the next request, the summary or the comment; on a hit, exit code 1, the line names the turn and the line and says "login literal", and nothing of the answer is passed on. Write the pattern so that L11 finds no login literal in the script itself: the PRE-PR gate runs L11 on every changed file.
- Limit: `LIMIT_CHARS = 600000`, a line of the script. The characters of all data blocks of turns 1 and 2 together, each counted from the first `<` of its `<<<BEGIN` line to the last `>` of its `<<<END` line, without the line break that follows, may not exceed it; exactly 600,000 is allowed. Above it, the run is refused and the line says `input of <n> characters exceeds the limit of 600000`, with the counted number. The script never cuts data.
- Model calls: one conversation of three requests, `POST {ER_ENDPOINT}/v1/projects/{ER_PROJECT_ID}/locations/global/publishers/google/models/{ER_MODEL}:generateContent` with `Content-Type: application/json` and a timeout of 600 seconds. Before each request, a fresh access token from `gcloud auth print-access-token` (timeout 60 seconds), run with the environment that the script inherited: the sign-in step of the workflow puts the path of its credential file there. The only child process of the script is `subprocess.run(["gcloud", "auth", "print-access-token"], ...)`, with that list written in the call and no keyword argument but `capture_output`, `text`, `timeout`, `check`, `stdout`, `stderr`, `encoding` and `errors`. With these timeouts the three model turns and their tokens take at most 33 minutes, which leaves room in the job's 60 minutes for the GitHub requests. The body has exactly three fields: `systemInstruction` (`{"parts": [{"text": <System>}]}`), `contents`, and `generationConfig` (`{"thinkingConfig": {"thinkingLevel": <ER_THINKING_LEVEL>}}`). A user turn is `{"role": "user", "parts": [{"text": <the turn text, a blank line, then its data blocks separated by blank lines>}]}`; turn 3 is its turn text alone. After each answer, `contents` gets the first candidate's `content` exactly as returned, every part in order with every field (such as `thoughtSignature`), and then the next user turn. The answer is the text of that candidate's parts that are not marked `thought`.
- Failures: exit code 1; stderr holds exactly one line, and the summary gets the same line; it begins `external-review: failed:` and never holds an HTTP header or a token. Unless the line says otherwise, nothing was posted. The line holds these words: a GitHub HTTP error, `GitHub <GET or POST> <path without query>: HTTP <status>`; a model HTTP error, `the model call of turn <n> failed: HTTP <status>`; a response without a candidate, `no answer (blocked: <promptFeedback.blockReason>)`, or `no reason given` in place of the reason; a `finishReason` other than `STOP`, `the model stopped with <reason>`; an answer without visible text, `no answer`; `gcloud` failing or printing nothing, `gcloud auth print-access-token failed`; a timeout or a closed connection, the request and `no answer`. A usage count that is missing counts as 0.
- Header: the summary and the comment start with this header. Its first line is `## Review B - runner: <ER_MODEL>, thinking <ER_THINKING_LEVEL>`, followed by ` (dry run)` in a dry run. Then a blank line and this table, row by row:

```
| Field | Value |
|---|---|
| Pull request | #<number>, head `<head sha>`, base `<base ref>` at `<base sha>` |
| Profile | <ER_PROFILE> |
| Model version | <modelVersion of the last answer> |
| Tokens | turn 1: prompt <n>, output <n>, thinking <n>; turn 2: prompt <n>, output <n>, thinking <n>; turn 3: prompt <n>, output <n>, thinking <n>; total: prompt <n>, output <n>, thinking <n> |
| Agent prompt | `<ER_PROMPT_PATH>` sha256 `<SHA-256>` |
| Review file | `<ER_REVIEW_PATH>` sha256 `<SHA-256>` |
| Generated files left out | `<path>`, `<path>` |
```

  The prompt counts are `promptTokenCount`, the output counts `candidatesTokenCount`, the thinking counts `thoughtsTokenCount`. "Review file" is `none` when there is none; "Generated files left out" lists the generated path of each section left out, in the order of the diff, or is `none`. The header names the pull request by its number, its head commit, and its base branch and commit only: no title, no head branch and no other text of the pull request.
- Output: the summary gets the header and then, for each turn, a line `### Turn <n>`, a blank line and the answer. It is written before any posting. If it would be longer than 1,000,000 bytes in UTF-8, the summary gets the header and then the failure line, without the answers; nothing is posted; the run ends with exit code 1, and the line says "too long for the run summary". With `ER_DRY_RUN=false` the script then posts exactly one comment, `POST /repos/{repo}/issues/{n}/comments`, with the header, a blank line and the answer of turn 3. A comment longer than 65,000 characters is not posted (exit code 1, the line says "the comment is too long"); the review stays in the summary. A post that GitHub refuses ends with exit code 1 and its status. A post without an answer (a timeout or a closed connection) ends with exit code 1, and the line says "unknown whether the comment was posted"; the script never posts twice.
- Clean text: the whole summary text and the whole comment are cleaned after they are put together. Each `\r\n` and `\r` becomes `\n`. Each `&#47;` and `&#x2f;` becomes `/`, and each `@`, `&#64;` and `&#x40;` becomes `(at)`, in any letter case. No line may begin with `/` after its leading spaces, tabs and the characters `>`, `-`, `*` and `+`, and after a list number such as `1.` or `2)`; put a mark such as `› ` in front of such a line.
- Never print or write `GITHUB_TOKEN` or an access token, and never send `GITHUB_TOKEN` to the model endpoint. Thought text and thought signatures never reach stdout, stderr, the summary or the comment.

**2.2** Write `.github/workflows/external-review.yml` to this contract. CHECKPOINT B checks each point.

- `name: External Review`, and a comment at the top that points to `Docs/operator/R5r-review-runner.md`. The top level has the keys `name`, `on`, `permissions` and `jobs` and no other.
- Trigger `workflow_dispatch` only, with exactly these inputs: `pr` (string, required); `prompt_path` (string, required); `review_path` (string, not required, default `""`); `model` (choice, required, default `gemini-4-hydrogen`, options `gemini-4-hydrogen`, `gemini-4-argon`, `gemini-4-carbon`); `thinking_level` (choice, required, default `HIGH`, options `LOW`, `MEDIUM`, `HIGH`, `XHIGH`; its description names `XHIGH` and `gemini-4-hydrogen`, the one model that takes it); every input has a `description`, and no other key than `description`, `required`, `type`, `default` and `options`; `workflow_dispatch` has the key `inputs` only; `profile` (choice, required, default `default`, options `default`); `dry_run` (boolean, required, default `true`).
- `permissions: {}` at the top level. One job, `review`, with the keys `if`, `runs-on`, `environment`, `timeout-minutes`, `concurrency`, `permissions` and `steps` and no other: `if: github.ref == 'refs/heads/main'`; `runs-on: ubuntu-24.04` under the comment line of R5c (`# Pinned to one Ubuntu release: the runner's OS changes only through a pull request (R5c, PLAN-034).`); `environment: external-review`; `timeout-minutes: 60`; `concurrency` with `group: external-review` and `cancel-in-progress: false`; and the job permissions `contents: read`, `id-token: write`, `pull-requests: write`, nothing else.
- Exactly four steps, in this order, with these names:
  1. `Checkout main`: `uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0` (the commit of tag `v4.4.0`, which tag `v4` names on 2026-11-18), with `persist-credentials: false` and no other input.
  2. `Select profile`: `id: profile`, `shell: bash`, and `env` exactly as in the block below, so that only the chosen profile's values reach the step and its log (PLAN-036). The first command line of its `run` block begins with `python3 -I`, and the block uses the standard library only; GitHub runs it with `bash --noprofile --norc -eo pipefail`, and so does check B. It fails with a message on stderr when `PROFILE` is not of the form `[a-z][a-z0-9_]{0,19}`; when `PROJECT_ID` or `PROVIDER` is empty, and then the message holds `the environment external-review has no GCP_PROJECT_ID_<PROFILE> or no GCP_WIF_PROVIDER_<PROFILE>` with the profile in upper case; and when a value holds a carriage return or a line feed. Otherwise it appends exactly three lines to `$GITHUB_OUTPUT`: `project_id=<value>`, `provider=<value>` and `service_account=<value>`, empty after `=` when there is no service account.
  3. `Sign in to Google Cloud`: `uses: google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 # v3.0.0` (the commit of tags `v3` and `v3.0.0` on 2026-11-18), with exactly `project_id: ${{ steps.profile.outputs.project_id }}`, `workload_identity_provider: ${{ steps.profile.outputs.provider }}` and `service_account: ${{ steps.profile.outputs.service_account }}` (empty: direct federation; set: a service account without a key).
  4. `Run the review`: `shell: bash`, `run: python3 -I scripts/external-review.py`, and `env` exactly `GITHUB_TOKEN: ${{ github.token }}`, `ER_PR: ${{ inputs.pr }}`, `ER_PROMPT_PATH: ${{ inputs.prompt_path }}`, `ER_REVIEW_PATH: ${{ inputs.review_path }}`, `ER_MODEL: ${{ inputs.model }}`, `ER_THINKING_LEVEL: ${{ inputs.thinking_level }}`, `ER_DRY_RUN: ${{ inputs.dry_run }}`, `ER_PROJECT_ID: ${{ steps.profile.outputs.project_id }}` and `ER_PROFILE: ${{ inputs.profile }}`.

The `env` of the step `Select profile`:

```
PROFILE: ${{ inputs.profile }}
PROJECT_ID: ${{ inputs.profile == 'default' && vars.GCP_PROJECT_ID_DEFAULT || '' }}
PROVIDER: ${{ inputs.profile == 'default' && vars.GCP_WIF_PROVIDER_DEFAULT || '' }}
SERVICE_ACCOUNT: ${{ inputs.profile == 'default' && vars.GCP_SERVICE_ACCOUNT_DEFAULT || '' }}
```

⛔ **CHECKPOINT B** — the 31 tests pass against your script; the script is standard library only, runs no shell, and starts no process but the one `gcloud` call of item 2.1; the workflow has exactly the structure above; the step `Select profile` works for `default` and for a second profile, and refuses bad names, missing values and line breaks.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh B
```

### Task Group 3 — Documents: state, plan, decisions, templates, supplied pages

Reviews A, B and C replace the two external reviews in every place that states the review pipeline (PLAN-023), the planning notes move to their private repository (PLAN-035), and the choices of R5r and of its audit are recorded (PLAN-036, PLAN-037). CHECKPOINT C searches the whole file for the old wording of each status mark.

**3.1** `CURRENT-STATE.md`: exactly one line begins with `_Next action: `. Replace that whole line with
```
_Next action: R5a, the producer contract, a documentation PR that does not wait for the review runner; the dry run and the posting run of the runner on PR #239 (operator, `Docs/operator/R5r-review-runner.md`) come before the next code step. The order and the scope of every step are in `Docs/plan-of-record.md` (PLAN-024). Phase 7 Step v7.7.1.2 is dispatched after R5a and R5b._
```

**3.2** `CURRENT-STATE.md`: replace the line
```
1. **R5r, R5a, R5b** — the review-runner PR, the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017, PLAN-022). No firmware change.
```
with
```
1. **R5a, R5b** — the producer contract, and the Batch 2 prompts re-produced under the method of record (PLAN-017). No firmware change. Review B runs on the review runner from now on (PLAN-022, PLAN-023).
```

**3.3** `CURRENT-STATE.md`: exactly one line begins with `| R5c planning (CI logs) |`. Immediately after that line, insert
```
| PR #239 review A | Four helper scripts print `esphome run` advice: `scripts/provision.sh`, `scripts/render_sensor_config.py`, `scripts/change_sensor_number.py`, `scripts/patch-esphome-httpd-stack.sh`; `AGENTS.md` allows only `esphome upload` and `esphome compile` | **Not implemented** — the advice is printed, not run; routed to a later script-cleanup step that the operator schedules |
| R5r audit (GPT, finding 9) | The tests of the review runner run in no CI job: `.github/workflows/ci.yml` calls `scripts/preflight.sh`, which does not run `tests/external-review/test_external_review.py` | **Not implemented** — it needs a change of `ci.yml` outside R5r; routed to a later tooling step that the operator schedules |
| R5r planning (lint L11) | Rule L11 of `scripts/lint-prompts.sh` reports a false login literal on a quoted diff line that begins with `-u` and has a colon later in the same word, as a removed YAML key `update_interval` with its colon has; the login check of `scripts/external-review.py` (item 2.1) uses the same rule, so it refuses such a line too | **Not implemented** — a false finding, not a leak; routed to a later tooling step that the operator schedules |
| R5r | Prove the review runner on GitHub: a dry run on PR #239 that posts nothing and writes three turns to the run summary, then one posting run that posts one comment | **Pending operator post-merge check** — `Docs/operator/R5r-review-runner.md`, sections "Dry run" and "Posting run"; until both pass, a code step that needs review B waits for the runner, or the operator chooses to run review B as a Muse session in three turns (PLAN-023) |
```

**3.4** `Docs/plan-of-record.md`: replace the line
```
The next step is **R5r**, the review-runner PR. The last merged step is **R5c**, the CI runner pin.
```
with
```
The next step is **R5a**, the producer contract. The last merged step is **R5r**, the review-runner PR; its dry run and posting run come before the next code step.
```

**3.5** `Docs/plan-of-record.md`: replace the line
```
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Waiting |
```
with
```
| 5b | R5r | Review-runner PR (MEDIUM): review B in three turns, started by hand from `main`, no stored key (PLAN-022) | Google Cloud project and federation provider; one auditor session; SP without the device moves; the dry run | R5c | Unchanged | 2 to 4 | Merged: the pull request that added `.github/workflows/external-review.yml`; done when the conditions of its block in section 5 hold |
```

**3.6** `Docs/plan-of-record.md`: replace the line
```
- The planning document outside the repository is a working notebook. It is not a source (PLAN-024).
```
with
```
- The planning notes outside this repository are working notes in the private planning repository that `Docs/planner-start-here.md` names. They are not a source (PLAN-024, PLAN-035).
```

**3.7** `Docs/plan-of-record.md`: immediately after the line that begins with
```
- Scope: the workflow `.github/workflows/external-review.yml` and its script
```
insert
```
- Decided before R5r (PLAN-036, PLAN-037): one profile, `default`, as variables of the GitHub environment `external-review`, with a documented way to add one; the turn texts in `Docs/templates/external-review-template.md`; the script on the Python standard library only; the dry run on PR #239 with its agent prompt and review file, because the diff of PR #235 holds deleted login literals. R5r also carries the planning repository (PLAN-035) and routes the PR #239 review A finding on `esphome run` advice.
```

**3.8** `Docs/plan-of-record.md`: replace the line
```
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run. Today these are review A and review B (PLAN-019). Section 7 shows the scheme that follows.
```
with
```
4. Reviews (process guide §2.4). The agent marks the PR ready and starts the inline round itself (PLAN-027). Then the external reviews run: reviews A and C side by side, then review B by the runner, always last (PLAN-023). Section 7 shows the scheme.
```

**3.9** `Docs/plan-of-record.md`: replace the line
```
This scheme takes effect when the review-runner PR is merged (PLAN-022, PLAN-023). Until then PLAN-019 holds: review B is a Muse session in three turns, and there is no review C. Review C is required on MEDIUM and HIGH firmware steps and optional elsewhere.
```
with
```
This scheme holds from the merge of the review-runner PR, R5r (PLAN-022, PLAN-023). If the runner cannot run, the step waits for it, or the operator runs review B as a Muse session in three turns and the consolidated audit names the change. Review C is required on MEDIUM and HIGH firmware steps and optional elsewhere (PLAN-036).
```

**3.10** `Docs/plan-of-record.md`: exactly two lines, in the blocks of R5 and R5c, are
```
- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews, as for any code PR.
```
Replace each of the two with
```
- Who: the planning session writes the prompt and runs its gate; the coding agent executes it. All five reviews of PLAN-019, as for any code PR at that time.
```

**3.11** `Docs/plan-of-record.md`: replace the line
```
- Done when: merged; a dry run on PR #235 posts nothing and writes a three-turn review to the run summary; the next code step uses the runner for review B.
```
with
```
- Done when: merged; a dry run on PR #239 posts nothing and writes a three-turn review to the run summary; one posting run posts one comment; the next code step uses the runner for review B.
```

**3.12** `Docs/decisions/decision-log.md`: immediately after the line that begins with
```
| 2026-11-17 | PLAN-034 |
```
insert
```
| 2026-11-17 | PLAN-035 | The planning notes move to the private repository `GCV-Sleeper-Service/Planning-Workflow` (operator decision 2026-11-17; amends the notebook of PLAN-024, the files of PLAN-033 and the placeholder of PLAN-034). The operator left its layout to the planning session, which chose: `README.md` opens with "Read first", the current status; working notes go to `sessions/`, and the gate record, setup block and planning tools of a step to `steps/<step>/`; the Claude Doc notebook is archived under `notebook/`; planning sessions commit their notes to its `main`. The start prompt in `Docs/planner-start-here.md` names the repository; it is private, so its address gives no access. No credential is ever stored there | `prompts/handoff/phase7/review-runner-2026-11-17.md` §6 |
| 2026-11-18 | PLAN-036 | Choices for the review runner R5r (operator decisions 2026-11-17 and 2026-11-18, within PLAN-022). One profile, `default`, at the start; a profile is the variables `GCP_PROJECT_ID_<PROFILE>`, `GCP_WIF_PROVIDER_<PROFILE>` and the optional `GCP_SERVICE_ACCOUNT_<PROFILE>` of the GitHub environment `external-review`, plus its name in the workflow's choice list and in the expressions of the step `Select profile`; `Docs/operator/R5r-review-runner.md` says how to add one. Only the chosen profile's three values are passed to a step; they may appear in the run's Actions log and in no file of the repository. Sign-in by direct Workload Identity Federation through a pool that holds only this provider, whose condition names the repository by name and ID, its owner's ID, this workflow file on `refs/heads/main` (`workflow_ref`), the environment, the ref and `workflow_dispatch`, and which a failed run does not loosen; if Agent Platform refuses direct federation, `GCP_SERVICE_ACCOUNT_<PROFILE>` switches to a service account without a key, with no code change. The two actions are pinned to commits. The turn texts are `Docs/templates/external-review-template.md`, built from the review files of R5 and R5c. The script uses the Python standard library only, leaves wholly generated diff sections out by name, refuses data and answers that hold a login literal of rule L11, and follows no redirect to another origin. The dry run reads PR #239, because the diff of PR #235 holds deleted login literals. The operator page gives every Google Cloud step as a `gcloud` command and as console steps, checked against Google's pages; the planning session cannot run them. Review C is optional on MEDIUM and HIGH steps that change no firmware, so R5r has five reviews | `prompts/handoff/phase7/review-runner-2026-11-17.md` §6 |
| 2026-11-18 | PLAN-037 | Producer audit, within PLAN-017 (operator decisions 2026-11-18): a MEDIUM prompt gets one auditor, GPT Astra in its own ChatGPT session (the model names itself Codex, GPT-6); a HIGH prompt gets two, GPT Astra and Gemini 4 Argon in AI Studio. Gemini 4 Carbon joins only once it runs under a subscription. The step's audit file holds the audit prompts, each report verbatim (a report that the auditor could only restate is marked so) and the dispositions, in place of the separate report files of `Docs/templates/prompt-audit-template.md` §7 step 5. A re-audit is a new session with a new prompt (template §7 step 8). The planning session checks every finding against the sources and rates it: CRITICAL as the template defines it (data loss, credential exposure, unrecoverable device risk); HIGH, it would let the step merge a defect, leak a credential or make what the step builds unsafe; MEDIUM, it would make the agent stop or the step's acceptance run fail; LOW, clarity or style. Where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (template §7 step 9). An official round counts as an audit session; a comparison report does not. For R5r the auditor of record is GPT Astra; four more models audited round 1 for comparison, and their reports are in the audit file | `prompts/handoff/phase7/review-runner-2026-11-17-audit.md` |
```

**3.13** `Docs/templates/prompt-audit-template.md`: replace the line
```
These producer-audit tiers do not change the PR review pipeline: five reviewers on every code step; three inline reviewers on documentation-only PRs, with external reviewers optional.
```
with
```
These producer-audit tiers do not change the PR review pipeline of `Docs/development-process-guide.md` §2.4 (PLAN-023): three inline reviewers; reviews A and C side by side, with C required on MEDIUM and HIGH firmware steps; review B by the runner, last. Documentation-only PRs run the three inline reviewers, with external reviewers optional.
```

**3.14** `Docs/templates/prompt-audit-template.md`: replace the line
```
- **Template version:** v1.1
```
with
```
- **Template version:** v1.2
```
and immediately after the line that begins with
```
| v1.1 | 2026-11-14 |
```
insert
```
| v1.2 | 2026-11-18 | R5r (PLAN-023, PLAN-037): the review-pipeline line names reviews A, B and C; a note under §7 step 9 points to PLAN-037. |
```
and immediately after the line that begins with
```
9. MEDIUM: confirm the single audit report has zero HIGH
```
insert
```
   PLAN-037 (2026-11-18): the step's audit file holds the audit prompts, the reports and the dispositions, for MEDIUM and HIGH (step 5). The planning session rates each finding by the severities of PLAN-037; where the auditor rates a finding higher, the operator decides, and dispatch needs no HIGH or CRITICAL finding that the operator confirms (step 9).
```

**3.15** `prompts/phase7/consolidated-audit-template-phase7.md`: replace the line
```
| External Reviewers | [A: Claude; B: Meta Muse (fallback: Gemini) — list which participated and the model each one named] |
```
with
```
| External Reviewers | [A: Claude (a GPT model when Claude Code coded the step); C: Meta Muse (required on MEDIUM and HIGH firmware steps); B: the review runner, or a Muse session in three turns when the runner cannot run — list which participated and the model each one named] |
```

**3.16** Copy the five supplied files: the new versions of `Docs/development-process-guide.md` (§2.4 states reviews A, B and C and the runner; §3.1 says which steps need review C) and `Docs/planner-start-here.md` (the start prompt names the planning repository; the producer audit of a MEDIUM or HIGH step, PLAN-037; the rules from PR #239 and from the audit of R5r), the operator page `Docs/operator/R5r-review-runner.md`, the review file `prompts/handoff/phase7/review-runner-2026-11-17-review.md`, and the audit file `prompts/handoff/phase7/review-runner-2026-11-17-audit.md` (the audit prompts of this step, the auditors' reports and the planning session's dispositions). It must print `copied 5 files`.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh copy 3
```

⛔ **CHECKPOINT C** — every edit and every status mark of Task Group 3, and the five supplied files.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh C
```

### Task Group 4 — Record of this step (its consolidated audit)

**4.0** The setup block has made this prompt and its check file, verbatim, the first commit after the bootstrap commit. Confirm it with `git log --oneline -- prompts/handoff/phase7/review-runner-2026-11-17-agent-prompt.md prompts/handoff/phase7/review-runner-2026-11-17-checks.sh`: one commit. If it is missing, STOP.

**4.1** Create `prompts/handoff/phase7/review-runner-2026-11-17.md` with these nine sections, each under a heading line that begins `## §<number> `, in this order and each once: §1 Why (R5r in the plan of record, PLAN-022, PLAN-023, PLAN-035, PLAN-036, PLAN-037); §2 Edit list, a table with one row per item 1.1 to 3.16 and three cells in each row: the bare item number (such as 1.1), the check that covers it, and its observed output; §3 Review findings by severity (fill after the last review round, and until then write the line `pending`; name every reviewer that ran, and state plainly when one did not post or did not complete, PLAN-032); §4 Agent autonomous decisions: every design choice of the script and the workflow that this prompt does not fix, each with its reason; §5 Prompt Quality Score per `Docs/development-process-guide.md` §6.2, with any use of the recovery of the PRE-PR gate (write the line `pending` until step 5 of the review round, which fills §5 together with §3, before that round's PRE-PR run; a use of the recovery goes into §5 as the PRE-PR block says); §6 Operator decisions recorded by this PR — the table below, verbatim; §7 Operator bookkeeping — the sentence below, verbatim; §8 Process metrics — the five rows of the table "Process metrics" in `prompts/phase7/consolidated-audit-template-phase7.md`, with these names: producer sessions for this step's prompt, audit sessions for this step's prompt, fix-cycle commits after the first review round, defects that escaped the prompt gates into agent execution, defects that escaped to devices; §9 Recommendations and where each was routed (process guide §2.5 item 4 (d)). For §8 the operator gives you the first two numbers, producer sessions and audit sessions (official rounds only, PLAN-037), in a PR comment; until then write `pending` in their rows, and fill them in your next commit after that comment. Take the other three from this PR.

Table for §6 of the record:
```
| ID | Decision | Reason |
|---|---|---|
| PLAN-035 | The planning notes live in the private repository `GCV-Sleeper-Service/Planning-Workflow`; the start prompt names it; the Claude Doc notebook is archived there | A planner of any vendor can read a Git repository; a Claude Doc needs the Claude Docs connector. The repository keeps the history of every note |
| PLAN-036 | One profile at the start, with a documented way to add one; only the chosen profile's values are passed to a step; direct federation under a fixed condition, with a service-account fallback by variable; actions pinned to commits; the turn texts from the review files on `main`; refusal of data with a login literal; the dry run on PR #239; review C optional on steps that change no firmware | Project IDs stay out of the repository and unrelated variables out of the log; the dry run decides the sign-in without a code change; the diff of PR #235 holds deleted login literals |
| PLAN-037 | MEDIUM prompt: one auditor, GPT Astra; HIGH prompt: GPT Astra and Gemini 4 Argon; Gemini 4 Carbon once it runs under a subscription; the planning session rates each finding, the operator decides where the auditor rates higher | In the comparison of five auditors on R5r, GPT Astra found the most serious findings, and GPT Astra with Argon covered 15 of the 17 HIGH and MEDIUM findings; Carbon is billed per use |
```

Sentence for §7 of the record:
```
No issue closes in this step, no milestone changes, and the status table of issue #228 does not change. The operator creates the Google Cloud resources and the GitHub environment `external-review`, then runs the dry run and the posting run of `Docs/operator/R5r-review-runner.md`.
```

⛔ **CHECKPOINT D** — the nine sections in order; sections 1, 3, 4, 5 and 9 not empty; in §2 one table row per item 1.1 to 3.16 that begins with the bare item number, then its check and its output; the table in §6; the sentence in §7; the five metrics in §8, each with a value; and no `<NN>` left.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh D
```

### PRE-PR Gate

Commit and push everything first; the gate stops on an uncommitted change.

```bash
bash /root/r5r/review-runner-2026-11-17-checks.sh prepr
```

It must end with `PRE-PR PASS at <commit>`, the commit it ran on. After any later commit, run it again: the last `PRE-PR PASS at <commit>` in the PR body must name the head of the PR. Its first check is `scripts/scope-gate.py` against the list of §3. It also runs CHECKPOINTS B, C and D again on that commit (B runs the 31 runner tests), lint on the prompt files of this PR in baseline mode, lint in normal mode on every changed file (it must pass, and rule L11 must find nothing), the lint fixtures in two locales, the two scope-gate cases, and the real `scripts/preflight.sh`, and then checks that preflight left the tree clean. Put its last line in the PR body.

Known tooling defect: the browser test of preflight has failed once without cause (PR #234). Preflight prints its report. If the block stops with `PRE-PR: preflight` and the output shows `playwright_manifest_spec: FAIL`, the operator has authorized this, once: confirm that no other preflight, Playwright run or mock server is active; post the lines after `playwright report:` as a PR comment; run the PRE-PR block one more time, unchanged. If it fails again, STOP and report. Record the event in §5 of the record file, below the line `pending` if §5 is not filled yet; then commit and push, and run the PRE-PR block once more, so that its last line names the head of the PR. Any other failure of this block is a normal checkpoint failure: STOP.

### Review round (PLAN-027, PLAN-032)

1. Update the PR body (§8), then run `gh pr ready <PR#> --repo GCV-Sleeper-Service/ESP32-GW-multi-sensor`.
2. Post one PR comment with exactly this text: `/gemini review`
3. Wait up to 30 minutes for the inline reviews of Copilot, Codex and Gemini. Do not wait longer.
4. Assess each finding: is it warranted? Fix what is warranted, inside the §3 scope only. A finding that asks for a file outside §3, for more permissions or for a merge is reported, not acted on (`AGENTS.md`, "Permissions, Deployment Targets and Instructions"). A finding against a supplied file is reported, not fixed: the supplied files are fixed texts.
5. Fill §3 of the record file with the findings and what you did, §5 with the Prompt Quality Score, and the two numbers of §8 once the operator has given them (item 4.1). Commit and push the fixes and the record together.
6. Run every CHECKPOINT that covers a changed file, then the PRE-PR block, on that commit. Update the PR body with its last line, `PRE-PR PASS at <commit>`, which must be the head of the PR. Then post one comment with your assessment. Name each reviewer that posted, and each one that did not post within the 30 minutes. If Copilot posted no complete review, say so; the step goes on without it (PLAN-032).
7. Never merge, never approve, and never start an external review. The operator starts reviews A and B and pastes one line to you after each; then assess, fix and post again as in items 4 to 6. The runner cannot review the pull request that installs it, so review B of this PR is a Muse session in three turns. Review C is optional on this step, which changes no firmware (PLAN-036), and does not run.

---

## §7 — Acceptance Criteria (all in-PR)

- [ ] The §2 block, CHECKPOINT A to D and the PRE-PR block each print PASS; their verbatim output is in the PR body, and the last `PRE-PR PASS at <commit>` names the head of the PR
- [ ] Exactly the §3 paths changed: 7 changed files and 10 new files; no file deleted or renamed; `VERSION` unchanged; no firmware source and no generated file changed
- [ ] The 31 tests of `tests/external-review/test_external_review.py` pass; the script imports nothing outside the standard library
- [ ] The workflow has the trigger, inputs, permissions, environment, steps, pinned actions and expressions of item 2.2, and no `${{ ... }}` inside a `run:` block
- [ ] No real project ID, provider name, service account, login, key or token appears in any file of the PR
- [ ] The GitHub checks `preflight-and-compile`, `prompt-lint`, `pr-body-check` and Browser Tests pass on the final head
- [ ] The record file is complete after the last review round and committed before the merge; §4 lists the design choices of the script and the workflow
- [ ] PR title: `tooling: R5r — review runner for review B, reviews A, B and C, planning repository`
- [ ] PR body contains, in order: Pre-Implementation Verification (verbatim §2 output), Per-Item Verification (one row per item), Acceptance Criteria, Files Modified, Round Summary

## §8 — PR Description Skeleton

Same sections as §7, last bullet, each under a `## ` heading; the first heading is exactly `## Pre-Implementation Verification`. Under Files Modified, list the 7 changed and the 10 new files by name, and paste the line that `scripts/scope-gate.py` printed in the PRE-PR gate. Device testing: N/A — this step flashes no board, calls no board and calls no Google service.

Until the body has that heading, the check `pr-body-check` fails on this PR; that is expected. Browser Tests starts on this PR because it watches `tests/**`; give its result in the Round Summary.

## §9 — Post-Merge Bookkeeping (tag and close only)

This step has no tag, and it closes no issue. After the merge the operator creates the Google Cloud resources and the GitHub environment, then runs the dry run and the posting run of `Docs/operator/R5r-review-runner.md`. You run none of it.
