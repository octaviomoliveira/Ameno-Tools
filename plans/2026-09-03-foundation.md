# Handoff — Fundação do Ameno Tools

**Data:** 2026-09-03  
**Estado:** fundação `0.0.1` validada; criação de cotas ainda não implementada.

## O que existe

- Pacote `ApplicationPlugins` para 3ds Max em `PackageContents.xml`.
- Macro `AmenoTools_Open` e painel inicial do Ameno Tools.
- Bootstrap MAXScript modular em `Contents/scripts/startup/`.
- Verificação de renderer por adapters, sem dependência direta de Corona ou V-Ray no núcleo.
- Scripts de validação, instalação de desenvolvimento e smoke test real em `tools/`.
- Especificações do produto, arquitetura, render, estilo, valores manuais, dados de cena e testes em `docs/`.

## Verificações realizadas

- Manifesto e estrutura do pacote validados por `tools/validate-package.ps1`.
- Smoke test executado com 3ds Max Batch 2026.3.
- Instalação de desenvolvimento confirmada no perfil de ApplicationPlugins do usuário.

## Decisões consolidadas

- Primeiro alvo: 3ds Max 2026. Compatibilidade 2021–2025 não pode impedir o MVP.
- Renderer de referência: Corona. V-Ray CPU entra por adapter; V-Ray GPU segue experimental até sua validação.
- Cotas pertencem à layer `AMENO_COTAS`; dados auxiliares pertencem a `AMENO_SYSTEM`.
- O Beauty e a configuração existente de LightMix/Render Elements não devem ser alterados automaticamente.
- A exportação inicial é o comando **Renderizar Cotas**, que gera um overlay transparente separado para compor em Photoshop.
- A cota possui valor medido, valor exibido arredondado e possível valor manual independente.
- Alteração manual é destacada somente em viewport, sem contaminar a renderização.

## Primeiro incremento recomendado

Implementar uma cota linear de três cliques:

1. origem;
2. destino;
3. posição da linha de cota.

O incremento deve criar as layers quando necessário, gravar um identificador de cota e seus pontos, desenhar linhas/terminadores/texto simples e suportar Undo. Antes de avançar para editor TextPlus-like, render ou associatividade automática, validar salvar/reabrir da cena e remoção correta.

## Leituras mínimas antes de editar

- `PLAN.md`
- `docs/architecture.md`
- `docs/scene-data-schema.md`
- `docs/interaction-and-workflows.md`
- `docs/test-plan.md`

