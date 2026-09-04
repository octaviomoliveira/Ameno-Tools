# ADR 0010 — Sistema de Estilos Visuais e Editor de Cotas

- Estado: aceita para o MVP
- Data: 2026-09-04

## Contexto

Em projetos de plantas humanizadas e visualização arquitetônica, o padrão estético das cotas é essencial para a leitura do projeto e o nível de entrega visual.
Até a Etapa E6, o Ameno Dimensions gerava cotas com parâmetros gráficos fixos (Arial 20 pt, traço arquitetônico 45° e espessura única 1.5).

Para a Etapa E7, o projeto necessita de um sistema de estilos visuais flexível, profissional e persistente que:
1. Controle tipografia refinada através do objeto nativo `TextPlus` do 3ds Max 2026 (família tipográfica, negrito, itálico, tamanho em unidades de cena, tracking/kerning e afastamento da linha).
2. Permita controlar a espessura de renderização das linhas com atalhos de projeto (Fina 0.8 mm, Normal 1.5 mm, Forte 2.5 mm).
3. Disponibilize os 5 tipos canônicos de terminais de cota:
   - Traço Arquitetônico 45° (`#tick`)
   - Seta Fechada (`#arrowClosed`)
   - Seta Aberta (`#arrowOpen`)
   - Ponto / Losango (`#dot`)
   - Nenhum (`#none`)
4. Mantenha os terminais dentro da mesma `SplineShape` da linha de cota para não poluir a cena com nós extras e garantir render idêntico em Corona, V-Ray e Arnold.
5. Persista a biblioteca de estilos no próprio arquivo `.max` da cena, sem depender de arquivos de configuração externos ou pastas de usuário.
6. Permita atualização em lote de todas as cotas que utilizam um determinado estilo, com Undo atômico em um único passo no 3ds Max.
7. Ofereça um editor visual dedicado (`AmenoStyleEditorRollout`) e integração direta no painel principal.

## Decisão

- **Estrutura de Dados `AmenoStyleRecord`**:
  Definida com os campos: `styleId`, `name`, `fontName`, `fontSize`, `bold`, `italic`, `tracking`, `textGap`, `lineThickness`, `extensionOverhang`, `extensionGap`, `terminalType`, `terminalSize`.
- **Presets de Fábrica**:
  - *Arquitetônico* (Padrão): Arial 20 pt, Traço 45° (14 mm), Espessura 1.5 mm.
  - *Editorial*: Georgia 22 pt, Ponto (8 mm), Tracking 10.0, Espessura 1.0 mm.
  - *Técnico*: Arial 16 pt, Seta Fechada (16 mm), Espessura 1.2 mm.
- **Terminais Vetoriais na mesma Spline**:
  - A geração geométrica dos terminais ocorre dentro do método `addTerminals` em `AmenoDimensionGraphicsService`.
  - As geometrias de terminais (segmentos de traço, polígonos fechados de seta, polilinhas abertas e losangos) são criadas como sub-splines adicionais no nó `lineNode` (`SplineShape`).
  - Benefício técnico: herdam automaticamente o material emissivo da cota e a propriedade `render_thickness`, sem instanciar nós separados na hierarquia da cena.
- **Tipografia via TextPlus**:
  - Utilização da interface `textObject2` do TextPlus (`SetFont`, `SetBold`, `SetItalic`, `ResetString`, `AppendString`).
  - Obtenção da lista segura de fontes instaladas no Windows via classe .NET `System.Drawing.FontFamily`.
  - Fallback automático para "Arial" caso a fonte especificada não esteja presente no sistema.
- **Persistência de Estilos na Cena (.max)**:
  - Estilos são serializados em formato delimitado e gravados no `rootNode` da cena via UserProps (`Ameno.Styles`).
  - Ao abrir ou resetar uma cena (`#filePostOpen`, `#systemPostNew`, `#postSceneReset`), o runtime recarrega automaticamente os estilos da cena.
- **Atualização em Lote e Undo Atômico**:
  - Ao alterar e salvar um estilo existente pelo editor, o método `updateStyleAndRebuild` itera sobre todas as cotas da cena que referenciam aquele `styleId` e as reconstrói dentro de um bloco `undo "Ameno: atualizar estilo de cotas" on`.
  - Um único `Ctrl+Z` reverte a alteração de todas as cotas da cena simultaneamente.
- **Interface Visual**:
  - Rollout `AmenoStyleEditorRollout` com seletores de estilo, fontes do sistema, estilo de texto (negrito/itálico), spinners dimensionais, atalhos de espessura (0.8, 1.5, 2.5), seletor de terminais e botões de ação ("Atualizar Estilo (Em Lote)", "Aplicar às Selecionadas", "Novo...").
  - Painel principal (`AmenoMainPanelRollout`) enriquecido com botão "Editor de Estilos..." e dropdown para troca rápida de estilo da cota selecionada.

## Consequências

### Positivas

- Liberdade e rigor estético: o usuário pode personalizar fonte, espessuras e terminais com precisão milimétrica.
- Eficiência máxima na viewport e render: zero nós adicionais por cota (apenas controller, lineNode, textNode e markerNode se manual).
- Portabilidade total da cena: abrir o arquivo `.max` em qualquer outra máquina carrega os mesmos estilos da cena sem necessidade de copiar arquivos externos.
- Segurança de Undo: atualizações de estilo em dezenas ou centenas de cotas podem ser desfeitas com um único toque.

### Limitações conhecidas

- Se o arquivo de cena for aberto em um computador que não possua a fonte tipográfica usada pelo estilo (ex: fonte comercial de terceiros), o sistema efetua fallback gracioso para Arial sem travar nem gerar erro de script.