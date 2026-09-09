# E17 — Identidade Ameno e experiência guiada na interface Qt

Data: 2026-09-09

Status: candidato implementado e instalado na branch `feature/e17-ameno-ux`;
gates automatizados concluídos em 2026-09-09; aceite gráfico humano pendente

Progresso salvo no checkpoint E17 final:

- baseline E15/E16 registrado;
- assets, fontes licenciadas, cache e fallback adicionados;
- tema aplicado somente em `AmenoMainWindow`;
- Login, shell e cinco páginas reorganizados com identidade Ameno;
- fluxo Cotar convertido para draft local + uma chamada de settings no start;
- primeiro uso e ajuda `?` implementados sem acesso à cena;
- prompts individuais e contínuos reescritos como passos operacionais;
- 17 testes Python verdes e galeria visual de seis telas gerada;
- matriz MaxScript E12–E17 verde (18/18 suites), incluindo o host Qt, ciclo de
  logout/fechamento e as métricas do E16;
- pacote de desenvolvimento instalado no `ApplicationPlugins` com o Max
  fechado e backup recuperável criado;
- pendente: somente aceite interativo de usabilidade/resize/DPI/soak em uma
  sessão gráfica real e autorização explícita para promover a branch.

Escopo: 3ds Max 2026 / Python 3.11 / PySide6 6.5.3. O E17 modifica a
apresentação e a orquestração de comandos da interface Qt. A matemática, o
schema das cotas, os renderers e o preview `gw` validado no E16 permanecem
congelados, salvo a inclusão estritamente textual de instruções de etapa no
prompt da ferramenta.

Estrutura: 11 etapas e 86 subetapas, executadas na ordem deste documento.

## 6.1 Estado de execução e evidências (atualização 2026-09-09)

| Bloco | Estado | Evidência |
| --- | --- | --- |
| E17.0 — baseline | concluído | `work/e17-baseline/`, branch `feature/e17-ameno-ux`, commit base E16 `f763059` |
| E17.1 — assets/identidade | concluído | `Contents/python/ameno_ui/assets/`, `assets/LICENSES.md`, testes de fallback e paridade de instalação |
| E17.2 — hierarquia de ações | concluído | páginas Qt e teste `test_all_previous_commands_remain_reachable_without_extra_primary_actions` |
| E17.3 — tema/componentes | concluído | `theme.py`, `components.py`, teste de escopo do QSS e 100 ciclos de navegação |
| E17.4 — Login | concluído | testes headless/host; token somente em memória; logout limpa o widget |
| E17.5 — shell/navegação | concluído | `test_e17_qt_host.ms`: cinco páginas fixas, show/close/reopen e navegação local |
| E17.6 — Cotar | concluído | draft local, uma chamada de settings no início e prompts operacionais; regressão E16 verde |
| E17.7 — páginas auxiliares | concluído | bridge E15 e host Qt validam Criar/Estilos/Editar/Render/Configuração |
| E17.8 — primeiro uso/erros | concluído | mensagens acionáveis em `common.py`, ajuda sem leitura da cena, diagnóstico sem token |
| E17.9 — regressões | concluído | `work/e17-gates/summary.txt`: 18/18 MaxScript; `run-python-gates.py`: 17 testes; ZIP canary validado sem WPF/cache; commit `ae3e576` |
| E17.10.1–E17.10.2 — canary | concluído | backup `D:\Ameno\backups\AmenoTools-before-e17-launcher-20260909-125919`; instalação com Max fechado |
| E17.10.3–E17.10.6 — aceite humano | pendente | exige Max interativo, redimensionamento, DPI, cotação real e profissional sem instrução |
| E17.10.7 — promoção | bloqueado por política | nenhuma alteração automática em `develop`/`main`; requer autorização explícita |

O teste host revelou e corrigiu um contrato importante: `python.Execute` retorna
`#success` (status), não o valor da última expressão. O launcher
`AmenoPythonUI.isOpen()` agora mantém estado explícito, e o gate cobre abrir,
fechar e reabrir. Isso evita falsos negativos e impede que um resultado de
execução seja confundido com estado de janela.

O canary ativo é a cópia instalada em
`C:\Users\octav\AppData\Roaming\Autodesk\ApplicationPlugins\AmenoTools`;
fonte e destino foram instalados/checados enquanto o 3ds Max estava fechado.
O artefato distribuível é
`dist/AmenoTools-0.0.1-e17-canary.zip` (SHA-256
`7F3ACAA4BE5D2F1BE7E9EEF90DFEAE2BC57F7B3589ABE7CD8145A59E5E09B406`). A
paridade do conteúdo confirmou zero divergências nos 68 arquivos instalados;
as sete ausências são exatamente os módulos WPF removidos pelo empacotador.
O resumo legível da última matriz fica em `work/e17-gates/summary.txt`; os
logs detalhados permanecem no mesmo diretório e são locais, pois contêm saída
gerada pelo Max.

