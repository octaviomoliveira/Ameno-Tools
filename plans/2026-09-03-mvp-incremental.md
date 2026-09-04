# Plano incremental de funcionamento — Ameno Dimensions

**Data:** 2026-09-03  
**Alvo:** 3ds Max 2026 + Corona  
**Estado atual:** E1 a E9 aprovadas interativamente no 3ds Max 2026; E10 em desenvolvimento; E11 planejada para o novo Editor Visual e Preview ao Vivo.

## Estratégia de execução

O plugin será construído em fatias verticais pequenas. Cada etapa precisa:

1. terminar com algo observável no 3ds Max;
2. ter critérios objetivos de aceite;
3. passar pelos testes automatizados aplicáveis;
4. ser instalada pela cópia de desenvolvimento;
5. receber validação manual no Max antes da etapa seguinte;
6. atualizar `PLAN.md` com resultado, pendências e commit.

Estados possíveis: `não iniciada`, `em desenvolvimento`, `pronta para teste no Max`, `aprovada` e `bloqueada`.

Não misturar duas etapas quando a primeira ainda não passou pelo seu gate. Correções internas descobertas no gate pertencem à mesma etapa.

## Visão geral

| Etapa | Entrega visível | Estado |
| --- | --- | --- |
| E0 | Pacote abre, mostra versão e reconhece o Corona | Aprovada |
| E1 | `Preparar esta cena` cria a infraestrutura Ameno com segurança | Aprovada |
| E2 | Núcleo calcula e formata uma cota linear sem criar objetos | Aprovada em Batch |
| E3 | Uma cota gráfica de teste é construída na cena | Aprovada no viewport, Arnold/V-Ray com luz e limpeza |
| E4 | Cota alinhada é criada com três cliques e preview | Aprovada no Max |
| E5 | Cotas sobrevivem a salvar/reabrir, Undo e alterações de cena | Aprovada no Max |
| E6 | Valor medido, arredondado e manual podem ser revisados | Aprovada no Max |
| E7 | Estilo edita fonte, texto, linhas e terminais | Aprovada no Max |
| E8 | Âncoras atualizam cotas e diagnóstico encontra problemas | Aprovada no Max |
| E8.1 | Estabilização das âncoras, estilos e interface | Aprovada no Max |
| E9 | Corona renderiza somente as cotas em arquivo transparente | Aprovada interativamente |
| E10 | Fluxo de produção, V-Ray CPU e estabilização do MVP | Em desenvolvimento |
| E11 | Editor Visual e Preview ao Vivo | Planejada após a E10 |


---

## E0 — Fundação e diagnóstico

### Entrega

- pacote `ApplicationPlugins` carregado;
- ação `Ameno Tools` abre o painel;
- versão do Max exibida;
- renderer ativo detectado por adapter.

### Gate aprovado

- painel aberto no 3ds Max 2026;
- interface mostra `Ameno Tools 0.0.1 · Max 2026`;
- Corona aparece como `suportado`;
- validação do pacote e smoke test passaram.

---

## E1 — Preparar esta cena

**Estado:** aprovada.
**Implementação:** `Contents/scripts/ameno/core/ameno_scene_setup.ms`.
**Evidência automatizada:** 3ds Max 2026.3 Batch aprovou criação, repetição sem duplicatas, restauração da layer corrente e conflito de nome `AMENO_COTAS`; a cópia instalada via `ApplicationPlugins` também carregou a E1.
**Commit publicado em `origin/main`:** `92bddd1` (`feat: prepare Ameno scene infrastructure`).
**Verificação visual em 2026-09-03:** a captura recebida mostrou a UI da sessão antiga. A cópia instalada foi comparada por SHA-256 com o checkout e contém `Preparar esta cena` e a E2; é necessário reiniciar completamente o 3ds Max antes de repetir o gate.
**Gate visual aprovado em 2026-09-03:** depois da reinicialização, o painel mostrou `Cena preparada` e as layers `AMENO_COTAS`/`AMENO_SYSTEM`; o Layer Explorer confirmou o registro de documento e o estilo padrão em `AMENO_SYSTEM`.

### Objetivo

Criar uma base segura e repetível antes de existir qualquer cota.

### Implementação

- serviço central de layers;
- criação/reutilização de `AMENO_COTAS` e `AMENO_SYSTEM`;
- identidade própria para não apropriar uma layer homônima do usuário;
- nó/registro de cena versionado na layer de sistema;
- estilo padrão mínimo registrado;
- botão `Preparar esta cena` no painel;
- estado visual: `não preparada`, `pronta` ou `requer reparo`;
- função de reparo limitada à infraestrutura Ameno.

### Regras de segurança

- não mudar renderer, unidades, câmera ou Render Setup;
- não mover objetos do usuário;
- preservar e restaurar a layer corrente;
- executar duas vezes sem duplicar layers, registros ou callbacks;
- conflito de nome deve produzir diagnóstico, não apropriação silenciosa;
- uma única entrada de Undo quando houver alteração de cena.

### Gate no Max

1. abrir uma cena vazia e preparar;
2. repetir o comando e confirmar que nada foi duplicado;
3. preparar uma cópia de uma cena real;
4. confirmar que renderer, unidades, layer corrente e objetos permaneceram iguais;
5. salvar, reabrir e confirmar estado `pronta`.

