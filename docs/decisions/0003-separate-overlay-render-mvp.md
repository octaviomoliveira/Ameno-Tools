# ADR 0003 — Render separado das cotas no MVP

Status: aceita
Data: 2026-09-03

## Contexto

Integrar cotas ao Beauty, LightMix e Render Elements no mesmo passe exige adapters específicos, testes por renderer e tratamento de Self Illumination, LightSelect, AOV, alpha e composição. Isso aumenta o escopo antes de validarmos a ferramenta de cotagem.

O usuário já possui um fluxo simples e conhecido: montar a imagem no Photoshop.

## Decisão

O MVP terá um botão `Renderizar Cotas` que produz somente a layer `AMENO_COTAS` em PNG/EXR transparente, usando a mesma câmera, resolução, frame e enquadramento da planta.

O Ameno não altera Beauty, LightMix ou Render Elements no MVP.

## Experiência

```text
render normal da planta
        +
botão Renderizar Cotas
        ↓
PNG/EXR transparente
        ↓
composição no Photoshop
```

## Benefícios

- implementação menor e mais testável;
- comportamento consistente entre renderizadores;
- LightMix permanece totalmente livre;
- nenhum risco de alterar Render Elements do usuário;
- saída visual explícita e fácil de diagnosticar;
- valida rapidamente o valor principal do Ameno Dimensions.

## Custos

- existe um segundo render;
- o usuário compõe manualmente;
- color management precisa ser documentado;
- o overlay não compartilha automaticamente o mesmo arquivo EXR multicanal.

## Requisitos obrigatórios

- alpha correto;
- alinhamento pixel-perfect;
- restauração da cena após sucesso, cancelamento ou erro;
- render apenas de todas as cotas ou das selecionadas;
- path previsível;
- nenhuma alteração permanente no render principal.

## Relação com ADR 0002

ADR 0002 continua como arquitetura futura. Esta decisão reduz o escopo da primeira versão: somente layer dedicada e render de overlay independente são obrigatórios no MVP.
