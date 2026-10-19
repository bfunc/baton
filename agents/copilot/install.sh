#!/bin/bash
# Baton for GitHub Copilot on this machine: the machine name, the user hooks file, a self-test.
# One hooks file serves both Copilot CLI and the Copilot chat in VS Code (agent mode, Local),
# which both read ~/.copilot/hooks/*.json; init.sh writes the instruction files both read.
# Usage: bash agents/copilot/install.sh [machine] [--project DIR] [--live] [--uninstall]
#   --project DIR  also add a Baton to that project (init.sh DIR copilot)
#   --live         also start a real `copilot -p` session and check that the start brief reaches it
# Re-run after moving the Baton folder. Exit 1 with ERROR: when something is wrong.
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../common.sh"
source "$HERE/agent.conf"
parse_args "$@"
need_tools

if [ -n "$UNINSTALL" ]; then
    rm -f "$HOOKS_FILE"
    echo "removed $HOOKS_FILE; ~/.baton kept"
    exit 0
fi

set_machine "$MACHINE"
command -v "$CLI" > /dev/null || echo "note: $CLI (Copilot CLI) not found on PATH; the hooks load when it runs"

# bash for cmd or PowerShell (VS Code on Windows): an 8.3 path has no spaces, so it runs in both
WINBASH="$(native_bash)"
if command -v cygpath > /dev/null; then
    short="$(cygpath -m "$(cygpath -d "$(command -v bash)")" 2> /dev/null)"
    case "$short" in *" "*|"") WINBASH="\"$WINBASH\""; echo "note: no short path for bash; the VS Code hooks need cmd on Windows" ;; *) WINBASH="$short" ;; esac
fi

# hooks.json -> the user hooks file, with this folder and this bash filled in
mkdir -p "$(dirname "$HOOKS_FILE")"
"$PY" - "$HERE/hooks.json" "$HOOKS_FILE" "$BATON_NATIVE" "$(native_bash)" "$WINBASH" << 'EOF' || die "could not write $HOOKS_FILE"
import json, os, re, sys
src, dst, base, bash, winbash = sys.argv[1:]
text = open(src, encoding="utf-8").read()
text = text.replace("{{BATON}}", base).replace("{{WINBASH}}", winbash.replace('"', '\\"')).replace("{{BASH}}", bash)
conf = json.loads(text)
assert conf.get("version") == 1
for ev in ("SessionStart", "PreToolUse", "Stop"):
    for h in conf["hooks"][ev]:
        for key in ("bash", "powershell", "command", "windows"):
            for p in re.findall(r"['\"]([^'\"]+\.sh)['\"]", h[key]):
                assert os.path.exists(p), "missing: " + p
open(dst, "w", encoding="utf-8").write(json.dumps(conf, indent=2) + "\n")
EOF
echo "hooks -> $BATON_NATIVE/hooks, in $HOOKS_FILE"

# on Windows: the exact command strings must run from cmd and from PowerShell
if command -v cygpath > /dev/null; then
    "$PY" - "$HOOKS_FILE" "$(cygpath -m "$(mktemp -d)")" << 'EOF' || die "a hook command from $HOOKS_FILE does not run on Windows (see above)"
import json, subprocess, sys
conf, empty = json.load(open(sys.argv[1], encoding="utf-8")), sys.argv[2]
payload = json.dumps({"hook_event_name": "SessionStart", "session_id": "x", "cwd": empty})
h = conf["hooks"]["SessionStart"][0]
runs = {"windows (cmd)": "cmd /c " + h["windows"],   # a string: cmd takes the line as it is
        "windows (PowerShell)": ["powershell", "-NoProfile", "-Command", h["windows"]],
        "powershell (Copilot CLI)": ["powershell", "-NoProfile", "-Command", h["powershell"]]}
bad = 0
for name, cmd in runs.items():
    r = subprocess.run(cmd, input=payload, capture_output=True, text=True, timeout=60)
    good = r.returncode == 0 and r.stdout.strip() in ("", "{}")
    print("  %s  hook command runs: %s" % ("ok  " if good else "FAIL", name) + ("" if good else " (exit %d) %s" % (r.returncode, (r.stderr or r.stdout)[:200])))
    bad += not good
sys.exit(1 if bad else 0)
EOF
fi

# VS Code: hooks are a preview feature; warn if they are switched off in the user settings
for f in "$APPDATA/Code/User/settings.json" "$HOME/Library/Application Support/Code/User/settings.json" "$HOME/.config/Code/User/settings.json"; do
    [ -f "$f" ] && grep -qE '"chat\.useHooks"[[:space:]]*:[[:space:]]*false' "$f" \
        && echo "WARNING: VS Code has chat.useHooks = false in $f: the Copilot chat won't run the hooks"
done

bash "$BATON/selftest.sh" copilot || die "self-test failed (see FAIL lines above)"

[ -n "$PROJECT" ] && { bash "$BATON/init.sh" "$PROJECT" copilot || die "init.sh $PROJECT failed"; }
[ -n "$LIVE" ] && live_test copilot "$CLI --allow-all-tools -p"
echo "done. New sessions load the hooks."
echo "Check in VS Code (no CLI for it): open the project, new Copilot chat in Agent mode, ask"
echo "  \"Quote the 'Sign log entries' line from the Baton facts you got at session start\""
echo "  It must end with @$(cat "$HOME/.baton/machine")#xxxx. If not: Developer: Show Agent Debug Logs."
