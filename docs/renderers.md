# Compatibilidade com Corona e V-Ray

## Ordem de implementação

1. Corona no 3ds Max 2026: renderer de desenvolvimento e referência visual.
2. V-Ray CPU no 3ds Max 2026: segundo adapter oficial.
3. V-Ray GPU: qualificação independente, inicialmente experimental.

O módulo de cotas não é duplicado. Os adapters mudam somente o que pertence ao renderizador.

## O que é comum

- geometria de splines e terminais;
- TextPlus e layout;
- layer `AMENO_COTAS`;
- câmera, frame, resolução, pixel aspect e crop;
- escolha de todas/selecionadas;
- nome e formato da saída;
- snapshot e restauração transacional;
- assinatura pixel-perfect;
- validação do PNG/EXR final.

## O que pertence ao adapter

- detectar renderer, versão e engine;
- criar o material gráfico apropriado;
- garantir visibilidade direta e alpha;
- neutralizar dependência de luz/exposição;
- configurar fundo transparente sem destruir o ambiente do usuário;
- executar e salvar o render de forma suportada;
- lidar com VFB/color pipeline;
- declarar capacidades e limitações verificadas.

## Perfil de cor padrão

`graphic-sRGB` é o padrão para Photoshop. A cor escolhida no estilo deve ser previsível e independente das luzes, do LightMix e da exposição usada na planta.

O arquivo final precisa declarar claramente:

- formato e bit depth;
- alpha straight ou premultiplied;
- espaço de cor/transform aplicado;
- se alguma correção do VFB foi incorporada.

### Evidência inicial da E3 e E9

O construtor gráfico foi validado visualmente no Arnold e no V-Ray com iluminação disponível na cena; a limpeza também foi confirmada. O caso Corona sem luz, no qual o usuário observou máscara/alpha sem conteúdo no Beauty, não foi usado para justificar luz automática. A E9 resolveu o problema pelo overlay isolado: o material temporário fica visível diretamente e no alpha sem depender de iluminação.

O app não deve aparentar uma cor no VFB e salvar outra sem avisar. PNG serve ao fluxo rápido; EXR preserva maior liberdade de composição.

## Corona adapter

O Corona é o gate de qualidade do MVP. A prova da E9 comparou as capacidades necessárias e adotou:

1. `CoronaLightMtl` visível diretamente e no alpha;
2. `emitLight = false`, para não iluminar a cena nem participar como luz do LightMix;
3. reflexos e refrações desligados durante o passe isolado;
4. `renderElements:false` e `vfb:false`, preservando o setup de produção.

A escolha foi confirmada em Corona 13 no 3ds Max 2026.3: splines e TextPlus apareceram no PNG 160 × 90, com `1338` pixels opacos de anotação e `13062` pixels transparentes de fundo. A geometria comum da cena foi excluída e restaurada ao final. A matriz de desempenho com 100, 500 e 1000 cotas permanece para a estabilização da E10.

O adapter não cria LightSelect, não executa setup de LightMix e não reaproveita o canal LightMix. O arquivo de cotas nasce independente e é composto depois.

O serviço comum preserva a viewport/câmera ativa e herda frame, resolução, pixel aspect e Crop/Region. O nome automático inclui cena e frame, e conflitos recebem sufixo incremental. Somente o adapter Corona conhece `CoronaLightMtl`; a futura implementação V-Ray reutilizará o mesmo contrato de request, isolamento, verificação e restauração.

## V-Ray CPU adapter

O V-Ray precisa entregar o mesmo contrato, não necessariamente usar as mesmas propriedades internas. Os candidatos são VRayMtl com self-illumination ou VRayLightMtl, com GI desativada e exposição controlada.

O Render Mask do V-Ray não será a base do isolamento. Segundo a documentação, pixels fora da máscara permanecem intactos no VFB, e objetos semitransparentes à frente ainda podem aparecer. O Ameno precisa gerar um arquivo novo, transparente e determinístico; por isso começa isolando os nós Ameno pelo estado renderizável, sempre com snapshot e restore.

As correções do V-Ray VFB também são tratadas explicitamente: algumas podem ser gravadas nos canais e outras são apenas de display. O adapter registra qual caminho produziu o arquivo para evitar dupla correção no Photoshop.

## V-Ray GPU

V-Ray GPU não herda automaticamente o selo do V-Ray CPU. A Chaos documenta diferenças de recursos entre engines, mesmo quando Render Mask e materiais comuns são suportados. O diagnóstico identifica a engine e, enquanto a matriz estiver incompleta, marca o modo como experimental.

Se o usuário estiver em GPU, o app pode:

- executar quando todas as capacidades necessárias forem verificadas;
- oferecer uma prova rápida de alpha;
- sugerir V-Ray CPU quando faltar uma capacidade crítica;
- nunca trocar a engine do usuário sem confirmação.

## Troca de renderer na mesma cena

As cotas persistem com estilos lógicos, como `annotation-dark`, e não com dependência oficial de um material Corona/V-Ray específico. Ao trocar o renderer:

1. o adapter anterior é descartado;
2. o novo adapter resolve os materiais derivados;
3. as definições e valores das cotas permanecem;
4. o diagnóstico pede um render de prova antes da saída final.

## Versões suportadas

A prova atual foi executada com Corona 13 e 3ds Max 2026.3. Isso registra uma combinação aprovada para desenvolvimento, mas ainda não define a versão mínima comercial; V-Ray também permanece sem versão mínima até a E10.

## Referências oficiais

- [Corona — recursos suportados e Advanced Render Selected](https://docs.chaos.com/display/CRMAX/Supported%2BFeatures)
- [Corona Light Material — emissão, visibilidade direta e alpha](https://docs.chaos.com/display/CRMAX/Corona%2BLight%2BMaterial)
- [Corona Physical Material — self-illumination e alpha mode](https://docs.chaos.com/display/CRMAX/Corona%2BPhysical%2BMaterial)
- [V-Ray Image Sampler — comportamento do Render Mask](https://docs.chaos.com/display/VMAX/Image%2BSampler)
- [V-Ray material — self-illumination e compensação de exposição](https://docs.chaos.com/display/VMAX/VRayMtl)
- [V-Ray Frame Buffer — salvamento e correções de cor](https://docs.chaos.com/display/VMAX/Frame%2BBuffer%2BSettings)
- [V-Ray GPU — recursos suportados](https://docs.chaos.com/display/VMAX/V-Ray%2BGPU%2BSupported%2BFeatures)
