# E11 — Editor Visual e Preview ao Vivo

**Data:** 2026-09-04

**Alvo inicial:** 3ds Max 2026

**Estado:** E11.0 e E11.1 concluídas e testadas na branch `feature/e11-visual-editor` (48/48 testes aprovados em `test_e11_1_draft.ms`); pronta para avançar para E11.2
**Referência visual:** mockup “Ameno — Editor de estilo” fornecido pelo usuário em 2026-09-04

## Contexto

A E7 entregou o sistema funcional de estilos e um editor em rollout MAXScript. Ele permite editar fonte, tamanho, tracking, espessura e terminais, mas não implementa o acabamento visual nem o quadro `Preview ao vivo` apresentado no mockup. O editor atual também aplica alterações à cena em cada evento de controle, enquanto o produto desejado pede um rascunho visual que possa ser cancelado antes de alterar cotas reais.

Neste plano, “viewport” significa o **preview 2D embutido no Editor de Estilo**. Não é uma quinta viewport do 3ds Max e não substitui a câmera ou o viewport da cena.

## Objetivo

Substituir o editor de estilo atual por uma interface visual coerente com o mockup, com preview imediato e isolado da cena, edição transacional e aplicação explícita às cotas.

Ao concluir, o usuário deve conseguir entender fonte, peso, tracking, máscara, espessura, cor, terminal e proporção da cota antes de clicar em `Aplicar` ou `Salvar estilo`.

## Fora do escopo

- redesenhar todo o painel principal do Ameno Tools;
- criar uma viewport 3D, câmera ou render interativo;
- implementar V-Ray, Corona ou qualquer função pertencente à E10;
- suportar oficialmente Max 2021–2025 nesta etapa;
- atualizar cotas reais continuamente durante o arraste dos sliders;
- substituir TextPlus ou o núcleo gráfico das cotas.

## Princípios obrigatórios

1. O preview não cria nós, materiais, helpers, callbacks persistentes ou lixo na cena.
2. Alterar controles modifica apenas um `StyleDraft` em memória.
3. `Cancelar` fecha o editor sem modificar estilo, cotas ou Undo.
4. `Aplicar às selecionadas` afeta somente as cotas selecionadas e gera um único Undo.
5. `Salvar estilo` persiste o estilo e atualiza as cotas vinculadas em um único Undo.
6. Fonte ausente ou incompatível aparece como aviso; nunca é substituída silenciosamente.
7. O editor deve continuar abrindo mesmo quando nenhuma cota estiver selecionada.
8. Nenhuma mudança da E11 pode quebrar arquivos `.max` criados entre E5 e E10.

## Experiência planejada

```text
┌─ Ameno — Editor de estilo ───────────────────────────────┐
│ Estilo e quantidade vinculada       Presets do projeto   │
├──────────────────────────────┬────────────────────────────┤
│ Preview ao vivo              │ Texto                      │
│ planta neutra + cota         │ fonte, tamanho, B/I,       │
│ zoom e fundo claro/escuro    │ tracking, máscara e cor    │
│ resumo da saída              ├────────────────────────────┤
│                              │ Linhas                     │
│                              │ presets, espessura e cor   │
│                              ├────────────────────────────┤
│                              │ Setas e terminais          │
│                              │ tipo, tamanho e posição    │
├──────────────────────────────┴────────────────────────────┤
│ Cancelar     Aplicar às selecionadas     Salvar estilo    │
└───────────────────────────────────────────────────────────┘
```

### Cabeçalho

- nome do estilo ativo;
- quantidade de cotas vinculadas;
- indicador de alterações não salvas;
- presets Arquitetônico, Editorial e Técnico;
- ação `Salvar como novo` acessível sem poluir a tela principal.

### Preview ao vivo

- parede/planta neutra apenas como contexto visual;
- cota completa com valor de exemplo configurável;
- texto, linha de dimensão, extensões e terminais;
- alternância de fundo claro/escuro;
- zoom 50 %, 100 % e 200 %;
- indicação do perfil de saída e escala de preview;
- resumo de fonte, tamanho, espessura e layer lógica;
- estados de fonte ausente, texto sem espaço e terminais externos.

O preview é uma aproximação vetorial determinística do resultado. Quando alguma métrica não puder coincidir exatamente com o TextPlus, a interface deve identificar o preview como estimativa e o gate manual compara com uma cota real.

### Controles de texto

- família de fonte reconhecida pelo TextPlus;
- tamanho;
- negrito e itálico;
- tracking;
- máscara de texto;
- cor compartilhada ou independente;
- fallback visível quando a fonte não estiver disponível.

### Linhas

- presets Fina, Normal e Forte;
- espessura contínua;
- cor;
- `extensionGap` e `extensionOverhang` em seção avançada;
- valores apresentados em unidade compreensível, mantendo armazenamento canônico.

### Terminais

