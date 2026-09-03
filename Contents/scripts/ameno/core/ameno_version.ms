global AmenoVersion

struct AmenoVersionInfo
(
    appVersion = "0.0.1",
    schemaVersion = 1,
    targetMax = 2026,

    fn displayName =
    (
        "Ameno Tools " + appVersion
    )
)

AmenoVersion = AmenoVersionInfo()
