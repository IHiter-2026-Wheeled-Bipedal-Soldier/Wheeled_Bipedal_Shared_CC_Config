#!/bin/bash
set -e

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
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR/.claude" ]; then
  PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi
# Policy file moved to rules/
POLICY_FILE="$PROJECT_DIR/.claude/rules/git-harness-agent-policy.md"

if [ -f "$POLICY_FILE" ]; then
  ADDITIONAL_CONTEXT="$(cat "$POLICY_FILE")"
else
  ADDITIONAL_CONTEXT="MANDATORY: Enforce protected-branch read-only mode, guide user to create a work branch with git checkout -b work/<name>, and never use git worktree."
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
