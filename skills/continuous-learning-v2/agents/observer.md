name: observer
description: Legacy alias for memory-observer. Use .claude/agents/memory-observer.md.
model: haiku
---

# Observer Agent (Legacy Alias)

Use `.claude/agents/memory-observer.md` for the active v2.1 implementation with split storage:
- Global: `.claude/GlobalMemory`
- Project: `<project_root>/ProjectMemory/<project-hash>`

Legacy compatibility note:
- old command path: `.claude/skills/continuous-learning-v2/agents/start-observer.sh`
- new command path: `.claude/agents/start-memory-observer.sh`
