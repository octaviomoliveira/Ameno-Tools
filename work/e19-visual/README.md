# Evidência visual E19 — Cotar

## Captura automatizada

- Arquivo: `01-cotar-980x720.png`
- Tamanho da janela: 980×720 px.
- SHA-256: `AF6B36D5CCF0D4A63C3F825EC1D795E2FA0FDEF69ACEC631678C6F267B7E6EBE`
- Resultado: quatro cards íntegros, CTA visível e scrollbar horizontal em zero.
- Testes associados: `tests/python/test_e19_cotar_reference.py`.
- `05-cotar-default-780x720.png`: abertura vertical padrão, com `Preparar cena`
  visível dentro do estado e menu reservado à manutenção.
- SHA-256: `86DB9B3D0445473BCA4683016D9E5AD6275B6BC81081543C672C08DE30831AE4`.

Esta captura foi gerada com Qt offscreen. Ela valida composição e regressão,
mas não substitui a captura e o aceite dentro do 3ds Max 2026 com DPI e fonte
do host real.

## Página Estilo

- `02-estilo-980x720.png`: duas colunas, preview e rodapé fixos.
- SHA-256: `59A77CD15A8099AB27E3DDD7B8321E67DF50BB0E353067F5C49484662CBD7212`.
- `03-estilo-780x560.png`: preview acima, controles em scroll próprio e rodapé
  fixo.
- SHA-256: `71E71DDB758DA298E91928364C85211C3270F1538FE73F67927BD0F97C3663B4`.
- `04-estilo-default-780x720.png`: abertura vertical padrão, preview fixo acima
  e controles em scroll independente.
- SHA-256: `2FB5959BE4AD606968ABE0939C5AD7CE8804658607FEA272B67B99598886F82F`.
- Referência: `work/e19-reference/02-estilo-target.png`.
- Testes: `tests/python/test_e19_style_workspace.py`.
