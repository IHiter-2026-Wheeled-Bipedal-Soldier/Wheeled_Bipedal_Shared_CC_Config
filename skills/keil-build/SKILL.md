---
name: keil-build
description: Meta skill for Keil compile only. Run one build and return raw compiler output without auto-fixes.
---

# Keil Build (Compile Only)

Run this command exactly once:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/.claude/skills/keil-build/scripts/keil-build.ps1"
```

## Output requirements

- Read and return `Project/.vscode/uv4.log` content summary.
- Include the final compiler line with `Error(s)` and `Warning(s)`.
- Do not modify any source code.
- Do not run compile-fix loops.

## Scope

- This skill is build telemetry only.
- Any remediation must be triggered by a separate explicit user request.
