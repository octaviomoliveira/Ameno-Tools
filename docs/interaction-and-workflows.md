# Experiência e fluxos de uso

## Objetivo de UX

O Ameno Tools deve parecer parte do 3ds Max, mas organizar o trabalho por resultado: criar, revisar e entregar cotas. O usuário não deve precisar entender nós internos, Custom Attributes ou callbacks.

## Painel principal

```text
┌─ AMENO TOOLS ───────────────────────┐
│ Projeto: Planta Apartamento         │
│ Câmera: CAM_Planta_01  ✓ Ortho      │
│ 24 cotas · 2 pendentes · 1 órfã     │
├─ CRIAR ─────────────────────────────┤
│ [Alinhada] [Horizontal] [Vertical]  │
│ [Contínua] [Geral + parciais]       │
│ Estilo: Apresentação escura      ▾  │
├─ SELEÇÃO ───────────────────────────┤
│ Valor real: 3,425 m                  │
│ Texto:      3,43 m                   │
│ Afastamento: 35 cm                   │
│ [Inverter] [Reancorar] [Atualizar]  │
├─ AÇÕES RÁPIDAS ─────────────────────┤
│ [Atualizar tudo] [Cotas para câmera]│
│ [Renderizar Cotas] [Converter/Bake] │
├─ DIAGNÓSTICO ───────────────────────┤
│ ⚠ 1 referência perdida              │
│ [Examinar] [Reparar]                 │
└─────────────────────────────────────┘
```

O painel começa compacto. Se não houver cota selecionada, a área `Seleção` mostra orientação curta. Se houver várias, mostra somente propriedades comuns.

## Primeiro uso

Ao abrir pela primeira vez:

1. detectar unidades do sistema;
2. detectar câmera ativa e se é ortográfica;
3. detectar renderizador;
4. propor criar layers e estilo padrão;
5. executar um teste não destrutivo de TextPlus e Renderable Spline;
6. mostrar `Tudo pronto` ou uma lista objetiva do que precisa ser ajustado.

O botão `Preparar esta cena` cria somente infraestrutura do Ameno. Não altera unidades, renderizador ou objetos do usuário sem confirmação explícita.

Ao preparar, cria `AMENO_COTAS` e `AMENO_SYSTEM`, configura o estilo inicial e apresenta as capacidades de Beauty, LightMix e Render Elements do renderer atual.

## Criação comum

### Antes dos cliques

- o botão escolhido fica ativo;
- a prompt line informa o próximo passo;
- o painel exibe estilo e unidade atuais;
- se Snap estiver desligado, um aviso discreto aparece, sem ligá-lo automaticamente;
- se a câmera for perspectiva, o painel recomenda plano XY/grade ou câmera ortográfica.

### Primeiro clique

- captura o ponto e, quando possível, o nó sob o cursor;
- oferece âncora local ao objeto como padrão;
- desenha marcador A;
- HUD mostra coordenada e tipo de âncora.

### Segundo clique

- mostra a linha de medida em tempo real;
- HUD mostra valor sem arredondar excessivamente;
- Shift alterna/constrange entre alinhada, horizontal e vertical;
- o segundo clique confirma B.

### Terceiro clique

- cursor escolhe lado e afastamento;
- preview completo mostra texto, linha, extensões e terminais;
- Tab pode focar um campo numérico para afastamento exato em fase posterior;
- clique confirma;
- modo contínuo reinicia em A ou encerra conforme preferência.

### Cancelamento

Esc ou botão direito:

- interrompe a etapa atual;
- remove qualquer preview;
- não cria histórico de Undo;
- preserva tipo e estilo escolhidos.

## Gestos produtivos propostos

- `Shift`: restringir orientação;
- `Alt`: inverter o lado durante o terceiro clique;
- `Ctrl`: concluir e continuar em cadeia;
- duplo clique em uma cota: abrir edição rápida;
- botão direito em cota: atualizar, inverter, reancorar, converter e diagnosticar;
- repetir último comando por ação configurável no CUI, sem impor atalho global.

Os modificadores precisam ser testados contra atalhos nativos e não devem capturar teclas fora da mouse tool.

## Edição direta

Selecionar o controlador deve exibir:

- handles A e B;
- handle de afastamento;
- posição lógica do texto;
- status da referência;
- valor real e valor exibido.

