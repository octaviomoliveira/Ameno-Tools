# Ameno Tools

Suíte modular de ferramentas para 3ds Max. O primeiro módulo, **Ameno Dimensions**, cria cotas gráficas e associativas para plantas humanizadas.

## Estado

Projeto em especificação e fundação técnica. Ainda não existe uma build executável.

Decisões já tomadas:

- MAXScript no primeiro MVP;
- pacote oficial `ApplicationPlugins` desde o início;
- cotas persistentes no arquivo `.max`;
- layer `AMENO_COTAS` criada e gerenciada automaticamente;
- geometria renderizável, não apenas overlay de viewport;
- MVP com botão `Renderizar Cotas` para gerar overlay transparente independente;
- nenhuma alteração automática no Beauty, LightMix ou Render Elements do usuário;
- dados separados da representação gráfica;
- arquitetura preparada para núcleo C++ futuro;
- sem dependência de índices frágeis de vértice no MVP.

Decisões pendentes:

- versão principal e versão mínima do 3ds Max;
- renderizador prioritário;
- interface apenas em português ou bilíngue;
- licença e modelo de distribuição;
- serviço e visibilidade do repositório remoto.

## Documentação

- [Especificação do produto](docs/product-spec.md)
- [Arquitetura técnica](docs/architecture.md)
- [Experiência e fluxos de uso](docs/interaction-and-workflows.md)
- [Formato dos dados de cena](docs/scene-data-schema.md)
- [Plano de testes](docs/test-plan.md)
- [Roadmap](ROADMAP.md)
- [ADR 0001 — MAXScript primeiro](docs/decisions/0001-maxscript-first.md)
- [ADR 0002 — Layer e saídas de render](docs/decisions/0002-layer-and-render-output.md)
- [ADR 0003 — Render separado no MVP](docs/decisions/0003-separate-overlay-render-mvp.md)

## Princípios

1. Uma cota comum deve exigir no máximo três cliques.
2. A ferramenta não deve modificar a arquitetura do usuário.
3. Nenhuma referência pode desaparecer silenciosamente.
4. Salvar e reabrir a cena deve preservar dados e aparência.
5. Atualizações derivadas não devem poluir o histórico de Undo.
6. O usuário sempre pode converter uma cota em geometria comum.
7. O arquivo deve continuar abrindo sem o Ameno Tools instalado.

## Licença

A definir. Enquanto não houver uma licença explícita, o código não deve ser considerado liberado para redistribuição.
