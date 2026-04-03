# Developing Styles

## Claude Config Rules (Current)

Sources: `settings.json`, `hooks/`.

- Keep hook behavior deterministic and minimal-context.
- Active git checkpoint events are only `UserPromptSubmit` (`CPST-`) and `Stop` (`CPED-`).
- `CPST-` must run at most once per session; `CPED-` runs on session stop only when changes exist.
- If workspace is not initialized as git, ask only once per session whether to run `git init`.
- Do not reintroduce `TaskCompleted` auto-checkpoint or protected-branch hard-block logic unless explicitly required.
- Hook commands in `settings.json` should keep `.claude/hooks/*` first and `hooks/*` fallback for submodule mounting compatibility.
- Python helpers for hooks should keep UTF-8 safety and Windows-compatible interpreter detection strategy.

## Project Rules (Highest Priority)

Sources: `ReadMe/ReadMe.txt`, user template file under `User/`.

- Keep Parse -> Process -> Distribute data flow.
- `.h` holds declarations only; implementations stay in `.c`.
- Document units at variable definition or struct field level.
- Prefer one function, one responsibility.
- Repeated logic should be extracted.
- Input-only function parameters should use `const` when practical.
- Follow file block layout:
  - includes
  - macro/constants
  - struct/array definitions
  - variable/enum definitions
  - function definitions

## Huawei C (Quality)

- No uninitialized reads.
- Handle all error return values.
- Keep nesting and function size under control.
- Avoid magic numbers.
- Use defensive boundary checks.
- Keep comments synchronized with code changes.

## Google C++ (Reference)

- Include what you use.
- Keep interfaces clear and self-contained.
- Prefer local scope for variables.

## Embedded Checks

- ISR-shared state should use `volatile` where needed.
- Protect shared mutable data across tasks.
- Watch stack usage for large local buffers.
- Use fixed-width integer types in interfaces.
- Avoid direct float equality in control logic.

## Priority

Project rules > Huawei mandatory > Huawei recommendations > Google reference.
