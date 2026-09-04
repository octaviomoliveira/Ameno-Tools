# ADR 0008 — Persistência com Custom Attributes versionados e integridade de cena

- Estado: aceita para o MVP
- Data: 2026-09-04

## Contexto

Nas etapas E3 e E4, os dados da cota (pontos, afastamento, unidade) foram armazenados temporariamente via User Defined Object Properties (`getUserPropVal` / `setUserPropVal`) no nó Point controlador (`AMENO_DIM_CTRL_*`). Para a etapa E5, as cotas precisam se comportar como entidades confiáveis de produção:
1. Sobreviver a salvar e reabrir arquivos `.max` sem depender de nomes de nós.
2. Permitir abertura do arquivo em instâncias do 3ds Max onde o Ameno Tools não esteja instalado, sem gerar erros de "Missing DLLs".
3. Manter a identidade estável caso o usuário renomeie nós ou camadas.
4. Manter Undo/Redo atômico (1 única entrada por criação/remoção/reparo).
5. Permitir inspecionar e reparar filhos gráficos acidentalmente deletados na viewport sem duplicar controladores ou perder dados.

## Decisão

- Criar a definição de Custom Attributes `AmenoDimensionCADef` (`attributes AmenoDimensionData`) com `attribID:#(0x414d454e, 0x44494d31)` ('AMEN', 'DIM1') e `version:1`.
- Utilizar apenas tipos de parâmetros nativos do 3ds Max (`#integer`, `#string`, `#point3`, `#float`), garantindo persistência binária no `.max` e abertura transparente em qualquer máquina sem o plugin.
- Anexar a CA ao nó controlador Point na camada de sistema (`AMENO_SYSTEM`), mantendo o nó oculto e fora de render.
- Manter espelhamento nas User Properties (`Ameno.Kind`, `Ameno.DimensionId`, etc.) para interoperabilidade e compatibilidade retroativa com dados gravados nas etapas anteriores.
- Implementar identificação baseada em `dimensionId` (não no nome dos nós), permitindo renomeação livre pelos usuários sem perda de integridade.
- Adicionar rotinas `inspectDimension` e `repairDimension`: quando um filho visual (`lines` ou `label`) for deletado acidentalmente, o Ameno é capaz de restaurar a representação gráfica utilizando os dados íntegros do controlador.
- Registrar callbacks idempotentes de ciclo de vida (`#filePostOpen`, `#systemPostNew`, `#postSceneReset`) com ID `#ameno_lifecycle` para reidratar contagens e sincronizar diagnósticos ao abrir ou reiniciar cenas.

## Consequências

### Positivas

- Cenas salvas preservam todos os parâmetros geométricos e de formatação com total fidelidade.
- Arquivos `.max` abrem em qualquer 3ds Max sem dependências quebradas.
- Filhos gráficos deletados podem ser recuperados instantaneamente pelo painel com um clique em "Reparar cotas".
- Undo e Redo permanecem estritamente atômicos.

### Limitações conhecidas

- Nesta primeira fatia da E5, a clonagem de cotas via ferramentas padrão do 3ds Max ainda reutiliza o `dimensionId` gravado na CA até a implementação do evento de clone dedicado.
- A migração de schema suporta a transição de UserProps legadas para CA versão 1; schemas futuros (ex: E6 com overrides manuais) serão adicionados aditivamente.
