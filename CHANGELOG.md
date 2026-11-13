# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-13

### Added

- `scripts/git-parity.sh`: parallel fetch, per-repository state detection and a
  ready-to-read report with next steps.
- Skills `status`, `remote`, `local` and `full`.
- Repository discovery from arguments, `~/.config/git-parity/repos`, the current
  repository, or a two-level directory scan.
- `never-push` list for branches that must never be offered for push.
- Test suite (`tests/run.sh`) and CI on Linux and macOS.