## 1. Resultado esperado

Transformar o candidato Qt funcional da E15 em um produto com a identidade do
site `ameno.studio` e utilizável por um profissional que entende desenho,
arquitetura e cotagem, mesmo que nunca tenha utilizado o 3ds Max ou o Ameno.

O produto deve:

- iniciar no Login com o wordmark Ameno, usando o `O` no vermelho do site;
- conservar a barra de título nativa com minimizar, maximizar/restaurar e
  fechar;
- apresentar uma única ação principal por página;
- traduzir intenção profissional para parâmetros do Max;
- ocultar complexidade rara por divulgação progressiva, sem remover funções;
- explicar o próximo clique enquanto a ferramenta está na viewport;
- manter navegação, tema e ajuda totalmente isolados da cena;
- provar que o desempenho e o lifecycle conquistados no E16 não regrediram.

## 2. Fontes de verdade visuais

### 2.1 Marca

- Master mais recente encontrado:
  `D:/Ameno/Marca/AMENO_ACERVO_2026-09-08/01_IDENTIDADE_AMENO/V2/ameno-v2-standard.svg`.
- Símbolo responsivo:
  `D:/Ameno/Marca/AMENO_ACERVO_2026-09-08/01_IDENTIDADE_AMENO/V2/ameno-v2-symbol-o.svg`.
- O corte e a irregularidade controlada do `O` não podem ser redesenhados ou
  substituídos por um círculo genérico.
- A variante do aplicativo será derivada do master: `amen` em off-white e `O`
  em vermelho. O master externo não será alterado.

### 2.2 Site

Tokens extraídos de `D:/Ameno/ameno-studio/src/app/globals.css`:

| Papel | Valor |
| --- | --- |
| fundo principal | `#0A0A0A` |
| fundo secundário | `#121212` |
| superfície elevada | `#161616` |
| texto principal | `#E8E8E0` |
| texto branco | `#FFFFFF` |
| texto discreto | `#8B8B85` / `#666666` |
| borda | `#222222` |
| vermelho Ameno | `#E63B2E` |

Tipografia do produto:

- Space Grotesk para interface e títulos;
- IBM Plex Mono para metadados, atalhos, IDs e estados técnicos;
- fallback obrigatório para `Segoe UI` e `Consolas`;
- fontes são registradas somente no processo com
  `QFontDatabase.addApplicationFont`; nunca são instaladas no Windows;
- licença acompanha qualquer binário de fonte distribuído.

## 3. Modelo mental e linguagem

O usuário escolhe a intenção e a interface traduz a escolha para o backend:

| Linguagem da interface | Contrato interno |
| --- | --- |
| Planta | `worldXY` |
| Fachada ou vista | `viewPlane` |
| Uma medida | ferramenta individual |
| Várias medidas em sequência | ferramenta contínua |
| Direção automática | `aligned` |
| Somente horizontal | `horizontal` |
| Somente vertical | `vertical` |

Não expor `worldXY`, `viewPlane`, `aligned`, nomes de structs, layers técnicas
ou códigos de erro na superfície principal. Detalhes técnicos ficam em uma
área copiável e recolhida.

## 4. Arquitetura da apresentação

```text
AmenoMainWindow (título nativo)
  └─ stylesheet aplicado somente nesta árvore
     ├─ LoginPage
     │  ├─ BrandLogo cacheado
     │  ├─ formulário de token
     │  └─ estado de autenticação
     └─ AppShell
        ├─ Sidebar fixa
        │  ├─ símbolo Ameno
        │  ├─ Cotar
        │  ├─ Aparência
        │  ├─ Revisar
        │  ├─ Exportar
        │  └─ Configuração no rodapé
        └─ páginas construídas uma vez
           ├─ CreatePage
           ├─ StylesPage
           ├─ EditPage
           ├─ RenderPage
           └─ ConfigPage
```

Arquivos previstos:

- `Contents/python/ameno_ui/theme.py`: tokens, QSS e registro de fontes;
- `Contents/python/ameno_ui/assets.py`: resolução e cache de imagens;
- `Contents/python/ameno_ui/components.py`: cabeçalhos, cards, escolhas,
  disclosure e menus;
