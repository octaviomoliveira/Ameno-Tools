# Plano compartilhado — Ameno Tools

> Fonte de continuidade do projeto para qualquer pessoa ou agente (incluindo Antigravity).
> Atualizado: 2026-09-04

## Regra de trabalho

Cada solicitação nova deve atualizar este arquivo **antes de encerrar a tarefa**:

1. registrar o pedido no histórico;
2. mover itens concluídos para **Concluído** com evidência (arquivo, teste ou commit);
3. atualizar **Em andamento** e **Próximo passo**;
4. quando a decisão for duradoura, criar ou atualizar uma ADR em `docs/decisions/`.

Não substituir o histórico: acrescentar uma entrada datada. O plano corrente é este arquivo; `plans/` guarda marcos e handoffs mais detalhados.

## Objetivo do MVP

Entregar, no 3ds Max 2026, o primeiro módulo do Ameno Tools: **Ameno Dimensions**. Ele deve criar cotas rápidas, editáveis e persistentes para plantas humanizadas, com apresentação controlável e uma saída de render independente para composição.

## Concluído

- Repositório Git local criado e fundação `0.0.1` do pacote `ApplicationPlugins` estruturada.
- Pacote carregado e smoke testado no 3ds Max 2026.3.
- Validação manual no 3ds Max concluída: painel `Ameno Tools 0.0.1 · Max 2026` aberto e Corona identificado como `suportado`.
- E1 implementada e aprovada em testes automatizados no 3ds Max 2026.3: `Preparar esta cena` cria infraestrutura idempotente, protege conflitos de layer e restaura a layer corrente.
- Cópia de desenvolvimento atualizada em `ApplicationPlugins` e validada em processo separado do 3ds Max Batch.
- E1 aprovada visualmente no 3ds Max: painel exibiu `Cena preparada`, `AMENO_COTAS` e `AMENO_SYSTEM`; registro e estilo padrão apareceram na layer de sistema.
- E2 implementada e aprovada em testes automatizados no 3ds Max 2026.3: layout de cota alinhada no plano XY, conversão canônica para milímetros, arredondamento por incremento e formatação determinística.
- E2 não cria objetos, layers, callbacks ou histórico de Undo; ela recebe pontos e devolve dados prontos para a representação gráfica da E3.
- E3 implementada e validada em Batch isolado no 3ds Max 2026.3: construtor gráfico cria controlador oculto, cinco segmentos de spline e rótulo TextPlus a partir de três pontos conhecidos; a reconstrução remove e recria somente os filhos gráficos.
- E3 aprovada no uso visual informado pelo usuário: Arnold exibiu a cota no render, V-Ray exibiu a cota com a iluminação da cena e `Limpar cotas de teste` removeu a cota sem resíduos. A diferença observada no Corona sem luz fica registrada como requisito da E9 (overlay independente), não como bloqueio da criação gráfica da E3.
- E4 implementada e aprovada em Batch isolado no 3ds Max 2026.3: o `MouseTool` conduz A/B/afastamento, atualiza uma prévia temporária, cria a cota permanente pelo construtor da E3 e cancela sem deixar nós. Após o primeiro teste manual, o encerramento automático no terceiro evento foi removido: a ferramenta agora só termina quando o commit confirma sucesso e mostra a exceção real se houver falha.
- E4 aprovada manualmente no 3ds Max em 2026-09-04: o fluxo de três cliques criou uma cota permanente de `4,05 m`, o painel mostrou `1 cota(s) ativa(s)` e a geometria permaneceu visível no viewport.
- E5 implementada e aprovada em testes automatizados no 3ds Max 2026.3 Batch e no pacote instalado via `ApplicationPlugins`: controlador Point técnico agora possui Custom Attributes versionados (`AmenoDimensionCA` v1); persistência geométrica comprovada em ciclo save/load de arquivo `.max`; renomeação livre de nós preserva a identidade da cota; rotina de inspeção e reparo não-destrutivo (`inspectDimension`, `repairDimension`, botão `Reparar cotas` no painel) regenera nós visuais ausentes sem duplicar controladores; callbacks de ciclo de vida (`#filePostOpen`, `#postSceneReset`) sincronizam diagnósticos ao abrir cenas; Undo atômico (`max undo`) validado em um único passo.
- Pacote instalado com E1, E2, E3, E4 e E5 validado em Batch isolado; as cópias dos módulos críticos foram conferidas por SHA-256 contra o fonte.
- Ação `Ameno Tools` e painel inicial registrados; bootstrap modular e validação de pacote incluídos.
- Modelo de dados inicial para cotas, estilos, referências e valores medidos/arredondados/manuais documentado.
- Regras decididas para `AMENO_COTAS`, geometria renderizável, render separado de cotas e preservação do Beauty, LightMix e Render Elements existentes.
- Fluxo do valor manual definido: a substituição não altera a medida real, é persistida no dado da cota e aparece em âmbar apenas na viewport.
- Editor de estilo especificado com inspiração na edição direta do TextPlus: fonte, tamanho, linhas, espessuras e tipos de seta com prévia.
- Estratégia de render definida: Corona como referência obrigatória; V-Ray CPU como segundo adapter oficial; V-Ray GPU separado e experimental até ser validado.
- Escopo inicial definido para 3ds Max 2026; compatibilidade 2021–2025 será avaliada após o MVP estar estável.

