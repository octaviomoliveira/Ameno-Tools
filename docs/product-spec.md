# Ameno Dimensions — especificação do produto

Status: rascunho 0.1
Produto-pai: Ameno Tools

## Problema

O 3ds Max mede a cena, mas não oferece um fluxo completo para criar cotas gráficas, consistentes e atualizáveis em plantas humanizadas. O usuário termina o render no Max e precisa reconstruir as cotas em outro programa, manter dois arquivos sincronizados e revisar valores manualmente sempre que a planta muda.

## Público inicial

- artistas de archviz;
- arquitetos que finalizam plantas no 3ds Max;
- estúdios de imagens imobiliárias;
- equipes que recebem DWG/Revit, humanizam no Max e entregam JPG/PNG/PDF;
- usuários que precisam de apresentação clara, mas não de documentação executiva BIM.

## Trabalho que o produto resolve

> Quando eu preparar uma planta humanizada, quero clicar nos pontos importantes e obter cotas visualmente consistentes, para entregar a imagem sem redesenhar tudo em outro aplicativo e sem correr o risco de mostrar valores desatualizados.

## Resultado esperado

Em uma planta típica, o usuário deve conseguir criar de 10 a 30 cotas em poucos minutos, alterar a arquitetura, atualizar as cotas e renderizar um resultado legível sem refazer o trabalho gráfico.

## Conceito de cota

Uma cota Ameno é composta por:

- duas âncoras;
- um plano de medição;
- uma regra de projeção;
- um afastamento;
- um valor calculado;
- uma regra de formatação;
- um estilo visual;
- um estado de integridade;
- uma representação de viewport/render derivada desses dados.

Linhas e texto são a saída visual. Eles não são a fonte oficial da informação.

## Tipos do MVP

### Alinhada

Mede a distância entre as âncoras projetadas no plano e orienta a linha de cota na mesma direção.

### Horizontal

Mede a projeção entre as âncoras no eixo horizontal do plano de trabalho.

### Vertical

Mede a projeção entre as âncoras no eixo vertical do plano de trabalho.

## Fluxo principal

1. O usuário escolhe `Alinhada`, `Horizontal` ou `Vertical`.
2. A barra de prompt pede `Clique no primeiro ponto`.
3. O cursor respeita o sistema de Snap já configurado pelo usuário.
4. Após o primeiro clique, surge uma prévia até o segundo ponto.
5. Após o segundo clique, a prévia mostra valor, extensões e terminais.
6. O terceiro clique define lado e afastamento.
7. O sistema grava a cota em um único bloco de Undo.
8. O modo contínuo pode permanecer ativo para criar outra cota.
9. Botão direito ou Esc cancela sem deixar objetos temporários.

## Modos de produtividade

### Cota rápida

Usa último tipo, estilo, câmera/plano e unidade. Abre diretamente a ferramenta de três cliques.

### Cota contínua

Cada novo clique usa o ponto anterior como início da próxima cota. Útil para sequências de paredes, esquadrias ou ambientes.

### Cota em cadeia

O usuário seleciona vários pontos; o sistema cria segmentos individuais alinhados na mesma linha externa.

### Cota geral + parciais

O usuário define os extremos e pontos intermediários. O sistema produz uma linha de dimensão geral e outra com os trechos internos.

Este modo é pós-MVP, mas o modelo de dados não deve impedi-lo.

### Cota por seleção

Atalhos posteriores poderão criar cotas a partir de bounding boxes, pivôs, paredes, portas e janelas selecionadas.

## Estilos

Um estilo deve controlar:

- fonte;
- altura do texto;
- caixa alta e convenções;
- cor;
- espessura da linha;
- extensão além da linha principal;
- folga entre âncora e linha auxiliar;
- terminal: seta, traço arquitetônico, ponto ou nenhum;
- tamanho do terminal;
- posição do texto;
- máscara/fundo do texto;
- prefixo, sufixo e unidade visível;
- precisão e remoção de zeros finais;
- separador decimal;
- material de render;
- altura em relação ao plano;
- perfil de saída.

Alterar um estilo atualiza todas as cotas ligadas a ele. O usuário também pode `Desvincular estilo`, criando uma cópia local.

## Perfis de saída

O diferencial do produto para planta humanizada será separar medida real de tamanho visual.

Exemplos:

- Instagram 1080 px;
- apresentação 1920 px;
- 4K;
- A3 a 300 dpi;
- tamanho fixo em unidades da cena.

Em câmera ortográfica, o sistema pode calcular a conversão de pixels para unidades do mundo a partir da largura ortográfica e da resolução. Assim uma linha configurada com 2 px e um texto de 36 px mantêm legibilidade mesmo quando o enquadramento muda.

## Organização por layer

Na criação da primeira cota, o Ameno cria automaticamente a layer `AMENO_COTAS`. Linhas, terminais, textos e geometrias auxiliares renderizáveis pertencem somente a essa layer.

Controladores e metadados não renderizáveis ficam em `AMENO_SYSTEM`. Assim o usuário pode ocultar ou congelar a arte sem desligar os dados associativos.

Regras:

- reutilizar `AMENO_COTAS` somente quando ela for reconhecida como propriedade do Ameno;
- se houver uma layer do usuário com o mesmo nome, criar um nome livre e registrar o conflito;
- acompanhar uma layer renomeada por referência/metadado, não apenas pelo nome;
- se a layer for apagada, preservar as cotas, recriá-la e reatribuir os nós;
- respeitar estados manuais de oculto, congelado e bloqueado;
- nunca mover objetos que não tenham sido gerados pelo Ameno para essa layer.

