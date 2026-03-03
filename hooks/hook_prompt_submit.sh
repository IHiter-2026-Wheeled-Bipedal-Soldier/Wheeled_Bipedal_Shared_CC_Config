#!/bin/bash
set -e

unset GIT_DIR
unset GIT_WORK_TREE
unset GIT_COMMON_DIR
unset GIT_INDEX_FILE
unset GIT_OBJECT_DIRECTORY

# Windows compatibility: test actual execution, not just path existence
# (Windows has a broken python3.exe stub in WindowsApps)
if python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif python -c "import sys" >/dev/null 2>&1; then
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
POLICY_FILE="$PROJECT_DIR/.claude/hooks/git-harness-agent-policy.md"

# Set environment variables for auto-commit.py
export HOOK_TRIGGERED=true
export HOOK_EVENT_TYPE=prompt_submit

# Execute auto-commit if we're in a git repository
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.py"
  if [ -f "$AUTO_COMMIT_SCRIPT" ]; then
    "$PYTHON_CMD" "$AUTO_COMMIT_SCRIPT" 2>/dev/null || true
  fi
fi

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
