#!/bin/bash
# Continuous Learning v2.1 - Project Detection Helper (Memory Split)
#
# Global scope storage:   .claude/GlobalMemory
# Project scope storage:  <project_root>/ProjectMemory/<project-id>

_CLV2_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLV2_CLAUDE_ROOT="$(cd "${_CLV2_SCRIPT_DIR}/.." && pwd)"
_CLV2_GLOBAL_MEMORY_DIR="${_CLV2_CLAUDE_ROOT}/GlobalMemory"
_CLV2_REGISTRY_FILE="${_CLV2_GLOBAL_MEMORY_DIR}/projects.json"

# Windows-safe python detection: test actual execution
_CLV2_PYTHON="python"
if python3 -c "import sys" >/dev/null 2>&1; then
  _CLV2_PYTHON="python3"
elif python -c "import sys" >/dev/null 2>&1; then
  _CLV2_PYTHON="python"
fi

_clv2_detect_project() {
  local project_root=""
  local project_name=""
  local project_id=""
  local remote_url=""

  if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
    project_root="$CLAUDE_PROJECT_DIR"
  fi

  if [ -z "$project_root" ] && command -v git >/dev/null 2>&1; then
    project_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  fi

  # If we accidentally detected the .claude submodule itself, move to host project root
  if [ -n "$project_root" ] && [ "$(basename "$project_root")" = ".claude" ]; then
    project_root="$(cd "$project_root/.." && pwd)"
  fi

  # Non-git fallback -> global scope
  if [ -z "$project_root" ]; then
    _CLV2_PROJECT_ID="global"
    _CLV2_PROJECT_NAME="global"
    _CLV2_PROJECT_ROOT=""
    _CLV2_PROJECT_DIR="${_CLV2_GLOBAL_MEMORY_DIR}"
    mkdir -p "${_CLV2_GLOBAL_MEMORY_DIR}/instincts/personal" "${_CLV2_GLOBAL_MEMORY_DIR}/instincts/inherited" \
      "${_CLV2_GLOBAL_MEMORY_DIR}/evolved/skills" "${_CLV2_GLOBAL_MEMORY_DIR}/evolved/commands" "${_CLV2_GLOBAL_MEMORY_DIR}/evolved/agents"
    return 0
  fi

  project_name="$(basename "$project_root")"

  if command -v git >/dev/null 2>&1; then
    remote_url=$(git -C "$project_root" remote get-url origin 2>/dev/null || true)
  fi

  local hash_input="${remote_url:-$project_root}"
  project_id=$(printf '%s' "$hash_input" | $_CLV2_PYTHON -c "import sys,hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:12])" 2>/dev/null)

  if [ -z "$project_id" ]; then
    project_id=$(printf '%s' "$hash_input" | sha256sum 2>/dev/null | cut -c1-12 || echo "fallback")
  fi

  _CLV2_PROJECT_ID="$project_id"
  _CLV2_PROJECT_NAME="$project_name"
  _CLV2_PROJECT_ROOT="$project_root"
  _CLV2_PROJECT_DIR="${project_root}/ProjectMemory/${project_id}"

  mkdir -p "${_CLV2_PROJECT_DIR}/instincts/personal"
  mkdir -p "${_CLV2_PROJECT_DIR}/instincts/inherited"
  mkdir -p "${_CLV2_PROJECT_DIR}/observations.archive"
  mkdir -p "${_CLV2_PROJECT_DIR}/evolved/skills"
  mkdir -p "${_CLV2_PROJECT_DIR}/evolved/commands"
  mkdir -p "${_CLV2_PROJECT_DIR}/evolved/agents"

  mkdir -p "$(dirname "$_CLV2_REGISTRY_FILE")"

  _CLV2_REG_PID="$project_id" \
  _CLV2_REG_PNAME="$project_name" \
  _CLV2_REG_PROOT="$project_root" \
  _CLV2_REG_PREMOTE="$remote_url" \
  _CLV2_REG_FILE="$_CLV2_REGISTRY_FILE" \
  $_CLV2_PYTHON -c '
import json, os
from datetime import datetime, timezone
registry_path = os.environ["_CLV2_REG_FILE"]
try:
    with open(registry_path) as f:
        registry = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    registry = {}
registry[os.environ["_CLV2_REG_PID"]] = {
    "name": os.environ["_CLV2_REG_PNAME"],
    "root": os.environ["_CLV2_REG_PROOT"],
    "remote": os.environ["_CLV2_REG_PREMOTE"],
    "last_seen": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
}
with open(registry_path, "w") as f:
    json.dump(registry, f, indent=2)
' 2>/dev/null || true
}

_clv2_detect_project

PROJECT_ID="$_CLV2_PROJECT_ID"
PROJECT_NAME="$_CLV2_PROJECT_NAME"
PROJECT_ROOT="$_CLV2_PROJECT_ROOT"
PROJECT_DIR="$_CLV2_PROJECT_DIR"
GLOBAL_MEMORY_DIR="$_CLV2_GLOBAL_MEMORY_DIR"
REGISTRY_FILE="$_CLV2_REGISTRY_FILE"
PYTHON_CMD="$_CLV2_PYTHON"
