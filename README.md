# Ameno Tools

Suíte modular de ferramentas para 3ds Max. O primeiro módulo, **Ameno Dimensions**, cria cotas gráficas e associativas para plantas humanizadas.

## Estado

Fundação técnica `0.0.1` executável no 3ds Max 2026. As etapas E1 a E8.1 foram concluídas e aprovadas interativamente: infraestrutura de cena idempotente (`AMENO_COTAS`), construtor gráfico de cotas com ferramenta de três cliques, persistência atômica via Custom Attributes versionados, medições auditáveis com overrides manuais, editor visual de estilos com tipografia TextPlus e terminais vetoriais, e âncoras associativas com reatividade contínua em tempo real e resiliência a cotas órfãs. A E9 está implementada, aprovada em testes automatizados e instalada para o gate manual: o rollout `Render Separado de Cotas` gera um PNG transparente independente no Corona sem modificar Beauty, LightMix ou Render Elements.


Decisões já tomadas:

- MAXScript no primeiro MVP;
- desenvolvimento principal no 3ds Max 2026;
- primeira versão oficialmente suportada somente no 3ds Max 2026;
- arquitetura sem acoplamentos desnecessários ao 2026, para avaliar 2021–2025 depois do MVP;
- pacote oficial `ApplicationPlugins` desde o início;
- cotas persistentes no arquivo `.max`;
- layer `AMENO_COTAS` criada e gerenciada automaticamente;
- geometria renderizável, não apenas overlay de viewport;
- MVP com botão `Renderizar Cotas` para gerar overlay transparente independente;
- nenhuma alteração automática no Beauty, LightMix ou Render Elements do usuário;
- Corona como renderer de referência e gate obrigatório do MVP;
- V-Ray CPU como segundo renderer oficial, implementado por adapter separado;
- V-Ray GPU tratado separadamente até passar sua própria matriz;
- valores medidos, arredondados e manuais mantidos separadamente;
- cotas manuais destacadas somente na viewport;
- dados separados da representação gráfica;
- arquitetura preparada para núcleo C++ futuro;
- sem dependência de índices frágeis de vértice no MVP.

Decisões pendentes:

- versões mínimas de Corona e V-Ray após testar o ambiente real;
- interface apenas em português ou bilíngue;
- licença e modelo de distribuição;
- serviço e visibilidade do repositório remoto.

## Documentação

- [Especificação do produto](docs/product-spec.md)
- [Arquitetura técnica](docs/architecture.md)
- [Experiência e fluxos de uso](docs/interaction-and-workflows.md)
- [Editor de estilos: texto, linhas e setas](docs/style-editor.md)
- [Valores manuais e avisos de viewport](docs/manual-overrides.md)
- [Formato dos dados de cena](docs/scene-data-schema.md)
- [Plano de testes](docs/test-plan.md)
- [Estratégia de versões do 3ds Max](docs/compatibility.md)
- [Compatibilidade com Corona e V-Ray](docs/renderers.md)
- [Roadmap](ROADMAP.md)
- [Plano compartilhado de execução](PLAN.md)
- [Histórico de planos e handoffs](plans/README.md)
- [ADR 0001 — MAXScript primeiro](docs/decisions/0001-maxscript-first.md)
- [ADR 0002 — Layer e saídas de render](docs/decisions/0002-layer-and-render-output.md)
- [ADR 0003 — Render separado no MVP](docs/decisions/0003-separate-overlay-render-mvp.md)
- [ADR 0004 — Sobrescritas manuais auditáveis](docs/decisions/0004-auditable-manual-overrides.md)
- [ADR 0005 — Max 2026 primeiro](docs/decisions/0005-max-2026-first.md)
- [ADR 0006 — Corona primeiro, V-Ray compatível](docs/decisions/0006-corona-primary-vray-secondary.md)
- [ADR 0013 — Overlay separado de cotas no Corona](docs/decisions/0013-e9-corona-separate-overlay.md)

## Princípios

1. Uma cota comum deve exigir no máximo três cliques.
2. A ferramenta não deve modificar a arquitetura do usuário.
3. Nenhuma referência pode desaparecer silenciosamente.
4. Salvar e reabrir a cena deve preservar dados e aparência.
5. Atualizações derivadas não devem poluir o histórico de Undo.
6. O usuário sempre pode converter uma cota em geometria comum.
7. O arquivo deve continuar abrindo sem o Ameno Tools instalado.

## Desenvolvimento local

Validar o manifesto e os arquivos do pacote:

```powershell
.\tools\validate-package.ps1
```

Executar o smoke test dentro do 3ds Max 2026 Batch:

```powershell
.\tools\test-maxscript.ps1
```

Executar a prova real da E9 com Corona instalado:

```powershell
.\tools\test-maxscript.ps1 -TestScript tests\maxscript\test_e9_corona_render.ms
```

Instalar a cópia de desenvolvimento no perfil do usuário:

```powershell
.\tools\install-dev.ps1
```

Depois de reiniciar o Max, abra `Customize User Interface`, procure a categoria `Ameno Tools` e associe a ação `AmenoTools_Open` a uma toolbar ou atalho. O painel deve mostrar a versão, a classe do renderer e um dos estados `suportado`, `experimental` ou `sem adapter`.

O pacote segue o formato oficial `ApplicationPlugins`: [PackageContents.xml](PackageContents.xml) é carregado pelo Max, [AmenoTools.mcr](Contents/macroscripts/AmenoTools.mcr) registra a ação e [ameno_bootstrap.ms](Contents/scripts/startup/ameno_bootstrap.ms) carrega os módulos em ordem explícita.

## Licença

A definir. Enquanto não houver uma licença explícita, o código não deve ser considerado liberado para redistribuição.
