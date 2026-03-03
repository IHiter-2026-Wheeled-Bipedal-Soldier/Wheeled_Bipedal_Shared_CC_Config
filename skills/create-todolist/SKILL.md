---
name: create-todolist
description: Decompose a large task into executable JSON tasks and initialize plan context plus plan-git-SHA tracking.
user-invocable: true
---

# Create Todo List

## Output

Create one JSON plan:
- `References/PlanPrompt/YYYY-MM-DDThh-mm-<topic>.json`

Each task must include:
- `id`, `name`, `description`
- `acceptance_criteria`
- `files_to_modify`
- `interface_specs`

## Required side effects

1. Set `.claude/plan-context.json` `active_plan` to the generated JSON path.
2. Initialize/append `.claude/plan-git-SHA.json` entry:
   - plan status `in_progress`
   - task status default `pending`
   - `base_plan_sha` and `head_plan_sha` = current HEAD

## Completion Hint

Offer both execution modes:
- `subagent-driven-dev`
- `quick-executing-dev`
