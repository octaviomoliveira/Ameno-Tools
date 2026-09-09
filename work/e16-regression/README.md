# E16 — regressão e evidência

Execução final: 2026-09-09, 3ds Max 2026.3 Batch isolado, uma suíte por vez.
Cada log da rodada está em
[`run-20260909-final`](run-20260909-final/); o pacote instalado foi validado
separadamente antes da rodada E16 final.

## Resultados principais

| Suíte | Resultado | Observação |
| --- | --- | --- |
| `test_e16_overlay_model.ms` | 27/27 PASS | modelo/terminais/revision sem nós |
| `test_e16_mousemove_no_scene.ms` | 13/13 PASS | 1.000 moves; 5,120 s de harness; zero full resolve/mutação |
| `test_e16_callback_lifecycle.ms` | 6/6 PASS | 100 ciclos; cardinalidade 0/1/0 |
| `test_vertical_performance.ms` | PASS | H: 0,2442 ms/cálculo; V: 0,2488 ms/cálculo; overlay=3, nodes=0 |
| `test_e16_commit_performance.ms` | 17/17 PASS | 7 segmentos em 181 ms; prepare 1 ms; material 1 ms; Undo/Redo e rollback |
| `test_e15_qt_bridge.ms` | PASS | launcher Python/Qt e snapshots preservados |
| `test_installed_package.ms` | PASS | pacote carregado via `ApplicationPlugins` |

## Matriz histórica executada

As seguintes suítes também terminaram com exit code 0, marcador PASS explícito
e zero marcador FAIL: R2 picking, R3 preview, cadeia/rollback, R1 lifecycle,
R4 transaction, E13 stage5 terminals, E13 text commit position, E14 plane
math, E14 tools, E14 graphics e E14 camera plane. Os respectivos logs estão
na pasta da rodada.

## Comandos

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-package.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-maxscript.ps1 \
  -TestScript .\tests\maxscript\test_e16_commit_performance.ms
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-maxscript.ps1 \
  -TestScript .\tests\maxscript\test_installed_package.ms
```

O assistente manual `manual_e16_viewport_soak.ms` também foi carregado em Batch
com exit code 0. Isso valida a sintaxe e a coleta de snapshot, mas não substitui
a confirmação humana de fluidez, clipping, câmeras e DPI em uma viewport real.

## Instalação e recuperação

- manifesto fonte e instalado: SHA-256
  `B729045EA01509DF3514E0474CFAE5A388D8BE00B8C159155D502AD0E78FF2C4`;
- backup recuperável do pacote ativo:
  `work/e16-backups/AmenoTools.active-before-e16-final-20260909-050905`;
- os cinco diretórios de backup antigos foram retirados de
  `ApplicationPlugins` e guardados em `work/e16-backups/legacy/`, deixando um
  único pacote ativo para o próximo processo do Max.
- pacote canário final: `AmenoTools-E16-20260909-final.zip`;
- SHA-256 do pacote final: `4AC732C15627109D3497E4F1CE21333E32406FDF9D8EC51DFAD7AE7BD78ADE31`
  (também em `AmenoTools-E16-20260909-final.zip.sha256`).

## Limitações declaradas

O soak visual E16.9 (20 sessões, cena problemática, câmeras/DPI e interação da
janela) ainda depende de uma sessão interativa nova. O Max interativo que já
estava aberto não foi encerrado à força para não perder uma cena não salva;
portanto este gate não é marcado como concluído por inferência.
