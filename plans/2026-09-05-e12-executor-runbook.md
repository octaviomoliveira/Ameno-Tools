# E12-R — Recuperação executável da interação contínua

Data: 2026-09-05. Documento de implementação futura; nenhum código alterado nesta entrega.
Base auditada: `0859164` na branch `feature/e12-continuous-dimension`; inclui o código de `d8ce420`. Instalação ativa restaurada a `ba55d95`. Não são o mesmo código.

Este documento detalha e prevalece sobre as instruções de interação conflitantes dos planos anteriores. E12-D (alinhado oblíquo) e E12-E (registro persistente de cadeia) continuam pendentes. Não declarar o produto inteiro concluído ao finalizar E12-R.

## 1. Objetivo e decisões fechadas

Estabilizar uma sequência H/V em planta XY: selecionar referências reais, mostrar intervalos sobre uma baseline comum e criar a sequência no primeiro clique vazio. Sucesso encerra o comando e libera o mouse. Nova sequência exige nova ativação. Essa saída substitui o reinício automático previsto originalmente na E12-C, conforme o relato de finalização do usuário.

Esc e botão direito cancelam apenas o draft. Não confirmam. Undo remove uma sequência já confirmada. Sem duplo clique, sem timer para inferir intenção, sem depender de botão em HUD modal. Remover HUD flutuante do caminho normal; orientar por status e feedback de viewport.

Inicialmente somente Horizontal e Vertical. Alinhado deve ser bloqueado ANTES da captura de mouse, com explicação clara e sem mudar silenciosamente a escolha do usuário. Viewports/plano sem interseção utilizável também devem produzir diagnóstico explícito. Não expandir para cotagem 3D arbitrária.

Não prometer ausência absoluta de bugs. Exigir evidência por incremento: análise de código, teste automatizado apropriado e teste real de mouse nos gates indicados.

## 2. Auditoria concreta: o que o agente deve corrigir

| Local | Comportamento observado no código | Consequência / ação |
|---|---|---|
| continuous: detectHitNode | Retorna cedo se snap aponta para nó inelegível | Grid/preview pode impedir a investigação do alvo real. Separar snap de picking. |
| continuous: detectHitNode | Primeiro hit elegível em intersectRayScene, sem ordenar explicitamente; exceptions engolidas | Não assumir ordem/ausência; distinguir consulta vazia de consulta falha. |
| continuous: detectHitNode | Tolerância em unidades equivalentes a 10 mm | Sensação muda com zoom; introduzir tolerância em pixels para o candidato. |
| continuous: isEligibleReferenceNode | Filtra nome AMENO_ e metadado, sem exigir classe suportada | Nome de objeto legítimo pode ser rejeitado; helper não Ameno pode passar. Usar identidade/tipo/capacidade. |
| continuous: classifyDetectedHit | snap não resolvido vira ambiguous | A ausência de referência elegível não deve, sozinha, significar erro técnico. |
| continuous: handleClassifiedClick | Append de flattenPoint destrói Z; aceita vertexId=0 | Guardar posição original 3D; ID de vértice precisa ser >=1. |
| continuous: isDuplicateReference | Verifica identidade e distância XY, não estação H/V | Duas referências com mesmo X em H ou mesmo Y em V invalidam layout depois de aceitas. |
| continuous: calculateChainLayout/commitChain | Recusa aligned, mas begin e painel permitem iniciar | Bloquear na entrada e congelar modo da sessão. |
| continuous: handleMove de d8ce420 | Cria cota entre primeiro ponto e cursor livre com offset fictício | Não é uma referência confirmada; pode lançar erro por medida zero. Substituir por marcador simples. |
| continuous: handleMove | Não usa resolvedor de candidato para hover | Não há garantia de que marcador e clique concordam. |
| continuous: commitChain de d8ce420 | Chama stopTool dentro do serviço de criação | Mistura transação e ciclo do MouseTool; preferir resultado e #stop na borda do evento. |
| continuous: onAbort de d8ce420 | Pode confirmar ao abortar com >=2 pontos | Esc não pode criar cotas. Remover essa lógica explicitamente. |
| continuous: onStop | Fecha HUD antes de tornar active=false | Evento close do HUD pode chamar cancel/stop novamente. Cleanup deve ser idempotente. |
| continuous: catch/default | Alguns erros silenciosos; status de stop sobrescreve motivo | Preservar resultado final e mensagem útil até próxima ativação. |
| graphics: createVisualNodes | Cria linha e texto antes de decorar/registrar linha | Falha no texto pode deixar linha órfã. Registrar imediatamente ao alocar. |
| graphics: createDimension catch | Deleta apenas controller | Não cobre nó parcialmente criado antes de retorno nem falha dentro de createController. |
| graphics: createPreviewDimension | Sem guarda transacional entre criação de linha e texto; herda renderable | Pode vazar preview e disputar snap/render. |
| graphics: updatePreviewDimension | Pode retornar undefined antes de apagar nós antigos | Sobrescrever registro com undefined perde a referência para cleanup. |
| chain math: layout | Ordena estações e rejeita coincidentes; contém cálculo aligned | Reutilizar H/V; presença da fórmula aligned não prova integração de gráficos/reatividade. |
| anchor service | Reconstrói cada filho via layoutForMode | Não há registro de cadeia que gerencie cruzamento de âncoras; permanece fora da conclusão R. |
| painel: lblTestHint | Ainda diz duplo-clique confirma | Texto contradiz implementação; atualizar somente após contrato definitivo. |
| tests | Injeta kind:#empty e testa layout de registros/CA | Não prova captura, picking, geometria mundial real ou ausência de resíduos. |
| runner da branch | Logs fixos, INI direto, sem guarda de Max aberto | Isolar execução antes de confiar em PASS. |

