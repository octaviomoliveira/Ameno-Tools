# E20 — Interface vertical adaptativa e prévia fiel

Data: 2026-09-13

Status: E20.0–E20.3 concluídas no gate técnico local; E20.4 é a próxima etapa.

## Checkpoint de execução — 2026-09-14

- Base publicada registrada: `origin/develop` em
  `1acc10af35a289c18ffafa9186ca2055e4f97f41`.
- Branch funcional isolada: `feature/e20-vertical-adaptive-ui`.
- Plano preservado por cherry-pick `d030e4f`; zero alterações em `Contents/`.
- Evidência: [baseline E20.0](../work/e20-baseline/README.md), três originais
  com dimensões/SHA-256, 50 capturas Qt e 12 contratos RED reproduzíveis.
- 69 regressões Python verdes; 19/19 suítes MAXScript verdes, zero FAIL;
  pacote estrutural válido. Testes executados em 2026-09-13, checkpoint
  concluído em 2026-09-14. Resumo Max na pasta de baseline.
- Decisão duradoura: [ADR 0029](../docs/decisions/0029-e20-vertical-adaptativo-e-previa-fiel.md).
- Dependência E20.5: Aplicar ainda usa o estilo salvo; Salvar pode reconstruir
  cotas. A separação aprovada exige contrato funcional adicional, registrado
  na baseline, sem mudança do núcleo nesta etapa.
- E20.1 concluída no commit funcional `0329146`: abertura vertical adaptada à
  área útil, persistência segura de posição/tamanho/maximização, recuperação de
  monitor/DPI e moldura nativa validada no Max 2026. Evidência:
  [work/e20-window](../work/e20-window/README.md).
- E20.2 concluída no gate Qt local em 2026-09-23: breakpoints pelo viewport,
  rail compacto acessível, linguagem visual e foco medidos. Shell 8/8 em 96 e
  144 DPI; 69/69 regressões Python; 25 capturas sem rolagem horizontal.
  Evidência: [work/e20-shell](../work/e20-shell/README.md). A instalação e o
  aceite visual no Max permanecem no gate E20.8.

| Etapa | Estado |
| --- | --- |
| E20.0 — Base e contratos | Concluída; regressões verdes e 12 REDs específicos |
| E20.1 — Janela e persistência | Concluída; 20/20 contratos em dois DPIs e host Max verde |
| E20.2 — Shell e identidade | Concluída no gate técnico local; aceite no Max em E20.8 |
| E20.3 — Cotar | Concluída no gate técnico local; aceite no Max em E20.8 |
| E20.4 — Prévia fiel | Não iniciada; próxima |
| E20.5 — Estilos | Não iniciada; dependência funcional identificada |
| E20.6 — Demais páginas | Não iniciada |
| E20.7 — Regressões e aceite técnico | Não iniciada |
| E20.8 — Instalação e aceite humano | Não iniciada |

Base obrigatória: `develop` no commit que estiver publicado quando a execução
começar. O executor deve registrar o SHA da base e criar uma branch funcional
isolada. Este documento foi preparado na branch de planejamento
`feature/e20-vertical-adaptive-ui-plan`.

Escopo: apresentação Python/PySide6 do Ameno Tools · Cotas. O núcleo MAXScript
de cotação não deve ser refatorado nesta etapa. Limitações funcionais descobertas
devem ser registradas para uma etapa posterior.

## 1. Decisão do produto

A experiência principal passa a abrir em formato vertical, semelhante às
capturas reais fornecidas pelo usuário em 2026-09-13. Esse formato mostrou o
fluxo completo de Cotar e permitiu manter a prévia de Estilos junto dos
controles. A janela continua livremente redimensionável e pode adotar duas
colunas quando houver largura útil suficiente.

Não existe tamanho mínimo de produto predefinido. O tamanho inicial deve caber
na área útil do monitor e mostrar o fluxo principal. Se a implementação provar
que um mínimo técnico é indispensável, ele deve ser derivado de métricas,
testado e documentado.

A janela deve lembrar o último tamanho e posição válidos, conservar minimizar,
maximizar e fechar, e recuperar uma geometria segura quando o monitor salvo não
existir mais ou a janela ficar fora da área visível.

## 2. Direção visual

- Identidade totalmente autoral do Ameno; não imitar o 3ds Max.
- Fundo quase preto e vermelho Ameno como accent permanente.
- Interface técnica, sofisticada, legível e com baixa poluição visual.
- Sidebar compacta por ícones, com tooltips acessíveis.
- Ordem: Cotar, Estilos, Revisar, Exportar e Configurações.
- O executor tem autonomia para alterar composição, hierarquia, tipografia,
  microcopy, espaçamento, densidade, cartões, ícones e comportamento
  responsivo quando houver melhoria comprovável.
