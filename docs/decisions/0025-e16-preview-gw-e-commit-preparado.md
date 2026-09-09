# ADR 0025 — Preview contínuo com `gw` e commit com contexto preparado

Data: 2026-09-09

Status: decidido; implementação não iniciada

## Contexto

O candidato Python/Qt da E15 removeu a família de falhas WPF e tornou a
navegação da interface mais rápida, mas não alterou o núcleo interativo. Na cena
observada, duas cotas verticais levaram 5,28 s e sete horizontais levaram
18,15 s: aproximadamente 2,6 s por segmento nos dois modos. A equivalência por
segmento exclui uma fórmula Vertical especial como causa principal.

O caminho atual da ferramenta contínua pode executar picking completo no
`mouseMove` e `refreshChainPreview()` cria/atualiza nós reais de spline,
`TextPlus`, terminais e material. O commit volta a materializar a representação
persistente e repete preparação de cena/layout por segmento.

## Decisões

1. O preview da ferramenta contínua será um modelo transitório composto somente
   por valores primitivos e desenhado por um único redraw callback `gw`.
2. `mouseMove` usará apenas interseção com o plano e hints nativos de snap. Ele
   não chamará resolução completa, scans de cena, `intersectRayScene` ou
   `snapshotAsMesh`.
3. `mousePoint` continuará chamando o resolver completo uma vez para preservar
   a seleção de geometria real, o `vertexId` e o contrato R2.
4. O callback apenas desenhará snapshots prontos. Ele não chamará serviços de
   cena, layout, estilo, picking, persistência ou UI.
5. O valor de função anterior será desregistrado antes de qualquer redefinição;
   begin/success/cancel/error/reset/open/shutdown terão teardown idempotente.
6. As APIs de preview baseadas em nós permanecerão temporariamente para a
   ferramenta individual, mas não serão chamadas pela ferramenta contínua.
7. O commit da cadeia preparará scene state, layers, estilo, material e layout
   uma vez, e usará uma API interna `createDimensionFromLayout` compatível com o
   wrapper público existente.
8. A criação persistente continuará na thread principal, dentro de um único
   Undo, com redraw exception-safe e rollback integral.
9. A E16 é certificada somente no Max 2026 e não altera a UI Qt, WPF, schema CA,
   renderers ou faixa de versões do pacote.

## Consequências

- A quantidade de referências deixa de multiplicar criação/atualização de nós
  enquanto o cursor se move.
- O hover pode ser provisório; a decisão de âncora continua exclusiva do clique.
- A tipografia transitória pode ser aproximada, mas o `TextPlus` final mantém
  paridade total.
- O commit permanece síncrono, porém remove trabalho repetido por segmento. Se
  ainda exceder a meta, o perfil deve orientar nova decisão; não será adotado
  background scene access para mascarar o custo.
- Callback e modelo tornam-se recursos explícitos de sessão e passam a exigir
  gates próprios de lifecycle.

## Alternativas rejeitadas

- aumentar apenas o throttle de mouse;
- ocultar nodes de preview em vez de não criá-los;
- resolver picking completo em timer/worker;
- criar cotas por thread Python/Qt;
- manter dois backends de preview simultâneos;
- remover CA, terminais ou dados de âncora para acelerar;
- fatiar uma única transação por eventos antes de provar a otimização síncrona.

## Evidência e aceite

Plano e runbook completos:
`plans/2026-09-09-e16-otimizacao-preview-commit-viewport.md`.

Aceite mínimo:

- 1.000 moves com zero mutação de cena e zero full resolve;
- callback Ameno 0/1/0 no lifecycle;
- picking de clique R2 inalterado;
- sete segmentos em até 5 s e nenhum acima de 1 s na cena de referência;
- um Undo/Redo e zero parciais em todas as falhas injetadas;
- regressões E12–E15, instalação e soak gráfico aprovados.
