# Substituição do WPF e isolamento da viewport

Data: 2026-09-09

Status: escopo ajustado; transição WPF → Qt é a prioridade exclusiva

Escopo: substituir a interface WPF sem reescrever o núcleo de cotas E1–E14

## Resultado recomendado

Adotar uma arquitetura híbrida:

1. **PySide6/Qt** para a janela principal, abas, formulários e preview 2D do
   editor de estilos;
2. **MAXScript `gw` + redraw callback** para todo desenho transitório dentro da
   viewport durante a cotação;
3. **serviços MAXScript atuais** para matemática, planos U/V/N, persistência,
   âncoras, render e criação dos objetos definitivos;
4. **rollout nativo mínimo** como modo de recuperação, capaz de criar/cancelar
   cotas mesmo se o shell Qt não abrir.

Qt elimina a família de falhas observada no bridge WPF/.NET, mas não torna o
3ds Max multithread. A garantia operacional vem principalmente de retirar do
`mouseMove` toda criação/atualização de spline, `TextPlus`, terminal, material e
Custom Attribute.

## Recorte aprovado para a próxima implementação

Por decisão do usuário em 2026-09-09, a próxima implementação tratará **somente
a transição do WPF para Python/Qt**. A redução de peso do `mouseMove`, o preview
`gw` completo e a otimização do commit permanecem documentados, mas não fazem
parte deste primeiro recorte.

O recorte de transição inclui:

1. criar a camada de compatibilidade PySide2/PySide6;
2. criar a fachada de comandos/DTOs entre Python e os serviços MAXScript;
3. substituir a janela WPF por um único shell Qt;
4. migrar Criar, Estilos, Editar e Render, preservando todas as funções atuais;
5. validar lifecycle, docking, troca de cena e empacotamento em Max 2021 e 2026;
6. manter rollback para o pacote anterior até a aceitação das duas versões.

Consequência assumida: essa entrega elimina os defeitos específicos de WPF,
XAML e reparenting, porém o bloqueio causado pelo pipeline pesado da viewport
pode continuar até a etapa de desempenho ser autorizada.

## Compatibilidade 3ds Max 2021–2026

A interface é portável, mas não deve importar PySide6 diretamente. O pacote de
compatibilidade deve detectar o host e expor uma API Qt única:

```python
try:
    from PySide6 import QtCore, QtGui, QtWidgets
    PYSIDE_MAJOR = 6
except ImportError:
    from PySide2 import QtCore, QtGui, QtWidgets
    PYSIDE_MAJOR = 2
```

Contratos obrigatórios da camada:

- todo o código Python deve ser sintaticamente compatível com Python 3.7;
- evitar `match`, tipos `X | Y`, `list[str]` e recursos posteriores ao 3.7;
- normalizar `QAction`, enums Qt, diálogos `exec/exec_` e diferenças de High DPI;
- usar `qtmax.GetQMaxMainWindow()`/helper disponível no host, evitando wrapping
  manual com `shiboken2` ou `shiboken6`;
- construir widgets em Python ou carregar `.ui` em runtime; não versionar saída
  gerada por um `pyside-uic` específico;
- não instalar wheels Qt externas: usar PySide embarcado pela Autodesk;
- manter uma única fonte Python e testes de compatibilidade específicos por host;
- não ampliar `SeriesMin/SeriesMax` antes de o bootstrap e o smoke real passarem
  no Max 2021.

Ambiente confirmado nesta máquina:

| Host | Python | Qt binding | Qt |
| --- | --- | --- | --- |
| 3ds Max 2021 | 3.7.6 | PySide2 | 5.12.5 |
| 3ds Max 2026 | 3.11.12 | PySide6 | 6.5.3 |

O pacote atual ainda não é instalável no Max 2021: `PackageContents.xml` declara
`SeriesMin="2026"`/`SeriesMax="2026"`, e `AmenoVersion.targetMax` vale 2026.
Esses valores só serão generalizados depois dos testes de API e de pacote. A
portabilidade do shell Qt está confirmada; a compatibilidade integral do núcleo,
renderers e arquivos `.max` precisa de uma matriz real nos dois hosts antes de
ser declarada suportada.

## Evidência da decisão

- O log `ameno-20260909-003154-597.log` não contém uma nova exceção WPF. Ele
  encerra após um commit horizontal de sete segmentos entre 00:39:15.551 e
  00:39:33.704: 18,153 s, ou aproximadamente 2,59 s por segmento.
