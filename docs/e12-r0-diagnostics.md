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
