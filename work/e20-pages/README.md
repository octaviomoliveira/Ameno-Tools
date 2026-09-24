# E20.6 — Revisar, Exportar e Configurações

Data: 2026-09-23. Branch: `feature/e20-vertical-adaptive-ui`. Base da etapa:
`2ca1838` (E20.5). A instalação do 3ds Max não foi alterada. Nenhum arquivo
MAXScript, do bridge ou do núcleo foi modificado; nenhuma função nova.

## Implementação

- **Cabeçalhos:** título e eyebrow iguais ao nome do rail nas cinco páginas
  (antes: "EDIÇÃO", "SAÍDA", "AMENO" e "Configuração" no singular).
- **Sem instrução repetida:** Revisar, Exportar e Configurações não abrem mais
  com uma mensagem de status que repetia o subtítulo; o status só aparece após
  uma ação. Informações de apoio viraram tooltip (leitura da seleção, fundo
  transparente, diagnóstico sem token, motivo da alteração).
- **Revisar:** estado vazio compacto (antes ocupava a altura do formulário
  inteiro); a troca vazio/carregado usa um host por visibilidade, porque o
  `QStackedWidget` media a altura pela página mais alta.
- **Exportar:** grupo "Renderer" em vez de "Pronto para exportar" (afirmação
  falsa antes de verificar); selo de estado com largura natural; rótulo do
  fundo encurtado para caber em janela estreita; menu "Atualizar".
- **Configurações:** botões secundários com largura natural; texto de
  privacidade com quebra de linha.
- **Mais ações:** mesmo texto em Cotar, Revisar e Exportar. Revisar e Exportar
  usam `ActionRow`: ação principal e Mais ações lado a lado, empilhadas abaixo
  de 420 px de largura de conteúdo.

## Evidência local

- `pages-96dpi.json` e `pages-144dpi.json`: 7 PASS / 0 FAIL
  (`tests/python/test_e20_pages_contracts.py`, 7 REDs antes da implementação).
  O contrato de overflow mede botões, rótulos sem quebra e placeholders nas
  geometrias do plano e em 440×1020; ele encontrou três textos cortados em
  440 px (checkbox de fundo, placeholder do motivo, texto de privacidade).
- Estilos 9/9, prévia 14/14, Cotar 8/8, shell 8/8, janela 20/20, nos dois DPIs.
- `legacy.json`: 69 PASS / 0 FAIL.
- `states-96dpi/` e `gallery-96dpi/`: as três páginas em 780×1020 e 440×1020,
  Revisar vazio e com cota carregada, e as cinco geometrias do plano.
- `tools/validate-package.ps1`: pacote válido para Max 2026.

## Limites

- Qt offscreen; aceite visual no Max em E20.8.
- O contrato de texto cortado cobre as três páginas desta etapa. Estendê-lo a
  Cotar e Estilos é parte da varredura global da E20.7.
- Cotar mantém sua própria linha de ações (limiar de 480 px da página); não foi
  migrada para `ActionRow` para não reabrir a E20.3.

## Reprodução

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-pages --report work/e20-pages/pages-96dpi.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite legacy --report work/e20-pages/legacy.json
& .\.test-output\e20-venv\Scripts\python.exe work/e20-pages/pages_states.py work/e20-pages/states-96dpi
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-pages --report work/e20-pages/pages-144dpi.json
```
