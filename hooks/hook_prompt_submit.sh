#!/bin/bash
set -e

# Hook role:
# - trigger CPST- prefixed auto-checkpoint commit once per session
# - inject minimal AskUserQuestion context only when git is not initialized

unset GIT_DIR
unset GIT_WORK_TREE
unset GIT_COMMON_DIR
unset GIT_INDEX_FILE
unset GIT_OBJECT_DIRECTORY

# Windows compatibility: test actual execution, not just path existence
# (Windows has a broken python3.exe stub in WindowsApps)
if python3 -c "import sys" > /dev/null 2>&1; then
  PYTHON_CMD="python3"
elif python -c "import sys" > /dev/null 2>&1; then
  PYTHON_CMD="python"
else
  echo "Error: Python not found" >&2
  exit 1
fi

PAYLOAD="$(cat)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi

# Auto checkpoint commit for UserPromptSubmit (CPST- prefix) and no-git state handling.
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.py"
AUTO_COMMIT_OUTPUT=""
if [ -f "$AUTO_COMMIT_SCRIPT" ]; then
  export HOOK_EVENT_TYPE=prompt_submit
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  AUTO_COMMIT_OUTPUT="$(printf '%s' "$PAYLOAD" | "$PYTHON_CMD" "$AUTO_COMMIT_SCRIPT" 2>/dev/null || true)"
fi

ADDITIONAL_CONTEXT=""
if [ -n "$AUTO_COMMIT_OUTPUT" ]; then
  export AUTO_COMMIT_OUTPUT
  ADDITIONAL_CONTEXT="$("$PYTHON_CMD" - <<'PY'
import json
import os

raw = os.environ.get("AUTO_COMMIT_OUTPUT", "").strip()
if not raw:
    print("")
    raise SystemExit(0)

try:
    data = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)

ctx = data.get("additional_context", "")
print(ctx if isinstance(ctx, str) else "")
PY
)"
fi

export ADDITIONAL_CONTEXT PYTHON_CMD
"$PYTHON_CMD" - <<'PY'
import json
import os

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": os.environ.get("ADDITIONAL_CONTEXT", "")
    }
}, ensure_ascii=False))
PY

exit 0
