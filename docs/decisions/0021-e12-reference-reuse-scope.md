# ADR 0021 — E12: reuso de referência é geométrico, não cota→cota

Data: 2026-09-05. Estado: aceito.

## Contexto

O relato inicial descrevia o vértice superior direito usado na cadeia Horizontal que
desaparecia ao iniciar a cadeia Vertical. Havia uma cota Ameno desenhada sobre o
mesmo pixel, portanto o Snap podia devolver primeiro uma spline/terminal/TextPlus da
anotação em vez da geometria de origem.

O gate R2 separou Snap de picking geométrico, ignorou gráficos técnicos Ameno como
fonte de âncora e resolveu o vértice elegível da geometria por `node + vertexId`.
O usuário repetiu exatamente o caso Horizontal→Vertical com a cota existente
coincidindo sobre o vértice e confirmou que o defeito deixou de ocorrer.

## Decisão

- A referência canônica de uma cota contínua é sempre a geometria elegível da cena,
  identificada por nó e `vertexId >= 1`, com o ponto mundial 3D preservado.
- O mesmo vértice da geometria pode ser reutilizado em sessões/cadeias diferentes,
  inclusive uma Horizontal e uma Vertical. A reutilização não é deduplicada entre
  cotas: cada cota mantém seu próprio vínculo à geometria.
- Controlador, spline, terminal, TextPlus e marcador de uma cota existente — assim
  como qualquer preview — nunca são fontes de âncora por adivinhação. A posição
  projetada da anotação serve, no máximo, para ajudar o picking a alcançar a
  geometria subjacente.
- Não implementar vínculo cota→cota nesta E12-R. Se no futuro o requisito for
  selecionar explicitamente uma ponta de anotação, ele deverá ser uma extensão
  separada com `dimensionId`, lado A/B, suporte a cotas baked/local e testes próprios.
  Sem esse contrato, clicar apenas numa anotação sem geometria resolvível não
  confirma a cadeia nem cria `vertexId` artificial.

## Consequências

O defeito reportado fica coberto pela correção e pelo gate manual do R2; não há
alteração de código necessária para o R5. Movimento da geometria original continua
atualizando todas as cotas que apontam para o mesmo nó/vértice, conforme o serviço de
âncoras existente. A exclusão da anotação fonte não afeta outras cotas ancoradas na
geometria; a exclusão da geometria segue a política de órfãs já aprovada.

O R5 é concluído como gate de definição. O próximo incremento é o R6, com regressões,
validação do pacote e aceitação interativa final.

## Evidência

- `plans/2026-09-05-e12-r2-handoff.md`: causa, contrato e roteiro do caso
  Horizontal→Vertical compartilhando o vértice.
- `tests/maxscript/test_e12_r2_picking.ms`: 33/33 PASS, incluindo gráfico Ameno
  sobreposto, resolução do nó/ID real e preservação do Z.
- `tests/maxscript/test_e12_chain_commit.ms`: 48/48 PASS, incluindo cadeias H/V,
  falha transacional e Undo/Redo.
