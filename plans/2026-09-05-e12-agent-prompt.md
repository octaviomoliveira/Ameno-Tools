# Prompt para o agente executor E12-R

Você vai recuperar a interação da cota contínua do Ameno Tools, MAXScript para 3ds Max 2026. Leia integralmente `PLAN.md` e `plans/2026-09-05-e12-executor-runbook.md` antes de editar. Esse runbook é o contrato de execução, prevalecendo sobre textos antigos de duplo clique, confirmação no abort e reinício automático após commit.

Repositório: https://github.com/octaviomoliveira/Ameno-Tools
Branch que contém o plano: feature/e12-continuous-dimension.
Worktree existente: D:\Ameno\_worktrees\e12-continuous.
Base de código auditada: 0859164 (inclui d8ce420).
Versão instalada por solicitação do usuário: ba55d95. NÃO presumir que a instalação coincide com HEAD.

Primeiro confira git status, histórico recente, regras AGENTS.md disponíveis e processos Max. Se houver alterações concorrentes, preserve-as e use worktree própria. Crie branch de recuperação a partir do plano atualizado, conforme R0. Não instale a branch atual automaticamente e não faça reset/revert global para voltar ao instalado.

Execute SOMENTE R0 inicialmente. Precisamos de um rastro dos eventos reais no ba55d95 que mostre onde a finalização para. Os testes anteriores de commit injetam #empty e não comprovam picking nem MouseTool. Prepare um probe opt-in/restaurável e o roteiro de reprodução do runbook; se não puder obter teste real, entregue o probe e aguarde o gate, sem afirmar uma causa runtime por inspeção estática.

Depois que R0 estiver comprovado, siga R1 a R6, um incremento por vez e respeitando gates manuais. Reaproveite matemática H/V, CA/âncoras E10.7, estilos e gráficos; corrija a orquestração. Não reescreva WPF E11, renderers ou o núcleo de âncoras. Leia as funções afetadas e seus chamadores antes de editá-las.

Comportamento-alvo: cliques em referências válidas adicionam pontos, preview inteiro tem baseline comum, primeiro clique vazio confirma N-1 cotas e encerra o comando. Esc/direito cancelam somente draft. Nenhum timer/duplo clique e nenhuma confirmação via onAbort. Alinhado fica indisponível antes da coleta nesta recuperação. Não depender do HUD flutuante.

Pontos que não podem ser esquecidos: offset independente de snap; ID>=1; posição original 3D preservada; estação duplicada rejeitada antes de append; hover e clique usam resolvedor comum; falha do raycast nunca equivale a vazio; preview não disputa snap; rollback inclui nó alocado antes de factory retornar; stop/cleanup idempotente e sem apagar resultado confirmado.

O runbook contém contratos, tabela de transições, arquivos permitidos, exemplos numéricos, testes negativos, isolamento do runner, critérios de instalação e aceitação. Não invente APIs de projeção/eventos de teclado: valide assinatura na documentação Autodesk e em microteste. Não converta a tarefa para mouseTrack/C++ antes de provar limitação do MouseTool.

Ao final de cada entrega atualize PLAN e checklist, registre logs/evidências e faça commit/push apenas da sua branch, sem force push. Informe o que foi comprovado, o que está apenas proposto, versão instalada e próximo gate. Não altere expectativas de testes só para fazê-los passar; documente mudanças legítimas de contrato. Não faça merge para main sem aprovação final.
