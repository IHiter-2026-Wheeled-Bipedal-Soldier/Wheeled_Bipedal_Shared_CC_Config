# Naming Rules

## Claude Config Naming (Current)

Sources: `settings.json`, `hooks/auto-commit.py`.

- Hook scripts follow `hook_<event>.sh` naming (for example: `hook_session_start.sh`, `hook_prompt_submit.sh`, `hook_stop.sh`).
- Hook Python helper constants use `UPPER_CASE` (for example: `PREFIX_MAP`, `STATE_FILE_NAME`).
- Hook Python helper function names use `snake_case`.
- Session state file name is fixed as `git-session-state.json`.
- Session state keys stay stable: `session_marker`, `git_init_prompted`, `git_init_decision`, `start_commit_done`, `updated_at`.
- AskUserQuestion token names stay stable: `INIT_GIT_NOW`, `SKIP_GIT_THIS_SESSION`.
- Checkpoint prefix tokens stay stable: `CPST-`, `CPED-`.
- Collaboration branch naming convention remains `dev/<name>`.

## Project Rules (Highest Priority)

Source: `ReadMe/ReadMe.txt`

- Prefix order: `[Scope][Type][Component]_[Name]`
- Scope: `G` global, `S` static
- Type: `ST`/`st` struct, `EM` enum, `F` flag
- Component: `CH` chassis, `GB` gimbal
- Suffix standards: `FB`, `Des`, `ZP`, `cnt`, `fps`
- Function helper naming:
  - `_FunctionName`: helper inside one function context
  - `__FunctionName`: tiny helper or predicate helper

Examples:

- `GFCH_SafeMode`
- `GSTCH_Data`

## Huawei C (Naming)

- Keep one naming style across project.
- Global/static identifiers must be clearly scoped.
- Macro and enum constants use uppercase with underscores.
- Avoid one-letter names except loop index `i/j/k`.
- Function names should be verb-first.

## Google C++ (Reference)

- Use clear, descriptive names.
- Avoid ambiguous abbreviations.
- Keep macro naming explicit and stable.

## Priority

Project rules > Huawei mandatory > Huawei recommendations > Google reference.
