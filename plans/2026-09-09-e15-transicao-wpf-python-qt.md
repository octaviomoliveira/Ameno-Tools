# E15 — Transição integral do WPF para Python/Qt

Data: 2026-09-09

Status: plano renovado; implementação não iniciada

Prioridade: exclusiva. Não otimizar neste marco o cálculo, preview ou commit das
cotas; entregar primeiro uma interface nova, isolada e estável.

## 1. Objetivo

Substituir integralmente a interface WPF do Ameno por uma interface Python/Qt
escrita do zero, preservando o comportamento necessário de Criar, Estilos,
Editar, Render e Configuração. A nova janela deve funcionar por contrato do 3ds
Max 2021 ao 2027, começar sempre na página de login/token e oferecer minimizar,
maximizar/restaurar e fechar.

Este marco combate os travamentos originados pela interface: XAML, bridge
`mxsdotNet`, cache/reparenting de controles, handlers duplicados, janelas de
gerações antigas e lifecycle reentrante. Ele não afirma resolver o custo já
existente no núcleo de viewport; apenas garante que a UI nova não acrescente
trabalho, polling ou bloqueios a esse caminho.

## 2. Decisão de reescrita

### 2.1 O que significa “não reaproveitar código”

- Todo código de apresentação será novo e ficará em
  `Contents/python/ameno_ui/`.
- Nenhum arquivo `ameno_*_wpf.ms`, XAML, controle WPF, handler `dotNet` ou
  renderer WPF será importado, traduzido linha a linha ou hospedado pelo Qt.
- O WPF atual será usado somente como inventário externo de requisitos e como
  referência de aceite visual/funcional.
- O launcher MAXScript e a fachada de comunicação com Python serão escritos do
  zero, com nomes e lifecycle próprios.
- Os serviços de domínio já validados — matemática, planos U/V/N, estilos,
  persistência, âncoras, render e MouseTools — permanecem como backend. Isso não
  é reaproveitar a interface WPF; é preservar o produto enquanto trocamos sua
  camada de apresentação.
- A UI Python não chamará funções de structs WPF nem dependerá do estado delas.
- Depois do corte, os arquivos WPF deixam de fazer parte do pacote distribuído.
  O histórico Git e o backup do pacote anterior serão o único rollback.

### 2.2 Restrições desta etapa

- Não alterar `refreshChainPreview`, picking, `intersectRayScene`,
  `snapshotAsMesh`, TextPlus ou criação de terminais por motivo de desempenho.
- Não modificar schemas de Custom Attributes ou o formato das cotas.
- Não alterar a matemática E14 de fachada.
- Não introduzir C++, WebView, WPF, WinForms, PyQt ou dependências instaladas por
  `pip`.
- Não fazer reload do plugin no mesmo processo do Max.

## 3. Compatibilidade 3ds Max 2021–2027

### 3.1 Matriz-alvo

| Max | Python | Binding Qt | Qt | Situação de teste |
| --- | --- | --- | --- | --- |
| 2021 | 3.7.6 | PySide2 | 5.12.5 | instalado localmente |
| 2022 | 3.7.9+ | PySide2 | 5.15.1 | compatível por contrato; ambiente pendente |
| 2023 | 3.9.7 | PySide2 | 5.15.1 | compatível por contrato; ambiente pendente |
| 2024 | 3.10.8 | PySide2 | 5.15.1 | instalado localmente |
| 2025 | 3.11.x | PySide6 | 6.5.3 | compatível por contrato; ambiente pendente |
| 2026 | 3.11.x | PySide6 | 6.5.3 | instalado localmente |
| 2027 | 3.13.9 | PySide6 | 6.8.3 | documentação disponível; instalação completa pendente |

“Compatível por contrato” não equivale a “certificado”. Só uma versão executada
com os gates deste plano poderá constar como suportada na release.

### 3.2 Base comum obrigatória

