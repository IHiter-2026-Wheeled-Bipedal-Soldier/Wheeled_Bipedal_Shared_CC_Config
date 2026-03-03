# MANDATORY Git Harness Agent Policy

This policy is mandatory and must be enforced by the agent.

## Protected Branch Policy

Protected branches include: `main`, `release/*`.

- If current branch is protected, treat repository as read-only until branch transition is completed.
- Do not modify files, stage changes, or commit on protected branches.
- Before any mutating tool call, MUST trigger AskUserQuestion immediately.

### Mandatory First-Response AskUserQuestion Protocol

- On `main`: ask user to choose one option immediately:
  1) Create `release/<name>` branch
  2) Create `work/<name>` branch
- On `release/*`: ask user to choose one option immediately:
  1) Create `work/<name>` branch
  2) Keep read-only and stop mutation
- The first assistant response under protected branch context MUST be this AskUserQuestion flow.
- Any editing/commit/push actions are forbidden before the branch-choice question is answered.

## Working Branch Policy

- Create a working branch with: `git checkout -b work/<name>`
- All AI changes must happen on a working branch.
- Keep changes minimal, scoped, and reviewable.

## Push-PR Two-Stage Policy (Mandatory)

- `/push-pr` must run as a two-stage protocol:
  - Stage 1: local merge check and conflict guidance (or guided manual merge steps), then stop.
  - Stage 2: user reruns `/push-pr` after review/resolve, then push + create/update PR.
- If `/push-pr` starts on protected branch (`main` or `release/*`):
  - Automatically create and switch to `push-pr/<name>` sub-branch.
  - Default PR base branch MUST be the original protected branch.
- If `/push-pr` starts on non-protected branch, use AskUserQuestion to ask what action user wants.

## Git Workflow Skills (Allowlist)

The following skills are authorized to run git operations even while on protected branches,
because they exist specifically to manage branch transitions and synchronization:

- `push-pr`: pushes current branch and creates/updates PR — always creates a sub-branch if on protected branch
- `sync-latest`: fetches and merges/rebases main, updates submodules
- `sync-submodules`: runs `git submodule update --init --recursive [--remote]`
- `git-archive`: creates `release/*` branch and worktree from current HEAD
- `clean-gone`: deletes local branches marked [gone]
- `commit`: commits staged/unstaged changes on a work branch

These skills use explicit `git` commands and do NOT modify source files directly.

## Hard Constraints

- NEVER use `git worktree` outside of the `git-archive` skill.
- Do not bypass branch protection with direct commits to protected branches.
- If branch context is ambiguous, ask the user and pause edits.
