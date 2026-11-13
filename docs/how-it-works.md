# How it works

## Design

```
/git-parity:<mode>
      │
      ▼
skills/<mode>/SKILL.md ──runs──▶ scripts/git-parity.sh <mode>
                                   │  discover repositories
                                   │  fetch all in parallel
                                   │  classify each repository
                                   │  fast-forward (remote/full only)
                                   ▼
                              finished report
      ┌────────────────────────────┘
      ▼
Claude: present it, ask before any push or pull request
```

All mechanical work is in one bash script, so results are deterministic and the
same on every run. The model is used only where judgment is needed: explaining a
divergence, asking for confirmation, writing a pull request.

This keeps token use low. The skill files are about 30 lines each, three of the
four are not loaded into context until you invoke them, and the script output is
capped per repository.

## What the script does per repository

1. `git fetch --prune`, with credential prompts disabled and a timeout. A failed
   fetch marks the repository `STALE`; the run continues.
2. Finds the base branch: `origin/HEAD`, else `origin/main`, else `origin/master`.
3. Reads the current branch, its upstream, uncommitted files, and whether a
   rebase, merge or cherry-pick is in progress.
4. For every other local branch, compares it with its upstream.
5. In `remote` and `full`:
   - current branch: `git merge --ff-only <upstream>`, only if the tree is clean
     and the branch is strictly behind;
   - other branches: `git fetch . <upstream>:<branch>`, which git itself refuses
     if it is not a fast-forward or the branch is checked out in another worktree.
6. In `local` and `full`, lists push candidates: branches with commits that exist
   on no remote branch, excluding protected names.

## Rules worth knowing

- **A branch that tracks the base is treated as never pushed.** `git switch -c
  feat origin/main` makes `feat` track `origin/main`. Comparing them would report
  a false "diverged", and fast-forwarding would silently move `feat` to `main`.
  git-parity ignores that upstream and offers `push -u origin feat`.
- **"Never pushed, n commits"** counts commits that are on no remote branch
  (`git rev-list <branch> --not --remotes`). A new branch with no commits of its
  own is not a push candidate.
- **`gone`** means the upstream branch was deleted on the remote, usually after a
  squash merge. It is reported as a count and never deleted.
- **Ordering.** `DIVERGED`, `ERROR`, `IN-PROGRESS`, `STALE`, `DIRTY`, `AHEAD`,
  `BEHIND`/`DETACHED`, `NO-UPSTREAM`/`GONE`, `BRANCHES`, `OK`.

## feature and cleanup

- **feature** lists local and remote branches matching the pattern, counts
  commits against the base, and asks `gh` for the pull request of each pushed
  branch. A branch is "stacked on" another matched branch when that branch is an
  ancestor of it; rows are ordered by commits ahead, which is the merge order.
- **cleanup** offers a branch for deletion only with proof: either it is an
  ancestor of the base (`git merge-base --is-ancestor`), or its remote branch is
  gone and `gh` finds a merged pull request for it. The current branch, the base,
  protected names and branches checked out in a worktree are never listed.
  The script only prints commands; deleting is done by the skill after you approve.

## Running the script directly

It has no dependency on Claude Code:

```bash
bash scripts/git-parity.sh status ~/code/api ~/code/web
bash scripts/git-parity.sh remote --no-fetch
bash scripts/git-parity.sh feature 'feat/login*' work
bash scripts/git-parity.sh cleanup
```
