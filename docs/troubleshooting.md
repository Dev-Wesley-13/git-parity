# Troubleshooting

## The report says a repository was skipped

That is the tool working as designed: it only acts when acting is provably safe.

| Report says | What to do |
|---|---|
| `DIRTY` | Commit or stash, then run the command again. |
| `DIVERGED` | Ask the agent to explain both sides; choose merge or rebase yourself. |
| `IN-PROGRESS` | Finish or abort the rebase, merge or cherry-pick. |
| `DETACHED` | Check out a branch. |
| `STALE` | The fetch failed. Check network, VPN or credentials: `git -C <repo> fetch`. |
| `base branch unknown` | `git -C <repo> remote set-head origin -a`. |

## A repository is missing from the report

- With a saved list, only the list is checked. The report ends with a note when the
  repository you are in is not on it; say yes when the agent offers to add it, or run
  `/git-parity:add <path>`.
- Without a saved list, detection covers repositories in the same parent folder with the
  same remote owner. A repository elsewhere, or owned by someone else, has to be added.
- `bash scripts/git-parity.sh detect` shows what detection sees; `add --list` shows what is
  saved.

## `remote` updated only one repository

No list is saved yet. Commands that change something stay on the current repository until
you save the detected groups. Run `status`, answer yes to the save question, run `remote`
again.

## "tracks origin/main instead of its own remote branch"

The branch was created with `git switch -c feat origin/main`, so git thinks its upstream is
`main`. git-parity treats it as never pushed and offers `push -u origin feat`, which fixes
the tracking.

## Pull requests show `-` or the repository appears under "Skipped"

The host CLI is missing or not logged in: `gh auth status` (GitHub) or `glab auth status`
(GitLab). For a self-hosted server, set `GIT_PARITY_FORGE`.

## Windows: bash reports `$'\r': command not found`

The script was checked out with CRLF line endings. Update to 1.3.2 or later and reinstall
the plugin; the repository now forces LF.

## Windows: the agent's command fails with exit code 1 before running the script

Quoting. Use the command from [agents.md](agents.md#windows) exactly: forward slashes in the
path and no inner quotes.

## The command is not found after installing

Plugins load when a session starts. Open a new session. In the Claude desktop app the slash
menu of a session that has not started yet may not list local plugins; type the command in
full.

## Something else

Open an [issue](https://github.com/Dev-Wesley-13/git-parity/issues) with the report that was
printed, your agent and its version, and your operating system. If git-parity ever changes
something it should not have, see [SECURITY.md](../SECURITY.md).
