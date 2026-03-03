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
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi

POLICY_FILE_PRIMARY="$CONFIG_DIR/rules/git-harness-agent-policy.md"
POLICY_FILE_FALLBACK="$PROJECT_DIR/.claude/rules/git-harness-agent-policy.md"

if [ -f "$POLICY_FILE_PRIMARY" ]; then
  ADDITIONAL_CONTEXT="$(cat "$POLICY_FILE_PRIMARY")"
elif [ -f "$POLICY_FILE_FALLBACK" ]; then
  ADDITIONAL_CONTEXT="$(cat "$POLICY_FILE_FALLBACK")"
else
  ADDITIONAL_CONTEXT="MANDATORY: Enforce protected-branch read-only mode, guide user to create a work branch with git checkout -b work/<name>, and never use git worktree."
fi

CURRENT_BRANCH="unknown"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

PROTECTED_HINT="NO"
ASK_HINT="No forced branch-choice required."
case "$CURRENT_BRANCH" in
  main)
    PROTECTED_HINT="YES"
    ASK_HINT="MANDATORY FIRST RESPONSE: Call AskUserQuestion immediately with options: (1) Create release/<name> branch (2) Create work/<name> branch. Do not run any mutating tool before this question is answered."
    ;;
  release/*)
    PROTECTED_HINT="YES"
    ASK_HINT="MANDATORY FIRST RESPONSE: Call AskUserQuestion immediately with options: (1) Create work/<name> branch (2) Keep read-only. Do not run any mutating tool before this question is answered."
    ;;
esac

ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT

---
RUNTIME BRANCH CONTEXT (MANDATORY)
- Current git branch: $CURRENT_BRANCH
- Protected branch detected: $PROTECTED_HINT
- $ASK_HINT
- For /push-pr on protected branch: auto-create push-pr/<name> and default PR base to the original protected branch.
"

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