## Em andamento

- E5 — persistência, Undo e reabertura — implementada, instalada no `ApplicationPlugins` e aprovada em Batch isolado; aguardando gate manual no 3ds Max.
- A E2 foi concluída por solicitação explícita, pois é um núcleo puro e independente da cena.
- A falha de bootstrap relatada após a primeira instalação da E3 foi corrigida: `throw getCurrentException()` é inválido dentro de `catch` no MAXScript e foi substituído por `throw`. O teste Batch passou a usar perfil isolado, portanto não exige fechar a sessão interativa do usuário.
- O diagnóstico adicional de render foi encerrado sem alterar a cena do usuário: o resultado confirmado é Arnold funcionando, V-Ray funcionando quando há luz na cena e limpeza funcionando. Não serão mantidos probes temporários no repositório.

## Próximo passo executável

Executar a validação manual da **E5 — Persistência, Undo e reabertura** no 3ds Max: reiniciar o 3ds Max, criar uma cota com a ferramenta de três cliques, salvar o arquivo `.max`, fechar e reabrir a cena; confirmar que o painel reconhece a cota ativa e que a geometria permanece íntegra; testar exclusão acidental de uma linha ou texto e clicar em `Reparar cotas` para validar a restauração sem resíduos; confirmar Undo atômico em um único passo.

## Decisões que ainda exigem validação

- Versões mínimas de Corona e V-Ray disponíveis no ambiente real.
- Se a interface inicial será somente em português ou já bilíngue.
- Serviço/visibilidade do repositório Git remoto e política de acesso.
- Licença e modelo de distribuição.

## Histórico de solicitações

