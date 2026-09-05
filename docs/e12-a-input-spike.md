# E12-A — spike de eventos e classificação

Data: 2026-09-05. Base: `acf2d5a`. Resultado: **gate automatizado aprovado**.

## API confirmada

A documentação Autodesk de [Mouse Tool Clauses](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/Scripted-Mouse-Tools/GUID-619AF4D3-A347-4155-943B-707D421BC460.html) confirma:

- `mousePoint` é chamado a cada clique e seu argumento é o número do evento da ferramenta, não um sinal de duplo clique;
- `mouseAbort` é chamado tanto por botão direito quanto por Esc;
- handlers podem retornar `#stop` para encerrar a ferramenta;
- interações de clicar/arrastar/soltar também afetam a sequência dos eventos.

Consequência: E12 não tenta distinguir Esc de botão direito; ambos cancelam. A heurística de `timeStamp() < 400` foi removida. Backspace não possui handler nativo nessa API; o botão Desfazer permanece como caminho garantido até existir um mecanismo de teclado comprovado e com cleanup.

## Fronteira implementada

`AmenoContinuousClickClassification` aceita somente `#reference`, `#geometryWithoutReference`, `#empty` ou `#ambiguous`. `handleClassifiedClick` é testável sem mouse: adiciona uma referência válida, rejeita identidade/ponto repetido, preserva draft em geometria/ambiguidade e muda para `#committing` no primeiro vazio com duas referências.

O detector deixou de buscar o vértice mais próximo em toda a cena. Prioriza snap em nó elegível; sem snap, usa a primeira geometria elegível realmente atingida pelo raio. Helpers Ameno, nomes `AMENO_`, objetos ocultos e congelados são inelegíveis. Um snap sem vértice elegível é ambíguo, não vazio.

## Limites que permanecem para os próximos gates

- A tolerância atual de vértice ainda é física (10 mm convertidos para scene units). A seleção por pixels prevista no plano exige um resolvedor dedicado de vértices projetados e deve entrar antes do gate interativo final.
- E12-A não cria layout nem cotas: `#committing` é a fronteira para E12-B/C.
- Preview antigo foi desativado para não apresentar uma geometria que diverge do layout compartilhado ainda inexistente.
- Persistência/schema não mudaram. Consumidores futuros: `ameno_dimension_graphics.ms`, `ameno_dimension_ca.ms`, `ameno_anchor_service.ms`, bootstrap, lifecycle/reset/open/Undo e testes E10/E11.

## Evidência

Foi criado `tests/maxscript/test_e12_chain_input.ms`, que passa somente pelos handlers/classificador e cobre: clique em referência, dois cliques consecutivos sem timer, duplicata, geometria sem vértice, ambíguo, vazio insuficiente, vazio solicitando commit, congelamento durante commit e abort/cancel.

A primeira execução do runner antigo da worktree não iniciou o script e terminou antes de criar `listener.log` (código `-2146232797`). Depois que o usuário fechou o Max, as suítes foram executadas com o runner isolado corrigido de `D:\Ameno\_tools-e10`, usando como template o INI e como código/testes a worktree E12:

- `test_e12_chain_input.ms`: **21/21 PASS**; log confirmou source e bootstrap em `D:\Ameno\_worktrees\e12-continuous`.
- `test_e12_continuous.ms`: **43/43 PASS**, atualizado apenas no contrato obsoleto `#offset` → `#committing`.
- `tools/validate-package.ps1`: pacote estruturalmente válido.

Não houve instalação nem teste interativo. O gate manual do fluxo completo pertence à E12-C, quando preview e commit existirem.
