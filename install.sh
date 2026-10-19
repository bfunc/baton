#!/bin/bash
# Set up Baton on this machine: the machine name and the Claude Code hooks.
# Usage: bash install.sh [machine-name]    (re-run after moving the repo)
#        bash install.sh --uninstall
# Needs bash (Git Bash on Windows), git and python; gh is optional.
set -e
DIR="$(cd "$(dirname "$0")" && { pwd -W 2> /dev/null || pwd; })"
SETTINGS="$HOME/.claude/settings.json"

for PY in python3 python; do "$PY" -c '' 2> /dev/null && break; done
"$PY" -c '' 2> /dev/null || { echo "python not found"; exit 1; }
command -v git > /dev/null || { echo "git not found"; exit 1; }
command -v gh > /dev/null || [ -x "$(cat "$HOME/.baton/gh" 2> /dev/null)" ] \
    || echo "note: gh not found; the start brief will skip PRs and CI (or put the path to gh in ~/.baton/gh)"

if [ "$1" != "--uninstall" ]; then
    mkdir -p "$HOME/.baton/sessions"
    NAME="${1:-$(cat "$HOME/.baton/machine" 2> /dev/null || hostname | tr 'A-Z' 'a-z')}"
    printf '%s\n' "$NAME" > "$HOME/.baton/machine"
    echo "machine: $NAME (agents sign as <model>@$NAME#<session>)"
fi

mkdir -p "$HOME/.claude"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"
"$PY" - "$SETTINGS" "$DIR" "$1" << 'EOF'
import json, os, sys
path, base, mode = sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else ""
s = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
hooks = s.setdefault("hooks", {})
mine = ("/hooks/brief.sh", "/hooks/stop-guard.sh", "/hooks/log-append-only.sh")

# drop earlier Baton entries (any path), keep everything else
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", []) if not any(m in h.get("command", "").replace("\\", "/") for m in mine)]
        if g["hooks"]:
            groups.append(g)
    hooks[event] = groups
    if not groups:
        del hooks[event]

if mode != "--uninstall":
    cmd = lambda f, t: {"type": "command", "command": f"bash {base}/hooks/{f}", "timeout": t}
    hooks.setdefault("SessionStart", []).append({"hooks": [cmd("brief.sh", 30)]})
    hooks.setdefault("Stop", []).append({"hooks": [cmd("stop-guard.sh", 15)]})
    hooks.setdefault("PreToolUse", []).append({"matcher": "Edit|Write|MultiEdit", "hooks": [cmd("log-append-only.sh", 10)]})
if not hooks:
    del s["hooks"]
json.dump(s, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
EOF

if [ "$1" = "--uninstall" ]; then
    echo "hooks removed from $SETTINGS (backup: settings.json.bak); ~/.baton kept"
else
    echo "hooks -> $DIR/hooks, in $SETTINGS (backup: settings.json.bak)"
    echo "start a new Claude Code session for them to load; add Baton to a project with: bash $DIR/init.sh <project>"
fi
