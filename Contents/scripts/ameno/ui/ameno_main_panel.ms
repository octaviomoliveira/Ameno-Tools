/*
    E13-H -- Stub de compatibilidade para ameno_main_panel.ms
    Os rollouts legados foram substituidos pela janela unificada WPF (AmenoCotasWindow).
    Mantem as variaveis e funcoes publicas globais para compatibilidade retroativa.
*/

global AmenoMainPanelRollout
global AmenoEnvRollout
global AmenoDimRollout
global AmenoAuditRollout
global AmenoAnchorRollout
global AmenoRenderRollout
global AmenoRefreshMainPanel
global AmenoShowMainPanel
global AmenoCotasWindow
global AmenoCotasEstilosTab
global AmenoApp
global AmenoStyleService
global AmenoCotasCriarTab
global AmenoCotasEditarTab
global AmenoCotasRenderTab

fn AmenoRefreshMainPanel =
(
    -- Se a janela unificada estiver aberta, sincronizar os dados de todas as abas
    if ::AmenoCotasWindow != undefined and ::AmenoCotasWindow.isOpen() do
    (
        try
        (
            -- Aba 1: Criar
            if ::AmenoCotasCriarTab != undefined do
            (
                try (::AmenoCotasCriarTab.populateEstilos()) catch ()
                try (::AmenoCotasCriarTab.updateCotaCount()) catch ()
            )
            -- Aba 2: Estilos
            if ::AmenoCotasEstilosTab != undefined do
            (
                try
                (
                    if ::AmenoStyleService != undefined then
                        ::AmenoCotasEstilosTab.currentDraft = ::AmenoStyleService.createDraftFromStyle "default"
                    ::AmenoCotasEstilosTab.populateStyleList()
                    ::AmenoCotasEstilosTab.loadDraftToUI()
                    ::AmenoCotasEstilosTab.updatePreview()
                )
                catch ()
            )
            -- Aba 3: Editar
            if ::AmenoCotasEditarTab != undefined do
            (
                try (::AmenoCotasEditarTab.refresh()) catch ()
            )
            -- Aba 4: Render
            if ::AmenoCotasRenderTab != undefined do
            (
                try (::AmenoCotasRenderTab.refreshCameras()) catch ()
                try (::AmenoCotasRenderTab.refreshRendererInfo()) catch ()
            )
        )
        catch ()
    )
)

fn AmenoShowMainPanel =
(
    if ::AmenoCotasWindow != undefined then
    (
        ::AmenoCotasWindow.show()
    )
    else if ::AmenoApp != undefined then
    (
        try (::AmenoApp.start()) catch ()
        if ::AmenoCotasWindow != undefined do ::AmenoCotasWindow.show()
    )
)