- botões visuais para Traço, Cheia, Aberta, Ponto e Nenhuma;
- tamanho;
- posição Automática, Interna ou Externa;
- ângulo do traço em seção avançada;
- miniatura do terminal no próprio botão.

## Arquitetura proposta

### E11.0 — Prova técnica da interface

**Estado:** Concluída e aprovada em 2026-09-04 na branch `feature/e11-visual-editor`.
**Decisão:** Aprovada e documentada na ADR 0019 (`docs/decisions/0019-e11-0-ui-technology-spike-wpf.md`).

**O que foi feito:**
- Comparação empírica entre WPF (.NET 8 CoreCLR) e WinForms + GDI+ sob o 3ds Max 2026.3 (`test_e11_0_spike.ms`).
- Instanciação de janela modeless vinculada ao HWND do 3ds Max via `WindowInteropHelper.Owner`.
- Renderização de cota vetorial 2D (linha de dimensão, linhas de extensão, terminais e texto sobre planta de contexto neutra).
- Teste de escala High-DPI (100%, 125%, 150%, 200% via DIUs e matriz de escala).
- Estilização em tema escuro profissional compatível com o mockup visual.
- Teste de estresse: 20 ciclos de abertura e fechamento sem vazamento de memória ou handles GDI (WPF: 0.41 s total, ~20.5 ms por janela; WinForms: 0.298 s total).
- Verificação de isolamento: 0 nós criados, 0 layers alteradas na cena.

**Arquivos modificados / criados:**
- `tests/maxscript/test_e11_0_spike.ms` (teste automatizado da prova técnica);
- `docs/decisions/0019-e11-0-ui-technology-spike-wpf.md` (ADR registrando a escolha de WPF .NET 8);
- `plans/2026-09-04-e11-editor-visual-preview.md` (atualização deste plano).

**Decisões técnicas tomadas:**
1. **Tecnologia adotada:** WPF (.NET 8) carregado nativamente no 3ds Max 2026.
2. **Definição declarativa via XAML:** O layout será construído em XAML semântico desacoplado e instanciado via `XamlReader.Parse`, eliminando a necessidade de compilação externa por .NET SDK (que não está presente nas máquinas dos usuários).
3. **Isolamento de Cena:** Nenhuma chamada durante a edição do estilo afeta a cena 3ds Max; todas as modificações são transacionais e manipuladas via `StyleDraft` na E11.1.

**Testes executados:**
- `powershell -File tools/test-maxscript.ps1 -TestScript tests/maxscript/test_e11_0_spike.ms` aprovado com código 0 (`[AMENO_TEST][PASS] E11.0 Spike Tecnico concluido com 100 por cento de sucesso`).

**Resultado do gate:**
- Prova técnica superou todos os critérios de aceite (DPI, modeless, vetorização, velocidade, isolamento de cena).

**Pendências e riscos para a E11.1:**
- Mapeamento de eventos de controles WPF (Sliders, ComboBox, CheckBox) para a estrutura `StyleDraft` em MAXScript;
- Interceptação de atalhos de teclado (`Esc`, `Ctrl+S`) sem interferência dos aceleradores de viewport do 3ds Max.

### E11.1 — StyleDraft e compatibilidade

Introduzir um modelo de rascunho separado do `AmenoStyleRecord` persistido:

```text
estilo persistido → clone → StyleDraft → PreviewModel
                                  ├→ descartar
                                  ├→ aplicar à seleção
                                  └→ salvar estilo
```

Auditar o schema antes de adicionar propriedades ainda ausentes, especialmente:

- `textMaskEnabled`;
- `annotationColor` e eventual cor de texto separada;
- `terminalPlacement`;
- `terminalAngle`;
- perfil/escala de preview.

Se o registro persistente evoluir, criar versão nova com migração idempotente. Estilos antigos recebem defaults equivalentes à aparência atual; não regravar cenas apenas por abrir o editor.

**Status E11.1 (Concluído em 2026-09-04):**
- Structs `AmenoPreviewModel` e `AmenoStyleDraft` implementadas com clone defensivo, desacopladas da cena e da viewport 3D.
- Schema v2 de `AmenoStyleRecord` estendido com 6 novas propriedades (`textMaskEnabled`, `annotationColor`, `textColor`, `terminalPlacement`, `terminalAngle`, `previewScale`) com serialização/desserialização retrocompatível e defensiva (13 a 19 tokens).
- Transações atômicas `saveDraftAsStyle`, `saveDraftAsNewStyle`, `discardDraft`, `applyDraftToSelection` com suporte a Undo/Redo e deduplicação de nós.
- Suíte `tests/maxscript/test_e11_1_draft.ms` executada sob 3ds Max 2026.3 headless com 48/48 testes aprovados (100% de cobertura).
- Suíte de regressão `test_bootstrap.ms` aprovada com 100% de sucesso.

### E11.2 — Shell e navegação

