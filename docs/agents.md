# Agents

One repository serves four agents. The script and its test suite are the same everywhere;
what differs is how each agent loads the skills and runs the script.

| Agent | Reads | How the script runs |
|---|---|---|
| Claude Code | `.claude-plugin/`, `skills/`, `hooks/claude-hooks.json` | Injected when the skill loads: the report arrives with no extra tool call |
| Codex | `.codex-plugin/`, `.agents/plugins/marketplace.json`, `skills/` | The agent runs it once, following the skill |
| Antigravity | `plugin.json` (root), `skills/` | The agent runs it once, following the skill |
| Gemini CLI | `gemini-extension.json`, `commands/git-parity/*.toml`, `skills/` | Injected by the command, after you confirm |

Requirements everywhere: git 2.23+ and bash 3.2+.

## Claude Code (terminal, desktop app, IDE)

```
/plugin marketplace add Dev-Wesley-13/git-parity
/plugin install git-parity@git-parity
```

From a shell: `claude plugin marketplace add Dev-Wesley-13/git-parity` and
`claude plugin install git-parity@git-parity`. Start a new session afterwards.

- Update: `/plugin update git-parity@git-parity`
- Remove: `/plugin uninstall git-parity@git-parity`
- Commands: `/git-parity:status`, `/git-parity:remote`, and so on. `status`, `feature`,
  `prs`, `whats-new` and `add` can also be picked up by the model when you ask in plain
  words; the commands that change something run only when you type them.

## Codex (CLI and desktop app)

```bash
codex plugin marketplace add Dev-Wesley-13/git-parity
codex plugin add git-parity@git-parity
```

Ask for a skill by name ("use the git-parity status skill") or type `$` and pick one.
To update, remove and add again: `codex plugin remove git-parity@git-parity`.

The desktop app and a CLI running under the same user profile share one plugin list. A CLI inside WSL has its own.

## Antigravity (CLI and desktop app)

```bash
agy plugin install https://github.com/Dev-Wesley-13/git-parity
```

Antigravity exposes the commands as skills: ask in plain words ("run git-parity status").
`agy plugin validate` reports one warning, about the `commands/` folder: those files are the
Gemini CLI commands, which Antigravity does not load. The nine skills are what it uses.
For a single project you can also copy `plugin.json`, `skills/` and `scripts/` into
`<project>/.agents/plugins/git-parity/`; the desktop app loads it from there.

## Gemini CLI

```bash
gemini extensions install https://github.com/Dev-Wesley-13/git-parity
```

Commands are `/git-parity:status` and so on. Gemini CLI asks you to confirm the script the
first time each command runs. The commands expect the extension in
`~/.gemini/extensions/git-parity/`, where `extensions install` puts it; with
`extensions link`, use the skills instead of the slash commands.

## Windows

The script is bash, so on Windows it runs through Git Bash, or through WSL when your
repositories live there. The skills tell the agent the exact command:

```
wsl.exe -d <distro> -- bash -c 'bash "$(wslpath -u <path-with-forward-slashes>/scripts/git-parity.sh)" status'
```

Desktop agents run in a sandbox and ask your permission the first time they call `wsl.exe`.
That is expected. The repository forces LF line endings (`.gitattributes`), so a Windows
clone runs as is (bash rejects CRLF line endings).

## What was verified

| Agent | Verified in a real session | Not exercised |
|---|---|---|
| Claude Code | CLI and desktop app: `status`, `remote`, `local`, `full`, `feature`, `cleanup` and `whats-new`, including declined pushes and deletions; `status`, `whats-new`, detection and the save question on Haiku | Accepting a push or a pull request end to end; `prs` and `add` as skills (script level only) |
| Codex | CLI in WSL and desktop app on Windows: install from GitHub and `status`, including on GPT Terra | The other commands; install through the app's own Plugins page |
| Antigravity | Desktop app on Windows: `status`, with the plugin loaded from the project folder, including on Gemini 3.8 Flash. CLI: `agy plugin validate` passes and `agy plugin install` from GitHub installs the nine skills | A conversation in the CLI; install through the app; the other commands |
| Gemini CLI | `extensions validate`, install from GitHub, every skill and command loads | Any conversation |

GitLab support was tested against a simulated `glab` only. If something behaves differently
for you, please [open an issue](https://github.com/Dev-Wesley-13/git-parity/issues) with the
agent version and what you saw.

## Trying it on an agent yourself

Nothing below changes anything unless you approve it.

1. Install, open a session inside a repository.
2. `status`: the report appears; if nothing is saved yet, the agent asks whether to save
   the detected groups.
3. `remote`: branches behind are fast-forwarded; dirty repositories are skipped.
4. `local`: push candidates are listed; answer "skip" and check that nothing was pushed.
5. `feature <name>` and `cleanup` (answer "keep").
