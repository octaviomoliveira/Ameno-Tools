# E10.8 — Estabilização do runner Batch em trabalho paralelo

**Data:** 2026-09-04

**Branch:** `fix/e10-stabilization`

**Estado:** implementação concluída; preflight aprovado com o 3ds Max aberto; execução das suítes no Batch aguarda o fechamento voluntário do Max.

## Problema

Durante a E10.7, o `3dsmaxbatch.exe` demorou vários minutos para iniciar e não gerou
logs quando havia uma sessão interativa do Max aberta. A auditoria após a integração
da E11 encontrou ainda duas fontes de resultados não determinísticos:

- `tests/maxscript/batch-isolated.ini` contém diretórios absolutos da checkout principal,
  fazendo worktrees paralelos compartilharem perfil, temporários e logs;
- `test_e10_1_modes.ms` e `test_e10_2_batch.ms` não emitiam o marcador
  `[AMENO_TEST][PASS]` exigido por `tools/test-maxscript.ps1`.

## Implementação

- `tools/test-maxscript.ps1` passa a gerar `.test-output/batch-isolated.generated.ini`;
- `PlugCFG`, `MaxData` e `Temp` são reescritos para a `.test-output` do worktree atual;
- caminhos do teste e do template são resolvidos de forma absoluta antes do lançamento;
- o runner detecta uma sessão `3dsmax.exe` aberta e falha imediatamente, sem iniciar
  Batch; `-AllowWhileMaxOpen` mantém uma saída explícita para diagnóstico consciente;
- E10.1 e E10.2 agora emitem o mesmo contrato de sucesso das demais suítes.

## Gates

- [x] runner executado no worktree `D:\Ameno\_tools-e10` com o Max aberto;
- [x] falha rápida informou o PID e confirmou que nenhum `3dsmaxbatch.exe` foi iniciado;
- [x] INI gerado aponta `PlugCFG`, `MaxData` e `Temp` somente para o worktree E10;
- [x] todos os testes E10 possuem marcador de sucesso reconhecido pelo runner;
- [x] estrutura do pacote aprovada por `tools/validate-package.ps1`;
- [ ] executar E10.1, E10.2, E10.4 e E10.7 após o usuário fechar o Max;
- [ ] confirmar regressão integral antes de integrar a branch na `main`.

## Regra para o trabalho paralelo

Enquanto o Antigravity ajustar a E11, esta branch não executará `install-dev.ps1` nem
alterará `ApplicationPlugins`. Somente a integração final poderá substituir o pacote
instalado no perfil do usuário.
