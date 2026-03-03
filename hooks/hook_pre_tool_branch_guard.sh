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
TOOL_COMMAND="$(echo "$PAYLOAD" | "$PYTHON_CMD" -c 'import json,sys; d=json.load(sys.stdin); ti=d.get("tool_input", {}); cmd=ti.get("command", "") if isinstance(ti, dict) else (ti if isinstance(ti, str) else ""); print(cmd)' 2>/dev/null || echo "")"

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
case "$CURRENT_BRANCH" in
  main|release/*)
    ;;
  *)
    exit 0
    ;;
esac

case "$TOOL_NAME" in
  Edit|Write|MultiEdit|NotebookEdit|Agent)
    echo "Protected branch '$CURRENT_BRANCH': blocked tool '$TOOL_NAME'. Use AskUserQuestion first, then create/switch branch." >&2
    exit 2
    ;;
  Bash)
    case "$TOOL_COMMAND" in
      git\ branch\ --show-current*|git\ status*|git\ rev-parse*|git\ fetch*)
        exit 0
        ;;
      git\ checkout\ -b\ work/*|git\ checkout\ -b\ release/*|git\ checkout\ -b\ push-pr/*|git\ switch\ -c\ work/*|git\ switch\ -c\ release/*|git\ switch\ -c\ push-pr/*|git\ checkout\ work/*|git\ checkout\ release/*|git\ checkout\ push-pr/*|git\ switch\ work/*|git\ switch\ release/*|git\ switch\ push-pr/*)
        exit 0
        ;;
      *)
        echo "Protected branch '$CURRENT_BRANCH': blocked Bash command. Allowed now: branch read commands, fetch, and branch transition (work/release/push-pr)." >&2
        exit 2
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
