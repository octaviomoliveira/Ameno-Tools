# E17 action inventory

This matrix records where every command from the functional E15 interface is
reachable after the E17 hierarchy change.

| E15 action | E17 location | Classification |
| --- | --- | --- |
| Cota individual | Cotar → Uma medida → Iniciar cotação | primary flow |
| Cota contínua | Cotar → Várias medidas → Iniciar cotação | primary flow |
| Preparar cena | Cotar → Mais ações | contextual |
| Atualizar estado | Cotar → Mais ações | contextual |
| Reparar tudo | Cotar → Mais ações | maintenance |
| Deletar seleção | Cotar → Mais ações | destructive, confirmed |
| Limpar órfãs | Cotar → Mais ações | destructive, confirmed |
| Deletar todas | Cotar → Mais ações | destructive, confirmed |
| Novo estilo | Aparência → Novo estilo | secondary |
| Duplicar estilo | Aparência → Mais | contextual |
| Excluir estilo | Aparência → Mais | destructive, confirmed |
| Atualizar estilos | Aparência → Mais | contextual |
| Salvar estilo | Aparência → Salvar alterações | primary |
| Aplicar selecionadas | Aparência → Aplicar estilo | contextual |
| Atualizar todas | Aparência → Aplicar estilo | contextual |
| Atualizar seleção | Revisar → Ler seleção atual | contextual |
| Aplicar alteração | Revisar → Aplicar alteração | primary |
| Restaurar medido | Revisar → Mais ações | contextual |
| Selecionar âncoras | Revisar → Mais ações | contextual |
| Escolher caminho | Exportar → Escolher arquivo | secondary |
| Renderizar | Exportar → Exportar PNG | primary |
| Atualizar renderer | Exportar → Mais ações | contextual |
| Abrir pasta | Exportar → Mais ações | contextual |
| Copiar caminho | Exportar → Mais ações | contextual |
| Copiar diagnóstico | Configuração | support |
| Logout | Configuração → Sair da conta | account |

No command was removed and no destructive action shares the red primary
emphasis.
