# ADR 0026 — Uma interface Qt progressiva com identidade Ameno

Data: 2026-09-09

Status: decidido; implementação em andamento em `feature/e17-ameno-ux`

## Contexto

A E15 entregou uma interface Qt estável e funcional, e a E16 retirou do
`mouseMove` a materialização pesada do preview. O candidato é rápido, mas ainda
herda o aspecto genérico do 3ds Max e apresenta ações frequentes, manutenção e
comandos destrutivos no mesmo nível. Um profissional sem familiaridade com o
Max precisa interpretar termos técnicos e escolher entre muitos botões antes de
criar a primeira cota.

## Decisão

1. A interface adotará os tokens e assets atuais do site Ameno, com logo
   derivado do master V2 e `O` em `#E63B2E`.
2. O tema será QSS nativo aplicado somente à árvore de `AmenoMainWindow`.
3. A barra de título continuará nativa; não haverá janela frameless.
4. Haverá uma única interface com divulgação progressiva, não modos iniciante e
   especialista separados.
5. Cada página terá uma ação primária. Comandos raros e destrutivos serão
   contextuais, mas todos permanecerão alcançáveis.
6. A tela Cotar perguntará intenção — Planta/Fachada e Uma medida/Sequência — e
   traduzirá isso para contratos internos.
7. Mudanças de seleção serão draft local; o backend receberá settings uma vez
   ao iniciar a ferramenta.
8. A orientação durante a ferramenta usará inicialmente o prompt nativo do Max.
   Qualquer HUD adicional em `gw` exigirá spike e gate próprios.
9. Tema, assets, ajuda e navegação nunca acessarão cena, bridge ou viewport.
10. O E16 será gate de regressão obrigatório para qualquer entrega E17.

## Consequências

- o produto deixa de expor a organização interna dos serviços como navegação;
- usuários recorrentes mantêm acesso rápido, enquanto detalhes raros ficam
  disponíveis sob demanda;
- a interface passa a carregar assets e fontes próprios, exigindo fallback e
  registro de licença;
- alterações de layout ficam desacopladas do backend, reduzindo o risco de
  regressão funcional;
- mensagens operacionais e detalhes técnicos tornam-se camadas separadas.

## Alternativas rejeitadas

- apenas trocar cores na interface existente;
- construir uma versão iniciante paralela;
- replicar o site dentro de WebView;
- usar janela sem borda para desenhar controles de sistema;
- esconder permanentemente funções raras;
- consultar a cena automaticamente ao navegar;
- animar fundo, logo ou sidebar durante o uso da viewport.

## Evidência esperada

O plano executável e os gates estão em
`plans/2026-09-09-e17-identidade-ux-qt.md`.

