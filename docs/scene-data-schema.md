# Formato dos dados de cena

Status: proposta inicial. O esquema será congelado somente após a prova técnica.

## Objetivos

- persistir sem depender de nomes;
- sobreviver a save/open, merge e rename;
- permitir migração de versão;
- preservar última aparência quando referências falharem;
- permitir implementação MAXScript hoje e C++ amanhã;
- manter arquivos abertos mesmo sem o plugin.

## Grafo de nós

```text
AMENO_SYSTEM layer
├─ AMENO_DOC_<guid>                  metadados do documento
└─ AMENO_STYLE_<guid>                um nó por estilo

AMENO_COTAS layer
└─ AMENO_DIM_<short-guid>            controlador
   ├─ AMENO_DIM_LINES_<short-guid>   spline renderizável
   ├─ AMENO_DIM_TEXT_<short-guid>    TextPlus
   └─ AMENO_DIM_MARK_<short-guid>    opcional
```

As layers e os nomes ajudam o usuário, mas não são identidade. A identidade é o GUID persistido.

## Documento

Campos sugeridos:

| Campo | Tipo | Função |
|---|---|---|
| `schemaVersion` | integer | versão do esquema do documento |
| `documentId` | string | GUID |
| `createdWith` | string | versão do Ameno |
| `lastSavedWith` | string | última versão que atualizou dados |
| `defaultStyleId` | string | estilo usado em nova cota |
| `activeWorkPlane` | enum/string | XY, active grid ou camera |
| `activeCameraHandle` | integer/ref | câmera principal |
| `projectName` | string | nome opcional |
| `lastValidationUtc` | string | auditoria mais recente |
| `dimensionLayerName` | string | último nome conhecido da layer de cotas |
| `systemLayerName` | string | último nome conhecido da layer interna |
| `deliveryChannel` | enum | Beauty, LightMix ou composição externa |
| `outputMode` | enum | integrada, separada, ambas ou viewport |
| `elementKind` | enum | mask ou annotationRGBA |
| `renderAdapterId` | string | adapter usado na configuração |

## Cota

| Campo | Tipo | Função |
|---|---|---|
| `schemaVersion` | integer | versão do registro |
| `dimensionId` | string | GUID imutável |
| `dimensionType` | enum | aligned, horizontal, vertical |
| `state` | enum | ok, dirty, orphan, unsupported |
| `planeMode` | enum | worldXY, activeGrid, camera |
| `planeOrigin` | point3 | origem persistida |
| `planeXAxis` | point3 | eixo horizontal |
| `planeYAxis` | point3 | eixo vertical |
| `planeNormal` | point3 | normal |
| `anchorA` | composite | primeira âncora |
| `anchorB` | composite | segunda âncora |
| `offset` | world float | distância assinada da linha |
| `styleRef` | node/string | referência e GUID do estilo |
| `valueMode` | enum | measured, rounded, manualNumeric, manualText |
| `manualValueMm` | float | valor numérico informado pelo usuário |
| `manualText` | string | texto livre avançado |
| `overrideReason` | string | motivo opcional, como Levantamento |
| `overrideUpdatedUtc` | string | última alteração manual |
| `overrideAuthor` | string | identificação opcional |
| `roundingIncrementMm` | float | incremento quando local à cota |
| `lastMeasuredMm` | float | último valor canônico válido |
| `lastDisplayMm` | float | último valor numérico exibido |
| `lastDeltaMm` | float | exibido menos medido |
| `lastFormattedText` | string | fallback visual/diagnóstico |
| `lineNodeRef` | node | spline derivada |
| `textNodeRef` | node | TextPlus derivado |
| `markNodeRef` | node | geometria opcional |
| `createdWith` | string | versão inicial |
| `lastUpdatedWith` | string | versão mais recente |

## Preferências de viewport

| Campo | Tipo | Função |
|---|---|---|
| `showManualOverrides` | boolean | mostra advertências de valor manual |
| `manualOverrideColor` | color | cor viewport-only, padrão âmbar |
| `manualOverrideMarker` | enum | M, pencil, dot ou none |
| `showOverrideDelta` | boolean | mostra delta junto ao marcador |

Essas preferências não controlam materiais e não fazem parte do render.

## Âncora

| Campo | Tipo | Função |
|---|---|---|
| `kind` | enum | world, objectLocal, helper |
| `nodeRef` | node | referência quando aplicável |
| `nodeHandleSnapshot` | integer | ajuda diagnóstica, não identidade definitiva |
| `localPoint` | point3 | posição no espaço local |
| `worldFallback` | point3 | última posição mundial válida |
| `label` | string | descrição opcional |
| `integrity` | enum | ok, missing, unsupported |

Se `nodeRef` ficar inválida, `worldFallback` mantém a cota visível e permite reancoragem.