- Sintaxe Python limitada ao Python 3.7: sem `match`, `X | Y`, `list[str]`,
  `zoneinfo` ou outros recursos posteriores.
- Uma única camada `qt_compat.py` importa PySide6 quando disponível e cai para
  PySide2; o restante do projeto nunca importa PySide diretamente.
- `qt_compat` normaliza enums, `QAction`, `exec/exec_`, High DPI,
  `QScreen.availableGeometry`, sinais e diferenças Qt5/Qt6 usadas pelo Ameno.
- Usar apenas o `QApplication` já criado pelo 3ds Max; nunca instanciar outro.
- Obter o parent pelo `qtmax.GetQMaxMainWindow()` disponível no host; não usar
  wrapping manual com `shiboken2`/`shiboken6`.
- Construir os widgets em Python. Não usar código gerado por `pyside-uic` de uma
  versão específica.
- O bootstrap distribuído continua sendo MAXScript e chama
  `python.Init()`/`python.ExecuteFile()`, rota disponível desde o Max 2021. Isso
  evita depender do suporte a `.py` direto no `PackageContents.xml`, adicionado
  apenas em versões posteriores.
- A detecção de recursos prevalece sobre condicionais pelo número da versão.

## 4. Arquitetura da nova interface

```text
Macro Ameno
  └─ launcher MAXScript novo
       └─ python.ExecuteFile(entrypoint.py)
            └─ AmenoApplication singleton
                 └─ AmenoMainWindow (uma instância por processo)
                      └─ QStackedWidget
                           ├─ LoginPage
                           └─ ApplicationPage
                                ├─ Criar
                                ├─ Estilos
                                ├─ Editar
                                ├─ Render
                                └─ Configuração/Conta

UI Python ── comandos e snapshots primitivos ── AmenoUiBridge novo
                                                   └─ serviços MAXScript atuais
```

### 4.1 Fronteiras

- A UI mantém somente estado de apresentação e modelos Python copiados.
- Nenhum proxy de nó, mesh, MAXScript struct ou controle temporário é guardado
  dentro de widgets.
- `AmenoUiBridge` é a única porta de acesso da UI ao runtime do Max.
- Cada comando retorna um envelope simples: sucesso, código, mensagem segura e
  snapshot atualizado. Exceções nunca atravessam diretamente até um signal Qt.
- Navegar entre páginas não consulta nem modifica a cena. Refresh pesado só
  ocorre por ação explícita do usuário ou após um comando que o exige.
- Nenhum timer periódico chama `pymxs`, MAXScript, viewport ou seleção.
- O painel não é escondido, destruído ou reparentado quando um MouseTool inicia;
  apenas os controles incompatíveis ficam desabilitados.
- Signals são conectados uma vez no construtor e desconectados no teardown.

## 5. Login obrigatório

### 5.1 Fluxo

Estados permitidos:

```text
LOGGED_OUT → VALIDATING → AUTHENTICATED → APPLICATION
     ↑            │              │
     └─ ERROR/OFFLINE/EXPIRED ←───┘
```

- A janela sempre abre em `LoginPage` quando não há sessão válida em memória.
- O usuário cola o token em um campo mascarado.
- O botão Entrar fica habilitado somente com entrada não vazia.
- Enter envia; Esc limpa o foco, mas não fecha o 3ds Max.
- Enquanto valida, o campo e o botão ficam bloqueados e existe Cancelar.
- Sucesso troca a página do mesmo `QStackedWidget`; não cria nova janela.
- Falha mantém a página, mostra mensagem curta e permite tentar novamente.
- Logout limpa token/sessão e retorna ao login sem reiniciar o plugin.
- Expiração retorna ao login somente depois de encerrar com segurança qualquer
  comando de cena em andamento.

### 5.2 Segurança

- O token não entra em log, traceback, analytics, `.max`, INI, QSettings ou Git.
- Nesta primeira versão o token vive apenas em memória e é solicitado novamente
  a cada processo do Max.
