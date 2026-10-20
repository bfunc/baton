# Baton changelog

- v0.8.1 (2026-10-20): installers take `--dry-run` (Claude: a diff of the `hooks` section; Copilot: the file it would write). Claude installer: stops on a settings file that isn't valid JSON instead of overwriting it; keeps other tools' hook entries that are not in Claude Code's shape (it used to drop them on merge) and warns that Claude Code ignores them. From a review of TokenBouncer's installer.
- v0.8 (2026-10-19): published. Agent-neutral: hooks read the common hook input; per-agent `agents/<agent>/agent.conf` + `install.sh` for Claude Code and GitHub Copilot (one hooks file for Copilot CLI and the VS Code chat; JSON output top-level and in `hookSpecificOutput`; the log guard knows the VS Code edit tools); `init.sh <dir> [agent ...]` always adds the AGENTS.md line; `selftest.sh <agent>` runs every hook the way that agent calls it, `--live` checks a real session. Fixes: `~/.baton/` was taken for a project Baton (a project now needs `.baton/STATE.md`); the log guard fails open on unreadable input; python3/md5 for Linux and macOS. Protocol unchanged (AGENT.md stays v0.7).
- v0.7 (2026-10-17): short log entries (≤5 lines), Left/Surprise move to STATE at session end, `Verifies:` closes Unverified items, month summaries, Baton changes logged here instead of project logs.
- v0.6 (2026-10-17): agents sign as `<model>@<machine>#<session4>`; times only from `date`.
- v0.5 (2026-10-17): Decisions get topics (a correction replaces its line); agent-inferred rules wait for the user's yes; `brief.sh` injects the newest log entries.
- v0.4 (2026-10-17): Claude Code hooks: `brief.sh`, `stop-guard.sh`, `log-append-only.sh`, one copy per machine.
- v0.3 (2026-10-17): `.baton/` folder (AGENT.md, STATE.md, log/YYYY-MM.md), start screen with menu, playbooks, multi-repo hub.
- v0.2 (2026-10-17): state only; README content removed from the Baton.
- v0.1 (2026-10-17): single BATON.md with Waypoint and Logbook.
