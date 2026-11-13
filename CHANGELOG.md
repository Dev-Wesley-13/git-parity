# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

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