Esses são achados estáticos. Não afirmar qual explica o último teste do usuário sem observar a sequência real de eventos.

## 3. Arquivos a ler e escopo permitido

Ler completamente as funções afetadas e localizar chamadores com rg antes de editar:

- `Contents/scripts/ameno/core/ameno_dimension_continuous_tool.ms`: serviço, HUD, MouseTool completo.
- `ameno_dimension_chain_math.ms`: resolveBasis, layout, sortByStation.
- `ameno_dimension_graphics.ms`: createController, createLineNode, createTextNode, createVisualNodes, createDimension, preview create/update/remove e decorators.
- `ameno_dimension_ca.ms`: readCA, resolveVertexWorld, findNearestVertex, resolvePoints. Reutilizar a leitura avaliada da E10.7; não substituí-la por baseObject.
- `ameno_anchor_service.ms`: rebuildIndex, atualização e cleanup; consultar para integração, não reescrever.
- `Contents/scripts/ameno/ui/ameno_main_panel.ms`: botão contínuo, seleção de modo e mensagens.
- Bootstrap e runtime: carga de módulos, reset/open/shutdown.
- Testes E12 input/math/commit/continuous, E10.7, bootstrap e runner.

Novos módulos sugeridos, NÃO APIs existentes: `ameno_continuous_input.ms` para amostra de evento/picking; `ameno_continuous_preview.ms` se isolamento de preview for necessário. Não criar módulos vazios nem reorganizar o plugin inteiro. Registrar cada inclusão no bootstrap e validar ordem.

Não alterar WPF E11, render Corona/V-Ray, schema CA v5 ou algoritmos E10.7 neste ciclo, salvo bug comprovado em dependência com teste e escopo explícito. Não migrar para C++ nem mouseTrack por preferência: usar spike comparativo somente se MouseTool impedir contrato de forma reproduzível.

## 4. Contratos internos propostos

Os nomes abaixo são contratos de projeto; adaptar ao MAXScript real sem inventar propriedades de APIs nativas.

### 4.1 InputSample, montado uma vez por evento

Campos: sessionId, sequência de evento, tipo, contador nativo, viewportId, posição em pixels relativa à viewport, rawWorldPoint informado pelo host, rayOrigin/rayDirection, snapHit/snapNode/snapWorldPoint, status da leitura do snap, status da consulta geométrica.

