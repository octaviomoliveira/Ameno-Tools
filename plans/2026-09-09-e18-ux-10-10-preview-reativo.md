# E18 — Experiência Qt 10/10 e prévia de estilo realmente reativa

Data: 2026-09-09

Status: execução iniciada na branch `feature/e18-ux-10-10`; E18.0 concluída
com dois testes vermelhos reproduzíveis. Próximo checkpoint: E18.1.

Base obrigatória: branch `feature/e17-ameno-ux`, commit `01e32cd`. Criar uma
branch nova a partir dessa base. Não trabalhar diretamente em `develop` ou
`main` e não promover sem autorização explícita.

Estrutura: **12 etapas e 118 subetapas**. A ordem é deliberada: primeiro
reproduzir e corrigir o contrato da prévia; depois redesenhar a página
Aparência; só então aplicar responsividade e polimento ao restante do produto.

## Checkpoint de execução

- **E18.0 — concluída (2026-09-09):** branch isolada criada; baseline E15/E17
  executada com 17 testes Python PASS; falha do draft sem modelo e overflow em
  780×560 convertidos em dois RED esperados em
  `tests/python/test_e18_baseline.py`; evidência em
  `work/e18-baseline/README.md`.
- **E18.1 — próxima:** implementar `StyleDraft` sempre válido, sem bridge,
  cena, `pymxs` ou mutação durante a edição.

## 1. Objetivo

Levar a interface Qt do Ameno de um candidato tecnicamente estável para uma
experiência profissional, autoexplicativa e visualmente consistente, sem
reintroduzir os travamentos de viewport eliminados no E16.

O resultado deve permitir que um profissional que nunca utilizou o Ameno — e
que pode nunca ter utilizado o 3ds Max — reconheça o fluxo principal, configure
uma cota, veja o resultado antes de aplicá-lo e conclua a primeira cotação sem
depender de explicação externa.

Este marco também corrige uma falha funcional do E17: a prévia 2D não responde
de forma confiável aos controles e hoje desenha apenas uma parte dos parâmetros
do estilo.

## 2. Diagnóstico que o executor não deve redescobrir

### 2.1 Prévia sem atualização perceptível

Em `Contents/python/ameno_ui/styles_page.py`, a página começa com
`self._current = None`. Os controles continuam editáveis antes de uma
atualização explícita da lista, mas `_edited_style()` retorna `None` enquanto
não existe estilo corrente. `update_preview()` encaminha esse valor nulo e o
`PreviewWidget` desenha o snapshot padrão. Por isso o usuário altera campos e
continua vendo a mesma prévia.

Mesmo quando existe um estilo carregado, o painter atual não representa
`tracking`, `extension_overhang`, `extension_gap`, `terminal_size`,
`terminal_placement`, `terminal_angle`, `text_color`, `preview_scale` nem a
geometria exata dos terminais. Uma atualização de repaint, sozinha, não resolve
o problema: é preciso paridade semântica entre o formulário e a prévia.

### 2.2 Clipping e rolagem horizontal

O shell usa sidebar fixa de 184 px; as páginas acrescentam cerca de 60 px de
margens horizontais; Aparência impõe splitter com mínimos de aproximadamente
210 + 600 px. Na janela padrão de 980 px, essa soma não cabe. As capturas reais
mostram textos cortados, cards saindo da área útil, campos truncados e barra
horizontal.

O teste existente `test_layout_renders_at_minimum_default_and_large_sizes`
somente comprova que uma imagem foi produzida e que o scroll é redimensionável.
Ele não prova ausência de clipping, barra horizontal, sobreposição ou perda da
ação principal. É um falso positivo de usabilidade.

### 2.3 O que funcionou e deve permanecer congelado

- A navegação Qt está muito mais rápida que a WPF.
- O E16 retirou criação de objetos e picking pesado do `mouseMove`.
- O preview interativo da viewport usa `gw` e só cria objetos no commit.
- A UI não monitora continuamente seleção, renderer ou viewport.
- Login mantém token apenas em memória.
- Fechar, logout e reabrir já possuem gates de lifecycle.

