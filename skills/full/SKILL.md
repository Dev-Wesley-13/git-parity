---
name: full
description: Full two-way sync across all tracked repositories - fast-forward local branches from the remote, then offer to push local work and open pull requests, with a confirmation per repository. Run only when the user explicitly asks for a full sync.
argument-hint: "[repo-path ...]"
disable-model-invocation: true
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: full

Report (already generated; branches strictly behind were fast-forwarded first, then push candidates were listed; nothing was pushed):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" full $ARGUMENTS`

If no report appears above (only Claude Code runs that line), run the script once yourself and use its output: `bash <plugin-root>/scripts/git-parity.sh full <arguments the user gave>`, where `<plugin-root>` is two directories above this file.

## What to do

1. Show the report as is. Translate prose to the user's language; keep names, states and commands verbatim. Open with one or two sentences: updated, needs attention, ready to push.
2. Incoming side: for DIVERGED rows explain both sides and offer options; run nothing without an explicit yes.
3. Outgoing side: if there is a "Push candidates" section, ask which to push (one decision per repo/branch; with a choice widget every question needs at least two options, so offer "push" and "skip" for a single candidate), run exactly the printed command, then offer a pull request (`gh pr create --fill` for GitHub, `glab mr create --fill` for GitLab, when that CLI is installed; otherwise the URL that `git push` showed).
4. End with: updated, pushed, PRs opened, left as is and why.

The goal is that every branch ends in a known, explained state. A branch waiting for review stays ahead of the base on purpose; that is not a problem to fix.

## Hard rules

- Nothing reaches the remote without a yes for that specific repo and branch. Never force, never `--no-verify`.
- Never push a branch that is not under "Push candidates".
- Never commit, stash, reset, rebase, switch branches or delete a branch on your own.
- A skipped repo is a correct outcome. Report it; do not "fix" it.
