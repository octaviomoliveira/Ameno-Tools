/*
    E13-F -- Terminais mesh preenchidos para cotas Ameno.

    Cria objetos mesh flat (triangulo, losango, disco) que substituem
    as pontas de seta/losango desenhadas em spline.
    Tipos suportados: #arrowClosed (triangulo 2-sided), #diamond (losango 2-sided), #dot (disco 2-sided).
    Tipos que permanecem em spline: #arrowOpen, #tick, #none.

    A geometria e sempre reconstruida a partir de posicao + direcao +
    tamanho persistido. Nunca usa uma aresta da malha anterior como medida:
    isso evita o crescimento cumulativo observado em atualizacoes reativas.
*/

global AmenoDimensionTerminalMesh
global AmenoSceneSetup

struct AmenoDimensionTerminalMeshService
(
    terminalSchemaVersion = 1,

    fn isMeshTerminalType termType =
    (
        termType == #arrowClosed or termType == #diamond or termType == #dot
    ),

    fn _normalise vectorValue fallback:[1, 0, 0] =
    (
        local resolved = vectorValue
        local vectorLength = 0.0
        try (vectorLength = length resolved) catch (vectorLength = 0.0)
        if vectorLength < 0.00001 then
            (normalize fallback)
        else
            (resolved / vectorLength)
    ),

    fn _resolvePlaneNormal requestedNormal =
    (
        -- A geometria E2/E12 atualmente suporta a planta XY. O default aqui
        -- preserva a API publica antiga; os consumidores de layout passam a
        -- normal explicita derivada da base direction/perpendicular.
        local resolved = if requestedNormal == undefined then [0, 0, 1] else requestedNormal
        local normalLength = 0.0
        try (normalLength = length resolved) catch (normalLength = 0.0)
        if normalLength < 0.00001 then return undefined
        normalize resolved
    ),

    fn _basisFor dir planeNormal:undefined =
    (
        local safeDir = _normalise dir fallback:[1, 0, 0]
        local safeNormal = _resolvePlaneNormal planeNormal
        if safeNormal == undefined then return undefined

        -- Uma direcao paralela a normal nao pertence ao plano suportado.
        if abs (dot safeDir safeNormal) > 0.999 then return undefined

        local perpendicular = undefined
        try (perpendicular = normalize (cross safeNormal safeDir)) catch (perpendicular = undefined)
        if perpendicular == undefined or (length perpendicular) < 0.00001 then return undefined

        #(safeDir, perpendicular, safeNormal)
    ),

    fn _setTerminalProp nd dimensionId termType size planeNormal =
    (
        if nd == undefined or not isValidNode nd then return false

        try (setUserProp nd "AMENO_TERMINAL" true) catch ()
        try (setUserPropVal nd "AMENO_TERMINAL_TYPE" (termType as string)) catch ()
        try (setUserPropVal nd "AMENO_TERMINAL_SIZE" (size as float)) catch ()
        try (setUserPropVal nd "AMENO_TERMINAL_PLANE_NORMAL" planeNormal) catch ()
        try (setUserPropVal nd "AMENO_TERMINAL_SCHEMA" (terminalSchemaVersion as string)) catch ()

        if ::AmenoSceneSetup != undefined do
        (
            try
            (
                if dimensionId != undefined and dimensionId != "" do
                    ::AmenoSceneSetup.setTextProperty nd "Ameno.DimensionId" dimensionId
                ::AmenoSceneSetup.setTextProperty nd "Ameno.Kind" "dimensionGraphic"
                ::AmenoSceneSetup.setTextProperty nd "Ameno.GraphicRole" "terminal"
                ::AmenoSceneSetup.setTextProperty nd "Ameno.TerminalType" (termType as string)
                ::AmenoSceneSetup.setTextProperty nd "Ameno.TerminalSize" (size as string)
                ::AmenoSceneSetup.setTextProperty nd "Ameno.TerminalSchema" (terminalSchemaVersion as string)
            )
            catch ()
        )
        true
    ),

    fn _terminalTypeFromNode nd =
    (
        local resolved = #none
        local typeValue = undefined
        try (typeValue = getUserPropVal nd "AMENO_TERMINAL_TYPE") catch ()
        if typeValue != undefined do
        (
            local typeText = typeValue as string
            if typeText != "" do
            (
                if typeText[1] == "#" do typeText = substring typeText 2 (typeText.count - 1)
                try (resolved = typeText as name) catch ()
            )
        )

        if resolved == #none then
        (
            local nodeName = nd.name
            if matchPattern nodeName pattern:"AMENO_TERM_A_*" then resolved = #arrowClosed
            else if matchPattern nodeName pattern:"AMENO_TERM_DOT_*" then resolved = #dot
            else if matchPattern nodeName pattern:"AMENO_TERM_D_*" then resolved = #diamond
        )
        resolved
    ),

    fn terminalTypeOf nd =
    (
        if nd == undefined or not isValidNode nd then undefined
        else _terminalTypeFromNode nd
    ),

    fn terminalSizeOf nd fallback:undefined =
    (
        if nd == undefined or not isValidNode nd then return fallback
        local value = undefined
        try (value = getUserPropVal nd "AMENO_TERMINAL_SIZE") catch ()
        if value != undefined then
        (
            try (return (value as float)) catch ()
        )
        fallback
    ),

    fn terminalPlaneNormalOf nd fallback:[0, 0, 1] =
    (
        if nd == undefined or not isValidNode nd then return fallback
        local value = undefined
        try (value = getUserPropVal nd "AMENO_TERMINAL_PLANE_NORMAL") catch ()
        if value != undefined do
        (
            try
            (
                if classof value == Point3 and (length value) > 0.00001 then return (normalize value)
            )
            catch ()
        )
        fallback
    ),

    fn isTerminal nd =
    (
        if nd == undefined or not isValidNode nd then false
        else (try ((getUserProp nd "AMENO_TERMINAL") == true) catch (false))
    ),

    fn setTerminalSide nd sideValue =
    (
        if nd == undefined or not isValidNode nd then return false
        try (setUserPropVal nd "AMENO_TERMINAL_SIDE" (sideValue as string)) catch ()
        if ::AmenoSceneSetup != undefined do
            try (::AmenoSceneSetup.setTextProperty nd "Ameno.TerminalSide" (sideValue as string)) catch ()
        true
    ),

    fn terminalSideOf nd =
    (
        if nd == undefined or not isValidNode nd then ""
        else
        (
            local value = ""
            try (value = getUserPropVal nd "AMENO_TERMINAL_SIDE" as string) catch ()
            value
        )
    ),

    fn _createDotMesh pos safeDir perpendicular radius meshColor dimensionId planeNormal sizeValue =
    (
        local vertices = #(pos)
        for vertexIndex = 0 to 11 do
        (
            local angle = (vertexIndex as float) * 30.0
            local alongPerpendicular = (cos angle) * radius
            local alongDirection = (sin angle) * radius
            append vertices (pos + (perpendicular * alongPerpendicular) + (safeDir * alongDirection))
        )

        local faces = #()
        for faceIndex = 2 to 13 do
        (
            local nextIndex = if faceIndex == 13 then 2 else (faceIndex + 1)
            append faces [1, faceIndex, nextIndex]
            append faces [1, nextIndex, faceIndex]
        )

        local nd = mesh name:(uniqueName "AMENO_TERM_DOT_") vertices:vertices faces:faces
        if nd != undefined and isValidNode nd then
        (
            nd.wirecolor = meshColor
            try (nd.renderable = true) catch ()
            _setTerminalProp nd dimensionId #dot sizeValue planeNormal
        )
        nd
    ),

    fn createTerminal termType pos dir size meshColor planeNormal:undefined dimensionId:"" =
    (
        if not (isMeshTerminalType termType) then return undefined

        local resolvedSize = 0.0
        try (resolvedSize = size as float) catch (resolvedSize = 0.0)
        if resolvedSize <= 0.00001 then throw "O tamanho do terminal mesh deve ser maior que zero."

        local basis = _basisFor dir planeNormal:planeNormal
        if basis == undefined then
            throw "A direção do terminal não pertence ao plano suportado pela cota."

        local safeDir = basis[1]
        local perpendicular = basis[2]
        local safeNormal = basis[3]
        local nd = undefined

        try
        (
            case termType of
            (
                #arrowClosed:
                (
                    local halfWidth = resolvedSize * 0.25
                    local tipPt = pos
                    local baseCenter = pos - (safeDir * resolvedSize)
                    local base1 = baseCenter + (perpendicular * halfWidth)
                    local base2 = baseCenter - (perpendicular * halfWidth)

                    -- 2-sided face: [1, 2, 3] e [1, 3, 2]
                    nd = mesh name:(uniqueName "AMENO_TERM_A_") \
                             vertices:#(tipPt, base1, base2) \
                             faces:#([1, 2, 3], [1, 3, 2])
                )

                #diamond:
                (
                    local half = resolvedSize * 0.5
                    local vFront = pos + (safeDir * half)
                    local vBack  = pos - (safeDir * half)
                    local vLeft  = pos + (perpendicular * half)
                    local vRight = pos - (perpendicular * half)

                    -- Quad com faces 2-sided.
                    nd = mesh name:(uniqueName "AMENO_TERM_D_") \
                             vertices:#(vFront, vLeft, vBack, vRight) \
                             faces:#([1, 2, 4], [2, 3, 4], [1, 4, 2], [2, 4, 3])
                )

                #dot:
                (
                    local radius = resolvedSize * 0.35
                    nd = _createDotMesh pos safeDir perpendicular radius meshColor dimensionId safeNormal resolvedSize
                )
            )

            if nd != undefined and isValidNode nd then
            (
                nd.wirecolor = meshColor
                try (nd.renderable = true) catch ()
                _setTerminalProp nd dimensionId termType resolvedSize safeNormal
            )
        )
        catch
        (
            throw
        )
        nd
    ),

    fn updateTerminal nd pos dir size:undefined planeNormal:undefined dimensionId:"" =
    (
        if nd == undefined or not isValidNode nd then return false
        if not (isTerminal nd) then return false

        local termType = _terminalTypeFromNode nd
        if not (isMeshTerminalType termType) then return false

        local resolvedSize = terminalSizeOf nd fallback:size
        if resolvedSize == undefined then return false
        try (resolvedSize = resolvedSize as float) catch (return false)
        if resolvedSize <= 0.00001 then return false

        local requestedNormal = planeNormal
        if requestedNormal == undefined do requestedNormal = terminalPlaneNormalOf nd
        local basis = _basisFor dir planeNormal:requestedNormal
        if basis == undefined then return false

        local safeDir = basis[1]
        local perpendicular = basis[2]
        local safeNormal = basis[3]
        local ok = false

        try
        (
            if termType == #arrowClosed then
            (
                if getNumVerts nd >= 3 then
                (
                    local halfWidth = resolvedSize * 0.25
                    local tipPt = pos
                    local baseCenter = pos - (safeDir * resolvedSize)
                    local base1 = baseCenter + (perpendicular * halfWidth)
                    local base2 = baseCenter - (perpendicular * halfWidth)
                    in coordsys world
                    (
                        setVert nd 1 tipPt
                        setVert nd 2 base1
                        setVert nd 3 base2
                    )
                    update nd
                    ok = true
                )
            )
            else if termType == #diamond then
            (
                if getNumVerts nd >= 4 then
                (
                    local half = resolvedSize * 0.5
                    local vFront = pos + (safeDir * half)
                    local vBack  = pos - (safeDir * half)
                    local vLeft  = pos + (perpendicular * half)
                    local vRight = pos - (perpendicular * half)
                    in coordsys world
                    (
                        setVert nd 1 vFront
                        setVert nd 2 vLeft
                        setVert nd 3 vBack
                        setVert nd 4 vRight
                    )
                    update nd
                    ok = true
                )
            )
            else if termType == #dot then
            (
                -- Discos antigos criados como Cylinder não possuem a topologia
                -- plana necessária para trocar de plano. O sincronizador remove
                -- e recria esses nós; nunca tenta inferir tamanho da malha.
                if getNumVerts nd == 13 and getNumFaces nd == 24 then
                (
                    local radius = resolvedSize * 0.35
                    setVert nd 1 pos
                    for vertexIndex = 0 to 11 do
                    (
                        local angle = (vertexIndex as float) * 30.0
                        local alongPerpendicular = (cos angle) * radius
                        local alongDirection = (sin angle) * radius
                        setVert nd (vertexIndex + 2) (pos + (perpendicular * alongPerpendicular) + (safeDir * alongDirection))
                    )
                    update nd
                    ok = true
                )
            )

            if ok do _setTerminalProp nd dimensionId termType resolvedSize safeNormal
        )
        catch (ok = false)
        ok
    ),

    fn removeTerminal nd =
    (
        if nd == undefined then return false
        if not (isValidNode nd) then return false
        if not (isTerminal nd) then return false
        try
        (
            delete nd
            true
        )
        catch
        (
            false
        )
    )
)

::AmenoDimensionTerminalMesh = AmenoDimensionTerminalMeshService()
