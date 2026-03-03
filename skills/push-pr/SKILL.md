---
name: push-pr
description: 'Push current branch to origin and create or update a GitHub PR. Use when user says "/push-pr", "push and open PR", or wants to submit their branch for review. Handles protected-branch detection: if on main/master/v1-stable, creates a sub-branch automatically before pushing. If not on protected branch, asks user what to do via AskUserQuestion.'
allowed-tools: Bash(git *), Bash(gh *)
---

# Push Branch and Open/Update PR

## Context (auto-loaded at start)

- Current branch: !`git branch --show-current`
- Remote tracking status: !`git status -sb`
- Recent commits (not yet on remote): !`git log @{u}..HEAD --oneline 2>/dev/null || git log -5 --oneline`

## Behavior by Branch State

### Case A: Currently on a PROTECTED branch (main / master / v1-stable)

If the user is on a protected branch:

1. Inform the user: "You are on a protected branch. A sub-branch will be created for your PR."
2. Use AskUserQuestion to ask: "What should the PR branch be named? (suggestion: `work/<feature-name>`)"
3. Create the branch:

   ```bash
   git checkout -b <branch-name>
   ```

4. Continue with **push + PR creation** below.
5. The **target branch** (PR base) defaults to the protected branch the user was on.

### Case B: Currently on a WORK branch with uncommitted changes

Use AskUserQuestion with options:

1. "There are uncommitted changes. What would you like to do?"
   - (a) Commit them now (run `/commit` first, then return here)
   - (b) Stash them and continue
   - (c) Push as-is (without these changes)

### Case C: Currently on a WORK branch, clean or committed

Proceed directly to **Merge Check + Push + PR** below.

---

## Merge Check (Before Push)

Before pushing, perform a **local dry-run merge** to detect conflicts:

```bash
# Fetch latest target branch without merging
git fetch origin <target-branch>

# Dry run: check for merge conflicts using merge-tree
git merge-tree $(git merge-base HEAD origin/<target-branch>) HEAD origin/<target-branch>
```

- If **no conflicts** detected: proceed to push.
- If **conflicts detected**:
  1. Inform the user of conflicting files.
  2. Show the command to open VSCode's merge UI:

     ```bash
     code --diff <conflicted-file>
     ```

     Or if using Git integration: "Open Source Control panel → Merge Changes"
  3. Provide the exact terminal commands to resolve manually:

     ```bash
     git merge origin/<target-branch>
     # Resolve conflicts in editor, then:
     git add <resolved-files>
     git commit
     ```

  4. Tell the user: "After resolving conflicts, run `/push-pr` again to continue."
  5. **Stop here.** Do not push until conflicts are resolved.

---

## PR Target Branch Selection

Use AskUserQuestion to ask:
"Which branch should this PR target? (default: main)"

- (a) main
- (b) master
- (c) Enter custom branch name

---

## Push and Create/Update PR

```bash
# Push branch (set upstream if first push)
git push -u origin <current-branch>

# Create PR (or update if already exists)
gh pr create \
  --title "<conventional-commit-style title from recent commits>" \
  --body "## Changes\n<summary of commits since branch point>\n\n## Checklist\n- [ ] Code reviewed\n- [ ] Build passes (keil-build 0 errors)" \
  --base <target-branch> \
  --head <current-branch>
```

If a PR already exists for this branch, use:

```bash
gh pr view --web
```

to open it in browser for the user to update.

---

## After PR Created

Report to user:

- PR URL
- Target branch
- Number of commits included
- Suggest: "After the PR is merged on GitHub, run `/sync-latest` to pull the merged changes."