- O commit vertical anterior levou 5,276 s para dois segmentos: cerca de 2,64 s
  por segmento. Portanto, o modo Vertical não possui custo especial; o custo é
  comum à materialização da cota.
- `handleMove()` chama `acquireSample()` e depois `refreshChainPreview()`.
  `refreshChainPreview()` percorre todos os segmentos e chama
  `createPreviewDimension()`/`updatePreviewDimension()`, que trabalham com nós
  reais da cena.
- Já existe um overlay `gw` estável para pontos e hover em
  `AmenoContinuousViewportDraw`. A substituição pode ampliar essa base em vez de
  criar uma segunda infraestrutura de viewport.
- O Max.log desta instalação confirma `PySide6`, `shiboken6` e Qt carregados. A
  documentação Autodesk do 3ds Max 2026 declara PySide6 como framework
  preferencial para UIs Python e fornece `qtmax.GetQMaxMainWindow()` para
  parenting/docking.

## Alternativas avaliadas

| Alternativa | Resultado visual | Risco de lifecycle | Custo de migração | Decisão |
| --- | --- | --- | --- | --- |
| Continuar no WPF | Mantém a tela atual | Alto; bridge .NET, reparenting e gerações antigas já falharam | Baixo agora, alto recorrente | Rejeitar |
| WinForms/.NET | Inferior ao WPF | Continua dependente da mesma família de bridge/lifecycle | Médio | Rejeitar |
| Rollout MAXScript | Mais simples e menos flexível | Baixo, totalmente nativo | Baixo | Usar como fallback e resgate |
| PySide6/Qt | Similar ou superior ao WPF | Baixo com singleton/parent único | Médio | **Shell principal recomendado** |
| C++/Qt SDK | Similar ou superior | Baixo, máximo controle | Muito alto; build por versão do Max | Reservar para um futuro gargalo comprovado |
| HTML/WebView externo | Flexível | Acrescenta IPC, foco e outro runtime | Alto | Rejeitar |

## Arquitetura-alvo

```text
QDockWidget PySide6 (apresentação; sem objetos de cena)
        │ comandos/DTOs simples
        ▼
AmenoUiBridge / AmenoApp (fachada curta e síncrona)
        │
        ├── serviços atuais: estilo, plano, âncora, render, CA
        │
        └── sessão interativa MAXScript
              ├── click: captura referência/âncora
              ├── mouseMove: layout puro + atualiza OverlayModel
              ├── redraw: `gw` desenha linhas, terminais, texto e hover
              └── commit: cria os nós definitivos uma única vez
```

Regras obrigatórias:

- A UI recebe somente IDs, números, strings, cores e snapshots imutáveis. Ela
  não guarda controles WPF, handles temporários, nós de preview ou meshes.
- Toda mutação da cena continua na thread principal do Max, por comandos curtos
  e não reentrantes. Nenhum worker Python acessa `pymxs.runtime` ou a cena.
- Um único `QDockWidget` existe por processo. Ele é parentado uma vez ao main
  window do Max; não se move o mesmo widget entre containers.
- Fechar a janela desconecta signals, para timers, cancela MouseTools, remove
  redraw callbacks, limpa o singleton e usa `WA_DeleteOnClose`/`deleteLater`.
- Atualização de código carregado exige reinício completo do 3ds Max. Não haverá
  `shutdown → start` no mesmo processo enquanto houver callbacks/objetos de UI.
- Eventos repetidos de mouse são coalescidos: usa-se apenas a posição mais
  recente. Se o frame anterior ainda estiver ocupado, o intermediário é
  descartado, nunca enfileirado.

## Plano de implementação — 6 etapas, 23 subetapas

### S1 — Contrato e chave de recuperação (4 subetapas)

1. Congelar o WPF: nenhuma tela ou correção cosmética nova entra nele.
2. Criar `AmenoUiBridge` com comandos e DTOs independentes de WPF/Qt.
3. Adicionar escolha persistida `qt`/`rollout` e macro “Abrir modo seguro”.
4. Cobrir abertura única, fechamento, troca de cena e erro de inicialização.

Gate: o rollout seguro cria uma cota individual e cancela uma sessão contínua
sem carregar `System.Windows`.

### S2 — Preview de viewport sem nós (5 subetapas)

1. Separar `OverlayModel` do record gráfico persistente.
2. Fazer `refreshChainPreview()` calcular somente o layout e atualizar dados.
3. Ampliar `AmenoContinuousViewportDraw` para baseline, linhas auxiliares,
   terminais, rótulos e estados de hover/erro usando apenas `gw`.
