global AmenoRendererProbe

struct AmenoRendererInfo
(
    family = #unknown,
    engine = #unknown,
    className = "",
    displayName = "Renderer desconhecido",
    supportState = #unsupported,

    fn statusLabel =
    (
        case supportState of
        (
            #supported: "suportado"
            #experimental: "experimental"
            default: "sem adapter"
        )
    )
)

struct AmenoRendererProbeService
(
    fn containsRendererName className pattern =
    (
        matchPattern className pattern:pattern ignoreCase:true
    ),

    fn isVrayClass className =
    (
        (containsRendererName className "*vray*") or
        (containsRendererName className "*v_ray*") or
        (containsRendererName className "*v-ray*") or
        (containsRendererName className "*v ray*")
    ),

    fn classify className =
    (
        if containsRendererName className "*corona*" then
        (
            (AmenoRendererInfo family:#corona engine:#cpu className:className displayName:"Corona" supportState:#supported)
        )
        else if isVrayClass className then
        (
            local usesGpu = containsRendererName className "*gpu*"

            (AmenoRendererInfo family:#vray engine:(if usesGpu then #gpu else #cpu) className:className displayName:(if usesGpu then "V-Ray GPU" else "V-Ray CPU") supportState:(if usesGpu then #experimental else #supported))
        )
        else
        (
            (AmenoRendererInfo className:className displayName:className)
        )
    ),

    fn detect =
    (
        local currentRenderer = renderers.current

        if currentRenderer == undefined then
        (
            AmenoRendererInfo()
        )
        else
        (
            local rendererClassName = (classOf currentRenderer) as string

            classify rendererClassName
        )
    )
)

AmenoRendererProbe = AmenoRendererProbeService()
