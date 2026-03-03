---
name: sync-latest
description: 'Sync local repo with the latest remote main branch and update all submodules. Use when user says "/sync-latest", "pull latest", "sync with main", or after a PR has been merged on GitHub and the user wants to bring their local up to date.'
allowed-tools: Bash(git *)
---

# Sync with Latest Main Branch

## Context (auto-loaded)

- Current branch: !`git branch --show-current`
- Uncommitted changes: !`git status --short`
- Remote fetch preview: !`git fetch --dry-run origin 2>&1 | head -20 || echo "(fetch preview unavailable)"`

## Step 1: Handle Uncommitted Changes

If `git status --short` shows any changes:

Use AskUserQuestion:
"You have uncommitted changes. What would you like to do before syncing?"

- (a) **Stash** them temporarily — they'll be restored after sync
- (b) **Commit** them now — run `/commit` first, then come back to `/sync-latest`
- (c) **Discard** them — WARNING: this is irreversible

If (a): `git stash push -m "stash before sync-latest"`
If (c): confirm with user before running `git checkout -- .`

## Step 2: Fetch Remote

```bash
git fetch origin
```

Show the user what's new:

```bash
git log HEAD..origin/main --oneline
```

If nothing new: inform the user and stop. "Already up to date with origin/main."

## Step 3: Ask Merge Strategy

Use AskUserQuestion:
"How would you like to integrate the latest main changes?"

- (a) **Merge** — keeps full history, creates a merge commit (safer for shared branches)
- (b) **Rebase** — rewrites local commits on top of main (cleaner history, use on personal work branches)

### Option (a) Merge

```bash
git merge origin/main
```

### Option (b) Rebase

```bash
git rebase origin/main
```

If rebase has conflicts, guide the user:

```bash
# After resolving each conflict:
git add <file>
git rebase --continue
# Or abort:
git rebase --abort
```

## Step 4: Update Submodules

```bash
git submodule update --init --recursive
```

## Step 5: Restore Stash (if stashed in Step 1)

```bash
git stash pop
```

## Step 6: Report

Show:

- How many commits pulled from origin/main
- Submodule status after update
- Current branch HEAD
- Any conflicts that need manual resolution
