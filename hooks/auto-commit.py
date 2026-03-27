#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Auto checkpoint commit helper for hook-triggered commits.

Responsibilities:
- Inject CPST-/CPED- prefix based on hook event.
- Compose final commit message as: <prefix><suffix>.
- Generate Chinese Conventional Commit suffix from staged git diff.
- Persist session-level state to avoid repeated no-git prompts.
"""

from __future__ import annotations

import io
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


# Mapping from hook event name to checkpoint prefix.
PREFIX_MAP = {
    "prompt_submit": "CPST-",
    "stop": "CPED-",
}

# Session state file name stored at repository/project root.
STATE_FILE_NAME = "git-session-state.json"

# Optional bridge file path for externally generated suffix.
DEFAULT_SUFFIX_FILE = ".claude/commit_suffix.txt"

# Regex to validate Conventional Commit style suffix.
CONVENTIONAL_RE = re.compile(r"^[a-z]+(\([^)]+\))?!?:\s+.+")

# Trigger tokens to help deterministic no-git decision parsing.
TOKEN_INIT_GIT = "INIT_GIT_NOW"
TOKEN_SKIP_GIT = "SKIP_GIT_THIS_SESSION"


def _now_iso() -> str:
    """! @brief Generate current UTC timestamp in ISO-8601 format.
    @return UTC timestamp string with trailing Z.
    """
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _default_state(session_marker: str = "") -> dict:
    """! @brief Build default session state object.
    @param session_marker Optional marker extracted from hook payload.
    @return Default state dictionary used when state file is missing/invalid.
    """
    return {
        "session_marker": session_marker,
        "git_init_prompted": False,
        "git_init_decision": "",
        "start_commit_done": False,
        "updated_at": _now_iso(),
    }


def run_git(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    """! @brief Execute a git command and capture text output.
    @param args Git command arguments without leading 'git'.
    @param cwd Optional working directory for command execution.
    @return CompletedProcess with return code, stdout, and stderr.
    """
    return subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        check=False,
        cwd=str(cwd) if cwd else None,
    )


def git_ok(args: list[str], cwd: Path | None = None) -> bool:
    """! @brief Check whether a git command completes successfully.
    @param args Git command arguments without leading 'git'.
    @param cwd Optional working directory for command execution.
    @return True when command exit code is zero.
    """
    return run_git(args, cwd=cwd).returncode == 0


def project_root() -> Path:
    """! @brief Resolve project root path for hook runtime.
    @return Project directory resolved from env or script location.
    """
    env_dir = os.environ.get("CLAUDE_PROJECT_DIR", "").strip()
    if env_dir:
        p = Path(env_dir)
        if p.exists():
            return p
    return Path(__file__).resolve().parent.parent


def repo_root(base_dir: Path) -> Path | None:
    """! @brief Resolve git repository root from a base directory.
    @param base_dir Working directory where git checks should run.
    @return Repository root path if git is initialized; otherwise None.
    """
    cp = run_git(["rev-parse", "--show-toplevel"], cwd=base_dir)
    if cp.returncode != 0:
        return None
    return Path(cp.stdout.strip())


def has_changes(base_dir: Path) -> bool:
    """! @brief Determine whether repository contains unstaged/staged changes.
    @param base_dir Repository root directory.
    @return True when worktree has any pending change.
    """
    cp = run_git(["status", "--porcelain"], cwd=base_dir)
    return cp.returncode == 0 and bool(cp.stdout.strip())


def state_file_path(base_dir: Path) -> Path:
    """! @brief Build absolute path to session state file.
    @param base_dir Project root directory used as state storage base.
    @return Path to git-session-state.json.
    """
    return base_dir / STATE_FILE_NAME


def load_state(base_dir: Path) -> dict:
    """! @brief Load session state from JSON file.
    @param base_dir Project root directory.
    @return State object; returns defaults if file does not exist or parse fails.
    """
    path = state_file_path(base_dir)
    if not path.exists():
        return _default_state()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return _default_state()


def save_state(base_dir: Path, state: dict) -> None:
    """! @brief Persist session state to JSON file.
    @param base_dir Project root directory.
    @param state State dictionary to write.
    @return None.
    """
    path = state_file_path(base_dir)
    state["updated_at"] = _now_iso()
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def normalize_text(value: str, max_len: int = 24) -> str:
    """! @brief Normalize whitespace and trim text to target length.
    @param value Raw input text.
    @param max_len Maximum output length in characters.
    @return Cleaned and truncated text.
    """
    cleaned = " ".join(value.replace("\r", " ").replace("\n", " ").split())
    return cleaned[:max_len]


def read_payload() -> dict:
    """! @brief Parse hook payload JSON from stdin.
    @return Parsed payload dictionary, or empty dict on parse failure.
    """
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


def read_session_marker(payload: dict) -> str:
    """! @brief Extract a stable session marker from payload when available.
    @param payload Hook payload dictionary.
    @return Session marker string or empty string when unavailable.
    """
    keys = ("session_id", "sessionId", "conversation_id", "conversationId")
    for key in keys:
        value = payload.get(key, "")
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def reset_session_state(base_dir: Path, payload: dict) -> None:
    """! @brief Reset per-session state at session start.
    @param base_dir Project root directory.
    @param payload SessionStart hook payload.
    @return None.
    """
    session_marker = read_session_marker(payload)
    state = _default_state(session_marker=session_marker)
    save_state(base_dir, state)


def load_suffix_from_file(root: Path) -> str:
    """! @brief Load commit suffix override from configured file.
    @param root Repository root directory.
    @return Suffix text when file exists and is readable; otherwise empty string.
    """
    suffix_file = os.environ.get("COMMIT_SUFFIX_FILE", DEFAULT_SUFFIX_FILE)
    path = root / suffix_file
    if not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def normalize_suffix(raw_suffix: str) -> str:
    """! @brief Normalize and validate Conventional Commit suffix.
    @param raw_suffix Raw suffix text.
    @return Conventional-style suffix (adds chore: when type is missing).
    """
    suffix = normalize_text(raw_suffix, max_len=120)
    if not suffix:
        return ""
    if CONVENTIONAL_RE.match(suffix):
        return suffix
    return f"chore: {suffix}"


def parse_name_status(root: Path) -> tuple[list[tuple[str, str]], dict[str, int]]:
    """! @brief Parse staged file status for summary generation.
    @param root Repository root directory.
    @return Tuple of (status-file pairs, status counters).
    """
    cp = run_git(["diff", "--cached", "--name-status"], cwd=root)
    items: list[tuple[str, str]] = []
    counters = {"A": 0, "M": 0, "D": 0, "R": 0}
    if cp.returncode != 0:
        return items, counters

    for raw_line in cp.stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split("\t")
        status_raw = parts[0] if parts else ""
        status = status_raw[:1] if status_raw else ""
        path = parts[-1] if len(parts) >= 2 else ""
        if status in counters:
            counters[status] += 1
        items.append((status, path))
    return items, counters


def detect_commit_type(files: list[str], counters: dict[str, int]) -> str:
    """! @brief Detect Conventional Commit type from changed files.
    @param files Changed file path list.
    @param counters Added/modified/deleted/renamed counters.
    @return Commit type string.
    """
    if files and all(path.endswith(".md") for path in files):
        return "docs"
    if counters["A"] > 0 and counters["M"] == 0 and counters["D"] == 0 and counters["R"] == 0:
        return "add"
    if counters["D"] > 0 and counters["A"] == 0 and counters["M"] == 0 and counters["R"] == 0:
        return "del"
    return "chore"


def build_topic_phrase(files: list[str]) -> str:
    """! @brief Build short Chinese topic phrase from changed paths.
    @param files Changed file path list.
    @return Topic phrase used in commit summary.
    """
    # Tag list records detected change domains used for concise Chinese summary.
    tags: list[str] = []
    if any(path.startswith("hooks/") for path in files):
        tags.append("hooks自动提交流程")
    if any(path == "settings.json" for path in files):
        tags.append("hooks配置")
    if any(path.startswith("rules/") or path.startswith("Resources/") for path in files):
        tags.append("规则文档")
    if any(path.startswith("skills/") for path in files):
        tags.append("技能说明")

    if not tags:
        return "项目文件"
    if len(tags) == 1:
        return tags[0]
    return f"{tags[0]}与{tags[1]}"


def generate_suffix_from_staged_diff(root: Path) -> str:
    """! @brief Generate Chinese Conventional Commit suffix from staged diff.
    @param root Repository root directory.
    @return Suffix string like 'chore: 更新xxx（新增1修改2删除0）'.
    """
    # Phase 1: collect staged status and counters.
    status_items, counters = parse_name_status(root)
    files = [path for _, path in status_items if path]

    # Phase 2: detect commit type and topic phrase.
    commit_type = detect_commit_type(files, counters)
    topic_phrase = build_topic_phrase(files)

    # Phase 3: compose compact Chinese summary with change counters.
    summary = (
        f"更新{topic_phrase}"
        f"（新增{counters['A']}修改{counters['M']}删除{counters['D']}重命名{counters['R']}）"
    )
    return normalize_suffix(f"{commit_type}: {summary}")


def build_suffix(root: Path) -> str:
    """! @brief Build commit suffix with override priority then auto generation.
    @param root Repository root directory.
    @return Final Conventional Commit suffix.
    """
    env_suffix = os.environ.get("COMMIT_SUFFIX", "").strip()
    if env_suffix:
        return normalize_suffix(env_suffix)

    file_suffix = load_suffix_from_file(root)
    if file_suffix:
        return normalize_suffix(file_suffix)

    return generate_suffix_from_staged_diff(root)


def stage_all_changes(root: Path) -> bool:
    """! @brief Stage all repository changes for checkpoint commit.
    @param root Repository root directory.
    @return True when staging succeeds and staged content exists.
    """
    if not git_ok(["add", "-A"], cwd=root):
        return False
    return not git_ok(["diff", "--cached", "--quiet"], cwd=root)


def commit_with_prefix(prefix: str, root: Path) -> bool:
    """! @brief Create checkpoint commit with provided CP prefix.
    @param prefix Prefix string such as CPST- or CPED-.
    @param root Repository root directory.
    @return True when commit command succeeds.
    """
    if not has_changes(root):
        return False
    if not stage_all_changes(root):
        return False

    suffix = build_suffix(root)
    if not suffix:
        return False

    message = f"{prefix}{suffix}"
    if os.environ.get("DRY_RUN", "").strip() == "1":
        print(message)
        return True
    return git_ok(["commit", "-m", message], cwd=root)


def detect_git_init_choice_from_prompt(prompt: str) -> str:
    """! @brief Detect explicit git-init choice token from user prompt.
    @param prompt User prompt text from UserPromptSubmit payload.
    @return 'init', 'skip', or empty string.
    """
    normalized = prompt.upper()
    if TOKEN_INIT_GIT in normalized:
        return "init"
    if TOKEN_SKIP_GIT in normalized:
        return "skip"
    return ""


def build_no_git_context() -> str:
    """! @brief Build minimal context instructing AskUserQuestion for git init.
    @return Minimal policy context string used by UserPromptSubmit hook.
    """
    return (
        "MANDATORY: Current workspace is not a git repository. "
        "Before any file/tool mutation, call AskUserQuestion exactly once with options: "
        "(1) INIT_GIT_NOW - initialize git now, "
        "(2) SKIP_GIT_THIS_SESSION - continue without git for this session. "
        "If user chooses option 1, run 'git init' in current repository, then continue. "
        "If user chooses option 2, continue and do not ask git-init again in this session."
    )


def handle_prompt_submit(payload: dict, base_dir: Path) -> dict:
    """! @brief Process UserPromptSubmit event for CPST and no-git ask-once flow.
    @param payload Hook payload dictionary.
    @param base_dir Project root directory.
    @return Response dict for hook additionalContext injection.
    """
    state = load_state(base_dir)

    # Refresh state when a new session marker is observed.
    session_marker = read_session_marker(payload)
    existing_marker = str(state.get("session_marker", ""))
    if session_marker and session_marker != existing_marker:
        state = _default_state(session_marker=session_marker)

    prompt_text = payload.get("prompt", "")
    prompt_text = prompt_text if isinstance(prompt_text, str) else ""
    root = repo_root(base_dir)
    user_choice = detect_git_init_choice_from_prompt(prompt_text)

    # Optional deterministic decision handling for AskUserQuestion option tokens.
    if root is None and user_choice == "init":
        if git_ok(["init"], cwd=base_dir):
            state["git_init_decision"] = "init"
            state["git_init_prompted"] = True
            root = repo_root(base_dir)

    if root is None and user_choice == "skip":
        state["git_init_decision"] = "skip"
        state["git_init_prompted"] = True

    if root is None:
        should_ask = not bool(state.get("git_init_prompted", False))
        if should_ask:
            state["git_init_prompted"] = True
            save_state(base_dir, state)
            return {"ask_git_init": True, "additional_context": build_no_git_context()}
        save_state(base_dir, state)
        return {"ask_git_init": False, "additional_context": ""}

    # Repository exists: execute CPST only once for this session.
    if bool(state.get("start_commit_done", False)):
        save_state(base_dir, state)
        return {"ask_git_init": False, "additional_context": ""}

    prefix = PREFIX_MAP.get("prompt_submit", "CPST-")
    commit_with_prefix(prefix, root)
    state["start_commit_done"] = True
    if not state.get("git_init_decision"):
        state["git_init_decision"] = "init"
    save_state(base_dir, state)
    return {"ask_git_init": False, "additional_context": ""}


def handle_stop(base_dir: Path) -> None:
    """! @brief Process Stop event for CPED checkpoint commit.
    @param base_dir Project root directory.
    @return None.
    """
    root = repo_root(base_dir)
    if root is None:
        return
    prefix = PREFIX_MAP.get("stop", "CPED-")
    commit_with_prefix(prefix, root)


def main() -> int:
    """! @brief Entry point for hook-triggered auto-commit handling.
    @return Process exit code.
    """
    event_type = os.environ.get("HOOK_EVENT_TYPE", "").strip().lower()
    base_dir = project_root()
    payload = read_payload()

    if event_type == "session_start":
        reset_session_state(base_dir, payload)
        return 0

    if event_type == "prompt_submit":
        result = handle_prompt_submit(payload, base_dir)
        if result:
            print(json.dumps(result, ensure_ascii=False))
        return 0

    if event_type == "stop":
        handle_stop(base_dir)
        return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