- “Lembrar token” fica fora de escopo até haver decisão explícita sobre Windows
  Credential Manager/DPAPI.
- Logs podem guardar apenas resultado, código HTTP, duração e os últimos quatro
  caracteres de um identificador não secreto fornecido pelo servidor.
- A validação usa `QNetworkAccessManager`, assíncrono no event loop Qt, com
  timeout e cancelamento; não usa `requests`, thread Python ou `pymxs` fora da
  thread principal.
- URL, headers e formato da resposta pertencem a `AuthGateway`; widgets não
  conhecem o backend.
- O endpoint e o contrato real de autenticação são dependência pendente. Até sua
  definição, testes usam um `FakeAuthGateway`, nunca um token real.

## 6. Janela e controles de sistema

- A primeira versão usa moldura nativa do Windows, não janela frameless.
- Habilitar explicitamente minimizar, maximizar/restaurar e fechar por window
  flags compatíveis Qt5/Qt6.
- O botão maximizar muda naturalmente para restaurar; não desenhar ícone ou
  implementar hit testing manual.
- A janela é modeless, redimensionável, filha lógica da janela principal do Max
  e possui uma única instância.
- Minimizar não descarrega páginas, não encerra autenticação e não cria timers.
- Maximizar usa layouts e `QScrollArea`; nenhum controle pode ficar inacessível.
- Fechar passa por um único `closeEvent`: trata rascunho sujo, MouseTool ativo e
  render em andamento antes do teardown.
- Geometria da janela é salva sem token e restaurada dentro da área visível do
  monitor atual; coordenadas inválidas voltam ao centro.
- DPI, troca de monitor e maximização não recriam widgets.
- Atalhos do Max são desabilitados apenas enquanto um campo editável tem foco e
  reabilitados ao perder foco/fechar.

## 7. Inventário funcional independente

O WPF é apenas a fonte deste checklist. A implementação Qt não deve consultar os
arquivos WPF em runtime.

### Login

- token mascarado, mostrar/ocultar, colar, Entrar, Cancelar validação, status,
  erro, expiração e Logout em Conta.

### Criar

- estado da cena e contagem de cotas;
- plano Planta XY ou Fachada/Vista;
- modo Alinhada, Horizontal ou Vertical;
- Cota Individual e Cota Contínua;
- estilo ativo, unidade, precisão e texto acompanhando a linha;
- Reparar tudo, Deletar seleção, Limpar órfãs e Deletar tudo;
- bloqueio coerente de controles durante MouseTool sem esconder a janela.

### Estilos

- selecionar, criar, duplicar e excluir estilo;
- estado sujo e quantidade de cotas em uso;
- presets Arquitetônico, Editorial e Técnico;
- fonte, tamanho, negrito, itálico, tracking, afastamento e máscara;
- cor de render;
- espessura, prolongamento e recuo;
- tipo, tamanho, posição e ângulo de terminais;
- preview 2D novo com `QPainter`, zoom 50/100/200 e fundo claro/escuro;
- salvar, aplicar às selecionadas e atualizar todas;
- confirmar salvar/descartar/cancelar ao sair com rascunho sujo.

### Editar

- estado da cota selecionada, medido, exibido, delta e status;
- modos Medido, Arredondado, Numérico e Texto;
- passo de arredondamento, valor/texto manual e motivo;
- restaurar medido e aplicar alteração;
- estilo da cota e aplicar estilo;
- exibir âncoras/orfandade, selecionar nós e reancorar A/B.

### Render

- renderer detectado e compatibilidade;
- câmera/vista;
- escopo Todas ou Selecionadas;
- PNG transparente e opção somente cotas;
- caminho Auto ou escolhido;
- Renderizar, Abrir pasta e Copiar caminho;
- progresso, cancelamento, erro e restauração da cena.

### Configuração/Conta

- versão do Ameno, versão do Max, Python, PySide e Qt;
- status da sessão e Logout;
- abrir pasta de logs e copiar diagnóstico sem segredos;
- restaurar geometria da janela e preferências visuais não sensíveis.