No MVP, handles podem ser Point Helpers visíveis somente quando selecionados. Em uma versão C++, podem virar manipuladores nativos.

## Editor de estilo

O editor abre ao clicar no nome do estilo ou em `Editar estilo`. Ele combina três áreas visíveis:

1. preview ao vivo da cota;
2. Texto, com controles inspirados no TextPlus;
3. Linhas e Setas, com presets e escolhas visuais.

Não haverá uma reprodução completa do TextPlus. Controles de múltiplas linhas, animação por caractere, extrusão e bevel ficam ocultos porque não ajudam na cotagem.

### Texto

- lista pesquisável de fontes instaladas;
- fontes recentes e favoritas no topo;
- regular, bold e italic;
- tamanho e tracking com sliders mais valor digitável;
- máscara de fundo;
- preview usando o TextPlus real sempre que possível;
- aviso de fonte ausente em outra máquina/render farm.

### Linhas

- botões Fina, Normal e Forte para decisão rápida;
- slider para ajuste fino;
- unidade visual em px quando o estilo for screen-based;
- color picker;
- opções avançadas recolhidas: extensão gap, overshoot e espessura independente.

### Setas e terminais

Uma grade visual evita dropdown abstrato:

- traço arquitetônico;
- seta cheia;
- seta aberta;
- ponto;
- nenhuma.

Após escolher, o usuário ajusta tamanho e posição. `Automática` é padrão e move setas para fora quando texto e terminais não cabem.

### Segurança de edição

O editor mostra `24 cotas vinculadas`. As ações são:

- `Aplicar às selecionadas`;
- `Salvar como novo`;
- `Atualizar estilo`;
- `Cancelar`.

Cancelar restaura o preview. Atualizar o estilo informa o alcance antes de reconstruir todas as cotas.

## Ações que realmente economizam tempo

### Atualizar tudo antes do render

O pre-render verifica a fila dirty e reconstrói somente o necessário. Se houver cotas órfãs ou sobrescritas, apresenta uma lista; a política de bloquear ou apenas avisar será configurável.

### Adaptar para câmera

`Cotas para câmera` aplica um perfil visual à câmera atual:

- espessura em pixels;
- altura de texto;
- distância mínima das paredes;
- cor clara/escura;
- visibilidade por enquadramento.

Isso evita redimensionar manualmente dezenas de textos quando a resolução ou o crop muda.

### Copiar estilo de uma cota

Conta-gotas de estilo: clicar em uma cota de referência e aplicar às selecionadas.

### Reancorar sem recriar

Escolher `Reancorar A`, clicar em outro objeto/ponto e manter afastamento, estilo, texto e identidade da cota.

### Diagnóstico navegável

Cada erro possui `Selecionar e enquadrar`. Em vez de procurar `AMENO_DIM_...` no Scene Explorer, o usuário chega ao problema em um clique.

### Conversão segura

`Bake` duplica ou converte a representação em objetos comuns, preserva um snapshot opcional dos metadados e permite desfazer em um bloco de Undo. É a saída para enviar uma cena a alguém sem o plugin.

### Isolar cotas

Alternar:

- beleza + cotas;
- somente cotas em fundo transparente;
- beleza sem cotas;
- somente selecionadas.

Esse fluxo facilita composição, correção de cor e versões com/sem informação comercial.

## Painel Render Output

> Painel avançado futuro. No MVP ele é substituído pelo painel simples abaixo.

## Painel Renderizar Cotas — MVP

```text
┌─ RENDERIZAR COTAS ─────────────────┐
│ Câmera: CAM_Planta_01              │
│ Saída: 3840 × 2160 · Pixel 1,0     │
│                                    │
│ Cotas: (•) Todas  ( ) Selecionadas │
│ Formato: [PNG + Alpha ▾]           │
│ Path: .../CAM_Planta_AMENO_COTAS   │
│ [✓] Fundo transparente             │
│ [✓] Abrir pasta ao concluir        │
│                                    │
│ [Preview] [RENDERIZAR COTAS]       │
└────────────────────────────────────┘
```

Ao clicar:

1. o app confere se câmera e saída combinam com o render da planta;
2. atualiza as cotas;
3. renderiza somente `AMENO_COTAS`;
4. restaura a cena;
5. informa o arquivo pronto para o Photoshop.

