# Getting started

## 1. Install

See the table in the [README](../README.md#install), or [agents.md](agents.md) for the
details of each agent.

## 2. Open a session in one of your repositories and ask for the status

```
/git-parity:status
```

In Codex and Antigravity, ask in plain words: "run git-parity status".

You get the report for the repositories of that project, found automatically, and the
agent asks whether to save the groups it detected. Say yes if they look right. From then
on every command covers the saved repositories, from any folder.

Nothing was changed: `status` only runs `git fetch`.

## 3. The daily routine

Start of the day, or before starting a task:

```
/git-parity:remote
```

Every base branch is brought up to date, your feature branches are fast-forwarded if a
teammate pushed to them, and anything that needs a decision is listed with the command to
run.

End of the day, or before switching machines:

```
/git-parity:local
```

Everything that exists only on your machine is listed. You choose what to push and whether
to open a pull request.

`/git-parity:full` does both.

## Working alone

`full` at the end of a session answers "is everything I did on the remote?" across all your
projects.

If you push straight to `main`, note that the base branch is never offered for push. That
is deliberate: run the printed `git push` yourself, or work on a branch.

## Working in a team

- Base branches stay current without interrupting work in progress: `main` is updated even
  while you are on a feature branch.
- "Remote branches not merged into base" shows teammates' branches you do not have locally,
  newest first.
- `/git-parity:prs` shows what is blocked on you; `/git-parity:whats-new` shows what the
  others merged and which of those files you also touched.
- Shared long-lived branches (`develop`, `release`, `staging`) belong in the `never-push`
  list, so they are never offered for a direct push. See [configuration.md](configuration.md).
- A branch waiting for review stays ahead of the base. That is the correct state, not
  something to fix.

## A feature that spans repositories

```
/git-parity:feature checkout
```

One table shows every branch whose name contains `checkout`, in every repository: how far
ahead of the base it is, whether it is pushed, its pull request, and which branch must be
merged first when branches are stacked.

## Large teams and large repositories

- Unmerged remote branches are shown as a count and the three newest names, and deleted
  remote branches as a single count, so the report stays short.
- Fetch time dominates. Tune it with `GIT_PARITY_JOBS` and `GIT_PARITY_FETCH_TIMEOUT`, or
  pass `--no-fetch` to report from what is already fetched.

## More than one project

Each project is a group. `/git-parity:status shop` checks only the group `shop`;
without a name, every saved repository is checked. Groups are created by detection or with
`/git-parity:add --group <name> <paths>`.

## Housekeeping

```
/git-parity:cleanup
```

Lists local branches whose work is already in the base, and asks before deleting anything.
