# Contributing

Issues and pull requests are welcome.

## Before you open a pull request

1. Run the checks:

   ```bash
   bash tests/run.sh
   shellcheck scripts/git-parity.sh tests/run.sh
   ```

2. Add a scenario to `tests/run.sh` for any behavior change. The suite builds throwaway
   repositories with local bare remotes and checks both the report and the resulting refs.
3. Keep the script compatible with bash 3.2 (macOS): no associative arrays, no `mapfile`.
4. Keep the safety rules in [docs/safety.md](docs/safety.md). A change that makes the script
   push, force, reset, stash, rebase, switch or delete will not be merged.
5. Skills are read by models on every run: keep them short, and keep the same wording in the
   matching `commands/git-parity/*.toml`.

To try your checkout as a plugin: `claude --plugin-dir .`

## Reporting a bug

Include the report git-parity printed, your agent and its version, your operating system, and
`git --version`.

## License of contributions

The project is licensed under the [PolyForm Shield License 1.0.0](LICENSE). By submitting a
contribution you agree that it is licensed to the project's maintainer under terms that allow
the maintainer to distribute it under that license and to relicense the project in the future.
