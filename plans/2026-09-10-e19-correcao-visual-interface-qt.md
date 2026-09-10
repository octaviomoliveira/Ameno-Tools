# E19 — Interface Qt visualmente aprovada no 3ds Max 2026

Data: 2026-09-10

Status: em execução; referências Cotar e Estilo implementadas e aprovadas nos
gates Qt locais. Cotar está instalada como canary; instalação e gate visual de
Estilo no 3ds Max 2026 ainda pendentes.

Origem: o canary E18 passou os gates técnicos, mas foi reprovado no uso real
do 3ds Max em 2026-09-10. As capturas em `work/e19-baseline` são a fonte de
verdade visual desta correção.

Decisão arquitetural: `docs/decisions/0028-e19-referencia-visual-e-gate-no-host.md`.

Base funcional: `feature/e18-ux-10-10`, incluindo o commit funcional
`d22fc8f` e as evidências posteriores até `f7f30b4`. Antes de editar, registrar
o HEAD exato e criar `feature/e19-qt-visual-acceptance`. Não trabalhar em
`develop` ou `main` e não promover sem autorização explícita.

Estrutura: **6 etapas e 32 subetapas**. Por decisão do usuário em 2026-09-10,
a página Cotar passa a ser a primeira referência visual e de interação.
Estilo e as demais páginas só recebem o padrão depois que Cotar passar no
Max real.

## 1. Resultado esperado

Entregar uma interface que caiba, seja legível e oriente o trabalho no tamanho
real usado pelo usuário. Um profissional deve conseguir identificar o fluxo,
criar uma cota de planta ou fachada, ajustar um estilo vendo a prévia, revisar
uma cota e exportar um PNG sem depender de explicação externa.

O E19 não será chamado de “10/10” por avaliação interna. O marco só termina
quando os critérios objetivos deste documento e o aceite humano forem
registrados.

## 2. Evidência da reprovação do E18

Capturas feitas dentro do Max, preservadas em:

- `work/e19-baseline/01-cotar-max-real.png`;
- `work/e19-baseline/02-aparencia-max-real.png`;
- `work/e19-baseline/03-revisar-max-real.png`;
- `work/e19-baseline/04-exportar-max-real.png`.

Falhas observadas:

- títulos, descrições, cartões e navegação cortados;
- breakpoint escolhido pela largura do shell, embora a largura útil da página
  fosse menor;
- preview de Aparência fora da área visível durante o ajuste dos sliders;
- fonte e espaçamentos grandes para a densidade disponível;
- botão de cor com contraste insuficiente;
- empty state de Revisar ocupa quase toda a janela sem acrescentar informação;
- mensagens repetem instruções e expõem detalhes internos de implementação;
- ausência de scrollbar horizontal foi interpretada como ausência de clipping;
- galeria offscreen não reproduziu as métricas de fonte, DPI e viewport do host.

## 3. Princípio de execução

```text
baseline real -> Cotar -> gate no Max -> sistema responsivo
              -> Aparência e demais páginas -> gate completo -> canary
```

Cotar precisa passar antes de qualquer propagação. Se ela falhar, corrigir a
causa nela e repetir o gate; não compensar o problema nas outras páginas.

## 4. Contrato visual mensurável

### 4.1 Tamanhos obrigatórios

Validar no cliente real da janela, depois de descontar title bar, sidebar,
scrollbar e margens:

| Janela | Objetivo |
| --- | --- |
| 780×560 | mínimo suportado, rail compacto, conteúdo sem corte |
| 980×720 | tamanho padrão usado nas capturas do usuário |
| 1280×800 | layout confortável em duas colunas quando couber |
| maximizada | expansão equilibrada, sem cartões excessivamente largos |

Registrar também `devicePixelRatio`, DPI lógico/físico, família real e métricas
da fonte carregada. A validação deve usar a escala do Windows do usuário e, na
automação isolada, 100%, 125%, 150% e 200%.

### 4.2 Critérios globais

