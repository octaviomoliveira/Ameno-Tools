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
- SHA-256: `87A673AB829CE787552F29DA33BD90B80A217681EFF9DCA890786AEE93FF74CA`.
- `03-estilo-780x560.png`: preview acima, controles em scroll próprio e rodapé
  fixo.
- SHA-256: `596A066D0C1A38B2BE3289CCDF4E6A0002A5D9059038C43474697D1F80AFC72F`.
- `04-estilo-default-780x720.png`: abertura vertical padrão, preview fixo acima
  e controles em scroll independente. A amostra abre em 100% e recupera o
  contexto arquitetônico do WPF: parede, retornos, pontos medidos, extensões,
  linha, terminais e texto. Em 100%, texto e terminais usam a escala normal
  legível; ticks são centrados e setas respeitam corretamente posição interna
  ou externa.
- SHA-256: `2E32FD807E9675DA48A82A91DE3D630254FF15C3CAF84554FD0DEE16E51D2C19`.
- Referência: `work/e19-reference/02-estilo-target.png`.
- Testes: `tests/python/test_e19_style_workspace.py`.
