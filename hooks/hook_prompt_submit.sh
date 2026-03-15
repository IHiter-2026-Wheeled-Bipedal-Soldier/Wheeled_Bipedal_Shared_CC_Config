#!/bin/bash
set -e

# Hook role:
# - inject runtime branch policy context for the assistant
# - trigger CPST- prefixed auto-checkpoint commit when worktree is dirty
# - commit suffix is produced outside this hook (skill/env/file), this hook handles prefix event only

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
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  PROJECT_DIR="$CLAUDE_PROJECT_DIR"
fi

# Auto checkpoint commit for UserPromptSubmit (CPST- prefix).
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit.py"
if [ -f "$AUTO_COMMIT_SCRIPT" ]; then
  export HOOK_EVENT_TYPE=prompt_submit
  printf '%s' "$PAYLOAD" | "$PYTHON_CMD" "$AUTO_COMMIT_SCRIPT" >/dev/null 2>&1 || true
fi

POLICY_FILE_PRIMARY="$CONFIG_DIR/rules/git-harness-agent-policy.md"
POLICY_FILE_FALLBACK="$PROJECT_DIR/rules/git-harness-agent-policy.md"

if [ -f "$POLICY_FILE_PRIMARY" ]; then
  ADDITIONAL_CONTEXT="$(cat "$POLICY_FILE_PRIMARY")"
elif [ -f "$POLICY_FILE_FALLBACK" ]; then
  ADDITIONAL_CONTEXT="$(cat "$POLICY_FILE_FALLBACK")"
else
  ADDITIONAL_CONTEXT="MANDATORY: Enforce protected-branch read-only mode, guide user to create/switch to dev branch with git checkout -b dev/<name>, and never use git worktree."
fi

CURRENT_BRANCH="unknown"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

PROTECTED_HINT="NO"
ASK_HINT="No forced branch-choice required."

DEV_BRANCH_OPTIONS=""
DEV_BRANCH_COUNT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r BRANCH_NAME; do
    [ -z "$BRANCH_NAME" ] && continue
    DEV_BRANCH_COUNT=$((DEV_BRANCH_COUNT + 1))
    DEV_BRANCH_OPTIONS="$DEV_BRANCH_OPTIONS
  ${DEV_BRANCH_COUNT}) Switch to existing branch ${BRANCH_NAME}"
  done <<EOF
$(git for-each-ref --format='%(refname:short)' "refs/heads/dev/*" 2>/dev/null)
EOF
fi

if [ -z "$DEV_BRANCH_OPTIONS" ]; then
  DEV_BRANCH_OPTIONS="
  (No local dev/* branch found)"
fi

case "$CURRENT_BRANCH" in
  main)
    PROTECTED_HINT="YES"
    ASK_HINT="MANDATORY FIRST RESPONSE: Call AskUserQuestion immediately with options:${DEV_BRANCH_OPTIONS}
  $((DEV_BRANCH_COUNT + 1))) Create a new dev branch
  $((DEV_BRANCH_COUNT + 2))) If creating a new dev branch, ask user to input branch name below (format: dev/<name>).
Do not run any mutating tool before this question is answered."
    ;;
esac

ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT

---
RUNTIME BRANCH CONTEXT (MANDATORY)
- Current git branch: $CURRENT_BRANCH
- Protected branch detected: $PROTECTED_HINT
- $ASK_HINT
- Collaboration model: one developer owns one dev branch; merge manually to main after on-robot validation.
- Pull Request workflow is not required in this repository.
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
