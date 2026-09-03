# Arquitetura técnica

## Direção

O Ameno Dimensions será implementado como um domínio independente da interface e da representação gráfica. Essa separação permite substituir splines/TextPlus por um objeto C++ no futuro sem mudar o significado salvo na cena.

## Camadas

```text
Interface / comandos / mouse tool
              │
              ▼
      Casos de uso do módulo
              │
              ▼
  Modelo da cota e regras de cálculo
        │                 │
        ▼                 ▼
Persistência         Representação
Custom Attributes    spline/TextPlus/material
        │                 │
        └──────┬──────────┘
               ▼
       Adaptadores do 3ds Max
```

### Core do Ameno Tools

- bootstrap e descoberta de módulos;
- versão;
- logger;
- registro/limpeza de callbacks;
- transações e Undo;
- configurações do usuário;
- localização;
- diagnóstico comum;
- migrações.

### Domínio Dimensions

- `DimensionDefinition`;
- `AnchorDefinition`;
- `WorkPlane`;
- `DimensionStyle`;
- `MeasurementService`;
- `UnitService`;
- `TextFormatter`;
- `GeometryLayoutService`;
- `IntegrityService`.

### Adaptadores

- mouse tool do Max;
- scene nodes;
- Custom Attributes;
- splines renderizáveis;
- TextPlus;
- material provider por renderizador;
- layer manager;
- render output adapter por renderizador;
- LightMix/composite adapter;
- Node Event callbacks;
- pre-render callback;
- rollout/floater ou painel futuro.

## Estratégia de versões

O MVP é desenvolvido, otimizado e testado no 3ds Max 2026. Pode usar APIs dessa versão quando elas melhorarem a experiência, a robustez ou a velocidade de entrega. Não existe, nesta fase, a obrigação de permanecer dentro da interseção de APIs do Max 2021–2026.

A portabilidade futura é preservada por fronteiras que já fazem sentido para o produto:

- regras de medição e formatação não conhecem widgets do Max;
- dados de cena têm schema próprio e versionado;
- menu, mouse tool, viewport, TextPlus, layers e render vivem em adaptadores/serviços;
- o ponto de entrada é uma ação MacroScript na categoria `Ameno Tools`;
- nenhuma comparação de versão é adicionada até existir uma segunda implementação real.

O Max 2025 mudou completamente o sistema de menus. Se a portabilidade alcançar versões 2021–2024, o lançamento do painel continuará comum, mas o registro opcional de menu terá um adapter legado. Essa possibilidade não entra no caminho crítico do MVP.

Se surgir um núcleo compilado em C++ no futuro, builds por SDK/release serão avaliados separadamente. A estratégia completa está em [compatibility.md](compatibility.md).

## Estado da ferramenta de três cliques

```text
IDLE
  └─ iniciar ─► WAIT_POINT_A
                  ├─ Esc/direito ─► CANCEL
                  └─ clique ─► WAIT_POINT_B
                                  ├─ mover ─► preview de medida
                                  ├─ Esc/direito ─► CANCEL
                                  └─ clique ─► WAIT_OFFSET
                                                  ├─ mover ─► preview completo
                                                  ├─ Esc/direito ─► CANCEL
                                                  └─ clique ─► COMMIT ─► IDLE/REPEAT
```

Durante o preview, nenhuma cota permanente deve existir. A preferência é desenhar a prévia por callback de viewport. Se limitações de texto ou hit-testing impedirem isso, podem ser usados nós temporários claramente identificados, com limpeza garantida em `abort`, erro, reset e troca de cena.

O commit cria controlador, representação e atributos em um único bloco de Undo nomeado `Ameno: criar cota`.

## Matemática de layout

Considere um plano com origem `O`, eixos ortonormais `X` e `Y`, e normal `N`.

As âncoras mundiais `A` e `B` são projetadas no plano:

```text
P(p) = p - N * dot(p - O, N)
```

