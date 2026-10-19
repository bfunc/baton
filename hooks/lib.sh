#!/bin/bash
# Shared helpers for the Baton hooks. Sourced, not run.

# python3 where it works (on Windows "python3" can be a Store stub), else python.
for PY in python3 python; do "$PY" -c '' 2> /dev/null && break; done
# md5sum (Linux, Git Bash) or md5 (macOS)
command -v md5sum > /dev/null && MD5=md5sum || MD5="md5 -r"

# Read the hook's JSON input once.
BATON_INPUT="$(cat)"

# json_get <dotted.key>: print a field of the hook input, empty if missing.
json_get() {
    printf '%s' "$BATON_INPUT" | "$PY" -c '
import json, sys
try:
    v = json.load(sys.stdin)
    for k in sys.argv[1].split("."):
        v = v.get(k) if isinstance(v, dict) else None
    if v is None: v = ""
    print(v if isinstance(v, str) else json.dumps(v))
except Exception:
    pass
' "$1"
}

# find_baton <dir>: print the nearest folder upwards that holds .baton/, or fail.
find_baton() {
    local d="$1"
    while [ -n "$d" ]; do
        [ -d "$d/.baton" ] && { printf '%s' "$d"; return 0; }
        local up="$(dirname "$d")"
        [ "$up" = "$d" ] && break
        d="$up"
    done
    return 1
}

# fingerprint of the work outside .baton/ (HEAD + uncommitted changes + untracked files)
code_fp() {
    { git rev-parse HEAD 2>/dev/null
      git diff HEAD -- . ':(exclude).baton' 2>/dev/null
      git ls-files --others --exclude-standard -- . ':(exclude).baton' 2>/dev/null
    } | $MD5 | cut -c1-32
}

# fingerprint of the logs
log_fp() {
    cat .baton/log/*.md 2>/dev/null | $MD5 | cut -c1-32
}

BATON_SESSIONS="$HOME/.baton/sessions"
mkdir -p "$BATON_SESSIONS"
