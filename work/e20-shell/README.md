# E20.2 — shell adaptativo e identidade

Data: 2026-09-23. Branch: `feature/e20-vertical-adaptive-ui`. Base da etapa:
`f0ee2dd` (E20.1). A instalação do 3ds Max não foi alterada.

## Implementação

- O modo compacto/médio/largo deriva da largura real do viewport da página,
  com histerese de 16 px para evitar alternância causada pela scrollbar.
- O rail Ameno permanece compacto e em ordem Cotar, Estilos, Revisar,
  Exportar, Configurações; Ajuda fica antes de Configurações. Todos os botões
  têm nome acessível, tooltip, ativação por teclado e alvo de pelo menos
  44×44 px.
- Tokens de cor e estados de hover, seleção, foco, pressionado e desabilitado
  foram consolidados. Contraste dos pares essenciais é medido no teste.
- Resize e navegação preservam a mesma árvore de páginas, hosts e conexões.
  O shell não consulta a cena durante essas interações.
- A página passou a se chamar **Estilos**, como definido no plano E20.

## Evidência local

- `shell-96dpi.json`: 8 PASS / 0 FAIL.
- `shell-144dpi.json`: 8 PASS / 0 FAIL.
- `legacy.json`: 69 PASS / 0 FAIL.
- `gallery-96dpi/metrics.json`: 25 capturas de 5 páginas em 780×720,
  780×1020, 980×720, 780×560 e 1280×800. Zero rolagem horizontal em todas.
- `tools/validate-package.ps1`: pacote válido para Max 2026.

Em 780×560, a ação de Cotar fica acessível por rolagem vertical; esse tamanho
é um teste de compressão, não o mínimo do produto. O preview de Estilos nessa
altura e sua fidelidade geométrica pertencem a E20.4/E20.5. Os 9 contratos
RED de `test_e20_preview_contracts.py` seguem falhando conforme a baseline
E20.0 e não fazem parte do gate do shell.

As capturas são evidência Qt offscreen. O aceite visual no 3ds Max 2026 e a
instalação do candidato pertencem a E20.8. Não houve merge em `develop` ou
`main`.