Capturar snap e posição ANTES de atualizar/criar preview ou disparar redraw. Erro ao consultar snap não pode virar snapHit=false com aparência de leitura válida. Não usar worldPoint automaticamente como cursor livre: ele pode já estar ajustado pelo snap. Manter plano XY em Z=0 para layout atual, mas preservar pontos 3D originais das âncoras.

Interseção independente para offset: para raio r=O+tD, t=(planeZ-O.z)/D.z. Se abs(D.z) <= epsilon, ou resultado inválido, retornar invalidPlane; não usar coordenada antiga. Documentar unidade e escolha de epsilon. Inicialmente aceitar planta Top/Bottom compatível e não prometer Front/Left. Comparar posição calculada com posição visual em viewport deslocada e DPI diferente.

### 4.2 PickResult

kind: reference | geometryWithoutReference | empty | ambiguous.
reasonCode obrigatório; reference contém nó, vertexId>=1, worldPoint3D, screenDistancePx, provenance. empty só quando a consulta aplicável terminou com sucesso sem alvo relevante. ambiguous é falha técnica, plano inválido ou candidato não resolvido de modo confiável; não é todo snap rejeitado.

Ordem de decisão:
1. Validar viewport/ray/estado.
2. Usar snap como candidato, validando metadado, nó e distância visual; não como comando de finalizar.
3. Excluir preview técnico. Para snap inelegível, continuar consulta normal.
4. Resolver nó(s) sob a região do cursor e vértices no raio visual, inclusive contorno onde um raio exato pode não cruzar triângulo. Não vasculhar vértices de toda a cena por movimento.
5. Ordenar hits de superfície por profundidade positiva explicitamente; registrar política em wireframe (usar superfície frontal; seleção de vértice posterior não entra neste ciclo).
6. Se houver candidato visível válido: reference. Havendo geometria relevante mas nenhum candidato: geometryWithoutReference. Se a consulta falhar: ambiguous. Somente consulta bem-sucedida vazia permite empty.

Pesquisa de candidato: projetar vértices avaliados em coordenadas de viewport e comparar distância 2D; raio inicial 10 px ajustável internamente. Não converter 10 px para 10 mm. Usar shortlist de nós por picking/região/bounds e cache por sessão; validar API de projeção e índice com microteste. Invalidar cache em alteração da geometria, transform e viewport; antes do clique revalidar o vencedor. Sem snapshot por vértice; liberar mesh temporária em sucesso e exceção.

Antes de implementar busca ampla, R2 deve provar uma forma correta de obter shortlist no contorno. Sem shortlist confiável, entregar limitação explícita e não confirmar automaticamente como vazio um clique sobre geometria não resolvida.

### 4.3 ReferenceDraft

Cada referência: identidade nó+vertexId, worldPoint3D original, ponto projetado XY, ordem de clique. Preservar arrays existentes inicialmente se necessário, mas centralizar append/remove e assertar comprimentos iguais. Não persistir Q (ponto da linha de cota) como âncora.

Validação pré-append: nó vivo, ID>=1, posição finita, identidade não repetida, estação não coincidente com existentes no eixo da sessão. H usa X; V usa Y. Tolerância numérica de estação não é tolerância visual de picking; manter unidade de cena e comportamento do math documentados. Para o teste, comparar também em escalas diferentes. Rejeitar somente candidato novo e conservar draft/preview anterior.

### 4.4 Estados e resultado

| Estado | Evento | Ação / próximo estado |
|---|---|---|
| idle | iniciar válido | preparar sessão, collecting |
| idle | modo/plano inválido | explicar; permanecer idle |
| collecting | referência válida | adicionar e atualizar preview, collecting |
| collecting | repetida/coincidente | orientar, sem alterar draft |
| collecting | geometryWithoutReference/ambiguous | orientar, sem confirmar |
| collecting | vazio com <2 referências | orientar, sem criar |
| collecting | vazio com >=2 referências | validar e entrar committing |
| committing | outro evento | ignorar para evitar reentrada |
| committing | falha | rollback próprio; collecting com draft e erro |
| committing | sucesso | result=committed, estado finished; evento retorna #stop |
| collecting | Esc/direito | result=cancelled, limpeza draft; saída |
| finished/cancelled | stop/finally repetido | cleanup idempotente; idle |

