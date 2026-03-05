# Workflow Guide (Recommended)

Use this repository workflow for embedded chassis development:

1. Start with `brainstorming` for requirement clarification and constraints.
2. Run `create-todolist` to generate a JSON plan in `References/PlanPrompt/`.
3. Choose one execution mode:
   - `subagent-driven-dev` for long and complex tasks.
   - `quick-executing-dev` for short, supervised tasks.
4. Ensure implementation uses `implement-and-verify` and confirms build evidence.
5. Trigger `code-review` before claiming completion.
6. After on-robot validation, manually merge from `dev/*` branch to `main`.
7. To commit changes: use `/commit`. For hook-triggered checkpoint commits, prefix (`CPST-`/`CPED-`/`TASK-`) is auto-injected by hook scripts; `/commit` skill only generates the Conventional Commit suffix. Manual `/commit` does not auto-add CP prefixes.

## Git Collaboration Notes

- `main` stores only stable code validated on robot.
- Use one owner-based `dev/*` branch per developer, not feature-based branch naming.
- If a feature depends on another developer's work, manually merge that developer's `dev/*` branch first.
- Pull Request flow is optional and not required in this repository.
- When current branch is `main`, first response must use AskUserQuestion to choose branch transition:
   1) Switch to an existing local `dev/*` branch (enumerated)
   2) Create a new `dev/*` branch
   3) If creating, ask for branch name input in format `dev/<name>`

Notes:

- Keep implementation minimal (YAGNI, DRY), avoid scope creep.
- Follow project naming/style conventions from `rules/naming-rules.md`.
- Follow coding style from `rules/developing-styles.md`.
- Build evidence must be explicit before final completion.
- All AI edits must happen on a `dev/*` branch, never on protected branch `main`.
