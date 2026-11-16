# Safety

git-parity is built so that the worst outcome of running it is "nothing happened".

## The script never

- pushes anything;
- uses `--force`, `reset`, `stash`, `rebase`, `checkout`/`switch`, `commit` or
  `branch -d/-D`;
- merges anything that is not a fast-forward;
- touches a repository with uncommitted changes, a detached HEAD, or a rebase,
  merge or cherry-pick in progress;
- moves a branch that is checked out in another worktree;
- prompts for credentials (a fetch that needs them fails and is reported).

The only writes it performs are `git fetch --prune` (updates remote-tracking
refs), fast-forwards of local branches that are strictly behind their own upstream
(`remote`/`full`), and its own list of repositories (`add`), which lives in
`~/.config/git-parity/` and never inside a repository.

Repositories found by detection, before you save a list, are only read: the commands that
change something act on the current repository alone until you confirm the list.

## The skills never

- push without an explicit yes for that repository and branch;
- push a base branch or a branch listed in `never-push`;
- add `--force`, `--force-with-lease` or `--no-verify`;
- commit on your behalf;
- resolve a divergence on their own;
- save detected repositories without asking you.

The one skill that deletes is `cleanup`, and only local branches the script
proved merged, one approval per repository. It never deletes remote branches.

The skills do not pre-approve `git push`, `gh pr create` or `git branch -D`. Besides the question
Claude asks you, Claude Code's own permission prompt still applies.

## How this is checked

`tests/run.sh` builds real repositories for each state and asserts, for every
state that must be skipped, that local branches, HEAD, the working tree and the
stash are byte-for-byte identical before and after. It also asserts that the
remote is unchanged after `full`.

## Reporting a problem

If git-parity ever changes something it should not have, open an issue with the
report it printed and the output of `git reflog -5` for the affected repository.
Fast-forwards are recorded in the reflog and can be undone with
`git branch -f <branch> <previous-sha>`.
