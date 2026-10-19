# Baton spec v0.8

Baton is the **state** of the work on a project, kept in a `.baton/` folder and passed from one agent session to the next. README says *what the project is*, `AGENTS.md` / `CLAUDE.md` say *how to work*, `.baton/` says *where the work is*.

```
.baton/
  AGENT.md        the protocol: reading it makes an agent a Baton agent (a versioned copy)
  STATE.md        Waypoint: Now, Decisions, Open issues, Waiting for you, In progress, Next
  log/YYYY-MM.md  Logbook: one entry per milestone, append-only, one file per month
```
Three items, no more. Monthly log files replace archiving and keep parallel agents from editing the same file.

## Enabling
Agents don't open hidden folders on their own (search tools skip them), so add one line to the project's agent file:
- `CLAUDE.md`: `@.baton/AGENT.md`
- `AGENTS.md`: `Before any work, read and follow .baton/AGENT.md.`

## Where `.baton/` lives
| Project shape | `.baton/` |
|---|---|
| One repo | repo root |
| Monorepo, many subprojects | root, with a status table of the subprojects in Now. A subproject gets its own `.baton/` only when it has steady work of its own. At most two levels |
| Several repos worked on together | only in the hub repo (orchestration / hub), which also holds the workspace `CLAUDE.md` and shared docs. No hub: propose one, wait for a yes. Never a Baton-only repo: nobody opens it and it has no code to compare with. The other repos' agent files point to it; if the path is missing, work without a Baton, never start a second one |

## Session
1. **Start:** find the nearest `.baton/` → cheap checks (fetch, STATE vs `git log`, stale claims, old `(?)`, size, secrets, protocol version) → external sources listed in `Sources:` → brief the user → claim.
2. **Briefing:** one line if the user came with a task; otherwise a start screen of ~12 lines (state, `!!`, in progress, unverified, waiting for you, next) and a numbered menu: feature, bug, verify, next item, release, cleanup.
3. **Playbooks** for each menu item, short, in `AGENT.md`; a project's `CLAUDE.md` may override them.
4. **During:** decisions, open issues and questions go to STATE as they come; a log entry at each milestone.
5. **End** (also on "handoff"): log entry, STATE updated, claim removed, `.baton/` committed with the work (multi-repo: child repo first, then the hub).

Full wording: [AGENT.md](AGENT.md). Files to copy: [template/.baton/](template/.baton/).

## Hooks (optional, Claude Code)
One copy per machine in user settings, not per project: `brief.sh` (SessionStart: gathers the facts, re-injects STATE after compaction), `stop-guard.sh` (Stop: work changed without a log entry → stop once), `log-append-only.sh` (PreToolUse: logs only grow). Without hooks the protocol still works. Setup: `install.sh`, see [README](README.md#setup).

## Rules
1. **State only.** Link, never copy.
2. **Short STATE**, at most ~60 lines.
3. **Decisions carry a topic and a reason** (`date · Topic: decision · why`) and stop the next agent from "fixing" what was done on purpose. Only what the user said or confirmed: a rule the agent inferred waits under Waiting for you as a proposed decision. A correction replaces the line with the same topic instead of adding a second one.
4. **Append-only logs, and short.** At most 5 lines per entry; detail in the commit. Only project work (Baton's own changes go to its CHANGELOG). The log is history, not storage: at the end of a session every `Left:` / `Surprise:` that matters moves to STATE. A verification starts with `Verifies: <heading>` and takes that entry off the Unverified list. A new month closes the previous file with a 3–5 line `## Summary`.
5. **Only verified claims.** `Checked: not tested` puts an entry on the Unverified list until someone verifies it.
6. **Write what git doesn't know.**
7. **No secrets or personal data.** Name a secret, never its value.
8. **Several agents:** claim first; don't take an item someone else holds. `Updated:` holds one hash per covered repo.

## Distribution
`AGENT.md` is copied into each project with a version line; the start check offers an update when the source is newer. No npm package for now: the protocol is text, projects aren't all Node, and agents don't read `node_modules/`. Later, once the format settles, a `check` / `init` tool can run straight from GitHub (`npx github:…`) without publishing.

## Reference
A real Baton to follow: [Midinja's `.baton/`](https://github.com/bfunc/midinja/tree/main/.baton). No invented examples: a made-up history shows the format but not whether it works.
