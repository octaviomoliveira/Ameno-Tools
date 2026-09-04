# 0017 — E10.4: Cenas-Fixture, Serviço de Diagnóstico e Guia de Uso

**Data:** 2026-09-04  
**Status:** Aprovado / Implementado  
**Contexto:** E10.4 — Fluxo de produção e estabilização (Fixtures, Diagnóstico e Documentação)

---

## 1. Contexto

A etapa E10.4 tem como objetivo solidificar o ambiente de testes e documentação do produto com:
1. Criação de geradores de cenários de teste controlados e reproduzíveis (fixtures arquitetônicas e de escala);
2. Um serviço centralizado de diagnóstico e auditoria de cena (`AmenoDiagnosticService`), capaz de inspecionar integridade de nós, saúde gráfica, distribuição de modos e âncoras;
3. Um manual completo de uso (`docs/user-guide.md`) orientado ao usuário final (arquitetos, modeladores e artistas 3D).

---

## 2. Decisões Técnicas

### 2.1 Serviço de Diagnóstico de Cena (`ameno_diagnostic_service.ms`)
- Implementado como singleton `AmenoDiagnosticService` carregado no bootstrap.
- A função `generateReport()` varre todos os controladores de cotas na cena e calcula:
  - Total de cotas ativas;
  - Integridade gráfica via `inspectDimension` (saudáveis, parciais, sem gráficos);
  - Distribuição por modo de cotagem (alinhada, horizontal, vertical);
  - Distribuição por tipo de âncora (mundial, nó A, nó B, ambos);
  - Presença de cotas órfãs com suas causas específicas;
  - Presença de valores manuais/overrides auditáveis;
  - Status e capacidades do renderer atualmente ativo.
- O relatório formatado é exposto via runtime (`AmenoApp.printDiagnosticReport()`) e acionado diretamente pela interface no botão `Relatório de Diagnóstico`.

### 2.2 Cenas-Fixture Reproduzíveis
- `tests/fixtures/create_fixture_architecture_plan.ms`:
  Gera uma planta baixa completa com 4 paredes e pilar central, configurando automaticamente cotas alinhadas, horizontais, verticais, com âncoras reativas e sobrescrita manual.
- `tests/fixtures/create_fixture_scale.ms`:
  Gerador paramétrico de $N$ cotas (10 a 1000) distribuídas ordenadamente, servindo de base para os testes de estresse da E10.5.

### 2.3 Guia de Uso Completo (`docs/user-guide.md`)
- Documento em português cobrindo o ciclo de vida completo da ferramenta:
  - Instalação e ativação da interface;
  - Fluxo de criação com snap em três cliques;
  - Diferenciação prática entre os modos Alinhada, Horizontal e Vertical;
  - Operações em lote (unidade, precisão, modo) e Bake de âncoras;
  - Diagnóstico e reparo de cotas órfãs;
  - Render Separado de Cotas com máscara transparente e integração de compositing no Photoshop.

---

## 3. Consequências
- A equipe de QA e desenvolvimento ganha ferramentas determinísticas para geração de cenários de teste complexos.
- Usuários e suporte ganham um diagnóstico de 1 clique para auditar cenas corrompidas ou com cotas perdidas.
- A documentação atende aos critérios do gate de MVP para a versão alpha interna.
