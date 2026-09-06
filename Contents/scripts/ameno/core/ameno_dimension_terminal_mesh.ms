/*
    E13-F -- Terminais mesh preenchidos para cotas Ameno.

    Cria objetos mesh flat (triangulo, losango, disco) que substituem
    as pontas de seta/losango desenhadas em spline.
    Tipos suportados: #arrowClosed (triangulo 2-sided), #diamond (losango 2-sided), #dot (cilindro/disco).
    Tipos que permanecem em spline: #arrowOpen, #tick, #none.
*/

global AmenoDimensionTerminalMesh
global AmenoSceneSetup

struct AmenoDimensionTerminalMeshService
(
    fn _setTerminalProp nd dimensionId =
    (
        if nd == undefined or not isValidNode nd then return false
        try (setUserProp nd "AMENO_TERMINAL" true) catch ()
        if ::AmenoSceneSetup != undefined do
        (
            try
            (
                if dimensionId != undefined and dimensionId != "" do
                    ::AmenoSceneSetup.setTextProperty nd "Ameno.DimensionId" dimensionId
                ::AmenoSceneSetup.setTextProperty nd "Ameno.Kind" "dimensionGraphic"
                ::AmenoSceneSetup.setTextProperty nd "Ameno.GraphicRole" "terminal"
            )
            catch ()
        )
        true
    ),

    fn createTerminal termType pos dir size meshColor dimensionId:"" =
    (
        local nd = undefined
        try
        (
            case termType of
            (
                #arrowClosed:
                (
                    local safeDir = dir
                    local dlen = length safeDir
                    if dlen < 0.00001 then safeDir = [1, 0, 0] else safeDir = safeDir / dlen
                    local upAxis = [0, 0, 1]
                    if abs (dot safeDir upAxis) > 0.999 do upAxis = [0, 1, 0]
                    local perp = normalize (cross upAxis safeDir)
                    local halfWidth = size * 0.25
                    local tipPt = pos
                    local baseCenter = pos - (safeDir * size)
                    local base1 = baseCenter + (perp *  halfWidth)
                    local base2 = baseCenter + (perp * -halfWidth)

                    -- 2-sided face: [1, 2, 3] e [1, 3, 2]
                    nd = mesh name:(uniqueName "AMENO_TERM_A_") \
                             vertices:#(tipPt, base1, base2) \
                             faces:#([1, 2, 3], [1, 3, 2])

                    if nd != undefined and isValidNode nd then
                    (
                        nd.wirecolor = meshColor
                        try (nd.renderable = true) catch ()
                        _setTerminalProp nd dimensionId
                    )
                )

                #diamond:
                (
                    local safeDir = dir
                    local dlen = length safeDir
                    if dlen < 0.00001 then safeDir = [1, 0, 0] else safeDir = safeDir / dlen
                    local upAxis = [0, 0, 1]
                    if abs (dot safeDir upAxis) > 0.999 do upAxis = [0, 1, 0]
                    local perp = normalize (cross upAxis safeDir)
                    local half = size * 0.5
                    local vFront = pos + (safeDir *  half)
                    local vBack  = pos + (safeDir * -half)
                    local vLeft  = pos + (perp *  half)
                    local vRight = pos + (perp * -half)

                    -- Quad com faces 2-sided
                    nd = mesh name:(uniqueName "AMENO_TERM_D_") \
                             vertices:#(vFront, vLeft, vBack, vRight) \
                             faces:#([1, 2, 4], [2, 3, 4], [1, 4, 2], [2, 4, 3])

                    if nd != undefined and isValidNode nd then
                    (
                        nd.wirecolor = meshColor
                        try (nd.renderable = true) catch ()
                        _setTerminalProp nd dimensionId
                    )
                )

                #dot:
                (
                    local radius = size * 0.35
                    local h = size * 0.05
                    if h < 0.1 do h = 0.1
                    nd = cylinder name:(uniqueName "AMENO_TERM_DOT_") \
                                  radius:radius height:h sides:12 pos:pos

                    if nd != undefined and isValidNode nd then
                    (
                        nd.wirecolor = meshColor
                        try (nd.renderable = true) catch ()
                        _setTerminalProp nd dimensionId
                    )
                )

                default:
                (
                    nd = undefined
                )
            )
        )
        catch
        (
            nd = undefined
        )
        nd
    ),

    fn updateTerminal nd pos dir dimensionId:"" =
    (
        if nd == undefined or not isValidNode nd then return false
        try
        (
            local isTerminal = false
            try (isTerminal = (getUserProp nd "AMENO_TERMINAL") == true) catch ()
            if not isTerminal then return false

            local nmStr = nd.name
            if (matchPattern nmStr pattern:"AMENO_TERM_A_*") then
            (
                local safeDir = dir
                local dlen = length safeDir
                if dlen < 0.00001 then safeDir = [1, 0, 0] else safeDir = safeDir / dlen
                local upAxis = [0, 0, 1]
                if abs (dot safeDir upAxis) > 0.999 do upAxis = [0, 1, 0]
                local perp = normalize (cross upAxis safeDir)
                local numV = getNumVerts nd
                if numV >= 3 then
                (
                    local edgeLen = length ((getVert nd 1) - (getVert nd 2))
                    local halfWidth = edgeLen * 0.25
                    local tipPt = pos
                    local baseCenter = pos - (safeDir * edgeLen)
                    local b1 = baseCenter + (perp *  halfWidth)
                    local b2 = baseCenter - (perp * -halfWidth)
                    in coordsys world
                    (
                        setVert nd 1 tipPt
                        setVert nd 2 b1
                        setVert nd 3 b2
                    )
                    update nd
                )
            )
            else if (matchPattern nmStr pattern:"AMENO_TERM_D_*") then
            (
                local safeDir = dir
                local dlen = length safeDir
                if dlen < 0.00001 then safeDir = [1, 0, 0] else safeDir = safeDir / dlen
                local upAxis = [0, 0, 1]
                if abs (dot safeDir upAxis) > 0.999 do upAxis = [0, 1, 0]
                local perp = normalize (cross upAxis safeDir)
                local numV = getNumVerts nd
                if numV >= 4 then
                (
                    local diagLen = length ((getVert nd 1) - (getVert nd 3))
                    local half = diagLen * 0.5
                    local vFront = pos + (safeDir *  half)
                    local vBack  = pos + (safeDir * -half)
                    local vLeft  = pos + (perp *  half)
                    local vRight = pos + (perp * -half)
                    in coordsys world
                    (
                        setVert nd 1 vFront
                        setVert nd 2 vLeft
                        setVert nd 3 vBack
                        setVert nd 4 vRight
                    )
                    update nd
                )
            )
            else
            (
                nd.pos = pos
            )

            if dimensionId != undefined and dimensionId != "" and ::AmenoSceneSetup != undefined do
            (
                try (::AmenoSceneSetup.setTextProperty nd "Ameno.DimensionId" dimensionId) catch ()
            )
            true
        )
        catch
        (
            false
        )
    ),

    fn removeTerminal nd =
    (
        if nd == undefined then return false
        if not isValidNode nd then return false
        try
        (
            local isTerminal = false
            try (isTerminal = (getUserProp nd "AMENO_TERMINAL") == true) catch ()
            if isTerminal then
            (
                delete nd
                true
            )
            else
            (
                false
            )
        )
        catch
        (
            false
        )
    )
)

::AmenoDimensionTerminalMesh = AmenoDimensionTerminalMeshService()
