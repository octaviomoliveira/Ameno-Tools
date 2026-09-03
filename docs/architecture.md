# Arquitetura técnica

## Direção

O Ameno Dimensions será implementado como um domínio independente da interface e da representação gráfica. Essa separação permite substituir splines/TextPlus por um objeto C++ no futuro sem mudar o significado salvo na cena.

## Camadas

```text
Interface / comandos / mouse tool
              │
              ▼
      Casos de uso do módulo
              │
              ▼
  Modelo da cota e regras de cálculo
        │                 │
        ▼                 ▼
Persistência         Representação
Custom Attributes    spline/TextPlus/material
        │                 │
        └──────┬──────────┘
               ▼
       Adaptadores do 3ds Max
```

### Core do Ameno Tools

- bootstrap e descoberta de módulos;
- versão;
- logger;
- registro/limpeza de callbacks;
- transações e Undo;
- configurações do usuário;
- localização;
- diagnóstico comum;
- migrações.

### Domínio Dimensions

- `DimensionDefinition`;
- `AnchorDefinition`;
- `WorkPlane`;
- `DimensionStyle`;
- `MeasurementService`;
- `UnitService`;
- `TextFormatter`;
- `GeometryLayoutService`;
- `IntegrityService`.

### Adaptadores

- mouse tool do Max;
- scene nodes;
- Custom Attributes;
- splines renderizáveis;
- TextPlus;
- material provider por renderizador;
- Node Event callbacks;
- pre-render callback;
- rollout/floater ou painel futuro.

## Estado da ferramenta de três cliques

```text
IDLE
  └─ iniciar ─► WAIT_POINT_A
                  ├─ Esc/direito ─► CANCEL
                  └─ clique ─► WAIT_POINT_B
                                  ├─ mover ─► preview de medida
                                  ├─ Esc/direito ─► CANCEL
                                  └─ clique ─► WAIT_OFFSET
                                                  ├─ mover ─► preview completo
                                                  ├─ Esc/direito ─► CANCEL
                                                  └─ clique ─► COMMIT ─► IDLE/REPEAT
```

Durante o preview, nenhuma cota permanente deve existir. A preferência é desenhar a prévia por callback de viewport. Se limitações de texto ou hit-testing impedirem isso, podem ser usados nós temporários claramente identificados, com limpeza garantida em `abort`, erro, reset e troca de cena.

O commit cria controlador, representação e atributos em um único bloco de Undo nomeado `Ameno: criar cota`.

## Matemática de layout

Considere um plano com origem `O`, eixos ortonormais `X` e `Y`, e normal `N`.

As âncoras mundiais `A` e `B` são projetadas no plano:

```text
P(p) = p - N * dot(p - O, N)
```

Para cota alinhada:

```text
u = normalize(P(B) - P(A))
v = normalize(cross(N, u))
d = dot(P(C) - P(A), v)
LA = P(A) + v * d
LB = P(B) + v * d
valor = length(P(B) - P(A))
```

`C` é o terceiro clique. O sinal de `d` escolhe o lado da cota.

Para horizontal, `u = X`; para vertical, `u = Y`. O valor é a magnitude da projeção no eixo correspondente. O layout mantém as linhas auxiliares ligadas às âncoras, mas a linha principal usa os pontos projetados no eixo da cota.

Casos degenerados:

- se `A` e `B` coincidirem dentro da tolerância, bloquear commit;
- se a projeção horizontal/vertical for zero, mostrar preview inválido;
- se o afastamento for quase zero, aplicar o afastamento mínimo do estilo;
- se o texto não couber entre terminais, movê-lo para fora conforme regra do estilo.

## Leitura do texto

O texto deve permanecer legível em relação à câmera/plano:

1. projetar a direção da linha no eixo horizontal da câmera;
2. se a direção visual estiver invertida, girar o texto 180 graus;
3. preservar alinhamento central e baseline;
4. aplicar deslocamento perpendicular configurado;
5. opcionalmente mover o texto para fora quando não houver espaço.

## Unidades determinísticas

O valor interno é obtido em unidades de sistema. A apresentação não deve depender apenas de `units.formatValue`, pois estilos diferentes podem exigir unidades e precisão próprias.

Processo:

1. ler `units.SystemScale` e `units.SystemType`;
2. converter o valor da cena para milímetros canônicos;
3. converter milímetros para a unidade do estilo;
4. arredondar somente para exibição;
5. aplicar zeros finais, separador decimal, prefixo e sufixo;
6. nunca usar o valor arredondado como nova origem de cálculo.

O valor canônico e o texto formatado devem ser mantidos separados.

## Âncoras

### Mundo

Armazena a posição mundial. Não acompanha objetos.

### Local ao objeto

Armazena referência ao nó, ponto local e última posição mundial válida.

```text
worldPoint = localPoint * objectTransform
```

Esse modo acompanha transformação do objeto sem depender de nome ou índice de vértice.

### Helper

Armazena referência a um Point Helper criado ou escolhido pelo usuário. É indicado quando se deseja controle explícito e animação.

### Superfície, futuro

