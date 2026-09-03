# Valores manuais e avisos de viewport

## Por que existe

O modelo do 3ds Max pode divergir do levantamento, do projeto aprovado ou de uma medida que precisa ser comunicada. O Ameno deve permitir corrigir a informação exibida sem fingir que a geometria possui aquele valor.

## Regra fundamental

```text
valor medido ≠ valor exibido
```

Ambos são preservados. O valor medido vem das âncoras; o valor exibido segue um modo explícito.

## Modos

### Medido

Usa a geometria atual e a formatação do estilo.

### Arredondado

Usa a geometria atual, arredondada para incremento conhecido. Resolve valores quebrados de forma consistente.

Exemplos:

- incremento 1 cm;
- incremento 5 cm;
- incremento 10 cm.

### Manual numérico

Usa o número informado pelo usuário, mas continua aplicando unidade, precisão, prefixo e sufixo do estilo.

### Texto manual

Texto livre para exceções. Deve ser visualmente identificado no painel e não confundido com número confiável.

## Advertência

Manual numérico e texto manual recebem:

- cor âmbar viewport-only;
- marcador `M` ou lápis;
- tooltip/painel com medido, exibido e delta;
- entrada no diagnóstico;
- filtro de seleção.

O render nunca contém a cor ou o marcador de advertência. Ele contém o valor manual com o estilo gráfico normal.

## Exemplo

```text
Geometria atual     20,000 m
Levantamento        19,600 m
Valor renderizado   19,60 m
Delta               -0,400 m
Motivo              Levantamento
Viewport            âmbar + M
Render              estilo normal
```

## Persistência

Guardar:

- modo;
- valor manual canônico em milímetros;
- texto livre, se usado;
- motivo;
- data de alteração;
- autor opcional;
- último medido;
- último delta.

## Alteração da planta

Ao mover uma referência:

1. recalcular medido;
2. manter manual;
3. recalcular delta;
4. manter advertência;
5. opcionalmente destacar quando delta ultrapassar tolerância definida.

## Ações em lote

- selecionar todas as manuais;
- mostrar/ocultar advertências;
- restaurar valores medidos;
- aplicar regra de arredondamento;
- exportar relatório CSV futuro;
- filtrar por motivo.

## Limites

- editar valor não move paredes;
- o Ameno não afirma que o valor manual corresponde à geometria;
- restauração em lote sempre pede confirmação;
- texto livre não participa de cálculos;
- valores numéricos são armazenados em unidade canônica, não como string localizada.
