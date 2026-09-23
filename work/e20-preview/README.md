# E20.4 — Prévia 2D fiel à cota confirmada

Data: 2026-09-23. Branch: `feature/e20-vertical-adaptive-ui`. Base da etapa:
`2eb6e26` (E20.3). A instalação do 3ds Max não foi alterada. Nenhum arquivo
MAXScript, do bridge ou do núcleo foi modificado.

## Modelo

`dimension_preview.py` passou a montar a amostra em milímetros e a converter
tudo com **uma única escala**, como `toSceneUnits` faz na cota confirmada:
terminal, recuo, prolongamento, espessura, texto, afastamento e máscara. Os
clamps e fatores independentes antigos foram removidos.

| Elemento | Oráculo MAXScript | Prévia |
| --- | --- | --- |
| Seta fechada | `createTerminal`: meia base `size*0.25`, corpo para dentro | idem |
| Seta aberta | `addTerminals`: asas `size*0.25`, corpo para dentro | idem |
| Traço | `addTerminals`: `normalize(direction+perpendicular)*size/2` | idem ("/" em cota da esquerda para a direita) |
| Ponto | `createTerminal`: raio `size*0.35` | idem |
| Losango | `createTerminal`: quatro vértices, diagonais `size` | idem, preenchido |
| Recuo/prolongamento | `updateLineSplinePoints` | idem, mesma escala |
| Texto | `updateTextNodePosition`: meio da linha + `textGap` | idem |

- **Posicionamento e ângulo:** a cota confirmada ignora os dois, e a prévia
  agora também (decisão do usuário em 2026-09-23). Os dois testes E18 que
  cobravam a resposta visual foram atualizados. O overlay de cotação ainda os
  aplica; a divergência continua registrada para etapa funcional própria.
- **Enquadramento:** em 100% o conjunto inteiro (parede, cota, terminais e
  rótulo) cabe no canvas; 50% reduz a mesma escala. Acima de 100% (zoom ou
  escala da prévia) o foco passa para o terminal esquerdo e o rótulo.
- **Amostra adaptativa:** canvas paisagem (2:1 ou mais) mede 3,50 m; canvas
  estreito ou alto mede uma parede menor, até 1,20 m, e o rótulo acompanha.
  As proporções continuam físicas; o texto fica legível no layout lateral.
- **Painter:** losango preenchido; a caneta nunca fica abaixo de 1 pixel de
  dispositivo. O modelo mantém a espessura nominal.

## Evidência local

- `preview-96dpi.json` e `preview-144dpi.json`: 14 PASS / 0 FAIL. Os 9 REDs de
  E20.0 ficaram verdes; 5 contratos novos cobrem extremos legais de todos os
  terminais (finitos e dentro do canvas em 50% e 100%), escala da prévia,
  foco ampliado, amostra estreita e custo por reconstrução (< 2 ms).
- `cotar-*`: 8/8; `shell-*`: 8/8; `window-*`: 20/20, nos dois DPIs.
- `legacy.json`: 69 PASS / 0 FAIL (dois testes E18 atualizados como acima).
- `preview-96dpi/`: presets Arquitetônico, Editorial e Técnico, seta aberta,
  losango, fundo claro, cor própria, 50%, 200% e texto extremo.
- `gallery-96dpi/`: Estilos nas cinco geometrias; prévia, controles e rodapé
  sem sobreposição e sem rolagem horizontal.
- `tools/validate-package.ps1`: pacote válido para Max 2026.

## Limites e notas

- Largura do texto é estimada (avanço 0,56 da altura; tracking TextPlus como
  1% da altura por unidade). Tipografia e antialiasing exigem conferência no
  host, em E20.8.
- Cor padrão da cota (245,245,245) quase desaparece com "Fundo escuro"
  desligado. É fiel ao estilo; sinalizar isso ao usuário é assunto de Cores
  na E20.5.
- As suítes MAXScript e o aceite no 3ds Max não rodaram nesta máquina (Max
  ausente).

## Reprodução

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-preview --report work/e20-preview/preview-96dpi.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite legacy --report work/e20-preview/legacy.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --capture .test-output/gallery
& .\.test-output\e20-venv\Scripts\python.exe work/e20-preview/preview_sheet.py work/e20-preview/preview-96dpi
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-preview --report work/e20-preview/preview-144dpi.json
```