Nenhuma configuração de LightMix ou Render Elements aparece nesse fluxo.

```text
┌─ SAÍDA DAS COTAS ──────────────────┐
│ Canal final                        │
│ [LightMix ativo ▾]                 │
│                                    │
│ Modo                               │
│ (•) Integrada + separada           │
│ ( ) Integrada                      │
│ ( ) Somente element                │
│ ( ) Somente viewport               │
│                                    │
│ Element: [Annotation RGBA ▾]       │
│ [✓] Alpha antialiasing             │
│ [✓] Sempre por cima                │
│ [✓] Cor independente do LightMix   │
│ Formato: [EXR 16-bit ▾]            │
│                                    │
│ Renderer: Corona                   │
│ RGBA no mesmo passe: não           │
│ Fallback: segundo passe disponível │
│                                    │
│ [Configurar] [Testar saída]        │
└────────────────────────────────────┘
```

`Testar saída` valida em resolução reduzida se as cotas aparecem no canal final escolhido e no element separado. Isso evita descobrir somente após o render que o Beauty contém cotas, mas o LightMix entregue não.

## Preview de composição

Quando o canal final for LightMix, o app oferece:

- visualizar LightMix sem cotas;
- visualizar `LightMix + AMENO_COTAS_RGBA`;
- salvar apenas o overlay;
- salvar uma cópia achatada;
- alternar entre diferentes LightMix preservando o mesmo overlay.

O overlay separado é sempre preservado, mesmo quando uma versão achatada é gerada.

## Controles da layer

No cabeçalho:

- olho: ligar/desligar `AMENO_COTAS`;
- freeze/lock: proteger seleção acidental;
- alvo: selecionar todas as cotas;
- enquadrar: localizar cotas fora da câmera;
- reparar: devolver nós Ameno movidos para outra layer.

O app respeita alterações manuais. `Reparar` só muda a cena quando solicitado ou ao reconstruir um nó próprio.

## Fluxos por cenário

### Entrega rápida de uma planta

1. abrir o Ameno;
2. `Preparar esta cena`;
3. escolher `Apresentação 4K`;
4. criar cotas externas e internas;
5. `Atualizar tudo`;
6. abrir diagnóstico;
7. renderizar beleza e overlay;
8. exportar preset junto da cena.

### Mudança solicitada pelo cliente

1. mover parede/móveis;
2. cotas dependentes ficam dirty;
3. ao soltar a transformação, atualização debounced ocorre;
4. cotas órfãs ficam destacadas;
5. usuário reancora somente as problemáticas;
6. novo render usa os valores atuais.

### Trabalhar com DWG importado

1. manter DWG em layer próprio;
2. criar âncoras locais aos objetos estáveis ou helpers;
3. ao atualizar/reimportar o DWG, executar diagnóstico;
4. reancorar referências substituídas;
5. preservar estilos e posição das cotas.

### Cena entregue a terceiro

1. executar `Verificar portabilidade`;
2. escolher manter cotas editáveis ou bake;
3. criar cópia da cena quando necessário;
4. relatório informa dependências e versão do Ameno.

## Recursos posteriores do app

### Favoritos por escritório

Biblioteca com estilos, perfis de saída e convenções de unidade sincronizáveis via arquivo de preset versionado.

### Regras por camada ou objeto

Exemplos:

- portas usam centímetros;
- cotas gerais usam metros;
- cotas internas usam estilo fino;
- cotas externas usam estilo forte.

### Sugestões, não decisões silenciosas

O app pode identificar bounding boxes, vãos e alinhamentos e sugerir cotas. Antes de criar em lote, mostra preview e permite desmarcar itens. Automação nunca deve gerar dezenas de objetos irreversíveis sem revisão.

### Auditoria visual

Mapa de cobertura indicando paredes/aberturas selecionadas sem cota associada. É uma ferramenta de apresentação, não validação normativa.

### Projetos Ameno

Um pequeno contexto por cena pode guardar:

- nome do projeto;
- câmeras de planta;
- estilos usados;
- perfis de entrega;
- última verificação;
- versão do plugin;
- notas de compatibilidade.

Isso transforma o painel em centro de controle da entrega, e não somente em botão para desenhar linhas.
