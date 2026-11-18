# git-parity

[![CI](https://github.com/Dev-Wesley-13/git-parity/actions/workflows/ci.yml/badge.svg)](https://github.com/Dev-Wesley-13/git-parity/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**Keep local and remote git branches in parity across all your repositories, from one command in Claude Code, Codex or Antigravity (Gemini).**

git-parity checks every repository of your project, fast-forwards what is safe to
fast-forward, offers to push what exists only on your machine, and gives you one short
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

- **Safe by construction.** Fast-forward only. It never pulls over uncommitted changes and
  never forces, resets, stashes, rebases, switches or deletes a branch on its own.
- **Nothing leaves your machine without a yes.** Pushes and pull requests are offered one
  repository at a time.
- **It finds your repositories.** No setup: it detects the repositories of your project
  and groups them, and asks you only when it is unsure.
- **Updates the base branch without leaving your feature branch.**
- **Cheap.** One bash script does the work and prints the finished report. The model reads
  one result instead of running fifteen git commands.
- **No dependencies.** bash and git. `gh` or `glab` are optional, for pull requests.

## Install

| Agent | Command |
|---|---|
| **Claude Code** (terminal, desktop, IDE) | `/plugin marketplace add Dev-Wesley-13/git-parity` then `/plugin install git-parity@git-parity` |
| **Codex** (CLI and desktop) | `codex plugin marketplace add Dev-Wesley-13/git-parity` then `codex plugin add git-parity@git-parity` |
| **Antigravity** (CLI and desktop) | `agy plugin install https://github.com/Dev-Wesley-13/git-parity` |
| **Gemini CLI** | `gemini extensions install https://github.com/Dev-Wesley-13/git-parity` |

Then open a session inside any of your repositories and run `/git-parity:status`
(Claude Code, Gemini CLI) or ask for it: "run git-parity status" (Codex, Antigravity).

Per-agent details, Windows and WSL, updating and removing: [docs/agents.md](docs/agents.md).

## It finds your repositories

You do not list anything. The first time, git-parity looks around:

- **Inside a repository:** that is your main project. The repositories beside it that have
  the same remote owner (the same GitHub organization or user) are its group.
- **In a folder that holds several projects:** every repository up to two levels below,
  grouped by remote owner. `shop-api`, `shop-web` and `shop-app` become the group `shop`.

The report then ends with what it detected, and the agent asks whether to save it. It asks
you about anything unclear, such as a repository with no remote. Until you say yes, the
commands that change something (`remote`, `full`, `local`, `cleanup`) act on the current
repository only.

A repository somewhere else on disk? Say so ("also track ~/work/legacy-api") or run
`/git-parity:add ~/work/legacy-api`. More in [docs/configuration.md](docs/configuration.md).

## Commands

| Command | What it does | Changes |
|---|---|---|
| `status` | Report only. | Nothing (runs `git fetch`). |
| `remote` | Brings remote changes in: fast-forwards every branch that is strictly behind. | Local branches, fast-forward only. |
| `local` | Finds work that is only on your machine and offers push and pull request. | Remote, after you confirm each one. |
| `full` | `remote`, then `local`. | Both, same rules. |
| `feature <name>` | Where the branches of one feature stand in every repository: ahead of base, pushed, pull request, merge order. | Nothing. |
| `cleanup` | Lists merged branches and stale worktree records; deletes what you approve. | Local branches, after you confirm. |
| `prs` | Your open pull requests with CI, review and conflict state, plus the ones waiting for your review. | Nothing. |
| `whats-new` | What came into the base branch, and which of those files you also changed. | Nothing. |
| `add` | Saves, lists or removes tracked repositories and groups. | Only git-parity's own list. |

In Claude Code and Gemini CLI they are `/git-parity:<command>`. Every command accepts
repository paths or a group name: `/git-parity:remote shop`.
Examples and output of each one: [docs/commands.md](docs/commands.md).

## Reading the report

Rows are ordered by how much they need you. Repositories with nothing to say are collapsed
into the `Clean` line.

| State | Meaning | What git-parity does |
|---|---|---|
| `DIVERGED` | Local and remote both have new commits. | Nothing. Explains both sides. |
| `IN-PROGRESS` | A rebase, merge or cherry-pick is unfinished. | Nothing. |
| `STALE` | Fetch failed; the data may be old. | Reports with what it has. |
| `DIRTY n` | `n` uncommitted files. | Nothing. Never pulls over them. |
| `AHEAD n` | `n` commits not pushed. | Offers a push in `local`/`full`. |
| `BEHIND n` | Remote has `n` new commits. | Fast-forwards in `remote`/`full`. |
| `FORK-BEHIND n` | Your fork's base is `n` commits behind `upstream`. | Fast-forwards the local base; you push it. |
| `DETACHED` | No branch checked out. | Nothing. |
| `NO-UPSTREAM` | Branch never pushed. | Offers a push in `local`/`full`. |
| `GONE` | Remote branch was deleted, usually after a merge. | Nothing. |
| `BRANCHES` | Current branch is fine; another branch needs attention. | See Detail. |
| `OK` | Clean, with something worth knowing (for example `main updated +3`). | Done. |

## Safety in one paragraph

The script's only writes are `git fetch`, fast-forwards of branches strictly behind their
own upstream, and its own list of repositories. Pushing, opening pull requests and deleting
merged branches are done by the agent, one approval at a time, using commands the script
printed. A test suite builds real repositories for every state and checks that skipped
repositories are byte-for-byte unchanged. Full list: [docs/safety.md](docs/safety.md).

## Cost and tested models

| | Tokens (estimated at 3.6 characters per token) |
|---|---|
| Always in context, Claude Code | about 370 |
| Always in context, Codex, Antigravity and Gemini | about 620 |
| One command: the skill file | 600 to 900 |
| One command: the report | 40 to 600 (about 110 for a clean `status` of 5 repositories) |

A `status` on Claude Haiku cost about $0.013 end to end. `status` gave correct results on
Claude Haiku 5.5, GPT Terra (Codex, low effort), Gemini 3.8 Flash (Antigravity) and each
agent's stronger default models.

What was verified on which agent, honestly stated: [docs/agents.md](docs/agents.md#what-was-verified).

## Documentation

- [Getting started](docs/getting-started.md): the daily routine, solo and in a team.
- [Commands](docs/commands.md): each command with an example.
- [Configuration](docs/configuration.md): groups, protected branches, GitLab, the optional reminder.
- [Agents](docs/agents.md): Claude Code, Codex, Antigravity, Gemini CLI, Windows and WSL.
- [How it works](docs/how-it-works.md): the design and every decision the script makes.
- [Safety](docs/safety.md): what it never does, and how that is tested.
- [Troubleshooting](docs/troubleshooting.md).
- [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Trademarks](TRADEMARKS.md)

## FAQ

**Does it work with GitLab, Bitbucket or a self-hosted server?**
Everything that is plain git works with any host. Pull and merge request features work on
GitHub (`gh`) and GitLab (`glab`). GitLab was tested against a simulated `glab` only.

**Why did it skip a repository?**
Because acting was not provably safe: uncommitted changes, diverged history, an unfinished
rebase, a detached HEAD. The report says which, and what to run.

**Will it ever merge my feature branch into main?**
No. That is what pull requests are for.

**Can I run the script without an AI agent?**
Yes: `bash scripts/git-parity.sh status`. It depends only on bash and git.

## License

git-parity is open source under the **Apache License 2.0** ([LICENSE](LICENSE) and
[NOTICE](NOTICE)). It is free for any use, personal or commercial.

If you redistribute it, with or without changes, keep the copyright notices and the
[NOTICE](NOTICE) file, and state the changes you made in any file you modified.

The name "git-parity" and its logo are not covered by the code license (Apache License 2.0,
Section 6); see [TRADEMARKS.md](TRADEMARKS.md). git-parity is not affiliated with the Git project.

Contributions are accepted under the Contributor License Agreement in
[CONTRIBUTING.md](CONTRIBUTING.md).

Copyright 2026 Wesley Rafael Fonseca.
