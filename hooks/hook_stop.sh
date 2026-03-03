#!/bin/bash
set -e

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

# Check if inside a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

# Set environment variables for auto-commit.py
export HOOK_TRIGGERED=true
export HOOK_EVENT_TYPE=stop

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.py"

# Execute auto-commit with Python
if [ -f "$AUTO_COMMIT_SCRIPT" ]; then
  "$PYTHON_CMD" "$AUTO_COMMIT_SCRIPT" 2>/dev/null || true
fi

exit 0
