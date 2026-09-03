# Plano de testes

## Estratégia

Separar testes de regras puras, integração com a cena, interação humana e render. Testes que exigem 3ds Max devem registrar versão, renderizador, unidades e arquivo-fixture.

## Matemática

- alinhada nos quatro quadrantes;
- horizontal com A antes/depois de B;
- vertical com A acima/abaixo de B;
- planos rotacionados;
- terceiro clique em ambos os lados;
- pontos coincidentes;
- afastamento zero;
- coordenadas muito grandes e muito pequenas;
- tolerância numérica;
- objetos com rotação;
- escala uniforme, não uniforme e negativa.

## Unidades

Combinações de sistema e exibição:

- sistema mm, saída mm/cm/m;
- sistema cm, saída mm/cm/m;
- sistema m, saída mm/cm/m;
- precisão 0–3;
- ponto e vírgula decimal;
- zeros finais ligados/desligados;
- prefixo/sufixo;
- cenas alteradas com Rescale World Units;
- valores próximos ao limite de arredondamento.

Casos de referência:

- 342,5 cm → `3,425 m`;
- 342,5 cm com 2 casas → `3,43 m`;
- 80 cm com metros e zeros removidos → `0,8 m`;
- 80 cm com duas casas fixas → `0,80 m`.

## Criação e cancelamento

- criar em três cliques;
- cancelar em cada etapa com Esc;
- cancelar em cada etapa com botão direito;
- trocar viewport durante ferramenta;
- perder foco da janela;
- reset/new/open durante preview;
- erro deliberado durante preview;
- confirmar que não ficam nós, callbacks ou Undo parciais.

## Persistência

- criar, salvar, fechar e reabrir;
- rename do objeto ancorado;
- rename da cota;
- mover/rotacionar/escalar referência;
- remover referência A/B/ambas;
- remover spline ou TextPlus filho;
- remover estilo;
- merge entre duas cenas Ameno;
- clone/copy/instance do controlador;
- abrir sem Ameno instalado;
- abrir novamente com Ameno e reconstruir.

## Undo/Redo

- criação = uma entrada;
- exclusão = uma entrada;
- troca de estilo = uma entrada;
- reancoragem = uma entrada;
- bake = uma entrada;
- atualização automática não cria dezenas de entradas;
- Undo de movimento atualiza a cota para a posição anterior;
- Redo refaz e atualiza novamente.

## Callbacks

- startup repetido sem duplicar callbacks;
- abrir múltiplas cenas na mesma sessão;
- reset;
- merge;
- XRef quando suportado;
- atualização de 100 cotas após mover um objeto comum;
- duas referências movidas simultaneamente;
- callbacks não reagem recursivamente aos filhos gráficos;
- fila é esvaziada antes do render;
- shutdown limpa os registros.

## Visual

- texto nunca aparece invertido na câmera suportada;
- terminais apontam para dentro/fora conforme regra;
- linha não sofre z-fighting;
- texto curto e longo;
- texto que não cabe entre terminais;
- cores clara e escura;
- fundo/máscara;
- 1080p, 4K e A3 300 dpi;
- alteração do crop/enquadramento ortográfico;
- espessura coerente entre resoluções.

## Editor de estilo

- lista fontes instaladas sem travar a abertura;
- troca de fonte atualiza preview;
- regular, bold e italic correspondem ao TextPlus;
- tamanho e tracking coincidem após salvar/reabrir;
- fonte ausente usa fallback e gera diagnóstico;
- render farm sem fonte recebe aviso verificável;
- Fina/Normal/Forte produzem espessuras distintas no perfil ativo;
- slider de espessura não reconstrói todas as cotas a cada evento;
- traço, seta cheia, seta aberta, ponto e nenhuma renderizam corretamente;
- terminais esquerdo/direito são espelhados;
- posição automática move terminais para fora quando necessário;
- texto longo não colide silenciosamente com setas;
- máscara acompanha bounding box e padding;
- Cancel restaura snapshot;
- Salvar como novo não altera cotas antigas;
- Atualizar estilo altera todas as vinculadas em um Undo;
- multi-seleção representa valores mistos corretamente;
- valores inválidos são bloqueados sem corromper o estilo.

## Valores medidos, arredondados e manuais