## Estilo

| Campo | Tipo | Função |
|---|---|---|
| `styleId` | string | GUID |
| `name` | string | nome do usuário |
| `parentStyleId` | string | herança futura |
| `unit` | enum | mm, cm, m, sceneDisplay |
| `precision` | integer | casas decimais |
| `trimTrailingZeros` | boolean | remove zeros finais |
| `decimalSeparator` | enum | locale, comma, dot |
| `prefix` | string | texto anterior |
| `suffix` | string | texto posterior |
| `fontName` | string | fonte desejada |
| `fontVariant` | string | variante/família selecionada |
| `fontFallback` | string | fallback quando ausente |
| `bold` | boolean | negrito |
| `italic` | boolean | itálico |
| `tracking` | float | espaçamento global do TextPlus |
| `textSizeMode` | enum | world, pixels, printMm |
| `textSize` | float | valor conforme modo |
| `textMaskEnabled` | boolean | fundo/máscara atrás do texto |
| `textMaskPadding` | float | margem da máscara |
| `textColor` | color | cor do texto |
| `lineSizeMode` | enum | world, pixels, printMm |
| `lineThickness` | float | espessura |
| `extensionThicknessMode` | enum | linked ou independent |
| `extensionThickness` | float | espessura independente |
| `lineColor` | color | cor lógica |
| `terminalType` | enum | tick, arrow, dot, none |
| `terminalSize` | float | tamanho |
| `terminalAngle` | float | ângulo do traço/seta |
| `terminalPosition` | enum | auto, inside, outside |
| `extensionGap` | float | folga inicial |
| `extensionOvershoot` | float | prolongamento |
| `textGap` | float | distância texto/linha |
| `textFitRule` | enum | inside, outsideWhenNeeded, alwaysOutside |
| `zOffset` | float | separação do plano |
| `materialRole` | string | chave para provider |

## Configuração de render

| Campo | Tipo | Função |
|---|---|---|
| `deliveryChannel` | enum | nativeBeauty, activeLightMix, both ou externalComposite |
| `lightMixElementRef` | maxObject/string | LightMix escolhido pelo usuário |
| `lightMixElementName` | string | fallback para diagnóstico |
| `outputMode` | enum | integrated, separate, integratedAndSeparate, viewportOnly |
| `elementKind` | enum | mask ou annotationRGBA |
| `elementName` | string | nome gerenciado pelo Ameno |
| `outputPathPattern` | string | path com tokens permitidos |
| `fileFormat` | enum | EXR, PNG ou formato suportado |
| `alphaMode` | enum | straight ou premultiplied |
| `occlusionMode` | enum | sceneDepth ou alwaysOnTop |
| `compositePreview` | boolean | mostrar overlay sobre canal final |
| `flattenFinalCopy` | boolean | gerar cópia achatada opcional |
| `independentFromLightMix` | boolean | impedir alteração pelos grupos de luz |
| `includeInReflections` | boolean | reflexão |
| `includeInRefractions` | boolean | refração |
| `castShadows` | boolean | sombra projetada |
| `receiveShadows` | boolean | sombra recebida |
| `affectGI` | boolean | contribuição de GI |
| `motionBlur` | boolean | motion blur |
| `depthOfField` | boolean | profundidade de campo |
| `adapterId` | string | adapter renderer-specific |
| `adapterVersion` | integer | versão da configuração |

Paths não serão executados como código. Tokens fora da whitelist serão rejeitados, e paths relativos serão resolvidos junto à saída principal ou ao projeto.

## Custom Attributes

Regras:

- definições possuem `version:`;
- mudanças aditivas são preferíveis;
- rename usa mapeamento explícito;
- remoções só ocorrem após migração para nova definição;
- dados desconhecidos são preservados quando possível;
- nenhuma string de campo será executada como MAXScript;
- referências derivadas podem ser reconstruídas e não são fonte oficial.

## Merge e duplicação

Ao fazer merge:

1. escanear IDs duplicados;
2. se os nós forem cópias independentes, gerar novos IDs;
3. se estilo com mesmo ID e conteúdo idêntico já existir, reutilizar;
4. se mesmo ID tiver conteúdo diferente, duplicar estilo com novo ID e nome `Conflito`;
5. reconstruir índice reverso;
6. validar referências e render nodes.

Clonar uma cota dentro da cena deve gerar novo `dimensionId` no evento de clone, mas preservar o `styleId`.

## Migrações

Cada migração é uma função pura quando possível:

```text
v1 -> v2 -> v3
```

Regras:

- nunca pular silenciosamente uma versão;
- backup/cópia recomendado antes de migração destrutiva;
- log por cota com sucesso ou erro;
- versão futura abre em modo somente leitura;
- testes mantêm cenas-fixture de todas as versões publicadas.
