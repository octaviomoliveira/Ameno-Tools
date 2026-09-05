# E12-B — layout matemático compartilhado H/V

Data: 2026-09-05. Estado: **aprovado em Batch**.

## Entrega

`ameno_dimension_chain_math.ms` introduz um cálculo puro de cadeia, sem criação de nós, callbacks ou Undo. Para cada referência P[i], calcula sua estação no eixo de medição e a projeta na mesma linha de cota:

    s[i] = dot(P[i] - O, u)
    h = dot(cursor - O, v)
    Q[i] = O + u*s[i] + v*h

No modo horizontal, todos os Q compartilham `cursor.y`; no vertical, todos compartilham `cursor.x`. As referências são ordenadas espacialmente pela estação, preservando `sourceIndex` para que a camada de interação mantenha a ordem de clique. Estações coincidentes são rejeitadas em vez de gerar segmentos de comprimento zero. A medida de cada intervalo é projetada e convertida pelo fator de unidades fornecido/atual da cena.

O módulo já contém a base alinhada fixa pelos dois primeiros pontos, mas o comportamento oblíquo não foi aprovado nesta etapa e permanece gate E12-D. E12-C deve consumir os layouts H/V prontos; não duplicar suas fórmulas no MouseTool ou no graphics.

## Evidência

`tests/maxscript/test_e12_chain_math.ms`: **29/29 PASS** no 3ds Max 2026.3 Batch isolado. O log confirmou source e bootstrap na worktree E12. Cobertura: baseline H/V com pontos desalinhados, três intervalos, afastamento negativo, ordem invertida, identidade do índice de origem, estação coincidente, escala de unidade inválida/válida e ausência de novos objetos na cena.

`tools/validate-package.ps1`: pacote estruturalmente válido. Não houve instalação ou teste visual.