- medido exibe exatamente o valor formatado da geometria;
- arredondamento de 19,555 m para incremento 0,10 m resulta em 19,60 m;
- arredondamento não altera `measuredMm`;
- manual 19,60 m sobre medido 20,00 m produz delta -0,40 m;
- manual numérico continua obedecendo unidade e precisão do estilo;
- texto livre permanece separado de manual numérico;
- mover âncoras recalcula medido e delta, preservando manual;
- `Usar valor medido` remove override e advertência em um Undo;
- reabrir cena preserva valor, motivo e estado;
- cotas manuais aparecem âmbar somente na viewport;
- marcador manual não aparece no PNG/EXR de cotas;
- material e cor de render permanecem normais;
- toggle de advertências não altera dados;
- cor de advertência é configurável;
- diagnóstico seleciona e enquadra todas as manuais;
- restauração em lote exige confirmação;
- merge e clone preservam ou renovam IDs sem perder override;
- relatório lista medido, exibido, delta e motivo.

## Layers

- primeira cota cria `AMENO_COTAS`;
- cotas seguintes reutilizam a layer;
- layer de usuário com nome conflitante não é apropriada;
- layer renomeada continua sendo encontrada;
- layer apagada é recriada sem perder cotas;
- nós gráficos movidos para outra layer são reparados;
- objetos do usuário nunca são movidos para `AMENO_COTAS`;
- layer corrente anterior é restaurada após criação;
- ocultar, congelar e bloquear manualmente são respeitados.

## Saída de render e LightMix

Os testes abaixo são futuros. Para o MVP, aplicar primeiro a seção `Render separado das cotas`.

- integrada aparece no Beauty nativo;
- integrada aparece também no LightMix escolhido;
- element separado pode excluir cotas do canal final;
- integrada + separada produz ambos;
- viewport only não aparece no render;
- Mask possui alpha e antialiasing corretos;
- Annotation RGBA preserva cor e transparência;
- alterar intensidade/cor no LightMix não muda a identidade gráfica das cotas;
- cotas não aparecem como grupo de luz controlável;
- self-illumination do renderer não contamina o overlay;
- preview `LightMix + overlay` coincide com a cópia achatada;
- trocar entre LightMix A/B conserva o mesmo overlay;
- fallback de segundo passe restaura a cena após sucesso, erro e cancelamento;
- Object IDs do usuário não são sobrescritos silenciosamente;
- Render Elements do usuário não são removidos, renomeados ou reordenados;
- element Ameno existente é reutilizado sem duplicação;
- paths com tokens geram nomes previsíveis;
- render de animação inclui frame e LightMix corretos;
- render farm encontra pacote, materiais, elements e paths;
- color management do overlay é consistente com o canal final.

## Render separado das cotas — MVP

- botão renderiza somente `AMENO_COTAS`;
- Beauty, LightMix e Render Elements permanecem inalterados;
- PNG contém alpha transparente;
- EXR possui dimensões e alpha esperados;
- largura, altura e pixel aspect coincidem com a planta;
- câmera e frame coincidem;
- crop/region geram resultado previsível ou aviso;
- todas/selecionadas funcionam;
- material preserva cor do estilo;
- objetos da planta não aparecem no overlay;
- render termina com todas as visibilidades restauradas;
- cancelamento restaura a cena;
- exceção simulada restaura a cena;
- render repetido não acumula callbacks ou objetos temporários;
- arquivo recebe nome sem sobrescrever silenciosamente outro frame;
- preview usa a mesma proporção da saída final;
- assinatura pixel-perfect detecta câmera ou resolução divergente.

## Renderizadores

Para cada renderizador oficialmente suportado:

- spline aparece;
- TextPlus aparece;
- material não recebe iluminação indevida;
- alpha correto no overlay;
- integração LightMix testada quando disponível;
- Self Illumination/LightSelect não altera cotas involuntariamente;
- motion blur/DOF não afetam cotas quando desabilitados pelo perfil;
- render local e render farm usam o mesmo pacote;
- cena sem adapter apresenta diagnóstico claro.

## Desempenho

Medir:

- 1, 10, 100, 500 e 1000 cotas;
- tempo de scan ao abrir;
- tempo de atualização total;
- tempo de atualização de uma dependência;
- uso de memória;
- responsividade durante drag;
- impacto no início do render.

Meta inicial: 100 cotas atualizadas em menos de 1 segundo no equipamento de referência.

## Matriz de compatibilidade

Depois de escolher o alvo:

| Max | Renderer | Criar | Reabrir | Atualizar | Render | Status |
|---|---|---:|---:|---:|---:|---|
| a definir | a definir | — | — | — | — | pendente |

## Critério de release alpha

- nenhum bug conhecido que perca dados;
- todas as cenas-fixture reabrem;
- criação/cancelamento/Undo aprovados;
- uma planta de produção concluída com o módulo;
- diagnóstico localiza referências removidas;
- instalação e desinstalação documentadas;
- limitações publicadas no README.
