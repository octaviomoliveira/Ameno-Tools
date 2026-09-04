# ADR 0013 — Overlay separado de cotas no Corona (E9)

- Estado: aceita para teste manual do MVP
- Data: 2026-09-04

## Contexto

O fluxo de planta humanizada precisa combinar a imagem final escolhida pelo usuário — Beauty nativo ou qualquer configuração de LightMix — com cotas gráficas editáveis. Colocar as cotas no render principal criaria dependência de iluminação, exposição e do canal final usado no Corona. Criar ou alterar Render Elements também aumentaria o risco de interferir no setup de produção.

A E9 precisava, portanto, gerar um arquivo independente, alinhado ao render da planta e seguro para composição no Photoshop. O processo deveria funcionar mesmo quando o Beauty final vem do LightMix e restaurar a cena após sucesso, erro ou cancelamento.

## Decisão

1. O MVP usa um segundo passe explícito, acionado por `Renderizar Cotas`, e grava PNG com alpha. EXR e integração no mesmo passe ficam fora da E9.
2. O passe herda a viewport/câmera ativa, o frame atual, resolução, pixel aspect e o modo Crop/Region do Render Setup. A API `render()` é chamada sem trocar a câmera ou a vista.
3. `AmenoRenderCotasService` coleta somente os nós gráficos `lines` e `label`, com escopo `Todas` ou `Selecionadas`. Marcadores de override e controladores técnicos nunca entram no overlay.
4. Antes do render, as âncoras são sincronizadas incrementalmente. Em seguida, o serviço captura o estado dos nós, materiais, layer das cotas, layer corrente e configurações PNG; isola temporariamente os alvos; e executa uma restauração única para sucesso, exceção e cancelamento.
5. O adapter Corona cria um `CoronaLightMtl` temporário com `emitLight = false`, `visibleDirect = true` e `affectAlpha = true`. Reflexos e refrações são desligados. Assim a anotação aparece diretamente e no alpha sem emitir luz, alimentar GI ou virar um grupo controlável do LightMix.
6. O passe usa `renderElements:false` e `vfb:false`. O Ameno não cria, remove, habilita, desabilita ou reordena Render Elements e não altera o Beauty ou o LightMix do usuário.
7. O nome automático é `<cena>_AMENO_COTAS_f####.png`. Quando o arquivo já existe, um sufixo incremental `_001`, `_002` e assim por diante evita sobrescrita silenciosa.
8. O resultado só é apresentado como sucesso depois que o PNG pode ser reaberto, possui canal alpha e, para render de quadro completo, mantém as dimensões esperadas.

## Consequências

### Positivas

- O mesmo overlay pode ser composto sobre Beauty, LightMix A, LightMix B ou outra versão da imagem sem rerenderizar as cotas.
- A aparência das cotas não depende da existência de luzes na cena.
- O setup de Render Elements e LightMix permanece fora do escopo de mutação do plugin.
- A arquitetura separa o serviço comum do adapter específico, permitindo adicionar V-Ray CPU na E10 sem duplicar o fluxo transacional.
- Falhas e cancelamentos não deixam materiais temporários, objetos isolados ou layers alteradas.

### Limitações da E9

- Apenas Corona no 3ds Max 2026 está habilitado; outros renderizadores mostram diagnóstico e bloqueiam o botão.
- A saída é PNG; EXR, alpha mode configurável, composição automática e Render Element próprio permanecem futuros.
- A cor de anotação acompanha o neutro gráfico disponível no MVP; controles de cor por estilo ainda não existem no registro de estilos atual.
- A aprovação definitiva depende do gate manual em uma planta real do usuário.

## Evidência

- Testes transacionais em `tests/maxscript/test_bootstrap.ms` cobrem escopo, herança do Render Setup, proteção contra sobrescrita e restauração após sucesso, exceção e cancelamento.
- `tests/maxscript/test_installed_package.ms` confirma o adapter e o serviço carregados pela cópia em `ApplicationPlugins`.
- `tests/maxscript/test_e9_corona_render.ms` executou Corona 13 no 3ds Max 2026.3 e criou PNG 160 × 90 com cotas opacas e fundo transparente, restaurando a geometria e os materiais originais.

## Referências

- [3ds Max 2026 MAXScript — `render()`](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Interacting-with-the-3ds-Max/Render-Scene-Dialog/GUID-9175301C-13E6-488B-ABA6-D27CD804B205.html)
- [Chaos Corona Light Material](https://docs.chaos.com/display/CRMAX/Corona+Light+Material)
