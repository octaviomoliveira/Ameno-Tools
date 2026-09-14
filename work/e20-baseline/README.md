# E20.0 — Baseline vertical, contratos RED e regressões

Execução: 2026-09-13. Checkpoint concluído em 2026-09-14. Gate E20.0 aprovado;
nenhum arquivo de produção foi alterado nesta etapa. Não é aceite visual da E20.

## Identidade da execução

- Base publicada: `origin/develop`, SHA `1acc10af35a289c18ffafa9186ca2055e4f97f41`.
- Branch de execução: `feature/e20-vertical-adaptive-ui`.
- Plano trazido da branch de planejamento por cherry-pick: `d030e4f46e0e9e83c7c61d6e1b17f6b24e65dfd4`.
- Esse HEAD é o baseline funcional, anterior a qualquer correção E20.
- Não houve instalação, merge, tag ou alteração da sessão/cena interativa.

## Evidência visual preservada

Os originais do usuário foram copiados sem edição. Dimensões são pixels da
imagem, incluindo moldura nativa; não equivalem ao viewport lógico do Qt.
SHA-256 completos e hashes de todos os fontes estão em [inputs.json](inputs.json).

| Original | Dimensões | Observação |
| --- | --- | --- |
| [Cotar quase quadrada](user/01-cotar-square-clipped.png) | 783×769 | Cartão de cena cortado e CTA fora da captura. |
| [Cotar vertical](user/02-cotar-vertical.png) | 781×1072 | Fluxo principal, CTA e Ajustar detalhes visíveis. |
| [Estilos vertical](user/03-estilos-vertical.png) | 789×1075 | Prévia acima dos controles e ações fixas. |

Origem: anexos `codex-clipboard-8905f792-4562-49ce-85da-36e0287d33d1.png`,
`codex-clipboard-726baad4-208b-40b2-bce9-d388fce7dfab.png` e
`codex-clipboard-5f497c4c-d760-477e-83ca-4879ef127f03.png` fornecidos em 2026-09-13.

O HEAD também foi capturado com Qt 6.5.3 offscreen: cinco páginas em cinco
geometrias, em 96 e 144 DPI solicitados, totalizando 50 PNGs. Cada
`qt-96dpi/metrics.json` e `qt-144dpi/metrics.json` contém SHA, tamanho lógico,
pixels físicos, DPR, viewport, sidebar, scroll, retângulos e métricas de texto.

| Geometria lógica | Cotar: CTA no primeiro viewport | Estilos: região de controles |
| --- | --- | --- |
| 780×720 | Sim no controle offscreen | 668×171, empilhado |
| 780×1020 | Sim | 668×466, empilhado |
| 980×720 | Sim | 456×451, lateral |
| 780×560 | Não; rolagem vertical 129 px | 668×101, empilhado |
| 1280×800 | Sim | 624×519, lateral |

Valores iguais nos dois DPRs, em coordenadas lógicas. O padrão offscreen atual
é 780×720 a 96 DPI e 780×560 a 144 DPI, devido à área lógica do monitor virtual.
Não há uma primeira abertura vertical correta ainda.

**Limite da evidência:** o plugin offscreen usa fonte/métricas distintas do Max
interativo. A 144 DPI ele produz DPR 1,5 e `logicalDpiY=96`; isso não reproduz a
densidade tipográfica das capturas do usuário. O CTA passa a 780×720 nesse
controle, apesar do problema visível no host. Esse PASS foi mantido como
controle positivo, não como prova de correção ou aceite. A galeria não contém
chrome nativo. Maximização real, monitores físicos e a matriz completa
100/125/150/200% ainda serão validados nas etapas seguintes.

## Resultados automatizados

- [Regressões Python anteriores](legacy-python.json): 69 PASS, zero FAIL.
- [Contratos E20 a 96 DPI](e20-red-96dpi.json): 1 PASS, 12 FAIL esperados.
- [Contratos E20 a 144 DPI](e20-red-144dpi.json): 1 PASS, os mesmos 12 FAIL.
- `tools/validate-package.ps1`: pacote estrutural válido para Max 2026.
- MAXScript: 19/19 suítes PASS, 31 marcadores finais PASS e zero FAIL, runner
  sequencial legado `tools/run-e18-max-gates.ps1`, exit 0. Execução das 20:01:30
  às 20:17:36 (-03:00) em 2026-09-13. [Resumo completo](max-regression/summary.txt).
  Inclui bridge/host Qt, fachadas, cadeia, rollback, biblioteca/cor, overlay,
  mouseMove sem cena, callbacks e performance. E16: 13/13 verificações
  mouseMove, callbacks 6/6 (máximo 1), commit 17/17; sete segmentos em 242 ms.
  Alguns acentos no resumo do runner legado foram decodificados incorretamente;
  marcadores ASCII e contagens estão intactos, logs originais preservados localmente.

