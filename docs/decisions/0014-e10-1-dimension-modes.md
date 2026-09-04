# 0014 — E10.1: Modos de cota (aligned / horizontal / vertical)

**Data:** 2026-09-04  
**Status:** Aceito  
**Autor:** Ameno Tools (IA)

---

## Contexto

Até a E9 o sistema suportava somente o modo #aligned — a cota segue o vetor AB projetado no plano XY. A E10.1 adiciona dois novos modos: #horizontal (mede somente a componente X) e #vertical (mede somente a componente Y).

---

## Decisões

### 1. Schema CA: v3 → v4 additive

O campo dimensionMode type:#string default:"aligned" foi adicionado ao bloco parameters main do CA AmenoDimensionData (GUID AMEN/DIM1). A versão sobe de 3 para 4.

Cenas abertas com CA v3 não têm o campo dimensionMode. O eadCA usa isProperty ca #dimensionMode para ler com guard; se ausente, retorna "aligned". Resultado: **compatibilidade total sem re-aplicar o CA**.

### 2. Dispatcher layoutForMode

Foi adicionada a função pública AmenoDimensionMath.layoutForMode pointA pointB offsetPoint mode:#aligned que despacha para lignedLayout, horizontalLayout ou erticalLayout.

Todos os call sites (graphics, tool, CA) passaram a usar layoutForMode. O lignedLayout continua como função interna, chamada pelo dispatcher.

### 3. Perpendicular fixo para H/V

Para #horizontal: direção = [1,0,0], perpendicular = [0,1,0]. Afastamento = componente Y do offset em relação a A.
Para #vertical: direção = [0,1,0], perpendicular = [1,0,0]. Afastamento = componente X do offset em relação a A.

Isso garante que ao mover âncoras, cotas H/V não "rodam" — seu afastamento é preservado no eixo fixo do modo.

### 4. resolvePoints mode-aware

O recálculo do offsetPoint quando âncoras se movem usa agora layoutForMode com o modo lido do CA. Para horizontal reconstrói o offset como [worldA.x, worldA.y + offsetDist, 0]; para vertical como [worldA.x + offsetDist, worldA.y, 0].

### 5. UI: radio buttons no rollout Criação de Cotas

Adicionado radiobuttons rdoMode Modo: com labels Alinhada, Horizontal, Vertical. O handler on rdoMode changed atualiza AmenoDimensionTool.activeMode.

### 6. Mensagem de erro zeroProjection

Cotas H/V com A e B no mesmo eixo retornam errorCode:#zeroProjection com mensagem descritiva. O updatePreview no tool exibe a mensagem ao usuário.

---

## Alternativas rejeitadas

- Novo GUID por modo: desnecessário — o CA suporta campos adicionais com default nativamente.
- Campo tipo integer (enum): rejeitado em favor de string para legibilidade e consistência.

---

## Consequências

- Cotas existentes abrem como aligned automaticamente.
- createDimension, createPreviewDimension, updatePreviewDimension e createController aceitam dimensionMode:#aligned com default não-disruptivo.
- Render overlay (E9) não precisa de alteração.
