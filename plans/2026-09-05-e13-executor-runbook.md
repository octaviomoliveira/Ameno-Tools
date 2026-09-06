# E13 — roteiro de implementação e aceitação por etapas

Data: 2026-09-05. Documento operacional para troca de agente/modelo.
Pedido: integrar a interface E13 feita no Antigravity com a E12 aprovada, corrigindo os problemas auditados, uma etapa por vez.
Estado: PLANEJAMENTO CONCLUÍDO. Nenhuma etapa de implementação iniciada por este roteiro.

## 1. Contexto que o executor precisa preservar

- Repositório principal: `D:\Ameno\_tools`; main publicada em `f131f089af03892f33a9c86e2df8d3e3288d75a9` na última verificação.
- Fonte E13: `feature/e13-unified-ui`, commit auditado `676e008c200c91478242630defef4f607d671452`; checkout `D:\Ameno\_worktrees\e13-unified-ui`.
- E13 NÃO contém a E12: nasceu antes dela. Não instalar diretamente esse checkout e não substituir arquivos inteiros escolhendo indiscriminadamente um lado do merge.
- E12 R0–R6: aprovada em Batch e pelo usuário no Max, incluindo cadeia H/V, mesmo vértice da geometria reutilizado H→V, finalização e Ctrl+Z/Y. Código instalado aprovado era R4 `688c8bc`; commits seguintes foram documentação/testes. Confirmar instalação atual antes de qualquer cópia, pois outro agente pode ter trabalhado nela.
- Branches antigas E12 foram apagadas após merge. Histórico permanece na main. Não recriá-las para implementar E13.
- Main tem modificação preexistente em `tests/maxscript/batch-isolated.ini`. Preservar; não publicar nem descartar automaticamente.
- A E12 não entrega cadeia alinhada oblíqua nem identidade persistente de cadeia para edição conjunta. Não ampliar esse escopo implicitamente. Cota individual alinhada é uma funcionalidade distinta.
- Reuso é geometria→cota; não criar vínculos cota→cota por inferência.
- Este documento e a entrada em PLAN.md são alterações de documentação ainda não necessariamente commitadas. Transportá-las para a branch de integração sem perdê-las.

## 2. Protocolo obrigatório de continuidade

1. Ler PLAN.md, este roteiro e eventuais AGENTS.md aplicáveis. Inspecionar status, branches, worktrees e último handoff antes de editar.
2. Executar somente a próxima etapa liberada. Um pedido genérico de seguir avança uma etapa; não instalar/publicar etapas seguintes por conta própria.
3. Marcar checkbox apenas após evidência. Distinguir código pronto, teste automatizado e aprovação manual; não chamar tudo de OK após apenas carregar o bootstrap.
4. Ao terminar cada etapa, atualizar este checklist, PLAN.md e `plans/2026-09-05-e13-etapa-N-handoff.md`. Registrar arquivos, commit se houver, testes/contagens, logs, limitações, estado da instalação e próximo passo.
5. Se houver falha, registrar PENDENTE com reprodução; não ajustar expectativa de teste só para obter PASS.
6. Trabalhar em cenas descartáveis. Não rodar scripts destrutivos na cena interativa do usuário. Não fechar Max sem sua concordância.
7. Instalação e publicação são estados separados. Nenhuma autorização de push/merge da E12 deve ser interpretada como publicação automática da E13.

### Painel de progresso

| Etapa | Código + testes | Manual | Estado |
|---|---|---|---|
| 0 — Plano e direcionamento | [x] | não se aplica | OK documental |
| 1 — Base integrada | [ ] | não exige instalação | PENDENTE |
| 2 — Criar e ciclo de vida | [ ] | [ ] | PENDENTE |
| 3 — Estilos e rascunho | [ ] | [ ] | PENDENTE |
| 4 — Editar e reancorar | [ ] | [ ] | PENDENTE |
| 5 — Terminais e transações | [ ] | [ ] | PENDENTE |
| 6 — Render e restauração | [ ] | [ ] | PENDENTE |
| 7 — Candidato, aceitação e publicação | [ ] | [ ] | PENDENTE |

Os gates manuais 2–6 podem ser executados juntos no candidato da etapa 7. Até lá manter a coluna manual pendente; etapa pode ficar IMPLEMENTADA/TESTADA, nunca APROVADA FINAL.

