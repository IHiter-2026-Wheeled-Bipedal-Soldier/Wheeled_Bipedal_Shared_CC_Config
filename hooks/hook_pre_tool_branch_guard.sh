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

__IsMutatingTool() {
  case "$1" in
    # Claude Code tool names
    Edit|Write|MultiEdit|NotebookEdit|Agent)
      return 0
      ;;
    # VS Code / GitHub Copilot tool names that can mutate workspace or git state
    apply_patch|create_file|create_directory|create_new_jupyter_notebook|edit_notebook_file|vscode_renameSymbol)
      return 0
      ;;
    run_in_terminal|run_task|create_and_run_task|kill_terminal)
      return 0
      ;;
    mcp_pylance_mcp_s_pylanceInvokeRefactoring|mcp_pylance_mcp_s_pylanceUpdatePythonEnvironment|install_python_packages)
      return 0
      ;;
    memory)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

__IsTerminalTool() {
  case "$1" in
    Bash|run_in_terminal)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
case "$CURRENT_BRANCH" in
  main)
    ;;
  *)
    exit 0
    ;;
esac

if __IsMutatingTool "$TOOL_NAME" && ! __IsTerminalTool "$TOOL_NAME"; then
  echo "Protected branch '$CURRENT_BRANCH': blocked tool '$TOOL_NAME'. Use AskUserQuestion first, then create/switch branch." >&2
  exit 2
fi

if __IsTerminalTool "$TOOL_NAME"; then
  case "$TOOL_COMMAND" in
    git\ branch\ --show-current*|git\ branch\ --list*|git\ status*|git\ rev-parse*|git\ fetch*)
      exit 0
      ;;
    git\ checkout\ -b\ dev/*|git\ switch\ -c\ dev/*|git\ checkout\ dev/*|git\ switch\ dev/*)
      exit 0
      ;;
    *)
      echo "Protected branch '$CURRENT_BRANCH': blocked Bash command. Allowed now: branch read commands, fetch, and branch transition (dev/*)." >&2
      exit 2
      ;;
  esac
fi

exit 0
