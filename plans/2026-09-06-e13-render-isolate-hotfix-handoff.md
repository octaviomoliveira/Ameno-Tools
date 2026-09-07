# Handoff — hotfix E13 de render com Isolate Selection

Data: 2026-09-06  
Branch/worktree: `develop` em `D:\Ameno\_worktrees\develop`  
Commit funcional: `888985e` (`fix: guard render during isolate selection`)  
Estado: código e Batch concluídos; instalação e gate manual pendentes porque o 3ds Max interativo está aberto.

## Incidente e diagnóstico

O usuário tentou renderizar as cotas na cena
`G:\Meu Drive\00.Portfolio\Coxinhas da Ana\Ameno_Wesley_DDA_3D_HUMANIZADA_AP_V01.max`
com Corona 15 Hotfix 1. O painel identificou corretamente `Corona [Corona]` e o
adapter chegou a criar `CoronaLightMtl`, mas `render()` lançou
`EXCEPTION_ACCESS_VIOLATION`, leitura no endereço `0x40`. O PNG de destino não
foi criado.

O mesmo endereço e estágio aparecem em três logs Ameno da mesma máquina:

- `%LOCALAPPDATA%\AmenoTools\Logs\ameno-20260906-180520-144.log`;
- `%LOCALAPPDATA%\AmenoTools\Logs\ameno-20260906-203536-650.log`;
- `%LOCALAPPDATA%\AmenoTools\Logs\ameno-20260906-213909-685.log`.

O log da sessão do Max registra `Corona version: 15 (Hotfix 1)` e, antes da
tentativa, `One or more objects are currently Isolated`. A cena real portanto
estava em Isolate Selection enquanto o Ameno aplicava seu isolamento temporário
por `renderable`, `isHidden`, layers e materiais. O código-fonte do Corona não
está disponível para atribuir a instrução nativa exata; o estado operacional que
diferencia a cena real do fixture Corona aprovado foi identificado e agora é
tratado antes da chamada nativa.

## Correção

`ameno_render_cotas_service.ms` agora:

- consulta `IsolateSelection.IsolateSelectionModeActive()` no preflight;
- registra câmera, tipo de render, resolução, pixel aspect, isolamento e saída;
- se o modo estiver ativo, retorna uma falha explicável antes de capturar ou
  modificar adapter, materiais ou cena;
- preserva o isolamento e orienta o usuário a executar Alt+Q/End Isolate.

O serviço não sai e reentra automaticamente no modo: `ExitIsolateSelectionMode`
descarta o estado interno que o Max usaria para restaurar a cena, e recriá-lo a
partir dos nós visíveis não é transacionalmente equivalente.

Arquivos do commit:

- `Contents/scripts/ameno/core/ameno_render_cotas_service.ms`;
- `tests/maxscript/test_e13_stage6_render_restore.ms`.

## Verificação concluída

Todos os processos terminaram com exit `0` e zero marcadores `FAIL`:

| Gate | Resultado |
| --- | --- |
| `tools/validate-package.ps1` | PASS |
| `test_bootstrap.ms` | 1 PASS |
| `test_e13_stage6_render_restore.ms` | 24 PASS; inclui quatro verificações novas do Isolate Selection |
| `test_e9_corona_render.ms` | 1 PASS com Corona 15 Hotfix 1 real; PNG 160×90 com alpha |

Evidências: `D:\Ameno\_worktrees\develop\.test-output\render-isolate-hotfix\`.
O PNG do teste real é `.test-output\e9_corona_real.png`.

## Instalação e próximo passo

Não houve cópia para `ApplicationPlugins`: no encerramento deste handoff o
processo `3dsmax.exe` PID 45400 seguia aberto e responsivo. A instalação ativa
continua sendo a do commit `dac0601`.

Próximo passo exato:

1. aguardar o usuário fechar normalmente o 3ds Max;
2. criar backup da instalação ativa e executar `tools/install-dev.ps1`;
3. conferir todos os arquivos por SHA-256 e executar `test_installed_package.ms`;
4. reabrir a cena; com Isolate Selection ativo, o botão deve retornar a mensagem
   de proteção sem iniciar o Corona;
5. executar Alt+Q/End Isolate e renderizar novamente; confirmar PNG, alpha e cor.

Não reproduzir o acesso inválido com a versão antiga na cena do usuário, não
fechar o Max à força e não publicar/merge/push sem autorização.
