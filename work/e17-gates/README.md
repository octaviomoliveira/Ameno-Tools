# Evidência dos gates E17 — Max 2026

Esta pasta guarda a saída local da matriz executada em 2026-09-09 contra a
cópia ativa do pacote em `ApplicationPlugins`.

- `summary.txt`: resumo legível, com 18/18 suites MaxScript aprovadas;
- `test_*.listener.log` e `test_*.system.log`: logs brutos por suite, mantidos
  localmente (`*.log` não entra no Git);
- o processo do 3ds Max foi encerrado entre as execuções Batch, e a instalação
  foi feita somente com o Max fechado.

Suites cobertas: bootstrap, E12 (matemática, entrada, commit, lifecycle,
picking e transação), E13 (estilos/cor), E14 (planos, gráficos e ferramentas),
E15 (bridge Qt), E17 (host Qt) e E16 (overlay, mouseMove, callbacks e commit).

Resultado complementar: `tools/run-python-gates.py` passou 17/17 testes com
Python 3.11/PySide6 6.5.3. O pacote distribuível validado é
`dist/AmenoTools-0.0.1-e17-canary.zip`, SHA-256
`7F3ACAA4BE5D2F1BE7E9EEF90DFEAE2BC57F7B3589ABE7CD8145A59E5E09B406`.
O smoke `test_installed_package.ms` também terminou com exit code 0, 1 PASS e
0 FAIL.
