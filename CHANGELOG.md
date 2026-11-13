# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

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
