---
name: sync-submodules
description: 'Update Git submodules (.claude/ config and .claude/memory/). Use when user says "/sync-submodules", "update submodules", or wants to pull the latest shared Claude config or cross-project memory. Asks whether to fetch remote latest (--remote) or just initialize missing submodules (--init).'
allowed-tools: Bash(git *)
---

# Sync Git Submodules

## Context (auto-loaded)

- Current submodule status: !`git submodule status 2>/dev/null || echo "No submodules configured"`

## Step 1: Ask User Intent

Use AskUserQuestion:

"What would you like to do with submodules?"

- (a) **Pull latest from remote** — fetch newest commits from each submodule's remote repo (e.g., new memory entries, updated skills)
- (b) **Initialize only** — initialize and checkout submodules at the commit pinned by this repo (no remote fetch)
- (c) **Reinitialize all** — deinit and reinit from scratch (use when submodule paths are broken)

## Step 2: Execute

### Option (a) — Pull latest remote

```bash
git submodule update --init --recursive --remote
```

This fetches each submodule's latest commit from its configured remote branch.

### Option (b) — Initialize only

```bash
git submodule update --init --recursive
```

This checks out the exact commit pinned in the parent repo's `.gitmodules`.

### Option (c) — Reinitialize all

```bash
git submodule deinit --all -f
git submodule update --init --recursive
```

## Step 3: Report

After completion, run:

```bash
git submodule status
```

Report to user:

- Which submodules were updated
- Their new HEAD commits
- Any errors encountered

If submodule paths don't exist yet (before first submodule setup), inform user:
"No submodules are configured yet. Add them with `git submodule add <url> <path>` or set up `.gitmodules` first."