- `Contents/python/ameno_ui/assets/brand/`: variantes derivadas da marca;
- `Contents/python/ameno_ui/assets/fonts/`: somente fontes licenciadas;
- `Contents/python/ameno_ui/assets/LICENSES.md`: origem e licença;
- páginas atuais serão refatoradas sem duplicar serviços ou bridge.

## 5. Fluxos de referência

### 5.1 Primeiro uso

```text
Login
  → boas-vindas curta
  → Planta ou Fachada/Vista
  → Uma medida ou Sequência
  → Iniciar cotação
  → clique 1 / clique 2 / posicionamento
  → sucesso, continuar ou encerrar
```

A apresentação inicial é curta, dispensável, persistida como preferência local
e reaberta pelo botão `?`. Token nunca participa dessa persistência.

### 5.2 Uso recorrente

```text
Login
  → Cotar com últimas preferências locais
  → Iniciar cotação
```

### 5.3 Divulgação progressiva

- superfície principal: contexto, quantidade e ação `Iniciar cotação`;
- `Ajustar detalhes`: orientação, estilo, unidade, precisão e texto;
- `Mais ações`: preparar, atualizar, reparar e excluir;
- exclusões têm confirmação específica e nunca compartilham o destaque da ação
  principal.

## 6. Plano de execução

### E17.0 — Congelamento e baseline (7 subetapas)

1. E17.0.1 — criar a branch a partir do commit aprovado do E16;
2. E17.0.2 — registrar hashes, versão do Max/Python/Qt e estado instalado;
3. E17.0.3 — capturar a árvore de widgets e contagem de ações por página;
4. E17.0.4 — executar testes E15 e E16 antes de alterar apresentação;
5. E17.0.5 — registrar tempo de construção e 100 navegações locais;
6. E17.0.6 — congelar contratos públicos de `UiBridge` e modelos;
7. E17.0.7 — criar evidência em `work/e17-baseline/`.

Gate: baseline reproduzível; nenhuma alteração funcional ou instalação.

### E17.1 — Assets e identidade (8 subetapas)

1. E17.1.1 — derivar logo dark sem alterar o master externo;
2. E17.1.2 — gerar `amen` off-white + `O` `#E63B2E` em 1x e 2x;
3. E17.1.3 — gerar símbolo responsivo vermelho para sidebar;
4. E17.1.4 — validar transparência, corte, margem e redução a 24–32 px;
5. E17.1.5 — adicionar Space Grotesk e IBM Plex Mono licenciadas;
6. E17.1.6 — documentar origem e licenças;
7. E17.1.7 — implementar fallback quando asset ou fonte faltar;
8. E17.1.8 — testar carga a partir do repositório e do ApplicationPlugins.

Gate: nenhuma rede em runtime; ausência de asset não impede abrir a UI.

### E17.2 — Inventário e hierarquia de ações (8 subetapas)

1. E17.2.1 — classificar cada comando como primário, secundário, contextual,
   avançado ou destrutivo;
2. E17.2.2 — manter uma ação primária por página;
3. E17.2.3 — transformar Individual/Contínua em escolha, não ação imediata;
4. E17.2.4 — transformar plano e direção em linguagem profissional;
5. E17.2.5 — mover manutenção para `Mais ações`;
6. E17.2.6 — mover operações raras de Estilos para barra/menu contextual;
7. E17.2.7 — separar mensagens operacionais de detalhes técnicos;
8. E17.2.8 — registrar matriz antes/depois e garantir alcance de 100% dos
   comandos existentes.

Gate: nenhuma função removida e nenhuma função destrutiva promovida.

### E17.3 — Tema e componentes (8 subetapas)

1. E17.3.1 — criar tokens centralizados em `theme.py`;
2. E17.3.2 — registrar fontes uma vez e manter IDs em cache;
3. E17.3.3 — aplicar QSS somente em `AmenoMainWindow`;
4. E17.3.4 — criar cabeçalho, card, texto discreto e status pill;
5. E17.3.5 — criar seletor exclusivo acessível por teclado;
6. E17.3.6 — criar disclosure estável sem reparenting;
7. E17.3.7 — criar menus com parent explícito e teardown pelo Qt;
8. E17.3.8 — validar estados hover, focus, pressed, disabled e error.

Gate: zero alteração em `qApp`, zero timer e zero chamada ao bridge.

### E17.4 — Login Ameno (8 subetapas)

