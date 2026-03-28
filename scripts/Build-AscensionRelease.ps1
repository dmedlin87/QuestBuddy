param(
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "release-assets",

    [Parameter(Mandatory = $false)]
    [string]$ReleaseNotes = "",

    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseConfigPath = Join-Path $repoRoot "addon-release.json"
if (-not (Test-Path -LiteralPath $releaseConfigPath -PathType Leaf)) {
    throw "Expected release metadata file was not found at '$releaseConfigPath'."
}
$releaseConfig = Get-Content -LiteralPath $releaseConfigPath -Raw | ConvertFrom-Json

if ($releaseConfig.schemaVersion -ne 1) {
    throw "Release metadata schemaVersion must be 1."
}

$addonName = [string]$releaseConfig.displayName
$addonId = [string]$releaseConfig.addonId
$Version = [string]$releaseConfig.version
$targetSupport = @($releaseConfig.targetSupport)
$folders = @($releaseConfig.folders)
$minInstallerVersion = [string]$releaseConfig.minInstallerVersion

if ([string]::IsNullOrWhiteSpace($addonName) -or
    [string]::IsNullOrWhiteSpace($addonId) -or
    [string]::IsNullOrWhiteSpace($Version) -or
    [string]::IsNullOrWhiteSpace($minInstallerVersion)) {
    throw "Release metadata is missing one of: displayName, addonId, version, minInstallerVersion."
}

if ($folders.Count -ne 1) {
    throw "Release metadata must define exactly one managed folder."
}

$addonFolder = [string]$folders[0]
$tocPath = Join-Path $repoRoot "$addonFolder.toc"
$resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $repoRoot $OutputDir
}

$semverPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'

if ($Version -notmatch $semverPattern) {
    throw "Version '$Version' is not valid semver. Use a tag like v1.0.0 or v1.0.0-beta.1."
}

if ($ExpectedVersion -and $ExpectedVersion -ne $Version) {
    throw "Release metadata version '$Version' does not match expected version '$ExpectedVersion'."
}

if ($targetSupport.Count -eq 0) {
    throw "Release metadata must define at least one supported target."
}

if ($minInstallerVersion -notmatch $semverPattern) {
    throw "minInstallerVersion '$minInstallerVersion' is not valid semver."
}

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Expected TOC file was not found at '$tocPath'."
}

$tocVersionMatch = Select-String -Path $tocPath -Pattern '^## Version:\s*(.+)$'
if (-not $tocVersionMatch) {
    throw "Unable to read addon version from '$tocPath'."
}

$tocVersion = $tocVersionMatch.Matches[0].Groups[1].Value.Trim()
if ($tocVersion -ne $Version) {
    throw "TOC version '$tocVersion' does not match release version '$Version'. Update $tocPath before releasing."
}

$tocEntries = Get-Content -LiteralPath $tocPath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#") }

if (-not $tocEntries) {
    throw "No runtime files were declared in '$tocPath'."
}

$zipName = "$addonFolder-v$Version.zip"
$zipPath = Join-Path $resolvedOutputDir $zipName
$manifestPath = Join-Path $resolvedOutputDir "addon-manifest.json"
$stageRoot = Join-Path $resolvedOutputDir ".stage-$addonFolder-$Version"
$stagedAddonPath = Join-Path $stageRoot $addonFolder

if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stagedAddonPath -Force | Out-Null
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

Copy-Item -LiteralPath $tocPath -Destination (Join-Path $stagedAddonPath "$addonFolder.toc") -Force

foreach ($entry in $tocEntries) {
    if ([System.IO.Path]::IsPathRooted($entry) -or $entry.Contains("..")) {
        throw "TOC entry '$entry' is not valid for release packaging."
    }

    $sourcePath = Join-Path $repoRoot $entry
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "TOC entry '$entry' was not found at '$sourcePath'."
    }

    $destinationPath = Join-Path $stagedAddonPath $entry
    $destinationDir = Split-Path -Parent $destinationPath
    if ($destinationDir) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

if (Test-Path -LiteralPath $manifestPath) {
    Remove-Item -LiteralPath $manifestPath -Force
}

Compress-Archive -Path $stagedAddonPath -DestinationPath $zipPath -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $rootNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.FullName)) {
            continue
        }

        $normalizedEntry = $entry.FullName.Replace('\', '/')
        $trimmed = $normalizedEntry.TrimStart('./').TrimEnd('/')
        if ([string]::IsNullOrEmpty($trimmed)) {
            continue
        }

        $rootSegment = $trimmed.Split('/')[0]
        if (-not [string]::IsNullOrEmpty($rootSegment)) {
            [void]$rootNames.Add($rootSegment)
        }
    }

    if ($rootNames.Count -ne 1 -or -not $rootNames.Contains($addonFolder)) {
        $foundRoots = ($rootNames | Sort-Object) -join ', '
        throw "Zip root validation failed. Expected only '$addonFolder' at the archive root, found: $foundRoots"
    }
}
finally {
    $archive.Dispose()
}

$manifest = [ordered]@{
    schemaVersion       = 1
    addonId             = $addonId
    displayName         = $addonName
    version             = $Version
    targetSupport       = $targetSupport
    folders             = $folders
    assetName           = $zipName
    sha256              = $hash
    minInstallerVersion = $minInstallerVersion
    releaseNotes        = $ReleaseNotes
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$writtenManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($writtenManifest.addonId -ne $addonId) {
    throw "Manifest validation failed: addonId must be '$addonId'."
}

if (@($writtenManifest.folders).Count -ne $folders.Count) {
    throw "Manifest validation failed: folders do not match release metadata."
}

if ($writtenManifest.assetName -ne $zipName) {
    throw "Manifest validation failed: assetName does not match the zip asset name."
}

foreach ($folder in $folders) {
    if (-not (@($writtenManifest.folders) -contains $folder)) {
        throw "Manifest validation failed: folders do not match release metadata."
    }
}

foreach ($target in $targetSupport) {
    if (-not (@($writtenManifest.targetSupport) -contains $target)) {
        throw "Manifest validation failed: targetSupport does not match release metadata."
    }
}

if ($writtenManifest.minInstallerVersion -ne $minInstallerVersion) {
    throw "Manifest validation failed: minInstallerVersion does not match release metadata."
}

if ($writtenManifest.version -ne $Version) {
    throw "Manifest validation failed: version must match the tag version without the leading v."
}

Remove-Item -LiteralPath $stageRoot -Recurse -Force

Write-Host "Built release assets:" -ForegroundColor Green
Write-Host "- $zipPath"
Write-Host "- $manifestPath"

