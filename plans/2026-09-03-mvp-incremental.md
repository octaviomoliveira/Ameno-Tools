# Plano incremental de funcionamento — Ameno Dimensions

**Data:** 2026-09-03  
**Alvo:** 3ds Max 2026 + Corona  
**Estado atual:** E1 aprovada visualmente; E2 aprovada em Batch; E3 aprovada visualmente no viewport, aguardando render comum e limpeza final.

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
| E3 | Uma cota gráfica de teste é construída na cena | Aprovada no viewport; render/limpeza pendentes |
| E4 | Cota alinhada é criada com três cliques e preview | Não iniciada |
| E5 | Cotas sobrevivem a salvar/reabrir, Undo e alterações de cena | Não iniciada |
| E6 | Valor medido, arredondado e manual podem ser revisados | Não iniciada |
| E7 | Estilo edita fonte, texto, linhas e terminais | Não iniciada |
| E8 | Âncoras atualizam cotas e diagnóstico encontra problemas | Não iniciada |
| E9 | Corona renderiza somente as cotas em arquivo transparente | Não iniciada |
| E10 | Fluxo de produção, V-Ray CPU e estabilização do MVP | Não iniciada |

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

**Estado:** aprovada visualmente no viewport em 2026-09-03, após aprovação visual da E1; render comum e limpeza final pendentes.
**Implementação:** `Contents/scripts/ameno/core/ameno_dimension_graphics.ms`, integrada em `ameno_bootstrap.ms`, `ameno_runtime.ms` e `ameno_main_panel.ms`.
**Instalação:** cópia de desenvolvimento atualizada em `ApplicationPlugins`; o hash SHA-256 do módulo instalado corresponde ao fonte.
**Evidência automatizada:** `tests/maxscript/test_bootstrap.ms` passou no 3ds Max 2026.3 e testou criar, reconstruir e remover a cota sem resíduos; `test_installed_package.ms` também aprovou E1, E2 e E3 dentro de `ApplicationPlugins`. Ambos usam `tests/maxscript/batch-isolated.ini`, perfil que evita bloquear a sessão interativa.
**Correção de bootstrap:** a primeira cópia da E3 falhou porque MAXScript só permite `throw` sem argumento dentro de `catch`. A ocorrência foi reproduzida em Batch isolado, corrigida e validada. O bootstrap e o macro agora preservam e mostram o diagnóstico detalhado se outro módulo falhar.
**Gate visual parcial:** a captura fornecida pelo usuário mostrou uma cota ativa, linhas de extensão/terminais e TextPlus `5,00 m` no viewport, com `AMENO_COTAS` selecionada e o painel indicando `1 ativa(s)`.

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

### Como validar agora

1. fazer um render comum da cena com a cota ativa;
2. clicar em `Limpar cotas de teste`;
3. confirmar que os três nós da cota foram removidos e que a cena voltou ao estado anterior.

### Gate no Max

- criar, selecionar, reconstruir e apagar uma cota de teste;
- texto legível pela câmera superior e sem inversão;
- geometria aparece no viewport e em um render comum de teste;
- nenhum helper de sistema aparece no render.

### Fora desta etapa

Ainda não haverá interação de três cliques nem associatividade.

---

## E4 — Ferramenta de três cliques

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

### Objetivo

Transformar o desenho criado em uma entidade Ameno confiável.

### Implementação

- Custom Attributes versionados no controlador;
- ID estável, pontos, offset, unidade, estilo e modo de valor;
- reconstrução após abrir a cena;
- comportamento definido para clone, merge e exclusão parcial;
- arquivo continua abrindo sem o plugin instalado;
- migração de schema preparada desde a primeira versão persistente.

### Gate

- criar, salvar, fechar e reabrir sem alteração visual ou numérica;
- renomear a cota sem perder sua identidade;
- excluir um filho gráfico e reparar pelo painel;
- Undo/Redo e merge não duplicam IDs indevidamente.

---

## E6 — Valores medidos, arredondados e manuais

### Objetivo

Permitir que a cota represente levantamento e intenção de projeto sem esconder divergências.

### Implementação

- painel da cota selecionada;
- `measuredMm`, `displayMode`, incremento e `manualValue` separados;
- motivo opcional da alteração manual;
- delta entre real e exibido;
- ação `Usar valor medido`;
- estado manual em âmbar e marcador `M` somente no viewport;
- filtro/lista de cotas manuais.

### Gate

- medido `20,00 m` pode exibir manual `19,60 m` e delta `-0,40 m`;
- mover os pontos muda o medido e o delta, preservando o manual;
- salvar/reabrir preserva valor e motivo;
- aviso âmbar não aparece no render.

---

## E7 — Editor visual de estilo

### Objetivo

Editar aparência com a clareza do TextPlus, sem expor controles irrelevantes à cotagem.

### Primeira fatia

- fonte instalada, peso, tamanho, tracking e cor;
- espessuras `Fina`, `Normal`, `Forte` e valor personalizado;
- terminais: traço, seta cheia, seta aberta, ponto e nenhum;
- preview de uma cota no próprio editor;
- `Aplicar às selecionadas`, `Salvar como novo` e `Atualizar estilo`;
- Cancelar restaura o snapshot anterior.

### Gate

- um estilo altera todas as cotas vinculadas em um único Undo;
- estilos diferentes coexistem;
- fonte ausente usa fallback e gera diagnóstico;
- terminais esquerdo/direito ficam corretamente espelhados.

---

## E8 — Âncoras, atualização e diagnóstico

### Objetivo

Fazer as cotas acompanharem alterações arquitetônicas sem se tornarem frágeis.

### Implementação

- âncora mundial e âncora local ao objeto;
- fila `dirty` e atualização com debounce;
- atualização antes do render;
- referência perdida fica órfã, nunca some silenciosamente;
- `Reancorar A/B`, `Selecionar e enquadrar` e `Reparar`;
- callbacks idempotentes e limpeza no shutdown/reset.

### Gate

- mover/rotacionar uma parede atualiza somente cotas dependentes;
- excluir referência marca órfã e mantém a cota visível;
- reancorar preserva estilo, texto manual e identidade;
- 100 cotas atualizam dentro da meta inicial de 1 segundo no equipamento de referência.

---

## E9 — Renderizar somente cotas no Corona

### Objetivo

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

## Próxima ação

Concluir o render e a limpeza do gate da **E3 — Primeiro construtor gráfico**. Com esses dois checks confirmados, registrar a aprovação final em `PLAN.md` e iniciar a E4.
