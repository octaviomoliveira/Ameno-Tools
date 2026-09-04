# 0016 — E10.3: Adapter de Render de Overlay para V-Ray CPU

**Data:** 2026-09-04  
**Status:** Aprovado / Implementado  
**Contexto:** E10.3 — Fluxo de produção e estabilização (Adapter V-Ray CPU)

---

## 1. Contexto

A etapa E9 estabeleceu o contrato comum de render separado de cotas (overlay PNG transparente com isolamento transacional da cena e preservação estrita de iluminação, materiais e Render Elements) utilizando o Corona Renderer como implementação de referência.

A etapa E10.3 estende esse contrato para suportar o **V-Ray CPU**, mantendo o pipeline renderer-agnostic e garantindo que o mesmo fluxo de isolamento, cálculo de resolução, enquadramento de câmera e restauração seja executado de maneira idêntica.

---

## 2. Decisões Técnicas

### 2.1 Contrato Universal do Adapter

O adapter V-Ray (`AmenoVRayRendererAdapterService`) implementa rigorosamente a interface exigida pelo `AmenoRenderCotasService`:

1. `validate(request)`:
   - Valida existência do request.
   - Detecta família do renderer via `AmenoRendererProbe.detect()` — aceita `#vray`.
   - Exige extensão `.png`.

2. `captureState()` / `restore(state)`:
   - Preserva e restaura configurações de I/O de PNG (`pngio.getAlpha()`, `pngio.getType()`, etc.).
   - Preserva e restaura `renderOutputFilename` e `renderSaveFile`.
   - Preserva e restaura propriedades de qualidade e GI do V-Ray (GI desativada no passe de overlay, thresholds de amostragem restaurados ao original).

3. `configureOutput(request)`:
   - Ativa PNG 24-bit com canal alpha habilitado.
   - Aponta `renderOutputFilename` para o arquivo de destino do request.
   - Desliga GI temporariamente para velocidade máxima e pureza de iluminação.
   - Configura limites de ruído (`0.02`) e tempo (`1.0` min) para garantir convergência ágil.

4. `createAnnotationMaterial(colorValue)`:
   - **Primeira escolha:** `VRayLightMtl()`, configurado com:
     - `color = colorValue`
     - `multiplier = 1.0`
     - `emitOnBackFaces = true`
     - `compensate_exposure = false` (evita escurecimento por exposição física de câmera)
     - `directRenderable = true`
   - **Fallback defensivo:** `VRayMtl()` com diffuse preto, `selfIllumination = colorValue`, `selfIllumination_multiplier = 1.0` e `selfIllumination_gi = false`.

5. `renderOverlay(request)`:
   - Executa `render ... cancelled:&wasCancelled`.
   - Limpa arquivos parciais em disco caso o usuário cancele com Esc.

6. `verifyOutput(request)`:
   - Confirma existência do arquivo gerado, correspondência de dimensões e presença do canal alpha.

### 2.2 Despacho Dinâmico de Adapter

O serviço central `AmenoRenderCotasService` agora conta com `resolveDefaultAdapter()`, que consulta `AmenoRendererProbe.detect()`:
- Se `#corona` -> utiliza `AmenoCoronaRendererAdapter`.
- Se `#vray` -> utiliza `AmenoVRayRendererAdapter`.
- Fallback padrão seguro para `AmenoCoronaRendererAdapter`.

A interface do usuário (`AmenoRenderRollout`) agora reconhece V-Ray CPU como pronto e V-Ray GPU como experimental, habilitando o botão de renderização automaticamente.

---

## 3. Consequências

- **Agnóstico:** A lógica de isolamento de cena, gestão de layers e restauração transacional não sabe nem precisa saber qual renderer está ativo.
- **Resiliente:** Se o usuário cancelar ou ocorrer uma falha durante o render no V-Ray, a cena do usuário é restaurada 100% ao estado anterior (materiais, visibilidade, iluminação).
- **Extensível:** Novos adaptadores futuros (ex.: Arnold, Scanline) podem ser adicionados seguindo exatamente este mesmo padrão.