- Zero texto cortado, inclusive hint, botão, combo, spinbox e status.
- Zero sobreposição e zero controle parcialmente fora do viewport horizontal.
- Quebra de linha explícita para conteúdo instrucional.
- Elipse somente em dados longos, com tooltip contendo o valor completo.
- CTA primário visível sem scroll no tamanho padrão.
- Navegação legível; no rail compacto, ícone completo e tooltip acessível.
- Contraste mínimo WCAG AA: 4,5:1 para texto normal e 3:1 para texto grande,
  foco e componentes essenciais.
- Alvo interativo mínimo de 32×32 px; CTA e ações principais com 40 px.
- Foco de teclado visível e ordem de Tab coerente.
- Nenhuma mensagem duplicada na mesma tela.
- Nenhum texto de arquitetura apresentado como orientação ao usuário.

### 4.3 Contrato específico de Cotar

- Textos curtos e orientados à decisão; nenhuma explicação repete o título.
- Quatro `ChoiceCard` reutilizáveis, cada um com ícone vetorial, título,
  descrição curta e indicador próprio.
- Duas perguntas apenas: como medir e orientação do desenho.
- Descrição nunca é texto multiline dentro de `QPushButton`; título e hint são
  `QLabel` independentes com word-wrap.
- Em 980×720, os quatro cards, o estado da cena e o CTA ficam inteiros sem
  rolagem horizontal ou vertical para iniciar.
- O vermelho marca somente a opção ativa e o CTA; estados inativos permanecem
  neutros.
- Sidebar permanece compacta e legível; Ajuda e Configurações não cortam.
- Estado da cena comunica prontidão, resumo, contagem e layers sem duplicação.
- Direção fica no fluxo principal em um seletor segmentado compacto. Automática
  é exclusiva de Uma medida; ao ativar Várias medidas, a interface escolhe
  Horizontal, mantém Automática visível e desabilitada e explica a regra.
- Automática, Horizontal e Vertical usam SVGs locais próprios, equivalentes à
  referência, com fallback seguro e sem depender de glifos da fonte do host.
- Combinação contínua + automática é impedida por estado; modal existe somente
  como fallback no CTA e nunca como fluxo normal.
- Detalhes e manutenção ficam sob demanda e não competem com o primeiro uso.
- A referência preservada é `work/e19-reference/01-cotar-target.png`.

### 4.4 Contrato específico de Estilo

- Preview 2D permanece visível enquanto qualquer parâmetro é alterado.
- Preview, primeiro grupo de sliders e barra de ações aparecem juntos em
  980×720.
- Em largura confortável, controles rolam à esquerda e preview fica fixo à
  direita.
- Em largura mínima, preview fica fixo no topo, ações no rodapé e somente os
  controles rolam.
- Nome, fonte, valor, unidade e reset nunca se sobrepõem.
- Arrastar slider atualiza a prévia localmente, sem bridge, cena ou timer.
- Digitação aceita vírgula e wheel sem foco não altera valores.
- Cor usa swatch separado; o texto do botão não herda a cor configurável.
- Salvar e Aplicar comunicam destinos diferentes e exibem estado dirty.
- Toda propriedade visível produz efeito perceptível na prévia.

## 5. Arquitetura de layout obrigatória

### 5.1 Largura útil

O breakpoint deve receber a largura do `viewport()` que hospeda a página. Não
usar `AppShell.width()` como aproximação. A largura útil é a área restante após
sidebar, frame, scrollbar e margens.

Contrato inicial, ajustável uma única vez com evidência do Max:

```text
available = page_view.viewport().width()
compact   = available < 660
medium    = 660 <= available < 900
wide      = available >= 900
```

### 5.2 Host de Estilo

A página Estilo não deve ficar inteira em uma única rolagem externa. Usar
um root estável com quatro regiões:

