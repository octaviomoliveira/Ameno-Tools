# E16 — spike `gw` / viewport

Data: 2026-09-09 · Host validado: 3ds Max 2026.3 Batch e pacote instalado.

O spike foi incorporado diretamente ao serviço transitório porque a API mínima
foi comprovada sem criar nós e a implementação precisava continuar no mesmo
contrato de lifecycle. Não há vídeo de viewport neste diretório: a validação
visual (câmera, clipping e DPI) é deliberadamente o gate manual descrito em
`tests/maxscript/manual_e16_viewport_soak.ms`.

## Decisão técnica

- `AmenoContinuousOverlayModel` guarda apenas `point3`, strings, cores,
  números, nomes, booleanos e arrays desses valores.
- Cada segmento publica linha, duas extensões, rótulo e terminais como
  primitivas `gw` (`polyline`, `polygon` ou `marker`).
- `publishLayout()` constrói um snapshot completo antes de substituir o modelo;
  revisão não avança para layout idêntico.
- `publishHover()` também coalesceia estado repetido.
- O callback antigo é removido antes de redefinição e só delega ao overlay
  quando a sessão `#gw` está habilitada; o backend `#sceneNodes` continua
  disponível como rollback técnico.
- `drawCurrent()` não acessa objetos, geometria, layers, estilo, picking,
  material, CA, UI ou arquivo. Falhas incrementam `drawErrorCount` e guardam a
  última mensagem em memória.

## Evidência automatizada

- `test_e16_overlay_model.ms`: **27/27 PASS** — tick, setas abertas/fechadas,
  losango, ponto, none, unidade/precisão, revision e layout inválido.
- `test_e16_callback_lifecycle.ms`: **6/6 PASS** — cardinalidade 0/1/0 em 100
  ciclos e nenhum erro de draw acumulado.
- `test_e16_mousemove_no_scene.ms`: **13/13 PASS** — 1.000 movimentos, zero
  full resolve, zero mutação, zero preview de nós, snapshot de cena inalterado.

## Gate manual ainda necessário

Em uma sessão nova do Max, executar o assistente, testar Planta/Fachada,
perspectiva/ortográfica, quatro viewports, DPI 100/125/150%, resize e
minimizar/maximizar/fechar. Não fazer hot reload e não usar a cena original.
