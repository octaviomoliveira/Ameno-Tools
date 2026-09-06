# E12-R0 — diagnóstico da interação real

Data: 2026-09-05. Branch: `feature/e12-input-recovery`.

## Objetivo e limite

Este incremento conserva o comportamento da versão `ba55d95` e acrescenta um probe desligado por padrão. Ele registra as fronteiras reais entre o `MouseTool`, classificação do clique, pedido de commit, criação e limpeza. Não corrige picking, encerramento, HUD ou preview e não autoriza avançar para R1 enquanto um trace interativo não explicar pelo menos uma falha.

A branch foi criada a partir de `c1224e6` e reverteu somente `d8ce420` no commit `df8c69b`. Assim, os planos novos permanecem disponíveis, mas o código executável volta ao ponto instalado e já conhecido pelo usuário.

## Como ativar

O build diagnóstico precisa ser instalado com o 3ds Max fechado. Depois de abrir o Max e uma cena descartável:

1. Abra o MAXScript Listener.
2. Execute `AmenoContinuousDiagnostics.start revision:"R0-interactive"`.
3. No Ameno Tools, selecione **Horizontal** e ative **Cota contínua**.
4. Clique uma vez em dois vértices distintos de um Editable Poly.
5. Clique uma vez em uma área vazia para posicionar/finalizar.
6. Se o comando não sair, pressione Esc uma única vez.
7. Execute `AmenoContinuousDiagnostics.stop()` no Listener.

O retorno de `stop()` é o arquivo de log, normalmente em `%LOCALAPPDATA%\AmenoTools\Diagnostics\e12-r0-<data>.log`. Esse arquivo não é salvo na cena nem enviado automaticamente.

Primeiro faça somente o caso-base acima. Depois, se necessário, repita em sessões separadas com snap de vértice ligado/desligado, grid ligado e cursor sobre o preview. Não misture variantes no primeiro trace.

## O que o trace discrimina

- evento nativo: `start`, `freeMove`, `mouseMove`, `mousePoint`, `mouseAbort`, `stop`;
- `clickNumber`, estado, modo e número de referências;
- estado do snap, nó e pontos recebidos;
- nó/vértice detectado, classificação e justificativa;
- pedido de commit, layout, criação por segmento, exceção e rollback;
- resultado retornado pelo handler e limpeza final.

Movimentos repetidos são limitados por estado/candidato; cliques e transições sempre são registrados. O probe não usa temporizador para inferir clique físico e não trata `mouseAbort` como confirmação, porque a API não diferencia com segurança Esc de botão direito nessa borda.

## Gate

O teste automatizado `tests/maxscript/test_e12_r0_diagnostics.ms` comprova apenas que o serviço inicia/desliga, grava marcadores, limita repetição e não altera um outcome injetado. Ele não substitui o clique real.

R0 só termina quando o log de uma reprodução real demonstrar uma destas fronteiras: clique vazio não classificado como vazio; commit não solicitado; commit falhando; commit concluído sem o MouseTool encerrar; ou outra causa observada. Até lá, R1–R6 permanecem bloqueados.

## Resultado do gate — 2026-09-05

R0 foi concluído com o build diagnóstico do commit `e1bc1142306b86f45a724cc42bf54fa41104c2e2`, instalado manualmente após backup em `D:\Ameno\_backups\AmenoTools-before-e1bc114-20260905-134400`. A comparação da origem com `ApplicationPlugins` encontrou 25 arquivos em cada lado, sem ausentes, extras ou diferenças SHA-256.

O trace interativo bruto está em `%LOCALAPPDATA%\AmenoTools\Diagnostics\e12-r0-20260905-165149-560.log`, SHA-256 `598CFF70DBE9B695CE2A360FB71D5C1D1D02CAF4D1DE22EEDC0144126B75D2AA`.

### Causas comprovadas

1. **Sucesso não encerra o MouseTool.** No modo Horizontal, o clique vazio foi classificado como `empty` (`seq=2290`), o pedido foi aceito (`seq=2292`), quatro segmentos foram criados (`seq=2295`–`2302`) e houve `commitSuccess` (`seq=2303`). Entretanto, o próprio evento terminou como `chainCommitted` ainda em `stage=collecting | active=true` (`seq=2304`–`2305`). Os cliques vazios seguintes foram processados como uma nova coleta sem referências e retornaram `needsMoreReferences` (`seq=2426`–`2440`). O `stop` só apareceu posteriormente (`seq=2655`). Portanto, a saída após sucesso é uma falha de lifecycle/retorno na borda do MouseTool, não de classificação ou criação.
2. **Alinhado entra na captura apesar de não ser suportado pelo commit E12-C.** O modo iniciou como `aligned`, coletou referências e reconheceu o vazio. O pedido foi aceito (`seq=1223`–`1225`), mas `commitChain` retornou `commitRejected | reason=unsupported-mode` (`seq=1226`), mantendo a ferramenta ativa com `commitFailed` (`seq=1227`–`1228`). O modo deve ser bloqueado antes de capturar o mouse no gate R1; isso não autoriza implementar a matemática/integração Alinhada.

O relato de que um vértice já usado em uma cadeia Horizontal não pôde ser reutilizado ao iniciar uma Vertical não aparece como sessão `vertical` neste trace. Ele permanece como sintoma a reproduzir no gate de picking, sem diagnóstico atribuído.

### Validação automatizada

Passaram serialmente, com marcador final conferido: `test_e12_r0_diagnostics.ms`, `test_e12_chain_input.ms`, `test_e12_chain_math.ms`, `test_e12_chain_commit.ms`, `test_e12_continuous.ms` e `test_bootstrap.ms`. `tools/validate-package.ps1` também aprovou o pacote. Os três primeiros runs do teste R0 expuseram problemas de bootstrap restritos ao probe; as correções de assinatura e leitura de ambiente foram incluídas em `e1bc114` antes da instalação.