```text
┌─────────────────────────────────────────────────────────────┐
│ título + seletor compacto de estilo                         │
├──────────────────────────────┬──────────────────────────────┤
│ controles com scroll próprio │ preview fixo                 │
│ texto / linhas / terminais   │ escala / fundo               │
├──────────────────────────────┴──────────────────────────────┤
│ estado dirty                   Salvar alterações | Aplicar   │
└─────────────────────────────────────────────────────────────┘
```

No compacto, o preview passa para cima dos controles com altura reduzida, mas
continua fora do scroll dos controles. A barra de ações também fica fixa. Não
usar coordenadas absolutas.

### 5.3 Política de tamanho

- Definir stretch factors e `QSizePolicy` conscientemente.
- Campos numéricos usam largura baseada no maior valor formatado.
- Frases quebram linha; labels de formulário permanecem curtas.
- Cartões não impõem `minimumWidth` maior que o viewport.
- Título + descrição usam componente com dois `QLabel` e word-wrap, não texto
  multiline em `QPushButton`.
- A rolagem vertical pertence somente à região que cresce.
- Scrollbar horizontal permanece visível durante desenvolvimento. O gate exige
  `maximum() == 0` e ausência de clipping interno.

## 6. Plano de execução — 6 etapas / 32 subetapas

### E19.0 — Congelar a falha e corrigir os instrumentos (4)

1. **Preservar o baseline real.** Copiar as quatro capturas para
   `work/e19-baseline`, registrar data, dimensões, hashes e descrição. Marcar
   E18.11 como reprovada no plano vivo, no E18 e no índice de planos.

2. **Capturar métricas do host.** Criar diagnóstico Qt local com geometria da
   janela, sidebar, viewport, scrollareas e widgets visíveis; registrar DPI,
   DPR, família, pixel size, ascent, descent, line spacing e bounding rect.
   Identificar cada widget por `objectName` e caminho de pais.

3. **Criar detector real de clipping.** Para `QLabel`, botão, checkbox, combo,
   spinbox e navegação, comparar `contentsRect()` com font metrics/`sizeHint()`.
   Considerar wrap, margens, ícone, indicador, suffix e scrollbar.

4. **Executar baseline RED.** Cobrir cartões ChoiceGroup, sidebar, preview fora
   da vista, botão de cor e empty state. Guardar o RED antes da implementação e
   confirmar que os gates técnicos E16/E18 continuam verdes.

**Gate E19.0:** as falhas das capturas são reproduzidas por métricas; nenhum
teste passa por esconder conteúdo ou scrollbar.

### E19.1 — Construir Cotar como referência (8)

1. **Preservar a referência do usuário.** Copiar a imagem para
   `work/e19-reference`, registrar origem, dimensões, hash e critérios. A imagem
   orienta composição; nunca é usada como fundo ou código.

2. **Criar `ChoiceCard` reutilizável.** Compor um botão checkable com ícone,
   título, hint e indicador em widgets independentes. Preservar `ChoiceGroup`,
   valores, sinais, preferências e acessibilidade.

3. **Desenhar ícones no Qt.** Usar `QPainter` para medida única, sequência,
   planta, fachada e estado. Não depender de glifos Unicode ou arquivos
   externos que possam faltar no host.

4. **Reduzir conteúdo.** Manter um título, uma frase curta, duas perguntas e
   descrições de no máximo 34 caracteres. Remover tutorial da rota principal e
   deixá-lo acessível apenas por Ajuda.

5. **Compor estado da cena.** Mostrar indicador, status, resumo da escolha,
   contagem e layers em um único card compacto. Nenhuma consulta acontece por
   resize, navegação ou pintura.

6. **Hierarquizar ações.** Manter um único CTA vermelho `Iniciar cotação` e
   uma ação secundária neutra `Mais ações`. Detalhes permanecem recolhidos.

7. **Validar o conteúdo interno.** Em 980×720, medir `contentsRect` e
   `QFontMetrics` de todos os títulos e hints, CTA visível e scrollbar
   horizontal em zero. Repetir em 780×560 e DPIs suportados.