E18 não autoriza alterar matemática, schema, âncoras, renderers ou pipeline de
commit. Se um ajuste visual exigir tocar nessas áreas, registrar o bloqueio e
deixar essa mudança fora do marco.

## 3. Definição verificável de “10/10”

“Bonito” não será aceito como critério isolado. O candidato só passa quando
todos os itens abaixo estiverem comprovados:

1. Não existe rolagem horizontal em 780×560, 980×720, 1120×760, 1280×800 e
   1560×1000.
2. Não existe clipping funcional em 100%, 125%, 150% e 200% de escala do
   Windows; conteúdo pode exigir rolagem vertical no modo compacto.
3. O botão principal da página aberta fica visível na janela padrão sem o
   usuário precisar procurar lateralmente.
4. Aparência exibe uma prévia válida imediatamente, antes de qualquer leitura
   da cena.
5. Cada parâmetro declarado como suportado altera pixels ou geometria da
   prévia de maneira testável.
6. Arrastar um slider não chama bridge, `pymxs`, MaxScript, cena, callback,
   renderer ou viewport.
7. Mil mudanças consecutivas de parâmetros mantêm o p95 do ciclo de
   modelo/layout/paint abaixo de 20 ms na máquina de desenvolvimento, sem
   crescimento de widgets, timers ou conexões.
8. Cem ciclos de resize e navegação mantêm a mesma árvore de widgets e não
   geram exceção Qt, WPF, minidump ou janela órfã.
9. Foco por teclado é visível, ordem de Tab é lógica e textos essenciais
   atingem contraste mínimo de 4,5:1.
10. Pelo menos três profissionais não treinados — idealmente cinco — concluem
    a primeira cota com taxa de sucesso de 80% ou mais, em até 90 segundos,
    com no máximo um clique incorreto; a sequência contínua deve ser concluída
    em até 180 segundos.
11. Todos os gates E16 e os contratos técnicos E17 continuam verdes.
12. O pacote canary é reproduzível, instalado com o Max fechado e reversível
    por backup.

## 4. Arquitetura de interação

### 4.1 Modelo mental do produto

O fluxo principal deve responder, nessa ordem, somente a três perguntas:

1. **Onde está o desenho?** Planta ou Fachada/Vista.
2. **Como você quer medir?** Uma medida ou Várias medidas.
3. **Qual ação executar?** Iniciar cotação.

Detalhes como unidade, precisão e estilo são configurações secundárias. Devem
ficar próximos do resultado, mas não competir com a decisão principal.

### 4.2 Navegação

- **Cotar:** produzir novas cotas.
- **Aparência:** criar, editar, prever e aplicar estilos.
- **Revisar:** carregar uma cota existente e corrigir seu conteúdo.
- **Exportar:** gerar a saída PNG.
- **Ajuda:** acesso persistente e contextual, sem abrir um novo modo.
- **Configuração/conta:** ação secundária no rodapé.

Ícone nunca substitui rótulo em ações críticas. No modo compacto a navegação
pode virar rail, mas tooltip e estado selecionado continuam obrigatórios.

### 4.3 Aparência

A página será composta por três zonas estáveis:

1. **Estilo atual:** lista, novo, duplicar, renomear e excluir.
2. **Prévia fixa:** permanece visível enquanto os parâmetros rolam.
3. **Ajustes:** grupos Texto, Linha, Terminais e Cor, com divulgação
   progressiva para opções avançadas.

O usuário pode experimentar livremente em um rascunho local. Salvar persiste o
estilo; Aplicar envia o estilo salvo/validado para as cotas. Alterar um controle
jamais aplica silenciosamente na cena.

## 5. Contratos técnicos obrigatórios

### 5.1 `StyleDraft` sempre válido

Criar `Contents/python/ameno_ui/style_draft.py` com um `QObject` local que:

