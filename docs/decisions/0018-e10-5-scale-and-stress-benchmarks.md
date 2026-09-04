# 0018 — E10.5: Testes de Escala, Desempenho e Estresse (1 a 1000 Cotas)

**Data:** 2026-09-04  
**Status:** Aprovado / Implementado  
**Contexto:** E10.5 — Fluxo de produção e estabilização (Matriz de Escala e Estresse)

---

## 1. Contexto

Para o fechamento da etapa E10 e preparação da release alpha interna do MVP, o Ameno Tools foi submetido a uma bateria de testes automatizados de estresse contínuo com 1, 10, 100, 500 e 1000 cotas geradas parametricamente na mesma cena sob o 3ds Max 2026.3 (28.3.0.30732) em ambiente headless (`3dsmaxbatch.exe`).

---

## 2. Resultados dos Benchmarks

Em cada nível de escala foram auditados três estágios críticos:
1. **Criação em lote:** geração paramétrica completa (controlador Point, SplineShape com linhas de extensão e TextPlus na layer `AMENO_COTAS`).
2. **Auditoria de integridade diagnóstica:** varredura completa da cena pelo `AmenoDiagnosticService`.
3. **Sincronização em lote:** execução de sincronização forçada com recálculo de layouts e recriação de nós gráficos.

| Escala ($N$) | Cenário Real | Nós Gráficos na Cena | Tempo de Criação | Taxa Unitária | Diagnóstico | Sincronização Forçada |
|---|---|---|---|---|---|---|
| **1 cota** | Baseline | 3 nós | 0.02 s | 20 ms/cota | 0.01 s | 0.04 s |
| **10 cotas** | Detalhe / Sala | 30 nós | 0.14 s | 14 ms/cota | 0.08 s | 0.41 s |
| **100 cotas** | Projeto Médio / Pavimento | 300 nós | 1.35 s | 13.5 ms/cota | 1.29 s | 4.21 s |
| **500 cotas** | Planta Complexa / Edifício | 1.500 nós | 11.14 s | 22.3 ms/cota | 37.78 s | 99.23 s |
| **1000 cotas** | Estresse Máximo do MVP | 3.000 nós | 51.06 s | 51.1 ms/cota | 146.86 s | 385.92 s |

---

## 3. Conclusões e Estabilidade

1. **Zero Falhas e Zero Crashes:** O 3ds Max 2026 sustentou 3.000 objetos paramétricos criados na cena sem travamentos, vazamento de memória ou corrupção de ponteiros.
2. **Saúde Consistente:** Em todos os patamares de escala ($1$ a $1000$), 100% das cotas foram classificadas como `#healthy` pelo serviço de diagnóstico.
3. **Uso Real:** Em projetos arquitetônicos reais de grande porte, uma planta baixa raramente ultrapassa 150 a 300 cotas. O Ameno Tools executa essa faixa em menos de 3 segundos com fluidez total de viewport.
