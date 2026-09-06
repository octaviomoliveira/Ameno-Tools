# E13 — Correções do feedback visual (2026-09-06)

Estado: implementadas e instaladas; hotfix de posição preparado, reinstalação e aceitação visual do hotfix pendentes.
Branch/worktree: `develop`, `D:\Ameno\_worktrees\develop`; base `ba4778a`.

## Pedido e alterações

As duas capturas do usuário mostram listas com texto branco sobre branco e rótulos horizontais cruzando a linha de cotas verticais.

- `Contents/scripts/ameno/ui/ameno_cotas_window.ms`: compartilha os recursos escuros existentes de Estilos com as demais abas; inclui template do popup e dos itens.
- `Contents/scripts/ameno/ui/ameno_cotas_estilos_tab.ms`: botão **Atualizar todas as cotas**, mantendo o botão de seleção; diálogo de nome antes de Novo/Salvar; cancelar e vazio não salvam; Salvar rejeita nome já usado por outro estilo.
- `Contents/scripts/ameno/core/ameno_style_service.ms`: aplicação global usa os controllers da cena, sem selecionar objetos; preserva a transação Undo existente. A ação aplica o estilo do rascunho a todas as cotas, não apenas às já vinculadas a esse estilo.
- `Contents/scripts/ameno/ui/ameno_cotas_criar_tab.ms`: opção **Texto acompanha a orientação da linha**, ligada inicialmente; mudança bloqueada durante ferramenta ativa. Conversão explícita para Nullable Boolean exigida pelo WPF/.NET 8.
- `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`: texto gira conforme a direção XY da cota, normalizado para leitura; preferência registrada em `Ameno.TextFollowsLine` no controller e rótulo, preservada por rebuild/sync. Cotas antigas sem a propriedade mantêm orientação horizontal; não há migração silenciosa da cena existente. A opção se aplica às novas cotas individuais e contínuas.
- Hotfix de posição: o `TextPlus` estava recebendo a rotação depois de uma posição mundial não nula, fazendo o pivot girar o ponto de inserção em torno da origem. `createTextNode()` e `updateTextNode()` agora zeram a posição antes de orientar e restauram `textPosition` depois; preview, commit e rebuild usam a mesma regra.
- `tests/maxscript/test_e13_visual_feedback.ms`: regressão específica de template, controles, orientação, rebuild/sync, nome e aplicação global sem seleção.
- `tests/maxscript/test_e13_text_commit_position.ms`: reproduz preview/commit vertical, compara a posição calculada e confirma orientação após o commit.

## Validação e limites

Logs desta rodada: `.test-output/visual-feedback/`, arquivos separados por suíte (`*-runner.log`, `*-listener.log`, `*-system.log`). Conferir resultado do runner e ausência de FAIL, não só ocorrência de PASS.

Reexecução final após a correção Nullable: `test_e13_visual_feedback` 18 PASS; `test_e13_stage2_create` 21 PASS; `test_e13_stage3_styles` 25 PASS. Todos com Batch exit 0 e zero FAIL: 64 marcadores PASS no total. `git diff --check` aprovado. Código e documentação registrados no commit desta entrega (consultar `git log -1`); ZIP e logs são artefatos locais não versionados.

Hotfix de posição: `test_e13_text_commit_position` 4 PASS; `test_e13_visual_feedback` 18 PASS; `test_e13_stage2_create` 21 PASS; `test_e13_stage3_styles` 25 PASS. Todos com exit 0 e zero FAIL. O diagnóstico capturou antes a rotação indevida da posição (`expected=[32.3622,50.0,0.0]`, observado `[-50.0,32.3622,0.0]`) e depois confirmou preview/commit em `[32.3622,50.0,0.0]`.

Falha descoberta na regressão Criar: atribuir `true` diretamente a `CheckBox.IsChecked` lançou erro de conversão para `System.Nullable[Boolean]` e interrompeu a atualização de unidade/precisão. A primeira execução terminou com exit -130 e 2 marcadores FAIL (uma asserção e o resumo), preservada em `stage2-failed-listener.log`/`stage2-failed-system.log`. Diagnóstico em `stage2-diagnostic-listener.log`; corrigido usando o mesmo tipo Nullable já empregado em Estilos/Editar, com duas verificações novas no teste específico. O catch de sincronização agora registra a exceção em vez de silenciá-la.

Validação estrutural `tools/validate-package.ps1`: aprovada. ZIP novo `dist/AmenoTools-0.0.1-e13-feedback1.zip`, 137824 bytes, SHA-256 `2289B9D8753DD1FA38A4D3B0302979D2B5FCD455D891A8A2C04F66902E5C4463`; todos os 44 arquivos do ZIP conferidos por hash com o worktree. O candidato anterior não foi sobrescrito.

Não validado nesta rodada: diálogo modal por interação humana, legibilidade visual dos popups em DPI real, viewport após reinstalação, save/load específico da nova propriedade. O teste de nome usa parâmetro de teste para não abrir um diálogo bloqueante no Batch. Não confundir teste de template/transform com aprovação visual.

## Instalação e continuidade

Instalação ativa em `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`: atualização do commit `20d618f` instalada com autorização do usuário em 2026-09-06. Os 42 arquivos do pacote instalado conferem por SHA-256 com o `develop`; o teste pelo caminho instalado terminou com exit 0 / 1 PASS / 0 FAIL. Backup anterior: `D:\Ameno\backups\AmenoTools-before-e13-20260906-120546` (26 arquivos). Evidências: `.test-output/visual-feedback/test_installed_package-runner.log` e `test_installed_package-listener.log`.

As correções acima estão instaladas. A sessão interativa foi preservada e o Max foi reaberto após a instalação; nenhum teste destrutivo foi executado nela. Nenhum merge/push/publicação.

Próximo passo: fechar o Max para instalar o hotfix; depois conferir no Max a criação de cotas verticais/contínuas, incluindo preview versus commit e Undo/Redo. Não declarar E13 aprovada até o gate manual.
