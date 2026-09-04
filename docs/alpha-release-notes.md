# Release Notes — Ameno Tools v0.0.1-alpha (MVP)

**Data de Lançamento:** 2026-09-04  
**Status da Versão:** Alpha Interno (MVP Completo)  
**Compatibilidade:** Autodesk 3ds Max 2026.3+ (Corona 13+ / V-Ray CPU 7+)  
**Artefato de Distribuição:** `dist/AmenoTools-0.0.1-alpha.zip`

---

## 1. Destaques da Versão

Esta versão consolida todos os marcos técnicos do MVP do **Ameno Tools** (E1 a E10), oferecendo uma solução completa e robusta de cotagem técnica paramétrica para fluxo de trabalho em visualização arquitetônica:

1. **Cotas Paramétricas com Snap 3D (E1-E5):**
   - Criação fluida com 3 cliques (Ponto A, Ponto B, Afastamento) e prévia em tempo real.
   - Camada de dados com Custom Attributes v4 persistentes e auditáveis.
   - Nós organizados automaticamente nas layers gerenciadas `AMENO_COTAS` e `AMENO_SYSTEM`.

2. **Três Modos de Cotagem (E10.1):**
   - **Alinhada:** medição direta euclidiana em 3D.
   - **Horizontal:** projeção no eixo X da cena.
   - **Vertical:** projeção no eixo Y da cena.

3. **Sobrescrita Manual Auditável `[M]` (E6):**
   - Suporte a arredondamento, valores manuais numéricos e anotações de texto livre.
   - Preservação perpétua da medição real nos atributos da cota para fins de auditoria de engenharia.

4. **Estilos e Presets de Desenho (E7):**
   - Presets **Arquitetônico** (ticks 45°), **Editorial** (setas preenchidas) e **Técnico** (pontos circulares).
   - Diálogo dedicado de edição de estilos com sincronização automática entre cotas.

5. **Âncoras Reativas e Reparo de Órfãs (E8, ADR 0015):**
   - Cotas vinculadas a nós de geometria acompanham translações e rotações em tempo real.
   - Detecção automática de objetos excluídos com alerta visual e ferramenta de reparo de órfãs.

6. **Render Separado de Cotas com Fundo Transparente (E9, E10.3):**
   - Geração de arquivos PNG transparentes para composição direta no Photoshop.
   - Adapters dedicados para **Corona Renderer** (`CoronaLightMtl`) e **V-Ray CPU** (`VRayLightMtl`).
   - Isolamento transacional em memória: restaura 100% da iluminação, materiais e Render Setup do usuário.

7. **Operações em Lote e Bake de Âncoras (E10.2):**
   - Conversão de unidades (m, cm, mm), ajuste de precisão decimal e troca de modo para seleções múltiplas.
   - Ferramenta de *Bake* com confirmação para fixar âncoras reativas em coordenadas mundiais estáticas.
   - Todas as operações em lote protegidas por 1 único passo de Undo.

8. **Auditoria e Diagnóstico da Cena (E10.4):**
   - Relatório completo de integridade gráfica, modos, âncoras e anomalias com 1 clique.

9. **Escalabilidade Comprovada (E10.5):**
   - Testada e aprovada com até 1.000 cotas simultâneas na cena (3.000 nós no viewport) com zero falhas.

---

## 2. Instruções de Instalação para Testadores

1. Feche o Autodesk 3ds Max.
2. Descompacte o arquivo `AmenoTools-0.0.1-alpha.zip`.
3. Copie a pasta descompactada para:  
   `%APPDATA%\Autodesk\ApplicationPlugins\AmenoTools`  
   *(Certifique-se de que o arquivo `PackageContents.xml` fique localizado diretamente dentro dessa pasta)*.
4. Abra o 3ds Max 2026.
5. Acesse **Customize** -> **Customize User Interface** -> aba **Toolbars** -> categoria **Ameno Tools**.
6. Arraste o botão **Ameno Tools** para a barra de ferramentas superior.

---

## 3. Roteiro de Validação em Planta Real

Para o gate de validação com os arquitetos e artistas de ArchViz:
- [ ] Criar cotas de vãos internos no modo **Horizontal**.
- [ ] Criar cotas de alturas de peitoril e vãos verticais no modo **Vertical**.
- [ ] Cotar paredes chanfradas no modo **Alinhada**.
- [ ] Mover um bloco de parede/esquadria e verificar a cota acompanhando o objeto.
- [ ] Selecionar todas as cotas da planta baixa e converter a unidade para **cm** com 0 decimais em lote.
- [ ] Executar **Renderizar Cotas** no Corona ou V-Ray e sobrepor o PNG gerado no Photoshop sobre o Beauty renderizado.
- [ ] Clicar em **Relatório de Diagnóstico** e verificar a saúde da cena no Listener.
