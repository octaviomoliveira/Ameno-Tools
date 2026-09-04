# ADR 0012 — Estabilização das Âncoras, Estilos e Interface (E8.1)

- Estado: aceita para o MVP
- Data: 2026-09-04

## Contexto

Após a implementação da Etapa E8, testes manuais e uma auditoria técnica aprofundada revelaram inconsistências que precisavam ser sanadas antes de avançar para o renderizador Corona (E9):

1. **Reatividade a transformações no Viewport**: O NodeEventCallback escutava apenas eventos estruturais e geométricos (modelStructured, geometryChanged, deleted). No 3ds Max, ferramentas de viewport como Move e Rotate atuam diretamente nos controladores de transformação e disparam controllerOtherEvent e controllerStructured. Sem esses eventos, a cota não acompanhava o objeto ao ser movido com a ferramenta de movimentação do Max.
2. **Poluição do histórico de Undo e risco de recursão**: Recriações e sincronizações durante a interação do usuário adicionavam entradas indesejadas na pilha de Undo e podiam disparar novos eventos em cascata no NodeEventCallback.
3. **Undo dos Estilos Visuais**: Modificações de estilo em lote não sincronizavam o registro interno serializado em caso de max undo ou max redo, permitindo discrepâncias entre as cotas na cena e o estado no editor de estilos. Além disso, referências expostas permitiam mutação acidental fora do serviço.
4. **Escala física real em milímetros**: Propriedades gráficas (lineThickness, 	erminalSize, extensionOverhang, extensionGap, 	extGap, ontSize) eram atribuídas sem conversão uniforme para unidades de cena (	oSceneUnits), gerando divergências em cenas configuradas em polegadas, centímetros ou metros. O parâmetro extensionGap (afastamento entre o ponto cotado e o início da linha de extensão) ainda não tinha suporte gráfico na spline.
5. **Prioridade visual de diagnóstico**: Se uma cota possuísse substituição manual de valor e simultaneamente perdesse um nó de ancoragem (tornando-se órfã), havia ambiguidade sobre qual cor devia prevalecer no viewport.
6. **Desempenho e latência**: Reconstruir nós (ebuildDimension) a cada micro-movimento gerava perda de nós selecionados e sobrecarga no garbage collector.
7. **Ergonomia em telas compactas e reancoragem**: A janela de diálogo ultrapassava a altura utilizável em monitores 1366 × 768 px e o botão de reancoragem não permitia clicar diretamente um ponto 3D na nova geometria.

## Decisão

1. **Reatividade Completa no NodeEventCallback**:
   - Registrados os eventos controllerOtherEvent e controllerStructured no NodeEventCallback do AmenoAnchorService.
   - Inicialização centralizada no meno_runtime.ms, eliminando auto-inicialização no corpo do script.
   - Idempotência rigorosa garantida em init() e shutdown() com desativação prévia segura de callbacks e liberação de recursos.
   - Guarda de recursão isSyncing impedindo reentrância nos métodos de sincronização.
   - Sincronizações reativas executadas dentro de bloco with undo off, preservando o histórico de Ctrl+Z do usuário limpo.

2. **Undo Atômico de Estilos e Imutabilidade**:
   - Criado o Custom Attribute AmenoStyleRegistryCA no helper técnico de sistema AMENO_STYLE_REGISTRY (alocado na layer AMENO_SYSTEM). Todas as alterações de estilos são gravadas na propriedade stylesData, integrando-se de forma nativa e automática ao histórico de Undo/Redo do 3ds Max.
   - O método checkSyncWithRegistry() detecta automaticamente quando um max undo ou max redo é acionado pelo usuário e recarrega os estilos sincronizados.
   - getStyle() e listStyles() passam a retornar clones defensivos (cloneStyle), impedindo efeitos colaterais por mutações externas.
   - Serialização com escape robusto de pipes (| -> \p) e ponto-e-vírgula (; -> \s).

3. **Escala Física Real em Milímetros (	oSceneUnits)**:
   - Todas as dimensões de estilo no construtor gráfico (meno_dimension_graphics.ms) passam obrigatoriamente por 	oSceneUnits, convertendo milímetros reais para as unidades de sistema ativas na cena.
   - Implementado o suporte geométrico ao extensionGap: as linhas de extensão agora iniciam em extStart = projectedPoint + extDir * gapExtScene, gerando o espaçamento regulamentar entre o objeto e a linha de chamada.

4. **Prioridade Visual Estrita no Viewport**:
   - Estabelecida a seguinte hierarquia visual para a cor de aramado (wirecolor) no viewport:
     1. **1º Órfã (Alerta crítico)**: Vermelho (color 230 70 70) — sobrepõe qualquer outro estado.
     2. **2º Manual Válida (Override auditável)**: Âmbar (color 245 166 35).
     3. **3º Normal / Medida**: Branco neutro (color 245 245 245).
   - O material renderizável neutro permanece inalterado para todas as cotas, assegurando que avisos de viewport nunca poluam renders.

5. **Atualização Rápida In-Place e Índice (1)$**:
   - Desenvolvido o método updateDimensionFast: atualiza nós existentes via setKnotPoint e atualiza a propriedade de texto do TextPlus sem destruir nem recriar nós de cena.
   - Implementado índice reverso de consulta (1)$ baseado em Dictionary #string nativo do MAXScript (nimHandle -> #(controllers)), garantindo alta escalabilidade ao manipular grandes conjuntos de cotas.

6. **Interface Compacta e Reancoragem Interativa com Snap**:
   - O painel principal (meno_main_panel.ms) foi redimensionado para altura máxima de 640 px e reestruturado com subRollout nativo com rollouts recolhíveis: Ferramentas de Cota, Auditoria de Medidas, Gestão de Âncoras e Diagnóstico de Ambiente.
   - Os botões "Reancorar Ponto A" e "Reancorar Ponto B" utilizam pickPoint snap:#3D, permitindo ao usuário clicar com precisão com snaps ativados em vértices, arestas ou faces da geometria, recalculando automaticamente a âncora e a medida.

7. **Separação de Schemas**:
   - Ameno.DataSchemaVersion = "3" aplicado aos nós controladores e Custom Attributes.
   - Ameno.GraphicSchemaVersion = "1" aplicado exclusivamente aos nós visuais de desenho (lines, label, marker).

## Consequências

### Positivas
- Mover ou rotacionar paredes e blocos no viewport atualiza instantaneamente as cotas associadas sem latência perceptível.
- Deletar um objeto marca visualmente a cota afetada em vermelho imediato no viewport e atualiza os alertas do painel.
- O histórico de Undo do usuário permanece limpo e previsível; editar estilos suporta Ctrl+Z e Ctrl+Y perfeitamente.
- O painel de interface se adapta ergonomicamente a qualquer resolução a partir de 1366 × 768 px sem cortes ou barras de rolagem desnecessárias.
- Desempenho comprovado: 100 cotas são atualizadas em lote em aproximadamente 2 segundos.

### Limitações conhecidas
- Como os nós são atualizados in-place via updateDimensionFast, nós danificados ou deletados acidentalmente pelo usuário requerem uma chamada a epairDimensions() ou ebuildDimension(), o que já é tratado de forma transparente pelo fallback interno.
