# ADR 0004 — Sobrescritas manuais auditáveis

Status: aceita
Data: 2026-09-03

## Contexto

Geometria de apresentação pode divergir do levantamento. Além disso, medidas reais podem produzir valores visualmente inconvenientes. O usuário precisa exibir um valor diferente sem perder a medição atual nem esquecer que tomou essa decisão.

## Decisão

Separar permanentemente:

- valor medido;
- valor exibido;
- modo de apresentação;
- delta;
- motivo opcional.

Os modos são measured, rounded, manualNumeric e manualText.

Valores manuais recebem advertência configurável apenas na viewport. Render e overlay usam a aparência normal do estilo.

## Razões

- evita perda da medida geométrica;
- permite representar levantamento/as-built;
- resolve arredondamento sem editar malha;
- reduz risco de esquecer overrides;
- permite diagnóstico e relatório;
- preserva aparência limpa da entrega.

## Consequências

- UI precisa mostrar medido e exibido juntos;
- schema passa a armazenar valor numérico canônico;
- viewport precisa de overlay não renderizável;
- alterações de geometria atualizam delta, não apagam manual;
- testes precisam provar que aviso nunca entra no render.

## Não decisão

Digitar uma cota não moverá paredes no MVP. Isso seria edição paramétrica da arquitetura e pertence a outro produto/escopo.