Os testes RED são assertions reais, sem `xfail`, skip ou mudança nos testes
antigos. A suíte E20 deve retornar exit 1 até a implementação; não é uma
regressão introduzida pela baseline. O runner separado permite registrar todos
os defeitos sem parar no primeiro. Não interpretar um runner global vermelho
como autorização para enfraquecer esses contratos.

### Três contratos de janela — responsabilidade E20.1

1. Não sobrescrever um tamanho válido aceito pela restauração do Qt (780×600
   vira 780×720 a 96 DPI). Se a geometria restaurada não couber no monitor
   atual, recuperar um tamanho seguro; a 144 DPI, 780×560 ainda excede 533×533.
2. Em monitor com área 1280×1200, primeira abertura deve ser vertical.
3. Em área 640×720, a janela não pode exceder a largura disponível.

O primeiro teste observa o retorno e tamanho após `restoreGeometry` real;
aceitar `resize` não prova que uma janela cabe no monitor. Os dois últimos
usam área útil controlada, não dependem do monitor da máquina.
Ainda será necessário expandir os casos para posição, moldura, maximização e
remoção de monitor. A janela atual sempre aplica `resize` depois de
`restoreGeometry`, e `max(780, min(780, ...))` nunca reduz a largura de 780.

### Nove contratos de prévia — responsabilidade E20.4

Sete são invariantes da geometria/escala confirmada, conferidos no código
MAXScript; os testes Python não executam TextPlus nem renderizam cotas do Max.

| Contrato | Resultado atual | Oráculo |
| --- | --- | --- |
| Base/comprimento da seta fechada | 0,90; esperado 0,50 | `ameno_dimension_terminal_mesh.ms`, `createTerminal`, meia base `size*0.25` |
| Base/comprimento da seta aberta | 0,84; esperado 0,50 | `ameno_dimension_graphics.ms`, `addTerminals` |
| Setas padrão paralelas à cota | Prévia gira 45°; commit mantém eixo | `addTerminalMeshes`/`addTerminals`, direção do layout |
| Raio do ponto/tamanho do terminal | 0,16; esperado 0,35 | `createTerminal`, raio `size*0.35` |
| Losango centrado, diagonais iguais | Três vértices; esperado quatro | `createTerminal`, quatro pontos ±`size*0.5` |
| Terminal, recuo e prolongamento com escala única | Prolongamento/terminal 1,20; esperado 1 | Conversão comum por `toSceneUnits` |
| Espessura nominal/tamanho | 0,75; esperado 0,10 | `configureLineShape`, espessura e terminal em mm |

Os outros dois são requisitos de apresentação E20:

- Zoom de 50% para 100% não pode mudar a proporção terminal/vão medido. Hoje
  muda de aproximadamente 0,03476 para 0,05040.
- Fonte 5000 mm e afastamento 1000 mm são aceitos pelos controles, mas o modelo
  posiciona a máscara acima do canvas (`y=-90,672` em 620×240).

Limites: a espessura testada é nominal, não largura antialiasada ou projetada;
a máscara não prova os contornos/fontes reais de TextPlus. Losangos e setas
usam a representação atual de `PreviewTerminal.points`; se ela mudar, preservar
as invariantes físicas ao adaptar o teste. `outside` e paridade tipográfica
precisam de casos adicionais. Os pontos arquitetônicos junto à parede não
foram confundidos com terminais.

## Mapa de implementação e efeitos externos

| Área | Fonte principal | Situação no HEAD |
| --- | --- | --- |
| Janela/persistência | `window.py`, `preferences.py` | Mínimo 780×560; restaura e depois sobrescreve tamanho. QSettings isolado nos testes. |
| Shell | `window.py`, `responsive.py`, `page_scaffold.py` | Árvores fixas; breakpoints 900/1280 pelo shell; rail 64/184/208. Deve usar área útil na E20.2. |
| Cotar | `create_page.py`, `components.py` | Scroll externo; quatro ChoiceCards; CTA + menu. Cadeia mantém Automática desabilitada. |
| Estilos | `styles_page.py`, `window.py::FixedPageHost` | Host fixo; controles com scroll próprio; prévia e footer fora dele. Lateral quando página tem 780 px. |
| Prévia | `dimension_preview.py`, `styles_page.py`, `style_draft.py` | Snapshot/draft e geometria locais; escalas/clamps independentes distorcem proporções. |
| Parâmetros/unidades | `parameter_control.py`, `style_draft.py`, `models.py` | Validar conversão física e sufixos na E20.5; não alterar unidade da cena para formatar campo. |
| Revisar/Exportar/Configurações | `edit_page.py`, `render_page.py`, `config_page.py` | Scroll externo; revisão visual após os padrões centrais. |
| Fronteira de comandos | `bridge.py`, `scripts/ameno/ui/ameno_ui_bridge.ms` | Cena somente por comandos explícitos; navegação/resize/preview permanecem locais. |

