# ADR 0029 — Vertical adaptativo e prévia fiel

Data: 2026-09-13

Status: aceita como direção de produto; implementação por gates E20.

## Contexto

As três capturas do usuário mostram Cotar cortada em uma janela quase quadrada
e o fluxo completo na janela alta. Em Estilos, a prévia acima dos controles
funciona melhor nessa proporção. A automação offscreen anterior continuou
verde, portanto não substitui a evidência e o aceite no host.

## Decisão

1. Primeira abertura vertical, dimensionada pela área útil do monitor. Não
   transformar 780×560, 780×720 ou a dimensão de uma captura em mínimo fixo de
   produto. Um mínimo técnico novo exige medição e justificativa.
2. A geometria válida escolhida pelo usuário prevalece sobre o padrão nas
   reaberturas. Preservar posição, tamanho normal e estado maximizado; recuperar
   janelas fora da tela ou salvas em monitor removido.
3. Rail compacto e identidade Ameno autoral, escura e vermelha; nome definitivo
   da página: Estilos. Layout largo pode colocar prévia e controles lado a lado.
4. Todos os elementos da cota usam a mesma transformação física na prévia. O
   modelo MAXScript de cotas confirmadas é o oráculo de proporção e orientação,
   não os fatores arbitrários do painter atual. Antialiasing e tipografia exigem
   verificação complementar no host; matemática pura não prova pixels iguais.
5. Manter edição e prévia inteiramente locais, sem bridge/pymxs/polling. Trocar
   mm/cm/m preserva a grandeza física e mantém sufixos visíveis.
6. Salvar deve persistir uma definição reutilizável; Aplicar deve usar o
   rascunho atual sem exigir salvamento. A fachada existente não oferece essa
   separação completa: registrar a dependência, não simular a funcionalidade.
7. Executar E20.0–E20.8 com evidência e commits por etapa, em branch isolada.
   Só instalar o candidato na E20.8, com backup e Max interativo fechado; sem
   merge/tag/promoção automáticos.

## Relação com decisões anteriores

- Preserva ADR 0024 (Qt nativo, sem WPF), 0025 (isolamento da viewport) e os
  contratos locais de draft/painter/lifecycle das ADRs 0027 e 0028.
- Substitui o padrão geométrico antigo pela abertura vertical adaptativa e a
  restauração válida. Os tamanhos antigos continuam casos de regressão.
- O plano E20 e a autonomia explícita sobre todas as páginas substituem a ordem
  intermediária da E19 que bloqueava propagação após uma única página. Isso
  não transforma o canary E18/E19 em visualmente aprovado, nem dispensa o gate
  humano do candidato E20 no Max.
- Mantém medição de clipping por conteúdo e breakpoints pela largura útil da
  página. Scrollbar ausente e captura offscreen não bastam para aceite.

## Consequências

Os REDs de E20.0 ficam explicitamente separados das regressões legadas. Eles
devem ficar verdes nas etapas responsáveis, sem adaptar o backend para que
coincida com uma prévia errada. A E20.5 poderá exigir um checkpoint funcional
adicional para Aplicar/Salvar; não pode ser declarada concluída só com novo
texto nos botões. Ângulo e posicionamento dos terminais também precisam de
contrato consistente entre overlay e geometria confirmada.

Complemento de 2026-09-23 (E20.4): por decisão do usuário, a prévia segue a
geometria confirmada e não aplica Posicionamento nem Ângulo, que o núcleo
ignora. A prévia usa uma escala física única; a amostra encurta de 3,50 m até
1,20 m em canvas estreito sem alterar proporções.

Complemento de 2026-09-23 (E20.5): Aplicar usa sempre a versão salva; com
rascunho sujo a ação é explicitamente "Salvar e aplicar". Posição e Ângulo
ficam ocultos, sem apagar o valor gravado. Aplicar rascunho transitório exige
comando novo no núcleo, fora da E20.

Referências: `plans/2026-09-13-e20-interface-vertical-adaptativa.md` e
`work/e20-baseline/README.md`.