4. Remover do `mouseMove` `createPreviewDimension()`, `updatePreviewDimension()`,
   `TextPlus`, spline, mesh, material, layer e CA.
5. Garantir unregister idempotente em sucesso, cancelamento, exceção, reset,
   abertura de arquivo e shutdown.

Gate: nenhum nó `AMENO_*` temporário é criado durante 1.000 movimentos; a
viewport permanece navegável e o callback registrado volta a zero ao encerrar.

### S3 — Shell Qt mínimo (4 subetapas)

1. Criar pacote Python interno e `QDockWidget` parentado por
   `qtmax.GetQMaxMainWindow()`.
2. Migrar primeiro a aba Criar e o status de sessão, mantendo Estilos/Editar/
   Render acessíveis pelo modo seguro até suas etapas.
3. Implementar singleton, restauração de tamanho/docking, DPI e limpeza de
   lifecycle sem reparenting.
4. Encaminhar erros ao logger persistente e oferecer reabertura em modo seguro.

Gate: 100 ciclos abrir/fechar e 100 ciclos de navegação não duplicam janela,
signals ou callbacks e não aumentam memória de forma contínua.

### S4 — Commit previsível e responsivo (4 subetapas)

1. Instrumentar separadamente layout, spline, texto, terminais, CA, âncoras e
   redraw para localizar o custo de ~2,6 s/segmento.
2. Reutilizar estilo/layer/material e dados de snap já capturados; não repetir
   `intersectRayScene` ou `snapshotAsMesh` no commit sem necessidade.
3. Criar a representação persistente uma vez por segmento dentro de uma única
   transação de Undo e com redraw suspenso; eliminar o ciclo criar-preview,
   atualizar-preview e recriar-definitivo.
4. Se ainda houver etapa longa, executá-la em fatias controladas pela thread do
   Max com estado de progresso/cancelamento, sem acessar a cena em background.

Gate: sete segmentos deixam de provocar 18 s de bloqueio; meta inicial <= 5 s
na cena de reprodução, nenhum segmento individual bloqueia por mais de 1 s e
cancelamento/rollback não deixam nós parciais.

### S5 — Paridade completa da interface (3 subetapas)

1. Migrar Estilos e o preview 2D para `QGraphicsScene`/`QPainter`, isolado da
   viewport e sem XAML.
2. Migrar Editar e Render mantendo os contratos transacionais atuais.
3. Remover dependências de `System.Windows.*` da carga normal e manter o rollout
   apenas para recuperação.

Gate: matriz funcional Criar/Estilos/Editar/Render equivalente ao WPF, inclusive
Undo/Redo, biblioteca global, reancoragem, render e mensagens de erro.

### S6 — Soak, corte e retirada do WPF (3 subetapas)

1. Executar teste real em cena pequena e na cena problemática: 20 sessões H/V/
   Fachada, cadeias de 2/10/50 pontos, troca de abas, arquivos e viewports.
2. Validar DPI, dois monitores, dock/float, minimizar/restaurar, reset/new/open,
   Corona/V-Ray/Arnold e fechamento do Max.
3. Tornar Qt o padrão somente após os gates; preservar um pacote anterior e a
   flag de rollback por uma versão antes de excluir o WPF.

Gate: zero exceções de lifecycle, zero callbacks órfãos, zero nós temporários e
memória estabilizada após repetir o fluxo; E14.6–E14.7 podem então ser retomadas.

## Caminhos que não devem ser usados

- Não portar diretamente o XAML para Qt mantendo handlers que criam cena em
  cada evento; isso só mudaria a aparência do travamento.
- Não tentar resolver responsividade acessando o 3ds Max por `threading`,
  `QtConcurrent` ou worker threads; o host e `pymxs` devem ser tratados como
  single-threaded.
- Não manter WPF e Qt ativos simultaneamente sobre o mesmo estado de sessão.
- Não conservar widgets de aba em cache e depois reparentá-los.
- Não recarregar o pacote dentro de uma sessão do Max durante desenvolvimento.
- Não instalar a migração sobre a única cópia da cena de produção; usar cópia
  descartável e pacote/backup recuperável.

## Ordem de entrega sugerida

No recorte atual, executar a parte de contrato/chave de recuperação de S1 e o
shell Qt de S3; depois migrar as quatro telas de S5 e executar somente os gates
de lifecycle/portabilidade de S6. S2 e S4 ficam explicitamente adiadas. Quando
o usuário autorizar o trabalho de desempenho, S2 remove o preview com nós e S4
trata a pausa longa no commit.
