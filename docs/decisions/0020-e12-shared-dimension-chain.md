# ADR 0020 — E12: linha comum e confirmação de cadeia

Data: 2026-09-05. Estado: proposta para implementação incremental; gates pendentes.

## Contexto

A E12 em db88f1b cria segmentos independentes e usa regras diferentes no preview e commit. Uma translação igual aplicada a pontos médios diferentes não produz uma linha comum. Ausência de snap não prova clique vazio. Os testes atuais não cobrem o resultado geométrico do fluxo interativo.

## Decisão proposta

Tratar sequência como conjunto com base fixa e referências originais. Um calculador projeta todas as referências na mesma linha; preview, criação e reconstrução consomem esse resultado. Selecionar vértices acrescenta intervalos provisórios; primeiro clique realmente vazio posiciona e confirma todo o conjunto em uma transação. Não usar temporização de duplo clique para finalizar.

Preservar cotas individuais e núcleo gráfico. Persistir identidade/base da cadeia e vínculo dos membros, com migração retrocompatível a definir e testar antes de uso em produção. Não substituir âncoras reais por pontos projetados. O modo alinhado usa um eixo fixo, não uma polilinha de eixos por segmento.

## Consequências

Exige integrar layout de cadeia à atualização de âncoras e persistência, não apenas ao MouseTool. H/V são implementados e validados antes do oblíquo; instalação e merge aguardam testes e aprovação interativa. Detalhes, limites, esquema proposto e gates: [plano E12](../../plans/2026-09-05-e12-continuous-revit-implementation.md).