### Registro para fechar a E1

Depois do gate visual aprovado, atualizar este arquivo e `PLAN.md` para `Aprovada`, anexar a data/versão do Max e registrar o commit/push correspondente. Só então a E2 pode ser iniciada.

### Fora desta etapa

Nenhuma linha, texto, mouse tool, callback associativo ou render de cotas.

---

## E2 — Matemática, unidades e texto do valor

**Estado:** aprovada em testes automatizados no 3ds Max 2026.3.
**Implementação:** `Contents/scripts/ameno/core/ameno_dimensions_math.ms`.
**Evidência automatizada:** layout positivo/negativo/diagonal, pontos coincidentes, conversões de unidade, arredondamento por incremento e formatação de `19,555 m` para `19,60 m` passaram no Batch e no pacote instalado via `ApplicationPlugins`.
**Commits publicados em `origin/main`:** `70c0fb2` (`feat: add pure dimension measurement core`) e `78e54d7` (evidência de validação).

### Objetivo

Ter um núcleo determinístico que transforme três pontos em dados de cota, sem depender da UI ou da cena.

### Implementação

- definição dos pontos A, B e ponto de afastamento;
- direção, perpendicular, lado e distância assinada;
- comprimento real normalizado em milímetros;
- primeira modalidade: cota alinhada no plano XY;
- formatação em mm, cm e m;
- precisão, zeros finais e separador decimal;
- arredondamento por incremento, separado do valor manual;
- tratamento de pontos coincidentes e tolerância numérica.

### Gate

- testes repetíveis em quatro quadrantes e nos dois lados da parede;
- `19,555 m` com incremento de `0,10 m` gera `19,60 m`;
- trocar unidades de exibição não altera a medida armazenada;
- nenhum nó é criado na cena.

### Observação de ordem

A E2 foi executada antes da validação visual da E1 por autorização explícita. Isso não amplia a cena nem depende das layers, pois o módulo é puro. A E3 continua aguardando a aprovação visual da E1.

---

## E3 — Primeiro construtor gráfico

**Estado:** aprovada no viewport, em render comum nas condições informadas e na limpeza em 2026-09-03, após aprovação visual da E1.
**Implementação:** `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`, integrada em `ameno_bootstrap.ms`, `ameno_runtime.ms` e `ameno_main_panel.ms`.
**Instalação:** cópia de desenvolvimento atualizada em `ApplicationPlugins`; o hash SHA-256 do módulo instalado corresponde ao fonte.
**Evidência automatizada:** `tests/maxscript/test_bootstrap.ms` passou no 3ds Max 2026.3 e testou criar, reconstruir e remover a cota sem resíduos; `test_installed_package.ms` também aprovou E1, E2 e E3 dentro de `ApplicationPlugins`. Ambos usam `tests/maxscript/batch-isolated.ini`, perfil que evita bloquear a sessão interativa.
**Correção de bootstrap:** a primeira cópia da E3 falhou porque MAXScript só permite `throw` sem argumento dentro de `catch`. A ocorrência foi reproduzida em Batch isolado, corrigida e validada. O bootstrap e o macro agora preservam e mostram o diagnóstico detalhado se outro módulo falhar.
**Gate visual:** a captura fornecida pelo usuário mostrou uma cota ativa, linhas de extensão/terminais e TextPlus `5,00 m` no viewport, com `AMENO_COTAS` selecionada e o painel indicando `1 ativa(s)`. O usuário confirmou render Arnold, render V-Ray com luz na cena e limpeza pelo painel. O Beauty do Corona em uma cena sem luz não é usado como bloqueio desta etapa; ele será resolvido no overlay isolado da E9.

### Objetivo

Comprovar que spline, terminais e TextPlus formam uma cota renderizável e reconstruível.

### Implementação

- comando temporário `Criar cota de teste` com pontos conhecidos;
- controlador lógico e filhos gráficos nomeados por ID;
- linha de cota, linhas de extensão e terminais em spline;
- TextPlus com o valor calculado;
- material gráfico inicial compatível com Corona;
- inserção de todos os nós visuais em `AMENO_COTAS`;
- reconstrução e remoção sem resíduos.

### Gate no Max

- criar, selecionar, reconstruir e apagar uma cota de teste;
- texto legível pela câmera superior e sem inversão;
- geometria aparece no viewport e em um render comum de teste sob a iluminação disponível;
- nenhum helper de sistema aparece no render.

### Fora desta etapa

Ainda não haverá interação de três cliques nem associatividade.

---

## E4 — Ferramenta de três cliques

**Estado:** aprovada no 3ds Max 2026.3 em 2026-09-04 após correção pós-validação.
**Implementação:** `Contents/scripts/ameno/core/ameno_dimension_tool.ms`, integrado ao `ameno_bootstrap.ms`, `ameno_runtime.ms`, `ameno_main_panel.ms` e ao construtor gráfico da E3.
**Evidência automatizada:** `test_bootstrap.ms` passou no Batch isolado, verificando carregamento do `MouseTool`, criação/atualização/remoção da prévia, fluxo A/B/afastamento e cancelamento sem resíduos. `test_installed_package.ms` aprovou a cópia `ApplicationPlugins` com a E4 carregada.
**Instalação:** `tools/install-dev.ps1` atualizou `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`; a cópia instalada foi conferida por SHA-256 e carregada após reiniciar o Max.

