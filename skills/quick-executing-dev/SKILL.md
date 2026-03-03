---
name: quick-executing-dev
description: Execute short tasks quickly with manual checkpoints and final mandatory code review.
user-invocable: true
---

# Quick Executing Development

## Preconditions

- Active plan exists.

## Flow

1. Implement requested scope quickly.
2. Run `implement-and-verify` for build evidence.
3. Trigger `code-review` once for final review.

## Completion

- Provide concise result and risks.
- Suggest next step: on-robot validation, then `merge-work-branch`.
- Use Chinese for output summaries and reports.
