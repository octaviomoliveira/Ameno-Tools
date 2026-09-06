/* Diagnostico/regressao: preview e cota permanente devem conservar a mesma
   posicao do rótulo quando o texto acompanha a linha. */
(
    local testPath = getSourceFileName()
    local root = pathConfig.normalizePath (pathConfig.appendPath (getFilenamePath testPath) @"..\..")
    local bootstrap = pathConfig.normalizePath (pathConfig.appendPath root @"Contents\scripts\startup\ameno_bootstrap.ms")
    resetMaxFile #noPrompt
    fileIn bootstrap quiet:true

    fn pointText p = ("[" + (p.x as string) + "," + (p.y as string) + "," + (p.z as string) + "]")
    fn check condition label =
    (
        if not condition do throw ("[AMENO_TEST][FAIL] " + label)
        format "[AMENO_TEST][PASS] %\n" label
    )

    ::AmenoDimensionGraphics.textFollowsLine = true
    local pointA = [0,0,0]
    local pointB = [0,100,0]
    local offset = [30,0,0]
    local layout = ::AmenoDimensionMath.layoutForMode pointA pointB offset mode:#vertical
    local preview = ::AmenoDimensionGraphics.createPreviewDimension pointA pointB offset outputUnit:#meters precision:2 styleId:"default" mode:#vertical
    local permanent = ::AmenoDimensionGraphics.createDimension pointA pointB offset outputUnit:#meters precision:2 styleId:"default" dimensionMode:#vertical

    local expectedGap = ::AmenoDimensionGraphics.toSceneUnits (::AmenoStyleService.getStyle "default").textGap
    local expected = ((layout.linePointA + layout.linePointB) * 0.5) + (layout.perpendicular * expectedGap)
    format "[AMENO_TEST][DETAIL] expected=% previewPos=% permanentPos=%\n" (pointText expected) (pointText preview.textNode.pos) (pointText permanent.textNode.pos)
    format "[AMENO_TEST][DETAIL] previewCenter=% permanentCenter=%\n" (pointText preview.textNode.center) (pointText permanent.textNode.center)
    check (::AmenoDimensionMath.nearlyEqualPoint preview.textNode.pos expected tolerance:0.0001) "preview conserva posicao calculada"
    check (::AmenoDimensionMath.nearlyEqualPoint permanent.textNode.pos expected tolerance:0.0001) "commit conserva posicao calculada"
    check ((abs permanent.textNode.transform.row1.y) > 0.99) "commit conserva orientacao vertical"

    ::AmenoDimensionGraphics.removePreviewDimension preview
    ::AmenoDimensionGraphics.removeDimension permanent.dimensionId
    format "[AMENO_TEST][PASS] Diagnostico de posicao concluido.\n"
)
