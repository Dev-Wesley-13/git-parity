# Testing on each agent

The script is the same everywhere and is covered by `tests/run.sh`. This list
checks the part that differs: how each agent loads and runs it. Use a throwaway
repository, or real ones if you are comfortable: nothing below changes anything
unless you approve it.

## Claude Code

1. `/plugin marketplace add Dev-Wesley-13/git-parity`, `/plugin install git-parity@git-parity`, new session.
2. `/git-parity:status`: the report appears with no tool call.
3. `/git-parity:remote`: branches behind are fast-forwarded; dirty repositories are skipped.
4. `/git-parity:local`: push candidates are listed; answer "skip" and check nothing was pushed.
5. `/git-parity:feature <name>` and `/git-parity:cleanup` (answer "keep").

## Codex

1. `codex plugin marketplace add Dev-Wesley-13/git-parity`, `codex plugin add git-parity@git-parity`.
2. `codex plugin list` shows `git-parity@git-parity` as installed and enabled.
3. Ask: "Use the git-parity status skill." The agent should run `scripts/git-parity.sh status` once and show the report.
4. Ask for the `local` skill and decline the push.

## Antigravity

1. `agy plugin install https://github.com/Dev-Wesley-13/git-parity`, or install from the Plugins page of Customizations in the desktop app.
2. The plugin appears with eight skills.
3. Ask: "Use the git-parity status skill with --no-fetch." The agent should run the script and show the report. Expect a permission prompt for `wsl.exe` the first time.
4. Ask for the `local` skill and decline the push.

## Gemini CLI

1. `gemini extensions install https://github.com/Dev-Wesley-13/git-parity`.
2. `gemini extensions list` shows the extension with eight agent skills.
3. `/git-parity:status`: confirm the script when asked; the report appears.
4. `/git-parity:local`: decline the push.

If something differs from this list, please open an issue with the agent
version and what you saw.
