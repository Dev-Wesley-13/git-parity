---
name: local
description: Find local work that is not on the remote yet across all tracked repositories and offer to push it and open a pull request, one confirmation per repository.
argument-hint: "[repo-path ...]"
disable-model-invocation: true
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: local

Report (already generated, nothing was changed):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" local $ARGUMENTS`

If no report appears above, run `bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" local $ARGUMENTS` once and use its output.

## What to do

1. Show the report as is. Translate prose to the user's language; keep names, states and commands verbatim.
2. If there is a "Push candidates" section, ask which ones to push. One decision per repository/branch; "all" is acceptable only if the user says so explicitly. When asking with a choice widget, every question needs at least two options: for a repository with a single candidate, offer "push" and "skip".
3. For each approved candidate, run exactly the command printed for it. Never add `--force`, `--force-with-lease` or `--no-verify`.
4. After a successful push of a non-base branch, offer a pull request. If the user agrees: `gh pr create --fill` in that repo for a GitHub remote, `glab mr create --fill` for a GitLab remote, when that CLI is installed; otherwise print the URL that `git push` showed. Ask for title/body changes before creating.
5. End with a short list: pushed, PR opened (with URL), skipped.

## Hard rules

- Nothing reaches the remote without a yes for that specific repo and branch.
- Never push a branch that is not listed under "Push candidates" (base branches and `never-push` entries are excluded on purpose).
- Never commit for the user. For DIRTY repos, show what is pending and let the user decide.
- DIVERGED branches are not pushed: explain and stop.
