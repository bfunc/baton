#!/bin/bash
# Shared helpers for agents/<agent>/install.sh. Sourced, not run.
set -e
BATON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# the same folder in the form the agent's shell takes (D:/x on Windows, /x elsewhere)
BATON_NATIVE="$(cd "$BATON" && { pwd -W 2> /dev/null || pwd; })"

die() { echo "ERROR: $*" >&2; exit 1; }

need_tools() {
    for PY in python3 python; do "$PY" -c '' 2> /dev/null && break; done
    "$PY" -c 'import sys; assert sys.version_info >= (3, 6)' 2> /dev/null || die "python 3 not found"
    command -v git > /dev/null || die "git not found"
    if ! command -v gh > /dev/null && [ ! -x "$(cat "$HOME/.baton/gh" 2> /dev/null)" ]; then
        echo "note: gh not found; the start brief skips PRs and CI (or put the path to gh in ~/.baton/gh)"
    fi
}

# set_machine [name]: the name agents sign with (<model>@<machine>#<session>)
set_machine() {
    mkdir -p "$HOME/.baton/sessions"
    local name="${1:-$(cat "$HOME/.baton/machine" 2> /dev/null || hostname | tr 'A-Z' 'a-z')}"
    printf '%s\n' "$name" > "$HOME/.baton/machine"
    echo "machine: $name"
}

# bash as a native path, for agents that start hooks from PowerShell or cmd
native_bash() {
    local b; b="$(command -v bash)"
    if command -v cygpath > /dev/null; then cygpath -m "$b"; else printf '%s' "$b"; fi
}

# parse_args: sets MACHINE, PROJECT, LIVE, UNINSTALL, DRY from "[machine] [--project DIR] [--live] [--uninstall] [--dry-run]"
parse_args() {
    MACHINE=""; PROJECT=""; LIVE=""; UNINSTALL=""; DRY=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) PROJECT="$2"; shift ;;
            --live) LIVE=1 ;;
            --uninstall) UNINSTALL=1 ;;
            --dry-run) DRY=1 ;;
            -*) die "unknown option $1" ;;
            *) MACHINE="$1" ;;
        esac
        shift
    done
}

# live_test <agent> <command prefix>: a real non-interactive session in a throwaway project;
# passes when the agent can quote the signature that only the start hook gives it.
live_test() {
    local agent="$1" cmd="$2" t out m
    command -v "${cmd%% *}" > /dev/null || die "live test: ${cmd%% *} not found on PATH"
    t="$(mktemp -d)"
    (cd "$t" && git init -q && git config core.autocrlf false && git config user.name selftest \
        && git config user.email selftest@example.invalid && echo hello > README.md \
        && bash "$BATON/init.sh" . "$agent" --name livetest > /dev/null && git add -A && git commit -qm init) \
        || die "live test: could not set up $t"
    m="$(cat "$HOME/.baton/machine")"
    echo "live test: starting $cmd in $t (up to 5 min)"
    out="$(cd "$t" && timeout 300 $cmd "Do not use any tools. In the Baton facts given to you at session start there is a line 'Sign log entries and claims as ...'. Reply with that line only, or NONE if you were given no Baton facts." 2>&1)" || true
    rm -rf "$t"
    if printf '%s' "$out" | grep -qiE "cannot find .*cli|not installed|command not found"; then
        printf '%s\n' "$out" | tail -5 >&2
        die "live test: the $agent CLI is not installed or not set up (see above)"
    fi
    if printf '%s' "$out" | grep -qE "@$m#[^ ]{4}"; then
        echo "live test: ok, the start brief reached $agent"
    else
        printf '%s\n' "$out" | tail -15 >&2
        die "live test: $agent did not get the start brief (reply above)"
    fi
}
