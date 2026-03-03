---
name: push-pr
description: 'Two-stage push + PR workflow. First run performs local merge validation and review handoff; second run pushes and creates/updates PR. If current branch is main or release/*, auto-create push-pr sub-branch and default PR base to current protected branch.'
allowed-tools: Bash(git *), Bash(gh *)
---

# Push Branch and Open/Update PR (Two-Stage)

## Context (auto-loaded at start)

- Current branch: !`git branch --show-current`
- Remote tracking status: !`git status -sb`
- Recent commits (not yet on remote): !`git log @{u}..HEAD --oneline 2>/dev/null || git log -5 --oneline`

## Mandatory Protocol

- `/push-pr` uses explicit two-stage flow:
  - Stage 1 (`merge-check`): perform local merge validation and hand off for manual review.
  - Stage 2 (`push-pr`): after user confirms review/resolve done, push and create/update PR.
- If current branch is protected (`main` or `release/*`), you must automatically create `push-pr/<name>` sub-branch first.
- On protected branch start, default PR base branch must be the original protected branch.

## Behavior by Branch State

### Case A: Currently on a PROTECTED branch (main / release/*)

If the user is on a protected branch:

1. Capture protected source branch as `ORIGINAL_BASE`.
2. Inform the user: "You are on a protected branch. A push-pr sub-branch will be created automatically."
3. Use AskUserQuestion to ask sub-branch suffix name.
4. Create branch `push-pr/<suffix>` from current HEAD:

   ```bash
   git checkout -b push-pr/<suffix>
   ```

5. Set PR base default to `ORIGINAL_BASE`.
6. Continue with Stage 1 merge-check.

### Case B: Currently on a WORK branch with uncommitted changes

Use AskUserQuestion with options:

1. "There are uncommitted changes. What would you like to do?"
   - (a) Commit them now (run `/commit` first, then return here)
   - (b) Stash them and continue
   - (c) Push as-is (without these changes)

### Case C: Currently on a WORK branch, clean or committed

Use AskUserQuestion to ask user intent:

- (a) Run Stage 1 merge-check now
- (b) Run Stage 2 push+PR directly (only if merge already checked manually)
- (c) Show manual commands/UI guide only

---

## Stage 1: Merge Check and Review Handoff

Before pushing, do a local real merge validation in a temporary branch:

```bash
# Fetch target branch
git fetch origin <target-branch>

# Create temporary check branch from target
git switch -c push-pr-check/<source-branch>-to-<target-branch> origin/<target-branch>

# Try merge source branch into target snapshot
git merge --no-ff --no-commit <source-branch>
```

- If **no conflicts** detected:
  1. Tell user validation passed.
  2. Clean temporary check branch (no commit needed).
  3. Ask user to run `/push-pr` again for Stage 2.
- If **conflicts detected**:
  1. Inform the user of conflicting files.
  2. Tell user to open VS Code merge UI from Source Control conflict list.
  3. Optionally provide terminal command to open diff view:

     ```bash
     code --diff <conflicted-file>
     ```

  4. Provide exact terminal commands for manual resolve:

     ```bash
     # resolve files in VS Code merge editor, then:
     git add <resolved-files>
     git commit -m "chore: resolve merge conflicts for pr precheck"
     ```

  5. Tell user: "After review/resolve, run `/push-pr` again to continue Stage 2."
  6. **Stop here.** Do not push yet.

---

## Stage 2: Push and Create/Update PR

Before running Stage 2, verify with AskUserQuestion: "Have merge review/check been completed?"

- (a) Yes, continue
- (b) No, go back to Stage 1

If user confirms continue, confirm target branch:

- If started from protected branch: default target is the original protected branch.
- Else: AskUserQuestion with options:
  - main
  - release/<name>
  - custom

Then execute:

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