1. E17.4.1 — posicionar o logo no topo do formulário;
2. E17.4.2 — usar `O` vermelho e contraste do site;
3. E17.4.3 — adicionar rótulo `AMENO COTAS / MAX 2026`;
4. E17.4.4 — reduzir o formulário a token, visibilidade e Entrar;
5. E17.4.5 — manter Limpar como ação textual secundária;
6. E17.4.6 — definir estados vazio, pronto, validando e erro;
7. E17.4.7 — preservar Enter, foco inicial e token somente em memória;
8. E17.4.8 — provar Login → App sem `refreshSnapshot`.

Gate: autenticação e segurança E15 sem regressão.

### E17.5 — Shell e navegação (7 subetapas)

1. E17.5.1 — manter a janela e controles nativos do Windows;
2. E17.5.2 — refazer sidebar com símbolo e indicador vermelho;
3. E17.5.3 — usar Cotar, Aparência, Revisar e Exportar;
4. E17.5.4 — posicionar Configuração no rodapé;
5. E17.5.5 — criar cabeçalho consistente por página;
6. E17.5.6 — manter os cinco hosts de página fixos;
7. E17.5.7 — provar navegação local sem acesso à cena.

Gate: uma janela, cinco páginas, zero reparenting e zero bridge call.

### E17.6 — Fluxo Cotar e orientação de viewport (10 subetapas)

1. E17.6.1 — criar seletor Uma medida/Sequência;
2. E17.6.2 — criar seletor Planta/Fachada ou vista;
3. E17.6.3 — usar Direção automática como padrão (`aligned`);
4. E17.6.4 — recolher orientação forçada e formatação em detalhes;
5. E17.6.5 — manter alterações como draft local;
6. E17.6.6 — enviar settings uma vez antes de iniciar a ferramenta;
7. E17.6.7 — adicionar botão único `Iniciar cotação`;
8. E17.6.8 — mover atualização e manutenção para status/menu;
9. E17.6.9 — instruir primeiro ponto, segundo ponto, posição e cancelamento
   pela linha de prompt do Max; HUD `gw` adicional só entra após spike isolado;
10. E17.6.10 — atualizar estado e mensagem ao encerrar sem polling.

Gate: um clique inicia o fluxo escolhido; E16 permanece dentro das métricas.

### E17.7 — Aparência, Revisar, Exportar e Configuração (8 subetapas)

1. E17.7.1 — separar propriedades de estilo em Texto, Linhas e Terminais;
2. E17.7.2 — manter preview 2D visível e isolado da viewport;
3. E17.7.3 — reduzir Estilos a Salvar e Aplicar como ações principais;
4. E17.7.4 — exibir estado vazio explícito em Revisar;
5. E17.7.5 — alternar campos de override com `QStackedWidget` fixo;
6. E17.7.6 — reduzir Exportar a um CTA, com pasta/cópia contextuais;
7. E17.7.7 — separar conta de diagnóstico em Configuração;
8. E17.7.8 — testar todos os comandos anteriormente visíveis.

Gate: paridade funcional E15 e menor carga visual.

### E17.8 — Primeiro uso e mensagens acionáveis (7 subetapas)

1. E17.8.1 — criar boas-vindas curta após o primeiro Login;
2. E17.8.2 — explicar Planta/Fachada e Uma medida/Sequência;
3. E17.8.3 — explicar Snap `S`, cancelar `Esc` e desfazer `Ctrl+Z`;
4. E17.8.4 — permitir dispensar e reabrir pelo `?`;
5. E17.8.5 — persistir somente a preferência de ajuda;
6. E17.8.6 — mapear erros técnicos para instruções operacionais;
7. E17.8.7 — manter detalhe copiável sem incluir token.

Gate: primeiro uso não bloqueia nem chama a cena.

### E17.9 — Responsividade, acessibilidade e regressões (8 subetapas)

1. E17.9.1 — validar 780×560, tamanho padrão e maximizado;
2. E17.9.2 — validar escalas 100%, 125%, 150% e 200%;
3. E17.9.3 — validar ordem de Tab, Enter, Esc e foco visível;
4. E17.9.4 — validar contraste de texto e ações;
5. E17.9.5 — executar 100 ciclos Login/App/logout/close;
6. E17.9.6 — executar 100 ciclos de navegação e verificar cardinalidade;
7. E17.9.7 — executar toda a matriz E15 e E16;
8. E17.9.8 — validar pacote e cópia instalada por hash.

Gate: zero exceção Qt/WPF, zero callback extra e zero regressão E16.

### E17.10 — Canary e aceite humano (7 subetapas)

