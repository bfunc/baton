#!/bin/bash
# Baton for Claude Code on this machine: the machine name, the hooks in the user settings, a self-test.
# Usage: bash agents/claude/install.sh [machine] [--project DIR] [--live] [--uninstall]
#   --project DIR  also add a Baton to that project (init.sh DIR claude)
#   --live         also start a real `claude -p` session and check that the start brief reaches it
# Re-run after moving the Baton folder. Exit 1 with ERROR: when something is wrong.
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../common.sh"
source "$HERE/agent.conf"
parse_args "$@"
need_tools

# merge_hooks <add|remove>: drop earlier Baton entries (any path), keep everything else, add ours
merge_hooks() {
    mkdir -p "$(dirname "$SETTINGS")"
    [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"
    "$PY" - "$SETTINGS" "$BATON_NATIVE" "$1" << 'EOF'
import json, os, sys
path, base, mode = sys.argv[1:]
s = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
hooks = s.setdefault("hooks", {})
mine = ("/hooks/brief.sh", "/hooks/stop-guard.sh", "/hooks/log-append-only.sh")
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", []) if not any(m in h.get("command", "").replace("\\", "/") for m in mine)]
        if g["hooks"]:
            groups.append(g)
    hooks[event] = groups
    if not groups:
        del hooks[event]
if mode == "add":
    cmd = lambda f, t: {"type": "command", "command": "bash '%s/hooks/%s'" % (base, f), "timeout": t}
    hooks.setdefault("SessionStart", []).append({"hooks": [cmd("brief.sh", 30)]})
    hooks.setdefault("Stop", []).append({"hooks": [cmd("stop-guard.sh", 15)]})
    hooks.setdefault("PreToolUse", []).append({"matcher": "Edit|Write|MultiEdit", "hooks": [cmd("log-append-only.sh", 10)]})
if not hooks:
    del s["hooks"]
json.dump(s, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
EOF
}

if [ -n "$UNINSTALL" ]; then
    merge_hooks remove
    echo "Baton hooks removed from $SETTINGS (backup: settings.json.bak); ~/.baton kept"
    exit 0
fi

set_machine "$MACHINE"
command -v claude > /dev/null || echo "note: claude not found on PATH; the hooks load when Claude Code runs"
merge_hooks add
"$PY" - "$SETTINGS" << 'EOF' || die "hooks were not written to $SETTINGS"
import json, os, re, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
cmds = [h["command"] for ev in ("SessionStart", "Stop", "PreToolUse") for g in s["hooks"][ev] for h in g["hooks"]]
found = [c for c in cmds if "/hooks/" in c.replace("\\", "/")]
assert len(found) >= 3, found
for c in found:
    p = re.search(r"'([^']+)'", c).group(1)
    assert os.path.exists(p), p
EOF
echo "hooks -> $BATON_NATIVE/hooks, in $SETTINGS (backup: settings.json.bak)"

bash "$BATON/selftest.sh" claude || die "self-test failed (see FAIL lines above)"

[ -n "$PROJECT" ] && { bash "$BATON/init.sh" "$PROJECT" claude || die "init.sh $PROJECT failed"; }
[ -n "$LIVE" ] && live_test claude "claude -p"
echo "done: start a new Claude Code session for the hooks to load"
