# git-parity

[![CI](https://github.com/Dev-Wesley-13/git-parity/actions/workflows/ci.yml/badge.svg)](https://github.com/Dev-Wesley-13/git-parity/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Keep local and remote git branches in parity across all your repositories, from one command in Claude Code, Codex or Antigravity (Gemini).**

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

Works in **Claude Code**, **Codex** and **Google Antigravity** (the successor of Gemini CLI),
in the terminal and in the desktop apps. Gemini CLI is still supported.

### Claude Code (terminal, desktop app, IDE)

```
/plugin marketplace add Dev-Wesley-13/git-parity
/plugin install git-parity@git-parity
```

The same commands work in the desktop app; from a shell use
`claude plugin marketplace add Dev-Wesley-13/git-parity` and
`claude plugin install git-parity@git-parity`. Update with
`/plugin update git-parity@git-parity`, remove with `/plugin uninstall git-parity@git-parity`.
Commands: `/git-parity:status`, `/git-parity:remote`, and so on.

### Codex (CLI and desktop app)

```bash
codex plugin marketplace add Dev-Wesley-13/git-parity
codex plugin add git-parity@git-parity
```

Then ask for it by name ("use the git-parity status skill") or type `$` and pick a skill.

### Antigravity (CLI `agy` and desktop app)

```bash
agy plugin install https://github.com/Dev-Wesley-13/git-parity
```

In the desktop app, install the same repository from the Plugins page of Customizations
(or ask the agent to install it from the GitHub URL). Antigravity exposes the commands as
skills, so type `/git-parity:status`-style requests as a message ("run git-parity status").

### Gemini CLI

```bash
gemini extensions install https://github.com/Dev-Wesley-13/git-parity
```

Commands are `/git-parity:status`, `/git-parity:remote` and so on. Gemini CLI asks you to
confirm the script the first time each command runs.

### Windows

The script is bash. On Windows use Git Bash, or WSL when your repositories live there.
The skills tell the agent to run it that way. Desktop agents run in a sandbox and will
ask your permission the first time they call `wsl.exe`; that is expected.
If you cloned the repository with an older version on Windows, update it: versions before
1.3.2 could be checked out with CRLF line endings, which bash cannot run.

### First run (30 seconds)

After installing, tell git-parity which repositories you work on. One path per line:

```bash
mkdir -p ~/.config/git-parity
printf '%s\n' ~/code/api ~/code/web ~/code/mobile > ~/.config/git-parity/repos
```

Then, in any session: `/git-parity:status`. Without that file it checks the repository you are in,
or the repositories found up to two levels below the current folder. More in
[Which repositories](#which-repositories).

### What works where

| | Claude Code | Codex | Antigravity | Gemini CLI |
|---|---|---|---|---|
| All eight commands | Yes | Yes, as skills | Yes, as skills | Yes |
| Report arrives with no extra tool call | Yes | No, the agent runs the script once | No, same | Yes |
| Session-start reminder | Yes (opt-in) | No | No | No |
| Verified by the author | CLI and desktop, real sessions | CLI (WSL) and desktop (Windows), real sessions | Desktop app, real session; see note | Installs and loads; see note |

Note: on Antigravity the desktop app was tested end to end with the plugin loaded from a project
folder (`.agents/plugins/`); `agy plugin install` and the in-app install from a URL were not
exercised. Gemini CLI was verified to install and load every command, but no full conversation
was run. The same script and test suite sit under all of them.
[Reports](https://github.com/Dev-Wesley-13/git-parity/issues) are welcome.

## Commands

| Command | What it does | Changes |
|---|---|---|
| `/git-parity:status` | Report only. | Nothing (runs `git fetch`). |
| `/git-parity:remote` | Brings remote changes in: fast-forwards every branch that is strictly behind. | Local branches, fast-forward only. |
| `/git-parity:local` | Finds work that is only on your machine and offers push and pull request. | Remote, after you confirm each one. |
| `/git-parity:full` | `remote`, then `local`. | Both, same rules. |
| `/git-parity:feature <name>` | Where the branches of one feature stand in every repository: ahead of base, pushed, pull request, merge order. | Nothing. |
| `/git-parity:cleanup` | Lists merged branches and stale worktree records, deletes what you approve. | Local branches, after you confirm. |
| `/git-parity:prs` | Your open pull requests with CI, review and conflict state, plus the ones waiting for your review. | Nothing. |
| `/git-parity:whats-new` | What came into the base branch, and which of those files you also changed. | Nothing. |

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

## GitHub and GitLab

Everything that is plain git works with any host. Pull request features use the
host's own CLI, picked from the `origin` URL:

| Host | CLI | Used by |
|---|---|---|
| GitHub | [`gh`](https://cli.github.com) | `prs`, `feature`, `cleanup`, pull request creation |
| GitLab | [`glab`](https://docs.gitlab.com/cli/) | the same, with merge requests |

Without the CLI those parts are skipped and the report says so. For a
self-hosted server whose URL contains neither name, set
`GIT_PARITY_FORGE=github` or `GIT_PARITY_FORGE=gitlab`.

## A reminder when you open a session (optional)

```
echo "session_hook=on" >> ~/.config/git-parity/config
```

With this, opening Claude Code prints one line when something needs you:
`git-parity: 2 of 5 repositories need attention.` It prints nothing when all is
clean, never changes anything, and gives each fetch 5 seconds. It is off by
default because it adds a fetch to every session start.

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

## Token cost

The work is done by a script, so the model mostly reads one finished report.

| | Tokens (estimated) |
|---|---|
| Always in context, Claude Code (4 model-invocable skills; the others are user-only) | about 290 |
| Always in context, Codex and Gemini (all 8 skills listed) | about 540 |
| One command: skill file | 600 to 800 |
| One command: the report | 40 to 600 (about 110 for a clean `status` of 5 repositories) |

Measured end to end: a `status` on Claude Haiku cost about $0.013, and on the Codex CLI about 4,700
tokens in total, most of which is each agent's own overhead. Estimates use about 3.6 characters per token.

## Tested models

`status` was run, with correct results, on Claude Haiku 5.5, GPT Terra (Codex, low effort),
Gemini 3.8 Flash (Antigravity) and the stronger default models of each agent. `whats-new`, which needs
the most judgment, was run on Haiku.

## Documentation

- [Guide](docs/guide.md): solo, team, large repositories, many repositories.
- [How it works](docs/how-it-works.md): architecture and every decision the script makes.
- [Safety](docs/safety.md): the full list of what it never does.
- [Testing on each agent](docs/testing-agents.md): a short manual checklist.

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
Yes for `status`, `remote`, `whats-new` and pushes: those are plain git, on any
host. Pull and merge request features work on GitHub (`gh`) and GitLab (`glab`).
GitLab support is tested against a simulated `glab`; please open an issue if a
real server behaves differently.

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
