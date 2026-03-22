[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ProjectRoot,
    [string]$PackageName = "com.example.my_album_app",
    [string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk",
    [string]$DeviceId,
    [switch]$InstallApk
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-AdbPath {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $sdkAdb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdb) {
        return $sdkAdb
    }

    return $null
}

function Resolve-ProjectPath {
    param(
        [string]$BasePath,
        [string]$CandidatePath
    )

    if ([System.IO.Path]::IsPathRooted($CandidatePath)) {
        return [System.IO.Path]::GetFullPath($CandidatePath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $CandidatePath))
}

if (-not $ProjectRoot) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$resolvedApkPath = Resolve-ProjectPath -BasePath $ProjectRoot -CandidatePath $ApkPath
$adbPath = Resolve-AdbPath
$connectedDevices = @()

if ($adbPath) {
    $adbOutput = & $adbPath devices
    if ($LASTEXITCODE -ne 0) {
        throw "adb devices failed with exit code $LASTEXITCODE"
    }

    $connectedDevices = @(
        $adbOutput |
            Where-Object { $_ -match "^[^\s]+\s+device$" } |
            ForEach-Object { ($_ -split "\s+")[0] }
    )
}

Write-Host ""
Write-Host "Android device smoke helper"
Write-Host "Project root: $ProjectRoot"
Write-Host "Package name: $PackageName"
Write-Host "APK path: $resolvedApkPath"
Write-Host "adb path: $(if ($adbPath) { $adbPath } else { 'not found' })"
Write-Host ""

if (-not $adbPath) {
    Write-Warning "adb was not found. Install Android platform-tools or add adb to PATH before using automatic device checks."
} elseif ($connectedDevices.Count -eq 0) {
    Write-Warning "No Android device is connected. Attach a physical device and enable USB debugging."
} else {
    Write-Host "Connected devices:"
    foreach ($connectedDevice in $connectedDevices) {
        Write-Host "  - $connectedDevice"
    }
}

if ($InstallApk) {
    if (-not $adbPath) {
        throw "Cannot install the APK because adb was not found."
    }

    if (-not (Test-Path $resolvedApkPath)) {
        throw "APK not found at $resolvedApkPath"
    }

    if ($connectedDevices.Count -eq 0) {
        throw "Cannot install the APK because no connected device was found."
    }

    if ($connectedDevices.Count -gt 1 -and [string]::IsNullOrWhiteSpace($DeviceId)) {
        throw "Multiple devices are connected. Re-run with -DeviceId to select one."
    }

    $targetDevice = if ($DeviceId) { $DeviceId } else { $connectedDevices[0] }

    if ($PSCmdlet.ShouldProcess($targetDevice, "Install release APK")) {
        & $adbPath -s $targetDevice install -r $resolvedApkPath
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }
}

Write-Host ""
Write-Host "Manual smoke checklist"
Write-Host "1. Open MuseArchive on the physical Android device."
Write-Host "2. Add screen > tap the barcode icon > grant camera permission > scan a real barcode."
Write-Host "   Verify the album lookup runs and the new album is saved."
Write-Host "3. Settings > create backup."
Write-Host "   Verify the system save dialog appears via flutter_file_dialog and the saved backup file is readable."
Write-Host "4. Settings > share backup."
Write-Host "   Verify the Android share sheet appears via share_plus and the chosen target receives the backup."
Write-Host "5. Optional: Settings > restore backup with the same backup file to confirm round-trip restore."
