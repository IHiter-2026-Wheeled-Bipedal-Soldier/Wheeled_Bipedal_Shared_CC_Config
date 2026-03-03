---
name: implement-and-verify
description: Implement planned changes with minimal scope, then verify with build evidence before completion.
user-invocable: true
---

# Implement and Verify

## Rules

- Implement only what current task requires.
- Follow project naming and style conventions.
- Keep changes minimal (YAGNI, DRY).
- Claim completion only with verification evidence.

## Verification

1. Run `keil-build`.
2. Confirm final summary line in build log.
3. If optional tests exist for target module, run them.

## Output

- Files changed
- Verification evidence
- Risks/open items
- Output summary must be in Chinese.