## 8. Plano de execução — 10 etapas, 72 subetapas

### E15.0 — Contrato e baseline (5 subetapas)

1. Congelar os arquivos WPF; nenhuma correção ou recurso novo entra neles.
2. Converter o inventário acima em testes de contrato, sem importar WPF.
3. Registrar baseline de abertura, navegação, callbacks, memória e viewport.
4. Criar branch isolada e pacote de desenvolvimento que não toca a instalação
   ativa enquanto o Max estiver aberto.
5. Registrar o endpoint/token como dependência explícita, sem inventar backend.

Gate: checklist funcional fechado, baseline reproduzível e zero código novo no
diretório WPF.

### E15.1 — Fundação Python/Qt do zero (7 subetapas)

1. Criar `Contents/python/ameno_ui/` sem copiar arquivos existentes.
2. Implementar `qt_compat.py` e testes PySide2/PySide6.
3. Implementar `host_info.py` por feature detection.
4. Implementar `entrypoint.py` e singleton `AmenoApplication`.
5. Criar launcher MAXScript mínimo com `python.Init/ExecuteFile` e erro legível.
6. Criar logging Python separado, com redaction obrigatória.
7. Proibir import de `System.Windows`, XAML, WinForms, PyQt e wheels externos por
   teste estático do pacote.

Gate: o mesmo “Olá Ameno” abre e fecha no Max 2021, 2024 e 2026 sem duplicar
`QApplication`, janela, handler ou callback.

### E15.2 — Login e autenticação (8 subetapas)

1. Criar `AuthState`, `AuthSession` e `AuthGateway` independentes da UI.
2. Criar `FakeAuthGateway` para sucesso, inválido, expirado, offline e timeout.
3. Criar `LoginPage` do zero com campo mascarado e mostrar/ocultar.
4. Implementar Entrar, Enter, Cancelar e mensagens de estado acessíveis.
5. Implementar validação assíncrona com `QNetworkAccessManager`.
6. Garantir token somente em memória e redaction em todos os erros/logs.
7. Implementar troca Login → App no mesmo `QStackedWidget`.
8. Implementar Logout/expiração e limpeza verificável do estado sensível.

Gate: nenhuma página funcional pode ser acessada sem estado autenticado; testes
não deixam token em arquivo, log, exception ou snapshot.

### E15.3 — Shell, navegação e janela (7 subetapas)

1. Criar `AmenoMainWindow` com moldura nativa e título/ícone próprios.
2. Habilitar e testar minimizar, maximizar/restaurar e fechar.
3. Criar sidebar/páginas novas para Criar, Estilos, Editar, Render e Config.
4. Implementar layouts responsivos, scroll e tamanhos mínimos.
5. Implementar persistência/clamp de posição, tamanho e estado maximizado.
6. Implementar `closeEvent` único e teardown idempotente.
7. Garantir que navegar/minimizar/maximizar nunca invoque a cena ou viewport.

Gate: 500 trocas de página, 100 min/max/restore e 100 open/close sem exceção,
janela órfã, crescimento monotônico ou perda de controles.

### E15.4 — Fachada UI ↔ domínio (7 subetapas)

1. Criar `AmenoUiBridge` em MAXScript do zero, sem referência aos structs WPF.
2. Definir comandos posicionais com tipos primitivos e códigos de erro estáveis.
3. Copiar imediatamente snapshots do runtime para modelos Python imutáveis.
4. Implementar trava contra comando reentrante e clique duplo.
5. Implementar estados `idle/busy/mouseTool/rendering/error`.
6. Garantir que nenhuma exceção MAXScript escape de um signal Qt.
7. Testar bridge com serviço falso e com os serviços reais em cena descartável.

Gate: a UI não acessa globais de domínio fora do bridge e não retém proxies do
Max entre eventos Qt.