- Uma função nova só pode aparecer se já houver suporte real e seguro. Ideias
  sem suporte devem ir para o relatório, não para botões simulados.

## 3. Contratos funcionais preservados

### 3.1 Cotar

Fluxo de referência:

1. Como você quer medir?
2. Orientação do desenho.
3. Direção.
4. Estado da cena.
5. Iniciar cotação.
6. Mais ações.
7. Ajustar detalhes.

O executor pode reorganizar a composição, mas não esconder decisões essenciais.

- Uma medida permite Automática, Horizontal e Vertical.
- Várias medidas mantém Automática visível e desabilitada.
- Ao trocar de Uma medida + Automática para Várias medidas, selecionar
  Horizontal e mostrar feedback discreto.
- Em Várias medidas, explicar continuamente por que Automática não está
  disponível; o CTA não deve ser o primeiro lugar onde a regra aparece.
- Iniciar cotação e Mais ações podem permanecer lado a lado.
- Mais ações e Ajustar detalhes preservam as capacidades existentes; ações
  novas exigem implementação funcional já suportada.
- O executor decide, com base no estado real, quais dados o cartão de cena
  mostra e o destino de Preparar cena quando a cena já estiver pronta.

### 3.2 Estilos

Nome definitivo: **Estilos**.

Ordem de referência: título, seletor, Novo estilo, menu, Prévia 2D, Texto,
Linhas, Terminais, Cores e rodapé.

- No vertical, prévia acima dos controles; no largo, ela pode ficar ao lado.
- A prévia representa a cota real, não uma ilustração aproximada.
- Corrigir os terminais/setas atualmente incorretos.
- Tudo que altera a aparência da cota atualiza a prévia imediatamente: fonte,
  peso, itálico, tamanho, tracking, afastamentos, espessuras, extensões,
  terminais, cores, escala e propriedades equivalentes existentes.
- Atualização local, determinística e rápida, sem bridge, cena, renderer,
  `pymxs`, viewport ou timer de polling.
- Controles de escala e fundo permanecem; Fundo escuro alterna de fato entre
  fundos escuro e claro.
- O usuário escolhe mm, cm ou m. Todo valor dimensional mostra unidade e a
  conversão preserva a grandeza física.
- Salvar estilo persiste uma definição reutilizável.
- Aplicar usa o estado atual naquele momento sem exigir a criação/persistência
  de um novo estilo.
- Preview, região rolável e rodapé nunca podem encobrir uns aos outros.

## 4. Contratos globais mensuráveis

- Zero rolagem horizontal.
- Zero texto, ícone, valor, suffix ou ação truncados.
- Unidade sempre visível em campos dimensionais.
- Conteúdo crítico acessível por teclado e foco visível.
- Tooltips nos ícones do rail.
- Contraste mínimo WCAG AA para texto e controles essenciais.
- Estados normal, hover, pressed, selected, focus, disabled, dirty, loading,
  sucesso e erro coerentes.
- Nenhum acesso ao domínio durante interação puramente visual.
- Nenhuma criação de nó, refresh de cena ou bloqueio da viewport causado por
  preview/resize/navegação.
- Lifecycle estável em abrir, fechar, reabrir, maximizar, restaurar e trocar de
  página.

Geometrias de evidência obrigatória:

- vertical padrão, dimensionada pela área útil do monitor;
- vertical alta equivalente às capturas de 2026-09-13;
- 980×720;
- 780×720;
- 780×560 como teste de compressão, não como mínimo declarado;
- 1280×800;
- maximizada.

Escalas automatizadas quando suportadas: 100%, 125%, 150% e 200%.

## 5. Plano de desenvolvimento

### E20.0 — Preparar branch, baseline e critérios

1. Atualizar a base local e registrar o SHA exato de `develop`.
2. Criar branch funcional isolada, sugerida:
   `feature/e20-vertical-adaptive-ui`.
3. Ler `PLAN.md`, E15–E19 e ADRs associados antes de editar.
4. Preservar as três capturas verticais de 2026-09-13 em
   `work/e20-baseline/`, com dimensões e SHA-256.
5. Gerar capturas equivalentes do HEAD funcional antes das mudanças.
6. Mapear páginas, widgets, scroll areas, breakpoints, persistência de janela,
   preview e chamadas ao bridge.
7. Converter clipping, geometria inválida e terminais incorretos em testes RED.

Gate: baseline reproduzível, testes RED específicos e regressões atuais verdes.