8. **Preservar contratos funcionais.** Seleções continuam locais até o clique
   no CTA; cada pergunta tem uma opção ativa; preferências, manutenção,
   planta/fachada e individual/contínua mantêm o mesmo bridge.

**Gate E19.1:** Cotar passa automação e produz captura legível em 980×720. O
gate automatizado está verde; canary instalado em 2026-09-10; o gate no Max
2026 continua pendente.

### E19.2 — Validar a referência e fechar responsividade (6)

1. **Instalar protótipo canary de Cotar.** Fechar Max/Batch, criar backup,
   instalar a branch, conferir hashes e capturar com fonte/DPI reais.

2. **Executar gate humano intermediário.** O usuário identifica como criar uma
   medida, várias medidas, planta e fachada; troca escolhas e encontra o CTA
   sem instrução externa. E19.3 fica bloqueada enquanto esse gate não passar.

3. **Usar largura útil nos breakpoints.** Ligar o cálculo ao
   `page_view.viewport().width()`, incluindo resize e mudança de DPI. Atualizar
   somente ao mudar de modo; não repolir `QStyle` nem reconstruir páginas.

4. **Corrigir navegação e tipografia.** Rail compacto mostra ícones completos e
   tooltips. Sidebar com rótulos só aparece quando todos cabem medidos pela
   fonte real. Limitar largura de leitura e definir escala tipográfica coerente.

5. **Fechar comportamento compacto.** Empilhar cards apenas quando a largura
   útil exigir. Não esconder texto, reduzir fonte abaixo do token ou impor
   largura mínima maior que o viewport.

6. **Repetir matriz de layout/lifecycle.** Cinco larguras, quatro DPIs, 100
   resizes e 100 navegações; árvore estável, conexões únicas, horizontal zero e
   detector de clipping zero. Repetir captura no Max após mudar breakpoint.

**Gate E19.2:** aprovação explícita de Cotar no Max e sistema responsivo
comprovado antes de alterar as demais páginas.

### E19.3 — Aplicar o padrão às demais páginas (6)

1. **Estilo.** Renomear a superfície Aparência e criar root fixo com seletor
   do estilo atual, `Novo estilo`, menu de ações, controles roláveis, preview
   sempre visível e barra de ações fixa. Preservar draft e sinais.

2. **Preview e parâmetros.** Organizar Texto, Linhas, Terminais e Cores em
   grupos recolhíveis. Slider, valor técnico e unidade não se sobrepõem. Toda
   alteração atualiza a prévia local imediatamente; cor usa swatch + valor +
   ação, e Salvar/Aplicar têm destinos claros.

3. **Revisar.** Trocar empty state gigante por orientação compacta com uma
   ação. Remover texto sobre arquitetura. Quando carregada, mostrar leitura,
   override e aplicação; IDs longos usam elipse + tooltip. Um único status.

4. **Exportar.** Consolidar renderer em uma linha. Caminho, escopo e fundo
   empilham em compact. Explicar bloqueio de forma acionável e remover mensagens
   repetidas.

5. **Configuração e Login.** Priorizar conta/logout; diagnóstico fica
   recolhido. Marca, token e CTA cabem em 780×560. Validar Enter, mostrar,
   ocultar e limpar sem submit duplicado nem exposição do token.

6. **Revisar microcopy e hierarquia.** Um título, uma orientação curta, uma
   ação principal e um estado por página. Remover termos de implementação e
   uniformizar ícones, espaços e foco.

**Progresso E19.3:** itens 1 e 2 implementados; 67/67 testes Python passaram,
incluindo layout 980x720/780x560, quatro escalas de DPI, prévia local sem bridge
e rodapé fixo. Após os primeiros gates no Max, a divisão foi ajustada para 7:4
em favor da coluna técnica. O gate agora exige ao menos 440 px úteis nos
controles e 265 px nos campos principais em 980x720; abaixo de 780 px úteis da
página, a prévia sobe antes que qualquer campo seja cortado. Itens 3 a 6 e a
repetição do gate dentro do Max continuam pendentes.

