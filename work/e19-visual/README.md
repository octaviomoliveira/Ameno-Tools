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
- SHA-256: `1034CC97C2C8E0D09EAB529170912437DD572AF3560882FAA0DBDE07750DB2F9`.
- `03-estilo-780x560.png`: preview acima, controles em scroll próprio e rodapé
  fixo.
- SHA-256: `F24CE33B39AD8F34540C24213E22569CA0BA31C2D682C7D0BEA0F1ADB03AC34F`.
- `04-estilo-default-780x720.png`: abertura vertical padrão, preview fixo acima
  e controles em scroll independente. A amostra abre em 100% e recupera o
  contexto arquitetônico do WPF: parede, retornos, pontos medidos, extensões,
  linha, terminais e texto.
- SHA-256: `96669374B2DD2DB04E5F424640AB0E472102DE52C858A3A0F8E2A054BE7A31B7`.
- Referência: `work/e19-reference/02-estilo-target.png`.
- Testes: `tests/python/test_e19_style_workspace.py`.
