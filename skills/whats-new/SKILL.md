---
name: whats-new
description: Summarize the commits that recently came into the base branch of each tracked repository and point out files that were also changed on the user's current branch. Use when the user asks what changed, what teammates merged, or what came in with the last pull.
argument-hint: "[group|repo-path ...]"
allowed-tools: Bash(bash *git-parity.sh*)
---

# git-parity: whats-new

Raw data (already generated, nothing was changed; only `git fetch` ran):

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/git-parity.sh" whats-new $ARGUMENTS`

If no data appears above (only Claude Code runs that line), run the script once yourself and use its output: `bash <plugin-root>/scripts/git-parity.sh whats-new <arguments the user gave>`, where `<plugin-root>` is two directories above this file.

On Windows the script needs a POSIX shell. When the repositories live in WSL, run exactly this (replace the path with the Windows path of the script; the quoting is deliberate):

`wsl.exe -d <distro> -- bash -c 'bash "$(wslpath -u "<windows path to scripts/git-parity.sh>")" whats-new <arguments>'`

Otherwise use Git Bash. Do not reimplement the script in PowerShell, and do not edit line endings: the file already uses LF.

## What to do

Unlike the other git-parity reports, do not paste this one. Write a short briefing in the user's language:

1. Per repository with news: two to four bullets grouping the commits by theme (feature, fix, area), naming who did what when that helps. Mention the count and whether it is "incoming, not pulled yet" or "since the last update".
2. Then, for every "Also changed on your branch" line: name the branch and the files, and say plainly that a merge or rebase may conflict there. This is the most useful part; do not bury it.
3. One closing line listing the repositories with nothing new.
4. Use only what is in the data. If the user wants more about a commit, run `git -C <repo> show --stat <sha>` then.

"incoming, not pulled yet" means the base branch is behind its remote; `/git-parity:remote` brings it in. Do not run it yourself.