ServiceResult deve separar outcome, errorCode/message, IDs criados e quantidade. Preservar lastResult após cleanup. Somente próxima ativação o reseta. `commitChain` não chama stopTool; MouseTool traduz sucesso em #stop no retorno do handler. Callback de movimento não pode retornar #stop acidentalmente por valor de função interna. Não usar #abort como se fosse sinônimo documentado de #stop para sucesso.

## 5. Incrementos para execução, um gate por vez

### R0 — Base, isolamento e observabilidade (primeira entrega)

1. Ler PLAN, este documento e o plano anterior de pesquisa. Conferir status e HEAD. Não resetar trabalho alheio.
2. Criar branch/worktree de correção a partir do HEAD auditado mais este commit documental; nome sugerido `feature/e12-input-recovery`. Não editar a instalação nem trocar branch no worktree de outro agente.
3. Registrar diferenças ba55d95..d8ce420 no relatório. Reproduzir ba55d95 primeiro sem incorporar comportamento posterior por acidente.
4. Criar probe opt-in que envolva fronteiras reais de handlePoint/classifyClick/requestCommit/commitChain/onAbort/onStop. Salvar originais e restaurar ao desligar; alternativa é build diagnóstico explícito com o mesmo comportamento. Não modificar resultado/classificação no probe. Em funções que serão chamadas por .NET, usar função global, sem capturar variável local proibida.
5. Log limitado por sessão: commit/hash, evento, contador, stage, modo, contagem, ray/snap, classification.reason, commit begin/end/error e cleanup. Movimentos somente em mudança de candidato/estado; cliques sempre. Erro visível contém código consultável, sem despejar log na tela.
6. Cena descartável: plano/caixa Editable Poly segmentada H/V. Executar 2 referências + vazio em H; repetir com snap desligado, vertex ligado, grid ligado e cursor sobre preview. Separar pressionar, arrastar, soltar, clicar rápido, Esc e direito. Não assumir contador=clique físico; documentação inclui evento inicial e liberações.
7. Capturar um rastro que explique por que não chega a commit, ou prove que commit cria e comando fica aberto. Registrar causa confirmada vs hipóteses.

Gate R0: causa de pelo menos uma falha interativa identificada pelo trace. Se Max indisponível, deixar R0 pendente e entregar probe/roteiro; NÃO inventar diagnóstico nem seguir a implementação inteira.

### R1 — Ciclo de vida e modo (corrigir causa independente)

Arquivos: continuous e trecho contínuo do painel; teste `test_e12_r1_lifecycle.ms`.
1. Guardar modo/estilo/unidade da sessão; bloquear Alinhado antes de startTool. Não alterar cota simples.
2. Remover commit em onAbort de d8ce420. Esc/direito nunca criam.
3. Separar resultado de commit de parada; retornar #stop na borda do mouse após committed. Se criação falhar, conservar captura para retry com mensagem.
4. Implementar cleanup com guard reentrante: active=false antes de fechar janela; remover previews/hover próprios, restaurar estado temporário, zerar draft uma única vez. Preservar lastResult/IDs após sucesso.
5. Desativar abertura automática do HUD. Corrigir texto de duplo clique e mensagens “próximo gate”. Remover instrução de atalho indisponível; Backspace não é requisito até prova de evento suportado.
6. begin não deixa active preso se prepare/open/start lançar exceção; onStop/finally toleram dupla chamada.

Gate: abort com 0/1/3 referências não cria cotas; begin inválido não captura; sucesso retorna stop; falha permite retry; dupla limpeza não apaga cotas confirmadas. Atualizar teste antigo que exigia collecting depois do sucesso, documentando mudança de contrato, sem apagar asserts de Undo/Redo.

### R2 — Resolver entrada/picking e offset sem ambiguidade artificial

