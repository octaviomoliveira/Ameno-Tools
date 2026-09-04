# ADR 0007 — MouseTool de três cliques e preview temporário

- Estado: aceita para o MVP
- Data: 2026-09-03

## Contexto

A E3 já cria uma cota determinística a partir de três pontos, mas ainda não oferece um fluxo de desenho utilizável. A primeira interação precisa ser previsível em uma planta, respeitar o Snap que o usuário já configurou e não deixar objetos quando o comando for cancelado.

## Decisão

- usar o `MouseTool` nativo do MAXScript com três pontos: A, B e afastamento;
- usar nós temporários somente durante a prévia, em `AMENO_COTAS`, com `Ameno.Kind=dimensionPreview` e `Ameno.Preview=1`;
- atualizar os knots da spline e a string/posição do TextPlus durante o movimento, sem criar novos nós a cada evento;
- não ligar nem alterar o Snap: o comando solicita `snap:#3D`, deixando o estado ligado/desligado sob controle do usuário;
- projetar os pontos para XY, coerente com a matemática da E2/E3;
- criar controlador e representação permanente apenas no terceiro clique, por meio de `AmenoDimensionGraphics.createDimension`;
- remover a prévia em Esc, botão direito, erro, reset e shutdown usando `undo off`;
- manter o commit da cota em uma entrada de Undo nomeada `Ameno: criar cota`.

## Consequências

### Positivas

- preview responde ao movimento sem poluir a cena;
- cancelamento é seguro e repetível;
- a geometria permanente continua centralizada na E3;
- Snap, renderer, luzes, LightMix e Render Elements permanecem fora do escopo da interação.

### Limitações conhecidas

- a primeira versão trabalha no plano XY;
- a prévia usa TextPlus e a mesma geometria de spline da E3; o adapter específico de overlay Corona continua na E9;
- a validação visual dos eventos reais de mouse ainda depende do teste manual do usuário no Max.