Fontes Python relativos a `Contents/python/ameno_ui/`; MAXScript relativo a
`Contents/`. A captura usa bridge que falha em qualquer acesso inesperado;
zero chamadas durante as 25 combinações por execução. Fechar o shell chama o
cancelamento previsto pelo lifecycle. Nunca reutilizar o fake como backend de
produto.

## Dependências funcionais identificadas, não implementadas

**ATENÇÃO — NECESSIDADE NO CÓDIGO FUNCIONAL:** `StylesPage.apply_selected` e
`apply_all` encaminham somente `_current.style_id`; o `applyStyleCommand` da
fachada aceita ID e escopo, reconstruindo o draft da versão salva. Assim,
Aplicar ignora o rascunho editado na UI. Já `saveStyleCommand` chama
`AmenoStyleService.updateStyleAndRebuild`, podendo alterar cotas existentes.
Recomendação: contrato explícito para aplicar snapshot transitório à seleção
ou a todas, separado da persistência reutilizável, com Undo, falhas, biblioteca
e reabertura testados. Não declarar E20.5 completa sem resolver/autorização.

**ATENÇÃO — NECESSIDADE NO CÓDIGO FUNCIONAL:** ângulo e posicionamento de
terminais não têm contrato uniforme entre overlay e geometria confirmada.
Não apresentar resposta visual que o desenho não reproduza. Registrar quais
tipos realmente respeitam cada parâmetro e tratar a correção funcional em
etapa própria, preservando o núcleo nesta rodada.

Há também risco local de perder rascunho ao trocar de estilo/refresh e ao
duplicar a versão salva em vez da editada. É responsabilidade E20.5 proteger o
rascunho e comunicar a decisão, não salvar/aplicar implicitamente.

## Reprodução

Runtime externo de teste: CPython embeddable 3.11.9 e PySide6/Shiboken 6.5.3,
isolados em `.test-output/`. Não copiar DLLs para Autodesk nem instalar pacote
Python no Max. A distribuição Qt do Max fornece somente plataforma Windows,
não `offscreen`; tentativas de usá-la fora do host não constituem testes Ameno.
O Max Batch continua usando seu próprio Python 3.11.12/Qt 6.5.3.

Download oficial do runtime de teste:
`https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip`.
SHA-256: `009D6BF7E3B2DDCA3D784FA09F90FE54336D5B60F0E0F305C37F400BF83CFD3B`.
Extraído em `.test-output/e20-python3119`; PySide6 e dependências em
`.test-output/e20-qt-runtime`. Acrescentar `../e20-qt-runtime` ao
`python311._pth`, mantendo as entradas originais. Não usar Python 3.12 com
esses binários. Dependências podem ser obtidas com pip `--target`,
`--platform win_amd64 --python-version 3.11 --implementation cp --abi abi3
--only-binary=:all: PySide6==6.5.3`.

Em PowerShell, a partir da raiz deste repositório:

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_PLUGIN_PATH = 'D:\Ameno\_tools\.test-output\e20-qt-runtime\PySide6\plugins'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --suite legacy --report work/e20-baseline/legacy-python.json
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --suite e20 --report work/e20-baseline/e20-red-96dpi.json
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --capture work/e20-baseline/qt-96dpi
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --suite e20 --report work/e20-baseline/e20-red-144dpi.json
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --capture work/e20-baseline/qt-144dpi
& .\tools\validate-package.ps1
& .\tools\run-e18-max-gates.ps1 -EvidenceDirectory 'work\e20-baseline\max-regression'
```

Não repetir o runner Max enquanto outro estiver executando. Ele reutiliza logs
temporários e executa cada suíte em processo isolado, sem reload da mesma
geração. Os logs brutos ficam locais (`*.log` ignorados); o resumo é versionado.

`inputs.json` compara, somente em leitura, os fontes com a instalação anterior:
53 arquivos presentes equivalentes ao normalizar EOL/BOM, zero divergências de
conteúdo; sete fontes WPF legados não distribuídos estão ausentes. Os hashes
binários são registrados separadamente e alguns diferem por EOL. Isso permite
identificar o código carregado pelo autoload nos gates atuais, **não** substitui
a paridade binária exigida para uma nova instalação na E20.8.

## Próxima etapa

E20.0 fechada com regressões legadas verdes e evidência registrada.
E20.1: corrigir e ampliar os três contratos de geometria; manter os nove
REDs da prévia identificados até E20.4. A galeria atual deve permanecer como
baseline: guardar capturas posteriores em outra pasta.
