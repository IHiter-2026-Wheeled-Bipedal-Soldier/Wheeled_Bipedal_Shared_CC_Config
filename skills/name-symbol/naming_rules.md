# Naming Rules

This file contains naming-only guidance used by `/name-symbol`.

## 1) Project Naming Rules (Highest Priority)

Source: `ReadMe/ReadMe.txt`

### Prefix pattern

`[Scope][Type][Component]_[Name]`

- Scope: `G` global, `S` static
- Type: `ST`/`st` struct, `EM` enum, `F` flag/float role marker
- Component: `CH` chassis, `GB` gimbal

Examples:

```c
GFCH_SafeMode
GSTCH_Data
SSTCH_PidParam
```

### Function prefix pattern

- Public function: no underscore prefix
- Internal helper: `_FunctionName`
- Tiny helper/predicate: `__FunctionName`

### Standard suffixes

- `FB` feedback
- `Des` desired/target
- `ZP` zero point
- `cnt` counter
- `fps` frame rate

## 2) Huawei C Naming (Mandatory + Recommended)

- Keep naming style consistent in one project.
- Macro/enum constants use uppercase with underscores.
- Avoid one-letter variables except loop indexes (`i/j/k`).
- Prefer verb-led function names.
- Avoid ambiguous abbreviations.

Common abbreviations:

`arg`, `buff`, `clk`, `cmd`, `cfg`, `err`, `init`, `max`, `min`, `para`, `prev`, `tmp`.

## 3) Google C++ Naming (Reference)

- Keep names descriptive and unambiguous.
- Variables: lower_snake_case.
- Macros: UPPER_SNAKE_CASE.

## Priority

Project rules > Huawei mandatory > Huawei recommendations > Google reference.