Arquivos: continuous + novo módulo somente se útil. Teste `test_e12_r2_picking.ms` e probe real.
1. Implementar InputSample/PickResult e funções de consulta substituíveis em teste. Testes injetam respostas de APIs na fronteira de aquisição, NÃO kind:#empty pronto.
2. Implementar offset do raio/plano separado de snap; guardar original 3D. Remover retorno antecipado por snap inelegível; distinguir falha de consulta de resultado vazio.
3. Implementar shortlist/ordenação/projeção em pixels conforme seção 4. Não aceitar helper arbitrário por nome; objetos Ameno identificados por CA/metadados/registro de preview. Não bloquear objeto legítimo apenas porque começa com AMENO_.
4. Testar bordas, wireframe, objeto atrás de outro, hidden/frozen, grid e preview. Estado snap do usuário é lido, não reconfigurado permanentemente.
5. Normalizar eventos somente com sequência observada em R0; deduplicar reentrega do mesmo evento, não cliques físicos por tempo. Não inferir mouse-down/up exclusivamente da paridade do contador.

Gate: vértice acrescenta, geometria sem vértice não confirma, grid em vazio pode confirmar, preview não bloqueia alvo atrás, erro do raycast não confirma. Clique real H/V chega a commit com snap ligado. Se evento/offset continuar errado, parar aqui com trace.

### R3 — Draft válido e preview que não vira alvo

Arquivos: continuous, preview graphics se necessário. Teste `test_e12_r3_preview.ms`.
1. Centralizar append/remove; manter original 3D e projeção separadas. Validar ID>=1 e estação antes de append. Exemplos: H (0,0),(0,8) rejeita segunda estação; H (0,0),(4,8) aceita.
2. Sem cota fictícia até cursor após primeiro ponto. Exibir apenas marca da referência e candidato. Com >=2 pontos, preview somente dos intervalos válidos de referências clicadas.
3. Hover usa o mesmo resolvedor de R2. Cor/forma sinaliza candidato válido; sumir quando não houver alvo e após stop. Manter marcador nativo se funcionar; caso desenhe próprio, usar callback de viewport global com registro único e remoção explícita. Não criar novo helper por movimento.
4. Garantir previews não renderizáveis e não candidatos. Se manter nós, testar mecanismo de não participação no snap; filtro de raycast por si só NÃO impede snap nativo. Avaliar flag suportada documentada ou desenho temporário em viewport. Trocar backend de preview apenas se necessário; não afetar geometria permanente.
5. Em erro de update, preservar registro anterior até cleanup; se criar parcialmente, registrar e remover nós. Não atribuir undefined ao único registro de nós vivos.
6. Clique e redraw não adicionam Undo; status explica referência rejeitada. Cache de hover invalidado e candidato revalidado no clique.

Gate: candidato destacado coincide com selecionado antes/depois do segundo ponto; estação rejeitada não some com preview; cancel/repetidas ativações sem nó/callback acumulado; teste com zoom e DPI registra alinhamento. Testar geometria 3D elevada para provar original preservado.

### R4 — Criação atômica inclusive falhas internas

Arquivos: graphics + continuous. Teste `test_e12_r4_transaction.ms`.
1. Não confiar só em createdIds após retorno de createDimension. Introduzir registro opcional de nós alocados, mantido pela tentativa, ou cleanup local equivalente em cada fábrica. Default preserva chamadas antigas.
2. Registrar nó imediatamente após construtor, ANTES de nome/tag/layer/estilo. Inclui controller, spline, TextPlus e marcador manual. Se fábrica interna falhar antes de retornar, deve limpar o próprio nó ou tê-lo registrado externamente. Propagar erro original.
3. Uma transação Undo para cadeia; validação/re-resolução de âncoras antes de criar. Snapshot lógico de draft/cursor permite retry. Preservar relação sourceIndexA/B da ordenação com nó+ID corretos.
4. Injetar falha: após controller; após linha antes de texto; durante decoração; segundo segmento; criação/update de preview. Não depender apenas do throw antes do segundo createDimension usado pelo teste anterior.
5. Rollback só registry da tentativa; não limpar layer, não chamar max undo para voltar arbitrariamente. Verificar Undo/Redo após falha: nós de tentativa fracassada não podem reaparecer. Se undo off na remoção gerar histórico inconsistente, corrigir escopo/transação e comprovar; não limpar histórico do usuário.
6. Material temporário sem uso não deve ser inserido em biblioteca nem mantido em registro global. Não remover materiais da cena preexistente.
7. Em sucesso remover previews sem apagar permanentes, rebuildIndex uma vez; erro de index precisa virar aviso explícito (não retornar falha de criação se cotas já foram confirmadas sem rollback).