| Data | Pedido / decisão | Situação | Evidência |
| --- | --- | --- | --- |
| 2026-09-03 | Estruturar Ameno Tools e iniciar pelo módulo de cotas para plantas humanizadas. | Concluído na fundação | `README.md`, `docs/`, pacote `0.0.1` |
| 2026-09-03 | Usar layer exclusiva, manter Beauty/LightMix intactos e renderizar cotas separadamente para composição. | Decidido e documentado | `docs/decisions/0002-*`, `0003-*` |
| 2026-09-03 | Permitir valores manuais auditáveis com alerta visível somente no viewport. | Decidido e documentado | `docs/decisions/0004-*`, `docs/manual-overrides.md` |
| 2026-09-03 | Priorizar 3ds Max 2026; Corona primeiro, com compatibilidade planejada para V-Ray. | Decidido e documentado | `docs/decisions/0005-*`, `0006-*` |
| 2026-09-03 | Centralizar o projeto em `D:\Ameno\_tools` e manter planos atualizados para continuidade via Antigravity. | Concluído | Repositório Git íntegro em `D:\Ameno\_tools`; origem removida após confirmação de vazio |
| 2026-09-03 | Confirmar o pacote aberto no 3ds Max e dividir o funcionamento do plugin em etapas pequenas. | Concluído no planejamento; E1 é a próxima implementação | `plans/2026-09-03-mvp-incremental.md` |
| 2026-09-03 | Seguir para E1 e registrar cada etapa em Markdown e GitHub. | E1 implementada, testada em Batch e pronta para validação visual; commit local `92bddd1`; GitHub bloqueado porque nenhum remoto está configurado | `Contents/scripts/ameno/core/ameno_scene_setup.ms`, `.test-output/*e1*` |
| 2026-09-03 | Conectar `github.com/octaviomoliveira/Ameno-Tools` e seguir para E2. | `origin/main` publicado; E2 implementada e aprovada em Batch e no pacote instalado; commits `70c0fb2` e `78e54d7` publicados | `Contents/scripts/ameno/core/ameno_dimensions_math.ms`, `.test-output/*e2*` |
| 2026-09-03 | Conferir a tela atual do Ameno Tools para validar E1. | Instalação confirmada por hash; a tela mostrada pertence à sessão anterior ao reload. Aguardando reinicialização completa do 3ds Max | `ApplicationPlugins\AmenoTools\Contents\scripts\ameno\ui\ameno_main_panel.ms` |
| 2026-09-03 | Reabrir o Max e validar E1; seguir para a próxima etapa. | E1 aprovada visualmente; E3 iniciada | captura do painel e Layer Explorer fornecida pelo usuário |
| 2026-09-03 | Seguir após reiniciar o Max. | E3 implementada e instalada; aguardando gate manual. A validação Batch foi concluída depois em perfil isolado. | `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`, cópia `ApplicationPlugins` conferida por SHA-256 |
| 2026-09-03 | Corrigir tela “O núcleo do Ameno Tools não foi carregado”. | Corrigido, testado no 3ds Max 2026.3 em Batch isolado e no pacote `ApplicationPlugins`; a mensagem futura agora inclui o módulo/erro reais. | `ameno_dimension_graphics.ms`, `ameno_bootstrap.ms`, `AmenoTools.mcr`, `.test-output/*e3*` |
| 2026-09-03 | Confirmar que a E3 funciona no Max após a correção. | Gate visual do viewport aprovado: uma cota ativa aparece com linhas, terminais e TextPlus `5,00 m`; `AMENO_COTAS` está selecionada. Render comum e limpeza ainda pendentes. | captura do viewport/painel fornecida pelo usuário |
| 2026-09-03 | Validar render e limpeza da E3; esclarecer o caso Corona sem luz. | Arnold exibiu a cota; V-Ray exibiu a cota com luz na cena; `Limpar cotas de teste` funcionou. A hipótese de ausência de luz no Corona permanece registrada para a E9, sem novos probes no pacote. | capturas de Arnold/V-Ray e confirmação textual do usuário |
| 2026-09-03 | Seguir para E4 e criar a ferramenta de três cliques com preview. | Implementada em `ameno_dimension_tool.ms`, integrada ao painel/bootstrap/runtime; smoke test E1–E4 passou e a instalação de desenvolvimento foi atualizada. Aguardando validação manual do fluxo no Max. | `.test-output/listener.log`, `ApplicationPlugins\\AmenoTools`, commit `a33139e` |
| 2026-09-03 | Corrigir o desaparecimento da prévia no terceiro clique. | Removido o limite `numPoints:3`: o MouseTool permanece ativo até o commit retornar sucesso, preserva a prévia em erro e o painel exibe a exceção. Teste Batch e teste do pacote instalado passaram. | `ameno_dimension_tool.ms`, `ameno_main_panel.ms`, commit `6ce2200` |
| 2026-09-04 | Confirmar a correção do terceiro clique no uso real. | Fluxo manual aprovado no Max: A/B/afastamento criou e manteve uma cota permanente de `4,05 m`; painel indicou `1 cota(s) ativa(s)`. E4 encerrada; próximo passo é E5. | captura do viewport/painel fornecida pelo usuário; commits `6ce2200` e `a868a4c` |
| 2026-09-04 | Implementar E5: persistência, Custom Attributes e ciclo de vida. | E5 implementada e aprovada em Batch isolado e no pacote ApplicationPlugins; aguardando validação manual no Max. | commit `9c78acf`, `ameno_dimension_ca.ms`, `0008-e5-custom-attributes-persistence.md` |

## Como retomar sem contexto

1. Leia este arquivo e depois `plans/2026-09-03-mvp-incremental.md`.
2. Execute `git status` e confirme que o estado local é o esperado.
3. Leia `README.md` e a documentação diretamente ligada ao próximo passo.
4. Implemente uma unidade pequena, teste no 3ds Max e registre o resultado aqui.