- nasce de `StyleSnapshot.default()`, nunca de `None`;
- contém todas as propriedades editáveis e um `style_id` opcional;
- emite `changed(field_name, value)` e `dirty_changed(bool)`;
- suporta `load(snapshot)`, `reset_to_default()`, `to_snapshot()` e
  `mark_clean()`;
- normaliza números, enums e cores em um único lugar;
- não importa bridge, `pymxs`, MaxScript nem módulos de cena;
- preserva o rascunho ao navegar para outra página;
- descarta ou salva somente após uma decisão explícita do usuário.

### 5.2 Controle composto slider + número

Criar `Contents/python/ameno_ui/parameter_control.py`. Cada parâmetro visual
usa um componente com:

- rótulo claro, unidade e descrição curta/tooltip;
- slider para exploração rápida;
- spinbox/double spinbox para precisão;
- botão discreto de restaurar padrão;
- sincronização bidirecional com `QSignalBlocker`;
- um único sinal semântico `value_changed` por alteração;
- suporte a teclado, PageUp/PageDown, Home/End e wheel apenas quando focado;
- valor digitado fora da faixa do slider aceito dentro da faixa técnica;
- debounce proibido quando esconder feedback; `update()` local pode ser
  agregado no próximo event loop, sem timer recorrente.

Faixas iniciais, derivadas do produto anterior e dos contratos atuais:

| Parâmetro | Slider | Entrada técnica | Passo | Unidade |
| --- | ---: | ---: | ---: | --- |
| Tamanho do texto | 10–500 | 1–5000 | 1 | mm |
| Espaçamento | -10–50 | -100–100 | 0,5 | relativo |
| Distância da linha | 0–250 | 0–1000 | 1 | mm |
| Espessura | 0,2–10 | 0,1–100 | 0,1 | mm |
| Prolongamento | 0–300 | 0–2000 | 1 | mm |
| Recuo da extensão | 0–200 | 0–2000 | 1 | mm |
| Tamanho do terminal | 10–300 | 0–2000 | 1 | mm |
| Ângulo do terminal | 0–180 | 0–180 | 1 | graus |

Essas faixas não mudam o schema. Se o serviço possuir limites mais estritos,
o draft deve validar e explicar o limite antes de salvar.

### 5.3 Prévia pura

Dividir a prévia em:

- `dimension_preview.py::build_preview_geometry(snapshot, viewport_rect)`:
  função pura que produz linhas, polígonos, círculos, posição/rotação do texto,
  máscara e bounding boxes;
- `DimensionPreviewWidget.paintEvent`: converte a geometria em primitivas de
  `QPainter`, sem regra de domínio;
- testes unitários de geometria independentes de tela;
- testes de imagem para estados representativos.

A prévia deve representar fonte, tamanho, negrito, itálico, tracking, máscara,
cor, espessura, afastamento, prolongamento, recuo, tipo/tamanho/posição/ângulo
do terminal e zoom local. O preview usa unidades normalizadas: não consulta
escala da cena e não promete equivalência de pixel com a viewport.

### 5.4 Layout adaptativo sem reconstrução

Criar `responsive.py` e `page_scaffold.py`. O layout troca proporções e
visibilidade de rótulos, mas não recria páginas, não reparenteia widgets e não
duplica sinais.

Breakpoints iniciais:

| Modo | Largura da janela | Navegação | Aparência | Margem |
| --- | ---: | --- | --- | ---: |
| Wide | ≥ 1280 | sidebar 208 px | lista + editor lado a lado | 30 px |
| Medium | 900–1279 | sidebar 184 px | preview acima dos ajustes | 22–24 px |
| Compact | 780–899 | rail 64 px | uma coluna | 16 px |

A janela padrão passa a 1120×760, preservando mínimo 780×560. A geometria
restaurada deve ser trazida para dentro da área visível dos monitores. Não usar
`setMinimumWidth` em cards internos. `QFormLayout` deve permitir wrap. Scroll
horizontal só poderá ser marcado `AlwaysOff` depois que os testes provarem que
o conteúdo realmente cabe; esconder a barra não é corrigir overflow.

