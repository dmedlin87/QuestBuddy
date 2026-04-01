Set-StrictMode -Version Latest

class AddonDevConfig {
    [string]$Action = "install"
    [string]$AddonName
    [string]$AddonFolder
    [string]$ProjectRoot
    [string]$EntryScriptPath
    [string]$WowPath = "C:\Program Files\Ascension Launcher\resources\client"
    [string]$Flavor = "retail"
    [bool]$PauseOnExit = $false
    [string]$InstallSourcePath
    [string]$LinkSourcePath
    [string]$TocPath
    [string]$TocContentRoot
    [string]$CoverageScriptPath
}

class AddonDevManager {
    [AddonDevConfig]$Config
    [bool]$ElevationRelaunched = $false
    [int]$ExitCode = 0

    AddonDevManager([AddonDevConfig]$config) {
        if ($null -eq $config) {
            throw "Addon development config is required."
        }

        if ([string]::IsNullOrWhiteSpace($config.AddonName)) {
            throw "Config.AddonName is required."
        }

        if ([string]::IsNullOrWhiteSpace($config.AddonFolder)) {
            $config.AddonFolder = $config.AddonName
        }

        if ([string]::IsNullOrWhiteSpace($config.ProjectRoot)) {
            throw "Config.ProjectRoot is required."
        }

        $this.Config = $config
    }

    [string[]] GetSupportedActions() {
        $actions = @("install", "link", "clean", "dist")
        if (-not [string]::IsNullOrWhiteSpace($this.Config.CoverageScriptPath)) {
            $actions += "coverage"
        }

        return $actions
    }

    [string] GetUsage() {
        return ".\\" + [System.IO.Path]::GetFileName($this.Config.EntryScriptPath) +
            " -Action [" + (($this.GetSupportedActions()) -join "|") + "] -Flavor [retail|classic|classic_era|ptr]"
    }

    [string] GetDirectAddonDir() {
        return Join-Path $this.Config.WowPath "Interface\AddOns"
    }

    [string] GetFlavorAddonDir() {
        return Join-Path $this.Config.WowPath ("_{0}_\Interface\AddOns" -f $this.Config.Flavor)
    }

    [string] GetTargetAddonDir() {
        $directAddonDir = $this.GetDirectAddonDir()
        if (Test-Path -LiteralPath $directAddonDir -PathType Container) {
            return $directAddonDir
        }

        return $this.GetFlavorAddonDir()
    }

    [string] GetTargetPath() {
        return Join-Path ($this.GetTargetAddonDir()) $this.Config.AddonFolder
    }

