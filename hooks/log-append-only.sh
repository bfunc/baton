#!/bin/bash
# PreToolUse hook (Edit|Write|MultiEdit): .baton/log/*.md is append-only.
# A change passes only if it keeps every existing line and adds after them.
HOOKS="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS/lib.sh"

printf '%s' "$BATON_INPUT" | "$PY" -c '
import json, os, re, sys
d = json.load(sys.stdin)
tool, t = d.get("tool_name", ""), d.get("tool_input", {}) or {}
path = (t.get("file_path") or "").replace("\\", "/")
if not re.search(r"/\.baton/log/[^/]+\.md$", path) or not os.path.exists(path):
    sys.exit(0)
old = open(path, encoding="utf-8").read()

def bad(msg):
    sys.stderr.write("Baton: .baton/log/ is append-only. " + msg + " Add a new entry at the end instead; fix mistakes with a new entry.\n")
    sys.exit(2)

if tool == "Write":
    if not t.get("content", "").startswith(old.rstrip("\n")):
        bad("This Write would change or remove existing lines.")
else:
    edits = t.get("edits") or [t]
    for e in edits:
        o, n = e.get("old_string", ""), e.get("new_string", "")
        if not n.startswith(o):
            bad("This edit replaces existing text.")
        if not old.rstrip("\n").endswith(o.rstrip("\n")):
            bad("Edits must append after the last line.")
'