## 6. Plano de execução — 12 etapas / 118 subetapas

### E18.0 — Baseline e reprodução objetiva (9)

1. Criar `feature/e18-ux-10-10` a partir de `01e32cd`.
2. Registrar HEAD, estado do Git, versões Max/Python/PySide e SHA do canary E17.
3. Guardar as cinco capturas do feedback como evidência referenciada, sem
   incorporar arquivos temporários ao pacote.
4. Reproduzir Aparência antes e depois de `Atualizar lista` e registrar o valor
   de `_current`, o snapshot recebido e a imagem resultante.
5. Instrumentar temporariamente, apenas nos testes, quais campos mudam pixels.
6. Medir client rect, viewport, sidebar, margens, mínimos e scrollbars nas cinco
   resoluções da definição de pronto.
7. Registrar contagem de widgets, conexões, timers, bridge calls e tempo de mil
   alterações.
8. Rodar os 17 testes Python e as 18 suítes MaxScript do baseline sem editar.
9. Salvar comandos, resultados e diagnóstico em `work/e18-baseline/README.md`.

**Gate:** a falha da prévia e o overflow precisam estar reproduzidos por teste
que falha. Não iniciar o redesenho com testes verdes falsos.

### E18.1 — Rascunho reativo independente da cena (10)

1. Implementar `StyleDraft` sempre inicializado com o estilo padrão.
2. Cobrir todos os campos de `StyleSnapshot` sem renomear o contrato da bridge.
3. Centralizar coerção de decimal com ponto/vírgula e enumeração.
4. Implementar carga atômica de snapshot com sinais bloqueados.
5. Implementar `to_snapshot()` validado e determinístico.
6. Separar estados vazio de biblioteca, estilo não salvo e estilo salvo.
7. Ligar o formulário exclusivamente ao draft.
8. Ligar a prévia exclusivamente ao draft.
9. Garantir que navegar não perca o draft nem aplique na cena.
10. Testar que 1.000 alterações geram zero chamadas ao bridge/pymxs.

**Gate:** abrir Aparência sem estilo carregado já exibe e edita uma prévia
válida. A lista vazia não desativa a experimentação.

### E18.2 — Componente slider + entrada numérica (10)

1. Criar o componente reutilizável com label, unidade, slider e spinbox.
2. Implementar mapeamento inteiro seguro para valores decimais.
3. Usar `QSignalBlocker` para impedir loops slider↔spinbox.
4. Emitir uma alteração semântica por gesto.
5. Permitir valor técnico fora da faixa confortável do slider.
6. Exibir erro inline apenas após entrada inválida concluída.
7. Implementar restaurar padrão e tooltip contextual.
8. Garantir foco, atalhos e leitura por tecnologia assistiva.
9. Testar limites, vírgula decimal, wheel, teclado e valores extremos.
10. Medir 1.000 arrastos simulados sem timer, bridge ou alocação crescente.

**Gate:** cada ajuste mostra resposta imediata e não persiste nada por conta
própria.

### E18.3 — Paridade completa da prévia 2D (12)

1. Extrair cálculo geométrico puro do `paintEvent`.
2. Definir espaço normalizado, margens e escala de ajuste ao canvas.
3. Implementar linha principal e linhas de extensão.
4. Implementar afastamento, prolongamento e recuo.
5. Implementar terminais tick, seta fechada, seta aberta, ponto e nenhum.
6. Implementar tamanho, posição e ângulo dos terminais.
7. Implementar texto, peso, itálico, tracking aproximado documentado e cor.
8. Implementar máscara e distância do texto à linha.
9. Implementar zoom da prévia sem alterar o draft.
10. Exibir estado vazio/erro sem cair silenciosamente no padrão.
11. Criar testes de geometria por parâmetro e snapshots em claro/escuro.
12. Provar que cada parâmetro suportado altera a saída esperada.

