# Handoff — estabilização do ciclo WPF da E13

Data: 2026-09-06  
Branch/worktree: `develop` em `D:\Ameno\_worktrees\develop`  
Estado: IMPLEMENTADA/TESTADA/INSTALADA; gate interativo pendente

## Relato e diagnóstico

Depois de criar cotas, a janela podia deixar de responder ao tentar navegar para
Estilos ou trocar de modo. O log real mostrou que o núcleo concluía as sessões:
quatro commits de cotas, cinco encerramentos do MouseTool e nenhum erro. O Max
continuou responsivo e executou autosave.

A causa principal estava no ciclo síncrono do shell WPF: o clique escondia a
janela, executava `startTool` e voltava a mostrar/ativar a janela antes de o mesmo
callback WPF terminar. A navegação ainda limpava `ContentArea`, descartava todas
as exceções com `catch ()` e retornava sucesso. Criar e Render reconstruíam seus
UserControls e registravam novos delegates a cada visita.

## Correções

- `ameno_cotas_window.ms`
  - mantém a janela carregada e visível durante o MouseTool;
  - desabilita somente a interação WPF e transfere foco ao Max;
  - reabilita a mesma instância ao terminar, sem `Hide/Show/Activate`;
  - considera uma janela carregada como singleton mesmo se estiver oculta;
  - constrói a aba seguinte antes de substituir a atual;
  - só altera `activeSection` e a sidebar após sucesso;
  - preserva conteúdo/estado anterior quando uma aba falha;
  - grava transições e exceções no logger persistente.
- `ameno_cotas_criar_tab.ms` e `ameno_cotas_render_tab.ms`
  - reutilizam o UserControl existente e não registram handlers novamente.
- `ameno_runtime.ms`
  - registra início, retorno e falhas do ciclo ferramenta/painel.
- `test_e13_ui_lifecycle.ms`
  - usa WPF real em Batch para doze ciclos Criar/Estilos/Editar/Render;
  - verifica identidade dos hosts, rollback, logger, suspensão e singleton.
- Suítes de Estilos/biblioteca global
  - `LOCALAPPDATA` agora aponta para uma pasta temporária exclusiva do processo;
  - não apagam mais `%LOCALAPPDATA%\AmenoTools\Profiles\styles.library` do usuário.

## Evidências

Todos os processos terminaram com exit `0` e zero marcadores `FAIL`:

| Gate | PASS |
| --- | ---: |
| `validate-package.ps1` | pacote válido |
| `test_e13_stage2_create.ms` | 22 |
| `test_e13_ui_lifecycle.ms` | 12 |
| `test_e13e.ms` | 9 |
| `test_e13h.ms` | 13 |
| `test_e13_stage4_edit_reanchor.ms` | 45 |
| `test_logger.ms` | 1 |
| `test_e12_continuous.ms` | 1 marcador final |
| `test_bootstrap.ms` | 1 marcador final |
| `test_e13_stage3_styles.ms` | 25 |
| `test_e13_global_styles_render_color.ms` | 13 |

Total observado pelo runner: 142 marcadores PASS, 0 FAIL. O runner validou também
o encerramento com sucesso de cada processo; não aceitou um PASS isolado.

O perfil real foi preservado:

- caminho: `C:\Users\octav\AppData\Local\AmenoTools\Profiles\styles.library`;
- modificação: `2026-09-06 20:51:01`;
- SHA-256: `6481FC2525CF0E31F37189895AF0073058B6C522EDED7F9CD6541D18EC10ACCF`.

## Instalação e próximo passo

O usuário fechou o Max e a ausência de `3dsmax.exe`/`3dsmaxbatch.exe` foi
confirmada antes da instalação. A versão anterior foi preservada em
`D:\Ameno\backups\AmenoTools-before-ui-lifecycle-20260906-213520` (42 arquivos).
O commit `dac0601` foi instalado em
`C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`:

- 42/42 arquivos correspondem ao worktree por SHA-256;
- 0 ausentes, 0 divergentes e 0 extras;
- `test_installed_package.ms`: exit 0, 1 PASS, 0 FAIL.

Nenhuma cena interativa foi aberta ou alterada. Agora executar o gate manual:

1. abrir Ameno Cotas;
2. criar uma cota individual e uma contínua por clique na viewport;
3. após cada sessão, alternar Criar → Estilos → Editar → Render → Criar;
4. repetir pelo menos cinco vezes e confirmar que a janela continua clicável;
5. conferir no novo log as entradas `painel desabilitado`, `painel reabilitado` e
   ausência de `falha ao construir aba`.

O Enter continua removido e não deve ser usado como confirmação. As issues #1,
#2 e #3 permanecem abertas e não fazem parte deste hotfix.
