# E20.7 — Matriz de aceite técnico (parte Qt)

Data: 2026-09-23. Branch: `feature/e20-vertical-adaptive-ui`. Base da etapa:
`2510823` (E20.6). A instalação do 3ds Max não foi alterada. Nenhum arquivo
MAXScript, do bridge ou do núcleo foi modificado.

**Estado:** parte Qt/Python fechada. A matriz MAXScript E16–E19 (item 6 do
plano) **não rodou**: esta máquina não tem 3ds Max 2026. O gate da E20.7 só
fecha depois dela.

## Matriz automatizada (`tests/python/test_e20_acceptance_contracts.py`)

| Item do plano | Contrato | Resultado |
| --- | --- | --- |
| 1. Geometrias e DPI | 780×1020, 780×720, 980×720, 1280×800, 780×560, 440×1020 e maximizada; 96 e 144 DPI | verde |
| 2. Clipping/overflow | Cinco páginas em estado cheio (cena com reparo, Várias medidas, detalhes abertos, todas as seções de Estilos, cota carregada em Revisar, detalhes de Configurações): rolagem horizontal, botões abaixo do mínimo, rótulos sem quebra, rótulos com quebra, spinboxes com sufixo, placeholders e combos | verde |
| 3. Teclado e tooltips | Tab do rail até a ação principal de cada página, Shift+Tab e volta; Espaço/Enter no rail, nos cartões e em Ajustar detalhes; todo botão só com ícone tem nome acessível e tooltip | verde |
| 4. Desempenho | Resize médio 34 ms (96 DPI) e 71 ms (144 DPI); troca de página 2–3 ms; slider + repaint síncrono da prévia 0,7–0,9 ms por passo | verde (limites: 150 / 60 / 30 ms) |
| 5. Lifecycle | 100 ciclos abrir → navegar → (maximizar/restaurar a cada 10) → fechar: 100 chamadas `cancel` e nenhuma janela restante | verde |

Tudo com um bridge que falha em qualquer acesso à cena: zero chamadas além do
`cancel` previsto no fechamento.

## Causas corrigidas pela matriz

Todas em 440 px de largura; nas geometrias do plano a matriz já estava verde.

- **Direção em Cotar:** o segmento "Automática" ficava 4 px abaixo do mínimo.
  `SegmentedChoice` tira os ícones antes de apertar um rótulo e os devolve
  quando há espaço.
- **Controles de Estilos:** a coluna precisava de 5 px a mais que a área
  útil (rolagem horizontal escondida pela política da scroll area). Os quatro
  formulários quebram o rótulo acima do campo quando a linha não cabe.
- **Cor das cotas:** "Editar" ficava espremido; a largura mínima do valor
  hexadecimal passou a ser a medida do texto, sem folga fixa de 72 px.

Nenhuma correção escondeu scrollbar nem reduziu fonte.

## Evidência

- `acceptance-*.json`: 6/6 em 96 e 144 DPI.
- `pages-*` 7/7, `styles-*` 9/9, `preview-*` 14/14, `cotar-*` 8/8,
  `shell-*` 8/8, `window-*` 20/20; `legacy.json` 69/69.
- `gallery-96dpi/` e `gallery-144dpi/`: 25 capturas cada, com `metrics.json`.
- `before-after-96dpi/`: 25 composições ANTES (baseline E20.0) | DEPOIS, com
  página e dimensões no rótulo; `index.json` lista os pares.
- `tools/validate-package.ps1`: pacote válido para Max 2026.

## Pendências para fechar a E20.7

- Rodar a matriz MAXScript (`tests/maxscript`, mesma seleção da baseline em
  `work/e20-baseline/max-regression/summary.txt`) numa máquina com Max 2026.
- As medições de desempenho são offscreen; repetir no host com fontes reais.

## Reprodução

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-acceptance --report work/e20-acceptance/acceptance-96dpi.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite legacy --report work/e20-acceptance/legacy.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --capture work/e20-acceptance/gallery-96dpi
& .\.test-output\e20-venv\Scripts\python.exe work/e20-acceptance/before_after.py work/e20-baseline/qt-96dpi work/e20-acceptance/gallery-96dpi work/e20-acceptance/before-after-96dpi
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-acceptance --report work/e20-acceptance/acceptance-144dpi.json
```
