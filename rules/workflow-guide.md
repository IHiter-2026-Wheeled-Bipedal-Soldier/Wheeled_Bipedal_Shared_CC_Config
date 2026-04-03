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
7. To commit changes: use `/commit`. Hook-triggered checkpoint commits include only `CPST-` (first prompt of session) and `CPED-` (session stop), and suffix is generated as a short Chinese Conventional Commit summary.
8. To push and open a PR: use `/push-pr`.
9. To sync with the latest main branch and submodules: use `/sync-latest`.
10. To archive a release snapshot: use `/git-archive`.
11. To clean up stale [gone] branches: use `/clean-gone`.
12. To update submodules (.claude/ memory): use `/sync-submodules`.

## Hook Runtime Notes (Current)

- `SessionStart`: reset `git-session-state.json` and inject minimal runtime context.
- `UserPromptSubmit`: run `CPST-` checkpoint at most once per session when repository has uncommitted changes.
- `UserPromptSubmit` in non-git workspace: ask once per session via AskUserQuestion with options `INIT_GIT_NOW` or `SKIP_GIT_THIS_SESSION`.
- `Stop`: run `CPED-` checkpoint when repository has uncommitted changes.
- `PreToolUse` and `PostToolUse`: only run memory observer hooks.
- No `TaskCompleted` auto-checkpoint hook is active.
- No protected-branch hard-block hook is active.
- Hook command path in `settings.json` prefers `.claude/hooks/*` and falls back to `hooks/*`.

## Git Collaboration Notes

- `main` stores only stable code validated on robot.
- Use one owner-based `dev/*` branch per developer, not feature-based branch naming.
- If a feature depends on another developer's work, manually merge that developer's `dev/*` branch first.
- Pull Request flow is optional and not required in this repository.
- When current branch is `main`, branch transition to `dev/*` is recommended before mutation, but this is a workflow convention instead of a hard hook blocker.

Notes:

- Keep implementation minimal (YAGNI, DRY), avoid scope creep.
- Follow project naming/style conventions from `rules/naming-rules.md`.
- Follow coding style from `rules/developing-styles.md`.
- Build evidence must be explicit before final completion.
- If git is not initialized, assistant asks once per session whether to run `git init` or continue without git.
