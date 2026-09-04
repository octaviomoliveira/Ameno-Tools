# ADR 0009 — Valores medidos, arredondados e manuais com marcador viewport-only

- Estado: aceita para o MVP
- Data: 2026-09-04

## Contexto

Em projetos de plantas humanizadas e arquitetura no 3ds Max, é frequente a necessidade de ajustar o valor exibido de uma cota (por exemplo, arredondar 19,58 m para 19,60 m ou substituir por uma cota executiva ou texto descritivo).
Entretanto, a prática comum de apagar o texto original e sobrescrever manualmente gera sérios riscos de erro em obra e incoerência técnica quando o modelo 3D é modificado.

Para a Etapa E6, o Ameno Dimensions estabelece a regra de ouro:
**Valor medido ≠ valor exibido. A medida física real nunca é apagada.**

Além disso:
1. Cotas alteradas devem ser visualmente identificáveis pelo artista na viewport através de cor âmbar e um marcador [M].
2. O render de produção (Corona primário, V-Ray secundário) NUNCA deve exibir o marcador [M] nem alterar os materiais do render.
3. A cota deve manter auditoria do delta (displayMillimeters - measuredMillimeters) e recalcular o delta se a geometria for alterada.
4. O usuário deve poder reverter para o valor físico real a qualquer momento.

## Decisão

- **Schema CA Version 2**:
  Expandir a definição AmenoDimensionCADef (`attribID:#(0x414d454e, 0x44494d31)`) para `version:2` com os campos:
  - manualValueMm (#float): valor numérico manual em milímetros.
  - manualText (#string): texto descritivo manual.
  - manualReason (#string): justificativa/motivo do override para auditoria.
  - lastMeasuredMm (#float): snapshot da última medição física real.
  - lastDeltaMm (#float): snapshot da divergência entre exibido e medido.
- **Modos de Valor**:
  - #measured: exibe a medida física pura calculada da projeção dos nós. Sem marcador, delta = 0.
  - #rounded: arredonda a medida física por incremento configurável (ex: 1 cm, 5 cm, 10 cm). Se o arredondamento divergir da medida real, ativa estado modificado e marcador.
  - #manualNumeric: exibe o valor numérico arbitrário em milímetros. O delta é continuamente recalculado em relação à geometria atual.
  - #manualText: exibe texto arbitrário preservando a cota geométrica.
- **Marcador Viewport-Only**:
  - Quando a cota estiver alterada (isManual == true), instancia um nó TextPlus AMENO_MARK_* com texto [M] ao lado do rótulo da cota.
  - O nó marcador recebe `renderable = false` e camada AMENO_COTAS. Isso garante que renderizadores de produção (Corona, V-Ray, Arnold, etc.) ignorem o objeto durante a geração de geometria de render.
  - O marcador recebe wirecolor = (color 245 166 35) (âmbar).
  - A linha e o texto principal da cota recebem wirecolor = (color 245 166 35) para sinalização visual na viewport, mantendo seu material original intacto (render sem alteração).
- **Inspeção e Reparo**:
  - inspectDimension valida se uma cota modificada possui seu marcador [M]. Retorna #missing_marker se ausente ou #unexpected_marker se indevido, permitindo reparo automático via repairDimension.
- **Interface e Histórico**:
  - Painel principal (AmenoMainPanelRollout) expandido com inspeção reativa via callback #selectionSetChanged (#ameno_selection).
  - Botões para aplicar modos e Restaurar Medido.
  - Todas as operações encapsuladas em blocos undo atômicos no MaxScript.

## Consequências

### Positivas

- Segurança técnica total: a medida real em milímetros nunca é perdida.
- O artista bate o olho na viewport e sabe exatamente quais cotas foram alteradas e qual o delta.
- Render limpo garantido por `renderable = false` e materiais inalterados.
- Auditoria e reversibilidade instantâneas.

### Limitações conhecidas

- Nesta etapa do MVP, o painel foca na seleção ativa da viewport. Relatórios tabulares em massa de auditoria de cena (ex: listar todas as cotas alteradas em uma tabela) poderão ser adicionados em fatias futuras de refinamento.
