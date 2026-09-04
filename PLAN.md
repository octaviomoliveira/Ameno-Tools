# Plano compartilhado — Ameno Tools

> Fonte de continuidade do projeto para qualquer pessoa ou agente (incluindo Antigravity).
> Atualizado: 2026-09-03

## Regra de trabalho

Cada solicitação nova deve atualizar este arquivo **antes de encerrar a tarefa**:

1. registrar o pedido no histórico;
2. mover itens concluídos para **Concluído** com evidência (arquivo, teste ou commit);
3. atualizar **Em andamento** e **Próximo passo**;
4. quando a decisão for duradoura, criar ou atualizar uma ADR em `docs/decisions/`.

Não substituir o histórico: acrescentar uma entrada datada. O plano corrente é este arquivo; `plans/` guarda marcos e handoffs mais detalhados.

## Objetivo do MVP

Entregar, no 3ds Max 2026, o primeiro módulo do Ameno Tools: **Ameno Dimensions**. Ele deve criar cotas rápidas, editáveis e persistentes para plantas humanizadas, com apresentação controlável e uma saída de render independente para composição.

## Concluído

- Repositório Git local criado e fundação `0.0.1` do pacote `ApplicationPlugins` estruturada.
- Pacote carregado e smoke testado no 3ds Max 2026.3.
- Ação `Ameno Tools` e painel inicial registrados; bootstrap modular e validação de pacote incluídos.
- Modelo de dados inicial para cotas, estilos, referências e valores medidos/arredondados/manuais documentado.
- Regras decididas para `AMENO_COTAS`, geometria renderizável, render separado de cotas e preservação do Beauty, LightMix e Render Elements existentes.
- Fluxo do valor manual definido: a substituição não altera a medida real, é persistida no dado da cota e aparece em âmbar apenas na viewport.
- Editor de estilo especificado com inspiração na edição direta do TextPlus: fonte, tamanho, linhas, espessuras e tipos de seta com prévia.
- Estratégia de render definida: Corona como referência obrigatória; V-Ray CPU como segundo adapter oficial; V-Ray GPU separado e experimental até ser validado.
- Escopo inicial definido para 3ds Max 2026; compatibilidade 2021–2025 será avaliada após o MVP estar estável.

## Em andamento

- Implementar o primeiro caminho completo de criação de cota: coleta de três pontos, cálculo e representação gráfica persistente.
- Criar e controlar automaticamente as layers `AMENO_COTAS` e `AMENO_SYSTEM`.

## Próximo passo executável

Criar o serviço de layers e o comando de cota linear no MAXScript, iniciando com três cliques: origem, destino e posição da linha de cota. Validar criação, desfazer/refazer, salvamento e reabertura da cena no 3ds Max 2026.

## Decisões que ainda exigem validação

- Versões mínimas de Corona e V-Ray disponíveis no ambiente real.
- Se a interface inicial será somente em português ou já bilíngue.
- Serviço/visibilidade do repositório Git remoto e política de acesso.
- Licença e modelo de distribuição.

## Histórico de solicitações

| Data | Pedido / decisão | Situação | Evidência |
| --- | --- | --- | --- |
| 2026-09-03 | Estruturar Ameno Tools e iniciar pelo módulo de cotas para plantas humanizadas. | Concluído na fundação | `README.md`, `docs/`, pacote `0.0.1` |
| 2026-09-03 | Usar layer exclusiva, manter Beauty/LightMix intactos e renderizar cotas separadamente para composição. | Decidido e documentado | `docs/decisions/0002-*`, `0003-*` |
| 2026-09-03 | Permitir valores manuais auditáveis com alerta visível somente no viewport. | Decidido e documentado | `docs/decisions/0004-*`, `docs/manual-overrides.md` |
| 2026-09-03 | Priorizar 3ds Max 2026; Corona primeiro, com compatibilidade planejada para V-Ray. | Decidido e documentado | `docs/decisions/0005-*`, `0006-*` |
| 2026-09-03 | Centralizar o projeto em `D:\Ameno\_tools` e manter planos atualizados para continuidade via Antigravity. | Em execução | Este plano e `plans/` |

## Como retomar sem contexto

1. Leia este arquivo e depois `plans/2026-09-03-foundation.md`.
2. Execute `git status` e confirme que o estado local é o esperado.
3. Leia `README.md` e a documentação diretamente ligada ao próximo passo.
4. Implemente uma unidade pequena, teste no 3ds Max e registre o resultado aqui.

