# E19 — instalação canary da página Estilo

Data: 2026-09-10 02:22 (America/Fortaleza)

## Origem e destino

- Branch: `feature/e19-qt-visual-acceptance`
- Commit funcional: `3e40860`
- Destino: `C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`
- Backup recuperável: `D:\Ameno\backups\AmenoTools-before-e19-style-20260910-022254`
- 3ds Max e 3ds Max Batch estavam fechados antes da cópia.

## Gates executados

- `python tools/run-python-gates.py`: **PASS, 66 testes**.
- `python -m compileall -q Contents/python`: **PASS**.
- `tools/validate-package.ps1`: pacote válido para 3ds Max 2026.
- Comparação SHA-256 entre fonte e instalação: **6/6 arquivos críticos idênticos**.
- Cache Python, `.pyc`, XAML ou WPF no pacote instalado: **0**.
- Captura 980×720: `work/e19-visual/02-estilo-980x720.png`.
- Captura compacta 780×560: `work/e19-visual/03-estilo-780x560.png`.

## Contratos cobertos

- navegação e título renomeados para Estilo;
- seletor atual, Novo estilo e menu de ações no topo;
- Texto, Linhas, Terminais e Cores recolhíveis;
- preview local sempre fora do scroll dos controles;
- duas colunas em 980×720 e preview acima em largura reduzida;
- rodapé fixo com dirty state, Salvar estilo e Aplicar;
- alteração de parâmetro atualiza a prévia sem bridge, cena, renderer, pymxs,
  viewport ou timer.

## Gate ainda pendente

Abrir o 3ds Max 2026 e validar fonte/DPI reais, interação dos sliders, mudança
dos grupos, salvar e aplicar. A evidência offscreen não substitui o aceite no
host.
