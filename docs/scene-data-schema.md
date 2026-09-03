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
| `manualTextEnabled` | boolean | indica sobrescrita |
| `manualText` | string | texto opcional |
| `lastMeasuredMm` | float | último valor canônico válido |
| `lastFormattedText` | string | fallback visual/diagnóstico |
| `lineNodeRef` | node | spline derivada |
| `textNodeRef` | node | TextPlus derivado |
| `markNodeRef` | node | geometria opcional |
| `createdWith` | string | versão inicial |
| `lastUpdatedWith` | string | versão mais recente |

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
| `textSizeMode` | enum | world, pixels, printMm |
| `textSize` | float | valor conforme modo |
| `lineSizeMode` | enum | world, pixels, printMm |
| `lineThickness` | float | espessura |
| `lineColor` | color | cor lógica |
| `terminalType` | enum | tick, arrow, dot, none |
| `terminalSize` | float | tamanho |
| `extensionGap` | float | folga inicial |
| `extensionOvershoot` | float | prolongamento |
| `textGap` | float | distância texto/linha |
| `textFitRule` | enum | inside, outsideWhenNeeded, alwaysOutside |
| `zOffset` | float | separação do plano |
| `materialRole` | string | chave para provider |

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
