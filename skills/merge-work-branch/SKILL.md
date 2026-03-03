---
name: merge-work-branch
description: Generate merge guide for merging current work branch into selected protected branch. Advisory only.
user-invocable: true
---

# Merge Work Branch

## Rules

- Do not run merge automatically.
- Do not use git worktree.
- Provide merge guidance directly in chat rather than a file.

## Procedure

1. Detect protected target branch (`main`, `master`, `v1-stable` or user-selected protected branch).
2. Analyze `git diff target..HEAD`.
3. Inform the user of:
   - Recommended merge commands.
   - Summary of key changes to be merged.
   - Any manual conflicts or risks identified during diff.
4. User will perform the merge manually in their terminal.