Pode armazenar face, coordenadas baricêntricas e assinatura de topologia. Mesmo assim deverá ser marcado como potencialmente frágil quando a pilha de modificadores alterar a topologia.

## Nós de cena

Cada cota do MVP usa:

- um controlador não renderizável;
- uma shape com linhas de extensão, linha principal e terminais compatíveis;
- um TextPlus;
- opcionalmente uma shape/mesh adicional quando o terminal exigir preenchimento.

O controlador é a raiz. Apagar o controlador remove sua representação; apagar apenas um filho aciona reparo/reconstrução.

Uma cota não deve depender do nome dos nós. IDs e referências são a identidade; nomes servem apenas para inspeção humana.

## Atualização associativa

### Índice reverso

Em memória, manter:

```text
nodeHandle -> conjunto de dimensionIds dependentes
```

Ao abrir uma cena, o índice é reconstruído por varredura dos controladores.

### Eventos

Callbacks de transformação, geometria, exclusão, Undo/Redo, abertura, merge e render apenas marcam cotas como `dirty`. Eles não devem reconstruir geometria pesada diretamente.

### Debounce

Uma fila processa as cotas sujas após pequena janela, aproximadamente 100–250 ms. Isso evita dezenas de atualizações enquanto o usuário arrasta um objeto.

### Proteções

- trava de reentrada;
- deduplicação por ID;
- suspensão durante carga/merge/reset;
- atualização em lote com redraw desativado;
- callbacks derivados ignoram os próprios nós gráficos;
- falha em uma cota não impede atualização das demais;
- pre-render força flush da fila;
- shutdown remove callbacks do processo.

### Undo

Ações iniciadas pelo usuário usam Undo nomeado. Reconstrução de geometria derivada usa `undo off` para não poluir o histórico. Após Undo/Redo de uma transformação, os eventos marcam novamente a cota para atualização.

## Representação e render

O domínio solicita uma descrição geométrica neutra:

- segmentos;
- polígonos de terminais;
- posição, rotação e escala do texto;
- material lógico;
- plano e elevação.

O adaptador converte isso em spline/TextPlus/material. Essa fronteira permitirá um renderer adapter ou objeto C++ sem reescrever as regras de cálculo.

Perfis previstos:

- `scene-units`: espessuras e texto em unidades do mundo;
- `screen-pixels`: tamanhos derivados da câmera ortográfica e resolução;
- `print-mm`: tamanhos derivados do formato físico e DPI;
- `overlay-pass`: material e visibilidade próprios para composição.

## Materiais

O estilo referencia um papel lógico, como `annotation-dark` ou `annotation-light`. Um provider escolhe a implementação:

- material genérico compatível;
- Corona;
- V-Ray;
- Arnold;
- material fornecido pelo usuário.

Sem provider específico, a geometria continua existindo e o diagnóstico informa que o material precisa ser atribuído.

## Performance

Metas iniciais:

- criação perceptualmente instantânea;
- atualização de 100 cotas abaixo de 1 segundo;
- nenhum callback de redraw reconstruindo toda a cena;
- no máximo dois ou três nós renderizáveis por cota;
- atualização em lote com um redraw final;
- cache de estilo resolvido e material.

Se 500 cotas excederem limites aceitáveis, considerar uma shape agregada por layer/câmera ou objeto nativo C++.

## Erros e recuperação

- referência removida: usar última posição e marcar órfã;
- nó gráfico removido: reconstruir a partir do controlador;
- estilo removido: aplicar fallback sem perder style ID original;
- versão futura: bloquear edição destrutiva e preservar dados;
- erro durante criação: limpar preview e não registrar Undo parcial;
- callbacks duplicados: remover pelo ID antes de registrar;
- arquivo sem Ameno: abrir normalmente, mantendo geometria visível quando possível.

## Segurança e portabilidade

- não salvar callbacks persistentes com código executável na cena;
- não executar strings vindas de propriedades da cena;
- Custom Attributes versionados e migrados explicitamente;
- valores enumerados validados contra lista permitida;
- paths externos nunca são confiáveis por padrão;
- diagnóstico informa dados incompatíveis sem apagá-los;
- bake oferece saída independente do plugin.

## Referências oficiais

- [MAXScript no 3ds Max](https://help.autodesk.com/cloudhelp/2026/ENU/MAXDEV-Overview/files/overview/MAXDEV_Overview_overview_maxscript_html.html)
- [Scripted Mouse Tools](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/GUID-80E8ADDC-F8A0-46F4-B909-4F39D5F37A29.html)
- [Custom Attributes](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Custom-Attributes/GUID-ADFD29E4-9751-4F55-98CC-F7C721C9AEE2.html)
- [Callbacks e Change Handlers](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/GUID-1BE2E978-72CF-495C-81D6-2B36E2C4FFC7.html)
- [Unidades](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Interacting-with-the-3ds-Max/Units/GUID-DB50F450-C3D1-47A5-98A2-A34601710034.html)
- [Undo](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Language-Reference/Names-Literal-Constants-and/Context-Expressions/GUID-C8517C4A-A75F-4D4E-A058-BE3EE61A2A11.html)