**Gate:** a matriz parâmetro→efeito está 100% coberta; nenhum controle decorativo
ou sem resposta permanece na tela.

### E18.4 — Redesenho da página Aparência (10)

1. Criar cabeçalho compacto com título, explicação e indicador salvo/não salvo.
2. Reorganizar lista de estilos com empty state útil.
3. Manter prévia sticky dentro da área útil, nunca sobre o conteúdo.
4. Agrupar controles em Texto, Linha, Terminais e Cor.
5. Deixar propriedades frequentes abertas e avançadas recolhidas.
6. Tornar `Salvar estilo` a ação principal e `Aplicar às cotas` uma ação
   distinta, com escopo explícito.
7. Tratar trocar/excluir estilo com draft sujo sem perda silenciosa.
8. Remover campos mortos, labels truncados e duplicidade de ações.
9. Incluir presets úteis de espessura sem substituir o valor preciso.
10. Validar estado novo, salvo, duplicado, excluído, inválido e sem cotas.

**Gate:** o usuário distingue “experimentar”, “salvar” e “aplicar” sem conhecer
o modelo interno.

### E18.5 — Shell responsivo e eliminação de clipping (12)

1. Implementar breakpoints Wide/Medium/Compact pela largura útil real.
2. Alterar sidebar para rail no compacto preservando tooltips.
3. Migrar páginas para `PageScaffold` com margens consistentes.
4. Remover mínimos horizontais incompatíveis com 780 px.
5. Permitir wrap de formulários e textos longos.
6. Trocar splitters inadequados por layouts adaptativos previsíveis.
7. Definir tamanho padrão 1120×760 e restaurar geometria on-screen.
8. Manter barra de título nativa e botões minimizar/maximizar/fechar.
9. Testar cada página nas cinco resoluções.
10. Testar 100/125/150/200% DPI com fonte real e fallback.
11. Asserir programaticamente ausência de clipping e scrollbar horizontal.
12. Repetir 100 resizes/navegações e comparar árvore de widgets/conexões.

**Gate:** todos os textos e ações críticas cabem; rolagem vertical é permitida
no compacto, horizontal não.

### E18.6 — Cotar para primeiro uso sem susto (9)

1. Reduzir o topo para uma instrução curta e acionável.
2. Apresentar Onde? antes de Como?, seguindo o modelo mental definido.
3. Transformar as quatro escolhas em cards compactos com ícone e exemplo.
4. Mostrar resumo legível: “Fachada · várias medidas · metros · estilo X”.
5. Fixar uma única ação vermelha `Iniciar cotação`.
6. Manter unidade, precisão e estilo em seção secundária visível.
7. Exibir os próximos cliques junto ao CTA, não em um bloco textual longo.
8. Cobrir estados sessão aberta, cancelada, erro e conclusão.
9. Executar teste de primeira cota sem instrução externa.

**Gate:** 80% dos participantes concluem o primeiro fluxo em até 90 segundos e
com no máximo um clique incorreto.

### E18.7 — Revisar, Exportar, Login e configurações (8)

1. Revisar deve explicar seleção como passo 1 e carregar como ação principal.
2. Revisar deve separar leitura, correção e restaurar medido.
3. Exportar deve apresentar destino, escopo e fundo antes do CTA.
4. `Mais ações` deve continuar secundário, com nomes completos.
5. Login deve preservar a marca, explicar token e mostrar erro acionável.
6. Configuração deve priorizar conta, ambiente e diagnóstico.
7. Estados vazios devem sempre responder “o que aconteceu?” e “o que fazer?”.
8. Validar todas as ações existentes contra o inventário E17 para não perder
   funcionalidade.

**Gate:** uma ação principal por contexto, nenhuma função removida e nenhuma
consulta automática à cena.

### E18.8 — Ícones, identidade e acabamento visual (9)

1. Definir grade vetorial Ameno de 24 px, traço e cantos consistentes.
2. Desenhar ícones próprios para Cotar, Aparência, Revisar, Exportar, Ajuda,
   Configuração e estados essenciais.