Gate: contagem e handles de TODOS os objetos voltam ao pré-tentativa, exceto infraestrutura de cena explicitamente preparada antes do teste. Uma cadeia válida entra inteira em Undo/Redo, sem resíduos de preview. Geometria de nó spline em mundo e label conferidos, não apenas layout do DTO.

### R5 — Reutilização de referência de cota existente (gate de definição)

O relato “referência de outra cota” é ambíguo. Confirmar com usuário se é vértice da geometria ignorado ou ponta da anotação. R2 resolve primeiro caso. Não tornar TextPlus ou qualquer ponto de uma linha de cota uma âncora por adivinhação.

Se ele confirmar ponta da anotação: resolver dimensionId -> controller -> lado A/B -> referência original. Definir quais pontos visuais representam cada lado; texto, centro da linha e terminal fora de tolerância não servem. Usar posição projetada apenas para picking; guardar original nó/vertexId. Órfã não cria vínculo falso. Cota baked/localPoint exige DTO que suporte esse tipo e teste próprio; entregar mensagem de não suporte enquanto isso, sem forçar vertexId=-1 no caminho que exige vértice. Não criar dependência circular cota->cota.

Gate: adicionar pela ponta e mover geometria original atualiza; apagar anotação fonte não apaga vínculo ao modelo; preview próprio nunca vira fonte. Se pedido for só geometria, marcar esta extensão fora de escopo com resposta do usuário.

### R6 — Integração, instalação e aceitação

1. Executar suites novas por estágio, matemática H/V existente e regressivos pertinentes: bootstrap, cota simples, âncoras E10.7 e estilo afetado. Registrar resultados reais/skips; não prometer contagem prévia.
2. Teste completo deve passar por aquisição de InputSample, resolvedor, handler, criação e stop. Além dele, gate com cliques reais continua obrigatório.
3. Casos numéricos H: pontos (0,0),(4,1),(8,0),(12,2), offset (6,3) => linha Y=3 e medidas 4/4/4. V: transpor X/Y. Ordem inversa produz mesmos intervalos. Verificar nos nós gráficos mundiais e no texto com conversão de unidade.
4. Salvar/abrir cotas H/V e alterar estilo não deve desfazer baseline; mover âncora sem cruzar estações, testar Undo. Cruzamento/topologia e persistência conjunta seguem E12-E; registrar essa limitação explicitamente.
5. validate-package da origem selecionada; Max fechado antes de instalação. Copiar PackageContents.xml e Contents da MESMA origem. Criar backup fora de diretórios de descoberta de plugins (por exemplo D:\Ameno\_backups), para não arriscar carregar duas versões. Não remover backups antigos sem analisar alcance.
6. Comparar lista e hashes com commit de origem, incluindo dll/assets; registrar commit instalado, ramo e backup. Teste installed verifica origem real e não carrega bootstrap do worktree por engano.
7. Gate usuário: H e V, 2/4 referências, snap on/off, clique único vazio, Esc, botão direito, hover, ativar novamente, Undo/Redo. Log aponta resultado. Não automatizar cliques na cena do usuário sem autorização/contexto.

Conclusão: R aprovado somente após mouse real estável. Sem merge automático para main; apresentar versão e evidência ao usuário. Branch publicada por incremento, sem force push.

## 6. Infraestrutura de testes e regras práticas

