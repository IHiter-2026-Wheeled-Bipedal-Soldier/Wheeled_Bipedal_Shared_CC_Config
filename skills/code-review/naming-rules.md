# Naming Rules

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