Para cota alinhada:

```text
u = normalize(P(B) - P(A))
v = normalize(cross(N, u))
d = dot(P(C) - P(A), v)
LA = P(A) + v * d
LB = P(B) + v * d
valor = length(P(B) - P(A))
```

`C` é o terceiro clique. O sinal de `d` escolhe o lado da cota.

Para horizontal, `u = X`; para vertical, `u = Y`. O valor é a magnitude da projeção no eixo correspondente. O layout mantém as linhas auxiliares ligadas às âncoras, mas a linha principal usa os pontos projetados no eixo da cota.

Casos degenerados:

- se `A` e `B` coincidirem dentro da tolerância, bloquear commit;
- se a projeção horizontal/vertical for zero, mostrar preview inválido;
- se o afastamento for quase zero, aplicar o afastamento mínimo do estilo;
- se o texto não couber entre terminais, movê-lo para fora conforme regra do estilo.

## Leitura do texto

O texto deve permanecer legível em relação à câmera/plano:

1. projetar a direção da linha no eixo horizontal da câmera;
2. se a direção visual estiver invertida, girar o texto 180 graus;
3. preservar alinhamento central e baseline;
4. aplicar deslocamento perpendicular configurado;
5. opcionalmente mover o texto para fora quando não houver espaço.

## Unidades determinísticas

O valor interno é obtido em unidades de sistema. A apresentação não deve depender apenas de `units.formatValue`, pois estilos diferentes podem exigir unidades e precisão próprias.

Processo:

1. ler `units.SystemScale` e `units.SystemType`;
2. converter o valor da cena para milímetros canônicos;
3. converter milímetros para a unidade do estilo;
4. arredondar somente para exibição;
5. aplicar zeros finais, separador decimal, prefixo e sufixo;
6. nunca usar o valor arredondado como nova origem de cálculo.

O valor canônico e o texto formatado devem ser mantidos separados.

## ValuePresentationService

O serviço resolve o que será exibido sem alterar a medição:

```text
measuredMm = MeasurementService(...)

switch valueMode
  measured      → displayMm = measuredMm
  rounded       → displayMm = roundToIncrement(measuredMm, incrementMm)
  manualNumeric → displayMm = manualValueMm
  manualText    → displayText = manualText

deltaMm = displayMm - measuredMm
formattedText = TextFormatter(displayMm, style)
```

`measuredMm` nunca é sobrescrito pelo valor informado. A reconstrução da cota atualiza medição e delta, preservando `manualValueMm`.

### Arredondamento previsível

Arredondamento usa incremento explícito em milímetros canônicos e uma regra documentada de midpoint. Não deve depender da quantidade de casas decimais exibidas nem acumular arredondamentos sucessivos.

### Manual numérico versus texto livre

`manualNumeric` mantém unidade, precisão, prefixo e sufixo do estilo. `manualText` ignora formatação e é reservado para casos como `VER LEVANTAMENTO`. A UI oferece numérico primeiro.

## ViewportOverrideOverlay

Advertências manuais são uma camada de feedback, não geometria renderizável.

O overlay usa callback de viewport para desenhar cor âmbar e marcador junto à cota. Alternativamente, helpers não renderizáveis podem ser usados se o desenho por Graphics Window não satisfizer hit-testing/legibilidade. Em ambos os casos:

- nenhum material de render é alterado;
- `AMENO_COTAS` mantém sua aparência final;
- o overlay consulta `valueMode` e a preferência global;
- cota fora da viewport não gera trabalho;
- redraw não recalcula medição;
- o callback é registrado uma vez e removido no shutdown.

O desenho deve ser compatível com viewport clara/escura e oferecer cor configurável. O marcador `M` acompanha o texto, mas não entra no TextPlus renderizável.

### Seleção e diagnóstico

Manter índice de `dimensionId` por `valueMode` permite:

