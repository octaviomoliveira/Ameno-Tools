# ADR 0001 — MAXScript primeiro

Status: aceita
Data: 2026-09-03

## Contexto

O Ameno Dimensions precisa de interação no viewport, acesso à cena, criação de shapes/TextPlus, unidades, Undo, persistência e callbacks. Ainda estamos validando o fluxo e não sabemos se um objeto nativo será necessário.

## Decisão

Construir o primeiro MVP em MAXScript, organizado em módulos e empacotado no formato oficial `ApplicationPlugins`.

Manter o domínio, o esquema de dados e a descrição geométrica separados dos adaptadores do Max. Isso permite substituir partes por C++ posteriormente.

## Consequências positivas

- ciclo de prototipação curto;
- distribuição inicial simples;
- integração direta com recursos do Max;
- menor custo para testar cenas reais;
- possibilidade de inspecionar e corrigir dados durante desenvolvimento.

## Consequências negativas

- menor desempenho que C++;
- desenho e manipuladores de viewport menos sofisticados;
- maior cuidado com callbacks e globais;
- proteção limitada de propriedade intelectual;
- UI nativa mais simples.

## Gatilhos para revisar a decisão

- atualização de 500 cotas excede a meta acordada;
- necessidade confirmada de hit-testing/manipuladores próprios;
- impossibilidade de manter aparência visual estável com spline/TextPlus;
- associação de baixo nível à topologia torna-se requisito central;
- comercialização exige núcleo compilado.

## Alternativas rejeitadas por enquanto

- C++ desde o primeiro commit: custo prematuro e builds por versão;
- Python como núcleo: menos direto para esta interação específica;
- apenas pós-produção 2D: não resolve atualização dentro da cena;
- cotas como linhas sem metadados: não oferece associação, diagnóstico ou migração.
