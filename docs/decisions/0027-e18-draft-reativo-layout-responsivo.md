# ADR 0027 — Draft reativo, prévia pura e layout Qt adaptativo

Data: 2026-09-09

Status: aceita para a execução da E18

## Contexto

O E17 provou o host Qt, o lifecycle e a preservação do desempenho E16, mas o
aceite humano reprovou a experiência visual. As capturas reais revelaram
clipping, rolagem horizontal, excesso de texto e hierarquia fraca na janela
padrão. A prévia 2D também não responde antes de existir um estilo corrente e
não representa vários parâmetros expostos pelo formulário.

A causa funcional principal é o uso de `None` como estado inicial do estilo:
os controles aceitam edição, `_edited_style()` devolve `None` e o painter cai
silenciosamente no snapshot padrão. O layout, por sua vez, combina sidebar,
margens e mínimos internos maiores que a largura útil disponível.

Voltar ao WPF não é opção: a migração para Qt eliminou o ciclo de reparenting
que travava o shell anterior. Também não se deve pagar uma melhoria visual com
novas consultas à viewport.

## Decisão

1. Permanecer em Python/PySide6 fornecido pelo 3ds Max 2026.
2. Introduzir um `StyleDraft` local, sempre válido e inicializado pelo padrão.
3. Ligar controles e prévia apenas ao draft; persistência e aplicação serão
   comandos explícitos.
4. Separar a prévia em cálculo geométrico puro e pintura com `QPainter`.
5. Representar na prévia todo parâmetro que permanecer editável.
6. Usar controles compostos de slider + entrada numérica sincronizados, sem
   chamadas à cena.
7. Tornar shell e páginas adaptativos em três breakpoints sem reconstruir ou
   reparenteiar widgets.
8. Criar ícones vetoriais próprios da Ameno, com SVG e fallback PNG; ícones não
   substituem rótulos em ações críticas.
9. Provar ausência de overflow, bridge calls, timers e regressão E16 com testes
   objetivos antes do canary.

## Consequências

- A edição visual ganha resposta imediata mesmo com biblioteca vazia.
- O usuário pode experimentar sem mutar a cena ou gerar Undo.
- Testes de geometria deixam de depender somente de screenshots.
- A interface passa a acomodar a janela mínima por reorganização, não por
  redução indiscriminada de fonte.
- A árvore de widgets permanece estável durante resize e navegação.
- Haverá novos componentes e testes, mas nenhuma alteração no schema de estilo
  ou nos serviços MaxScript.

## Alternativas rejeitadas

- **Corrigir apenas `update()`:** continuaria desenhando o snapshot padrão e
  ignorando parâmetros.
- **Ocultar a barra horizontal:** mascara o overflow e mantém controles
  inacessíveis.
- **Aumentar o tamanho mínimo:** transfere o problema para telas menores e DPI
  alto.
- **Reutilizar sliders WPF:** reintroduz tecnologia e lifecycle já rejeitados;
  apenas o comportamento de exploração rápida serve como referência.
- **WebView/processo externo:** aumenta dependências, autenticação, foco e
  lifecycle sem necessidade.
- **Atualizar a cena a cada slider:** viola o isolamento do E16 e degrada a
  viewport.

## Evidência e execução

O plano vinculante é
`plans/2026-09-09-e18-ux-10-10-preview-reativo.md`. O aceite exige métricas,
matriz de layout/DPI, regressões E16 e teste humano; aprovação estética isolada
não basta.