## 3. Etapa 1 — Preparar e integrar a base

- [ ] Conferir `git status`, `git worktree list`, fetch origin e hashes. Se E13 ou main avançaram, revisar o delta além dos commits auditados antes do merge.
- [ ] Criar branch proposta `integration/e13-on-e12` a partir da main atual em `D:\Ameno\_worktrees\e13-integration`, após verificar que nome/diretório não pertencem a outro trabalho. Se já existir, inspecionar e retomar, não sobrescrever.
- [ ] Transportar este plano e a atualização documental de PLAN.md para a integração. Preservar a alteração INI da main.
- [ ] Incorporar feature/e13-unified-ui. Conflitos previstos: `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`, `ameno_dimension_tool.ms`, `Contents/scripts/ameno/ui/ameno_main_panel.ms`.
- [ ] Graphics: conservar alocação rastreada, rollback, `useUndo` e transação externa E12; acrescentar terminais, campos do record e passagem `style:style` E13. Não duplicar Undo de cada segmento dentro da cadeia.
- [ ] Tool: conservar resolução geométrica/picking E12 e integrar exclusão de meshes técnicos E13. Nome AMENO não deve ser a única garantia; conferir metadados e IDs.
- [ ] Painel: adotar entrada da janela WPF, inventariando funções públicas antes de retirar rollouts. Preservar funções de compatibilidade ainda chamadas pelo runtime e ferramenta.
- [ ] Revisar auto-merges de runtime/bootstrap/test_bootstrap: carregar math/input/diagnostics/continuous E12 e terminal_mesh E13 antes dos consumidores; manter startContinuousDimensionTool disponível.
- [ ] Conferir funções de desligamento/reload, chamadas ao painel antigo e referências globais; pesquisar consumidores, não apenas definições.
- [ ] Validar pacote, bootstrap e suítes E12 existentes; registrar falhas de integração. Não instalar ainda.

OK: árvore sem conflitos, módulos presentes, bootstrap funcional e E12 preservada. Não exige que os defeitos específicos de interface das próximas etapas já estejam corrigidos; eles devem estar registrados.

## 4. Etapa 2 — Aba Criar e interação

Arquivos principais: `ameno_cotas_criar_tab.ms`, `ameno_runtime.ms`, `ameno_cotas_window.ms`, `Contents/macroscripts/AmenoTools.mcr`; consultar contrato de `ameno_dimension_continuous_tool.ms`.

- [ ] Substituir TODO do handler onCotaContinua por chamada real ao runtime. Fazer botão e macro passarem pelo mesmo caminho.
- [ ] Mapear modo/unidade/precisão/estilo para os campos existentes do motor. Conferir os nomes no código antes de criar qualquer propriedade nova.
- [ ] Sincronizar controles a partir do serviço ao abrir/voltar à aba; retirar defaults visuais que discordem do estado ativo.
- [ ] Respeitar modo congelado da sessão contínua E12. Mudança de controles durante sessão não deve reinterpretar pontos já coletados.
- [ ] Manter rejeição explícita de cadeia oblíqua não implementada e funcionamento de alinhada individual.
- [ ] Revisar foco após clique WPF, Esc/botão direito, término e reinício. Não reintroduzir duplo clique/temporização para confirmar.
- [ ] Atualizar contagem da cena após criação/remoção/Undo sem apagar rascunhos de outras abas.
- [ ] Criar teste de comportamento do comando compartilhado e sincronização de estado; presença da função não basta.

Manual futuro: criar H com 4 vértices; finalizar; criar V reutilizando vértice direito sob anotação; confirmar losangos, clique vazio e saída; Ctrl+Z remove cadeia inteira e Ctrl+Y restaura. Testar botão e macro, sem duplicação.

## 5. Etapa 3 — Estilos, navegação e ciclo de cena

Arquivos: `ameno_cotas_estilos_tab.ms`, `ameno_cotas_window.ms:setTabContent`, stub `ameno_main_panel.ms:AmenoRefreshMainPanel`, `ameno_style_editor_wpf.ms`, runtime/callbacks.

