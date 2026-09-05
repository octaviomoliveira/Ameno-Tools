/*
    E13-F -- Terminais mesh preenchidos para cotas Ameno.

    Cria objetos mesh flat (triangulo, losango, disco) que substituem
    as pontas de seta/losango desenhadas em spline.
    Tipos suportados: #arrowClosed (triangulo), #diamond (losango), #dot (disco).
    Tipos que permanecem em spline: #arrowOpen, #tick, #none.
*/

global AmenoDimensionTerminalMesh

struct AmenoDimensionTerminalMeshService
(
    fn _setTerminalProp nd =
    (
        if nd == undefined or not isValidNode nd then return false
        try (setUserProp nd "AMENO_TERMINAL" true) catch ()
        true
    ),

    fn createTerminal termType pos dir size meshColor =
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
                    local perp = normalize (cross [0, 0, 1] safeDir)
                    local halfWidth = size * 0.25
                    local tipPt = pos + (safeDir * size)
                    local base1 = pos + (perp *  halfWidth)
                    local base2 = pos + (perp * -halfWidth)

                    nd = mesh name:(uniqueName "AMENO_TERM_A_") \
                             vertices:#(tipPt, base1, base2) \
                             faces:#([1, 2, 3])

                    if nd != undefined and isValidNode nd then
                    (
                        nd.wirecolor = meshColor
                        try (nd.renderable = true) catch ()
                        _setTerminalProp nd
                    )
                )

                #diamond:
                (
                    local safeDir = dir
                    local dlen = length safeDir
                    if dlen < 0.00001 then safeDir = [1, 0, 0] else safeDir = safeDir / dlen
                    local perp = normalize (cross [0, 0, 1] safeDir)
                    local half = size * 0.5
                    local vFront = pos + (safeDir *  half)
                    local vBack  = pos + (safeDir * -half)
                    local vLeft  = pos + (perp *  half)
                    local vRight = pos + (perp * -half)

                    nd = mesh name:(uniqueName "AMENO_TERM_D_") \
                             vertices:#(vFront, vLeft, vBack, vRight) \
                             faces:#([1, 2, 4], [2, 3, 4])

                    if nd != undefined and isValidNode nd then
                    (
                        nd.wirecolor = meshColor
                        try (nd.renderable = true) catch ()
                        _setTerminalProp nd
                    )
                )

                #dot:
                (
                    local radius = size * 0.4
                    nd = cylinder name:(uniqueName "AMENO_TERM_DOT_") \
                                  radius:radius height:0.1 sides:12 pos:pos

                    if nd != undefined and isValidNode nd then
                    (
                        nd.wirecolor = meshColor
                        try (nd.renderable = true) catch ()
                        _setTerminalProp nd
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

    fn updateTerminal nd pos dir =
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
                local perp = normalize (cross [0, 0, 1] safeDir)
                local numV = getNumVerts nd
                if numV >= 3 then
                (
                    local edgeLen = length ((getVert nd 1) - (getVert nd 2))
                    local halfWidth = edgeLen * 0.25
                    local tipPt = pos + (safeDir * edgeLen)
                    local b1 = pos + (perp *  halfWidth)
                    local b2 = pos + (perp * -halfWidth)
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
                local perp = normalize (cross [0, 0, 1] safeDir)
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