### E15.5 — Página Criar (7 subetapas)

1. Implementar cards de cena, plano, modo, ferramenta e estilo.
2. Implementar Planta/Fachada e Alinhada/H/V com validação de combinações.
3. Implementar Individual/Contínua com início, retorno, cancelamento e erro.
4. Implementar estilo, unidade, precisão e orientação de texto.
5. Implementar contagem/estado por refresh explícito, não polling.
6. Implementar Reparar, Deletar seleção, Limpar órfãs e Deletar tudo com
   confirmações adequadas.
7. Durante MouseTool, manter janela viva e desabilitar somente ações conflitantes.

Gate: paridade funcional da aba Criar em 2021/2024/2026 e nenhum evento de UI
adicional registrado em `mouseMove`.

### E15.6 — Página Estilos e preview 2D (8 subetapas)

1. Implementar modelo de rascunho Python independente de widgets.
2. Implementar lista/Novo/Duplicar/Excluir e contagem em uso.
3. Implementar tipografia, tracking, afastamento, máscara e cor.
4. Implementar linha, prolongamento, recuo e presets de espessura.
5. Implementar terminais, tamanho, posição e ângulo.
6. Criar preview 2D do zero com `QPainter`, sem cena e sem WPF.
7. Implementar zoom/fundo e coalescer sliders em um paint por ciclo de eventos.
8. Implementar salvar/aplicar/atualizar todas e proteção de rascunho sujo.

Gate: testes de estado/rollback e 5.000 alterações de slider sem tocar viewport,
criar nós ou crescer objetos Qt continuamente.

### E15.7 — Página Editar (7 subetapas)

1. Implementar snapshot da seleção e estados vazio/válido/órfão.
2. Implementar Medido/Arredondado/Numérico/Texto.
3. Implementar validação de valor, texto, passo e motivo antes do comando.
4. Implementar aplicar/restaurar com Undo/Redo preservado.
5. Implementar escolha/aplicação de estilo.
6. Implementar exibição/seleção de âncoras e reancoragem A/B.
7. Atualizar após ações explícitas/callback coalescido, nunca polling contínuo.

Gate: matriz de edição e âncoras equivalente ao comportamento atual, sem WPF e
sem interferir na navegação da viewport quando a seleção muda rapidamente.

### E15.8 — Render, Configuração e Conta (8 subetapas)

1. Implementar diagnóstico de renderer e câmera/vista.
2. Implementar escopo, somente cotas e caminho de saída.
3. Implementar render/cancelamento e estado único `rendering`.
4. Implementar Abrir pasta e Copiar caminho com validação.
5. Garantir restauração da cena em sucesso, erro e cancelamento.
6. Implementar Config com versões, logs e diagnóstico redigido.
7. Implementar Conta/Logout e retorno seguro à página Login.
8. Impedir fechar/logout durante transação sem passar pelo fluxo de cancelamento.

Gate: render real e restauração passam; diagnóstico não contém token; fechar ou
logout não deixa render, callback ou estado de cena pendente.

### E15.9 — Certificação, corte e rollback (8 subetapas)

1. Rodar testes Python puros com o interpretador de cada Max disponível.
2. Rodar bootstrap, login falso, lifecycle e páginas no Max 2021.
3. Repetir a matriz no Max 2024.
4. Repetir a matriz no Max 2026.
5. Executar soak com UI aberta: orbit/pan/zoom, seleção, 20 MouseTools, troca de
   páginas, min/max e open/close; comparar com a baseline sem regressão da UI.
6. Obter ambientes 2022/2023/2025/2027 ou marcar cada versão honestamente como
   não certificada; nenhum suporte será presumido.
7. Gerar pacote sem WPF, backup recuperável e manifesto correspondente somente
   às versões certificadas.
8. Instalar com todos os Max fechados, validar hashes, smoke instalado e rollback.

Gate: zero carga de `System.Windows`, zero reparenting, zero janela/callback
órfão, zero segredo persistido e zero regressão de viewport causada pela UI.

