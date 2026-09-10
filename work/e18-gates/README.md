# E18 automated gates

`summary.txt` and the paired listener/system logs are the 3ds Max 2026 evidence
for the E18 transition. The matrix runs the bootstrap and all E12–E17
regressions plus the E18 Qt host contract: 19 suites, all PASS on 2026-09-09.

The installed canary was then checked separately with
`tests/maxscript/test_e18_installed_host.ms`, which loads the copy under
`%APPDATA%\\Autodesk\\ApplicationPlugins\\AmenoTools` and validates the same
draft, pure preview, compact rail, overflow and icon contracts.
