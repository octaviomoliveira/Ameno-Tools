# E12-C — Preview e commit H/V

Data: 2026-09-05. Branch: `feature/e12-continuous-dimension`.

Estado: **implementação, gates automatizados e instalação concluídos; gate manual no 3ds Max pendente**.

## Entrega

- Preview de todos os intervalos horizontais ou verticais usando o mesmo layout compartilhado da E12-B.
- Uma única baseline para a cadeia: Y comum no modo Horizontal e X comum no modo Vertical.
- O primeiro clique vazio, com ao menos duas referências, posiciona e confirma `N-1` cotas sem uma fase adicional de offset.
- Os segmentos são criados em uma única transação de Undo. Um Undo remove a cadeia inteira e um Redo a restaura.
- Falha durante o commit remove somente as cotas criadas naquela tentativa, preserva referências e previews e devolve a ferramenta ao estado `#collecting`.
- Após sucesso, o draft é limpo e a ferramenta permanece pronta para iniciar outra sequência.
- `createDimension` ganhou a opção retrocompatível `useUndo:true`; chamadas antigas preservam seu comportamento e a cadeia usa `useUndo:false` dentro da transação externa.
- O classificador de clique vazio agora preserva o ponto mundial do clique, necessário para definir a baseline do commit real.

Ainda fora desta entrega: modo Alinhado oblíquo (E12-D), registro persistente de cadeia e atualização conjunta após reabrir/editar âncoras (E12-E).

## Gates executados

- `test_e12_chain_commit.ms`: **43/43**. Cobre preview e persistência H/V, baseline comum, rollback com falha injetada no segundo segmento, draft preservado, `N-1` cotas e Undo/Redo único.
- `test_e12_chain_input.ms`: aprovado pelo runner com marcador `[AMENO_TEST][PASS]`.
- `test_e12_continuous.ms`: aprovado pelo runner com marcador `[AMENO_TEST][PASS]`.
- `test_bootstrap.ms`: aprovado; bootstrap e funcionalidades acumuladas do pacote permaneceram carregáveis.
- `test_installed_package.ms`: aprovado com `[AMENO_INSTALLED_TEST][PASS]` após instalar a cópia de `ApplicationPlugins`.
- `git diff --check`: sem erros; apenas avisos esperados de conversão LF/CRLF no Windows.

Os testes foram executados em cena descartável pelo `3dsmaxbatch.exe` 2026.3. Nenhum teste foi executado na cena interativa do usuário.

## Instalação para o gate manual

- Commit instalado: `ba55d95`.
- Origem: `D:\Ameno\_worktrees\e12-continuous`.
- Destino: `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`.
- 24 arquivos conferidos por SHA-256 entre origem e destino.
- Pacote anterior preservado em `AmenoTools.backup-before-E12C-20260905-013001` no mesmo diretório `ApplicationPlugins`.

## Gate manual necessário

Com esta branch instalada e o 3ds Max fechado durante a cópia:

1. Ativar Cota contínua em modo Horizontal.
2. Clicar em três ou mais vértices desalinhados em Y.
3. Mover o cursor e confirmar com um clique vazio: as cotas devem ficar em uma única linha horizontal.
4. Repetir em Vertical com vértices desalinhados em X.
5. Confirmar que um único Undo remove toda a sequência e Redo restaura.
6. Criar outra sequência imediatamente, sem reiniciar a ferramenta.
7. Confirmar que clique sobre geometria sem vértice válido não encerra a sequência e que Esc/botão direito cancela.

Somente após aprovação desse gate a E12-C deve ser marcada como concluída e a E12-D pode começar.
