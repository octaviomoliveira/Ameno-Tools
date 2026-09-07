# ADR 0022 — Biblioteca global de estilos, cor do overlay e guarda do renderer

Data: 2026-09-06
Status: aceito para o hotfix E13; gate visual e V-Ray CPU real pendentes

## Contexto

O editor de estilos salvava os registros apenas no `.max`. Isso fazia um perfil desaparecer quando o usuário trocava de cena ou reiniciava o 3ds Max sem salvar a cena. Além disso, o render separado substituía temporariamente os materiais das cotas por um material branco, ignorando a cor escolhida no estilo.

Houve também um crash no caminho de render: o log persistente registrou `Renderer: Arnold · sem adapter` seguido de `EXCEPTION_ACCESS_VIOLATION` durante o estágio `render`. O despacho anterior usava Corona como fallback para uma família não reconhecida, permitindo que um adapter incompatível chegasse ao comando nativo.

## Decisões

1. A biblioteca global será gravada em `%LOCALAPPDATA%\AmenoTools\Profiles\styles.library`. O arquivo temporário `.tmp` evita escrita parcial e o `.bak` fornece recuperação best-effort. Registros scene-local continuam válidos e têm precedência por `styleId`, preservando portabilidade e referências antigas.
2. `annotationColor` é a fonte da cor de render da anotação. O serviço converte o RGB salvo no estilo e cria um material do adapter para cada cor distinta; `wirecolor` continua sendo apenas estado visual de viewport.
3. A seleção do adapter depende da família detectada no renderer atual. Corona e V-Ray têm adapters próprios; renderer desconhecido, Arnold e outras famílias retornam “sem adapter” e não chegam a `render()`.
4. A classe real do renderer (`classOf renderers.current`) deve aparecer junto do nome amigável no painel Render, no diagnóstico e no log. A UI atualiza essa informação ao abrir/ativar a aba e no clique de render; o serviço repete a validação imediatamente antes da chamada nativa.
5. Chamadas ao `render()` sem câmera não devem passar `camera:undefined`; o adapter usa uma forma de chamada sem o argumento para evitar que `undefined` atravesse a ponte nativa como ponteiro nulo.

## Consequências

- Perfis ficam disponíveis entre cenas e reinícios, sem remover os estilos embutidos nos arquivos `.max`.
- Um renderer não suportado fica bloqueado e explicado ao usuário, em vez de tentar um adapter de outra família.
- Compatibilidade com versões novas de Corona depende das propriedades de capacidade descobertas pelo adapter; Corona 15 Hotfix 1 foi testado de forma real nesta rodada.
- V-Ray CPU ainda precisa de render real. Arnold permanece deliberadamente sem adapter até existir uma implementação específica.

## Evidência

- `tests/maxscript/test_e13_global_styles_render_color.ms`: persistência global, RGB, materiais por cor e encaminhamento ao adapter.
- `tests/maxscript/test_e10_3_vray.ms`: despacho por família e rejeição de adapter conhecido em renderer incompatível.
- `tests/maxscript/test_e9_corona_render.ms`: Corona 15 Hotfix 1, PNG com alpha e restauração; saída em `.test-output/e9_corona_real.png`.
- `C:\Users\octav\AppData\Local\AmenoTools\Logs\ameno-20260906-180520-144.log`: incidente original com Arnold e access violation.
