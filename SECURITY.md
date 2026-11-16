# Security

## What git-parity can do on your machine

It runs `git` in the repositories you track. By itself the script only fetches, fast-forwards
branches that are strictly behind, and writes its own list in `~/.config/git-parity/`. It sends
nothing anywhere except through `git fetch` and, if you use them, `gh` or `glab`. The complete
list of guarantees is in [docs/safety.md](docs/safety.md).

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private reporting:
the **Security** tab of the repository, then **Report a vulnerability**.

Useful to include: what you ran, the report that was printed, and `git reflog -5` of the
affected repository.

## If git-parity changed something it should not have

That is treated as a security bug. Fast-forwards are recorded in the reflog and can be undone
with `git branch -f <branch> <previous-sha>`. Report it as above.

## Supported versions

Fixes go into the latest release.