3. Entregar SVG como fonte e PNG fallback em 1x/2x para compatibilidade Qt.
4. Não usar emoji, glyph de fonte ou pacote de ícones sem licença.
5. Reutilizar o símbolo `O` oficial sem redesenhá-lo.
6. Limitar vermelho à marca, seleção, CTA e erro real.
7. Uniformizar radius, borda, espaçamento, hover, pressed, disabled e focus.
8. Documentar licença/proveniência de todo asset.
9. Gerar galeria visual comparável das páginas e estados.

**Gate:** nenhum asset falta no pacote instalado; fallback mantém função e
hierarquia quando uma fonte ou SVG falhar.

### E18.9 — Acessibilidade, desempenho e lifecycle (10)

1. Definir ordem de Tab por página.
2. Adicionar accessible names e descriptions.
3. Validar contraste e não depender somente de cor.
4. Garantir alvo mínimo de 32 px e feedback de foco.
5. Bloquear wheel acidental em spinbox sem foco.
6. Medir p50/p95 de atualização da prévia.
7. Confirmar zero bridge/pymxs durante edição local e navegação.
8. Confirmar ausência de timers recorrentes e callbacks novos.
9. Repetir abrir/fechar/logout/reabrir e sessão de 30 minutos.
10. Verificar logs, exceções, handles, memória e minidumps.

**Gate:** p95 < 20 ms para o ciclo local e nenhuma regressão de estabilidade.

### E18.10 — Automação, galeria e pacote candidato (10)

1. Substituir o teste de render superficial por asserts geométricos.
2. Adicionar detector de overflow por widget/viewport.
3. Adicionar detector de scrollbar horizontal.
4. Adicionar testes de draft, slider e matriz parâmetro→prévia.
5. Adicionar testes de responsive e DPI.
6. Adicionar teste de árvore estável em resize/navegação.
7. Rodar toda a suíte Python.
8. Rodar as 18 suítes MaxScript E12–E17/E18 e métricas E16.
9. Gerar galeria visual e manifesto SHA-256.
10. Empacotar canary excluindo WPF, caches, evidência e arquivos de trabalho.

**Gate:** zero FAIL, pacote reproduzível e evidência legível por outro agente.

### E18.11 — Canary, validação humana e decisão (9)

1. Confirmar que o 3ds Max está fechado antes da instalação.
2. Criar backup recuperável do `ApplicationPlugins` atual.
3. Instalar e conferir paridade de hashes.
4. Rodar smoke instalado e abrir no Max 2026.
5. Executar matriz manual de páginas, DPI, resize e primeira cotação.
6. Realizar teste com três profissionais, idealmente cinco, sem treinamento.
7. Registrar tempo, erros, hesitações e comentários sem conduzir o usuário.
8. Corrigir somente causas comprovadas e repetir os gates afetados.
9. Solicitar autorização explícita antes de push/promoção; manter `main`
   intacta.

**Gate final:** todos os critérios da seção 3 aprovados. “Parece melhor” não
substitui aceite humano nem métricas.

## 7. Matriz mínima de testes

| Área | Casos obrigatórios |
| --- | --- |
| Draft | default, load, dirty, reset, invalid, navegação, lista vazia |
| Slider | mouse, teclado, wheel, vírgula, extremos, restore, sinais únicos |
| Preview | um golden por terminal; um teste por parâmetro; claro/escuro; zoom |
| Layout | 5 tamanhos × 4 DPIs × 5 páginas; fonte real e fallback |
| Lifecycle | 100 navegações/resizes; 25 open/close; logout/relogin |
| Performance | 1.000 alterações; p50/p95; calls/timers/widgets/memória |
| Viewport | criação individual/contínua; planta/fachada; Esc; commit; Undo |
| Persistência | novo, salvar, duplicar, excluir, reabrir cena e biblioteca |
| Exportar | estado, caminho, escopo, transparente, cancelamento |
| Empacotar | WPF ausente; assets presentes; hash fonte/destino; smoke instalado |

