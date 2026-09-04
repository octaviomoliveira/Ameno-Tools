# ADR 0006 — Corona primeiro, V-Ray compatível

- Estado: aceita
- Data: 2026-09-03

## Contexto

O uso imediato é no Corona, mas o produto também deve atender usuários de V-Ray. O MVP gera as cotas em um render separado, sem modificar Beauty, LightMix ou Render Elements. Isso permite compartilhar domínio, geometria, interface e orquestração, deixando somente materiais, alpha, color pipeline e execução atrás de adapters.

V-Ray possui engines CPU e GPU com matrizes de recursos diferentes. Tratá-las como uma implementação única criaria uma promessa sem teste.

## Decisão

- Corona é o renderer de referência e gate obrigatório do MVP;
- V-Ray CPU é o segundo adapter oficial e deve obedecer ao mesmo contrato de saída;
- V-Ray GPU passa por qualificação independente e começa como experimental;
- o botão `Renderizar Cotas` não modifica LightMix nem Render Elements;
- isolamento por renderability/layer é o caminho base comum;
- Render Selected/Render Mask nativo é apenas otimização possível;
- o overlay padrão usa cor gráfica previsível para composição, independente da iluminação;
- sem adapter aprovado, o render é bloqueado com diagnóstico em vez de usar fallback silencioso.

## Consequências

### Positivas

- o problema real em Corona define a qualidade do produto;
- V-Ray reaproveita quase todo o módulo;
- diferenças de renderer não entram nos dados das cotas;
- LightMix continua fora do caminho crítico;
- resultados incorretos de alpha ou cor não são disfarçados como compatibilidade.

### Custos

- cada adapter precisa de cenas-fixture e testes de render;
- versões mínimas só podem ser prometidas depois de validação real;
- V-Ray GPU pode exigir comportamento ou material específico;
- integração no mesmo passe permanece fora do MVP.

## Evidência do primeiro construtor gráfico

Na validação do usuário em 03/09/2026, a geometria da E3 apareceu no Arnold, apareceu no V-Ray quando havia luz na cena e foi removida integralmente pelo comando de limpeza. Uma cena Corona sem luz exibiu diferença entre Beauty e a saída/máscara observada; isso é compatível com o objetivo de separar o overlay e não deve ser corrigido adicionando luzes automaticamente. A matriz de saída sem luz será validada somente na E9, com material/geometry proxy do adapter e restauração transacional.