- selecionar todas as manuais;
- enquadrar a próxima;
- restaurar medido em lote com confirmação;
- exportar relatório de medido, exibido, delta e motivo;
- contar overrides sem varrer toda a geometria.

## Âncoras

### Mundo

Armazena a posição mundial. Não acompanha objetos.

### Local ao objeto

Armazena referência ao nó, ponto local e última posição mundial válida.

```text
worldPoint = localPoint * objectTransform
```

Esse modo acompanha transformação do objeto sem depender de nome ou índice de vértice.

### Helper

Armazena referência a um Point Helper criado ou escolhido pelo usuário. É indicado quando se deseja controle explícito e animação.

### Superfície, futuro

Pode armazenar face, coordenadas baricêntricas e assinatura de topologia. Mesmo assim deverá ser marcado como potencialmente frágil quando a pilha de modificadores alterar a topologia.

## Nós de cena

Cada cota do MVP usa:

- um controlador não renderizável;
- uma shape com linhas de extensão, linha principal e terminais compatíveis;
- um TextPlus;
- opcionalmente uma shape/mesh adicional quando o terminal exigir preenchimento.

O controlador é a raiz. Apagar o controlador remove sua representação; apagar apenas um filho aciona reparo/reconstrução.

Uma cota não deve depender do nome dos nós. IDs e referências são a identidade; nomes servem apenas para inspeção humana.

## Layers

O `LayerService` resolve ou cria:

```text
AMENO_COTAS   representação renderizável
AMENO_SYSTEM  controladores, estilos e metadados não renderizáveis
```

O nome é uma convenção visível, não a única identidade. Ao criar ou reconstruir uma cota, o serviço valida propriedade, resolve conflitos, adiciona somente os nós gerados e restaura a layer corrente anterior. Assim, objetos criados depois pelo usuário não caem acidentalmente em `AMENO_COTAS`.

Se a layer for renomeada, a referência registrada continua válida. Se for apagada, o diagnóstico recria uma layer gerenciada e reatribui os nós. Estados explícitos de visibilidade, freeze e lock são respeitados.

## Atualização associativa

### Índice reverso

Em memória, manter:

```text
nodeHandle -> conjunto de dimensionIds dependentes
```

Ao abrir uma cena, o índice é reconstruído por varredura dos controladores.

### Eventos

Callbacks de transformação, geometria, exclusão, Undo/Redo, abertura, merge e render apenas marcam cotas como `dirty`. Eles não devem reconstruir geometria pesada diretamente.

### Debounce

Uma fila processa as cotas sujas após pequena janela, aproximadamente 100–250 ms. Isso evita dezenas de atualizações enquanto o usuário arrasta um objeto.

### Proteções

- trava de reentrada;
- deduplicação por ID;
- suspensão durante carga/merge/reset;
- atualização em lote com redraw desativado;
- callbacks derivados ignoram os próprios nós gráficos;
- falha em uma cota não impede atualização das demais;
- pre-render força flush da fila;
- shutdown remove callbacks do processo.

### Undo

Ações iniciadas pelo usuário usam Undo nomeado. Reconstrução de geometria derivada usa `undo off` para não poluir o histórico. Após Undo/Redo de uma transformação, os eventos marcam novamente a cota para atualização.

## Representação e render

O domínio solicita uma descrição geométrica neutra:

- segmentos;
- polígonos de terminais;
- posição, rotação e escala do texto;
- material lógico;
- plano e elevação.

O adaptador converte isso em spline/TextPlus/material. Essa fronteira permitirá um renderer adapter ou objeto C++ sem reescrever as regras de cálculo.

Perfis previstos:

- `scene-units`: espessuras e texto em unidades do mundo;
- `screen-pixels`: tamanhos derivados da câmera ortográfica e resolução;
- `print-mm`: tamanhos derivados do formato físico e DPI;
- `overlay-pass`: material e visibilidade próprios para composição.

