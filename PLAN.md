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
- Validação manual no 3ds Max concluída: painel `Ameno Tools 0.0.1 · Max 2026` aberto e Corona identificado como `suportado`.
- E1 implementada e aprovada em testes automatizados no 3ds Max 2026.3: `Preparar esta cena` cria infraestrutura idempotente, protege conflitos de layer e restaura a layer corrente.
- Cópia de desenvolvimento atualizada em `ApplicationPlugins` e validada em processo separado do 3ds Max Batch.
- E2 implementada e aprovada em testes automatizados no 3ds Max 2026.3: layout de cota alinhada no plano XY, conversão canônica para milímetros, arredondamento por incremento e formatação determinística.
- E2 não cria objetos, layers, callbacks ou histórico de Undo; ela recebe pontos e devolve dados prontos para a representação gráfica da E3.
- Ação `Ameno Tools` e painel inicial registrados; bootstrap modular e validação de pacote incluídos.
- Modelo de dados inicial para cotas, estilos, referências e valores medidos/arredondados/manuais documentado.
- Regras decididas para `AMENO_COTAS`, geometria renderizável, render separado de cotas e preservação do Beauty, LightMix e Render Elements existentes.
- Fluxo do valor manual definido: a substituição não altera a medida real, é persistida no dado da cota e aparece em âmbar apenas na viewport.
- Editor de estilo especificado com inspiração na edição direta do TextPlus: fonte, tamanho, linhas, espessuras e tipos de seta com prévia.
- Estratégia de render definida: Corona como referência obrigatória; V-Ray CPU como segundo adapter oficial; V-Ray GPU separado e experimental até ser validado.
- Escopo inicial definido para 3ds Max 2026; compatibilidade 2021–2025 será avaliada após o MVP estar estável.

## Em andamento

- E1 está **pronta para validação visual manual** no 3ds Max, definida em `plans/2026-09-03-mvp-incremental.md`.
- A E2 foi concluída por solicitação explícita, pois é um núcleo puro e independente da cena.
- A E3 permanece bloqueada até o gate visual da E1 ser aprovado.

## Próximo passo executável

Validar visualmente a **E1 — Preparar a cena** após recarregar o 3ds Max: abrir o Ameno, usar `Preparar esta cena` em uma cena vazia ou cópia segura, confirmar `Cena preparada`, repetir o comando, verificar `AMENO_COTAS` e `AMENO_SYSTEM` no Layer Explorer e salvar/reabrir. O comando não deve alterar renderer, unidades, câmera, objetos do usuário nem a layer corrente. Após esse gate, iniciar a E3 com os dados já fornecidos pela E2.

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
| 2026-09-03 | Centralizar o projeto em `D:\Ameno\_tools` e manter planos atualizados para continuidade via Antigravity. | Concluído | Repositório Git íntegro em `D:\Ameno\_tools`; origem removida após confirmação de vazio |
| 2026-09-03 | Confirmar o pacote aberto no 3ds Max e dividir o funcionamento do plugin em etapas pequenas. | Concluído no planejamento; E1 é a próxima implementação | `plans/2026-09-03-mvp-incremental.md` |
| 2026-09-03 | Seguir para E1 e registrar cada etapa em Markdown e GitHub. | E1 implementada, testada em Batch e pronta para validação visual; commit local `92bddd1`; GitHub bloqueado porque nenhum remoto está configurado | `Contents/scripts/ameno/core/ameno_scene_setup.ms`, `.test-output/*e1*` |
| 2026-09-03 | Conectar `github.com/octaviomoliveira/Ameno-Tools` e seguir para E2. | `origin/main` publicado; E2 implementada e aprovada em Batch e no pacote instalado; commits `70c0fb2` e `78e54d7` publicados | `Contents/scripts/ameno/core/ameno_dimensions_math.ms`, `.test-output/*e2*` |

## Como retomar sem contexto

1. Leia este arquivo e depois `plans/2026-09-03-mvp-incremental.md`.
2. Execute `git status` e confirme que o estado local é o esperado.
3. Leia `README.md` e a documentação diretamente ligada ao próximo passo.
4. Implemente uma unidade pequena, teste no 3ds Max e registre o resultado aqui.
