# Guide

## Daily use

Start of the day, or before starting a task:

```
/git-parity:remote
```

Every base branch is brought up to date, your feature branches are fast-forwarded
if a teammate pushed to them, and anything that needs a decision is listed with
the command to run.

End of the day, or before switching machines:

```
/git-parity:local
```

Everything that exists only on your machine is listed. You choose what to push
and whether to open a pull request.

`/git-parity:full` does both. `/git-parity:status` only looks.

## Solo developer

List your projects once in `~/.config/git-parity/repos`. Then `full` at the end of
a session answers "is everything I did on the remote?" across all of them.

If you push straight to `main`, note that the base branch is never offered for
push. That is deliberate: run the printed `git push` yourself, or work on a
branch.

## Team (2 to 10 people)

- Base branches stay current without interrupting work in progress: `main` is
  updated even while you are on a feature branch.
- "Remote branches not merged into base" shows teammates' branches you do not
  have locally, newest first, so you see what is in flight.
- Shared long-lived branches (`develop`, `release`, `staging`) belong in
  `~/.config/git-parity/never-push`, so they are never offered for a direct push.
- A branch waiting for review stays ahead of the base. That is the correct state,
  not something to fix.

## Large teams and large repositories

- Only counts and the three newest names are printed for unmerged remote
  branches, and `gone` branches are a single count, so the report stays short no
  matter how many branches exist.
- Fetch time dominates. Tune with `GIT_PARITY_JOBS` (parallel fetches, default 8)
  and `GIT_PARITY_FETCH_TIMEOUT` (seconds per repository, default 30).
- `--no-fetch` reports from what is already fetched:
  `/git-parity:status --no-fetch`.
- In a monorepo, run it inside the repository; it reports that one repository.

## Many repositories

Use the `repos` file for the set you always work on, with `[group]` sections if
you have more than one set (`[work]`, `[oss]`). For a one-off, pass paths.
From a parent folder with no `repos` file, repositories up to two levels below
are found automatically.

## A feature that spans repositories

```
/git-parity:feature checkout
```

One table shows every branch whose name contains `checkout`, in every repository:
how far ahead of the base it is, whether it is pushed, its pull request, and
which branch must be merged first when branches are stacked. Use it before a
release to see what is still missing.

## Pull requests and news

```
/git-parity:prs
/git-parity:whats-new
```

`prs` answers "what is blocked on me": your open pull requests ordered by
urgency (failing checks, conflicts, requested changes first), then the ones
teammates are waiting for you to review.

`whats-new` answers "what did the others merge": a short briefing of the commits
that came into each base branch, and a warning for every file that was also
changed on your current branch.

## Housekeeping

```
/git-parity:cleanup
```

Lists local branches whose work is already in the base, and asks before deleting
anything. Squash-merged branches are only offered when a merged pull request is
found (needs `gh`); otherwise they are listed as "not verified" with no delete
command.

## Forks

Add the original repository as a remote named `upstream`. From then on
`/git-parity:remote` keeps your local base equal to `upstream`, and the report
reminds you to push it to your fork.

## When something is skipped

| Report says | What to do |
|---|---|
| `DIRTY` | Commit or stash, then run the command again. |
| `DIVERGED` | Ask Claude to explain both sides; choose merge or rebase yourself. |
| `IN-PROGRESS` | Finish or abort the rebase/merge. |
| `STALE` | Check network, VPN or credentials: `git -C <repo> fetch`. |
| `base branch unknown` | `git -C <repo> remote set-head origin -a`. |

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `GIT_PARITY_CONFIG_DIR` | `~/.config/git-parity` | Where `repos` and `never-push` live. |
| `GIT_PARITY_JOBS` | `8` | Parallel repositories. |
| `GIT_PARITY_FETCH_TIMEOUT` | `30` | Seconds before a fetch is abandoned (needs `timeout`). |
| `GIT_PARITY_FORGE` | from `origin` URL | `github` or `gitlab`, for self-hosted servers. |

`~/.config/git-parity/config` holds one optional line, `session_hook=on`.
