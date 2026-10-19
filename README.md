# Baton

**Waypoint and Logbook for coding agents.** A `.baton/` folder in the project (`AGENT.md` protocol, `STATE.md`, `log/YYYY-MM.md`), passed from one agent session to the next like a relay baton. Open a session, say "hi", and the agent shows where the work stands and a menu of next tasks.

- **Waypoint**: where the work is: focus, decisions, open issues, who is working on what, what is next. Only state; what the project is stays in the README.
- **Logbook**: what each session did, how it was checked and what it left unfinished.

Each new session starts without memory. Baton is the shortest path to "I know what this project is, where it stands, and what not to touch".

- Spec: [SPEC.md](SPEC.md) · protocol the agent reads: [AGENT.md](AGENT.md)
- Real example: [Midinja's `.baton/`](https://github.com/bfunc/midinja/tree/main/.baton)

## Setup

Baton is agent-neutral: the protocol is plain Markdown, the hooks in `hooks/` read the common hook input (`cwd`, `session_id`, `tool_input`, …), and everything agent-specific sits in `agents/<agent>/`: an `agent.conf` (which project files point to the protocol, how the start brief is handed over, where the hooks go) and an `install.sh`. Supported now: `claude` (Claude Code) and `copilot`: one hooks file in `~/.copilot/hooks/` serves both Copilot CLI and the Copilot chat in the VS Code sidebar (Agent mode; VS Code hooks are a preview feature, on by default via `chat.useHooks`). If you turn on `chat.useClaudeHooks` in VS Code, it also runs the Claude hooks: install only one of the two for VS Code then.

Needs bash (Git Bash on Windows), git and python 3; `gh` is optional (PRs and CI in the start brief).

**On each machine**, once per agent:
```sh
git clone https://github.com/bfunc/baton
bash baton/agents/claude/install.sh <machine-name>
bash baton/agents/copilot/install.sh <machine-name>
```
Each installer checks the tools, writes the machine name to `~/.baton/machine` (agents sign as `<model>@<machine>#<session>`), installs that agent's hooks (Claude: merged into `~/.claude/settings.json`, backup `settings.json.bak`; Copilot: `~/.copilot/hooks/baton.json`), and runs `selftest.sh <agent>`: a throwaway repo, `init.sh`, then every hook called the way that agent calls it (start brief format, append-only log for both agents' edit fields, stop guard). Anything wrong ends with `ERROR:` and exit 1.

The Copilot installer also runs the exact hook commands through cmd and PowerShell on Windows, and warns when VS Code has hooks switched off. The VS Code chat has no CLI, so its last check is by hand: the installer prints the question to ask in a new chat.

Options: `--project DIR` also runs `init.sh` there; `--live` starts a real non-interactive session of the agent's CLI and checks that the start brief reached it; `--uninstall` removes the hooks. Re-run after moving the folder. If `gh` is not on PATH, put its path in `~/.baton/gh`. Update: `git pull` in the clone; projects get offered the newer `AGENT.md` at session start.

**In each project:**
```sh
bash <path-to>/baton/init.sh <project-dir> [agent ...]     # e.g. init.sh . claude copilot
```
It creates `.baton/` (the `AGENT.md` copy, `STATE.md`, this month's log), adds "Before any work, read and follow .baton/AGENT.md." to `AGENTS.md`, and the lines each named agent needs (`CLAUDE.md`: `@.baton/AGENT.md`; `.github/copilot-instructions.md`). It never overwrites. Then open a session and say hi: the agent fills `STATE.md` from git history and marks guesses `(?)`. Commit `.baton/` with the project: it is how the next session, on any machine, picks up the work.

**Another agent:** add `agents/<name>/agent.conf` and `install.sh` (copy the closest one), then `bash selftest.sh <name>`.

## Hooks

Without hooks the agent follows AGENT.md by itself. With them the facts are gathered and the rules enforced by code. One copy per machine, not per project; every script stays silent where there is no `.baton/STATE.md`.

| Event | Script | Does |
|---|---|---|
| Session start | `hooks/brief.sh` (`--json` for agents that take `{"additionalContext": …}`) | git fetch, ahead/behind, STATE vs HEAD, stale claims, `(?)`, waiting for you, "not tested", size, secret and injection scan, protocol version, PRs and CI → into the agent's context. After compaction it re-injects STATE |
| Stop | `hooks/stop-guard.sh` | work changed but `log/` didn't → stops the agent once and asks for a log entry |
| Before a tool | `hooks/log-append-only.sh` | rejects any change to `.baton/log/*.md` that is not an append (write, edit or patch); lets everything else through, also when it can't read the input |

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

v0.8: `.baton/` folder, per-agent installers with a self-test (Claude Code, GitHub Copilot), start checks, briefing with menu, playbooks, multi-repo hub, Claude Code hooks. First real use: Midinja. Ideas for later: a Claude Code plugin instead of manual hook setup; a local history index over session transcripts (SQLite FTS5) to bootstrap Decisions; big decisions as ADR files linked from STATE.

## Licence

MIT, see [LICENSE](LICENSE).
