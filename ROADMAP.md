# Roadmap

## 0.0.1 — Fundação

- estrutura do pacote `ApplicationPlugins`;
- manifesto inicial direcionado ao 3ds Max 2026;
- carregamento previsível de módulos;
- logger, versão e diagnóstico;
- MacroScript para abrir o painel;
- registro e limpeza segura de callbacks;
- cena de teste manual.

## 0.0.2 — Prova de interação

- mouse tool de três cliques;
- preview sem criar lixo na cena;
- cota alinhada no plano XY;
- valor em centímetros;
- traço arquitetônico;
- criação automática da layer `AMENO_COTAS`;
- botão `Renderizar Cotas`;
- PNG transparente alinhado ao Render Setup;
- criação em um único bloco de Undo.

## 0.0.3 — Persistência

- nó controlador;
- Custom Attributes versionados;
- âncoras mundiais e locais ao objeto;
- reconstrução ao reabrir a cena;
- detecção de referência perdida.
- modos de valor medido, arredondado e manual;
- aviso viewport-only para valor manual;
- restauração do valor geométrico;

## 0.1.0-alpha — MVP interno

- alinhada, horizontal e vertical;
- estilos globais;
- editor visual inspirado no TextPlus;
- fonte, tamanho, tracking, máscara e cor;
- espessura por presets e valor contínuo;
- terminais por traço, seta cheia/aberta, ponto ou nenhum;
- unidades e formatação;
- atualização automática com debounce;
- atualização antes do render;
- render separado das cotas em PNG/EXR com alpha;
- câmera, resolução, crop e frame iguais à planta;
- restauração segura do estado da cena;
- converter/bake;
- diagnóstico e reparo;
- filtro e relatório de cotas manuais;
- documentação de uso.
- validação completa no Max 2026.

## 0.2.0 — Produção de plantas

- cotas contínuas e em cadeia;
- dimensionamento por seleção;
- perfis de saída em pixels e impressão;
- render apenas das cotas selecionadas;
- preview rápido do overlay;
- nomes e paths automáticos;
- presets por escritório/projeto;
- localização português/inglês.

## 0.3.0 — Automação assistida

- sugestão de cotas a partir de objetos selecionados;
- largura de portas e janelas;
- cotas gerais e parciais automáticas;
- detecção e resolução assistida de sobreposição;
- auditoria de cotas órfãs ou desatualizadas.

## Futuro — Compatibilidade 2021–2025

- congelar a primeira release estável como referência funcional no Max 2026;
- inventariar chamadas realmente incompatíveis antes de alterar o produto;
- priorizar versões conforme usuários e custo de manutenção;
- criar adapters somente para diferenças comprovadas;
- testar primeiro o Max 2025 e depois descer até o piso comercial escolhido;
- publicar limitações por versão sem degradar a experiência do 2026.

## Futuro — Integração avançada de render

- Render Element/AOV no mesmo passe quando suportado;
- integração opcional com Beauty e LightMix;
- adapters por Corona, V-Ray e Arnold;
- composição e flatten automáticos;
- empacotamento em EXR multicanal.

## 1.0.0 — Produto estável

- matriz formal para cada versão do Max que vier a ser suportada;
- instalador e atualizador;
- telemetria somente se opcional e consentida;
- política de migração de cenas;
- documentação, exemplos e suporte;
- licenciamento, se o produto for comercial.
