Run `spec-reviewer` for this review request.

Inputs required:
- Active plan from `.claude/plan-context.json`
- SHA range from `.claude/plan-git-SHA.json`
- Diff scope: `git diff BASE..HEAD`

Focus:
- acceptance_criteria coverage
- interface_specs conformance
- out-of-scope additions
- planned-but-missing items

Output requirement:
- Keep this prompt in English, but write any generated review report content fully in Chinese.
