#!/bin/bash
# Stop hook: if the work changed since the last check and the Baton log did not,
# stop the agent once and ask it to log. Silent everywhere else.
# --json: the block is also nested in hookSpecificOutput, for agents that read it there.
HOOKS="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS/lib.sh"

[ "$(json_get stop_hook_active)" = "true" ] && exit 0
SID="$(json_get session_id)"; [ -z "$SID" ] && exit 0
CWD="$(json_get cwd)"; [ -z "$CWD" ] && CWD="$PWD"
ROOT="$(find_baton "$CWD")" || exit 0
cd "$ROOT" || exit 0
F="$BATON_SESSIONS/$SID"

CODE="$(code_fp)"; LOG="$(log_fp)"
if [ ! -f "$F" ]; then
    printf '%s %s\n' "$CODE" "$LOG" > "$F"   # session started before the hooks existed
    exit 0
fi
read -r CODE0 LOG0 < "$F"
printf '%s %s\n' "$CODE" "$LOG" > "$F"       # new baseline: block at most once per change

if [ "$CODE" != "$CODE0" ] && [ "$LOG" = "$LOG0" ]; then
    R="Baton: the work changed but .baton/log/ has no new entry. Append a log entry (Did / Checked / Commit / Left) and update .baton/STATE.md, or say in one line why this change needs none."
    if [ "$1" = "--json" ]; then   # also nested, for agents that read hookSpecificOutput
        printf '{"decision":"block","reason":"%s","hookSpecificOutput":{"hookEventName":"Stop","decision":"block","reason":"%s"}}\n' "$R" "$R"
    else
        printf '{"decision":"block","reason":"%s"}\n' "$R"
    fi
fi
exit 0
