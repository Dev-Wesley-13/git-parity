# Commands

In Claude Code and Gemini CLI the commands are `/git-parity:<command>`. In Codex and
Antigravity they are skills: ask for them by name ("use the git-parity remote skill").

Every command accepts repository paths or a group name after it, and `--no-fetch` to skip
the network: `/git-parity:status shop --no-fetch`.

## status

Read-only report. The only thing it runs against the remote is `git fetch`.

```
git-parity status · 5 repo(s) · 2 need attention · fetched in 3s

| Repo | Branch       | State     | Detail                                   |
|------|--------------|-----------|------------------------------------------|
| web  | feat/filters | DIVERGED  | 2 local / 5 remote commits differ; not touched |
| api  | main         | BEHIND 2  | can fast-forward                         |

Clean (3): app, docs, infra

Next steps
- web: diverged from origin/feat/filters; inspect both sides: git -C ~/web log --oneline --left-right feat/filters...origin/feat/filters
- api: fast-forward: /git-parity:remote
```

## remote

Fast-forwards every branch that is strictly behind its own remote branch: the current one
(if the working tree is clean) and the others, including the base branch, without checking
them out. Everything else is left alone and reported.

## local

Lists the branches that have commits on no remote branch, under "Push candidates", each
with its exact command. The agent asks which to push, one decision per repository and
branch, then offers a pull request (`gh`) or merge request (`glab`).

Base branches and names in `never-push` are never candidates.

## full

`remote`, then `local`, in that order: bring changes in first, then send yours out. The
goal is that every branch ends in a known, explained state, not that every count is zero.

## feature

```
/git-parity:feature checkout
/git-parity:feature 'feat/checkout-*' shop
```

```
| Repo | Branch             | vs base | Remote       | PR       | Note                                                |
|------|--------------------|---------|--------------|----------|-----------------------------------------------------|
| api  | feat/checkout-core | +3      | pushed       | #41 OPEN |                                                     |
| api  | feat/checkout-tax  | +5      | never pushed | -        | stacked on feat/checkout-core: merge that one first |
| web  | feat/checkout-page | +2 / -4 | 1 unpushed   | none     |                                                     |
```

The pattern matches any part of the branch name; globs work too. Rows are in merge order
inside each repository.

## cleanup

```
Merged into the base (safe to delete)
- api (3): git -C ~/api branch -D feat/login feat/signup fix/typo

Remote branch deleted, merge NOT verified (do not delete without checking)
- web (1): spike/old-idea
```

A branch is offered for deletion only with proof: it is fully contained in the base, or its
remote branch is gone and a merged pull request exists for it. Nothing is deleted until you
approve, per repository.

## prs

Your open pull requests, ordered by urgency (failing checks, conflicts or requested changes
first; approved and ready to merge next), then the ones waiting for your review. Needs `gh`
for GitHub or `glab` for GitLab.

## whats-new

A short briefing of the commits that came into each base branch, and a warning for every
file that was also changed on your current branch. If the base is behind its remote, it
shows what is incoming; otherwise, what the last update brought.

## add

```
/git-parity:add ~/work/legacy-api
/git-parity:add --group shop ~/code/shop-api ~/code/shop-web
/git-parity:add --list
/git-parity:add --remove ~/work/legacy-api
```

Maintains the list of tracked repositories. It only writes git-parity's own list and never
touches a repository. You rarely need to type it: when a report detects repositories that
are not saved, the agent offers to save them for you.
