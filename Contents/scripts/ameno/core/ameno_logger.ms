global AmenoLog

struct AmenoLogger
(
    prefix = "Ameno",
    entries = #(),

    fn write level message =
    (
        local levelText = toUpper (level as string)
        local line = "[" + prefix + "][" + levelText + "] " + (message as string)

        append entries line
        format "%\n" line
        line
    ),

    fn info message =
    (
        write #info message
    ),

    fn warn message =
    (
        write #warn message
    ),

    fn error message =
    (
        write #error message
    ),

    fn clear =
    (
        entries = #()
        true
    )
)

AmenoLog = AmenoLogger()
