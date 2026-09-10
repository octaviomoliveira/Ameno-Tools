# Evidência visual E19 — Cotar

## Captura automatizada

- Arquivo: `01-cotar-980x720.png`
- Tamanho da janela: 980×720 px.
- SHA-256: `95073F044CB4F162FED0FAFADE43949D421DC858443AD7777299A6C1326962F4`
- Resultado: quatro cards íntegros, CTA visível e scrollbar horizontal em zero.
- Testes associados: `tests/python/test_e19_cotar_reference.py`.

Esta captura foi gerada com Qt offscreen. Ela valida composição e regressão,
mas não substitui a captura e o aceite dentro do 3ds Max 2026 com DPI e fonte
do host real.

## Página Estilo

- `02-estilo-980x720.png`: duas colunas, preview e rodapé fixos.
- SHA-256: `663AF469B6E27AD02D576F7D3C4316555ADAB83100C944FF3B97FEAD3F7C1F6B`.
- `03-estilo-780x560.png`: preview acima, controles em scroll próprio e rodapé
  fixo.
- SHA-256: `71E71DDB758DA298E91928364C85211C3270F1538FE73F67927BD0F97C3663B4`.
- Referência: `work/e19-reference/02-estilo-target.png`.
- Testes: `tests/python/test_e19_style_workspace.py`.
