---
name: code-review
description: Review dispatcher. Run spec-reviewer first, then quality-reviewer, with SHA range selection from plan-git-SHA.
argument-hint: "[task|plan|files]"
user-invocable: true
---

# Code Review Dispatcher

This skill orchestrates review flow only. It does not auto-edit code.

## Execution order (mandatory)

1. Resolve review range from `.claude/plan-git-SHA.json`.
2. Run `spec-reviewer` first.
3. Continue to `quality-reviewer` only if spec review passes.
4. Mark review complete only if both reviewers pass.

## SHA range strategy

- Select latest `in_progress` plan on current branch.
- Plan-level review:
  - `BASE = base_plan_sha`
  - `HEAD = current HEAD`
- Task-level review:
  - first task: `BASE = base_plan_sha`
  - otherwise: `BASE = previous completed task head_sha` by `completed_at`
  - `HEAD = current HEAD`
- Always run `git diff --stat BASE..HEAD` before dispatch.

## Fallback when no active plan

Ask user using AskUserQuestion:

1. No in-progress plan found. Choose scope:
   - (a) input BASE_SHA and HEAD_SHA
   - (b) review last N commits
   - (c) other
2. If (a): ask for both SHAs.
3. If (b): ask for N.

## Output policy

- Pass result: return concise message, no file required.
- Fail result: write markdown report to `References/ReviewReport/<plan-id>/`.
  - spec fail: `SPEC-<plan-id>.md`
  - quality fail: `QLTY-<plan-id>.md`
- Report content must be fully in Chinese.
- Use Chinese report sections: `优势`, `问题`, `结论`.

## References

- `naming-rules.md`
- `developing-styles.md`
- `spec-reviewer-prompt.md`
- `quality-reviewer-prompt.md`