Complemento após o gate real: a janela passa a abrir em 1280x720, limitada à
área útil do monitor, mesmo quando existir geometria estreita de uma sessão
anterior. Bibliotecas antigas que possuíam somente o estilo Arquitetônico
recebem os presets Editorial e Técnico sem sobrescrever estilos personalizados
e sem duplicar registros em aberturas posteriores. O conjunto local passou a
67 testes Python; a migração host-side possui teste MaxScript dedicado e ainda
precisa ser executada com o Max fechado.

**Gate E19.3:** todas as páginas passam os contratos de Cotar e todas as ações
funcionais anteriores continuam alcançáveis.

### E19.4 — Validação visual e de uso no Max (5)

1. **Gerar galeria dentro do host.** Capturar Login, Cotar, Estilo, Revisar
   vazia/carregada, Exportar e Configuração em 780×560, 980×720 e maximizada;
   registrar DPI, fonte e geometria.

2. **Executar auditoria host-side.** Percorrer controles visíveis e falhar por
   texto cortado, overflow, sobreposição, foco invisível, CTA fora da viewport
   ou preview invisível durante edição.

3. **Executar tarefas sem instrução.** Pedir apenas: criar cota na planta;
   mudar tamanho e aplicar; exportar cotas. Registrar tempo, primeiro clique,
   hesitações, erros e necessidade de ajuda.

4. **Testar com três profissionais, idealmente cinco.** Todos devem concluir
   Cotar; pelo menos 80% concluem Aparência e Exportar sem ajuda; zero perda de
   dados, crash ou bloqueio. Registrar comentários sem conduzir.

5. **Triar e repetir.** Corrigir causas comprovadas. Correção visual repete
   E19.1/E19.2; correção de fluxo repete a tarefa; alteração de host repete E16.
   Comparar capturas novas com o baseline rejeitado.

**Gate E19.4:** critérios aprovados e aceite registrado pelo usuário. Avaliação
do agente não encerra este gate.

### E19.5 — Regressão, canary final e decisão (3)

1. **Rodar regressão completa.** Executar Python E15–E19, MaxScript E12–E19,
   E14 planta/fachada e E16 overlay/mouseMove/callback/commit. Verificar logs,
   dumps, memória, handles e close/reopen. Zero FAIL/exceção nativa.

2. **Empacotar e instalar canary final.** Validar manifesto Max 2026, excluir
   WPF/cache/work, gerar SHA-256, fechar Max, criar backup, instalar, comparar
   hashes e rodar smoke. Fazer uma cotação planta/fachada na cópia instalada.

3. **Registrar decisão.** Atualizar plano, galeria e evidências. Solicitar
   autorização antes de push/merge/promoção. Se o humano reprovar, manter o
   canary rejeitado e abrir somente correções baseadas em fatos.

**Gate E19.5:** canary funcional e visualmente aprovado, rollback comprovado e
decisão registrada.

## 7. Testes obrigatórios

Novos testes Python/Qt:

- `test_e19_clipping_audit.py`;
- `test_e19_appearance_workspace.py`;
- `test_e19_parameter_rows.py`;
- `test_e19_responsive_content_width.py`;
- `test_e19_page_states.py`;
- `test_e19_copy_contrast.py`;
- `test_e19_lifecycle_performance.py`.

Testes dentro do Max:

- launcher e close/reopen;
- Login/App/logout;
- troca de página sem leitura de cena;
- resize/DPI com métricas reais;
- preview visível durante sliders;
- criação individual/contínua em planta/fachada;
- Esc, Undo, commit, seleção/revisão e exportação;
- instalação via `ApplicationPlugins`.

Cada teste de scrollbar deve incluir uma asserção de geometria, texto ou
visibilidade. Captura golden sozinha não aprova comportamento.

## 8. Falhas previsíveis e caminho correto

### 8.1 Teste verde com texto cortado

Causa: medir somente scrollbar ou widget pai. Caminho: medir `contentsRect`,
font metrics, margens, ícone, wrap e size hint do controle real no host; guardar
imagem e relatório do mesmo frame.

