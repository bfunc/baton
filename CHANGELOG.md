# Baton changelog

- v0.8 (2026-10-19): published; `install.sh` (machine name + hooks in user settings, idempotent, `--uninstall`) and `init.sh` (adds `.baton/` and the CLAUDE.md line to a project); hooks run on Linux/macOS too (python3, md5); gh path from `~/.baton/gh`. Protocol unchanged (AGENT.md stays v0.7).
- v0.7 (2026-10-17): short log entries (≤5 lines), Left/Surprise move to STATE at session end, `Verifies:` closes Unverified items, month summaries, Baton changes logged here instead of project logs.
- v0.6 (2026-10-17): agents sign as `<model>@<machine>#<session4>`; times only from `date`.
- v0.5 (2026-10-17): Decisions get topics (a correction replaces its line); agent-inferred rules wait for the user's yes; `brief.sh` injects the newest log entries.
- v0.4 (2026-10-17): Claude Code hooks: `brief.sh`, `stop-guard.sh`, `log-append-only.sh`, one copy per machine.
- v0.3 (2026-10-17): `.baton/` folder (AGENT.md, STATE.md, log/YYYY-MM.md), start screen with menu, playbooks, multi-repo hub.
- v0.2 (2026-10-17): state only; README content removed from the Baton.
- v0.1 (2026-10-17): single BATON.md with Waypoint and Logbook.