## Pipeline de saída

> A arquitetura abaixo descreve a evolução futura. O MVP usa o serviço independente `RenderCotasService` e não configura Beauty, LightMix ou Render Elements.

## RenderCotasService do MVP

Entrada:

```text
camera
frame
resolution/pixelAspect
crop/region
outputPath
fileFormat
selectionMode: all | selected
background: transparent
```

Fluxo:

1. validar câmera, resolução, layer e cotas órfãs;
2. atualizar todas as cotas dirty;
3. capturar um snapshot mínimo do estado que será alterado;
4. isolar `AMENO_COTAS` ou somente os controladores selecionados;
5. garantir material de annotation e alpha transparente;
6. executar o render para arquivo próprio;
7. restaurar o snapshot em caminho de sucesso, erro ou cancelamento;
8. validar que o arquivo foi criado e informar dimensões/path.

O serviço não dispara o render normal da planta e não edita o Render Element Manager.

### Snapshot protegido

Guardar somente o necessário:

- visibilidade/renderability das layers/nós afetados;
- layer corrente;
- câmera ativa;
- frame;
- output path e flags temporárias;
- region/crop quando alterado;
- environment/alpha quando necessário;
- material override temporário, se usado;
- trava contra callbacks recursivos.

Evitar alterar configurações globais quando os argumentos do comando `render` permitirem informar câmera, frame, resolução e output diretamente.

### Pixel-perfect

O serviço calcula uma assinatura da saída:

```text
cameraId + projection + transform + frame + width + height + pixelAspect + crop
```

Essa assinatura pode ser salva ao lado do overlay ou em metadados/arquivo auxiliar. O diagnóstico compara a assinatura com a configuração atual da planta e alerta quando o overlay não encaixará exatamente.

### Materiais

O renderer adapter do MVP tem responsabilidade pequena: fornecer material gráfico que preserve cor e alpha. Ele não integra LightMix ou AOV. Se nenhum adapter existir, o app oferece um material genérico e avisa sobre limitações de exposição/tone mapping.

## StyleEditorService

O editor trabalha sobre um `StyleDraft`, não diretamente nos nós da cena.

```text
estilo persistido
      ↓ snapshot
StyleDraft ← controles/preview
      ↓ aplicar
validação → persistência → mark dirty → rebuild
```

Durante sliders e escolha de fontes, somente o preview é atualizado imediatamente. Cotas selecionadas podem receber preview throttled opcional. O commit final agrupa a alteração em um único Undo; Cancel restaura o snapshot sem reconstrução desnecessária.

### TextPlusAdapter

Responsabilidades:

- criar/reparar o TextPlus filho;
- definir string formatada;
- aplicar fonte e variante;
- aplicar bold/italic;
- aplicar size e tracking;
- manter alinhamento central;
- configurar interpolação suficiente para a resolução;
- calcular bounding box real do texto;
- informar fonte ausente ou substituída.

O TextPlus continua sendo representação derivada. Editá-lo manualmente não altera o estilo oficial; o diagnóstico oferece `Reaplicar estilo` ou, futuramente, `Capturar aparência`.

### Conversão pixels → mundo

Para câmera ortográfica, o perfil calcula `worldPerPixel` a partir do enquadramento e da resolução. O tamanho visual escolhido no editor vira:

```text
textSizeWorld = textSizePx * worldPerPixel * fontCalibration
lineWidthWorld = lineWidthPx * worldPerPixel
terminalSizeWorld = terminalSizePx * worldPerPixel
```

`fontCalibration` corrige diferenças de altura aparente entre famílias e é calculado pela bounding box real do TextPlus. O valor fica em cache por fonte/variante.

### LineStyleAdapter

Converte o estilo em Renderable Spline:

- espessura da linha principal;
- espessura das extensões, vinculada ou independente;
- cap/segmentos quando aplicável;
- cor/material;
- gap inicial e overshoot;
- elevação Z.

