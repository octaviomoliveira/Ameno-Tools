# ADR 0024 — Interface Python/Qt reescrita do zero

Data: 2026-09-09

Status: decidido; implementação iniciada para o Max 2026

## Contexto

A interface WPF apresentou falhas recorrentes de lifecycle e reparenting no
bridge `mxsdotNet`, incluindo controles com dois pais lógicos, Visual fora da
árvore esperada, handlers de gerações antigas e crash durante reload no mesmo
processo. O usuário decidiu abandonar essa camada e priorizar exclusivamente a
transição antes de otimizações do núcleo de viewport.

O produto poderá precisar de uma rota de compatibilidade do 3ds Max 2021 ao
2027, mas não existem ambientes para 2022, 2023, 2025 e 2027. Para reduzir risco
e entregar estabilidade primeiro, o usuário determinou que o candidato inicial
será implementado e certificado somente no Max 2026.

## Decisões

1. A nova interface será escrita do zero em Python/Qt. Arquivos, XAML, controles,
   handlers e renderers WPF não serão copiados, importados ou hospedados.
2. O WPF será somente inventário de requisitos. Serviços MAXScript de domínio
   permanecem como backend por uma fachada nova `AmenoUiBridge`.
3. O candidato inicial usará Python 3.11/PySide6 do Max 2026. `qt_compat`
   centralizará o binding, mas suporte PySide2 será implementado somente depois
   do aceite do 2026.
4. O launcher universal será MAXScript chamando `python.Init/ExecuteFile`; não
   haverá dependência de wheels externos ou de `.py` direto no manifesto.
5. Existirá uma janela modeless por processo, com parent único, páginas fixas em
   `QStackedWidget` e sem reparenting. Reload no mesmo processo é proibido.
6. A janela usará chrome nativo do Windows com minimizar, maximizar/restaurar e
   fechar. Uma janela frameless/custom titlebar não entra na primeira versão.
7. Login por token será a primeira página. Token ficará apenas em memória, será
   mascarado/redigido e validado de forma assíncrona por `QNetworkAccessManager`.
8. Nenhuma navegação, pintura ou timer da UI chamará cena/viewport. Signals usam
   comandos explícitos, não reentrantes e snapshots primitivos.
9. A release inicial será certificada somente no Max 2026 e seu manifesto
   continuará restrito a essa versão. Todas as demais ficam adiadas.
10. Otimização do preview/commit fica fora da E15. A E15 deve provar que a UI não
    adiciona regressão à baseline já conhecida.

## Consequências

- A interface não herda a dívida de lifecycle do WPF.
- Haverá esforço maior de reconstrução e teste, compensado por limites claros.
- A portabilidade futura terá uma fronteira de binding clara, sem impor agora o
  risco de uma matriz multiversão não executada.
- A autenticação real depende de contrato/endpoint ainda não fornecido.
- Um travamento causado pelo núcleo atual pode continuar após a transição; será
  tratado em marco separado, com baseline capaz de separar as causas.

## Evidência esperada

- Plano: `plans/2026-09-09-e15-transicao-wpf-python-qt.md`.
- Testes de import/compatibilidade no Python embarcado do Max 2026.
- Gates de login, lifecycle, páginas, viewport e pacote no Max 2026.
- Busca estática provando ausência de WPF no pacote novo.

## Estado do candidato (2026-09-09)

Implementados `Contents/python/ameno_ui/`, `ameno_ui_bridge.ms` e
`ameno_python_ui.ms`. O pacote ativo do Max 2026 e o ZIP alpha não carregam os
módulos de apresentação WPF; a navegação Qt não faz refresh implícito e o
fechamento cancela uma coleta antes do teardown. Compilação/import Python,
smoke MAXScript, smoke da ponte e teste do pacote instalado passaram.

O token ainda usa `LocalTokenGateway` (não há endpoint/contrato fornecido), e a
validação visual/soak só será marcada após uma sessão gráfica real do Max 2026.
Essas pendências não autorizam adaptar o binding para outras versões nem
reintroduzir a camada WPF.