Capturas golden não podem ser a única asserção. Sempre combinar comparação
visual com asserção semântica de geometria, estado ou ação.

## 8. Guardrails para o Antigravity

1. Não copiar nem reativar código WPF.
2. Não criar WebView, browser embutido, processo externo ou servidor local.
3. Não instalar pacotes via pip dentro do Max.
4. Usar somente PySide6/Qt fornecido pelo Max 2026 e biblioteca padrão.
5. Não alterar `mouseMove`, overlay `gw` ou commit E16 sem um teste vermelho
   diretamente relacionado.
6. Não chamar bridge, cena ou viewport em hover, paint, resize, slider, troca de
   aba ou atualização de preview.
7. Não usar timer recorrente para “manter a UI atualizada”.
8. Não ler seleção/renderer automaticamente; leitura continua explícita.
9. Não aplicar estilo enquanto o usuário apenas explora controles.
10. Não usar `None` como estado normal do draft.
11. Não esconder scrollbar antes de provar que não existe overflow.
12. Não resolver layout aumentando o mínimo da janela.
13. Não usar coordenadas absolutas para conteúdo.
14. Não reparenteiar páginas nem recriar widgets em breakpoint.
15. Não conectar o mesmo sinal mais de uma vez.
16. Não capturar widgets em closures sem lifecycle claro.
17. Não criar ícones com emoji ou fonte dependente do sistema.
18. Não alterar o master da marca.
19. Não usar vermelho em grandes superfícies; reservar para intenção e estado.
20. Não reduzir contraste para parecer mais “sofisticado”.
21. Não ocultar unidade nem aceitar valor inválido silenciosamente.
22. Não manter controle cuja mudança não apareça na prévia ou no resultado.
23. Não fazer golden update automático diante de diferença.
24. Não ignorar fallback de fonte/SVG.
25. Não gravar token em disco, log, screenshot ou fixture.
26. Não instalar com `3dsmax.exe` ou `3dsmaxbatch.exe` abertos.
27. Não sobrescrever backup anterior.
28. Não incluir `work/`, logs, caches, fontes externas ou screenshots do usuário
   no pacote.
29. Não fazer push, merge ou promoção sem autorização explícita.
30. Interromper se houver nova exceção nativa, minidump, mutação de cena durante
   preview ou regressão mensurável E16.

## 9. Ordem de diagnóstico quando algo falhar

1. Reduzir o caso ao draft puro.
2. Verificar valor no controle e sinal semântico.
3. Verificar valor normalizado no `StyleDraft`.
4. Verificar geometria pura da prévia.
5. Verificar painter e bounding boxes.
6. Verificar constraints/layout e só então DPI/tema.
7. Se a falha aparecer apenas no Max, verificar host/lifecycle.
8. Somente depois verificar bridge.
9. Nunca investigar a viewport enquanto a falha ainda reproduz em Qt headless.

Esse caminho evita atribuir novamente um bug local de UI ao cálculo de fachada
ou ao pipeline de criação de cotas.

## 10. Checkpoints e política de commits

Commits pequenos e reversíveis:

- `test(e18): capture reactive preview and overflow failures`
- `feat(e18): introduce local style draft`
- `feat(e18): add slider numeric parameter control`
- `feat(e18): rebuild pure dimension preview`
- `feat(e18): redesign appearance workflow`
- `feat(e18): add adaptive shell layouts`
- `feat(e18): simplify novice workflows`
- `feat(e18): add ameno icon system and polish`
- `test(e18): complete accessibility performance and max gates`
- `chore(e18): package validated canary`

Após cada gate, registrar em `work/e18-gates/summary.md`: commit, comandos,
contagens PASS/FAIL, métricas e arquivos de evidência. Não usar “testado” sem
comando e resultado.

## 11. Arquivos previstos

Novos:

