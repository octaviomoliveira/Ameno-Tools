# E20.1 — Janela vertical e persistência segura

Execução e gate concluídos em 2026-09-14 no commit funcional
`032914618ba80092f67e1bd6e02f1e6a19951f9a`. Não houve instalação, merge ou
tag; o pacote ativo do 3ds Max permaneceu inalterado.

## Resultado

- Primeira abertura em proporção vertical `780×1020`, centralizada e reduzida
  uniformemente quando a área útil do monitor é menor.
- Redimensionamento livre, sem mínimo fixo de produto; conteúdo vertical fica
  sob responsabilidade das regiões roláveis de cada página.
- Tamanho e posição normais, estado maximizado, identidade da tela e sua área
  útil são persistidos separadamente.
- Geometrias inválidas, excessivas, fora da tela, em monitor removido ou após
  mudança de resolução/DPI são recuperadas para um monitor real.
- A moldura nativa é conferida uma vez depois de materializada pelo host. Uma
  janela aberta maximizada repete essa conferência ao voltar ao estado normal.
- Não há polling, gravação durante arraste, acesso ao bridge, à cena ou ao
  viewport nesse fluxo.

## Gates

| Evidência | Resultado |
| --- | --- |
| [Contratos de janela — 96 DPI](window-96dpi.json) | 20 PASS, 0 FAIL |
| [Contratos de janela — 144 DPI](window-144dpi.json) | 20 PASS, 0 FAIL |
| [Regressões Python E15–E19](legacy-python.json) | 69 PASS, 0 FAIL |
| [Contratos de prévia adiados](preview-deferred.json) | 0 PASS, 9 FAIL esperados para E20.4 |
| `tools/validate-package.ps1` | pacote válido para 3ds Max 2026 |
| Compilação Python | exit 0 |
| [Host Max 2026](max-host-summary.txt) | 1 PASS, 0 FAIL |

Os quatro relatórios Python registram o mesmo HEAD funcional, versões do
runtime, hashes dos testes e hashes de todos os fontes de `ameno_ui`. O runtime
offscreen é CPython 3.11.9 com PySide6/Qt 6.5.3. Os nove REDs da prévia são a
baseline deliberadamente preservada para E20.4, não regressões desta etapa.

## Gate no host Autodesk

`test_e20_window_host.ms` executou em processo Batch isolado do 3ds Max 2026.3,
com Python 3.11.12 e Qt 6.5.3. O teste carregou o entrypoint da branch e usou
um arquivo de preferências temporário. Foram validados:

1. primeira abertura vertical com o frame inteiro dentro da área útil;
2. gravação e reabertura exata de uma geometria normal segura;
3. maximizar, minimizar, fechar e reabrir ainda maximizada;
4. retorno ao estado normal pelo estado da janela nativa, preservando a
   geometria e mantendo o frame acessível.

Resultado final do runner: `MAXScript smoke test: OK. PASS markers: 1; FAIL
markers: 0.` O teste não leu nem substituiu a instalação ativa.

## Reprodução

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_FONT_DPI = '96'
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --suite e20-window --report work/e20-window/window-96dpi.json
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --suite legacy --report work/e20-window/legacy-python.json
$env:QT_FONT_DPI = '144'
& .\.test-output\e20-python3119\python.exe tools/e20-baseline.py --suite e20-window --report work/e20-window/window-144dpi.json
& .\tools\validate-package.ps1
& .\tools\test-maxscript.ps1 -TestScript .\tests\maxscript\test_e20_window_host.ms
```

## Próxima etapa

E20.2: medir breakpoints pelo viewport real, consolidar shell/tokens e fechar
overflow horizontal, foco, contraste, alvos e navegação por teclado.
