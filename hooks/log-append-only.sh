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
# field names differ by agent and tool
PATH = ("file_path", "path", "filePath")
OLD = ("old_string", "old_str", "oldString")
NEW = ("new_string", "new_str", "newString")
TEXT = ("content", "file_text")

def bad(msg):
    sys.stderr.write("Baton: .baton/log/ is append-only. " + msg + " Add a new entry at the end instead; fix mistakes with a new entry.\n")
    sys.exit(2)

def get(d, keys, default=None):
    for k in keys:
        if k in d:
            return d[k]
    return default

def is_log(path):
    return bool(re.search("/" + LOG + "$", str(path or "").replace("\\", "/")))

def check_patch(text):
    # a patch as text: no removed lines in a log file
    if re.search(LOG, text.replace("\\", "/")) and re.search(r"(?m)^-(?!--)", text):
        bad("This patch removes lines.")

def check_edit(e, path):
    path = get(e, PATH, path)
    if not is_log(path) or not os.path.exists(path):
        return
    old = open(path, encoding="utf-8").read().rstrip("\n")
    o, n = get(e, OLD), get(e, NEW)
    if o is None:
        text = get(e, TEXT)
        if text is not None:
            if not text.startswith(old):
                bad("This write would change or remove existing lines.")
        elif "code" in e:
            bad("This tool rewrites the file.")
        return
    n = n or ""
    if not n.startswith(o):
        bad("This edit replaces existing text.")
    if not old.endswith(o.rstrip("\n")):
        bad("Edits must append after the last line.")

def check(d):
    t = d.get("tool_input") or {}
    if isinstance(t, str):
        try:
            t = json.loads(t)
        except ValueError:
            return check_patch(t)
    if not isinstance(t, dict):
        return
    for k in ("input", "patch"):
        if isinstance(t.get(k), str):
            check_patch(t[k])
    path = get(t, PATH)
    for e in t.get("edits") or t.get("replacements") or [t]:
        if isinstance(e, dict):
            check_edit(e, path)

try:
    check(json.load(sys.stdin))
except SystemExit:
    raise
except Exception:
    pass
'
