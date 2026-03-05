#!/bin/bash
set -e

# Hook role:
# - inject workflow guide context at session start
# - inject branch snapshot hint to enforce protected-branch transition protocol

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
GUIDE_FILE_PRIMARY="$CONFIG_DIR/rules/workflow-guide.md"
GUIDE_FILE_FALLBACK="$PROJECT_DIR/rules/workflow-guide.md"

if [ -f "$GUIDE_FILE_PRIMARY" ]; then
  ADDITIONAL_CONTEXT="$(cat "$GUIDE_FILE_PRIMARY")"
elif [ -f "$GUIDE_FILE_FALLBACK" ]; then
  ADDITIONAL_CONTEXT="$(cat "$GUIDE_FILE_FALLBACK")"
else
  ADDITIONAL_CONTEXT="Workflow guide is missing at rules/workflow-guide.md. Ask user to restore it before using workflow skills."
fi

CURRENT_BRANCH="unknown"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT

Session branch snapshot: $CURRENT_BRANCH
If branch is main or release/*, before any mutating action you must trigger AskUserQuestion to choose branch transition."

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
