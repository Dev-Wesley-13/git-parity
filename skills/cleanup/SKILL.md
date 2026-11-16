---
name: cleanup
description: List local branches that are already merged and stale worktree records across all tracked repositories, then delete only what the user approves. Run only when the user explicitly asks to clean up branches.
argument-hint: "[group|repo-path ...]"
disable-model-invocation: true
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: cleanup

Report (already generated; nothing was deleted):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" cleanup $ARGUMENTS`

If no report appears above (only Claude Code runs that line), run the script once yourself and use its output: `bash <plugin-root>/scripts/git-parity.sh cleanup <arguments the user gave>`, where `<plugin-root>` is two directories above this file.

On Windows the script needs a POSIX shell: run it with Git Bash, or with `wsl bash` and the script path converted by `wslpath` when the repositories live in WSL. Do not reimplement it in PowerShell.

## What to do

1. Show the report grouped as it is, translating prose to the user's language; keep names and commands verbatim. For long lists, show the count and the first few names, and offer the full list.
2. Ask what to delete, one decision per repository and group ("merged", "squash-merged"). Every question needs at least two options (for example "delete" and "keep").
3. For each approval, run exactly the printed command. To delete only some branches, run the same command with only those names.
4. End with: deleted (count per repo), kept.

## Hard rules

- Delete only branches listed under "Merged into the base" or "Squash-merged". The script verified those: the first group is fully contained in the base; the second has a deleted remote branch and a merged pull request.
- Branches under "merge NOT verified" get no command on purpose. Never delete them on your own. If the user insists, show `git log --oneline <base>..<branch>` first so they see what would be lost, and ask again.
- Never delete the current branch, the base branch, a branch checked out in a worktree, or any remote branch.
- A deleted branch can be restored from `git reflog` for a while; mention this once after deleting.