Commit sugerido: `test(e20): capture vertical baseline and red contracts`.

### E20.1 — Geometria da janela e persistência segura

Estado: concluída em 2026-09-14 no commit funcional `0329146`. Gate e
reprodução em `work/e20-window/README.md`.

1. Definir tamanho inicial vertical a partir de `availableGeometry()` do monitor.
2. Fazer o primeiro frame mostrar o fluxo principal sem abrir fora da tela.
3. Persistir tamanho, posição e estado maximizado somente após geometria válida.
4. Restaurar no monitor correspondente ou no monitor disponível mais adequado.
5. Corrigir coordenadas salvas fora da área útil ou em monitor removido.
6. Preservar redimensionamento livre e chrome completo.
7. Evitar saltos, loops de resize e gravação excessiva durante o arraste.
8. Testar primeira abertura, reabertura, maximização e mudança de monitores.

Gate: geometria previsível, recuperável e persistente, sem clipping novo.

Commit sugerido: `feat(e20): adopt safe vertical window geometry`.

### E20.2 — Shell adaptativo e linguagem visual

Estado: concluída no gate técnico local em 2026-09-23. Evidência em
`work/e20-shell/README.md`; aceite visual no host fica para E20.8.

1. Medir breakpoints pela largura útil do viewport da página.
2. Manter rail compacto, ordem aprovada e tooltips acessíveis.
3. Revisar ícones apenas quando a nova solução for mais legível e consistente.
4. Unificar tokens de cor, tipografia, espaçamento, raio, borda e estados.
5. Preservar vermelho Ameno e identidade própria, sem mimetizar o Max.
6. Corrigir contraste, foco, targets e navegação por teclado.
7. Garantir que páginas não imponham largura mínima maior que o viewport.
8. Cobrir compacto, médio, largo, maximizado e DPI alto.

Gate: shell consistente, zero overflow horizontal e navegação completa.

Commit sugerido: `feat(e20): refine adaptive Ameno shell`.

### E20.3 — Refinar Cotar como fluxo vertical principal

Estado: concluída no gate técnico local em 2026-09-23. Evidência em
`work/e20-cotar/README.md`; aceite visual no host fica para E20.8.

1. Reavaliar densidade e proporções dos quatro cartões de decisão.
2. Garantir leitura completa no padrão vertical sem esconder o CTA.
3. Preservar e testar todas as transições de tipo, orientação e direção.
4. Tornar a regra de Automática autoexplicativa e não intrusiva.
5. Refinar o cartão de cena com somente informações acionáveis.
6. Definir comportamento coerente de Preparar cena em cada estado.
7. Preservar Iniciar cotação + Mais ações lado a lado onde couber; adaptar sem
   perder hierarquia quando não couber.
8. Manter Ajustar detalhes secundário e acessível.
9. Impedir ações sem backend e remover qualquer affordance falsa.
10. Validar estados inicial, não verificado, pronto, ocupado, erro e cotagem em
    andamento.

Gate: fluxo completo visível no vertical padrão, regras funcionais preservadas
e zero regressão de bridge.

Commit sugerido: `feat(e20): polish vertical quoting flow`.

### E20.4 — Reconstruir fidelidade da Prévia 2D de Estilos

1. Auditar o modelo geométrico puro contra a geometria real das cotas.
2. Corrigir setas, ticks, dots, diamonds e demais terminais suportados.
3. Criar testes de paridade de proporção, orientação, extensão e espessura.
4. Garantir atualização local para toda propriedade visual.
5. Definir transformação de mundo visual para canvas com escala estável.
6. Fazer zoom caber o conjunto sem tornar texto ou terminais ilegíveis.
7. Implementar fundos claro/escuro reais e contraste correspondente.
8. Cobrir valores mínimos, máximos, zero válido e combinações extremas.
9. Provar que nenhum evento da prévia chama bridge, `pymxs`, cena ou viewport.
10. Medir latência de slider/digitação e eliminar trabalho redundante.

Gate: preview fiel, responsivo, instantâneo e inteiramente local.

Commit sugerido: `fix(e20): make style preview geometrically faithful`.

### E20.5 — Layout adaptativo e semântica de Estilos

1. No vertical, manter prévia acima dos controles em tamanho compreensível.
2. No largo, avaliar e adotar preview lateral quando melhorar a comparação.
3. Definir conscientemente quais regiões ficam fixas e qual região rola.
4. Impedir que rodapé encubra Cores ou o último controle.
5. Exibir unidade em todo valor dimensional e preservar conversão física.
6. Refinar alinhamento de sliders, spinboxes, checkboxes e labels.
7. Tornar Salvar estilo e Aplicar semanticamente distintos nos estados e textos.
8. Cobrir dirty, sincronizado, salvamento, aplicação, erro e descarte.
9. Validar seleção, criação, duplicação e menu sem perder o rascunho.

