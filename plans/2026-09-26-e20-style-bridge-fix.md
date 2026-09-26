# E20 — correção da aplicação e leitura de estilos

Data: 2026-09-26. Base: `feature/e20-vertical-adaptive-ui` em `14ffe28`.
O Max estava fechado durante a instalação e os testes Batch. Aceite visual do
usuário na própria cena ainda pendente.

## Falha reproduzida

Na página Estilos, `Aplicar` retornava `Bridge Exception: Argument count error:
applyStyleCommand wanted 1, got 2`. O Python passava `all_dimensions` como
segundo argumento posicional, mas `allDimensions:false` é keyword no MAXScript.
Os testes Qt usavam bridge simulada e não atravessavam esse contrato.

## Correções instaladas

1. `UiBridge.apply_style` passa `allDimensions=` como keyword; atende tanto a
   seleção quanto `Aplicar a todas`.
2. O comando MAXScript devolve `noSelection` quando não há cota Ameno
   selecionada, em vez de anunciar sucesso para zero cotas.
3. `parseStyleList` preserva campos vazios com `splitEmptyTokens:true`. Registros
   já deslocados pelo parser antigo são normalizados somente em memória; a
   biblioteca do usuário não é regravada no carregamento. Um ângulo customizado
   perdido em salvamentos antigos pode não ser recuperável com precisão; usa-se
   45° quando o registro já foi resalvo com o valor deslocado padrão.
4. `applyDraftToSelection` não anuncia sucesso se `saveStyle` devolve falha.

## Preservação de dados

- Instalação anterior: `D:\Ameno\_backups\AmenoTools-before-style-fix-2026-09-26`.
- Biblioteca original: `D:\Ameno\_backups\styles.library-before-style-fix-2026-09-26`.
- SHA-256 da biblioteca ativa e do backup conferidos iguais após a instalação
  e os testes. Nenhuma cena do usuário foi aberta ou salva pelo Batch.

## Gates concluídos

- `tools/validate-package.ps1` e `git diff --check`: passaram.
- Python/Qt 3.11.9 + PySide6 6.5.3: Estilos 10/10; aceite E20 6/6.
- Max 2026 Batch isolado: novo teste de ponte real, seleção e parser retrocompat
  passou; regressão E13 de estilos globais e cor passou (13 marcadores PASS).
- Build corrigida instalada em `%APPDATA%\Autodesk\ApplicationPlugins\AmenoTools`.

## Gate pendente e risco conhecido

- Usuário abrir o Max novamente, selecionar uma cota e confirmar `Aplicar` e
  `Aplicar a todas` na cena real. Não promover E20 para `main` antes disso.
- `updateStyleAndRebuild` ainda grava a biblioteca global antes de reconstruir
  todas as cotas. Uma falha posterior pode deixar estilo persistido com rebuild
  incompleto. Exige etapa transacional própria e teste de falha injetada; não
  foi modificado nesta correção pontual para evitar risco novo à cena do usuário.
