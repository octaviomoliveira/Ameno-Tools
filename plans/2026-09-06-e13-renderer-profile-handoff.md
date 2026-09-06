# Handoff — E13: perfis globais, cor de render e guarda do renderer

Data: 2026-09-06
Estado: IMPLEMENTADA/TESTADA NO WORKTREE E INSTALADA; gate manual pendente

## Contexto e causa confirmada

O log real `C:\Users\octav\AppData\Local\AmenoTools\Logs\ameno-20260906-180520-144.log` registrou:

```text
Renderer: Arnold · sem adapter
Falha no overlay de cotas: render: -- Known system exception
EXCEPTION_ACCESS_VIOLATION
```

O despacho anterior mantinha Corona como fallback quando a família do renderer não era reconhecida. Isso permitia que uma chamada antiga chegasse ao `render()` com adapter incompatível. A cópia instalada foi conferida antes da substituição: `ameno_cotas_render_tab.ms` em `%APPDATA%\Autodesk\ApplicationPlugins\AmenoTools` tinha SHA-256 diferente do worktree e não continha a guarda nova. Ela foi preservada em `D:\Ameno\backups\AmenoTools-before-e13-render-guard-20260906`; depois o Max foi confirmado fechado e a versão atual foi instalada.

## Alterações

- `Contents/scripts/ameno/renderers/ameno_renderer_probe.ms`: detecção protegida, classe real e `detailedLabel()`.
- `Contents/scripts/ameno/core/ameno_render_cotas_service.ms`: despacho sem fallback, compatibilidade por `adapterId`, revalidação imediatamente antes do render, log do renderer/adapter e materiais agrupados por RGB.
- `Contents/scripts/ameno/ui/ameno_cotas_render_tab.ms`: banner com nome/classe, botão desabilitado para renderer sem adapter e revalidação no clique.
- `Contents/scripts/ameno/core/ameno_diagnostic_service.ms` e `ameno_runtime.ms`: classe do renderer incluída no diagnóstico e no log de startup.
- `Contents/scripts/ameno/core/ameno_style_service.ms`: biblioteca global em `%LOCALAPPDATA%\AmenoTools\Profiles\styles.library`, backup `.bak`, escrita temporária `.tmp`, precedência scene-local e persistência de cor.
- `Contents/scripts/ameno/core/ameno_dimension_graphics.ms` e adapters Corona/V-Ray: `annotationColor` encaminhada ao material temporário; chamada sem `camera:` quando não há câmera; capacidades Corona tratadas sem depender de uma versão única.
- `tests/maxscript/test_e13_global_styles_render_color.ms`: persistência global, RGB, materiais por cor e encaminhamento ao adapter.
- `tests/maxscript/test_e10_3_vray.ms` e `test_bootstrap.ms`: despacho por família, rejeição de adapter obsoleto e identificação detalhada.
- `docs/decisions/0022-e13-global-style-library-renderer-guard.md`: decisão durável.

## Testes e evidências

Todos os comandos abaixo foram executados no worktree `D:\Ameno\_worktrees\develop` com `tools/test-maxscript.ps1 -TestScript ...`, exit 0 e zero marcadores `[FAIL]`:

| Suíte | Resultado |
|---|---:|
| `test_bootstrap.ms` | 1 PASS |
| `test_e10_3_vray.ms` | 18 PASS |
| `test_e10_4_diagnostics.ms` | 1 PASS |
| `test_e11_4_persistence.ms` | 1 PASS |
| `test_e11_5_integration.ms` | 1 PASS |
| `test_e12_r0_diagnostics.ms` | 1 PASS |
| `test_e13_stage3_styles.ms` | 25 PASS |
| `test_e13_global_styles_render_color.ms` | 13 PASS |
| `test_e13_stage6_render_restore.ms` | 20 PASS |
| `test_e13e.ms` | 9 PASS |
| `test_e9_corona_render.ms` | 1 PASS |

O teste real Corona executou com `Corona 15 (Hotfix 1)`, registrou `Corona [Corona]`, criou `CoronaLightMtl`, produziu PNG com alpha e foi visualmente conferido em `D:\Ameno\_worktrees\develop\.test-output\e9_corona_real.png`. O runner também foi validado contra o caso PASS+FAIL: ele exige exit 0, ao menos um PASS e zero FAIL.

Após a instalação, a conferência do `ApplicationPlugins` encontrou 41/41 arquivos de conteúdo e `PackageContents.xml` idênticos por SHA-256 (`MISSING=0`, `DIFFERENT=0`). `test_installed_package.ms` terminou com exit 0, 1 `[AMENO_INSTALLED_TEST][PASS]` e 0 FAIL; o log dessa execução registra `Renderer: Arnold [Arnold] · sem adapter` e não chama render para Arnold.

Pacote estrutural:

- `tools/validate-package.ps1`: PASS.
- `dist/AmenoTools-0.0.1-e13-render-guard-20260906.zip`: 47 entradas; SHA-256 `F26A568B90041A86C799131936F64005FB8FC0554FA7C128598BBC9DA16F7252`.
- O ZIP contém bootstrap, service de estilos, service de render, probe de renderer, aba Render e guia do usuário.

## Ainda pendente

- Gate manual em cena descartável: banner `Corona [classe]`/`V-Ray [classe]`, render Corona 15 com cor escolhida, persistência após reinício e bloqueio informativo em Arnold. Não pressionar Enter durante a cotação.
- Render real V-Ray CPU e qualquer suporte a GPU.
- Publicação/merge/push continuam fora deste handoff.

## Estado Git

- Branch: `develop`.
- HEAD antes do commit deste handoff: `e0455d6`.
- Alterações funcionais e documentais estão pendentes de commit neste momento; `tests/maxscript/batch-isolated.ini` permanece preservado. A instalação ativa corresponde ao worktree atual, ainda não a um commit publicado.

## Próximo passo exato

1. Usuário reabre o Max normalmente com o hotfix já instalado.
2. Fazer apenas o gate manual descrito acima em cena descartável; em Arnold, confirmar o bloqueio informativo sem tentar renderizar.
3. Se o gate passar, registrar aprovação e decidir publicação; V-Ray CPU real continua sendo uma validação separada.
