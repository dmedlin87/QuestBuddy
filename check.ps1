$ErrorActionPreference = 'Stop'

$lua = Get-Command lua -ErrorAction SilentlyContinue
if (-not $lua) {
    $lua = Get-Command luajit -ErrorAction SilentlyContinue
}

if (-not $lua) {
    throw 'No lua or luajit executable was found on PATH.'
}

& $lua.Source 'tests/test_runner.lua'
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host 'QuestBuddy checks passed.'