**Correção após o primeiro teste:** o limite automático `numPoints:3` foi removido. Se a atualização ou o commit falhar no terceiro clique, o Max não encerra silenciosamente o comando: a prévia permanece, a ferramenta aceita outra tentativa no afastamento e, ao sair, o painel mostra o erro registrado.

**Gate manual aprovado em 2026-09-04:** o usuário confirmou o fluxo principal no Max. A captura mostra a cota permanente `4,05 m` no viewport, a ferramenta encerrada e o painel indicando `1 cota(s) ativa(s)`. A correção do desaparecimento no terceiro clique está validada; a matriz complementar de orientações e Undo permanece como regressão recomendada durante a E5.

### Como usar

1. Abra `Ameno Tools` e prepare a cena se o painel indicar infraestrutura pendente.
2. Clique em **Criar cota**.
3. No viewport, clique no ponto A, clique no ponto B e clique no terceiro ponto para definir o afastamento da linha.
4. Mova o mouse entre o segundo e o terceiro clique para ver a prévia; o texto é recalculado conforme a distância.
5. Use Esc ou o botão direito para cancelar. A prévia é temporária e não fica na cena.
6. O Snap não é ligado pelo plugin; quando estiver ligado no Max, o `MouseTool` usa o limite 3D do Snap atual.

### Implementação e segurança

- a prévia cria apenas dois nós em `AMENO_COTAS`, marcados `Ameno.Kind=dimensionPreview` e `Ameno.Preview=1`;
- o controlador e os filhos permanentes só nascem no terceiro clique;
- o commit reutiliza `AmenoDimensionGraphics.createDimension` e mantém a entrada de Undo `Ameno: criar cota`;
- cancelamento, erro e shutdown removem a prévia com `undo off`;
- pontos são projetados para o plano XY, mesma regra da E2/E3 atual;
- a ferramenta não altera renderer, luzes, LightMix, Render Elements ou o estado do Snap.

### Gate no Max

- criar uma cota horizontal, vertical e diagonal;
- testar os dois lados da linha e A/B invertidos;
- cancelar após o primeiro e após o segundo clique e confirmar que não sobram nós;
- usar Ctrl+Z após o terceiro clique e confirmar que a cota inteira desaparece em uma entrada;
- repetir `Criar cota` sem duplicar preview ou controlador;
- se houver falha no commit, confirmar que a prévia não desaparece e que o painel informa o erro.

O botão `Criar cota de teste` permanece disponível para regressão da E3.

### Objetivo

Entregar a primeira cota realmente utilizável.

### Fluxo

1. clique A: origem;
2. clique B: destino e medida;
3. clique C: lado e afastamento;
4. confirmação cria uma cota usando o construtor da E3.

### Implementação

- mouse tool para cota alinhada;
- preview leve, sem acumular objetos;
- orientação e valor atualizados durante o movimento;
- respeito ao Snap existente, sem ligá-lo automaticamente;
- Esc e botão direito cancelam em qualquer fase;
- criação inteira em um único bloco de Undo;
- aviso claro para ponto coincidente ou falha de criação.

### Gate no Max

- criar pelo menos dez cotas em uma planta simples;
- testar A/B invertidos e os dois lados da parede;
- cancelar em cada clique sem deixar nós ou Undo parcial;
- Undo remove a cota inteira e Redo a restaura.

---

## E5 — Persistência e ciclo de vida

**Estado:** aprovada no 3ds Max 2026.3 em 2026-09-04 após validação manual do usuário.
**Implementação:** `Contents/scripts/ameno/core/ameno_dimension_ca.ms`, integrado ao `ameno_bootstrap.ms`, `ameno_dimension_graphics.ms`, `ameno_runtime.ms`, `ameno_main_panel.ms` e documentado na ADR `0008-e5-custom-attributes-persistence.md`.
**Evidência automatizada:** `test_bootstrap.ms` aprovou no Batch isolado a criação de Custom Attributes versionados (`AmenoDimensionCA`), ciclo completo de salvar cena em `.max`, reset e reabertura com preservação exata dos dados geométricos e de formatação, renomeação livre de nós mantendo integridade e identidade, simulação de exclusão acidental de nós visuais e regeneração via `AmenoApp.repairDimensions()`, e Undo atômico em um único passo. `test_installed_package.ms` aprovou a presença e funcionamento de `AmenoDimensionCA` na instalação do `ApplicationPlugins`.
**Instalação:** `tools/install-dev.ps1` atualizou `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`; a cópia instalada foi conferida e testada via Batch isolado.
**Gate manual aprovado em 2026-09-04:** o usuário confirmou que a cota persistiu perfeitamente após o ciclo de salvar e reabrir a cena `.max`, a exclusão acidental de filhos gráficos foi recuperada via botão "Reparar cotas" sem duplicar controladores na layer de sistema, e o Undo atômico removeu a cota inteira em uma única ação. A E5 está encerrada.

### Objetivo

Transformar o desenho criado em uma entidade Ameno confiável que sobreviva a salvar/abrir, renomeação e exclusão acidental de elementos visuais.

### Implementação

