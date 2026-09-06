# Handoff — hotfix do crash no Enter da cotação contínua

Data: 2026-09-06  
Branch: `develop`  
Commit: `2135b3b` — `fix: remove crashing continuous Enter monitor`

## Contexto

O usuário reproduziu no 3ds Max 2026.3 que pressionar Enter durante a cotação
contínua encerrava o 3ds Max. O relatório de crash correspondente tinha
exceção CLR/.NET `0xE0434352` com `E_FAIL`; a reprodução confirmou que o
monitor `DispatcherTimer`/callback usado pelo Enter era o caminho acionado.
Como o clique na viewport já foi corrigido inclusive dentro das paredes, a
decisão deste hotfix foi remover o Enter do fluxo interativo até existir um
evento de teclado suportado pelo `MouseTool` sem callback assíncrono.

## Alterações

- Removidos `DispatcherTimer`, `dotNet.addEventHandler ... Tick`,
  `isEnterDown` e todo o ciclo do monitor de Enter de
  `ameno_dimension_continuous_tool.ms`.
- O `MouseTool` confirma a cadeia exclusivamente pelo clique na viewport e
  mantém Esc/botão direito como cancelamento.
- `confirmPoints()` permanece como operação interna programática/testável,
  mas não é acionada por teclado.
- Prompts, instruções do HUD legado e teste de lifecycle foram atualizados para
  não anunciar Enter.
- O logger persistente foi concluído em
  `Contents/scripts/ameno/core/ameno_logger.ms`; sessões são gravadas em
  `%LOCALAPPDATA%\AmenoTools\Logs\ameno-<sessão>.log`, com rotação de
  2 MiB e falhas de I/O isoladas.
- Bootstrap registra falhas de carregamento no logger sem deixar logging
  interferir na inicialização.

## Evidências

### Estrutura e fonte

- Busca estrutural: `STRUCTURE_PASS: caminho CLR/Enter removido`.
- `git diff --check`: passou.
- O pacote fonte contém 42 arquivos.

### Batch isolado após a remoção

- Bootstrap, logger, lifecycle E12-R1, commit contínuo, contínuo, picking
  E12-R2, preview E12-R3, transação E12-R4 e teste do pacote instalado:
  todos terminaram com exit 0, marcador PASS e zero FAIL.
- Regressão E13:
  - auditoria: 8 PASS;
  - etapas 2, 3, 4, 5 e 6: 21, 25, 45, 41 e 20 PASS;
  - posição do texto: 4 PASS;
  - feedback visual: 18 PASS;
  - E13-A…H: 3, 6, 7, 8, 9, 7, 4 e 13 PASS.
- Total do lote E13: 239 PASS / 0 FAIL.
- A verificação estrita do runner foi usada; nenhum sucesso foi aceito apenas
  pela presença de um PASS quando havia FAIL.

### Instalação

- Destino: `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`.
- Pacote: `dist\AmenoTools-0.0.1-e13-no-enter-20260906.zip`.
- SHA-256 do pacote: `247B153A4C434FD465A5A2EC3F0FB90D91E27596923CE84BD2E771A4E0C3033B`.
- Comparação fonte/instalação: 42/42 arquivos, 0 ausentes, 0 extras e 0
  divergências SHA-256.
- Verificação da instalação: `INSTALLED_STRUCTURE_PASS`; teste instalado exit
  0, 1 PASS e 0 FAIL.
- Backup recuperável da instalação anterior:
  `D:\Ameno\backups\AmenoTools-before-no-enter-20260906-165737` (42 arquivos).

## Pendente

- Reabrir o 3ds Max e validar manualmente uma cotação contínua com cliques em
  referências e clique de confirmação dentro e fora de paredes.
- Não testar Enter nesta versão: ele foi removido deliberadamente para impedir
  a reprodução do crash.
- Uma futura tentativa de reintroduzir confirmação por teclado exige um spike
  separado com evento suportado pelo `MouseTool`, microteste e gate manual;
  não usar novamente `DispatcherTimer` para chamar MaxScript.
- Não houve publicação, merge ou alteração na `main`.

## Próximo passo

Reabrir o Max, confirmar que o fluxo por clique está estável e coletar o novo
log persistente se ocorrer qualquer erro. Depois decidir separadamente se vale
implementar uma confirmação por teclado suportada pelo host.
