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
global AmenoCotasCriarTab
global AmenoCotasEditarTab
global AmenoCotasRenderTab

fn AmenoRefreshMainPanel =
(
    -- Se a janela unificada estiver aberta, notificar as abas ativas
    if ::AmenoCotasWindow != undefined and ::AmenoCotasWindow.isOpen() do
    (
        try
        (
            case ::AmenoCotasWindow.activeSection of
            (
                1: if ::AmenoCotasCriarTab != undefined do ::AmenoCotasCriarTab.updateCotaCount()
                3: if ::AmenoCotasEditarTab != undefined do ::AmenoCotasEditarTab.refresh()
                4: if ::AmenoCotasRenderTab != undefined do ::AmenoCotasRenderTab.refreshRendererInfo()
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
