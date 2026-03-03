# Workflow Guide (Recommended)

Use this repository workflow for embedded chassis development:

1. Start with `brainstorming` for requirement clarification and constraints.
2. Run `create-todolist` to generate a JSON plan in `References/PlanPrompt/`.
3. Choose one execution mode:
   - `subagent-driven-dev` for long and complex tasks.
   - `quick-executing-dev` for short, supervised tasks.
4. Ensure implementation uses `implement-and-verify` and confirms build evidence.
5. Trigger `code-review` before claiming completion.
6. After on-robot validation, run `merge-work-branch`.
7. To commit changes: use `/commit`.
8. To push and open a PR: use `/push-pr`.
9. To sync with the latest main branch and submodules: use `/sync-latest`.
10. To archive a release snapshot: use `/git-archive`.
11. To clean up stale [gone] branches: use `/clean-gone`.
12. To update submodules (.claude/ memory): use `/sync-submodules`.

Notes:

- Keep implementation minimal (YAGNI, DRY), avoid scope creep.
- Follow project naming/style conventions from `rules/naming-rules.md`.
- Follow coding style from `rules/developing-styles.md`.
- Build evidence must be explicit before final completion.
- All AI edits must happen on a work branch, never on protected branches (main/master/v1-stable).
