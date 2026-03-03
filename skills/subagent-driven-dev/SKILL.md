---
name: subagent-driven-dev
description: Execute long tasks by task-level implementation and mandatory review dispatch per task.
user-invocable: true
---

# Subagent Driven Development

## Preconditions

- Active plan exists in `.claude/plan-context.json`.

## Loop (for each task)

1. Implement with `implement-and-verify`.
2. Trigger `code-review`.
3. Require spec pass then quality pass.
4. Mark task complete only after review pass.

## Completion

- Require `keil-build` clean evidence.
- Suggest next step: on-robot validation, then `merge-work-branch`.
