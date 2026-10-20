#!/bin/bash
# Baton for Claude Code on this machine: the machine name, the hooks in the user settings, a self-test.
# Usage: bash agents/claude/install.sh [machine] [--project DIR] [--live] [--uninstall] [--dry-run]
#   --project DIR  also add a Baton to that project (init.sh DIR claude)
#   --live         also start a real `claude -p` session and check that the start brief reaches it
#   --dry-run      only print what would change in the settings file; write nothing
# Re-run after moving the Baton folder. Exit 1 with ERROR: when something is wrong.
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../common.sh"
source "$HERE/agent.conf"
parse_args "$@"
need_tools

# merge_hooks <add|remove> [dry]: drop earlier Baton entries (any path), keep everything else, add
# ours. A settings file that doesn't parse stops the install: it is never replaced by {}.
# dry: print the change of the hooks section as a diff and write nothing.
merge_hooks() {
    if [ -z "$2" ]; then
        mkdir -p "$(dirname "$SETTINGS")"
        [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak"
    fi
    "$PY" - "$SETTINGS" "$BATON_NATIVE" "$1" "$2" << 'EOF'
import copy, difflib, json, os, sys
path, base, mode, dry = sys.argv[1:]
try:
    s = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
except ValueError as e:
    sys.exit("ERROR: %s is not valid JSON (%s); fix it first, nothing was changed" % (path, e))
old = copy.deepcopy(s.get("hooks", {}))
hooks = s.setdefault("hooks", {})
mine = ("/hooks/brief.sh", "/hooks/stop-guard.sh", "/hooks/log-append-only.sh")
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        if not isinstance(g, dict) or not isinstance(g.get("hooks"), list):
            groups.append(g)   # not ours and not in Claude Code's shape: keep it as it is (the check below names it)
            continue
        g["hooks"] =[h for h in g.get("hooks", []) if not any(m in h.get("command", "").replace("\\", "/") for m in mine)]
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
if dry:
    a, b = (json.dumps({"hooks": h}, indent=2, ensure_ascii=False).splitlines() for h in (old, s.get("hooks", {})))
    print("\n".join(difflib.unified_diff(a, b, path + " (now)", path + " (after)", lineterm="")) or "no change in " + path)
else:
    json.dump(s, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
EOF
}

if [ -n "$DRY" ]; then
    echo "dry run: machine name for ~/.baton/machine: ${MACHINE:-$(cat "$HOME/.baton/machine" 2> /dev/null || hostname | tr 'A-Z' 'a-z')}"
    merge_hooks "$([ -n "$UNINSTALL" ] && echo remove || echo add)" dry
    echo "dry run: nothing written (the backup would go to $SETTINGS.bak)"
    exit 0
fi

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
# Claude Code's shape: {event: [{"matcher"?: str, "hooks": [{"type": "command", "command": str}, ...]}]}.
# Claude Code skips entries in another shape without a word: name them (ours must pass).
for ev, groups in s["hooks"].items():
    for i, g in enumerate(groups if isinstance(groups, list) else [groups]):
        hs = g.get("hooks") if isinstance(g, dict) else None
        if isinstance(hs, list) and hs and all(isinstance(h, dict) and isinstance(h.get("type"), str) for h in hs):
            continue
        assert not any(m in json.dumps(g) for m in ("brief.sh", "stop-guard.sh", "log-append-only.sh")), "a Baton entry has the wrong shape: %s" % g
        print("WARNING: hooks.%s[%d] in %s is not in Claude Code's hook format (matcher + hooks: [{type, command}]), so Claude Code ignores it: %s" % (ev, i, sys.argv[1], json.dumps(g)[:160]))
cmds = [h.get("command", "") for ev in ("SessionStart", "Stop", "PreToolUse") for g in s["hooks"][ev] if isinstance(g, dict) and isinstance(g.get("hooks"), list) for h in g["hooks"]]
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
