#!/bin/bash
set -e

# Hook role:
# - trigger CPED- prefixed auto-checkpoint commit when worktree is dirty
# - commit suffix is composed by helper logic; prefix source is this hook event type

unset GIT_DIR
unset GIT_WORK_TREE
unset GIT_COMMON_DIR
unset GIT_INDEX_FILE
unset GIT_OBJECT_DIRECTORY

# Windows compatibility: test actual execution, not just path existence
if python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif python -c "import sys" >/dev/null 2>&1; then
  PYTHON_CMD="python"
else
  exit 0  # Python not available, skip auto-commit
fi

PAYLOAD="$(cat)"

# Set environment variables for auto-commit.py
export HOOK_EVENT_TYPE=stop

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.py"

# Execute auto-commit with Python
if [ -f "$AUTO_COMMIT_SCRIPT" ]; then
  export CLAUDE_PROJECT_DIR="$PROJECT_DIR"
  printf '%s' "$PAYLOAD" | "$PYTHON_CMD" "$AUTO_COMMIT_SCRIPT" 2>/dev/null || true
fi

exit 0
