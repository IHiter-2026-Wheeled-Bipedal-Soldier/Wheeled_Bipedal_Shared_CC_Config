---
name: goto
description: Switch working branch or travel to a past commit
disable-model-invocation: true
user-invocable: true
---

# Go To Skill

$ARGUMENTS represents either a branch name or a commit ID.
If the user passes a commit ID, run `git checkout` to jump to a detached HEAD.
If they pass a branch name, run `git checkout` to access it.
