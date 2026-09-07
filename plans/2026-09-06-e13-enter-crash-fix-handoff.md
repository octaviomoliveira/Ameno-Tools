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

## Atualização — recuperação após modo incorreto

Data: 2026-09-06
Branch: `develop`
Commit: `5a31643` — `fix: recover continuous dimension mode mismatch`

### Sintoma e causa

O usuário relatou que, com o painel em Horizontal, uma tentativa acidental de
cotar uma sequência Vertical podia deixar o aplicativo sem responder a Esc,
troca de modo ou fechamento do painel. O fluxo confirma que o painel é ocultado
durante o `MouseTool` e que o modo é capturado no início da sessão; portanto,
os controles do painel não podem ser usados como recuperação durante a coleta.
O caminho anterior também não rejeitava explicitamente uma direção incompatível
no segundo ponto e não forçava um retorno `#stop` no abort caso a limpeza
lançasse exceção.

### Alterações

- `ameno_dimension_continuous_tool.ms` compara o segundo ponto com o primeiro
  usando os eixos X/Y; se a direção dominante contradiz Horizontal/Vertical,
  registra o motivo, cancela a sessão, restaura o painel e mostra uma mensagem
  acionável.
- `escapeEnable` é salvo, habilitado apenas durante o `startTool` e restaurado
  ao sair, sem alterar permanentemente a preferência global do usuário.
- `on mouseAbort` isola a limpeza e retorna explicitamente `#stop`, para que um
  erro de cleanup não mantenha o `MouseTool` ativo.
- O Enter continua fora do fluxo interativo; não foi reintroduzido o
  `DispatcherTimer` que provocou o crash CLR anterior.

### Evidências automatizadas

- `git diff --check`: passou.
- `tests/maxscript/test_e12_r1_lifecycle.ms`: 70/70 verificações, exit 0,
  70 marcadores PASS e 0 FAIL, incluindo mismatch Horizontal/Vertical,
  cancelamento e armamento/restauração de `escapeEnable`.
- Regressões `test_e12_continuous.ms`, `test_e12_r2_picking.ms` e
  `test_e13_stage2_create.ms`: exit 0 e 0 FAIL.
- `tools/package-alpha.ps1`: pacote validado.
- Pacote: `dist/AmenoTools-0.0.1-e13-mode-recovery-20260906.zip`;
  SHA-256 `D029DEC315250DBE8947C47A52128F9945FC051FBD9897BA312A7AC4C9940B3F`.
- Instalação: `SOURCE_FILES=41`, ausentes 0, divergências 0; teste pelo
  `ApplicationPlugins` exit 0, 1 PASS e 0 FAIL.

### Instalação e estado

O Max estava fechado antes da instalação. Foi preservado o backup em
`D:\Ameno\backups\AmenoTools-before-mode-recovery-20260906-175430`.
Depois do teste instalado, não havia processo `3dsmax.exe` ou `3dsmaxbatch`
ativo. Isso confirma a instalação do código, mas não substitui o gate manual
em uma nova sessão interativa.

### Pendente

- Reabrir o Max e, sem pressionar Enter, iniciar em Horizontal e clicar dois
  pontos claramente verticais; a sessão deve cancelar sozinha e devolver o
  painel com a mensagem de modo incompatível.
- Repetir uma cadeia correta Horizontal e uma correta Vertical, confirmar por
  clique dentro e fora das paredes e verificar Undo/Redo.
- Pressionar Esc antes do segundo ponto e depois de referências coletadas;
  confirmar que o painel retorna e que a contagem não muda.
- Se o Max voltar a travar, anexar o log em
  `%LOCALAPPDATA%\AmenoTools\Logs\ameno-<sessao>.log`.

Não publicar, fazer merge na `main` ou testar Enter nesta versão.
