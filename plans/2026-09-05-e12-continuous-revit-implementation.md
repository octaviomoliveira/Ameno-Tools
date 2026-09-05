# E12 — Cotagem contínua: plano executável de recuperação

Data: 2026-09-05. Estado: **planejamento concluído; implementação e gates pendentes**.
Base inspecionada: `db88f1b`, branch `feature/e12-continuous-dimension`.
Worktree: `D:\Ameno\_worktrees\e12-continuous`.
Remoto: https://github.com/octaviomoliveira/Ameno-Tools

## 1. Objetivo e limites

Reaproveitar o núcleo funcional do Ameno e substituir a orquestração da E12 para criar uma sequência de cotas com linha comum. Não reescrever o plugin, alterar o editor E11, trocar materiais ou implementar cotagem automática de paredes.

Referência de interação: [Autodesk — Add an Aligned Dimension](https://help.autodesk.com/cloudhelp/2026/ENU/Revit-DocumentPresent/files/GUID-E0FB313E-CE57-4741-9EF5-6747BBA3BDDB.htm). O Revit seleciona múltiplas referências e posiciona a dimensão ao afastar o cursor e clicar. As decisões abaixo são a adaptação proposta para vértices no Max, não uma promessa de reproduzir toda a semântica BIM do Revit.

Escopo inicial: planta XY, referências de vértices suportadas pelo serviço atual, modos horizontal/vertical e depois alinhado oblíquo. Uma sequência tem uma única direção; contornar uma sala virando a direção requer outra sequência. Não oferecer silenciosamente distância de polilinha no lugar de distância projetada.

## 2. Diagnóstico verificado

Arquivo principal: `Contents/scripts/ameno/core/ameno_dimension_continuous_tool.ms`.

- `handlePoint` confunde ausência de snap com espaço vazio e exige uma fase `#offset` seguida de outro clique.
- Detecção de duplo clique por intervalo de tempo pode consumir cliques rápidos em referências diferentes.
- Coleta não apresenta todos os segmentos confirmados em preview; preview ativo usa cursor livre como extremidade.
- `refreshAllPreviewsWithOffset` e commit usam cálculos diferentes.
- Commit usa perpendicular por segmento e captura erros individualmente, permitindo criação parcial.
- `layoutForMode` deriva o eixo alinhado de cada par; uma perpendicular global não corrige isso por si só.
- Os 43 testes existentes manipulam principalmente listas e estados. Não são evidência de alinhamento geométrico, picking, commit ou persistência da cadeia. Não foram executados novamente para produzir este plano.

O patch `segMid + gPerp * offsetDist` é insuficiente: em horizontal, segmentos cujos pontos médios têm Y diferentes continuam em Y diferentes após a mesma translação. Não aplicar esses dois patches como solução final.

## 3. Contrato de interação obrigatório

1. Ativar Cota contínua: estado `#collecting`, zero referências.
2. Clique no primeiro vértice: marcador de referência, sem segmento permanente.
3. Clique no segundo: preview do primeiro intervalo.
4. Cada vértice adicional: preview da sequência inteira, sempre sobre uma linha comum.
5. Movimento do cursor: posiciona a linha comum. Hover em referência destaca candidato, sem adicionar referência antes do clique.
6. **Primeiro clique vazio com pelo menos duas referências válidas:** posiciona e confirma tudo nesse clique, sem etapa extra de afastamento.
7. Após sucesso, limpar apenas o draft e continuar aguardando a primeira referência da próxima sequência.
8. Clique vazio com menos de duas referências: não criar nem encerrar silenciosamente; mostrar orientação.
9. Backspace ou botão Remover último: desfaz a última referência escolhida. Esc/botão Cancelar cancela draft e sai. Botão direito também cancela, nunca confirma implicitamente.
10. Não depender de duplo clique ou timers para interpretar intenção. Verificar em spike como MouseTool entrega Esc/right-click e teclas; não prometer eventos inexistentes. Manter botão Remover último como alternativa ao atalho até comprová-lo.

Classificação explícita de cada clique, nesta ordem:

- `#reference`: nó elegível e vértice resolvido; guardar referência real e ponto mundial.
- `#geometryWithoutReference`: geometria sob cursor, mas sem vértice válido; orientar, não finalizar.
- `#empty`: nenhum alvo elegível sob cursor; confirmar se o draft for válido.
- `#ambiguous`/falha de picking: não confirmar; mostrar diagnóstico curto.

Ausência de `snapMode.hit` NÃO prova `#empty`. Snap de grid, helper ou do próprio Ameno NÃO constitui referência. Excluir previews e nós Ameno do picking para permitir posicionar sobre o próprio preview. Definir e testar geometria oculta/congelada e wireframe: ignorar objetos ocultos/congelados como alvos; respeitar as superfícies de geometria elegível mesmo em wireframe. Clique sobre piso sem vértice não finaliza por este contrato; não flexibilizar silenciosamente. Se isso bloquear o uso real, pedir decisão de UX antes de mudar a regra.

Usar tolerância visual em pixels para selecionar candidatos; não procurar o vértice mais próximo de toda a cena sem limite. Preservar a resolução E10.7 da malha avaliada e capturar ponto 3D antes de projetar em XY. Não substituir por leitura ingênua de `baseObject`, nem aplicar transform duas vezes.

## 4. Matemática única, independente do mouse

Criar um calculador puro de cadeia (nome sugerido: `ameno_dimension_chain_math.ms`) que retorne layout pronto para TODOS os segmentos, sem criar nós/callbacks/Undo.

Dados: origem fixa O, eixo unitário u, perpendicular unitária v no XY, cota de plano Z, coordenada de afastamento h e referências P[i].

    s[i] = dot(P[i] - O, u)
    h = dot(cursor - O, v)
    Q[i] = O + u*s[i] + v*h
    medida[i] = abs(s[i+1] - s[i])

Horizontal: u=X, v=Y, todos Q.y=cursor.y.
Vertical: u=Y, v=X, todos Q.x=cursor.x (a convenção de sinal deve ser consistente, não exigir cross para este caso).
Alinhado: u=normalize(P2-P1) projetado em XY, v=cross(Z,u); fixar eixo após segundo ponto válido, sem recalculá-lo a cada novo ponto. Se voltar a menos de dois pontos, liberar eixo para nova escolha.

P são âncoras originais; Q são extremidades projetadas da linha de cotagem. Extensões partem de P em direção a Q, respeitando gap/overshoot do estilo. NÃO persistir Q como se fossem vértices de origem.

Ordenação: ordenar referências por s para intervalos espaciais consecutivos; guardar também ordem de clique para Remover último. Rejeitar repetição da mesma referência e estações coincidentes dentro da tolerância, com aviso. Não criar segmento zero. Converter medidas usando as unidades da cena existentes, nunca assumir que uma unidade corresponde a um metro.

A base da cadeia permanece fixa no mundo quando uma âncora muda. Não girar/recentralizar automaticamente a linha após mover vértices. Se referências cruzarem sua ordem depois de confirmadas, sinalizar conflito e congelar o último layout válido; não redistribuir overrides silenciosamente. Reordenação pós-criação fica fora desta E12.

## 5. Arquitetura e persistência proposta

Reutilizar graphics, TextPlus, estilos, layers, unidade/override, resolução de âncoras e render. Ler antes de modificar:

- `ameno_dimensions_math.ms`: `layoutForMode`.
- `ameno_dimension_graphics.ms`: create/update preview, `createDimension`, `rebuildDimension`.
- `ameno_dimension_ca.ms`: record, CA v5, leitura/gravação e `resolvePoints`.
- `ameno_anchor_service.ms`: `updateDimensionFast`, fila, reconstrução de índice e pré-render.
- Bootstrap, ciclo de vida, testes de persistência e editor E11 para identificar consumidores indiretos.

Introduzir uma entrada de layout compartilhada para cadeia, usada em preview, commit, atualização rápida e reconstrução. Preservar o caminho antigo quando não houver cadeia. Não passar pontos projetados para `createDimension` e perder âncoras; permitir fornecer layout calculado, ou extrair um adaptador gráfico comum. Validar em teste que valor medido também vem da projeção.

Modelo sugerido, a comprovar na subetapa A:

- Um helper técnico por sequência em `AMENO_SYSTEM`, não renderizável, com CA próprio versionado: chainId, O/u/v/h, plano, modo, referências ordenadas, ordem de clique e membros.
- Referências com identidade estável, nó, vertexId/localPoint, último ponto válido. Os índices de vértice seguem as limitações atuais de topologia; não prometer identidade após remesh.
- Filhos mantêm controladores de cota e valores/estilos próprios, com vínculo `chainId`/referências de extremidade. Se ampliar CA v5, definir v6 mantendo identidade do CA e defaults de cadeia vazia; validar leitura de cenas antigas. Não mexer nos defaults de âncoras existentes.
- Registro da cadeia é fonte de verdade da base; não duplicar parâmetros divergentes nos filhos. Ausência de registro: preservar último gráfico e sinalizar, não aplicar layout legado silenciosamente.
- Agrupar dirty por cadeia: resolver referências uma vez e atualizar todos os membros. Evitar watcher duplicado e reentrada; listeners não devem gerar Undo extra.
- Limpeza, Undo/Redo, reset/open, exclusão e shutdown devem incluir helpers e índice. Exclusão de um filho remove esse membro, sem recriá-lo sozinho; remover helper quando não restarem membros. Duplicação/clonagem deve gerar IDs próprios ou ser explicitamente bloqueada com aviso nesta etapa.
- Bake/desancorar resolve pontos atuais mas preserva base e membros. Órfãos preservam último resultado e alerta da política atual. Override manual permanece ligado ao mesmo par de referências.

Não integrar persistência por tentativa em muitas frentes: primeiro documentar esquema e contratos no gate A; implementá-los no gate E. Até E, funcionalidades novas são experimentais, não prontas para entrega.

## 6. Subetapas e gates (um commit pequeno por entrega)

### E12-A — Estado, picking e contrato

- Criar DTO de hit/draft e classificador testável; retirar heurística temporal e separar picking da ação.
- Usar estados explícitos `#collecting`, `#committing`, `#idle`; não manter `#offset` como clique obrigatório.
- Definir/adicionar testes de input para vazio, grid, Ameno, geometria sem vértice, repetidos, 2 cliques rápidos, cancelamento.
- Fazer spike mínimo de eventos nativos e listar alterações de schema/consumidores para E.
- Gate: testes exercitam handlers reais ou classificador injetável, não inserção direta nas arrays. Registrar resultado do spike; pedir validação interativa curta se necessária. Não avançar com picking ambíguo tratado como vazio.

### E12-B — Layout puro H/V

- Implementar calculador sem nós e testes numéricos de projeção/ordenação/tolerância.
- Caso horizontal obrigatório P=(0,0),(4,1),(8,0),(12,2), cursor=(6,3): todas Q.y=3; três medidas 4 unidades de cena.
- Caso vertical: transpor X/Y do anterior, cursor.x=3; todas Q.x=3.
- Testar afastamento negativo, ordem invertida, estação duplicada, referência duplicada e unidades diferentes.
- Gate: zero comprimentos inesperados, dot(Q-O,v)=h para todos Q dentro de tolerância documentada; nenhum objeto criado pelo teste de matemática.

### E12-C — Preview e commit H/V

- Renderizar somente referências selecionadas; usar mesmo resultado de layout para preview e commit.
- Um clique vazio confirma N-1 segmentos válidos. Congelar input enquanto confirma.
- Criar conjunto em uma transação Undo; rastrear nós criados inclusive controlador/filhos/helper. Em exceção, limpar SOMENTE objetos dessa transação, restaurar draft/preview e permitir tentar novamente. Nunca executar Undo global arbitrário para rollback nem limpar layer inteira.
- Não descartar preview antes de ter resultado final válido. Remover previews sem histórico de Undo e sem sujeira na cena persistida.
- Gate: falha injetada no segundo segmento não deixa nenhum segmento permanente; uma ação Undo remove conjunto inteiro, Redo restaura. Testar nova sequência imediatamente após a primeira. Validar H/V no Max com usuário antes de promover como concluído.

### E12-D — Alinhado oblíquo

- Usar base fixa; não reutilizar `layoutForMode #aligned` por par para reconstruir eixo.
- Teste O=(0,0), P1=(0,0), P2=(3,4), P3=(10,5), u=(0.6,0.8), v=(-0.8,0.6), h=2: estações 0,5,10 e medidas 5,5. P3 não está na linha P1-P2.
- Gate: preview/commit idênticos, extensões corretas, textos legíveis nos dois lados; nenhum salto de eixo ao adicionar P3.

### E12-E — Persistência e integração

- Implementar registro/versionamento aprovados em A, leitura/escrita, IDs, caminho de layout único e atualização por cadeia.
- Testar salvar/abrir, Undo/Redo, mover vértice Edit Poly/Editable Poly/Editable Mesh suportados, transformar nó, apagar âncora, apagar membro, bake, override manual e reconstrução de estilo.
- Confirmar que dados 3D e transform estão corretos; projeção só afeta plano de cotagem.
- Gate: posição da linha comum não muda após eventos; cotas individuais antigas seguem intactas; erro de referência não derruba serviço nem some com a sequência.

### E12-F — Regressão, pacote e gate final

- Executar suítes existentes relevantes E4/E5/E6/E7/E8/E10/E11 disponíveis e E12. Registrar arquivos/contagens reais, falhas, skips e limitações. Não exigir todos os testes antigos de comportamento obsoleto passarem sem atualizar contrato, nem reduzir cobertura para obter PASS.
- Validar pacote e bootstrap. Testar overlay Corona e V-Ray CPU sem alterar Beauty/LightMix; indisponibilidade de renderer é gate pendente, não aprovação.
- Usuário valida uma planta real H/V e oblíqua, cancelamento, cliques rápidos, edição posterior de vértices e reabertura.
- Só após aprovação, preparar merge para main com verificação de mudanças concorrentes. Este plano não autoriza merge automático antes do gate.

## 7. Testes e evidência confiável

Manter `tests/maxscript/test_e12_continuous.ms` como suíte de integração; criar arquivos menores sugeridos `test_e12_chain_math.ms`, `test_e12_chain_input.ms`, `test_e12_chain_persistence.ms`.

Todo teste deve carregar explicitamente o bootstrap da worktree E12, registrar caminho de origem e ter marcador único de início/fim. Exceções ou assertions devem provocar falha real; PASS de outro teste ou logs antigos não servem. Assertar os pontos e comprimentos da geometria criada, não apenas arrays do draft. Comparar geometria em coordenadas mundiais, preservando unidades da cena.

Antes de batch: ler o runner atual e confirmar isolamento, parâmetros, processos Max existentes e local dos logs. Não rodar simultaneamente ao batch de outro agente nem matar processos dele. Nunca iniciar testes destrutivos na cena aberta do usuário. Usar cena descartável e logs separados por suíte/run. Startup pode demorar minutos; não declarar travamento por ausência inicial de output.

O runner desta branch inspecionado em db88f1b aceita `-TestScript`, usa `.test-output/listener.log` compartilhado e config batch-isolated.ini; portanto é necessário auditar isolamento antes de executar. O runner de `D:\Ameno\_tools` pode ter evoluído: não presumir que carrega E12 só porque recebeu um caminho de teste.

## 8. Instalação segura (somente depois de testes e com Max fechado)

Não executar `D:\Ameno\_tools\tools\install-dev.ps1` para instalar esta branch. O script inspecionado resolve raiz a partir de PSScriptRoot; a origem depende da cópia executada, não de um caminho universal fixo. O handoff anterior simplificou esse detalhe.

Origem obrigatória: `D:\Ameno\_worktrees\e12-continuous\PackageContents.xml` e `Contents` dessa mesma worktree. Destino esperado: `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools` (resolver APPDATA real e conferir caminho absoluto).

Validar pacote desta worktree, fechar Max com autorização do usuário, fazer backup recuperável apenas do pacote AmenoTools, copiar versão completa sem resíduos e comparar lista de arquivos e SHA-256 com origem. Não executar o Remove-Item recursivo do handoff sem validar alvo; preferir backup a exclusão. Registrar commit instalado e caminho. Não instalar nem abrir Max durante o planejamento.

## 9. Disciplina para o agente executor

1. Ler `PLAN.md`, este plano e `docs/decisions/0020-e12-shared-dimension-chain.md`.
2. Conferir `git status`, branch, worktree e HEAD. Se diferente de db88f1b mais commits documentais, revisar diff antes de editar. Não resetar mudanças alheias nem trocar branch de outro agente.
3. Começar apenas pela E12-A. Antes de tocar em código compartilhado E10/E11, conferir mudanças concorrentes e coordenar responsabilidade. Branches na mesma pasta não isolam agentes: usar worktree própria se outro agente ainda editar esta.
4. Ler completamente funções afetadas e seus chamadores. Nomes de novos módulos neste plano são sugestões, não APIs já existentes.
5. Evitar palavras reservadas MAXScript (`off`, `on`, `true`, `false`) como variáveis. Parentetizar if usado em concatenação. Callbacks .NET devem usar funções globais compatíveis e cleanup explícito. Confirmar APIs em documentação Autodesk quando houver dúvida; não inventar assinaturas.
6. Ao concluir cada subetapa, atualizar checklist abaixo e PLAN.md com evidência, commit e gate pendente. Commitar apenas arquivos próprios. Publicar na branch E12, nunca forçar push.
7. Não considerar Batch equivalente a validação de mouse. Se precisar de gate manual, parar e entregar passos curtos ao usuário; não continuar implementando todas as etapas no escuro.

## 10. Checklist de continuidade

- [x] Planejamento e diagnóstico estático documentados.
- [x] E12-A: interação/classificador aprovados em Batch (21/21 novos + 43/43 legados); gate manual fica para E12-C, pois layout/commit ainda não existem.
- [x] E12-B: matemática H/V aprovada em Batch (29/29), pura e sem criar nós.
- [ ] E12-C: preview/commit H/V e gate manual aprovados.
- [ ] E12-D: alinhado oblíquo aprovado.
- [ ] E12-E: persistência e integração aprovadas.
- [ ] E12-F: regressões, pacote, instalação e gate final aprovados.
- [ ] Merge para main autorizado e concluído.

## Prompt de partida

Você vai executar a recuperação da E12 do Ameno Tools. Leia PLAN.md, plans/2026-09-05-e12-continuous-revit-implementation.md e docs/decisions/0020-e12-shared-dimension-chain.md na branch feature/e12-continuous-dimension. Trabalhe a partir de D:\Ameno\_worktrees\e12-continuous, verificando primeiro status e concorrência. Implemente SOMENTE E12-A inicialmente, com seus testes e evidências. Reaproveite o núcleo existente; não aplique apenas os patches de perpendicular do handoff antigo. O fluxo final é selecionar vértices com preview de cadeia comum e confirmar toda a sequência no primeiro clique vazio. Não instale, não faça merge e não altere E11 nesta primeira entrega. Atualize os Markdown e publique um commit escopado na branch E12. Ao terminar, informe resultados reais, limitações e o gate necessário para avançar.
