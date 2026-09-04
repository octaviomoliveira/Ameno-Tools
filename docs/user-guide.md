# Guia de Uso — Ameno Tools (Cotas Paramétricas)

**Versão:** 0.0.1 (MVP)  
**Compatibilidade:** 3ds Max 2026+ (Corona 13+ / V-Ray CPU 7+)  
**Idioma:** Português (Brasil)

---

## 1. Visão Geral

O **Ameno Tools** é um plugin de produtividade e cotagem técnica/arquitetônica para Autodesk 3ds Max. Ele foi concebido para atender escritórios de arquitetura, visualização 3D (ArchViz) e design de interiores, oferecendo:

- **Cotas inteligentes e paramétricas:** criadas com snap 3D de alta precisão.
- **Três modos de cotagem:** Alinhada, Horizontal (projeção em X) e Vertical (projeção em Y).
- **Âncoras reativas em tempo real:** cotas que acompanham objetos quando eles são movidos ou transformados na cena.
- **Estilos visuais padronizados:** presets Arquitetônico, Editorial e Técnico com controle vetorial de terminais (tick, setas, pontos).
- **Sobrescrita manual auditável (`[M]`):** substituição de valores sem perder a medição real de engenharia.
- **Operações em lote:** aplicação rápida de unidades, precisão decimal, modos e *Bake* de âncoras para congelamento.
- **Render Separado de Cotas:** geração de PNG com fundo transparente 100% isolado da geometria comum da cena para pós-produção no Photoshop, preservando a câmera, resolução e enquadramento exatos do Render Setup.

---

## 2. Instalação e Ativação

### 2.1 Instalação
O pacote é instalado como plugin modular padrão da Autodesk em:
`%APPDATA%\Autodesk\ApplicationPlugins\AmenoTools`

### 2.2 Abrindo o Painel
1. No menu principal do 3ds Max, abra **Customize** -> **Customize User Interface**.
2. Na aba **Toolbars** ou **Quads**, filtre pela categoria **Ameno Tools**.
3. Arraste a ação **Ameno Tools** para sua toolbar favorita.
4. Clique no botão para abrir o painel flutuante compacto.

---

## 3. Fluxo de Trabalho de Criação

### 3.1 Três Cliques
1. No painel, no rollout **Criação de Cotas**, escolha o **Modo**:
   - **Alinhada:** mede a distância euclidiana direta entre os pontos A e B.
   - **Horizontal:** projeta os pontos no eixo X e mantém a linha principal horizontal.
   - **Vertical:** projeta os pontos no eixo Y e mantém a linha principal vertical.
2. Clique no botão **Criar Cota** (ou atalho). O snap 3D é ativado automaticamente.
3. **Clique 1 (Ponto A):** clique no primeiro ponto de referência ou vértice.
4. **Clique 2 (Ponto B):** clique no segundo ponto. Uma prévia interativa da linha e do texto passa a acompanhar o cursor.
5. **Clique 3 (Afastamento):** clique no local onde deseja posicionar a linha principal da cota.
6. A cota permanente é gerada na layer gerenciada `AMENO_COTAS`.

---

## 4. Modos e Edição em Lote

### 4.1 Modos de Cotagem
- **Alinhada:** ideal para paredes diagonais, rampas e elementos inclinados.
- **Horizontal:** ideal para cotas de vãos internos, larguras de cômodos e fachadas.
- **Vertical:** ideal para alturas de peitoris, pés-direitos e profundidades.

### 4.2 Edição de Várias Cotas (Seleção Múltipla)
Ao selecionar uma ou mais cotas na viewport (selecionando qualquer nó da cota ou seu controlador), use a seção **Selecionadas** no rollout **Âncoras e Diagnóstico**:
- **Aplicar Unidade:** converte todas as cotas selecionadas para metros (`m`), centímetros (`cm`) ou milímetros (`mm`).
- **Aplicar Precisão:** ajusta as casas decimais (ex.: `2` para `4,05 m`, `0` para `405 cm`).
- **Aplicar Modo Atual:** altera o modo de todas as cotas selecionadas para o modo ativo no radio do painel (Alinhada / Horizontal / Vertical).
- **Bake Âncoras:** congela as âncoras de objetos em posições fixas mundiais. Todas as operações de lote são protegidas por **um único passo de Undo (Ctrl+Z)**.

---

## 5. Âncoras e Reatividade

### 5.1 Como funcionam as Âncoras
Quando você clica em um objeto para iniciar ou finalizar uma cota, o Ameno Tools detecta o nó automaticamente. Se o clique com snap estiver sobre um vértice de Editable Poly ou Editable Mesh, também registra o ID desse vértice; nos demais casos, registra a âncora em coordenadas locais:
- Se você mover, rotacionar ou escalar o objeto, a cota se atualiza instantaneamente no viewport.
- Âncoras identificadas como vértice acompanham a edição desse vértice no base object.
- **Limitação conhecida:** Delete, Weld, Attach, subdivisões e outras mudanças topológicas podem renumerar os vértices. Nessa situação, a cota preserva a última posição e fica órfã, em vez de saltar para outro ponto. Edit Poly como modificador e FFD ainda não fazem parte desta primeira entrega.

### 5.2 Cotas Órfãs e Reparo
Se um objeto ancorado for deletado da cena:
- A cota entra em estado de **alerta (órfã)** e fica avermelhada na viewport, mas **não desaparece nem corrompe a cena**.
- Clique em **Reparar Cotas Órfãs** para converter automaticamente as referências perdidas em coordenadas mundiais estáticas.

---

## 6. Render Separado de Cotas (Overlay PNG)

Para sobrepor as cotas no Beauty renderizado no Photoshop sem poluir a cena 3D:

1. Configure seu enquadramento (Câmera ou Vista) e Render Setup (Resolução, Frame, Aspect).
2. No rollout **Render Separado de Cotas**:
   - Escolha o escopo: **Todas** as cotas da cena ou apenas as **Selecionadas**.
   - O campo **PNG** exibe o nome automático (ex.: `nomeCena_cotas_f0.png`).
3. Clique em **Renderizar Cotas**:
   - O Ameno Tools isola a cena transacionalmente em memória.
   - Aplica material emissivo puro (`CoronaLightMtl` para Corona ou `VRayLightMtl` para V-Ray).
   - Renderiza em alta velocidade (1-2 segundos) com fundo 100% transparente (canal Alpha).
   - Restaura instantaneamente todos os materiais, luzes, layers e configurações originais do usuário.
4. No Photoshop ou software de composição:
   - Abra o Beauty renderizado.
   - Coloque o PNG das cotas em uma camada superior. O alinhamento de pixels é milimétrico e idêntico!

---

## 7. Diagnóstico e Saúde da Cena

Clique no botão **Relatório de Diagnóstico** para obter um sumário detalhado instantâneo no MAXScript Listener e na tela:
- Quantidade total de cotas.
- Distribuição por modo (Alinhada, Horizontal, Vertical).
- Distribuição por tipo de âncora (Mundial, Objeto A, Objeto B, Ambos).
- Identificação de nós ausentes ou cotas órfãs.