### 8.2 Breakpoint errado no Max

Causa: usar largura da janela/shell. Caminho: observar `page_view.viewport()`,
reagir a resize/DPI e registrar largura disponível + modo no diagnóstico.

### 8.3 Preview desaparece durante ajuste

Causa: preview e controles compartilham scroll. Caminho: preview e ações ficam
fora da scrollarea dos controles; compact reduz altura, mas não muda o contrato.

### 8.4 Troca de layout duplica sinal ou derruba Qt

Causa: recriar/reparentear a cada resize ou usar `QStyle.unpolish/polish`.
Caminho: widgets únicos, mudança idempotente apenas no breakpoint, receivers
testados e stylesheet top-level somente quando necessário.

### 8.5 Fonte real muda a densidade

Causa: confiar no offscreen ou em altura fixa. Caminho: size hints, métricas da
fonte real e layout flexível; validar Space Grotesk e fallback. Não reduzir a
fonte globalmente para mascarar.

### 8.6 Valor técnico estoura a linha

Causa: spinbox dimensionado pelo valor atual. Caminho: maior valor formatado,
incluindo sinal, decimal, unidade e botões; compact pode usar duas linhas.

### 8.7 Cor torna ação ilegível

Causa: cor escolhida usada como fundo do botão. Caminho: swatch independente,
ação com tema e contraste calculado.

### 8.8 Correção visual toca viewport

Causa: chamar refresh/bridge em resize ou preview. Caminho: layout e painter
consomem draft local; cena/renderer somente em ações explícitas.

### 8.9 Outras páginas voltam a cortar

Causa: copiar pixels da referência sem princípios. Caminho: extrair componentes
flexíveis aprovados e rodar o detector em cada página.

### 8.10 Avaliação interna encerra cedo

Causa: confundir preferência do executor com evidência. Caminho: tarefas sem
instrução, critérios mensuráveis e aceite humano registrado.

## 9. Guardrails obrigatórios

1. Não declarar “10/10” antes do gate humano.
2. Não alterar `develop` ou `main` durante a execução.
3. Não fazer push, merge, tag ou release sem autorização.
4. Não reativar WPF, WebView, browser ou processo auxiliar.
5. Não instalar dependências no Python do Max.
6. Não aumentar o tamanho mínimo para esconder clipping.
7. Não ocultar scrollbar para passar teste.
8. Não reduzir globalmente a fonte como correção.
9. Não usar coordenadas absolutas.
10. Não usar altura fixa em texto com wrap.
11. Não usar `QPushButton` multiline para título + descrição.
12. Não usar largura do shell como largura útil.
13. Não colocar preview e controles no mesmo scroll.
14. Não destruir/recriar páginas durante resize.
15. Não reparentear widget em todo resize.
16. Não conectar sinal mais de uma vez.
17. Não chamar `QStyle.unpolish/polish` no Qt embarcado.
18. Não adicionar timer recorrente para layout/preview.
19. Não chamar bridge, pymxs, cena, renderer ou viewport em paint, slider,
    hover, resize ou navegação.
20. Não alterar E16 sem teste vermelho direto.
21. Não alterar matemática, fachada, CA ou renderer por motivo visual.
22. Não usar captura offscreen como aceite final.
23. Não aprovar scrollbar zero sem detector de clipping.
24. Não usar elipse em instruções ou ações.
25. Não deixar CTA fora do primeiro viewport padrão.
26. Não exibir texto destinado ao desenvolvedor.
27. Não repetir orientação em header, card e status.
28. Não usar cor configurável sob texto sem contraste.
29. Não manter controle sem efeito comprovado.
30. Não perder draft/seleção ao trocar breakpoint.
31. Não instalar com Max/Batch aberto.
32. Não remover backup antes da promoção aceita.

## 10. Arquivos previstos

Novos:

