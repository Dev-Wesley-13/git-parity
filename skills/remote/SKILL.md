---
name: remote
description: Bring remote changes into local branches across all tracked repositories using fast-forward only, then report what changed. Run only when the user explicitly asks to sync, pull or update their repositories.
argument-hint: "[repo-path ...]"
disable-model-invocation: true
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: remote

Report (already generated; branches strictly behind their remote were fast-forwarded, nothing else was touched):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" remote $ARGUMENTS`

If no report appears above (only Claude Code runs that line), run the script once yourself and use its output: `bash <plugin-root>/scripts/git-parity.sh remote <arguments the user gave>`, where `<plugin-root>` is two directories above this file.

On Windows the script needs a POSIX shell: run it with Git Bash, or with `wsl bash` and the script path converted by `wslpath` when the repositories live in WSL. Do not reimplement it in PowerShell.

## What to do

1. Show the report as is: table, "Clean" line, "Next steps". Translate prose to the user's language; keep names, states and commands verbatim.
2. Start with one or two sentences: how many repos were updated ("updated +N" in Detail) and how many need the user.
3. For a DIVERGED row, explain both sides in one line each and offer the options (merge, rebase, or leave it). Run nothing without an explicit yes.

## Hard rules

- Never pull over uncommitted changes, never `stash`, `reset`, `rebase`, `merge` (other than what the script already did), `checkout`/`switch`, force anything or delete a branch on your own.
- Never push. Use `/git-parity:local` for that.
- A skipped repo is a correct outcome. Report it; do not "fix" it.
