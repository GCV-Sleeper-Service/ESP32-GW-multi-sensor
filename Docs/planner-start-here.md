# Planner, start here

_The entry page for a planning or prompt-producing session. Written 2026-11-16 for the step R3c (PLAN-024, PLAN-030)._
_A coding agent does not start here. It starts at `AGENTS.md`._

## Who this page is for

Any planning or prompt-producing session, of any vendor and any account, on the three conditions of PLAN-030:

1. The session has its own clone of this repository and a shell. A chat without a shell can plan, but it cannot run a gate.
2. The session keeps the rules below.
3. The session does not run on the build host. The checkout of the coding agent, the boards and the secrets are there.

## Rules

- Never push to this repository, and never open a pull request in it. Your files reach the repository through a pull request of the coding agent.
- Never touch the boards. The operator runs every device command and pastes the output.
- Never write a credential, in a file, a command or a chat. The login stays in the operator's shell as `$ESP_USER` and `$ESP_PASS` (SEC-003).
- One session, one role: planner, prompt producer, coding agent or reviewer (HowTo §2.2).
- Sources win over memory. Every value in a prompt comes from a live command or from `CURRENT-STATE.md`. If you cannot run commands, write `<LIVE>` where an expected value belongs; the pre-dispatch gate fills it.
- Confirm what is happening with one command before you explain why.

## Read in this order

1. `CURRENT-STATE.md`: what is true now.
2. `Docs/plan-of-record.md`: which step is next, and its scope.
3. `Docs/decisions/decision-log.md`: what was decided.
4. `Docs/development-process-guide.md`: how a step runs. Its top names the method of record, the HowTo at a pinned tag.
5. Then only what the task needs.

When sources disagree, this order decides (HowTo §2.5): live code on `main`; measurements tied to a named build; `CURRENT-STATE.md`; the decision log; the plan of record; the prompt and the handoff of the step; the changelog; archived documents; anyone's memory, the model's included. `Docs/archive/` is evidence, not instruction.

## The restart check

Run it at the start of every session (HowTo §3.5). Clone once:

```bash
git clone https://github.com/GCV-Sleeper-Service/ESP32-GW-multi-sensor
git clone --branch v2.3.1 --depth 1 https://github.com/GCV-Sleeper-Service/HowTo-LLM-Assisted-Workflow-v2
```

Then, in the clone of this repository:

```bash
git fetch origin
git rev-parse --short origin/main
git log --oneline -5 origin/main
git show origin/main:VERSION
git show origin/main:CURRENT-STATE.md | sed -n '3,4p'
git -C ../HowTo-LLM-Assisted-Workflow-v2 rev-parse --short 'v2.3.1^{commit}'
```

Give `git rev-parse` one revision in each call. Fill this table and show it to the operator before any other work:

| Check | Result | Evidence |
|---|---|---|
| `main` | The commit, and what is new since the last session | The commands above |
| Open pull requests and issues | Numbers and titles | GitHub, read today |
| HowTo pin | The tag still names the commit in the process guide | The last command above |
| State file | `Last verified` and `Next action` | `CURRENT-STATE.md`, lines 3 and 4 |
| Plan of record | "You are here" agrees with `main` | `Docs/plan-of-record.md`, section 2 |
| Environment | The operator's news from the build host and the boards, or "none" | The operator's message |
| Disagreements | Each one, and which source is wrong | The order above |

A disagreement is recorded before you act on it. Something that a conversation called done, and that is not on `main` or on the tracker, is not done.

## How a step is produced

1. Read the block of the step in the plan of record. If the order or the scope must change, write the decision row first (HowTo §3.4).
2. Write the agent prompt, in the form of the last merged prompt in `prompts/handoff/phase7/`. Every edit is anchored by quoted text, never by a line number.
3. Write the files that go with it: the operator page for `Docs/operator/`, the setup block (process guide §2.2), and for a code step the review file.
4. Run the pre-dispatch gate (process guide §2.1 item 6) on the day of dispatch.
5. Rehearse the whole pull request on a fresh worktree of `origin/main`: apply every edit as written, run every checkpoint, run the real `scripts/lint-prompts.sh` and the real `scripts/preflight.sh`. Add negative tests: each gate must stop when its condition is broken.
6. Hand over: the prompt, the operator page, the setup block, and the gate record with the expected SHA-256 of every file that has a fixed text.
7. After the merge, close the step: read the merged pull request and its audit, and correct the next prompt at its gate.

## Rules that came from review findings (PR #234, PR #235)

- Run every command that you give the operator yourself first, exactly as written.
- No secret in a command argument. A check that needs a secret reads it from the environment inside one process.
- A check stops when its precondition fails.
- A statement of scope names the files it covers.
- A status mark that the pull request changes is searched for in the whole file, not only on the edited line.
- A rule that changes is changed in every place that states it.
- A prompt that changes a file an agent loads (`AGENTS.md`, `CLAUDE.md`, the Copilot files) says so in the review file, because Copilot reads these files from the head branch of the pull request.

## Where a planning session can run

Checked on 2026-11-16 against the vendors' documentation. Check again before you rely on a row.

| Where | Clone and shell | As a planner |
|---|---|---|
| Claude Code, cloud session, on the operator's subscription | Yes | The normal way |
| Claude Code on a machine that is not the build host, through Google's Agent Platform (Vertex AI), Amazon Bedrock or Microsoft Foundry | Yes | Overflow, metered; measure one session in the billing report first |
| GitHub Copilot agent in VS Code, or the Copilot CLI, with a Claude model, on a machine that is not the build host | Yes | Overflow |
| Any agent on the build host | Yes | No: condition 3 |
| GitHub Copilot in the cloud (the cloud agent) | Yes | No: it works through a branch and a pull request in this repository |
| A chat on the web without a shell | No | It can plan; it cannot gate |

Each gate record names the model, the provider and the tool that produced the prompt.

## Working notes

Keep working notes outside the repository, in any notebook. They are not a source. What the next session needs goes into the repository through the pull request of a step: the plan of record, the decision log, `CURRENT-STATE.md`.