- [ ] Corrigir build que recria currentDraft a partir de default em toda visita. Manter controles em cache OU manter modelo de estado independente deles, escolhendo uma abordagem única.
- [ ] Refresh genérico não pode substituir rascunho editado. Separar refresh de contagem/seleção de troca explícita de estilo/cena.
- [ ] Definir salvar/descartar/cancelar para troca de estilo e fechamento com rascunho sujo, reaproveitando contrato E11. Cancelar conserva tudo.
- [ ] Ao reset/abrir cena, invalidar referências da cena anterior e recarregar estilos da nova; rascunho antigo não pode ser aplicado silenciosamente à nova cena.
- [ ] Revisar salvar, duplicar, excluir estilo em uso, presets e aplicar à seleção; manter persistência e Undo existentes.
- [ ] Revisar fechamento/reabertura/reload: remover callbacks/eventos próprios sem remover os de outras funcionalidades.
- [ ] Testar rascunho alterado → outra aba → retorno com valores e dirty preservados; salvar e reabrir cena; cancelamento de descarte; aplicação + Undo/Redo.

OK manual: não perder trabalho ao navegar e não carregar dados da cena anterior.

## 6. Etapa 4 — Editar, validar e reancorar

Arquivos: `ameno_cotas_editar_tab.ms`, serviços runtime/graphics/anchors existentes.

- [ ] Validar somente campos do modo escolhido antes de escrever dados. Não usar 1000 mm/50 mm como substitutos silenciosos de entradas inválidas.
- [ ] Tratar vazio, letras, vírgula decimal, ponto, zero e negativo. Reusar limites do serviço; quando inválido, mensagem clara, nenhum dado alterado e nenhum Undo vazio.
- [ ] Preservar medição real, override, motivo e unidades; verificar conversão explícita cm→mm e m→mm dos campos rotulados.
- [ ] Atualizar painel na seleção e Undo/Redo, sem recursão de handlers.
- [ ] Reancorar usando picking geométrico E12; não aceitar terminal/texto como geometria. Confirmar vertexId no serviço de âncoras.
- [ ] Cancelar pick não deve converter uma âncora para mundial por acidente; exigir ação explícita para tal mudança.
- [ ] Revisar seleção única/múltipla, controlador inválido, órfãs, aplicação de estilo e retorno ao valor medido.
- [ ] Exercitar editar → Undo → Redo, reancorar → mover vértice, excluir geometria e restaurar; incluir entradas inválidas nos testes.

## 7. Etapa 5 — Terminais, preview e transação

Arquivos: `ameno_dimension_terminal_mesh.ms`, `ameno_dimension_graphics.ms`, preview renderer, input/picking E12 e testes.

- [ ] Buscar todos os consumidores de updateTerminal. Corrigir b2 com sinal oposto a b1; tamanho deve vir de parâmetro/metadado estável, não de aresta diagonal que cresce a cada atualização.
- [ ] Testar área não nula, simetria e tamanho após várias atualizações; criação/atualização/remoção de arrowClosed, diamond e dot.
- [ ] Derivar orientação do plano suportado pelo layout, não presumir Z global. Validar vistas suportadas; fora do escopo, rejeitar claramente em vez de ampliar matemática sem plano.
- [ ] Conferir material, layer, DimensionId, GraphicRole e marca terminal; limpar todos os nós em rebuild/delete/rollback.
- [ ] Conferir updateDimensionFast/serviço de âncoras: meshes devem acompanhar movimento junto com spline e texto, inclusive após alteração do estilo.
- [ ] Implementar paridade de terminal no preview pertinente sem reintroduzir previews de segmentos onde E12 deliberadamente usa apenas marcadores de referências. Mapear hover, preview de posicionamento e editor separadamente.
- [ ] Falha ao criar terminal obrigatório não pode ser engolida e produzir cota incompleta. Propagar falha para a transação E12 e remover alocações parciais.
- [ ] Injetar falha no segundo segmento com terminais; zero resíduos, draft preservado, Undo não suspenso; repetir criação com sucesso e Ctrl+Z/Y.
- [ ] Testar snap sobre mesh técnico coincidente com vértice real, persistência save/load, rebuild e mudança entre terminal spline/mesh.

OK: cadeia e nós técnicos permanecem íntegros em sucesso, falha e reconstrução.

## 8. Etapa 6 — Render e restauração

Arquivos: `ameno_cotas_render_tab.ms`, serviço render existente e adapters apenas se necessário.

