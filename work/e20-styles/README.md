# E20.5 — Estilos: layout adaptativo e semântica

Data: 2026-09-23. Branch: `feature/e20-vertical-adaptive-ui`. Base da etapa:
`21abc26` (E20.4). A instalação do 3ds Max não foi alterada. Nenhum arquivo
MAXScript, do bridge ou do núcleo foi modificado.

## Decisões do usuário (2026-09-23)

1. **Aplicar honesto, sem núcleo novo:** Aplicar sempre usa a versão salva.
   Com rascunho sujo o botão vira **Salvar e aplicar**: salva (o núcleo
   reconstrói as cotas que já usam o estilo) e então aplica. Aplicar um
   rascunho transitório sem salvar continua dependência funcional registrada.
2. **Posição e Ângulo ocultos:** a cota confirmada os ignora. Os valores
   gravados no estilo não mudam e continuam indo no salvamento.

## Implementação

- Salvar estilo fica desabilitado sem alterações e explica que também atualiza
  as cotas que já usam o estilo. Menu: "Aplicar/Salvar e aplicar às cotas
  selecionadas" e "… a todas as cotas". Mensagens informam quantas cotas foram
  aplicadas e quantas do estilo foram reconstruídas.
- Falha ao salvar nunca aplica e mantém o rascunho.
- **Rascunho protegido:** trocar de estilo ou criar/duplicar com alterações
  pergunta Salvar / Descartar / Cancelar. Recarregar a biblioteca (menu ou
  refresh de sessão) mantém o rascunho do estilo atual.
- **Unidade dos valores:** mm, cm ou m no topo dos controles, lembrada entre
  sessões. Só muda a exibição dos seis campos em mm; o rascunho e o bridge
  continuam em mm (ex.: 140 mm = 14,0 cm = 0,1400 m). Espaçamento continua
  sem unidade (unidade relativa do TextPlus).
- **Losango** passa a ser oferecido em Terminais: o núcleo já o suporta
  (`createTerminal`, `addTerminals`) e a prévia E20.4 já o desenha.
- Layout: prévia fixa acima dos controles no vertical e ao lado no largo;
  somente a coluna de controles rola; rodapé fixo. Medido nas cinco geometrias.

## Evidência local

- `styles-96dpi.json` e `styles-144dpi.json`: 9 PASS / 0 FAIL
  (`tests/python/test_e20_styles_contracts.py`, 7 REDs antes da implementação;
  os 2 contratos de layout/aplicação limpa já passavam e ficam como proteção).
- Prévia 14/14, Cotar 8/8, shell 8/8, janela 20/20, nos dois DPIs.
- `legacy.json`: 69 PASS / 0 FAIL.
- `states-96dpi/`: limpo, sujo, Terminais em cm com Losango e salvo+aplicado,
  em 780×1020 e 980×720 (`styles_states.py`).
- `gallery-96dpi/`: Estilos nas cinco geometrias do plano.
- `tools/validate-package.ps1`: pacote válido para Max 2026.

## Limites

- Qt offscreen; suítes MAXScript e aceite no Max não rodaram nesta máquina.
  Salvar e aplicar, Losango salvo e reconstrução precisam do host em E20.8.
- Terminal com tamanho 0 é aceito pelo campo, mas o núcleo recusa terminais
  mesh de tamanho zero; fica como nota para etapa funcional.
- Aplicar rascunho sem salvar, e Posição/Ângulo na cota confirmada, seguem
  como dependências do núcleo.

## Reprodução

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-styles --report work/e20-styles/styles-96dpi.json
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite legacy --report work/e20-styles/legacy.json
& .\.test-output\e20-venv\Scripts\python.exe work/e20-styles/styles_states.py work/e20-styles/states-96dpi
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-venv\Scripts\python.exe tools/e20-baseline.py --suite e20-styles --report work/e20-styles/styles-144dpi.json
```
