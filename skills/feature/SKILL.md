---
name: feature
description: Show where the branches of one feature stand across all tracked repositories - commits ahead of the base, pushed or not, pull request state, and merge order for stacked branches. Use when the user asks about the state of a feature that spans several repos.
argument-hint: "<branch-name-or-pattern> [group|repo-path ...]"
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: feature

Report (already generated, nothing was changed; only `git fetch` ran):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" feature $ARGUMENTS`

If no report appears above, run `bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" feature $ARGUMENTS` once and use its output. If the report says a pattern is needed, ask the user for the feature's branch name or a part of it.

## What to do

1. Show the table as is, translating prose to the user's language; keep repo names, branch names and commands verbatim.
2. Open with one or two sentences: how many branches in how many repos, and what blocks the feature from being merged (unpushed work, missing pull requests, stacked order).
3. Keep "Next steps". Rows are already in merge order inside each repository; if the feature needs a cross-repository order (for example backend before frontend), say that this is the user's call and suggest one only if the branch names make it obvious.
4. Do not run any other command. This skill never changes anything.

Columns: "vs base" is commits ahead / behind the base branch ("merged" = nothing left to merge). "Remote" is pushed, N unpushed, never pushed, behind remote, or remote only. "PR" is the pull request number and state, "none", or "-" when the branch is not on the remote or `gh` is not installed.
