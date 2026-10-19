# Baton

**Waypoint and Logbook for coding agents.** A `.baton/` folder in the project (`AGENT.md` protocol, `STATE.md`, `log/YYYY-MM.md`), passed from one agent session to the next like a relay baton. Open a session, say "hi", and the agent shows where the work stands and a menu of next tasks.

- **Waypoint**: where the work is: focus, decisions, open issues, who is working on what, what is next. Only state; what the project is stays in the README.
- **Logbook**: what each session did, how it was checked and what it left unfinished.

Each new session starts without memory. Baton is the shortest path to "I know what this project is, where it stands, and what not to touch".

- Spec: [SPEC.md](SPEC.md) · protocol the agent reads: [AGENT.md](AGENT.md)
- Real example: [Midinja's `.baton/`](https://github.com/bfunc/midinja/tree/main/.baton)

## Setup

Needs bash (Git Bash on Windows), git and python 3; `gh` is optional (PRs and CI in the start brief).

**On each machine**, once:
```sh
git clone https://github.com/bfunc/baton
bash baton/install.sh <machine-name>
```
`install.sh` writes the machine name to `~/.baton/machine` (agents sign log entries as `<model>@<machine>#<session>`) and adds the hooks to `~/.claude/settings.json` (backup in `settings.json.bak`; other hooks and settings are kept). Re-run it after moving the folder; `bash install.sh --uninstall` removes the hooks. If `gh` is not on PATH, put its path in `~/.baton/gh`. Start a new Claude Code session for the hooks to load. Update: `git pull` in the clone; projects get offered the newer `AGENT.md` at session start.

**In each project:**
```sh
bash <path-to>/baton/init.sh <project-dir> [project-name]
```
It creates `.baton/` (the `AGENT.md` copy, `STATE.md`, this month's log) and adds `@.baton/AGENT.md` to the project's `CLAUDE.md`; it never overwrites an existing `.baton/`. Then open a session in the project and say hi: the agent fills `STATE.md` from git history and marks guesses `(?)`. For other agents add "Before any work, read and follow .baton/AGENT.md." to `AGENTS.md`. Without the scripts: copy [template/.baton/](template/.baton/) and [AGENT.md](AGENT.md) into `.baton/` by hand.

Commit `.baton/` with the project: it is how the next session, on any machine, picks up the work.

## Hooks (Claude Code)

Without hooks the agent follows AGENT.md by itself. With them the facts are gathered and the rules enforced by code. One copy per machine, not per project; every script exits silently where there is no `.baton/`.

| Hook | Script | Does |
|---|---|---|
| SessionStart | `hooks/brief.sh` | git fetch, ahead/behind, STATE vs HEAD, stale claims, `(?)`, waiting for you, "not tested", size, secret and injection scan, protocol version, PRs and CI → into the agent's context. After compaction it re-injects STATE |
| Stop | `hooks/stop-guard.sh` | work changed but `log/` didn't → stops the agent once and asks for a log entry |
| PreToolUse `Edit\|Write\|MultiEdit` | `hooks/log-append-only.sh` | rejects any change to `.baton/log/*.md` that is not an append |

## Where the ideas come from

Only parts that are used in practice and reported to work:

| Taken | From | Why |
|---|---|---|
| Plain Markdown, no required syntax, root file | [AGENTS.md](https://agents.md) (Linux Foundation standard, read by most coding agents) | Zero friction; any agent and any human can read it |
| Static "how to work" stays in AGENTS.md; Baton holds the state | AGENTS.md practice: keep the root file short, no duplication | Avoids two files saying the same thing and drifting |
| Progress log read at start, written at end; also read `git log` | Anthropic, [Effective harnesses for long-running agents](https://anthropic.com/engineering/effective-harnesses-for-long-running-agents) (`claude-progress.txt`) | Fixes "every session starts with no memory" |
| "Done" only after real testing (`Checked:`) | Same Anthropic post: agents marked features done without end-to-end checks | The most common failure mode |
| Decision Log with reason and date; Surprises | OpenAI [ExecPlans / PLANS.md](https://developers.openai.com/cookbook/articles/codex_exec_plans) | The next agent knows *why*, and doesn't repeat dead ends |
| Small current-state doc, not a running log; size limits | Cline [Memory Bank](https://docs.cline.bot/features/memory-bank) (`activeContext.md`, `progress.md`) | Every line is read into context every session |
| Self-enabling import line; state at workspace level for multi-repo work; one real reference instead of invented examples; "accepted, don't fix"; not done until documented | A private agent-driven orchestration repo (workspace `CLAUDE.md` that imports the contract) | Zero setup per session; proven in daily use |
| Context gathered by code at session start; injection scan of context files; hard size limit | [Hermes Agent](https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files) (Nous Research) | Facts don't depend on how careful the model is |
| Snapshot + append-only log + next steps | Community handoff formats (wecansync `.ai/HANDOFF + LOG`, ctxio, OpenHandoff) | The shape they all converged on |

Deliberately left out:
- **Many files** (Memory Bank has 6, `.ai/` has 5+). Three items: protocol, state, monthly logs.
- **JSON / schemas** (GovZero, OpenHandoff `context.json`). Anthropic found JSON harder for a model to overwrite by mistake, so it is worth it for a strict feature checklist, but for context and logs Markdown is read and written better. The append-only rule covers the overwrite risk.
- **Full plan sections** (ExecPlan has 13). Plans belong in a separate doc when needed; Baton only links them.

## Status

v0.8: `.baton/` folder, install and init scripts, start checks, briefing with menu, playbooks, multi-repo hub, Claude Code hooks. First real use: Midinja. Ideas for later: a Claude Code plugin instead of manual hook setup; a local history index over session transcripts (SQLite FTS5) to bootstrap Decisions; big decisions as ADR files linked from STATE.

## Licence

MIT, see [LICENSE](LICENSE).
