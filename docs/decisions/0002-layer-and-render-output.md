# ADR 0002 — Layer dedicada e saídas de render

Status: aceita
Data: 2026-09-03

## Contexto

Cotas de planta precisam ser controladas como conjunto e usadas tanto em imagens prontas quanto em composição. Além disso, muitos usuários entregam o resultado do LightMix, que existe como canal/Render Element diferente do Beauty nativo. Uma cota presente apenas no RGB original pode desaparecer da saída realmente entregue.

Materiais emissivos também podem ser classificados como Self Illumination ou luz e entrar no LightMix. Isso permitiria alterar a cor/intensidade das cotas junto com a iluminação, o que é indesejado.

## Decisão

Toda representação renderizável pertence a uma layer gerenciada, normalmente `AMENO_COTAS`. Controladores e metadados ficam em `AMENO_SYSTEM`.

O perfil de render separa três conceitos:

- canal de entrega: Beauty, LightMix ou composição externa;
- modo: integrada, separada, integrada + separada ou somente viewport;
- tipo de element: Mask ou Annotation RGBA.

Por padrão, LightMix recebe as cotas como overlay posterior à iluminação. O overlay permanece separado e pode gerar uma prévia ou cópia achatada do canal final.

A integração é feita por adapters de renderizador. Quando RGBA isolado não estiver disponível no mesmo passe, usa-se segundo passe protegido e restaurável.

## Razões

- layer oferece controle imediato de seleção e visibilidade;
- separar sistema e representação evita desligar dados ao ocultar a arte;
- Mask é eficiente para cor única;
- Annotation RGBA preserva cores e permite composição direta;
- overlay posterior não contamina LightMix, Self Illumination ou LightSelect;
- adapters isolam diferenças de Corona, V-Ray, Arnold e futuros renderizadores;
- fallback impede prometer uma capacidade que o renderer não possui.

## Restrições

- não sequestrar layer homônima do usuário;
- não tratar cotas como luzes controláveis pelo LightMix;
- não apagar ou alterar Render Elements do usuário;
- não deixar estado temporário após erro/cancelamento;
- não afirmar que Mask equivale a RGBA colorido;
- não depender apenas do nome da layer/element como identidade;
- validar Beauty e LightMix separadamente nos testes.

## Consequências

O primeiro MVP oferece layer dedicada e Beauty. Em seguida entram Mask e Annotation RGBA por segundo passe. Integração direta com LightMix e RGBA no mesmo passe são habilitadas por renderer apenas depois de testes formais.

## Referências

- [LayerManager do 3ds Max](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Interfaces/Core-Interfaces/Core-Interfaces-Documentation/L/GUID-79537E16-FE25-4567-BEA6-06F39E0A5C1F.html)
- [RenderElementMgr do 3ds Max](https://help.autodesk.com/cloudhelp/2022/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Interfaces/Other-Interfaces/Other-Interfaces-1/GUID-E8F75D47-B998-4800-A3A5-610E22913CFC.html)
- [V-Ray LightMix](https://docs.chaos.com/pages/viewpage.action?pageId=60885856)
- [Corona Light Material e LightMix](https://docs.chaos.com/display/CRMAX/Corona%2BLight%2BMaterial)
