# ADR 0024 — Interface Python/Qt reescrita do zero

Data: 2026-09-09

Status: decidido; implementação pendente

## Contexto

A interface WPF apresentou falhas recorrentes de lifecycle e reparenting no
bridge `mxsdotNet`, incluindo controles com dois pais lógicos, Visual fora da
árvore esperada, handlers de gerações antigas e crash durante reload no mesmo
processo. O usuário decidiu abandonar essa camada e priorizar exclusivamente a
transição antes de otimizações do núcleo de viewport.

O produto também precisa ter uma rota de compatibilidade do 3ds Max 2021 ao
2027. Esse intervalo atravessa Python 3.7–3.13, PySide2/PySide6 e Qt5/Qt6.

## Decisões

1. A nova interface será escrita do zero em Python/Qt. Arquivos, XAML, controles,
   handlers e renderers WPF não serão copiados, importados ou hospedados.
2. O WPF será somente inventário de requisitos. Serviços MAXScript de domínio
   permanecem como backend por uma fachada nova `AmenoUiBridge`.
3. Todo código Python será compatível com Python 3.7 e usará uma única camada
   `qt_compat` para PySide2/PySide6 e Qt5/Qt6.
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
9. A release inicial será certificada localmente em Max 2021, 2024 e 2026. As
   demais versões só serão anunciadas após teste real.
10. Otimização do preview/commit fica fora da E15. A E15 deve provar que a UI não
    adiciona regressão à baseline já conhecida.

## Consequências

- A interface não herda a dívida de lifecycle do WPF.
- Haverá esforço maior de reconstrução e teste, compensado por limites claros.
- A mesma fonte pode atravessar Max 2021–2027 sem extensão binária própria.
- A autenticação real depende de contrato/endpoint ainda não fornecido.
- Um travamento causado pelo núcleo atual pode continuar após a transição; será
  tratado em marco separado, com baseline capaz de separar as causas.

## Evidência esperada

- Plano: `plans/2026-09-09-e15-transicao-wpf-python-qt.md`.
- Testes de import/compatibilidade nos Pythons embarcados.
- Gates de login, lifecycle, páginas, viewport e pacote por versão.
- Busca estática provando ausência de WPF no pacote novo.
