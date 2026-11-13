# git-parity

[![CI](https://github.com/Dev-Wesley-13/git-parity/actions/workflows/ci.yml/badge.svg)](https://github.com/Dev-Wesley-13/git-parity/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Keep local and remote git branches in parity across all your repositories, from one Claude Code command.**

`git-parity` checks every repository you work on, fast-forwards what is safe to
fast-forward, offers to push what is only on your machine, and gives you one short
report with the exact next step for anything it left alone.

[Português (Brasil)](README.pt-BR.md)

```
git-parity full · 4 repo(s) · 2 need attention · fetched in 1s

| Repo | Branch     | State       | Detail                    |
|------|------------|-------------|---------------------------|
| app  | main       | DIRTY 1     | uncommitted changes       |
| web  | feat/login | NO-UPSTREAM | never pushed, 1 commit(s) |
| api  | feat/pay   | OK          | main updated +1           |

Clean (1): docs

Push candidates (ask before each push)
- web · feat/login · never pushed, 1 commit(s) · git -C ~/web push -u origin feat/login

Next steps
- app: commit or stash 1 file(s): git -C ~/app status --short
- web: publish the branch: git -C ~/web push -u origin feat/login
```

## Why

- **Safe by construction.** Fast-forward only. It never pulls over uncommitted
  changes and never forces, resets, stashes, rebases, switches or deletes a branch.
- **Nothing leaves your machine without a yes.** Pushes and pull requests are
  offered one repository at a time.
- **Updates the base branch without leaving your feature branch.** `main` is
  brought up to date while you stay where you are.
- **Fast and cheap.** One bash script fetches all repositories in parallel and
  prints the finished report. The model reads one result instead of running
  fifteen git commands.
- **No dependencies.** bash and git. `gh` is optional, for pull requests.

## Install

In Claude Code:

```
/plugin marketplace add Dev-Wesley-13/git-parity
/plugin install git-parity@git-parity
```

Update with `/plugin update git-parity@git-parity`. Remove with
`/plugin uninstall git-parity@git-parity`.

Requirements: git 2.23+, bash 3.2+ (Linux, macOS, WSL, Git Bash).

## Commands

| Command | What it does | Changes |
|---|---|---|
| `/git-parity:status` | Report only. | Nothing (runs `git fetch`). |
| `/git-parity:remote` | Brings remote changes in: fast-forwards every branch that is strictly behind. | Local branches, fast-forward only. |
| `/git-parity:local` | Finds work that is only on your machine and offers push and pull request. | Remote, after you confirm each one. |
| `/git-parity:full` | `remote`, then `local`. | Both, same rules. |
| `/git-parity:feature <name>` | Where the branches of one feature stand in every repository: ahead of base, pushed, pull request, merge order. | Nothing. |
| `/git-parity:cleanup` | Lists merged branches and stale worktree records, deletes what you approve. | Local branches, after you confirm. |

Every command accepts repository paths or group names:
`/git-parity:status ~/code/api ~/code/web`, `/git-parity:remote work`.

## Which repositories

The first source that yields something wins:

1. Paths passed to the command.
2. `~/.config/git-parity/repos`, one path per line (`#` starts a comment, `~` is expanded).
3. The repository you are in.
4. Repositories found up to two levels below the current directory.

```
# ~/.config/git-parity/repos
~/notes

[work]
~/work/api
~/work/web
~/work/mobile

[oss]
~/oss/some-fork
```

With no argument every path is used. `[name]` starts a group:
`/git-parity:status work` checks only those three.

## One feature, many repositories

```
/git-parity:feature checkout work
```

```
| Repo | Branch             | vs base | Remote       | PR       | Note                                             |
|------|--------------------|---------|--------------|----------|--------------------------------------------------|
| api  | feat/checkout-core | +3      | pushed       | #41 OPEN |                                                  |
| api  | feat/checkout-tax  | +5      | never pushed | -        | stacked on feat/checkout-core: merge that one first |
| web  | feat/checkout-page | +2 / -4 | 1 unpushed   | none     |                                                  |
```

The pattern matches any part of the branch name; globs work too
(`'feat/checkout-*'`).

## Forks

If a repository has a remote named `upstream`, the base branch follows it:
`remote` fast-forwards your local base from `upstream`, and the report shows
`FORK-BEHIND n` until you push the base to your fork.

## Protected branches

The base branch (`origin/HEAD`, else `main`, else `master`) is never offered for
push. Add more names, one per line, to `~/.config/git-parity/never-push`.

## Reading the report

Rows are ordered by how much they need you. Repositories with nothing to say are
collapsed into the `Clean` line.

| State | Meaning | What git-parity does |
|---|---|---|
| `DIVERGED` | Local and remote both have new commits. | Nothing. Explains both sides. |
| `IN-PROGRESS` | A rebase, merge or cherry-pick is unfinished. | Nothing. |
| `STALE` | Fetch failed; the data may be old. | Reports with what it has. |
| `DIRTY n` | `n` uncommitted files. | Nothing. Never pulls over them. |
| `AHEAD n` | `n` commits not pushed. | Offers a push in `local`/`full`. |
| `BEHIND n` | Remote has `n` new commits. | Fast-forwards in `remote`/`full`. |
| `DETACHED` | No branch checked out. | Nothing. |
| `NO-UPSTREAM` | Branch never pushed. | Offers a push in `local`/`full`. |
| `GONE` | Remote branch was deleted, usually after a merge. | Nothing. |
| `FORK-BEHIND n` | Your fork's base is `n` commits behind `upstream`. | Fast-forwards the local base in `remote`/`full`; you push it. |
| `BRANCHES` | Current branch is fine; another branch needs attention. | See Detail. |
| `OK` | Clean, with something worth knowing (for example `main updated +3`). | Done. |

## Documentation

- [Guide](docs/guide.md): solo, team, large repositories, many repositories.
- [How it works](docs/how-it-works.md): architecture and every decision the script makes.
- [Safety](docs/safety.md): the full list of what it never does.

## Development

```bash
bash tests/run.sh
```

The suite builds throwaway repositories with local bare remotes, one scenario per
state, and checks both the report and the resulting refs. To try the plugin from
a checkout: `claude --plugin-dir .`

Issues and pull requests are welcome. Please add a scenario to `tests/run.sh`
for any behavior change.

## FAQ

**Does it work with GitLab, Bitbucket or a self-hosted server?**
Yes for `status`, `remote`, `cleanup` and pushes: those are plain git. Pull
request lookup and creation use `gh`, so they are GitHub only for now.

**Why did it skip a repository?**
Because acting was not provably safe: uncommitted changes, diverged history, an
unfinished rebase, a detached HEAD. The report says which, and what to run.

**My feature branch shows "tracks origin/main".**
It was created with `git switch -c feat origin/main`, so git thinks its upstream
is `main`. git-parity treats it as never pushed and offers `push -u origin feat`,
which fixes the tracking.

**Will it ever merge my feature branch into main?**
No. That is what pull requests are for.

## License

[MIT](LICENSE)
