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
PLAN_SHA_FILE="$PROJECT_DIR/.claude/plan-git-SHA.json"

TASK_SUBJECT="$(echo "$PAYLOAD" | "$PYTHON_CMD" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("task_subject", ""))' 2>/dev/null || echo "")"
TASK_PREFIX="$(printf '%s' "$TASK_SUBJECT" | "$PYTHON_CMD" -c 'import sys; s=sys.stdin.read().replace("\n"," ").replace("\r"," ").strip(); print(s[:10])')"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        git add -A >/dev/null 2>&1 || true
        git commit -m "TASK:${TASK_PREFIX}" >/dev/null 2>&1 || true
    fi
fi

CURRENT_BRANCH=""
HEAD_SHA=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || echo "")"
fi
NOW_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

export PLAN_SHA_FILE CURRENT_BRANCH HEAD_SHA NOW_ISO TASK_SUBJECT PYTHON_CMD
"$PYTHON_CMD" - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ.get("PLAN_SHA_FILE", ""))
branch = os.environ.get("CURRENT_BRANCH", "")
head_sha = os.environ.get("HEAD_SHA", "")
now_iso = os.environ.get("NOW_ISO", "")
task_subject = os.environ.get("TASK_SUBJECT", "")

if not path.parent.exists():
    path.parent.mkdir(parents=True, exist_ok=True)

if path.exists():
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        data = {"git_branch": branch, "plans": []}
else:
    data = {"git_branch": branch, "plans": []}

data["git_branch"] = branch
plans = data.get("plans", [])

def norm_status(value: str) -> str:
    s = (value or "").strip().lower().replace("-", "_").replace(" ", "_")
    if s in {"completed", "done"}:
        return "completed"
    if s in {"in_progress", "inprogress", "processing"}:
        return "in_progress"
    if s in {"pending", "not_started", "todo"}:
        return "pending"
    return s or "pending"

def norm_task_status(value: str) -> str:
    s = (value or "").strip().lower().replace("-", "_").replace(" ", "_")
    if s == "completed":
        return "completed"
    return "pending"

in_progress = [
    p for p in plans
    if norm_status(p.get("metadata", {}).get("status", "in_progress")) == "in_progress"
]
if not in_progress:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    raise SystemExit(0)

plan = in_progress[-1]
tasks = plan.get("tasks", {})
matched_key = None
for key, info in tasks.items():
    name = info.get("task_name", "")
    if task_subject and (name == task_subject or key == task_subject):
        matched_key = key
        break

if matched_key is None:
    for key, info in tasks.items():
        if norm_task_status(info.get("status", "pending")) != "completed":
            matched_key = key
            break

if matched_key is not None:
    task_obj = tasks.get(matched_key, {})
    task_obj["status"] = "completed"
    task_obj["completed_at"] = now_iso
    task_obj["head_sha"] = head_sha
    tasks[matched_key] = task_obj

if "git_sha" not in plan:
    plan["git_sha"] = {}
plan["git_sha"]["head_plan_sha"] = head_sha

all_done = True
if not tasks:
    all_done = False
else:
    for info in tasks.values():
        if norm_task_status(info.get("status", "pending")) != "completed":
            all_done = False
            break

if all_done:
    plan.setdefault("metadata", {})["status"] = "completed"

path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
PY

exit 0
