---
name: remote
description: Bring remote changes into local branches across all tracked repositories using fast-forward only, then report what changed.
argument-hint: "[repo-path ...]"
disable-model-invocation: true
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: remote

Report (already generated; branches strictly behind their remote were fast-forwarded, nothing else was touched):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" remote $ARGUMENTS`

If no report appears above, run `bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" remote $ARGUMENTS` once and use its output.

## What to do

1. Show the report as is: table, "Clean" line, "Next steps". Translate prose to the user's language; keep names, states and commands verbatim.
2. Start with one or two sentences: how many repos were updated ("updated +N" in Detail) and how many need the user.
3. For a DIVERGED row, explain both sides in one line each and offer the options (merge, rebase, or leave it). Run nothing without an explicit yes.

## Hard rules

- Never pull over uncommitted changes, never `stash`, `reset`, `rebase`, `merge` (other than what the script already did), `checkout`/`switch`, force anything or delete a branch on your own.
- Never push. Use `/git-parity:local` for that.
- A skipped repo is a correct outcome. Report it; do not "fix" it.
