#!/bin/bash
# Baton for GitHub Copilot on this machine: the machine name, the Copilot CLI hooks, a self-test.
# Usage: bash agents/copilot/install.sh [machine] [--project DIR] [--live] [--uninstall]
#   --project DIR  also add a Baton to that project (init.sh DIR copilot)
#   --live         also start a real `copilot -p` session and check that the start brief reaches it
# Copilot in VS Code reads the instruction files that init.sh writes; the hooks are for Copilot CLI.
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
command -v "$CLI" > /dev/null || echo "note: $CLI not found on PATH; the hooks load when Copilot CLI runs"

# hooks.json -> the user hooks file, with this folder and this bash filled in
mkdir -p "$(dirname "$HOOKS_FILE")"
"$PY" - "$HERE/hooks.json" "$HOOKS_FILE" "$BATON_NATIVE" "$(native_bash)" << 'EOF' || die "could not write $HOOKS_FILE"
import json, os, re, sys
src, dst, base, bash = sys.argv[1:]
text = open(src, encoding="utf-8").read().replace("{{BATON}}", base).replace("{{BASH}}", bash)
conf = json.loads(text)
assert conf.get("version") == 1
for ev in ("SessionStart", "PreToolUse", "Stop"):
    for h in conf["hooks"][ev]:
        for key in ("bash", "powershell"):
            for p in re.findall(r"'([^']+)'", h[key]):
                assert os.path.exists(p), "missing: " + p
open(dst, "w", encoding="utf-8").write(json.dumps(conf, indent=2) + "\n")
EOF
echo "hooks -> $BATON_NATIVE/hooks, in $HOOKS_FILE"

bash "$BATON/selftest.sh" copilot || die "self-test failed (see FAIL lines above)"

[ -n "$PROJECT" ] && { bash "$BATON/init.sh" "$PROJECT" copilot || die "init.sh $PROJECT failed"; }
[ -n "$LIVE" ] && live_test copilot "$CLI --allow-all-tools -p"
echo "done: start a new Copilot CLI session for the hooks to load"
