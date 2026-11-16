# git-parity

**Mantenha branches locais e remotas em paridade em todos os seus repositórios, com um comando no Claude Code, Codex ou Antigravity (Gemini).**

O `git-parity` verifica cada repositório em que você trabalha, faz fast-forward do
que é seguro, oferece enviar o que só existe na sua máquina e entrega um relatório
curto com o próximo passo exato para tudo o que ele deixou como estava.

[English](README.md)

```
git-parity full · 4 repo(s) · 2 need attention · fetched in 1s

| Repo | Branch     | State       | Detail                    |
|------|------------|-------------|---------------------------|
| app  | main       | DIRTY 1     | uncommitted changes       |
| web  | feat/login | NO-UPSTREAM | never pushed, 1 commit(s) |
| api  | feat/pay   | OK          | main updated +1           |

Clean (1): docs

Push candidates (ask before each push)
- web · feat/login · never pushed, 1 commit(s) · git -C ~/web push -u origin feat/login

Next steps
- app: commit or stash 1 file(s): git -C ~/app status --short
- web: publish the branch: git -C ~/web push -u origin feat/login
```

O script imprime em inglês; o Claude apresenta o relatório no seu idioma.

## Por quê

- **Seguro por construção.** Só fast-forward. Nunca faz pull por cima de mudanças
  não commitadas e nunca força, reseta, faz stash, rebase, troca ou apaga branch.
- **Nada sai da sua máquina sem um sim.** Push e pull request são oferecidos um
  repositório por vez.
- **Atualiza a branch base sem sair da sua feature branch.** A `main` fica em dia
  enquanto você continua onde está.
- **Rápido e barato.** Um script bash faz fetch de todos os repositórios em
  paralelo e imprime o relatório pronto. O modelo lê um resultado em vez de rodar
  quinze comandos git.
- **Sem dependências.** bash e git. `gh` é opcional, para pull requests.

## Instalação

Funciona no **Claude Code**, no **Codex** e no **Google Antigravity** (sucessor do Gemini CLI),
no terminal e nos apps desktop. O Gemini CLI continua suportado.

### Claude Code (terminal, app desktop, IDE)

```
/plugin marketplace add Dev-Wesley-13/git-parity
/plugin install git-parity@git-parity
```

Pelo shell: `claude plugin marketplace add Dev-Wesley-13/git-parity` e
`claude plugin install git-parity@git-parity`. Atualize com `/plugin update git-parity@git-parity`.

### Codex (CLI e app desktop)

```bash
codex plugin marketplace add Dev-Wesley-13/git-parity
codex plugin add git-parity@git-parity
```

### Antigravity (CLI `agy` e app desktop)

```bash
agy plugin install https://github.com/Dev-Wesley-13/git-parity
```

No app desktop, instale o mesmo repositório pela página de Plugins em Customizations. O
Antigravity expõe os comandos como skills: peça em linguagem natural ("rode o git-parity status").

### Gemini CLI

```bash
gemini extensions install https://github.com/Dev-Wesley-13/git-parity
```

### Windows

O script é bash. No Windows use Git Bash, ou WSL quando os repositórios estão lá.

### O que funciona onde

| | Claude Code | Codex | Antigravity | Gemini CLI |
|---|---|---|---|---|
| Os oito comandos | Sim | Sim, como skills | Sim, como skills | Sim |
| Relatório chega sem tool call extra | Sim | Não | Não | Sim |
| Lembrete ao abrir a sessão | Sim (opcional) | Não | Não | Não |
| Verificado pelo autor | CLI e desktop, sessões reais | CLI (WSL) e desktop (Windows), sessões reais | App desktop, sessão real | Instala e carrega |

No Antigravity, o app desktop foi testado de ponta a ponta com o plugin carregado de uma pasta de
projeto (`.agents/plugins/`); `agy plugin install` e a instalação por URL dentro do app não foram
exercitados. No Gemini CLI foi verificado que os comandos instalam e carregam, sem conversa completa.

## Comandos