- `Contents/python/ameno_ui/layout_metrics.py`;
- `Contents/python/ameno_ui/visual_audit.py`;
- testes Python E19 listados na seção 7;
- `tests/maxscript/test_e19_qt_visual_contracts.ms`;
- `tests/maxscript/test_e19_installed_host.ms`;
- `tools/render-e19-host-gallery.py`;
- `work/e19-baseline/README.md`;
- `work/e19-reference/README.md` e `01-cotar-target.png`;
- `work/e19-gates/summary.txt`;
- `work/e19-visual/README.md`.

Alterações prováveis:

- `styles_page.py`, `parameter_control.py`, `dimension_preview.py`;
- `window.py`, `responsive.py`, `page_scaffold.py`, `components.py`, `theme.py`;
- `create_page.py`, `edit_page.py`, `render_page.py`, `config_page.py`,
  `login_page.py`;
- runners e empacotador somente para novos módulos/assets.

Congelados salvo teste vermelho relacionado:

- ferramenta contínua e overlay `gw`;
- matemática/plano de fachada;
- spline, TextPlus e terminais;
- Custom Attributes e persistência;
- adapters Corona/V-Ray e serviço de render.

## 11. Commits sugeridos

1. `test(e19): capture real host clipping failures`
2. `feat(e19): rebuild cotar from approved visual reference`
3. `test(e19): certify cotar at 980x720`
4. `feat(e19): build fixed appearance workspace`
5. `fix(e19): drive breakpoints from page viewport`
6. `test(e19): certify visual contracts in Max host`
7. `chore(e19): package approved canary evidence`

## 12. Definição de pronto

E19 termina somente quando:

- as quatro falhas do baseline não aparecem nas novas capturas;
- detector de clipping retorna zero em todas as páginas/tamanhos;
- Cotar preserva textos curtos, cards íntegros e CTA visível em 980×720;
- Aparência mantém preview, controles relevantes e ações acessíveis;
- usuário aprova Cotar antes da propagação;
- tarefas Cotar, Aparência e Exportar passam sem instrução;
- teste com profissionais atinge a taxa definida;
- regressão Python/Max, E14 e E16 passa;
- pacote instalado tem hashes iguais e zero WPF/cache;
- não há exceção nativa, dump ou regressão de viewport;
- usuário registra aceite final e decide sobre promoção.

## 13. Prompt para o agente executor

```text
Execute integralmente o plano E19 em
D:\Ameno\_tools\plans\2026-09-10-e19-correcao-visual-interface-qt.md.

Leia o documento inteiro. Comece pelas capturas reais em work/e19-baseline e
pela referência em work/e19-reference. Construa somente Cotar como primeira
referência. Não propague o padrão às demais páginas até Cotar passar no 3ds
Max 2026 e receber aceite humano intermediário.

Em Cotar, use textos curtos, sidebar compacta, cards com descrição curta e
componentes reutilizáveis. Não corte conteúdo em 980×720. Vermelho aparece
somente na opção ativa e no CTA. Evite tutorial permanente, duplicação e
poluição visual.

Calcule breakpoints pela largura do viewport da página. Mantenha preview e
ações fora do scroll dos controles. Meça texto com fonte real, DPI, margens,
ícones e indicadores; ausência de scrollbar não basta. Não aumente a janela
mínima; não esconda scrollbar; não reduza globalmente a fonte.

Preserve E16: edição, paint, resize e navegação usam somente estado local e
nunca chamam bridge, pymxs, cena, renderer ou viewport. Não use
QStyle.unpolish/polish, timers, WPF, WebView ou dependências novas.

Registre gates e capturas. Deixe push/promoção por último e apenas após
autorização explícita. Se a referência reprovar, corrija-a antes de propagar.
```

## 14. Estado de partida

- E16: desempenho de viewport aprovado e congelado.
- E18: tecnicamente verde, visualmente reprovado no Max real.
- Canary E18: instalado apenas como baseline; não promover.
- E19: plano pronto, zero código implementado.
- Próxima ação: E19.0, preservar baseline, medir host e criar testes RED.
