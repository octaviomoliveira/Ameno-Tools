# E12 — Planejamento da finalização e picking

Pedido: pesquisar Revit/SketchUp e avaliar viabilidade no 3ds Max. Apenas planejamento; nenhum código ou pacote alterado nesta entrega.

## Base e evidências

- Instalação ativa: ba55d95. Branch: 957fa67, incluindo tentativa d8ce420. Não confundir as duas bases.
- Revit: seleciona duas ou mais referências destacadas, apresenta preview e posiciona a dimensão com clique afastado. Fonte: https://help.autodesk.com/cloudhelp/2026/ENU/Revit-DocumentPresent/files/GUID-E0FB313E-CE57-4741-9EF5-6747BBA3BDDB.htm
- SketchUp: inferências identificam pontos; início, fim e clique de posicionamento criam uma dimensão associativa. Não é o mesmo fluxo multirreferência do Revit. Fonte: https://help.sketchup.com/en/sketchup/adding-text-labels-and-dimensions-model
- LayOut: cotas sucessivas podem repetir afastamento por duplo clique. É um produto/fluxo distinto; não importar esse gesto para o Ameno inadvertidamente. Fonte: https://help.sketchup.com/en/layout/marking-dimensions
- MaxScript MouseTool oferece movimento, pontos, abort e retorno #stop. Os eventos incluem o pressionamento inicial e liberações posteriores: não equivalem simplesmente a um evento por clique físico. Fonte: https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/Scripted-Mouse-Tools/GUID-619AF4D3-A347-4155-943B-707D421BC460.html
- mouseTrack é alternativa com callback e snap; possui limitações de plano de construção e interseção. Não trocar de API antes de medir a falha. Fonte: https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Interacting-with-the-3ds-Max/MouseTrack/GUID-0A4CD125-5CA0-42DA-B2D6-B8FDF511CCE8.html

A documentação descreve comportamento e APIs, não revela a implementação interna dos produtos. É viável construir interação equivalente no Max, com serviços próprios de referência e cadeia; não significa obter semântica BIM automaticamente.

## Falhas concretas e hipóteses

1. ba55d95: snap em nó inelegível retorna antes do raycast; classificador converte snap não resolvido em ambiguous. Pode bloquear posicionamento sobre grid, preview ou cotas. Caminho comprovado no código; falta provar que explica o clique do usuário.
2. ba55d95: calculateChainLayout/commitChain recusam Alinhado. O painel sincroniza o modo da cota simples com a contínua. A ferramenta não deve aceitar coleta em modo que não consegue confirmar.
3. Após commit, ba55d95 reinicia coleta; clicar novamente no vazio retorna needsMoreReferences. Pode parecer travamento mesmo com cotas já criadas. Separar diagnóstico de ausência de criação e ausência de saída do comando.
4. HUD contém confirmação desabilitada e depende de interação com janela durante captura do mouse. Remover essa dependência do fluxo proposto.
5. Hover atual só atualiza layout: não resolve nem apresenta explicitamente candidato de referência. A causa da perda do marcador nativo ainda exige reprodução.
6. d8ce420 confirma em onAbort: risco de tratar Esc como confirmação, pois o callback não prova que veio do botão direito. Não incorporar sem discriminação comprovada.
7. Testes que injetam kind:#empty validam commit, mas pulam picking/eventos reais. PASS anterior não constitui aprovação manual.

## Incrementos propostos

### C1 — Diagnóstico reproduzível

Registrar de forma temporária evento/contador, estado, modo, snapHit/nó, resultado do picking, número de referências, entrada/saída de commit e exceção. Uma cena descartável H/V, dois vértices e um clique vazio, comparando snap ligado/desligado, grid e preview. Registrar código instalado por hash. Gate: identificar onde o fluxo para; não atribuir causa somente à imagem.

### C2 — Contrato de entrada e saída

Validar modo antes de iniciar. Vértice elegível acrescenta referência; geometria sem referência orienta; espaço vazio posiciona e confirma com pelo menos duas referências. Snap inelegível não é prova de falha de picking: continuar investigação do alvo; falha real permanece ambígua e nunca confirma. Offset vem da interseção do cursor com plano de cotagem, separado do ponto de snap. Normalizar eventos físicos com evidência, sem timer de duplo clique.

Proposta ajustada ao relato: após confirmar com sucesso, sair do comando e liberar mouse; próxima cadeia começa pelo botão/atalho. Esc/direito cancelam somente o rascunho. Cotagem já confirmada é removida por Undo. Gate: clique único confirma e encerra; falha explica motivo e preserva draft; nenhuma confirmação em Esc.

### C3 — Hover e referências

Um resolvedor comum para movimento e clique, tolerância em pixels e leitura da malha avaliada E10.7. Prévia visual do candidato sem adicionar referência. Previews não devem disputar o picking/snap. Validar marcador nativo; se insuficiente, marcador próprio de viewport com cleanup, sem geometria renderizável. Confirmar significado de referência de outra cota: se for ponta de cota existente, resolver até a âncora original; não ancorar no TextPlus ou em spline temporária. Gate: mesmo candidato destacado e selecionado, com zoom e após segundo ponto.

### C4 — Confirmação observável e interface

Reaproveitar matemática H/V, gráficos, TextPlus, estilos e transação. Separar sucesso/erro da limpeza do comando; preservar cotas confirmadas ao encerrar; rollback somente dos objetos da tentativa. Substituir HUD flutuante por instruções e contagem na viewport/status; não prometer teclas sem suporte demonstrado. Gate: N-1 cotas, Undo/Redo único, falha no segundo segmento limpa somente tentativa, saída sem captura residual.

### C5 — Gate real e continuidade

Cobrir evento até criação, além de testes matemáticos. Usuário valida H/V, cliques rápidos, grid, sobre preview, cancelamento, nova ativação e hover. Só então retomar Alinhado e persistência de cadeia do plano anterior. Se MouseTool mostrar limitação reproduzível que impede contrato, fazer spike pequeno de mouseTrack; C++/SDK só após demonstrar necessidade. Não reescrever núcleo por suposição.

## Estado

Pesquisa e plano concluídos. Diagnóstico runtime, implementação e gate manual pendentes. Não instalar nem mesclar esta entrega documental.
