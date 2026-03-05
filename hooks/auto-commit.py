#!/usr/bin/env python3
"""Auto checkpoint commit helper for hook-triggered commits.

Responsibilities:
- Inject CPST-/CPED-/TASK- prefix based on hook event.
- Compose final commit message as: <prefix><suffix>.
- Suffix can come from hook-provided env/file, with safe fallback.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


PREFIX_MAP = {
    "prompt_submit": "CPST-",
    "stop": "CPED-",
    "task_complete": "TASK-",
}

FIELD_MAP = {
    "prompt_submit": "prompt",
    "stop": "last_assistant_message",
    "task_complete": "task_subject",
}

CONVENTIONAL_RE = re.compile(r"^[a-z]+(\([^)]+\))?!?:\s+.+")


def run_git(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], capture_output=True, text=True, check=False)


def git_ok(args: list[str]) -> bool:
    return run_git(args).returncode == 0


def repo_root() -> Path | None:
    cp = run_git(["rev-parse", "--show-toplevel"])
    if cp.returncode != 0:
        return None
    return Path(cp.stdout.strip())


def has_changes() -> bool:
    cp = run_git(["status", "--porcelain"])
    return cp.returncode == 0 and bool(cp.stdout.strip())


def current_branch() -> str:
    cp = run_git(["rev-parse", "--abbrev-ref", "HEAD"])
    if cp.returncode != 0:
        return ""
    return cp.stdout.strip()


def is_protected_branch(branch: str) -> bool:
    return branch == "main" or branch.startswith("release/")


def normalize_text(value: str, max_len: int = 24) -> str:
    cleaned = " ".join(value.replace("\r", " ").replace("\n", " ").split())
    return cleaned[:max_len]


def read_payload() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return {}


def load_suffix_from_file(root: Path) -> str:
    # Optional bridge: skill can write suffix to this file.
    suffix_file = os.environ.get("COMMIT_SUFFIX_FILE", ".claude/commit_suffix.txt")
    path = root / suffix_file
    if not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def normalize_suffix(raw_suffix: str) -> str:
    suffix = normalize_text(raw_suffix, max_len=120)
    if not suffix:
        return ""
    if CONVENTIONAL_RE.match(suffix):
        return suffix
    return f"chore: {suffix}"


def build_suffix(event_type: str, payload: dict, root: Path) -> str:
    env_suffix = os.environ.get("COMMIT_SUFFIX", "").strip()
    if env_suffix:
        return normalize_suffix(env_suffix)

    file_suffix = load_suffix_from_file(root)
    if file_suffix:
        return normalize_suffix(file_suffix)

    key = FIELD_MAP.get(event_type, "")
    source = payload.get(key, "") if key else ""
    source = source if isinstance(source, str) else ""
    snippet = normalize_text(source, max_len=24)
    if snippet:
        return f"chore: checkpoint {snippet}"
    return "chore: checkpoint"


def main() -> int:
    event_type = os.environ.get("HOOK_EVENT_TYPE", "").strip().lower()
    prefix = PREFIX_MAP.get(event_type, "")
    if not prefix:
        return 0

    root = repo_root()
    if root is None:
        return 0

    branch = current_branch()
    if is_protected_branch(branch):
        return 0

    if not has_changes():
        return 0

    payload = read_payload()
    suffix = build_suffix(event_type, payload, root)
    if not suffix:
        return 0

    message = f"{prefix}{suffix}"

    if git_ok(["add", "-A"]) is False:
        return 0

    if git_ok(["diff", "--cached", "--quiet"]):
        return 0

    if os.environ.get("DRY_RUN", "").strip() == "1":
        print(message)
        return 0

    run_git(["commit", "-m", message])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