    [void] ConfirmPath([string]$path) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
            throw "Path not found: $path"
        }
    }

    [void] InvokeOperation([scriptblock]$operation, [string]$failureMessage) {
        try {
            & $operation
        }
        catch {
            throw "$failureMessage $($_.Exception.Message)"
        }
    }

    [bool] TestIsAdministrator() {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    [string] FormatArgument([string]$value) {
        if ($null -eq $value) {
            return '""'
        }

        return '"' + ($value -replace '"', '\"') + '"'
    }

    [string] BuildRelaunchArgumentList() {
        $argList = @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            ($this.FormatArgument($this.Config.EntryScriptPath))
            "-Action"
            ($this.FormatArgument($this.Config.Action))
            "-WowPath"
            ($this.FormatArgument($this.Config.WowPath))
            "-Flavor"
            ($this.FormatArgument($this.Config.Flavor))
        ) -join " "

        if ($this.Config.PauseOnExit) {
            $argList += " -PauseOnExit"
        }

        return $argList
    }

    [void] RequestElevation([string]$actionDescription) {
        if ([string]::IsNullOrWhiteSpace($this.Config.EntryScriptPath)) {
            throw "$actionDescription requires administrator privileges. Re-run PowerShell as Administrator."
        }

        try {
            Start-Process PowerShell -Verb RunAs -ArgumentList ($this.BuildRelaunchArgumentList()) | Out-Null
            Write-Host "$actionDescription requires elevation. Opened an administrator PowerShell to continue." -ForegroundColor Yellow
            $this.ElevationRelaunched = $true
            throw [System.OperationCanceledException]::new("ElevationRelaunched")
        }
        catch [System.OperationCanceledException] {
            throw
        }
        catch {
            throw "Failed to relaunch PowerShell as Administrator. $($_.Exception.Message)"
        }
    }

    [void] EnsureWriteAccess([string]$directoryPath, [string]$actionDescription, [bool]$requireAdministrator) {
        if ($requireAdministrator -and -not $this.TestIsAdministrator()) {
            $this.RequestElevation($actionDescription)
        }

        $probePath = Join-Path $directoryPath (".{0}-write-test" -f $this.Config.AddonFolder.ToLowerInvariant())
        try {
            New-Item -ItemType File -Path $probePath -Force -ErrorAction Stop | Out-Null
            Remove-Item -Path $probePath -Force -ErrorAction Stop
        }
        catch {
            if (-not $this.TestIsAdministrator()) {
                $this.RequestElevation($actionDescription)
            }

            throw "$actionDescription requires write access to '$directoryPath'. $($_.Exception.Message)"
        }
    }

    [string] GetTocPath() {
        if ([string]::IsNullOrWhiteSpace($this.Config.TocPath)) {
            throw "A TOC path is required for this action."
        }

        return $this.Config.TocPath
    }

    [string] GetTocContentRoot() {
        if ([string]::IsNullOrWhiteSpace($this.Config.TocContentRoot)) {
            throw "A TOC content root is required for this action."
        }

        return $this.Config.TocContentRoot
    }

    [string] GetTocVersion() {
        $tocPath = $this.GetTocPath()
        $this.ConfirmPath($tocPath)

        $tocVersionMatch = Select-String -Path $tocPath -Pattern '^## Version:\s*(.+)$'
        if (-not $tocVersionMatch) {
            throw "Unable to read addon version from '$tocPath'."
        }

        return $tocVersionMatch.Matches[0].Groups[1].Value.Trim()
    }

    [string[]] GetTocEntries() {
        $tocPath = $this.GetTocPath()
        $this.ConfirmPath($tocPath)

        $tocEntries = Get-Content -LiteralPath $tocPath |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#") }

        if (-not $tocEntries) {
            throw "No runtime files were declared in '$tocPath'."
        }

        return @($tocEntries)
    }

    [string] NewStageRoot([string]$purpose) {
        $stageBase = Join-Path ([System.IO.Path]::GetTempPath()) "addon-dev-stage"
        New-Item -ItemType Directory -Path $stageBase -Force | Out-Null

        $stageRoot = Join-Path $stageBase ("{0}-{1}-{2}" -f $this.Config.AddonFolder, $purpose, [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
        return $stageRoot
    }

    [string] StageRuntimeFromToc([string]$stageRoot) {
        $stagedAddonPath = Join-Path $stageRoot $this.Config.AddonFolder
        $tocPath = $this.GetTocPath()
        $contentRoot = $this.GetTocContentRoot()

        New-Item -ItemType Directory -Path $stagedAddonPath -Force | Out-Null
        Copy-Item -LiteralPath $tocPath -Destination (Join-Path $stagedAddonPath ("{0}.toc" -f $this.Config.AddonFolder)) -Force

        foreach ($entry in $this.GetTocEntries()) {
            if ([System.IO.Path]::IsPathRooted($entry) -or $entry.Contains("..")) {
                throw "TOC entry '$entry' is not valid for staging."
            }

            $sourcePath = Join-Path $contentRoot $entry
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

        return $stagedAddonPath
    }

    [hashtable] ResolveInstallSource() {
        if (-not [string]::IsNullOrWhiteSpace($this.Config.InstallSourcePath)) {
            $this.ConfirmPath($this.Config.InstallSourcePath)
            return @{
                Path        = $this.Config.InstallSourcePath
                CleanupPath = $null
            }
        }

        $stageRoot = $this.NewStageRoot("install")
        $stagedAddonPath = $this.StageRuntimeFromToc($stageRoot)
        return @{
            Path        = $stagedAddonPath
            CleanupPath = $stageRoot
        }
    }

    [hashtable] ResolveDistSource() {
        if (-not [string]::IsNullOrWhiteSpace($this.Config.TocPath)) {
            $stageRoot = $this.NewStageRoot("dist")
            $stagedAddonPath = $this.StageRuntimeFromToc($stageRoot)
            return @{
                Path        = $stagedAddonPath
                CleanupPath = $stageRoot
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($this.Config.InstallSourcePath)) {
            $this.ConfirmPath($this.Config.InstallSourcePath)
            return @{
                Path        = $this.Config.InstallSourcePath
                CleanupPath = $null
            }
        }

        throw "No install or TOC source is configured for dist."
    }

    [void] RemovePathIfPresent([string]$path) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
        }
    }

    [void] Install() {
        $targetAddonDir = $this.GetTargetAddonDir()
        $targetPath = $this.GetTargetPath()
        $source = $this.ResolveInstallSource()

        $this.ConfirmPath($targetAddonDir)
        $this.EnsureWriteAccess($targetAddonDir, ("Installing {0}" -f $this.Config.AddonName), $false)

        try {
            Write-Host ("Installing {0} to {1}..." -f $this.Config.AddonName, $targetPath) -ForegroundColor Cyan
            if (Test-Path -LiteralPath $targetPath) {
                $this.InvokeOperation(
                    { $this.RemovePathIfPresent($targetPath) },
                    "Failed to remove existing addon."
                )
            }

            $this.InvokeOperation(
                { Copy-Item -Recurse -Path $source.Path -Destination $targetPath -ErrorAction Stop },
                "Failed to install addon."
            )

            Write-Host ("Installed {0} to {1}" -f $this.Config.AddonName, $targetPath) -ForegroundColor Green
        }
        finally {
            if ($source.CleanupPath) {
                $this.RemovePathIfPresent($source.CleanupPath)
            }
        }
    }

    [void] Link() {
        if ([string]::IsNullOrWhiteSpace($this.Config.LinkSourcePath)) {
            throw "LinkSourcePath is required for the link action."
        }

        $targetAddonDir = $this.GetTargetAddonDir()
        $targetPath = $this.GetTargetPath()
        $this.ConfirmPath($this.Config.LinkSourcePath)
        $this.ConfirmPath($targetAddonDir)
        $this.EnsureWriteAccess($targetAddonDir, ("Linking {0}" -f $this.Config.AddonName), $true)

        Write-Host ("Creating Symbolic Link for {0}..." -f $this.Config.AddonName) -ForegroundColor Cyan
        if (Test-Path -LiteralPath $targetPath) {
            Write-Host "Removing existing folder/link..." -ForegroundColor Yellow
            $this.InvokeOperation(
                { $this.RemovePathIfPresent($targetPath) },
                "Failed to remove existing addon before linking."
            )
        }

        $this.InvokeOperation(
            { New-Item -ItemType SymbolicLink -Path $targetPath -Target $this.Config.LinkSourcePath -ErrorAction Stop | Out-Null },
            "Failed to create symbolic link."
        )

        Write-Host "Link created! Changes in this folder will reflect instantly in-game (after /reload)." -ForegroundColor Green
    }

    [void] Clean() {
        $targetAddonDir = $this.GetTargetAddonDir()
        $targetPath = $this.GetTargetPath()

        if (Test-Path -LiteralPath $targetPath) {
            $this.ConfirmPath($targetAddonDir)
            $this.EnsureWriteAccess($targetAddonDir, ("Cleaning {0}" -f $this.Config.AddonName), $false)
            Write-Host ("Cleaning {0} from {1}..." -f $this.Config.AddonName, $targetPath) -ForegroundColor Yellow
            $this.InvokeOperation(
                { $this.RemovePathIfPresent($targetPath) },
                "Failed to clean addon."
            )
            Write-Host "Cleaned." -ForegroundColor Green
            return
        }

        Write-Host "Addon not found in target path. Nothing to clean."
    }

    [void] Dist() {
        $version = $this.GetTocVersion()
        $source = $this.ResolveDistSource()
        $zipFile = Join-Path $this.Config.ProjectRoot ("{0}-v{1}.zip" -f $this.Config.AddonFolder, $version)

        try {
            Write-Host ("Creating distribution zip: {0}" -f $zipFile) -ForegroundColor Cyan
            if (Test-Path -LiteralPath $zipFile) {
                Remove-Item -LiteralPath $zipFile -Force
            }

            Compress-Archive -Path $source.Path -DestinationPath $zipFile -Force
            Write-Host ("Created {0}" -f $zipFile) -ForegroundColor Green
        }
        finally {
            if ($source.CleanupPath) {
                $this.RemovePathIfPresent($source.CleanupPath)
            }
        }
    }

    [void] Coverage() {
        if ([string]::IsNullOrWhiteSpace($this.Config.CoverageScriptPath)) {
            throw ("Coverage is not configured for {0}." -f $this.Config.AddonName)
        }

        $this.ConfirmPath($this.Config.CoverageScriptPath)

        Write-Host "Running Lua coverage..." -ForegroundColor Cyan
        & $this.Config.CoverageScriptPath -Clean
        if ($LASTEXITCODE -ne 0) {
            $this.ExitCode = $LASTEXITCODE
            throw ("Coverage script exited with code {0}." -f $LASTEXITCODE)
        }

        Write-Host "Coverage complete." -ForegroundColor Green
    }

    [void] Run() {
        $action = if ([string]::IsNullOrWhiteSpace($this.Config.Action)) {
            "install"
        } else {
            $this.Config.Action.ToLowerInvariant()
        }

        switch ($action) {
            "install" { $this.Install(); return }
            "link" { $this.Link(); return }
            "clean" { $this.Clean(); return }
            "dist" { $this.Dist(); return }
            "coverage" {
                if (-not ($this.GetSupportedActions() -contains "coverage")) {
                    break
                }

                $this.Coverage()
                return
            }
        }

        throw ("Unknown action: {0}`nUse: {1}" -f $this.Config.Action, $this.GetUsage())
    }
}

function Test-AddonDevAutoPauseOnExit {
    try {
        $currentProcess = Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = {0}" -f $PID) -ErrorAction Stop
        if ($null -eq $currentProcess -or $currentProcess.ParentProcessId -le 0) {
            return $false
        }

        $parentProcess = Get-Process -Id $currentProcess.ParentProcessId -ErrorAction Stop
        return $parentProcess.ProcessName -ieq "explorer"
    }
    catch {
        return $false
    }
}

function Wait-ForAddonDevExitAcknowledgement {
    param(
        [Parameter(Mandatory)]
        [bool]$PauseOnExit
    )

    $shouldPause = $PauseOnExit -or (Test-AddonDevAutoPauseOnExit)
    if (-not $shouldPause) {
        return
    }

    Write-Host ""
    Write-Host "Press any key to close this window..." -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
}

function Invoke-AddonDevCommand {
    param(
        [Parameter(Mandatory)]
        [AddonDevConfig]$Config
    )

    $exitCode = 0
    $manager = [AddonDevManager]::new($Config)

    try {
        $manager.Run()
    }
    catch [System.OperationCanceledException] {
        if (-not $manager.ElevationRelaunched) {
            Write-Error $_.Exception.Message
            $exitCode = if ($manager.ExitCode -ne 0) { $manager.ExitCode } else { 1 }
        }
    }
    catch {
        Write-Error $_.Exception.Message
        $exitCode = if ($manager.ExitCode -ne 0) { $manager.ExitCode } else { 1 }
    }
    finally {
        Wait-ForAddonDevExitAcknowledgement -PauseOnExit:$Config.PauseOnExit
    }

    exit $exitCode
}
