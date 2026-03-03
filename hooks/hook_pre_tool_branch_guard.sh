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
TOOL_NAME="$(echo "$PAYLOAD" | "$PYTHON_CMD" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_name", ""))' 2>/dev/null || echo "")"

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
case "$CURRENT_BRANCH" in
  main|master|v1-stable)
    ;;
  *)
    exit 0
    ;;
esac

case "$TOOL_NAME" in
  Edit|Write|MultiEdit|NotebookEdit|Bash|Agent)
    echo "Protected branch '$CURRENT_BRANCH': blocked tool '$TOOL_NAME'. Create/switch to a work branch first (git checkout -b work/<name>)." >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
