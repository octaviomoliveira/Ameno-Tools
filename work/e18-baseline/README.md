# E18 — registro inicial de baseline

Data do planejamento: 2026-09-09

Este diretório é o ponto de entrada para a evidência que será produzida pelo
executor da E18. Nenhum resultado abaixo deve ser marcado como aprovado sem
executar novamente os comandos na branch E18.

## Base conhecida

- repositório: `D:\Ameno\_tools`;
- branch de origem: `feature/e17-ameno-ux`;
- HEAD observado ao planejar: `01e32cd`;
- commit funcional E17: `ae3e576`;
- baseline E16: `f763059`;
- canary E17:
  `dist/AmenoTools-0.0.1-e17-canary.zip`;
- SHA-256:
  `7F3ACAA4BE5D2F1BE7E9EEF90DFEAE2BC57F7B3589ABE7CD8145A59E5E09B406`.

## Evidência humana recebida

As capturas temporárias fornecidas pelo usuário mostram a janela em cerca de
980×762/768 px. Os sintomas visíveis são:

- cabeçalhos e textos cortados à direita;
- cards de Cotar maiores que a área útil;
- barra de rolagem horizontal;
- formulário Aparência espremido por splitter e mínimos;
- ações/labels parcialmente ocultos;
- prévia 2D aparentemente estática ao alterar números.

Não copiar os arquivos da pasta Temp para o pacote. Se forem necessários como
evidência local, registrar seus hashes e manter fora de `Contents/` e `dist/`.

## Fatos confirmados no código

- `StylesPage._current` começa como `None`.
- `_edited_style()` devolve `None` nesse estado.
- `update_preview()` encaminha esse valor.
- `PreviewWidget` usa um `StyleSnapshot` padrão quando recebe `None`.
- O painter atual não representa todos os campos editáveis.
- O shell fixa sidebar de 184 px.
- A página Aparência combina mínimos próximos de 210 + 600 px.
- O teste de layout atual não verifica clipping nem scrollbar horizontal.

## Baseline que o executor deve preencher

Registrar aqui ou em `work/e18-gates/summary.md`:

1. `git status --short`, `git rev-parse HEAD` e versões do ambiente;
2. comando/resultados dos testes Python;
3. comando/resultados das 18 suítes MaxScript;
4. dimensões úteis por página e breakpoint;
5. contagem de widgets, timers, conexões e bridge calls;
6. p50/p95 de 1.000 alterações;
7. teste vermelho da prévia;
8. teste vermelho do overflow.

O runbook completo está em
`plans/2026-09-09-e18-ux-10-10-preview-reativo.md`.
