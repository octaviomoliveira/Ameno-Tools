# ADR 0028 — Cotar como referência e gate visual no host

Data: 2026-09-10

Status: aceita para a execução da E19

## Contexto

O E18 passou automação, smoke e instalação, mas as capturas do Max real
mostraram textos e navegação cortados, preview fora da área de ajuste e
contraste insuficiente. A automação validava scrollbar horizontal e estabilidade
da árvore, porém não media o conteúdo interno com a fonte e o DPI do host.

O layout também escolhia breakpoints pela largura do shell. Essa medida não
representa a área entregue à página depois da sidebar, frame, margens e
scrollbars. A galeria offscreen não reproduziu a densidade observada no Max.

## Decisão

1. Usar Cotar como primeira referência antes de propagar alterações.
2. Bloquear as demais páginas até Cotar ser aprovada no Max 2026.
3. Calcular breakpoints pela largura do viewport que hospeda a página.
4. Em Cotar, usar cards compostos com ícone vetorial, título e hint separados;
   em Aparência, manter preview e ações fora da rolagem dos controles.
5. Medir clipping com `QFontMetrics`, `contentsRect`, margens, ícones e size
   hints, além de verificar scrollbars.
6. Exigir capturas e tarefas no host real para aceite visual.
7. Preservar draft e painter locais do E18 e a estabilidade de viewport do E16.

## Consequências

- A primeira entrega E19 cobre somente Cotar até o gate intermediário.
- A responsividade usa a largura realmente disponível para cada página.
- Testes ficam mais próximos do que o usuário vê, incluindo fonte e DPI.
- Cotar define a hierarquia, densidade, sidebar e seleção visual reutilizáveis.
- Aparência ganha rolagem interna própria na etapa seguinte.
- O avanço fica mais lento por checkpoint, mas evita propagar uma referência
  visual reprovada para todo o produto.

## Partes da ADR 0027 preservadas

- `StyleDraft` sempre válido e sem acesso à cena.
- Geometria pura do preview e pintura por `QPainter`.
- Slider + entrada técnica sincronizados.
- Zero bridge/pymxs/timer durante edição, paint, resize e navegação.
- Ausência de WPF e árvore de widgets estável.

## Partes substituídas

- Breakpoint por largura do shell passa a usar o viewport da página.
- Uma rolagem externa para toda Aparência passa a ser um root fixo com scroll
  somente nos controles.
- Galeria offscreen deixa de ser evidência suficiente para aceite.
- Scrollbar zero deixa de provar, sozinha, ausência de clipping.

## Evidência e execução

O plano vinculante é
`plans/2026-09-10-e19-correcao-visual-interface-qt.md`. O baseline real está em
`work/e19-baseline`.