| Comando | O que faz | Altera |
|---|---|---|
| `/git-parity:status` | Só relatório. | Nada (roda `git fetch`). |
| `/git-parity:remote` | Traz o remoto: fast-forward de toda branch que está só atrás. | Branches locais, só fast-forward. |
| `/git-parity:local` | Acha trabalho que só existe na sua máquina e oferece push e pull request. | Remoto, após você confirmar cada um. |
| `/git-parity:full` | `remote`, depois `local`. | Ambos, mesmas regras. |
| `/git-parity:feature <nome>` | Onde estão as branches de uma feature em cada repositório: à frente da base, enviada, pull request, ordem de merge. | Nada. |
| `/git-parity:cleanup` | Lista branches já mergeadas e registros de worktree obsoletos, apaga o que você aprovar. | Branches locais, após você confirmar. |
| `/git-parity:prs` | Seus pull requests abertos com estado de CI, review e conflito, mais os que aguardam seu review. | Nada. |
| `/git-parity:whats-new` | O que entrou na branch base e quais desses arquivos você também alterou. | Nada. |

Todo comando aceita caminhos ou nomes de grupo:
`/git-parity:status ~/code/api ~/code/web`, `/git-parity:remote trabalho`.

## Quais repositórios

Vale a primeira fonte que retornar algo:

1. Caminhos passados ao comando.
2. `~/.config/git-parity/repos`, um caminho por linha (`#` inicia comentário, `~` é expandido).
3. O repositório em que você está.
4. Repositórios até dois níveis abaixo do diretório atual.

No arquivo `repos`, uma linha `[nome]` inicia um grupo. Sem argumento, todos os
caminhos são usados; `/git-parity:status trabalho` verifica só aquele grupo.

```
# ~/.config/git-parity/repos
[trabalho]
~/trabalho/api
~/trabalho/web
```

## Forks

Se o repositório tem um remoto chamado `upstream`, a base segue ele: `remote`
faz fast-forward da base local a partir do `upstream`, e o relatório mostra
`FORK-BEHIND n` até você enviar a base para o seu fork.

## GitHub e GitLab

O que é git puro funciona em qualquer host. Recursos de pull request usam a CLI
do host, escolhida pela URL do `origin`: `gh` no GitHub, `glab` no GitLab (merge
requests). Sem a CLI, essas partes são puladas e o relatório avisa. Para servidor
próprio, defina `GIT_PARITY_FORGE=github` ou `GIT_PARITY_FORGE=gitlab`.

## Lembrete ao abrir a sessão (opcional)

```
echo "session_hook=on" >> ~/.config/git-parity/config
```

Com isso, ao abrir o Claude Code aparece uma linha quando algo precisa de você.
Não imprime nada se tudo está limpo e nunca altera nada. Vem desligado porque
adiciona um fetch a cada início de sessão.

## Branches protegidas

A branch base (`origin/HEAD`, senão `main`, senão `master`) nunca é oferecida para
push. Adicione outros nomes, um por linha, em `~/.config/git-parity/never-push`.

## Lendo o relatório

As linhas vêm ordenadas por urgência. Repositórios sem nada a dizer ficam na linha
`Clean`.

| Estado | Significado | O que o git-parity faz |
|---|---|---|
| `DIVERGED` | Local e remoto têm commits novos. | Nada. Explica os dois lados. |
| `IN-PROGRESS` | Rebase, merge ou cherry-pick inacabado. | Nada. |
| `STALE` | Fetch falhou; os dados podem estar velhos. | Reporta com o que tem. |
| `DIRTY n` | `n` arquivos não commitados. | Nada. Nunca faz pull por cima. |
| `AHEAD n` | `n` commits não enviados. | Oferece push em `local`/`full`. |
| `BEHIND n` | O remoto tem `n` commits novos. | Fast-forward em `remote`/`full`. |
| `DETACHED` | Nenhuma branch em uso. | Nada. |
| `NO-UPSTREAM` | Branch nunca enviada. | Oferece push em `local`/`full`. |
| `GONE` | Branch remota apagada, em geral após merge. | Nada. |
| `FORK-BEHIND n` | A base do seu fork está `n` commits atrás do `upstream`. | Fast-forward da base local em `remote`/`full`; o push é seu. |
| `BRANCHES` | Branch atual em ordem; outra branch pede atenção. | Veja Detail. |
| `OK` | Limpo, com algo que vale saber (ex.: `main updated +3`). | Feito. |

## Documentação

Em inglês: [Guia](docs/guide.md), [Como funciona](docs/how-it-works.md),
[Segurança](docs/safety.md).

## Desenvolvimento

```bash
bash tests/run.sh
```

Para testar o plugin a partir do checkout: `claude --plugin-dir .`

## Licença

[MIT](LICENSE)