1. E17.10.1 — criar backup recuperável do pacote ativo;
2. E17.10.2 — instalar somente com o Max fechado ou para processo novo;
3. E17.10.3 — testar login, redimensionamento e cinco páginas;
4. E17.10.4 — testar Planta, Fachada, Individual e Sequência;
5. E17.10.5 — executar soak de viewport e lifecycle;
6. E17.10.6 — executar teste com profissional sem instrução externa;
7. E17.10.7 — promover somente após autorização explícita.

Gate: candidato utilizável; `main` e `develop` não são alteradas implicitamente.

## 7. Guardrails técnicos

### 7.1 Isolamento do Max

- QSS é aplicado na janela Ameno, nunca em `QApplication.instance()`;
- nenhum helper visual importa `pymxs` ou `UiBridge`;
- nenhuma navegação chama `refresh`, `scene`, `styles` ou `selected_audit`;
- nenhuma página usa polling para descobrir mudanças;
- nenhum paint event acessa a cena, disco, log ou bridge;
- nenhuma função de UI cria ou altera callbacks de viewport;
- não recarregar Python/Qt no mesmo processo do Max durante o gate.

### 7.2 Lifecycle Qt

- uma `AmenoApplication` e uma `AmenoMainWindow` por processo;
- widgets e menus têm parent explícito;
- páginas, scroll areas e stacks são construídos uma vez;
- alternância usa visibilidade/índice, nunca remove/reparenta widgets;
- conexões são feitas uma vez no construtor;
- nenhuma lambda mantém referência a widget temporário sem parent;
- fechamento cancela ferramenta interativa antes de destruir a janela.

### 7.3 Desempenho

- assets carregados uma vez, com pixmap cacheado;
- nenhuma animação contínua, `QTimer`, blur ou `QGraphicsEffect`;
- preview de estilo redesenha somente quando o draft muda;
- seletores de Cotar alteram somente o draft local;
- o bridge recebe um único snapshot ao iniciar;
- a matriz E16 mede 1.000 moves, callbacks e commit antes/depois.

### 7.4 Segurança e recuperação

- token permanece somente no `AuthSession`;
- `QSettings` guarda apenas geometria, preferências visuais e ajuda;
- mensagens e diagnóstico nunca recebem o token;
- exclusões exigem confirmação que nomeia o alcance;
- erro mantém a interface utilizável e oferece detalhe copiável;
- backup do pacote é criado antes da instalação final.

## 8. Aceite de usabilidade

Uma pessoa que nunca utilizou o Ameno deve, em uma cena de teste preparada:

1. criar uma cota de Planta em até dois minutos;
2. criar uma sequência em até três minutos;
3. entender Planta versus Fachada/Vista;
4. saber que `Esc` cancela e `Ctrl+Z` desfaz;
5. localizar edição de uma cota selecionada;
6. localizar exclusão sem confundir seleção com todas;
7. concluir sem abrir Configuração ou Manutenção;
8. relatar o próximo passo da ferramenta em cada estágio sem ajuda externa.

## 9. Aceite técnico

- árvore de páginas com cardinalidade estável após 100 navegações;
- zero bridge call ao navegar, abrir detalhes ou trocar seletores;
- zero timer da apresentação em idle;
- Login → App antes de qualquer leitura síncrona da cena;
- 1.000 mouse moves E16 com zero full resolve, zero mutação e zero node preview;
- callback E16 com cardinalidade 0/1/0;
- commit contínuo mantém Undo/Redo e rollback;
- testes E12–E16 e novos testes E17 passam no Max 2026;
- origem, ZIP e instalação têm hashes verificáveis.

## 10. Rollback

O rollback do E17 restaura o pacote instalado anterior e volta ao commit E16
sem apagar preferências ou cenas. Assets e módulos E17 não modificam arquivos
`.max`; remover a interface E17 não exige migração de dados. Nenhum merge,
push, tag ou promoção faz parte implícita da implementação.

## 11. Proibições para o agente executor

- não criar uma janela frameless ou reimplementar minimizar/maximizar/fechar;
- não usar WPF, WinForms, WebView, HTML, QML ou dependências por `pip`;
- não aplicar tema global ao Max;
- não alterar o site ou os masters externos da marca;
- não inventar autenticação remota;
- não remover funções para reduzir botões;
- não automatizar Snap ou preferências do Max sem captura/restauração e ADR;
- não adicionar HUD animado à viewport;
- não mascarar regressão com throttle;
- não promover para `develop`/`main` sem autorização explícita.
