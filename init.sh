#!/bin/bash
# Add a Baton to a project: .baton/ from the template + the CLAUDE.md line.
# Usage: bash init.sh [project-dir] [project-name]
# Never overwrites: an existing .baton/ is left alone.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
P="${1:-.}"; cd "$P"
NAME="${2:-$(basename "$PWD")}"

if [ -d .baton ]; then
    echo ".baton/ already exists in $PWD; nothing copied"
else
    mkdir -p .baton/log
    cp "$SRC/AGENT.md" .baton/AGENT.md
    sed "s/<Project>/$NAME/" "$SRC/template/.baton/STATE.md" > .baton/STATE.md
    M="$(date +%Y-%m)"
    sed -e "s/<Project>/$NAME/" -e "s/YYYY-MM\$/$M/" "$SRC/template/.baton/log/YYYY-MM.md" > ".baton/log/$M.md"
    echo "created $PWD/.baton/"
fi

if grep -qs '@.baton/AGENT.md' CLAUDE.md; then
    echo "CLAUDE.md already imports .baton/AGENT.md"
else
    [ -s CLAUDE.md ] && printf '\n' >> CLAUDE.md
    printf '@.baton/AGENT.md\n' >> CLAUDE.md
    echo "added @.baton/AGENT.md to CLAUDE.md"
fi
[ -f AGENTS.md ] && ! grep -qs '.baton/AGENT.md' AGENTS.md && echo "AGENTS.md found: add 'Before any work, read and follow .baton/AGENT.md.' for other agents"
echo "next: open a Claude Code session here and say hi; the agent fills STATE.md (guesses marked (?))"
