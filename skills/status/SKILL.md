---
name: status
description: Read-only report of every tracked git repository - which branches are behind, ahead, diverged, dirty or never pushed, with next steps. Use when the user asks whether their repos or branches are in sync, up to date, or what is unpushed.
argument-hint: "[repo-path ...]"
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: status

Report (already generated, nothing was changed; only `git fetch` ran):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" status $ARGUMENTS`

If no report appears above, run `bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" status $ARGUMENTS` once and use its output.

## What to do

1. Show the report to the user as is: keep the table, the "Clean" line and "Next steps". Translate labels and prose to the user's language; keep repo names, branch names, states and commands verbatim.
2. Add at most two sentences of summary on top. Do not re-explain rows.
3. Do not run any other command. This skill never changes anything.

States: DIVERGED (local and remote both have new commits), IN-PROGRESS (rebase/merge unfinished), STALE (fetch failed), DIRTY n (n uncommitted files), AHEAD n (not pushed), BEHIND n (can fast-forward), DETACHED, NO-UPSTREAM (never pushed), GONE (remote branch deleted, usually merged), BRANCHES (current branch fine, another branch needs attention), OK (clean, something was updated or noted).
