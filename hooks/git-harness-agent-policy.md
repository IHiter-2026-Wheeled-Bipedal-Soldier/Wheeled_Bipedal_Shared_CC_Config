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

## Hard Constraints

- NEVER use `git worktree` in this repository workflow.
- Do not bypass branch protection with direct commits to protected branches.
- If branch context is ambiguous, ask the user and pause edits.
