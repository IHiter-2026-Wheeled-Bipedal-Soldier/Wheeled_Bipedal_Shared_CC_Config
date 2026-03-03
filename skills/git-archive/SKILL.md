---
name: git-archive
description: 'Create a release branch and a matching git worktree archive from the current HEAD. Use when user says "/git-archive", "archive this version", "create release snapshot", or wants to save a stable milestone. Must be on main branch. Asks for the release name interactively without breaking the conversation.'
allowed-tools: Bash(git *)
---

# Git Archive — Create a Release Snapshot

## Rules

- Only run from the `main` branch (or the repo's primary protected branch).
- Creates both a `release/<name>` branch AND a matching worktree in a `worktrees/` sibling directory.
- Use AskUserQuestion for the release name — keep conversation continuous, no interruption.
- Do NOT switch away from `main` after creating the release branch.

## Step 1: Verify Branch

Check current branch:

```bash
git branch --show-current
```

If NOT on `main` (or `master`):
Use AskUserQuestion:
"You are currently on `<branch>`, not `main`. `/git-archive` should be run from main to snapshot a stable version. Would you like to:"

- (a) Switch to main first, then archive
- (b) Archive from the current branch anyway
- (c) Cancel

## Step 2: Get Release Name

Use AskUserQuestion (SINGLE question, no follow-up, keep conversation flowing):

"What should this release be named? (This will create `release/<name>` branch and worktree)\nExamples: v1.0, 2026-infantry-final, demo-day-03"

The user's answer becomes `<name>`. Do NOT ask again if the answer looks valid.

## Step 3: Validate Name

- Strip leading/trailing whitespace
- Replace spaces with `-`
- If empty, ask once more: "Please provide a non-empty name."

## Step 4: Create Release Branch

```bash
git checkout -b release/<name>
git push -u origin release/<name>
```

## Step 5: Create Worktree Archive

```bash
# Ensure worktrees directory exists
mkdir -p ../worktrees

# Create the worktree
git worktree add "../worktrees/release-<name>" release/<name>
```

## Step 6: Return to Main

```bash
git checkout main
```

## Step 7: Report

Tell the user:

- Release branch created: `release/<name>`
- Worktree location: `../worktrees/release-<name>/`
- Current HEAD SHA captured
- How to access the archived code:

  ```bash
  cd ../worktrees/release-<name>
  # This is a read-only snapshot of your release
  ```

- Suggest: "You can now continue working on main. The release snapshot is preserved independently."
