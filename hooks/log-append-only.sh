#!/bin/bash
# PreToolUse hook: .baton/log/*.md is append-only.
# A change passes only if it keeps every existing line and adds after them.
# Exit 2 = deny (stderr is the reason). Any other tool or file passes, and so does anything
# this script fails to read: some agents deny the tool call on any non-zero exit.
HOOKS="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS/lib.sh"

printf '%s' "$BATON_INPUT" | "$PY" -c '
import json, os, re, sys
LOG = r"\.baton/log/[^/\s]+\.md"

def bad(msg):
    sys.stderr.write("Baton: .baton/log/ is append-only. " + msg + " Add a new entry at the end instead; fix mistakes with a new entry.\n")
    sys.exit(2)

def check(d):
    t = d.get("tool_input") or {}
    if isinstance(t, str):
        try:
            t = json.loads(t)
        except ValueError:
            # a patch as text: no removed lines in a log file
            if re.search(LOG, t.replace("\\", "/")) and re.search(r"(?m)^-(?!--)", t):
                bad("This patch removes lines.")
            return
    if not isinstance(t, dict):
        return
    # field names differ by agent: file_path / old_string / new_string / content,
    # or path / old_str / new_str / file_text
    path = str(t.get("file_path") or t.get("path") or "").replace("\\", "/")
    if not re.search("/" + LOG + "$", path) or not os.path.exists(path):
        return
    old = open(path, encoding="utf-8").read().rstrip("\n")
    content = t.get("content", t.get("file_text"))
    if content is not None and "old_string" not in t and "old_str" not in t:
        if not content.startswith(old):
            bad("This write would change or remove existing lines.")
        return
    for e in t.get("edits") or [t]:
        o = e.get("old_string", e.get("old_str", ""))
        n = e.get("new_string", e.get("new_str", ""))
        if not n.startswith(o):
            bad("This edit replaces existing text.")
        if not old.endswith(o.rstrip("\n")):
            bad("Edits must append after the last line.")

try:
    check(json.load(sys.stdin))
except SystemExit:
    raise
except Exception:
    pass
'