Presets Fina/Normal/Forte são valores relativos ao perfil de saída, não números fixos em unidades do mundo.

### TerminalGeometryFactory

Gera terminais espelhados e consistentes:

- `tick`: segmento inclinado com ângulo configurável;
- `closedArrow`: triângulo preenchido;
- `openArrow`: dois segmentos;
- `dot`: círculo/disco;
- `none`: sem terminal.

O layout `auto` usa a largura real do texto, gaps e tamanho dos terminais. Se não houver espaço interno, move setas e/ou texto para fora conforme a regra do estilo.

### Atualização em massa

Ao salvar um estilo:

1. validar fonte e valores;
2. persistir uma nova revisão do estilo;
3. localizar cotas vinculadas pelo índice de estilo;
4. marcá-las dirty;
5. reconstruir em lote com redraw suspenso;
6. emitir um único redraw e uma entrada de Undo.

Sliders não podem disparar rebuild integral de dezenas de cotas em cada pixel de movimento.

### Falha segura

Restauração é obrigatória. O código mantém snapshot e flag de operação ativa; callbacks de reset, open, cancel e exceções chamam a mesma rotina idempotente de restore. Uma segunda chamada de restore não deve causar efeitos.

O `RenderOutputService` recebe uma política neutra:

```text
deliveryChannel: nativeBeauty | activeLightMix | both | externalComposite
outputMode: integrated | separate | integratedAndSeparate | viewportOnly
elementKind: mask | annotationRGBA
occlusionMode: sceneDepth | alwaysOnTop
alphaMode: straight | premultiplied
```

Ele seleciona um `IRenderOutputAdapter` compatível com o renderer ativo.

### Integrated

As cotas precisam aparecer no canal de entrega, que pode ser o Beauty nativo ou um LightMix. `Aparece no RGB original` não é condição suficiente para aprovação.

### Mask

O adapter atribui seleção ou Object ID aos nós Ameno e cria/reutiliza `AMENO_COTAS_MASK`. IDs existentes do usuário não podem ser sobrescritos sem mapeamento e restauração.

### Annotation RGBA

Contém cor real, alpha e antialiasing. Quando o renderer suporta AOV/LPE/texmap adequado no mesmo passe, o adapter o configura. Essa capacidade é declarada e testada por renderer; nunca presumida.

### Segundo passe

Fallback renderer-agnostic:

1. atualizar todas as cotas;
2. salvar visibilidade, materiais, câmera, resolução, frame, paths e color management;
3. isolar a saída de anotação;
4. renderizar RGBA transparente;
5. restaurar todo o estado mesmo após erro ou cancelamento;
6. impedir recursão do pre-render.

O segundo passe é exibido claramente no painel e não pode modificar permanentemente a cena.

## LightMix

LightMix é tratado como canal de entrega e não como sinônimo de Beauty. O adapter deve detectar:

- se há LightMix ativo;
- quais LightMix/LightSelect elements existem;
- qual canal o usuário considera final;
- se self-illumination é agrupada separadamente;
- se a composição final pode receber overlay sem novo render.

As cotas não devem ser tratadas como luzes. Em V-Ray, LightMix cria canais de Environment e Self Illumination; em Corona, materiais luminosos também podem participar de LightSelect/LightMix. Se usarmos emissão para deixar a cota independente da iluminação, ela pode cair em Self Illumination e ser alterada pelo LightMix. Por isso, a estratégia padrão é `overlay after LightMix`:

```text
Beauty/LightMix final
        +
AMENO_COTAS_RGBA
        =
preview/saída achatada opcional
```

O Ameno mantém o overlay original separado e pode gerar uma prévia composta. Assim o LightMix continua livre para mudar intensidades, cores e ambientes sem alterar a identidade gráfica das cotas.

### Integração direta opcional