- [ ] Preferir câmera explícita no pedido se o serviço já suportar. Caso precise trocar viewport, guardar identidade da viewport, tipo, câmera, transform e FOV/zoom relevantes com APIs verificadas para Max 2026.
- [ ] Restaurar em sucesso, cancelamento e exceção antes de anunciar cena restaurada. Reportar falha de restauração em vez de escondê-la.
- [ ] Preservar caminho, câmera e escopo ao alternar abas. Atualizar lista sem resetar seleção válida; tratar câmera removida da cena.
- [ ] Validar saída PNG, caminho inexistente, proteção contra sobrescrita, escopo sem cotas, cancelamento e renderer não suportado.
- [ ] Conferir nós mesh no isolamento/material/alpha; preservar Beauty, LightMix e Render Elements conforme contrato existente.
- [ ] Testar seleção de câmera partindo de perspectiva livre com enquadramento conhecido e comparar estado antes/depois.
- [ ] Render real no Corona disponível; V-Ray CPU somente se disponível e validado. GPU continua experimental; registrar não testado quando aplicável.

## 9. Etapa 7 — Candidato e entrega

- [ ] Reexecutar conjunto combinado após alterações finais: pacote/bootstrap; E12 input/math/commit/continuous/R0–R4; E13 A–H/audit_fixes; testes novos de integração; E10/E11 impactados e persistência.
- [ ] Registrar código exato testado e contagens. Corrigir erros antes de preparar candidato.
- [ ] Preparar backup recuperável do pacote instalado e manifesto SHA-256 do candidato. `tools/install-dev.ps1` remove recursivamente o destino: ler script e validar caminho exato ANTES de usar; backup deve existir fora do destino.
- [ ] Confirmar Max fechado antes de instalar. Conferir hashes do pacote instalado e testar bootstrap/installed package pelo caminho instalado.
- [ ] Executar gates manuais 2–6 em cena de teste e fechar/reabrir painel/cena. Solicitar ao usuário apenas os passos concretos que exigem interação.
- [ ] Registrar aprovação do usuário e limitações por renderer/vista. Não inventar aprovação visual a partir de Batch.
- [ ] Atualizar PLAN.md e handoffs, inclusive situação histórica E12 já publicada. Manter f131f08 como referência recuperável.
- [ ] Commitar somente arquivos relevantes; conferir diff/status, autorizações de merge/push E13 e publicar quando autorizado. Verificar hash remoto após push.
- [ ] Não apagar branch E13/worktrees antes da aceitação e autorização de limpeza.

## 10. Execução dos testes: cuidados descobertos

O runner atual `tools/test-maxscript.ps1` aceita qualquer ocorrência de `[AMENO_TEST][PASS]` e não rejeita explicitamente `[AMENO_TEST][FAIL]`. Portanto exit code 0 e mensagem OK do runner NÃO comprovam suíte aprovada. Na etapa 1, endurecer runner para rejeitar FAIL e verificar conclusão da suíte, ou fazer validação adicional equivalente documentada. Alguns testes E13 verificam só existência de métodos: acrescentar testes comportamentais nos pontos corrigidos.

Interface real do runner: `-MaxBatchPath`, `-ConfigPath`, `-TestScript`. Usar scripts e config do worktree integrado. Não inventar switches. O runner sobrescreve `.test-output/listener.log` e `system.log`: executar suítes sequencialmente por worktree e copiar logs após cada uma para diretório identificado por etapa/suíte. Não usar logs antigos como evidência de execução atual. Conferir o INI para garantir isolamento; não publicar mutações geradas pelo Max sem revisão.

## 11. Modelo de handoff a preencher

```text
Etapa: N / título
Estado: PENDENTE | EM IMPLEMENTAÇÃO | IMPLEMENTADA/TESTADA | AGUARDA MANUAL | OK
Branch/worktree:
Base e HEAD atual:
Arquivos alterados:
Problema e comportamento final:
Testes executados / contagens / logs:
Não testado e motivo:
Instalação ativa / backup / hashes:
Aprovação manual (fala/data; ou PENDENTE):
Commit (ou alterações não commitadas):
Próximo passo exato:
```

Primeira ação do próximo agente: etapa 1, inspecionar estado e criar/retomar integração. Não partir diretamente para instalar E13.
