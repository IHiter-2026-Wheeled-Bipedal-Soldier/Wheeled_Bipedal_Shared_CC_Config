#!/bin/bash
set -e

# Hook role:
# - reset session checkpoint state
# - inject minimal runtime context only

PAYLOAD="$(cat)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

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

AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.py"
if [ -f "$AUTO_COMMIT_SCRIPT" ]; then
  export HOOK_EVENT_TYPE=session_start
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  printf '%s' "$PAYLOAD" | "$PYTHON_CMD" "$AUTO_COMMIT_SCRIPT" >/dev/null 2>&1 || true
fi

ADDITIONAL_CONTEXT="Runtime hooks active: CPST auto-commit runs once at first prompt when git repo exists; CPED auto-commit runs on session stop when changes exist. If git is not initialized, assistant will ask once whether to initialize git in this session."

export ADDITIONAL_CONTEXT PYTHON_CMD
"$PYTHON_CMD" - <<'PY'
import json
import os

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": os.environ.get("ADDITIONAL_CONTEXT", "")
    }
}, ensure_ascii=False))
PY

exit 0
