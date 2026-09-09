# E16 — baseline congelada

Data da coleta: 2026-09-09. Escopo certificado: 3ds Max 2026.3 (build
28.3.0.0.30732), Python 3.11.12 e PySide6/Qt 6.5.3. O renderer observado no
Batch foi Arnold. O Batch não expõe driver, DPI nem resolução de viewport; esses
campos ficam para o gate manual.

## Evidência anterior à E16

O diagnóstico registrado antes da implementação mediu o mesmo custo por
segmento nos dois modos:

| Caso | Tempo informado | Custo aproximado |
| --- | ---: | ---: |
| 2 segmentos verticais | 5,28 s | 2,64 s/segmento |
| 7 segmentos horizontais | 18,15 s | 2,59 s/segmento |

Isso aponta para o pipeline comum de criação de spline, TextPlus, terminais,
material e preview, não para uma fórmula vertical isolada. A linha quente
inspecionada era `refreshChainPreview()` durante `mouseMove`.

Esses valores são a medição de reprodução fornecida no diagnóstico e não são
apresentados como uma mediana estatística de cinco rodadas: o processo Max
interativo existente não podia ser recarregado com segurança sem risco para uma
cena não salva. A comparação reproduzível pós-E16 está em
`../e16-regression/README.md` e nos logs da execução Batch.

## Invariantes observados

- a cena real não é usada como canvas de preview;
- picking completo fica reservado ao clique;
- o estado de referência é comparado por handles, classes, materiais, layers e
  seleção;
- os testes Batch são executados uma instância por vez, em perfil isolado.

## Comando de referência

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-maxscript.ps1 \
  -TestScript .\tests\maxscript\test_vertical_performance.ms
```

O teste acima é um controle H/V do cálculo e da materialização. Ele não
substitui o soak humano em uma cena problemática.
