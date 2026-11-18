# Contributing

Issues and pull requests are welcome: bug reports, code improvements and documentation fixes.
git-parity is maintained by **Wesley Rafael Fonseca**, who alone decides what is accepted and
merged.

## Before you open a pull request

1. Run the checks, and make sure they all pass:

   ```bash
   bash tests/run.sh
   shellcheck scripts/git-parity.sh tests/run.sh
   ```

2. Keep LF line endings (no CRLF). The repository's `.gitattributes` turns line-ending conversion
   off, and the test suite fails if a CR appears in a shipped file.
3. Add a scenario to `tests/run.sh` for any behavior change. The suite builds throwaway
   repositories with local bare remotes and checks both the report and the resulting refs.
4. Keep the script compatible with bash 3.2 (macOS): no associative arrays, no `mapfile`.
5. Keep the safety rules in [docs/safety.md](docs/safety.md). A change that makes the script
   push, force, reset, stash, rebase, switch or delete on its own will not be merged.
6. Skills are read by models on every run: keep them short, and keep the same wording in the
   matching `commands/git-parity/*.toml`.

To try your checkout as a plugin: `claude --plugin-dir .`

## Reporting a bug

Open an [issue](https://github.com/Dev-Wesley-13/git-parity/issues/new/choose) with the report
git-parity printed, your agent and its version, your operating system, and `git --version`.
Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Contributor License Agreement

By submitting a pull request or any other contribution to this repository, you expressly agree to
assign and transfer to **Wesley Rafael Fonseca**, irrevocably, free of charge, perpetually and
worldwide, all economic copyright, title and interest in and to your contribution. This lets the
author keep sole ownership of the project, relicense the work in the future under any terms, and
distribute your contribution under the Apache License 2.0.

You also declare that the contribution is your own original creation and does not infringe the
rights of any third party.

Where the law does not allow such an assignment (for example, moral rights in some countries), you
grant Wesley Rafael Fonseca an irrevocable, perpetual, worldwide, royalty-free, exclusive license to
the same extent, and you waive, or agree not to assert, any rights that cannot be assigned.

The pull request template asks you to confirm this agreement. A pull request without that
confirmation will not be merged.
