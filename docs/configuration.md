# Configuration

Nothing here is required. git-parity works with no configuration at all.

## Which repositories

The first source that yields something wins:

1. Paths or group names passed to the command.
2. The saved list, `~/.config/git-parity/repos`.
3. Detection, when nothing is saved.

### Detection

- **Inside a repository:** the repositories in the same parent folder that share its remote
  owner form its group. A repository alone is simply checked on its own.
- **In a folder of projects:** every repository up to two levels below, grouped by remote
  owner. Hidden folders and `node_modules` are skipped.
- **Group names** come from the common prefix of the folder names (`shop-api`, `shop-web`
  give `shop`); a single repository is named after its remote.

Detection flags what it cannot decide, and the agent asks you: a repository with no remote,
a repository named like a group but owned by someone else, more than ten repositories.

Until a list is saved, `remote`, `full`, `local` and `cleanup` act on the current
repository only. Read-only commands cover the detected group.

To see what would be detected without running anything else:

```bash
bash scripts/git-parity.sh detect
```

### The saved list

Written by `/git-parity:add` (or by the agent, after you agree):

```
# ~/.config/git-parity/repos
~/notes

[shop]
~/code/shop-api
~/code/shop-web

[oss]
~/oss/some-fork
```

One path per line, `#` starts a comment, `~` is expanded, `[name]` starts a group. You can
edit it by hand; `add` keeps a copy of the previous version in `repos.bak`.

## Protected branches

The base branch (`origin/HEAD`, else `main`, else `master`) is never offered for push. Add
more names, one per line, to `~/.config/git-parity/never-push`.

## GitHub and GitLab

Pull request features use the host's own CLI, picked from the `origin` URL: `gh` for GitHub,
`glab` for GitLab. Without the CLI those parts are skipped and the report says so. For a
self-hosted server whose URL contains neither name, set `GIT_PARITY_FORGE=github` or
`GIT_PARITY_FORGE=gitlab`.

## Forks

Add the original repository as a remote named `upstream`. `remote` then keeps your local
base equal to `upstream`, and the report shows `FORK-BEHIND n` until you push the base to
your fork.

## A reminder when you open a session (Claude Code, optional)

```
echo "session_hook=on" >> ~/.config/git-parity/config
```

Opening Claude Code then prints one line when something needs you, and nothing when all is
clean. It never changes anything and gives each fetch 5 seconds. It is off by default
because it adds a fetch to every session start.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `GIT_PARITY_CONFIG_DIR` | `~/.config/git-parity` | Where `repos`, `never-push` and `config` live. |
| `GIT_PARITY_JOBS` | `8` | Repositories processed in parallel. |
| `GIT_PARITY_FETCH_TIMEOUT` | `30` | Seconds before a fetch is abandoned (needs `timeout`). |
| `GIT_PARITY_FORGE` | from `origin` URL | `github` or `gitlab`, for self-hosted servers. |