Se um renderer oferecer um canal de composição que permita incluir o overlay depois do LightMix sem registrá-lo como luz, o adapter pode habilitar `integrated`. Esse caminho só será marcado como suportado após teste de:

- cor constante;
- alpha correto;
- denoise;
- tone mapping;
- bloom/glare;
- salvamento em EXR/CXR;
- render interativo e render farm.

### Capacidades do adapter

Cada adapter declara:

- mask no mesmo passe;
- RGBA no mesmo passe;
- overlay após LightMix;
- flatten opcional do canal final;
- alpha antialiasing;
- IPR e render farm;
- formatos e limitações.

Se o modo pedido não existir, o app propõe Mask ou segundo passe antes do render.

## Render Element Manager

O MAXScript pode consultar, adicionar, habilitar e configurar paths de Render Elements. O Ameno procura primeiro um element próprio existente e nunca chama operações globais que apaguem elements do usuário.

Regras:

- nomes reservados começam com `AMENO_`;
- classe, nome e configuração são validados;
- elements do usuário não são removidos, renomeados ou reordenados;
- troca de renderer invalida somente o adapter, não as cotas;
- paths e tokens são validados antes do batch render;
- diagnóstico informa se a saída é Mask, RGBA ou segundo passe.

## Materiais

O estilo referencia um papel lógico, como `annotation-dark` ou `annotation-light`. Um provider escolhe a implementação:

- material genérico compatível;
- Corona;
- V-Ray;
- Arnold;
- material fornecido pelo usuário.

Sem provider específico, a geometria continua existindo e o diagnóstico informa que o material precisa ser atribuído.

## Performance

Metas iniciais:

- criação perceptualmente instantânea;
- atualização de 100 cotas abaixo de 1 segundo;
- nenhum callback de redraw reconstruindo toda a cena;
- no máximo dois ou três nós renderizáveis por cota;
- atualização em lote com um redraw final;
- cache de estilo resolvido e material.

Se 500 cotas excederem limites aceitáveis, considerar uma shape agregada por layer/câmera ou objeto nativo C++.

## Erros e recuperação

- referência removida: usar última posição e marcar órfã;
- nó gráfico removido: reconstruir a partir do controlador;
- estilo removido: aplicar fallback sem perder style ID original;
- versão futura: bloquear edição destrutiva e preservar dados;
- erro durante criação: limpar preview e não registrar Undo parcial;
- callbacks duplicados: remover pelo ID antes de registrar;
- arquivo sem Ameno: abrir normalmente, mantendo geometria visível quando possível.

## Segurança e portabilidade

- não salvar callbacks persistentes com código executável na cena;
- não executar strings vindas de propriedades da cena;
- Custom Attributes versionados e migrados explicitamente;
- valores enumerados validados contra lista permitida;
- paths externos nunca são confiáveis por padrão;
- diagnóstico informa dados incompatíveis sem apagá-los;
- bake oferece saída independente do plugin.

## Referências oficiais

- [MAXScript no 3ds Max](https://help.autodesk.com/cloudhelp/2026/ENU/MAXDEV-Overview/files/overview/MAXDEV_Overview_overview_maxscript_html.html)
- [Scripted Mouse Tools](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/GUID-80E8ADDC-F8A0-46F4-B909-4F39D5F37A29.html)
- [Custom Attributes](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Custom-Attributes/GUID-ADFD29E4-9751-4F55-98CC-F7C721C9AEE2.html)
- [Callbacks e Change Handlers](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/GUID-1BE2E978-72CF-495C-81D6-2B36E2C4FFC7.html)
- [Unidades](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Interacting-with-the-3ds-Max/Units/GUID-DB50F450-C3D1-47A5-98A2-A34601710034.html)
- [Undo](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Language-Reference/Names-Literal-Constants-and/Context-Expressions/GUID-C8517C4A-A75F-4D4E-A058-BE3EE61A2A11.html)
