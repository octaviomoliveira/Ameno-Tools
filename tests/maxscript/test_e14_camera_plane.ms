/* E14.1 — captura de câmera ortográfica nivelada e recusas do MVP. */
(
    global AmenoDimensionPlaneService

    local testFile = getSourceFileName()
    local testPath = getFilenamePath testFile
    local repositoryRoot = pathConfig.normalizePath (pathConfig.appendPath testPath @"..\..")
    local bootstrapPath = pathConfig.normalizePath (pathConfig.appendPath repositoryRoot @"Contents\scripts\startup\ameno_bootstrap.ms")
    fileIn bootstrapPath quiet:true
    resetMaxFile #noPrompt

    local passed = 0
    local failed = 0

    fn check label value expected: true =
    (
        if value == expected then passed += 1
        else
        (
            failed += 1
            format "[FAIL] % | esperado=% obtido=%\n" label expected value
        )
    )

    local target = targetObject name:"E14_CAMERA_TARGET" pos:[0,0,50]
    local camera = targetCamera name:"E14_CAMERA_ORTHO" pos:[0,-200,50] target:target
    camera.orthoProjection = true
    local captured = AmenoDimensionPlaneService.cameraPlane camera
    check "camera ortográfica nivelada válida" captured.valid
    check "camera gera plano de vista" captured.planeType expected:#viewPlane
    check "camera mantém V mundial Z" ((length (captured.axisV - [0,0,1])) <= 0.001)

    camera.orthoProjection = false
    local perspective = AmenoDimensionPlaneService.cameraPlane camera
    check "camera perspectiva recusada" perspective.errorCode expected:#perspectiveNotSupported

    camera.orthoProjection = true
    target.pos = [0,20,70]
    local tilted = AmenoDimensionPlaneService.cameraPlane camera
    check "camera inclinada recusada" tilted.errorCode expected:#cameraTilt

    format "=== [AMENO_E14_CAMERA] RESULT %/% PASS ===\n" passed (passed + failed)
    delete #(camera, target)
    if failed == 0 then
        format "[AMENO_TEST][PASS] E14 camera plane passed.\n"
    else
    (
        format "[AMENO_TEST][FAIL] E14 camera plane failures=%\n" failed
        throw ("E14 camera plane failed: " + (failed as string))
    )
)
