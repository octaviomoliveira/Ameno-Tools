# Editor de estilos — texto, linhas e setas

## Objetivo

Oferecer a potência útil do TextPlus sem expor sua complexidade. O usuário trabalha com uma cota completa e recebe preview imediato da relação entre texto, linha e terminais.

## Princípios

1. Decisões visuais aparecem como escolhas visuais.
2. Presets resolvem o uso comum; números continuam disponíveis.
3. O preview mostra a cota inteira, não texto isolado.
4. Tamanho visual é separado de unidades do mundo.
5. Estilos compartilhados deixam seu alcance explícito.
6. Fonte ausente nunca é substituída silenciosamente.

## Estrutura

### Cabeçalho

- nome do estilo;
- quantidade de cotas vinculadas;
- presets Arquitetônico, Editorial e Técnico;
- indicador de alterações não salvas.

### Preview

- pequena planta neutra;
- cota real com valor de exemplo;
- zoom/saída ativa;
- fonte, tamanho e espessura atuais;
- alternância futura entre fundo claro e escuro.

### Texto

Inspirado nos parâmetros globais do TextPlus:

- font family;
- variante;
- bold;
- italic;
- size;
- tracking;
- máscara;
- cor;
- alinhamento central fixo no MVP.

Não expor no MVP:

- leading;
- formatação por caractere;
- underline/strikethrough;
- superscript/subscript;
- animação;
- extrude/bevel;
- layout multilinha/region.

### Linhas

Controles rápidos:

- Fina;
- Normal;
- Forte;
- espessura contínua;
- cor.

Avançado recolhido:

- espessura das extensões ligada/independente;
- folga até a geometria;
- prolongamento além da linha de cota;
- elevação Z;
- material role.

### Setas e terminais

Grade com preview gráfico:

- traço arquitetônico;
- seta fechada;
- seta aberta;
- ponto;
- nenhum.

Parâmetros:

- tamanho;
- ângulo;
- posição automática/dentro/fora;
- vínculo de cor/espessura com a linha;
- regra de fit.

## Fluxos

### Editar um estilo global

1. abrir estilo;
2. modificar com preview;
3. clicar `Atualizar estilo`;
4. confirmar quantidade de cotas afetadas;
5. rebuild em lote;
6. um único Undo.

### Criar variação

1. abrir estilo base;
2. modificar;
3. `Salvar como novo`;
4. nomear;
5. aplicar às cotas selecionadas.

### Edição rápida da seleção

1. selecionar cotas;
2. escolher preset ou espessura;
3. `Aplicar às selecionadas`;
4. criar override ou novo estilo conforme preferência.

## Fontes

A lista usa fontes reconhecidas pelo 3ds Max/TextPlus. O cache é reconstruído quando solicitado, não em cada abertura.

Cada estilo guarda fonte desejada, variante e fallback. O diagnóstico verifica a estação atual e pode gerar relatório para render farm. O Ameno não distribui arquivos de fonte automaticamente por questões técnicas e de licenciamento.

## Preview e desempenho

O preview tem objeto dedicado e não faz parte da cena final. Durante drag:

- atualizar preview imediatamente;
- opcionalmente atualizar apenas uma cota selecionada;
- aplicar debounce para cena;
- reconstruir todas somente no commit.

## Defaults propostos

- preset: Arquitetônico;
- fonte: Arial até definirmos a identidade Ameno;
- tamanho: dependente do perfil, exibido em px;
- linha: Normal;
- terminal: traço arquitetônico;
- posição: Automática;
- máscara: ligada;
- cor: compartilhada entre texto e linha.

## Referência TextPlus

O TextPlus oferece fonte, variante, bold/italic, tamanho, tracking, alinhamento e ajustes por caractere. O Ameno utiliza a base tipográfica, mas mantém somente os controles coerentes com cotas.

- [Documentação oficial do TextPlus](https://help.autodesk.com/cloudhelp/2026/ENU/3DSMax-Modeling/files/GUID-98DE9F44-B5C0-4AAC-A7CD-2F9E2B924ECD.htm)
