# git-parity

**Mantenha branches locais e remotas em paridade em todos os seus repositórios, com um comando no Claude Code, Codex ou Antigravity (Gemini).**

O git-parity verifica cada repositório do seu projeto, faz fast-forward do que é seguro,
oferece enviar o que só existe na sua máquina e entrega um relatório curto com o próximo
passo exato para tudo o que ele deixou como estava.

[English](README.md) (documentação completa)

## Por quê

- **Seguro por construção.** Só fast-forward. Nunca faz pull por cima de mudanças não
  commitadas e nunca força, reseta, faz stash, rebase, troca ou apaga branch por conta própria.
- **Nada sai da sua máquina sem um sim.** Push e pull request são oferecidos um repositório
  por vez.
- **Ele acha seus repositórios.** Sem configuração: detecta os repositórios do projeto,
  agrupa e só pergunta quando fica em dúvida.
- **Barato.** Um script bash faz o trabalho e imprime o relatório pronto.
- **Sem dependências.** bash e git. `gh` ou `glab` são opcionais, para pull requests.

## Instalação

| Agente | Comando |
|---|---|
| **Claude Code** (terminal, desktop, IDE) | `/plugin marketplace add Dev-Wesley-13/git-parity` e depois `/plugin install git-parity@git-parity` |
| **Codex** (CLI e desktop) | `codex plugin marketplace add Dev-Wesley-13/git-parity` e depois `codex plugin add git-parity@git-parity` |
| **Antigravity** (CLI e desktop) | `agy plugin install https://github.com/Dev-Wesley-13/git-parity` |
| **Gemini CLI** | `gemini extensions install https://github.com/Dev-Wesley-13/git-parity` |

Depois, abra uma sessão dentro de um dos seus repositórios e rode `/git-parity:status`
(Claude Code, Gemini CLI) ou peça: "rode o git-parity status" (Codex, Antigravity).

No Windows o script roda por Git Bash, ou por WSL quando os repositórios estão lá.
Detalhes por agente: [docs/agents.md](docs/agents.md).

## Ele acha seus repositórios

- **Dentro de um repositório:** ele é o projeto principal; os repositórios ao lado com o
  mesmo dono no remoto (a mesma organização ou usuário do GitHub) formam o grupo.
- **Numa pasta com vários projetos:** todos os repositórios até dois níveis abaixo,
  agrupados pelo dono do remoto. `loja-api`, `loja-web` e `loja-app` viram o grupo `loja`.

O relatório termina com o que foi detectado, e o agente pergunta se deve salvar. Até você
dizer sim, os comandos que alteram algo (`remote`, `full`, `local`, `cleanup`) atuam só no
repositório atual. Para um repositório em outro lugar do disco, peça ("acompanhe também
~/trabalho/api-antiga") ou rode `/git-parity:add ~/trabalho/api-antiga`.

## Comandos

| Comando | O que faz | Altera |
|---|---|---|
| `status` | Só relatório. | Nada (roda `git fetch`). |
| `remote` | Traz o remoto: fast-forward de toda branch que está só atrás. | Branches locais, só fast-forward. |
| `local` | Acha trabalho que só existe na sua máquina e oferece push e pull request. | Remoto, após você confirmar cada um. |
| `full` | `remote`, depois `local`. | Ambos, mesmas regras. |
| `feature <nome>` | Onde estão as branches de uma feature em cada repositório, com a ordem de merge. | Nada. |
| `cleanup` | Lista branches já mergeadas; apaga o que você aprovar. | Branches locais, após você confirmar. |
| `prs` | Seus pull requests abertos e os que aguardam seu review. | Nada. |
| `whats-new` | O que entrou na branch base e quais desses arquivos você também alterou. | Nada. |
| `add` | Salva, lista ou remove repositórios e grupos acompanhados. | Só a lista do próprio git-parity. |

No Claude Code e no Gemini CLI são `/git-parity:<comando>`. Todos aceitam caminhos ou o nome
de um grupo: `/git-parity:remote loja`.

## Documentação (em inglês)

[Primeiros passos](docs/getting-started.md) · [Comandos](docs/commands.md) ·
[Configuração](docs/configuration.md) · [Agentes](docs/agents.md) ·
[Como funciona](docs/how-it-works.md) · [Segurança](docs/safety.md) ·
[Solução de problemas](docs/troubleshooting.md)

## Licença

O git-parity é **gratuito para todos**, em casa ou no trabalho, em qualquer repositório ou
projeto, inclusive comercial.

**Não é open source.** Não é permitido modificar, publicar versões alteradas nem redistribuir
(o que inclui vender ou listar em outro lugar) sem autorização escrita do autor. Para pedir,
abra uma issue.

Os termos são a [PolyForm Strict License 1.0.0](LICENSE) com uma permissão adicional que libera
qualquer uso, inclusive comercial. Continua possível, por definição: os termos do GitHub deixam
qualquer pessoa ver e fazer fork deste repositório público dentro do GitHub, e instalar o plugin
por um agente faz uma cópia local, que a licença permite. O que a licença retira é o direito de
alterar o git-parity e de repassar cópias.

As builds publicadas antes da 1.5.0 (13 a 16 de novembro de 2026) foram retiradas; as que saíram
sob a licença MIT continuam MIT para quem já as tem. Este resumo não é aconselhamento jurídico;
vale o arquivo [LICENSE](LICENSE).

O nome e o logo git-parity seguem o [TRADEMARKS.md](TRADEMARKS.md). O git-parity não tem
relação com o projeto Git.

Copyright (c) 2026 Wesley Rafael Fonseca.
