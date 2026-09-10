# Planos e handoffs

`../PLAN.md` é o plano vivo e a fonte de verdade do estado atual.

Esta pasta preserva planos de marco, handoffs e registros suficientemente detalhados para uma nova sessão ou outro agente assumir o trabalho sem depender do histórico de chat.

Arquivos atuais:

- [Fundação de 2026-09-03](2026-09-03-foundation.md): estado técnico entregue, decisões e ponto de retomada.
- [Plano incremental do MVP](2026-09-03-mvp-incremental.md): etapas funcionais, gates no 3ds Max e ordem de implementação.
- [E11 — Editor Visual e Preview ao Vivo](2026-09-04-e11-editor-visual-preview.md): inventário histórico do editor WPF; a apresentação distribuída foi supersedida pela reescrita Python/Qt da E15.
- [E10.7 — Âncoras por vértice](2026-09-04-e10-7-subobject-anchors.md): schema v5 e atualização reativa após edição de vértices em Editable Poly/Editable Mesh.
- [E14 — Planos de cotação e fachadas](2026-09-08-e14-planos-de-cotacao-fachadas.md): generalização do núcleo para planos ortográficos, dividida em sete subetapas; implementação não iniciada.
- [Substituição do WPF e isolamento da viewport](2026-09-09-substituicao-wpf-qt-viewport.md): recomendação PySide6/Qt + overlay `gw`, modo seguro nativo e migração em seis etapas.
- [E15 — Transição integral WPF → Python/Qt](2026-09-09-e15-transicao-wpf-python-qt.md): execução ativa da UI do zero, login por token e janela nativa, certificada primeiro apenas no Max 2026.
- [E16 — Preview `gw` e commit previsível](2026-09-09-e16-otimizacao-preview-commit-viewport.md): plano executável em 10 etapas/78 subetapas para retirar toda mutação e picking pesado do `mouseMove`, desenhar o preview contínuo com `gw` e reduzir o commit sem quebrar âncoras, fachada, Undo ou render.
- [E17 — Identidade Ameno e experiência guiada Qt](2026-09-09-e17-identidade-ux-qt.md): candidato técnico em 11 etapas/86 subetapas; automação verde, mas aceite visual humano reprovado em 2026-09-09 por clipping, hierarquia e prévia incompleta.
- [E18 — Experiência Qt 10/10 e prévia reativa](2026-09-09-e18-ux-10-10-preview-reativo.md): runbook executado em 12 etapas/118 subetapas; gates técnicos passaram, mas o canary foi reprovado visualmente no Max real por clipping, densidade, contraste e preview fora da área de ajuste.
- [E19 — Interface Qt visualmente aprovada no Max](2026-09-10-e19-correcao-visual-interface-qt.md): correção em 6 etapas/32 subetapas após a reprovação visual do E18; usa Aparência como referência, mede clipping real e bloqueia propagação até aprovação dentro do Max 2026.

Ao abrir um marco novo, criar um arquivo datado (`AAAA-MM-DD-assunto.md`) e incluir o link no `PLAN.md` quando ele for relevante para continuidade.