- Custom Attributes versionados no controlador técnico (`AmenoDimensionCA`, version: 1, attribID:#(0x414d454e, 0x44494d31));
- Parâmetros nativos (`schemaVersion`, `dimensionId`, `dimensionRole`, `pointA`, `pointB`, `offsetPoint`, `outputUnit`, `precision`, `displayMode`, `roundingIncrementMm`, `manualValue`, `styleId`);
- Espelhamento em User Properties para compatibilidade retroativa com cenas das etapas E3/E4;
- Identificação por `dimensionId`, imune a renomeação de nós ou camadas;
- Inspeção e reparo não-destrutivo (`inspectDimension`, `repairDimension`, `repairAllDimensions` e botão `Reparar cotas` na interface);
- Callbacks de ciclo de vida idempotentes (`#filePostOpen`, `#postSceneReset`, `#systemPostNew`) com ID `#ameno_lifecycle` para sincronização ao abrir ou resetar cenas;
- Preservação da atomocidade do Undo (`Ameno: criar cota`, `Ameno: remover cota`, `Ameno: reparar cota`);
- Cenas salvas continuam abrindo normalmente sem o plugin instalado, sem avisos de "Missing DLLs".

### Gate no Max

1. Abrir o 3ds Max 2026 e preparar a cena.
2. Criar uma cota com três cliques usando **Criar cota**.
3. Salvar a cena em um arquivo `.max`, fechar o Max ou resetar a cena.
4. Reabrir a cena salva e abrir o painel Ameno Tools:
   - Confirmar que o painel reconhece a cota ativa (`1 cota(s) ativa(s)`).
   - Confirmar que as linhas e o texto permanecem íntegros no viewport.
5. No Layer Explorer, selecionar e deletar o nó do texto ou da linha (filho gráfico em `AMENO_COTAS`).
6. No painel Ameno Tools, clicar em **Reparar cotas**:
   - Confirmar que o elemento visual é restaurado imediatamente sem duplicar o controlador da layer `AMENO_SYSTEM`.
7. Criar uma nova cota e pressionar `Ctrl+Z`:
   - Confirmar que a cota inteira é desfeita em um único passo de Undo.

---

## E6 — Valores medidos, arredondados e manuais

**Estado:** aprovada no 3ds Max 2026.3 em 2026-09-04 após validação manual do usuário.
**Implementação:** `Contents/scripts/ameno/core/ameno_dimension_ca.ms` (schema v2), `Contents/scripts/ameno/core/ameno_dimension_graphics.ms` (cálculo de audit, marcador viewport-only `[M]`, alteração e restauração de modos), `Contents/scripts/ameno/core/ameno_runtime.ms` (seleção e delegação), `Contents/scripts/ameno/ui/ameno_main_panel.ms` (painel expandido com inspeção reativa via `#selectionSetChanged`), e documentado na ADR `docs/decisions/0009-e6-manual-overrides-viewport-marker.md`.
**Evidência automatizada:** `test_bootstrap.ms` aprovou no Batch isolado:
1. Estado inicial medido com delta 0 e sem marcador.
2. Override manual numérico (20,00m -> 19,60m) com delta -0,40m e motivo registrado.
3. Instanciação do marcador `[M]` no viewport com `renderable = false` e `wirecolor` âmbar `(color 245 166 35)`, além de wirecolor âmbar nas linhas e no rótulo.
4. Alteração da geometria física e recálculo automático do delta mantendo inalterado o valor manual exibido (regra de ouro).
5. Persistência completa do modo manual, motivo e nó marcador em arquivo `.max` com reabertura íntegra e `renderable = false` preservado.
6. Ação de restauração para valor medido (`resetDimensionToMeasured`), excluindo o marcador e retornando o wirecolor ao padrão.
7. Modo arredondado por incremento configurável.
8. Reversão atômica via Undo (`max undo`).
`test_installed_package.ms` aprovou a execução dos overrides no pacote instalado via `ApplicationPlugins`.
**Instalação:** `tools/install-dev.ps1` sincronizou a versão atualizada no `ApplicationPlugins\AmenoTools`.
**Gate manual aprovado em 2026-09-04:** o usuário validou no 3ds Max 2026 interativo a cota com override numérico manual (1,10 m com medido 1,09 m, delta +0,01 m), confirmando que o marcador [M] âmbar apareceu na viewport, o painel indicou [MODIFICADA / MANUAL] e no render (Arnold RenderView) o marcador [M] NÃO apareceu, mantendo render 100% limpo e sem advertência visual na saída final. A E6 está encerrada.

### Objetivo

Permitir que a cota represente levantamento e intenção de projeto sem esconder divergências. Regra de ouro: **"Valor medido ≠ valor exibido. A medida física real nunca é apagada."**

### Implementação

- Schema CA Version 2 no controlador técnico com campos `manualValueMm`, `manualText`, `manualReason`, `lastMeasuredMm`, `lastDeltaMm`;
- Quatro modos de valor: `#measured` (medido puro), `#rounded` (arredondado por passo em cm), `#manualNumeric` (numérico arbitrário em metros) e `#manualText` (texto livre);
- Marcador visual `[M]` TextPlus posicionado ao lado da cota, com `renderable = false` (não renderiza em Corona/V-Ray/Arnold) e `wirecolor = (color 245 166 35)`;
- Linha e texto da cota recebem `wirecolor` âmbar quando modificados, mantendo seus materiais originais para um render limpo;
- Painel reativo: ao selecionar qualquer nó da cota na cena, o painel exibe ID, Valor Medido, Valor Exibido, Delta (com aviso `[MODIFICADA / MANUAL]`), modo ativo, campos para edição e botão de restauração imediata;
- Undo atômico para todas as transições de modo e valores.

### Gate no Max

1. Abrir o 3ds Max 2026 com o Ameno Tools instalado.
2. Criar uma cota qualquer no viewport (ex: ~20 m).
3. Selecionar a cota no viewport e verificar no painel:
   - Medido e Exibido devem mostrar o mesmo valor.
   - Delta deve ser `0 m [EXATO]`.
   - Na cena, não existe marcador `[M]`, e o wirecolor é padrão (branco).
4. No painel, selecionar modo **Numérico Manual**, inserir um valor diferente (ex: diminuir 40 cm), preencher o motivo e clicar em **Aplicar Alteração**:
   - O texto da cota exibe o novo valor manual.
   - Um marcador `[M]` âmbar aparece ao lado do texto no viewport.
   - As linhas e o texto da cota ficam com cor de arame âmbar na viewport.
   - O painel exibe o Delta exato (ex: `-0,40 m [MODIFICADA / MANUAL]`).
5. Renderizar a cena (Corona, V-Ray ou Arnold):
   - Confirmar que o marcador `[M]` **NÃO aparece no render** e as linhas renderizam com material normal (sem cor âmbar).
6. Mover um dos pontos da cota na cena:
   - Confirmar que o valor exibido continua fixo no valor manual, e o Delta no painel é recalculado automaticamente.
7. Clicar em **Restaurar Medido**:
   - Confirmar que a cota volta ao valor físico real, o marcador `[M]` desaparece e a cor de arame volta ao padrão.
8. Pressionar `Ctrl+Z` e confirmar o Undo atômico.

---

## E7 — Editor visual de estilo

**Estado:** aprovada no 3ds Max 2026.3 em 2026-09-04 após validação manual do usuário.
**Implementação:** `Contents/scripts/ameno/core/ameno_style_service.ms`, `Contents/scripts/ameno/ui/ameno_style_editor.ms`, atualizações em `ameno_dimension_graphics.ms`, `ameno_dimension_tool.ms`, `ameno_runtime.ms`, `ameno_main_panel.ms`, e documentada na ADR `docs/decisions/0010-e7-style-system-and-visual-editor.md`.
**Evidência automatizada:** `test_bootstrap.ms` e `test_installed_package.ms` aprovaram no 3ds Max Batch isolado:
1. Inicialização do `AmenoStyleService` com os 3 presets de fábrica (*Arquitetônico*, *Editorial*, *Técnico*).
2. Construção correta dos 5 tipos de terminais vetoriais na mesma spline (`#tick`, `#arrowClosed`, `#arrowOpen`, `#dot`, `#none`), herdando `render_thickness`, espessura visível no viewport (`render_displayRenderMesh = true`) e material de cota.
3. Configuração de tipografia no TextPlus (`fontSize`, `tracking`, `fontName`, `bold`, `italic`, `textGap`) com fallback para Arial.
4. Atualização de estilo ao vivo e em lote (`updateStyleAndRebuild`), atualizando todas as cotas da cena que utilizam o estilo.
5. Preservação da seleção no 3ds Max ao reconstruir nós visuais da cota.
6. Undo atômico: reversão da atualização em lote de todas as cotas com um único `max undo`.
7. Persistência de biblioteca de estilos no arquivo `.max` via UserProps de `rootNode` (`Ameno.Styles`), com reabertura e integridade comprovadas.
**Instalação:** `tools/install-dev.ps1` sincronizou a versão atualizada no `ApplicationPlugins\AmenoTools`.
**Gate manual aprovado em 2026-09-04:** o usuário validou no 3ds Max 2026 interativo a reatividade completa do Editor de Estilos (ajuste de fontes, tamanhos, terminais e espessuras com atualização em tempo real no viewport, atalhos de espessura ativos, sincronização bidirecional com a cota selecionada e Undo atômico). A E7 está encerrada com aprovação total.

### Objetivo

Editar aparência com a clareza do TextPlus, sem expor controles irrelevantes à cotagem, oferecendo padrões estéticos refinados para plantas humanizadas com render vetorial idêntico em Corona, V-Ray e Arnold.

### Implementação

- Modelo `AmenoStyleRecord` e serviço `AmenoStyleService`;
- Presets: *Arquitetônico* (Arial 20 pt, Traço 45° 14 mm, espessura 1.5 mm), *Editorial* (Georgia 22 pt, Ponto 8 mm, espessura 1.0 mm), *Técnico* (Arial 16 pt, Seta Fechada 16 mm, espessura 1.2 mm);
- 5 tipos canônicos de terminais geométricos na mesma `SplineShape`: `#tick`, `#arrowClosed`, `#arrowOpen`, `#dot`, `#none`;
- Espessuras rápidas de linha com atalhos: `Fina (0.8)`, `Normal (1.5)`, `Forte (2.5)` e spinner de ajuste contínuo;
- Lista dinâmica de fontes instaladas no Windows via classe .NET `System.Drawing.FontFamily` e fallback gracioso;
- Atualização em lote com reconstrução automática de todas as cotas vinculadas;
- Reversibilidade total: Undo atômico no 3ds Max;
- Persistência na cena: estilos salvos com o `.max` via UserProps em `rootNode`, garantindo portabilidade sem arquivos externos;
- Editor visual dedicado `AmenoStyleEditorRollout` e integração no painel principal `AmenoMainPanelRollout`.

### Gate no Max

1. Abrir o 3ds Max 2026 com o Ameno Tools instalado.
2. Abrir o painel Ameno Tools e clicar no botão **Editor de Estilos...**:
   - Confirmar abertura do editor "Ameno Dimensions — Editor de Estilos".
   - Confirmar que o dropdown lista os presets *Arquitetônico*, *Editorial* e *Técnico*.
3. Alternar entre os estilos no editor e verificar a atualização dinâmica dos campos (fontes, tamanhos, terminais e espessuras).
4. Criar uma cota na cena e aplicar o estilo *Editorial*:
   - Confirmar que a cota assume terminais em ponto/losango e espessura fina (1.0).
5. Criar outra cota e aplicar o estilo *Técnico*:
   - Confirmar que a cota assume setas fechadas e espessura 1.2.
6. No Editor de Estilos, selecionar o estilo *Arquitetônico*, alterar a espessura para `Forte (2.5)` e clicar em **Atualizar Estilo (Em Lote)**:
   - Confirmar que as cotas usando o estilo Arquitetônico na cena aumentam de espessura imediatamente.
7. Pressionar `Ctrl+Z` (Undo) e verificar que todas as cotas retornam à espessura original em um único passo.
8. Renderizar a cena (Corona, V-Ray ou Arnold) e verificar que as setas e pontos renderizam perfeitamente como geometria fina, com o mesmo material autoluminoso da cota.

---

## E8 — Âncoras, atualização e diagnóstico

**Estado:** aprovada no 3ds Max 2026.3 em 2026-09-04.
**Implementação:** `Contents/scripts/ameno/core/ameno_anchor_service.ms`, `Contents/scripts/ameno/core/ameno_dimension_ca.ms` (Schema v3 com nós e coordenadas locais), atualizações em `ameno_dimension_graphics.ms`, `ameno_dimension_tool.ms`, `ameno_runtime.ms`, `ameno_main_panel.ms` e documentada na ADR `docs/decisions/0011-e8-anchors-dirty-queue-diagnostics.md`.
**Evidência automatizada:** `test_bootstrap.ms` e `test_installed_package.ms` aprovaram no 3ds Max Batch isolado:
1. Criação associativa ligada a nós (`nodeA`, `nodeB`) e cálculo de coordenadas no espaço local (`localPointA`, `localPointB`).
2. Movimentação e rotação de nós da cena com recálculo automático da linha de cota e medição milimétrica.
3. Botão e rotina `selectAnchors` para localizar e selecionar na cena os nós âncora da cota selecionada.
4. Resiliência a nós deletados: a exclusão de nós na cena não apaga nem quebra a cota; ela é convertida em órfã (`isOrphan = true`), mantém a última posição física mundial intacta e adquire indicação visual vermelha de alerta `(color 230 70 70)` no viewport e badge no painel.
5. Reancoragem interativa (`reanchorDimension` para ponto A ou B) via botão de captura no painel, restaurando o status da cota para ativo.
6. Reparo em lote de cotas órfãs (`repairOrphans`), convertendo-as para cotas estáticas no espaço mundial de forma limpa.
7. Persistência de nós de âncora e coordenadas locais no arquivo `.max`.
8. Garantia mandatória de sincronização síncrona pré-render (`#preRender`), executando `flushQueue` e `syncAll` antes de qualquer frame em Corona, V-Ray ou Arnold.
9. Benchmark de escalabilidade com 100 cotas ativas sincronizadas em lote.
**Instalação:** `tools/install-dev.ps1` sincronizou a versão atualizada no `ApplicationPlugins\AmenoTools`.
**Gate manual aprovado em 2026-09-04:** o usuário validou no 3ds Max 2026 interativo a criação de cotas ancoradas em caixas/paredes, movimentação/rotação de geometria com recálculo dinâmico, seleção de âncoras, detecção de cotas órfãs ao deletar objetos e fluxo de reancoragem a novos objetos.

### Objetivo

Fazer as cotas acompanharem alterações arquitetônicas (translação/rotação de paredes e elementos) sem se tornarem frágeis, sem travar o viewport e sem perder dados quando nós forem excluídos.

### Implementação

- Schema CA v3 com `anchorType`, `nodeA`, `localPointA`, `nodeB`, `localPointB`, `isOrphan`, `orphanReason`;
- Serviço `AmenoAnchorService` com `dirtyQueue`, debounce timer (50ms) e listener via `NodeEventCallback`;
- Garantia pré-render via hook `#preRender`;
- Indicação visual de cota órfã: arame e material emissivo vermelhos `(color 230 70 70)` no viewport;
- Ferramentas no painel principal: botões de reancoragem A e B com `pickObject`, botão `Selecionar Âncoras` e botão `Reparar Órfãs (Mundial)`;
- Reversibilidade total: Undo atômico em todas as operações de reancoragem e reparo.

### Gate no Max

1. Abrir o 3ds Max 2026 com o Ameno Tools instalado.
2. Criar dois objetos na cena (ex: duas caixas ou paredes `Box001` e `Box002`).
3. Clicar em **Criar cota** e clicar sobre `Box001`, depois sobre `Box002` e posicionar o afastamento da linha:
   - Selecionar a cota e verificar no painel: grupo **Âncoras** exibe `A: Box001` e `B: Box002`.
4. Mover ou rotacionar `Box001` ou `Box002` no viewport:
   - Confirmar que a cota acompanha os objetos e a medida se atualiza em tempo real.
5. Clicar em **Selecionar Âncoras**:
   - Confirmar que `Box001` e `Box002` são selecionados na cena.
6. Deletar `Box002` com a tecla Delete:
   - Confirmar que a cota **não desaparece**.
   - A cota permanece na última posição física válida e suas linhas e texto mudam para cor de alerta vermelha na viewport.
   - O painel exibe `⚠️ COTA ÓRFÃ` e o motivo `Nó de ancoragem B foi excluído da cena`.
7. Criar uma nova caixa `Box003`, selecionar a cota e clicar em **Reancorar B**:
   - Clicar sobre `Box003` no viewport.
   - Confirmar que a cota se reconecta ao `Box003`, o status de órfã desaparece, o texto/linhas voltam à cor normal e o painel exibe `A: Box001 | B: Box003`.
8. Deletar as caixas de uma cota e clicar em **Reparar Órfãs (Mundial)**:
   - Confirmar que a cota é convertida para coordenadas mundiais estáticas limpas e a indicação de órfã é removida.

---

## E8.1 — Estabilização das Âncoras, Estilos e Interface

**Estado:** aprovada no 3ds Max 2026.3 em 2026-09-04 após validação interativa completa.
**Implementação:**
- `Contents/scripts/ameno/core/ameno_anchor_service.ms`: reatividade em tempo real assegurada via watchers dinâmicos `when transform (getAnimByHandle h) changes` compilados em runtime por `execute()` para cada nó âncora; índice reverso $O(1)$ por `Dictionary #string`; sincronização reativa com `with undo off` preservando o histórico de Undo do usuário; inclusão de `controllerOtherEvent` e `controllerStructured` no `NodeEventCallback`; inicialização centralizada e idempotente no `ameno_runtime.ms`; trava anti-recursão `isSyncing` e otimização in-place via `updateDimensionFast`.
- `Contents/scripts/ameno/core/ameno_style_service.ms`: persistência atômica via Custom Attribute `AmenoStyleRegistryCA` no helper de sistema `AMENO_STYLE_REGISTRY` integrado ao histórico nativo de Undo/Redo do 3ds Max, retorno defensivo de clones em `getStyle()` e `listStyles()`, e escape seguro de caracteres (`|`, `;`).
- `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`: conversão obrigatória para unidades de cena (`toSceneUnits`) em todas as dimensões de estilo (`lineThickness`, `fontSize`, `terminalSize`, `extensionOverhang`, `extensionGap`, `textGap`), implementação geométrica de `extensionGap` na spline, e hierarquia estrita de prioridade visual de viewport (Órfã vermelha `230 70 70` > Manual âmbar `245 166 35` > Normal `245 245 245`) mantendo o material de render neutro.
- `Contents/scripts/ameno/core/ameno_dimension_tool.ms`: chamada de `AmenoAnchorService.rebuildIndex()` imediatamente após a criação bem-sucedida de cota, garantindo reatividade instantânea no primeiro movimento sem necessidade de reancoragem prévia; repasse correto de coordenadas de viewport para `handlePoint` e raycast iterativo filtrando nós técnicos Ameno.
- `Contents/scripts/ameno/ui/ameno_main_panel.ms`: redimensionamento compacto para 380 × 640 px (compatível com 1366 × 768 px) com `subRollout` nativo (seções Cota, Auditoria, Âncoras e Ambiente) e reancoragem interativa usando `pickPoint snap:#3D`.
**Evidência automatizada:** `test_bootstrap.ms` e `test_installed_package.ms` aprovados com código 0 no 3ds Max 2026.3 Batch, cobrindo idempotência, Undo de estilos, escala em unidades de cena, prioridade de wirecolor, `extensionGap`, separação de schemas e sincronização de 100 cotas em 2.095 segundos.
**Instalação:** `tools/install-dev.ps1` sincronizou a versão atualizada no `ApplicationPlugins\AmenoTools`.
**Gate manual aprovado em 2026-09-04:** o usuário validou no 3ds Max 2026 interativo:
1. **Reatividade em tempo real**: mover e rotacionar objetos faz a cota acompanhar a geometria imediatamente durante o drag;
2. **Histórico de Undo limpo**: `Ctrl+Z` reverte apenas os movimentos do usuário sem passos espúrios de cota;
3. **Cotas órfãs**: ao excluir um objeto de âncora, a cota não se perde e torna-se vermelha `(230, 70, 70)` com alerta no painel;
4. **Reancoragem**: clicar em reancorar e selecionar novo nó restaura a cota para estado normal e recalculado;
5. **Editor de estilos e Undo**: modificações de estilo com suporte nativo a Undo/Redo no 3ds Max.

---

## E9 — Renderizar somente cotas no Corona

**Estado:** aprovada interativamente no 3ds Max 2026.3 com Corona 13 em 2026-09-04. PNG com fundo transparente gerado, proteção de sobrescrita confirmada (`_001`), cena restaurada. Dois bugs corrigidos durante o gate: `renderOutputFilename`/`renderSaveFile` obrigatórios para o Corona gravar o PNG; critério de parada forçado para 1 % noise / 20 passes no passe de overlay.

**Implementação:** `Contents/scripts/ameno/core/ameno_render_cotas_service.ms`, `Contents/scripts/ameno/renderers/ameno_corona_adapter.ms` e rollout `Render Separado de Cotas` em `Contents/scripts/ameno/ui/ameno_main_panel.ms`.

**Evidência automatizada em 2026-09-04:**

- smoke test integral E1–E9 aprovado no 3ds Max 2026.3;
- pacote instalado via `ApplicationPlugins` aprovado em processo Batch isolado;
- transações simuladas de sucesso, exceção e cancelamento restauraram nós, materiais e layer;
- teste real com Corona 13 produziu PNG 160 × 90 com cotas no alpha (`1338` pixels opacos) e fundo transparente (`13062` pixels transparentes), sem renderizar a geometria comum da cena;
- material de anotação validado com `emitLight = false`, `visibleDirect = true`, `affectAlpha = true`, sem reflexo/refração no passe isolado;
- E10 não foi iniciada: a etapa só avança após o gate manual abaixo.


Gerar o overlay para Photoshop sem tocar no Beauty, LightMix ou Render Elements do usuário.

### Implementação

- painel `Renderizar Cotas`;
- câmera, frame, resolução, pixel aspect e crop herdados do Render Setup;
- isolamento temporário da layer `AMENO_COTAS`;
- primeira saída PNG com alpha; EXR vem após o PNG passar;
- todas as cotas ou somente selecionadas;
- nome/path previsíveis e proteção contra sobrescrita;
- restauração transacional da cena em sucesso, erro ou cancelamento;
- adapter Corona responsável pelo material e comportamento de alpha.

### Gate

- overlay encaixa pixel a pixel sobre a planta;
- apenas cotas aparecem e o fundo é transparente;
- Beauty, LightMix, Render Elements, VFB e visibilidades permanecem intactos;
- exceção simulada e cancelamento restauram todo o estado.

---

## E10 — Fluxo de produção e estabilização

### Entregas

- cotas horizontal e vertical reutilizando o núcleo alinhado;
- seleção múltipla, atualização em lote e bake;
- V-Ray CPU pelo mesmo contrato do adapter Corona;
- V-Ray GPU permanece experimental até matriz própria;
- cenas-fixture, relatório de diagnóstico e documentação de uso;
- testes com 1, 10, 100, 500 e 1000 cotas;
- empacotamento de uma versão alpha interna para uma planta real.

### Gate do MVP interno

- uma planta humanizada real concluída do início ao fim;
- nenhuma perda de dados conhecida;
- instalação, criação, edição, persistência e render separado aprovados;
- limitações e versões exatas de Max, Corona e V-Ray registradas.

---

## E11 — Editor Visual e Preview ao Vivo

**Estado:** planejada; iniciar após a aprovação da E10.

Substituir o rollout funcional criado na E7 por um editor visual coerente com o mockup aprovado pelo usuário. A “viewport” desta etapa é um preview 2D embutido e isolado da cena, não uma viewport 3D adicional do Max.

### Entregas

- prova técnica entre WPF/C# e MAXScript + .NET/WinForms;
- interface moderna com cabeçalho, presets, preview e grupos Texto/Linhas/Terminais;
- `StyleDraft` em memória: controles não alteram a cena antes do commit;
- preview vetorial com planta neutra, texto, linhas, máscara, cores e cinco terminais;
- ações distintas `Cancelar`, `Aplicar às selecionadas`, `Salvar estilo` e `Salvar como novo`;
- compatibilidade/migração segura dos estilos existentes;
- funcionamento em DPI 100/125/150/200 % e pacote `ApplicationPlugins` independente do checkout.

### Gate

- aparência aprovada pelo usuário contra o mockup;
- preview fluido sem criar nós ou rebuildar a cena;
- Cancelar não altera dados nem Undo;
- Aplicar/Salvar atualizam em lote com um único Undo e restauração em erro;
- save/open, fontes ausentes, cinco terminais e pacote instalado aprovados;
- nenhuma regressão funcional nas etapas E1–E10.

**Plano detalhado:** `plans/2026-09-04-e11-editor-visual-preview.md`.


## Próxima ação

Implementar a **E10 — Fluxo de produção e estabilização**:

1. cotas horizontal e vertical reutilizando o núcleo alinhado;
2. seleção múltipla, atualização em lote e bake;
3. adapter V-Ray CPU pelo mesmo contrato do adapter Corona;
4. cenas-fixture, relatório de diagnóstico e documentação de uso;
5. testes de escala com 1, 10, 100, 500 e 1000 cotas;
6. empacotamento de versão alpha interna para uma planta real.
