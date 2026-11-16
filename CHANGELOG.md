# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.4.1] - 2026-11-16

### Added

- Plugin logo (`assets/logo.svg`) for the Antigravity plugin list.

### Changed

- Docs: `agy plugin validate` and `agy plugin install` from GitHub are now verified.

## [1.4.0] - 2026-11-16

### Added

- Automatic detection. With no saved list, git-parity finds the repositories of the current
  project (same parent folder, same remote owner) or of a folder of projects, proposes named
  groups, and the agent asks before saving. No first-run setup.
- `/git-parity:add`: save, list (`--list`) or remove (`--remove`) tracked repositories and
  groups. The script gained `detect` and `add`.
- Docs reorganized: getting started, commands, configuration, agents, troubleshooting;
  `CONTRIBUTING.md` and `SECURITY.md`.

### Changed

- **License: PolyForm Shield 1.0.0 from this version on.** Free to use, copy, modify and
  share; not to be offered as a competing product. Versions 1.0.0 to 1.3.3 remain under MIT.
- Until a list is saved, `remote`, `full`, `local` and `cleanup` act on the current
  repository only. Previously, run from a folder of projects, they acted on every repository
  found there.
- A note is printed when the current repository is not in the saved list.

## [1.3.3] - 2026-11-16

### Changed

- The Windows note in every skill now gives the exact `wsl.exe ... wslpath` command, with
  forward slashes and no inner quotes. Without it, the Codex desktop app needed four attempts and
  the Antigravity desktop app three (quotes are stripped by PowerShell, backslashes eaten by bash).

## [1.3.2] - 2026-11-16

### Fixed

- Windows: clones converted the scripts to CRLF and bash refused to run them
  (found by running the Codex desktop app on Windows). `.gitattributes` now forces
  LF for scripts, skills and manifests, and the test suite fails if a CR appears.

## [1.3.1] - 2026-11-16

### Added

- Antigravity: native `plugin.json` at the repository root, so
  `agy plugin install https://github.com/Dev-Wesley-13/git-parity` installs it as a
  native plugin (skills load as they are).
- Windows note in every skill: run the script with Git Bash, or `wsl bash` when the
  repositories live in WSL.

### Changed

- README installation section covers Claude Code, Codex, Antigravity and Gemini CLI,
  terminal and desktop, with a table of what works where.

## [1.3.0] - 2026-11-13

### Added

- Codex support: `.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json`.
- Gemini CLI support: `gemini-extension.json` and `/git-parity:*` commands.
- Skills no longer depend on Claude Code to locate the script: other agents are
  told where it is and run it once.
- The script accepts all arguments as one quoted string and ignores empty ones,
  which is how some agents pass them.

### Changed

- Skills that write (`remote`, `local`, `full`, `cleanup`) say in their
  description that they run only on explicit request, for agents that do not
  support user-only skills.

## [1.2.0] - 2026-11-13

### Added

- `/git-parity:prs`: your open pull requests with CI, review and conflict state,
  ordered by urgency, plus the ones waiting for your review.
- `/git-parity:whats-new`: commits that came into the base branch, the areas they
  touch, and the files also changed on your current branch.
- GitLab: merge requests through `glab` in `prs`, `feature`, `cleanup`, `local`
  and `full`. `GIT_PARITY_FORGE=github|gitlab` overrides host detection for
  self-hosted servers.
- Optional session-start hook: one line when repositories need attention. Off by
  default; enable with `session_hook=on` in `~/.config/git-parity/config`.

## [1.1.0] - 2026-11-13

### Added

- Groups: `[name]` sections in `~/.config/git-parity/repos`; pass a group name
  wherever a path is accepted.
- `/git-parity:feature <pattern>`: where the branches of one feature stand in
  every repository, with pull request state and merge order for stacked branches.
- `/git-parity:cleanup`: lists branches merged into the base, squash-merged
  branches with a merged pull request, and stale worktree records. Deletes only
  what you approve.
- Forks: when a remote named `upstream` exists, the base branch is compared with
  it and fast-forwarded from it; the report shows how far the fork is behind.

### Fixed

- `local` and `full` offer "push" and "skip" when a repository has a single push
  candidate.

## [1.0.0] - 2026-11-13

### Added

- `scripts/git-parity.sh`: parallel fetch, per-repository state detection and a
  ready-to-read report with next steps.
- Skills `status`, `remote`, `local` and `full`.
- Repository discovery from arguments, `~/.config/git-parity/repos`, the current
  repository, or a two-level directory scan.
- `never-push` list for branches that must never be offered for push.
- Test suite (`tests/run.sh`) and CI on Linux and macOS.