## Canais de entrega

O termo `Beauty` não é suficiente, porque Corona e V-Ray podem entregar um resultado final calculado pelo LightMix em outro Render Element/canal. O perfil Ameno deve definir o **canal de entrega** usado pelo usuário:

- Beauty nativo;
- LightMix ativo;
- Beauty e LightMix;
- Annotation Element separado;
- composição externa;
- somente viewport.

O Ameno não deve colocar as cotas como uma luz do LightMix nem permitir que intensidade e cor delas mudem junto com grupos de iluminação. A anotação é uma camada gráfica posterior à iluminação.

## Modos de saída

### Integrada

A cota aparece no canal final escolhido. Se o usuário entrega LightMix, ela deve estar presente no resultado LightMix, e não apenas no Beauty original.

### Separada

A cota não é incorporada ao canal final e sai como máscara ou `Annotation RGBA` para composição.

### Integrada + separada

O usuário recebe o resultado pronto e também um elemento independente para correções.

### Somente viewport

A cota ajuda no trabalho, mas não aparece em nenhuma saída.

## Tipos de elemento

### Mask

Máscara antialiasing das cotas. Pode sair no mesmo render e é suficiente quando a cor será aplicada na composição.

### Annotation RGBA

Imagem com cores reais, alpha e antialiasing. É a saída ideal para sobrepor diretamente no Photoshop, After Effects ou outro compositor.

Nem todo renderizador consegue excluir um objeto do Beauty e ainda fornecer seu RGBA completo em um element no mesmo passe. Nesses casos, o Ameno usa um segundo passe protegido, mantendo câmera, resolução, frame e color management.

## LightMix

No Corona e no V-Ray, LightMix reconstrói ou apresenta um resultado em canal próprio. Materiais emissivos podem entrar em grupos de self-illumination e sofrer ajustes indesejados. Portanto, o padrão Ameno será:

1. manter cotas fora dos grupos de iluminação;
2. gerar `AMENO_COTAS_RGBA` como overlay independente;
3. visualizar uma composição de conferência sobre Beauty ou LightMix;
4. salvar o overlay separadamente;
5. opcionalmente gerar uma versão achatada do canal final com as cotas.

Esse fluxo preserva a liberdade do LightMix: o usuário altera luzes, exposição e ambiente sem mudar a cor gráfica das cotas.

## Comportamento visual no render

Por padrão, as cotas:

- não projetam nem recebem sombras;
- não contribuem para GI;
- não aparecem em reflexos/refrações;
- não recebem motion blur ou profundidade de campo;
- aparecem por cima da planta no Annotation RGBA;
- preservam alpha, antialiasing e color management;
- mantêm cor visual independente dos multiplicadores do LightMix.

## Gerenciamento seguro de elements

O Ameno adiciona ou atualiza somente elements identificados como seus, como `AMENO_COTAS_MASK`, `AMENO_COTAS_RGBA` e, quando necessário, `AMENO_COMPOSITE_PREVIEW`. Nunca apaga ou reordena elements do usuário automaticamente.

O path pode usar tokens:

```text
{scene}_{camera}_{lightmix}_{frame}_AMENO_COTAS.exr
```

## Estados de integridade

- `ok`: referências disponíveis e visual atualizado;
- `dirty`: dados mudaram e aguardam reconstrução;
- `orphan-a`: referência A desapareceu;
- `orphan-b`: referência B desapareceu;
- `orphan-both`: ambas desapareceram;
- `unsupported`: dado criado por versão mais nova;
- `baked`: convertido em geometria comum;
- `hidden-by-profile`: oculto pelo perfil/câmera atual.

Uma cota órfã conserva a última posição válida e aparece no diagnóstico. Nunca deve desaparecer automaticamente.

## Operações de edição

- reposicionar afastamento;
- inverter lado;
- reancorar A ou B;
- trocar tipo;
- trocar estilo;
- editar prefixo/sufixo;
- sobrescrever texto, mantendo o valor real disponível no painel;
- restaurar texto calculado;
- ocultar em câmera/perfil;
- atualizar;
- duplicar;
- converter em geometria;
- excluir.

## Sobrescrita segura

Quando o usuário digitar um valor manual, o painel deve mostrar:

- `Valor medido: 3,42 m`;
- `Texto exibido: 3,40 m`;
- indicador visual de sobrescrita.

Isso evita que uma correção gráfica seja confundida com uma medida real.

## Painel de diagnóstico

O app deve responder rapidamente:

- quantas cotas existem;
- quantas estão desatualizadas;
- quais perderam referências;
- quais possuem texto sobrescrito;
- quais usam estilos ausentes;
- quais não aparecem na câmera atual;
- quais foram criadas por versão incompatível.

Cada item terá `Selecionar`, `Enquadrar`, `Reparar` e, quando seguro, `Corrigir todas`.

## Não objetivos do MVP

- substituir AutoCAD, Revit ou Archicad;
- editar paredes alterando o valor da cota;
- reconhecer semanticamente toda a arquitetura;
- garantir associação a topologia deformável;
- gerar documentação executiva normativa;
- oferecer cotas em perspectiva com aparência de HUD.

## Métricas de sucesso

- tempo mediano menor que 8 segundos por cota simples;
- nenhuma perda de cotas após salvar/reabrir em cenas de teste;
- menos de 1 segundo para atualizar 100 cotas em uma estação comum;
- zero objetos temporários após cancelamento;
- diagnóstico capaz de localizar 100% das referências removidas nos testes;
- usuário consegue produzir a primeira cota sem consultar documentação extensa.
