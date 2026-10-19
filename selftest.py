"""Hook part of selftest.sh: calls the hooks with the payloads an agent sends and checks the answers.
Usage (from selftest.sh): python selftest.py <bash> <baton> <project> <dir-without-baton> <text|json> <YYYY-MM>
"""
import json, os, random, subprocess, sys

bash, baton, proj, outside, fmt, month = sys.argv[1:]
fails = 0


def ok(m):
    print("  ok    " + m)


def fail(m):
    global fails
    fails += 1
    print("  FAIL  " + m)


def check(cond, m):
    (ok if cond else fail)(m)


def run(script, payload, *args):
    data = payload if isinstance(payload, str) else json.dumps(payload)
    r = subprocess.run([bash, baton + "/hooks/" + script, *args], input=data,
                       capture_output=True, text=True, encoding="utf-8", timeout=60)
    return r.returncode, r.stdout, r.stderr


sid = "selftest%06d" % random.randrange(10**6)
start = {"hook_event_name": "SessionStart", "session_id": sid, "cwd": proj, "source": "startup"}
args = ["--json"] if fmt == "json" else []

# SessionStart: the facts reach the agent in the form it reads
code, out, err = run("brief.sh", start, *args)
text = out
if fmt == "json":
    try:
        text = json.loads(out)["additionalContext"]
        ok("start brief is JSON with additionalContext")
    except Exception:
        text = ""
        fail("start brief is not JSON with additionalContext: %r %r" % (out[:200], err[:200]))
for marker in ("# Baton facts", "# STATE.md", "selftest · Baton"):
    check(marker in text, "start brief has %r" % marker)
code, out, err = run("brief.sh", dict(start, cwd=outside), *args)
check(out.strip() in ("", "{}"), "start brief silent outside a Baton project")

# PreToolUse: logs are append-only
log = proj + "/.baton/log/" + month + ".md"
old = open(log, encoding="utf-8").read()
last = old.rstrip("\n").splitlines()[-1]
first = old.splitlines()[0]
other = proj + "/README.md"
cases = [
    ("append by write", 0, {"tool_name": "Write", "tool_input": {"file_path": log, "content": old + "\n### new entry\n"}}),
    ("rewrite by write", 2, {"tool_name": "Write", "tool_input": {"file_path": log, "content": "# replaced\n"}}),
    ("append by edit", 0, {"tool_name": "Edit", "tool_input": {"file_path": log, "old_string": last, "new_string": last + "\n- more"}}),
    ("replace by edit", 2, {"tool_name": "Edit", "tool_input": {"file_path": log, "old_string": first, "new_string": "# changed"}}),
    ("replace by edit (path/old_str/new_str)", 2, {"tool_name": "Edit", "tool_input": {"path": log, "old_str": first, "new_str": "# changed"}}),
    ("append by edit (path/old_str/new_str)", 0, {"tool_name": "Edit", "tool_input": {"path": log, "old_str": last, "new_str": last + "\n- more"}}),
    ("rewrite by create (file_text)", 2, {"tool_name": "Write", "tool_input": {"path": log, "file_text": "x"}}),
    ("arguments as a JSON string", 2, {"tool_name": "Edit", "tool_input": json.dumps({"path": log, "old_str": first, "new_str": "x"})}),
    ("patch that removes a log line", 2, {"tool_name": "apply_patch", "tool_input": "*** Update File: .baton/log/%s.md\n-%s\n+x\n" % (month, first)}),
    ("edit of another file", 0, {"tool_name": "Edit", "tool_input": {"file_path": other, "old_string": "hello", "new_string": "bye"}}),
    ("shell command", 0, {"tool_name": "Bash", "tool_input": {"command": "ls"}}),
    ("unreadable input", 0, "not json"),
]
for name, want, payload in cases:
    code, out, err = run("log-append-only.sh", payload)
    m = "log guard: %s -> %s" % (name, "deny" if want else "allow")
    check(code == want, m if code == want else m + " (got exit %d %s)" % (code, err.strip()[:120]))
check(open(log, encoding="utf-8").read() == old, "the log guard left the log untouched")

# Stop: work changed without a log entry -> block once
stop = {"hook_event_name": "Stop", "session_id": sid, "cwd": proj, "stop_hook_active": False}
code, out, err = run("stop-guard.sh", stop)
check("block" not in out, "stop guard quiet when nothing changed")
open(other, "a", encoding="utf-8").write("change\n")
code, out, err = run("stop-guard.sh", stop)
try:
    blocked = json.loads(out).get("decision") == "block"
except Exception:
    blocked = False
check(blocked, "stop guard blocks: work changed, no log entry" + ("" if blocked else " (got %r)" % out[:200]))
code, out, err = run("stop-guard.sh", stop)
check("block" not in out, "stop guard blocks only once")
open(log, "a", encoding="utf-8").write("\n### entry\n- Did: test\n")
open(other, "a", encoding="utf-8").write("change 2\n")
code, out, err = run("stop-guard.sh", stop)
check("block" not in out, "stop guard quiet when the log grew too")

try:
    os.remove(os.path.join(os.path.expanduser("~"), ".baton", "sessions", sid))
except OSError:
    pass
sys.exit(1 if fails else 0)
