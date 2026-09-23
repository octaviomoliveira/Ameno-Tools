# E20.3 — Cotar como fluxo vertical principal

Data: 2026-09-23. Branch: `feature/e20-vertical-adaptive-ui`. Base da etapa:
`d028a90` (E20.2). A instalação do 3ds Max não foi alterada. Nenhum arquivo
MAXScript, do bridge ou do núcleo foi modificado.

## Decisões de apresentação

- **Cartão de cena só com fatos da cena:** estado, detalhe informado pelo
  núcleo, contagem de cotas e uma única ação coerente com o estado. O resumo
  das escolhas saiu do cartão e virou a linha de contexto logo acima do CTA.
- **Ação da cena por estado real** (`ameno_scene_setup.ms`):

  | Estado | Ação | Comando | Indicador |
  | --- | --- | --- | --- |
  | não verificada | Preparar cena | `prepareSceneCommand` | neutro |
  | `notPrepared` | Preparar cena | `prepareSceneCommand` | neutro |
  | `requiresRepair` | Reparar cena | `prepareSceneCommand` | aviso |
  | `error` | Tentar novamente | `prepareSceneCommand` | erro |
  | `ready` | Atualizar estado | `refresh` | pronto |

  Em cena pronta, `prepare()` do núcleo é no-op; por isso a ação só relê o
  estado. Quando o núcleo recusa o reparo (ex.: registros Ameno duplicados), a
  página mostra erro com o detalhe em vez de sucesso.
- **Automática autoexplicativa:** o próprio segmento desabilitado carrega
  tooltip e descrição acessível com a regra; a mensagem abaixo da direção e o
  modal de fallback no início foram mantidos.
- **Cotação em andamento:** CTA muda para "Cotação em andamento…", todas as
  decisões (inclusive Direção, antes esquecida) ficam travadas e a mensagem
  explica viewport, Esc e Ctrl+Z. O travamento não reabilita Automática em
  Várias medidas.
- **CTA + Mais ações:** lado a lado; abaixo de 480 px de largura de página
  empilham com a mesma largura, sem rolagem horizontal.
- Contagem no singular/plural ("1 cota", "3 cotas").
- Densidade dos quatro cartões reavaliada e mantida: o fluxo completo cabe em
  780×720 sem rolagem.

## Evidência local

- `cotar-96dpi.json` e `cotar-144dpi.json`: 8 PASS / 0 FAIL
  (`tests/python/test_e20_cotar_contracts.py`, 7 REDs antes da implementação).
- `shell-*.json`: 8/8; `window-*.json`: 20/20, nos dois DPIs.
- `legacy.json`: 69 PASS / 0 FAIL.
- `gallery-96dpi/`: Cotar em 780×720, 780×1020, 980×720 e 1280×800 com CTA
  inteiro visível e zero rolagem (horizontal e vertical). 780×560 continua
  como compressão: CTA por rolagem vertical, zero rolagem horizontal.
- `states-96dpi/`: não preparada, requer reparo, erro, pronta, em andamento e
  concluída em 780×1020 e 440×1020.
- `tools/validate-package.ps1`: pacote válido para Max 2026.
- `test_e20_preview_contracts.py` segue com 9 REDs, previstos para E20.4.

## Limites

- Evidência Qt offscreen com CPython 3.11 + PySide6 6.5.3 (venv local em
  `.test-output/`). As suítes MAXScript e o aceite no 3ds Max não rodaram nesta
  máquina (Max ausente); a mudança não toca MAXScript nem o bridge. Aceite
  visual e instalação seguem em E20.8.
- Em 440 px o texto do cartão de cena quebra em várias linhas, sem truncar.
  Reorganizar o cartão para largura estreita fica como nota, não como gate.

## Reprodução

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-cotar --report work/e20-cotar/cotar-96dpi.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite legacy --report work/e20-cotar/legacy.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --capture .test-output/gallery
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-cotar --report work/e20-cotar/cotar-144dpi.json
```
