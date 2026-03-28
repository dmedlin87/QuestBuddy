param(
    [Parameter(Mandatory = $false)]
    [string]$Action = "install", # install, link, clean, dist

    [Parameter(Mandatory = $false)]
    [string]$WowPath = "C:\Program Files\Ascension Launcher\resources\client",

    [Parameter(Mandatory = $false)]
    [string]$Flavor = "retail", # retail, classic, classic_era

    [Parameter(Mandatory = $false)]
    [switch]$PauseOnExit
)

$sharedHelperPath = Join-Path $PSScriptRoot "scripts\AddonDevManager.ps1"
if (-not (Test-Path -LiteralPath $sharedHelperPath -PathType Leaf)) {
    throw "Shared addon helper was not found at '$sharedHelperPath'."
}

. $sharedHelperPath

$config = [AddonDevConfig]::new()
$config.Action = $Action
$config.AddonName = "QuestBuddy"
$config.AddonFolder = "QuestBuddy"
$config.ProjectRoot = $PSScriptRoot
$config.EntryScriptPath = $MyInvocation.PSCommandPath
$config.WowPath = $WowPath
$config.Flavor = $Flavor
$config.PauseOnExit = [bool]$PauseOnExit
$config.LinkSourcePath = $PSScriptRoot
$config.TocPath = Join-Path $PSScriptRoot "QuestBuddy.toc"
$config.TocContentRoot = $PSScriptRoot

Invoke-AddonDevCommand -Config $config