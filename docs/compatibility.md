# Estratégia de versões do 3ds Max

## Decisão atual

O primeiro Ameno Dimensions será desenvolvido e suportado oficialmente no 3ds Max 2026 para Windows. Resolver bem o uso real no 2026 tem prioridade sobre manter compatibilidade antecipada com versões antigas.

Isso significa que o MVP pode usar uma API exclusiva do 2026 quando ela trouxer uma vantagem concreta de interface, estabilidade ou desempenho. Não vamos remover uma boa solução nem criar fallbacks sem antes comprovar que a portabilidade é necessária.

## O que preservaremos desde o início

Portabilidade não exige limitar o produto. Exige apenas evitar acoplamentos que já seriam ruins no próprio 2026:

- medição, arredondamento e formatação ficam fora da UI;
- o schema persistente das cotas é próprio e versionado;
- TextPlus, splines, viewport, layer e render são representações derivadas;
- o painel abre por uma ação MacroScript bem definida;
- integrações do Max ficam concentradas por responsabilidade;
- chamadas e propriedades exclusivas do host não entram nos dados de domínio.

Essas fronteiras são justificadas pelo design atual, mesmo que nunca exista uma versão para o Max 2021.

## O que não faremos no MVP

- seis ambientes de desenvolvimento;
- matriz de regressão 2021–2026;
- dois sistemas de menus;
- detecção de capacidade para recursos que só têm uma implementação;
- UI reduzida ao menor denominador comum;
- promessa de abrir no 2021 um `.max` salvo no 2026;
- builds C++ para SDKs que ainda não são alvo.

## Caminho de expansão depois do MVP

Quando a build do 2026 estiver estável, a portabilidade vira um trabalho mensurável:

1. congelar cenas-fixture e o comportamento esperado do 2026;
2. inventariar as APIs realmente utilizadas;
3. testar a versão anterior de maior demanda;
4. listar diferenças reais, em vez de presumidas;
5. criar adapters somente nos pontos divergentes;
6. decidir se cada fallback mantém a qualidade mínima do produto;
7. executar a matriz completa antes de anunciar suporte.

O Max 2025 é o primeiro candidato técnico porque usa a geração nova do sistema de menus. A travessia para 2024 e anteriores introduz a fronteira do menu legado. Isso não impede o núcleo das cotas, mas aumenta instalação, UI e testes.

## Possível estrutura futura

Somente quando duas implementações existirem, o pacote pode ganhar uma camada como:

```text
compat/
  host_capabilities.ms
  modern_menu_adapter.ms      # 2025+
  legacy_menu_adapter.ms      # 2021–2024
```

O domínio e o schema de cena permanecem os mesmos. Se houver um plugin C++ no futuro, cada release suportada poderá precisar de um build com seu SDK correspondente.

## Política de suporte

Uma versão do Max terá um destes estados:

- `suportada`: passou a matriz completa da release;
- `experimental`: testada parcialmente, sem compromisso de produção;
- `não suportada`: não testada ou bloqueada pelo pacote.

No MVP:

| Versão | Estado |
|---|---|
| 3ds Max 2026 | suportada após aprovação da release |
| 3ds Max 2021–2025 | não suportada; avaliação futura |

## Referências oficiais

- [Migração do sistema de menus no 3ds Max 2025](https://help.autodesk.com/cloudhelp/2025/ENU/MAXDEV-Developer/files/3ds_max_sdk_features/user_interface/menu_system/menu_migration_guide.html)
- [Formato do PackageContents.xml no 3ds Max 2026](https://help.autodesk.com/cloudhelp/2026/ENU/MAXDEV-Developer/files/writing_plug-ins/plugin_package/packagexml_format.html)
- [Empacotamento de plugins no 3ds Max 2026](https://help.autodesk.com/cloudhelp/2026/ENU/MAXDEV-Developer/files/writing_plug-ins/plugin_package/packaging_plugins.html)
