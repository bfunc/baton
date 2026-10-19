#!/bin/bash
# Self-test of the Baton hooks the way a given agent calls them, in a throwaway git repo.
# Usage: bash selftest.sh <agent>     Prints a FAIL line and exits 1 for anything wrong.
BATON="$(cd "$(dirname "$0")" && pwd)"
A="${1:?usage: selftest.sh <agent>}"
CONF="$BATON/agents/$A/agent.conf"
[ -f "$CONF" ] || { echo "ERROR: no $CONF" >&2; exit 1; }
. "$CONF"
for PY in python3 python; do "$PY" -c '' 2> /dev/null && break; done
export PYTHONIOENCODING=utf-8
native() { (cd "$1" && { pwd -W 2> /dev/null || pwd; }); }
BASH_EXE="$(command -v bash)"; command -v cygpath > /dev/null && BASH_EXE="$(cygpath -m "$BASH_EXE")"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P="$T/selftest-project"; mkdir -p "$P" "$T/outside"
echo "Baton self-test for $AGENT_NAME"
FAILS=0
ok() { echo "  ok    $1"; }
fail() { echo "  FAIL  $1"; FAILS=$((FAILS + 1)); }

(cd "$P" && git init -q && git config core.autocrlf false && git config user.name selftest && git config user.email selftest@example.invalid \
    && echo hello > README.md && git add -A && git commit -qm init) || fail "git repo for the test"

# init
if bash "$BATON/init.sh" "$P" "$A" --name selftest > /dev/null; then ok "init.sh"; else fail "init.sh"; fi
for f in AGENT.md STATE.md "log/$(date +%Y-%m).md"; do
    if [ -s "$P/.baton/$f" ]; then ok ".baton/$f"; else fail ".baton/$f missing"; fi
done
if grep -qsF ".baton/AGENT.md" "$P/AGENTS.md"; then ok "AGENTS.md line"; else fail "AGENTS.md line"; fi
while IFS='|' read -r f line; do
    [ -z "$f" ] && continue
    if grep -qsF -- "$line" "$P/$f"; then ok "$f line"; else fail "$f line"; fi
done <<< "$INSTR"
(cd "$P" && git add -A && git commit -qm baton) || fail "commit .baton/"

# the hooks, called the way the agent calls them
"$PY" "$BATON/selftest.py" "$BASH_EXE" "$(native "$BATON")" "$(native "$P")" "$(native "$T/outside")" "$BRIEF_FORMAT" "$(date +%Y-%m)" \
    || FAILS=$((FAILS + 1))

if [ "$FAILS" -gt 0 ]; then echo "Baton self-test: FAILED"; exit 1; fi
echo "Baton self-test: all passed"