Gate: usuário consegue compreender, ajustar, comparar, salvar e aplicar sem
perder a prévia nem confundir os destinos.

Commit sugerido: `feat(e20): complete adaptive styles workspace`.

### E20.6 — Revisar, Exportar e Configurações

1. Aplicar os tokens e breakpoints consolidados às páginas restantes.
2. Remover redundância, empty states excessivos e textos internos.
3. Manter ações essenciais visíveis e explicações sob demanda.
4. Revisar formulários, unidades, caminhos, feedback e estados indisponíveis.
5. Não adicionar funções sem suporte real.
6. Registrar dependências funcionais encontradas para etapa posterior.

Gate: cinco páginas parecem partes do mesmo produto e passam os contratos
globais.

Commit sugerido: `feat(e20): unify remaining product pages`.

### E20.7 — Acessibilidade, desempenho e regressões

1. Executar matriz de geometrias e DPI.
2. Executar detector de clipping e overflow em todas as páginas/estados.
3. Validar Tab, Shift+Tab, Enter, Espaço, Esc, tooltips e foco.
4. Medir resize, troca de página, sliders e preview.
5. Repetir lifecycle em pelo menos 100 ciclos automatizados.
6. Repetir regressões Python, MAXScript E16–E19 e pacote.
7. Gerar galeria antes/depois com dimensões e estados identificados.
8. Corrigir causas; não aprovar por esconder scrollbar ou reduzir texto
   indiscriminadamente.

Gate: automação integral verde, evidência visual revisável e nenhuma regressão
funcional conhecida.

Commit sugerido: `test(e20): close adaptive UI acceptance matrix`.

### E20.8 — Pacote, instalação segura e aceite humano

1. Confirmar que o Max interativo está fechado antes de substituir arquivos.
2. Criar backup recuperável do pacote instalado.
3. Gerar ZIP candidato e SHA-256.
4. Validar pacote e comparar arquivos instalados por hash.
5. Executar smoke test da cópia instalada.
6. Abrir uma nova sessão gráfica do Max; nunca reinicializar/recarregar o
   bootstrap repetidamente no mesmo processo.
7. Validar manualmente Cotar, Estilos, demais páginas, resize e persistência.
8. Registrar capturas reais e resultado do aceite humano.
9. Não fazer merge, tag ou promoção sem autorização explícita do usuário.

Gate: candidato instalado e reproduzível, aguardando ou contendo aceite humano
registrado.

Commit sugerido: `chore(e20): package adaptive UI candidate`.

## 6. Critérios de parada

Interromper a etapa e registrar evidência se ocorrer:

- crash, hang ou exceção nativa do Max;
- necessidade de reload do bootstrap no mesmo processo;
- chamada ao domínio durante preview ou resize;
- alteração funcional de MAXScript necessária para continuar;
- perda de dados de estilo ou mudança destrutiva de unidade;
- testes legados quebrados sem causa compreendida;
- interface que só passa reduzindo ou escondendo conteúdo importante.

## 7. Relato obrigatório de dependência funcional

Se surgir necessidade fora da camada gráfica, o relatório final deve usar:

**ATENÇÃO — NECESSIDADE NO CÓDIGO FUNCIONAL:** descrever problema, impacto,
arquivos prováveis, evidência e solução recomendada. Não implementar uma
refatoração ampla do núcleo dentro da E20.

## 8. Entrega final do executor

- branch e SHA da base;
- sequência de commits;
- decisões visuais e justificativas;
- arquivos alterados;
- testes com contagens e logs;
- galeria antes/depois e capturas do Max real;
- ZIP, SHA-256, backup e paridade da instalação;
- estado do gate humano;
- pendências funcionais em negrito no formato obrigatório;
- atualização do `PLAN.md` e ADRs necessárias.

## 9. Prompt curto para iniciar a execução

> Execute o plano `plans/2026-09-13-e20-interface-vertical-adaptativa.md` por
> etapas. Comece somente pela E20.0, partindo da `develop` publicada e criando
> uma branch funcional isolada. Leia integralmente o plano vivo, E15–E19 e as
> ADRs relacionadas. Faça testes e um commit recuperável por etapa, atualize o
> `PLAN.md` e pare em cada gate quando faltar evidência. Não faça merge em
> `develop`/`main`. Não recarregue o bootstrap no mesmo processo do Max.
