# ADR 0023 — Planos persistentes para cotas de fachada

Data: 2026-09-08
Status: implementado em `feature/e14-facade-planes`; gates manuais e render pendentes

## Contexto

O núcleo original projetava todas as referências no plano mundial XY. Isso
impedia medir a largura e a altura de uma fachada sem perder os snaps 3D ou
sem depender da posição atual da câmera. A cotação contínua também calculava o
cursor pela interseção com `Z = 0`.

## Decisões

1. Cada cota passa a carregar uma base ortonormal destra `O, U, V, N`. `U` é o
   eixo horizontal da vista, `V` o vertical e `N = cross(U,V)`. `Planta` usa
   `worldXY`; `Fachada / Vista` captura Front, Back, Left, Right ou câmera
   ortográfica nivelada. Perspectiva, Top/Bottom, inclinação e roll são
   recusados no MVP.
2. A orientação é capturada ao iniciar a ferramenta e a origem é ancorada na
   projeção do primeiro snap. Pan/zoom não recapturam a base; mudança de
   viewport, câmera ou orientação cancela a sessão para evitar mistura de
   planos.
3. Os pontos A/B permanecem os pontos mundiais reais, com nó e vértice. Apenas
   a medida, o afastamento e os nós gráficos usam a projeção U/V. Assim um
   deslocamento ao longo de N não altera uma medida projetada.
4. O Custom Attribute sobe aditivamente para v6, acrescentando ao final
   `planeType`, `planeOrigin`, `planeAxisU`, `planeAxisV`, `planeNormal`,
   `baselinePolicy` e `baselineCoordinate`. Registros v1–v5 assumem XY; uma
   base v6 inválida permanece inválida e gera diagnóstico, sem fallback
   silencioso.
5. Cadeias novas H/V em fachada persistem uma baseline absoluta no plano
   (`fixedPlaneBaseline`): V constante para Horizontal e U constante para
   Vertical. Cotas individuais e registros legados mantêm a política relativa.
6. TextPlus, linhas, extensões, marcadores e terminais recebem a mesma base
   completa; o texto é orientado por matriz e posicionado depois da orientação
   para não girar em torno da origem mundial.

## Consequências

- As cotas de planta existentes continuam com o resultado XY e podem ser lidas
  por versões anteriores do fluxo de dados.
- Rebuild, auditoria, atualização rápida, estilo, reancoragem e bake resolvem o
  plano persistido antes de calcular a geometria.
- A cotação contínua de fachada permanece restrita a Horizontal/Vertical; uma
  cadeia alinhada/oblíqua exige uma decisão posterior.
- A prova automatizada cobre o contrato e o save/load; a leitura visual nas
  quatro vistas, câmera rotacionada, render real e aceite do usuário ainda são
  gates da E14.6/E14.7.

## Evidência

- `tests/maxscript/test_e14_plane_math.ms`: 32/32.
- `tests/maxscript/test_e14_graphics.ms`: persistência v6, rebuild e save/load.
- `tests/maxscript/test_e14_tools.ms`: 31/31, individual/contínua e baseline
  após movimento de referência.
- `tests/maxscript/test_bootstrap.ms`, E10.7, E12 e `test_e13_ui_lifecycle.ms`:
  exit code 0 e zero FAIL; `tools/validate-package.ps1` aprovado.
