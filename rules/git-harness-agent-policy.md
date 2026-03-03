# MANDATORY Git Harness Agent Policy

This policy is mandatory and must be enforced by the agent.

## Protected Branch Policy

Protected branches include: `main`, `master`, `v1-stable`.

- If current branch is protected, treat repository as read-only.
- Do not modify files, stage changes, or commit on protected branches.
- Ask the user to create/switch to a working branch before any edit.

## Working Branch Policy

- Create a working branch with: `git checkout -b work/<name>`
- All AI changes must happen on a working branch.
- Keep changes minimal, scoped, and reviewable.

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