- `Contents/python/ameno_ui/style_draft.py`
- `Contents/python/ameno_ui/parameter_control.py`
- `Contents/python/ameno_ui/dimension_preview.py`
- `Contents/python/ameno_ui/responsive.py`
- `Contents/python/ameno_ui/page_scaffold.py`
- `Contents/python/ameno_ui/assets/icons/*.svg`
- `Contents/python/ameno_ui/assets/icons/png/{1x,2x}/*.png`
- `tests/python/test_e18_style_draft.py`
- `tests/python/test_e18_parameter_control.py`
- `tests/python/test_e18_preview_geometry.py`
- `tests/python/test_e18_responsive_layout.py`
- `tests/python/test_e18_accessibility_performance.py`
- `tests/maxscript/test_e18_qt_host.ms`

Alterações prováveis:

- `styles_page.py`, `create_page.py`, `edit_page.py`, `render_page.py`,
  `login_page.py`, `settings_page.py`;
- `window.py`, `components.py`, `theme.py`, `models.py`;
- empacotador, validador estrutural e launcher somente se assets/módulos novos
  exigirem inclusão explícita.

Arquivos congelados salvo prova em contrário:

- matemática/plano de fachada;
- ferramenta contínua E16 e overlay `gw`;
- construtor de spline/TextPlus/terminais;
- schema de Custom Attributes;
- adapters de render.

## 12. Roteiro de validação humana

Entregar ao participante apenas: “Abra o Ameno e crie uma cota na planta”.
Não explicar botões. Observar:

- onde o olhar vai primeiro;
- se entende Planta/Fachada;
- se entende Uma/Várias;
- se encontra o CTA;
- se sabe cancelar;
- se entende a diferença entre Salvar estilo e Aplicar;
- se prevê o efeito de um slider;
- se encontra Revisar e Exportar depois da cotação.

Perguntas posteriores, nunca durante a execução:

1. O que você esperava que acontecesse ao clicar?
2. Em que momento ficou em dúvida?
3. Que nome você daria a esta opção?
4. Você confiaria em usar isso em um trabalho real?

## 13. Rollback

- Fechar o Max.
- Remover somente a pasta instalada E18 após confirmar o caminho absoluto.
- Restaurar o backup criado em E18.11.2.
- Conferir hashes e rodar o smoke instalado.
- Manter a branch e evidências para diagnóstico; não reescrever histórico.

## 14. Prompt pronto para o Antigravity

```text
Execute o plano E18 em
D:\Ameno\_tools\plans\2026-09-09-e18-ux-10-10-preview-reativo.md
do início ao fim, na ordem definida.

Base obrigatória: feature/e17-ameno-ux no commit 01e32cd. Crie a branch
feature/e18-ux-10-10. Não altere develop ou main, não faça push e não promova
sem autorização explícita.

Comece transformando a falha atual da prévia e o overflow em testes vermelhos.
Corrija primeiro o StyleDraft sempre válido e a prévia geométrica pura. Somente
depois redesenhe Aparência, responsividade e as demais páginas. Preserve
integralmente o desempenho E16: nenhuma chamada a bridge, pymxs, MaxScript,
cena, renderer ou viewport durante edição local, paint, resize ou navegação.

Obedeça todos os guardrails, gates e critérios mensuráveis do plano. Faça
commits pequenos por checkpoint e registre comandos, PASS/FAIL, métricas e
evidências em work/e18-gates/summary.md. Diante de minidump, exceção nativa,
mutação de cena durante preview ou regressão E16, pare e documente antes de
continuar.

Deixe qualquer etapa que exija decisão humana ou autorização de publicação por
último. A instalação canary só pode ocorrer com 3ds Max e 3ds Max Batch
fechados e após backup recuperável.
```

## 15. Estado ao encerrar este planejamento

- Plano técnico e de produto: pronto.
- Implementação E18: não iniciada.
- E17: gates técnicos verdes, mas aceite visual humano reprovado.
- E16: baseline de desempenho obrigatório e congelado.
- Próxima ação do executor: E18.1, implementando o `StyleDraft` local sempre
  válido e fazendo os dois testes RED avançarem sem acessar a cena.