- criar a janela moderna com layout responsivo;
- manter instância única por sessão;
- suportar teclado: `Esc` cancela, `Ctrl+Enter` aplica, `Ctrl+S` salva;
- incluir tooltips e ordem de tabulação;
- lembrar apenas preferências de interface seguras, como tamanho da janela e fundo do preview;
- manter o painel principal compacto: o botão existente apenas abre o novo editor.

### E11.3 — Renderer do preview

Criar um renderer UI-only que receba `PreviewModel` e desenhe:

- planta neutra;
- extensões e linha principal;
- cinco tipos de terminal;
- texto medido e centralizado;
- máscara e cores;
- comportamento dentro/fora quando faltar espaço.

O renderer não acessa diretamente nós do Max. Conversão estilo → preview fica em uma camada testável e não altera `AmenoDimensionGraphics`.

Durante o arraste, atualizar apenas o canvas, com debounce máximo de 16–33 ms. Nenhum rebuild de cotas reais ocorre até uma ação de commit.

### E11.4 — Aplicação e persistência

- `Cancelar`: descartar o draft;
- `Aplicar às selecionadas`: criar/reutilizar estilo conforme contrato definido, deduplicar `dimensionId` e atualizar em lote;
- `Salvar estilo`: confirmar o número de cotas vinculadas e persistir uma única revisão;
- `Salvar como novo`: criar ID novo e não alterar o estilo de origem;
- erro durante aplicação: restaurar o snapshot e apresentar mensagem acionável;
- seleção alterada enquanto o editor está aberto: atualizar somente contexto/contagem, sem perder o draft silenciosamente.

### E11.5 — Integração, testes e instalação

- substituir a abertura do rollout antigo pelo novo host;
- manter fallback diagnosticável se a UI externa não carregar;
- empacotar assemblies/assets no `ApplicationPlugins`;
- validar carregamento por caminho sem depender do diretório do repositório;
- instalar a cópia de desenvolvimento;
- executar gate manual antes de remover definitivamente o editor antigo.

## Testes automatizados

### Modelo e transação

- abrir estilo cria clone defensivo;
- editar draft não altera registro nem cena;
- cancelar mantém dados e Undo intactos;
- salvar atualiza uma vez e suporta Undo/Redo;
- aplicar à seleção deduplica partes da mesma cota;
- falha simulada restaura estilo e cotas;
- migração de estilo antigo é idempotente.

### Preview

- todos os cinco terminais geram geometria visual;
- tracking, peso, itálico e tamanho alteram o layout;
- máscara e cores aparecem nos fundos claro e escuro;
- fit interno/externo é determinístico;
- resize e DPI não cortam controles;
- fonte ausente mostra o estado de alerta.

### Ciclo de vida

- abrir/fechar vinte vezes não acumula callbacks;
- reset/open de cena com editor aberto não causa exceção;
- desinstalação ou assembly ausente produz diagnóstico claro;
- pacote instalado carrega sem depender de arquivos externos;
- smoke test E1–E10 permanece verde.

## Gate manual no 3ds Max

1. abrir o editor pelo painel principal;
2. comparar a composição geral com o mockup aprovado;
3. testar fonte, tamanho, B/I, tracking, máscara e cor;
4. testar Fina/Normal/Forte e espessura contínua;
5. testar os cinco terminais, tamanho e posição;
6. confirmar preview fluido sem alterar as cotas da cena;
7. cancelar e confirmar que nada mudou;
8. aplicar às selecionadas e testar Undo/Redo;
9. salvar estilo e confirmar atualização das cotas vinculadas;
10. salvar/reabrir a cena e verificar persistência;
11. verificar DPI 100 % e uma escala acima de 100 %;
12. reiniciar o Max e validar o pacote instalado.

## Critérios de conclusão

- interface visual aprovada pelo usuário, não apenas funcional;
- preview responde sem rebuild da cena durante edição;
- Cancelar, Aplicar e Salvar possuem semânticas distintas e previsíveis;
- nenhuma regressão nas cotas, estilos, âncoras, render Corona/V-Ray ou Undo;
- pacote instalado e testes automatizados aprovados;
- `PLAN.md`, plano incremental, documentação e ADR sincronizados;
- commit publicado em `origin/main` somente após o gate manual.

## Ordem de execução

1. concluir e aprovar a E10 em andamento;
2. executar somente a prova E11.0;
3. registrar a escolha tecnológica em ADR e pedir gate;
4. implementar E11.1–E11.4 em fatias pequenas;
5. executar E11.5 e o gate manual completo;
6. não iniciar uma etapa posterior enquanto a E11 estiver pendente.

## Regras de colaboração

- cada subetapa atualiza `PLAN.md` antes de encerrar;
- cada subetapa recebe commit próprio e push após testes;
- preservar alterações paralelas da E10 e nunca incluí-las acidentalmente nos commits da E11;
- não usar o mockup como evidência de implementação;
- não tirar capturas nem operar a sessão interativa do Max sem solicitação do usuário.
