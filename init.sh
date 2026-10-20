#!/bin/bash
# Add a Baton to a project: .baton/ from the template, a line in AGENTS.md (read by most agents),
# and for each agent named the lines from agents/<agent>/agent.conf.
# Usage: bash init.sh <project-dir> [agent ...] [--name NAME]     e.g. bash init.sh . claude copilot
# Never overwrites: an existing .baton/ and existing lines are left alone.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
P="."; NAME=""; AGENTS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --name) NAME="$2"; shift ;;
        *) if [ "$P" = "." ] && [ -d "$1" ]; then P="$1"; else AGENTS="$AGENTS $1"; fi ;;
    esac
    shift
done
for a in $AGENTS; do [ -f "$SRC/agents/$a/agent.conf" ] || { echo "ERROR: no agents/$a/agent.conf" >&2; exit 1; }; done
cd "$P"
NAME="${NAME:-$(basename "$PWD")}"

if [ -d .baton ]; then
    echo ".baton/ already exists in $PWD; nothing copied"
else
    mkdir -p .baton/log
    cp "$SRC/AGENT.md" .baton/AGENT.md
    ESC="$(printf '%s' "$NAME" | sed 's/[|&\\]/\\&/g')"   # | & \ are special in the sed replacement
    sed "s|<Project>|$ESC|" "$SRC/template/.baton/STATE.md" > .baton/STATE.md
    M="$(date +%Y-%m)"
    sed -e "s|<Project>|$ESC|" -e "s|YYYY-MM\$|$M|" "$SRC/template/.baton/log/YYYY-MM.md" > ".baton/log/$M.md"
    echo "created .baton/"
fi

# add_line <file> <line>: append the line unless the file already has it
add_line() {
    if grep -qsF -- "$2" "$1"; then
        echo "$1 already points to .baton/AGENT.md"
    else
        mkdir -p "$(dirname "$1")"
        [ -s "$1" ] && printf '\n' >> "$1"
        printf '%s\n' "$2" >> "$1"
        echo "added the Baton line to $1"
    fi
}
add_line AGENTS.md "Before any work, read and follow .baton/AGENT.md."
for a in $AGENTS; do
    INSTR=""; . "$SRC/agents/$a/agent.conf"
    while IFS='|' read -r f line; do [ -n "$f" ] && add_line "$f" "$line"; done <<< "$INSTR"
done
echo "next: open an agent session here and say hi; it fills STATE.md (guesses marked (?)). Commit .baton/ with the project."