## 9. Matriz preventiva de bugs

| Risco | Prevenção obrigatória | Prova |
| --- | --- | --- |
| Repetir reparenting do WPF | uma janela, um parent, `QStackedWidget` fixo | 500 navegações |
| Duas gerações da UI | singleton + recusa de reload em processo | 100 chamadas da macro |
| Criar outro QApplication | usar `QApplication.instance()` | assert por host |
| Qt5/Qt6 divergirem | somente `qt_compat` importa PySide | teste estático + três hosts |
| Código não rodar no Python 3.7 | sintaxe/base stdlib 3.7 | compile no Python do Max 2021 |
| Token vazar | memória apenas + redaction | busca em logs/arquivos/tracebacks |
| Login congelar Max | `QNetworkAccessManager` assíncrono + timeout | offline/timeout/cancelar |
| Signals duplicados | conexão única e teardown idempotente | abrir/fechar repetido |
| Navegação tocar viewport | pages trabalham com modelos locais | trace de comandos vazio |
| Seleção gerar tempestade | callback coalescido, sem polling | seleção rápida/soak |
| MouseTool reparentar janela | desabilitar controles, não hide/show | 20 sessões seguidas |
| Maximizar quebrar layout | chrome nativo + layouts/scroll | DPI/monitores/min-max |
| Fechar deixar estado vivo | `closeEvent` único + cleanup ordenado | callbacks/timers zerados |
| Versão não testada ser anunciada | separar contrato de certificação | release matrix assinada |

## 10. Critérios finais de aceite

- A primeira tela sempre é Login e o token válido desbloqueia o app.
- A janela apresenta minimizar, maximizar/restaurar e fechar funcionais.
- Criar, Estilos, Editar, Render e Config possuem paridade funcional documentada.
- Nenhum arquivo da UI nova contém XAML, `System.Windows`, WinForms ou handlers
  WPF; o pacote final não inclui a interface antiga.
- Abrir, navegar, minimizar, maximizar e fechar não executam comandos de cena.
- A UI permanece uma única instância após repetição e troca de cenas.
- Token não persiste nem aparece em logs.
- Max 2021, 2024 e 2026 passam integralmente antes de instalar o primeiro
  candidato sobre o pacote ativo do usuário.
- Max 2022, 2023, 2025 e 2027 só entram na lista pública após execução real.
- O peso preexistente da cotação fica registrado separadamente e não pode ser
  atribuído à interface nova sem comparação com a baseline.

## 11. Dependências antes da autenticação real

Para sair do `FakeAuthGateway`, ainda será necessário definir:

1. URL do endpoint de validação;
2. formato e prefixo do token;
3. headers obrigatórios;
4. resposta de sucesso/erro e expiração;
5. política offline;
6. revogação/logout no servidor;
7. ambiente de homologação sem credenciais de produção.

Essas informações não bloqueiam a fundação Qt, o shell, os testes de lifecycle
ou a página de login; bloqueiam apenas a autenticação real.

## 12. Referências oficiais

- Autodesk — matriz Python/PySide do 3ds Max 2021–2027:
  <https://help.autodesk.com/cloudhelp/2027/ENU/MAXDEV-Python/files/MAXDEV_Python_what_s_new_in_3ds_max_python_api_html.html>
- Autodesk — requisitos Qt do 3ds Max 2021–2026:
  <https://help.autodesk.com/view/MAXDEV/2026/ENU/?guid=sdk_requirements>
- Autodesk — execução de Python por MAXScript no Max 2021:
  <https://help.autodesk.com/cloudhelp/2021/ENU/Max-Python-API/executing_python/executing_python_from_maxscript.html>
- Autodesk — criação e lifecycle de interfaces PySide:
  <https://help.autodesk.com/cloudhelp/2026/ENU/MAXDEV-Python/files/MAXDEV_Python_creating_python_uis_html.html>
