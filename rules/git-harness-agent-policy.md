# MANDATORY Git Harness Agent Policy

This policy is mandatory and must be enforced by the agent.

## Protected Branch Policy

Protected branches include: `main`.

- If current branch is protected, treat repository as read-only until branch transition is completed.
- Do not modify files, stage changes, or commit on protected branches.
- Before any mutating tool call, MUST trigger AskUserQuestion immediately.

### Mandatory First-Response AskUserQuestion Protocol

- On `main`: ask user to choose one option immediately:
  1) Switch to an existing local `dev/*` branch (enumerate each branch as an option)
  2) Create a new `dev/*` branch
  3) If creating a new branch, ask user to input branch name below (format: `dev/<name>`)
- The first assistant response under protected branch context MUST be this AskUserQuestion flow.
- Any editing/commit/push actions are forbidden before the branch-choice question is answered.

## Dev Branch Policy

- Create a dev branch with: `git checkout -b dev/<name>` or `git switch -c dev/<name>`
- All AI changes must happen on a `dev/*` branch.
- Keep changes minimal, scoped, and reviewable.
- `main` stores only stable code validated on robot.

## Collaboration Model

- One developer owns one `dev/*` branch (branching by owner, not by feature).
- When a new feature depends on another developer's code, manually merge that developer's branch as the base.
- This repository does not require Pull Request workflow for daily collaboration.
- Changes are tracked through git commits and manual merges into `main`.

## Git Workflow Skills (Allowlist)

The following skills are authorized to run git operations even while on protected branches,
because they exist specifically to manage branch transitions and synchronization:

- `commit`: commits staged/unstaged changes on a dev branch

These skills use explicit `git` commands and do NOT modify source files directly.

## Hard Constraints

- Do not bypass branch protection with direct commits to protected branches.
- Do not force PR-based workflow for this repository.
- If branch context is ambiguous, ask the user and pause edits.