- Antes de executar batch, ler runner. O runner E12 auditado usa logs fixos e não impede Max aberto. Corrigir isolamento em commit próprio se necessário: diretório por run/suite, INI gerado a partir de template, sem editar INI versionado, checagem de processos e nenhuma morte de processo alheio.
- Runner E10 usado anteriormente: `D:\Ameno\_tools-e10\tools\test-maxscript.ps1`, parâmetros reais `-ConfigPath` e `-TestScript`. Não existe `-ConfigTemplate`. Ele tem saída compartilhada: só usar serialmente e preservar log por execução; preferir runner isolado local corrigido.
- Bootstrap deve registrar caminho e teste abortar se módulo/versão esperado não carregou. Um global vindo da instalação antiga não pode satisfazer o teste.
- PASS único da suite no fim, FAIL/exceção => exit inválido. Não aceitar apenas presença de qualquer PASS anterior. Testes que usam resetMaxFile apenas em batch/cena descartável explicitamente autorizada.
- Não assumir que teste antigo de 43/43 cobre clique real. Não mudar expectativa só para ficar verde: registrar razão contratual.
- MAXScript: evitar palavras reservadas; parentetizar if em concatenação; funções locais não podem capturar arbitrariamente variáveis externas; callbacks .NET globais e cleanup. Não escrever pseudocódigo como se fosse API nativa validada.
- Não recalcular toda a malha da cena em cada movimento. Registrar desempenho e crescimento de nós/callbacks em repetição. Se otimizar, preservar revalidação no clique.
- Preservar snap/grid/seleção/layer do usuário quando modificados temporariamente. Não alterar preferências globais para esconder defeito.

## 7. Tabela mínima de aceitação

| Caso | Resultado obrigatório |
|---|---|
| Modo Alinhado nesta entrega | Mensagem antes de captura; nenhuma cota/draft |
| Dois vértices H + vazio com grid snap | Uma cota; comando encerra no clique |
| Quatro vértices H/V desalinhados | Três intervalos em baseline única |
| Cursor sobre preview com geometria atrás | Preview ignorado; candidato real avaliado |
| Piso sem vértice no cursor | Orientação; não confirmar silenciosamente |
| Query de geometria lança exceção | ambiguous/error; não criar |
| Mesmo vértice ou estação | Rejeitar novo; preservar draft/preview |
| VertexId=0 | Rejeitar, nunca persistir como válido |
| Esc/direito com 3 referências | Nenhuma cota criada |
| Sucesso e depois Esc | Cotagem confirmada preservada |
| Falha no TextPlus após criar linha | Sem linha/controlador residual; retry possível |
| Undo/Redo depois de falha | Tentativa fracassada não reaparece |
| Repetir ativar/cancelar 20 vezes | Sem callbacks/nós crescendo |
| Dois eventos do primeiro gesto | Uma referência por gesto conforme spike |
| Clique rápido em referências diferentes | Ambas aceitas sem heurística temporal |
| Fonte elevada/rotacionada | Originais 3D e vertexIds preservados |

## 8. Handoff a cada entrega

Atualizar PLAN e checklist abaixo antes de encerrar. Relatar: causa comprovada; arquivos alterados; teste e caminho do log; comportamento instalado vs worktree; commit/push; pendência manual. Não instalar conjunto de estágios não testados para economizar viagens.

- [x] Auditoria estática e plano detalhado produzidos.
- [ ] R0 diagnóstico real identificado. Branch/worktree isoladas e build diagnóstico opt-in preparados; teste Batch e reprodução real ainda pendentes enquanto o 3ds Max está aberto. Instruções: `docs/e12-r0-diagnostics.md`.
- [ ] R1 lifecycle e modos.
- [ ] R2 picking/eventos/offset, gate real.
- [ ] R3 draft e preview/hover.
- [ ] R4 transação robusta.
- [ ] R5 definição e tratamento da referência de cota.
- [ ] R6 regressões, pacote e aceitação interativa.

## 9. Referências técnicas

As páginas documentam APIs/gestos, não código interno dos produtos:
- MouseTool eventos e #stop: https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/Scripted-Mouse-Tools/GUID-619AF4D3-A347-4155-943B-707D421BC460.html
- mouseTrack e limitações de plano: https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Interacting-with-the-3ds-Max/MouseTrack/GUID-0A4CD125-5CA0-42DA-B2D6-B8FDF511CCE8.html
- Revit multirreferência: https://help.autodesk.com/cloudhelp/2026/ENU/Revit-DocumentPresent/files/GUID-E0FB313E-CE57-4741-9EF5-6747BBA3BDDB.htm
- SketchUp inferências e cota início/fim/posição: https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model
