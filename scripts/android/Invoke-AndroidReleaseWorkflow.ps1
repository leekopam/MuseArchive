[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ProjectRoot,
    [switch]$GenerateKeystore,
    [switch]$InstallApk,
    [string]$DeviceId,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ProjectRoot) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$readinessScript = Join-Path $ProjectRoot "scripts\android\Get-AndroidReleaseReadiness.ps1"
$keystoreScript = Join-Path $ProjectRoot "scripts\android\New-AndroidReleaseKeystore.ps1"
$smokeScript = Join-Path $ProjectRoot "scripts\android\Invoke-AndroidDeviceSmoke.ps1"
$flutterPath = "C:\flutter\flutter\bin\flutter.bat"
$keyPropertiesPath = Join-Path $ProjectRoot "android\key.properties"

if (-not (Test-Path $readinessScript)) {
    throw "Missing readiness helper: $readinessScript"
}

if (-not (Test-Path $keystoreScript)) {
    throw "Missing keystore helper: $keystoreScript"
}

if (-not (Test-Path $smokeScript)) {
    throw "Missing device smoke helper: $smokeScript"
}

Write-Host ""
Write-Host "Step 1/4: current readiness"
& $readinessScript -ProjectRoot $ProjectRoot

if ($GenerateKeystore -and -not (Test-Path $keyPropertiesPath)) {
    Write-Host ""
    Write-Host "Step 2/4: generating Android release keystore"
    if ($PSCmdlet.ShouldProcess($keyPropertiesPath, "Generate Android release signing files")) {
        & $keystoreScript -ProjectRoot $ProjectRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Keystore helper failed with exit code $LASTEXITCODE"
        }
    }
} elseif ($GenerateKeystore) {
    Write-Host ""
    Write-Host "Step 2/4: keystore generation skipped because android/key.properties already exists."
} else {
    Write-Host ""
    Write-Host "Step 2/4: keystore generation not requested."
}

if (-not $SkipBuild) {
    if (-not (Test-Path $flutterPath)) {
        throw "Flutter executable not found at $flutterPath"
    }

    Write-Host ""
    Write-Host "Step 3/4: building release APK"
    & $flutterPath build apk --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk --release failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host ""
    Write-Host "Step 3/4: release build skipped."
}

Write-Host ""
Write-Host "Step 4/4: post-build readiness and optional install"
& $readinessScript -ProjectRoot $ProjectRoot

if ($InstallApk) {
    & $smokeScript -ProjectRoot $ProjectRoot -InstallApk -DeviceId $DeviceId
    if ($LASTEXITCODE -ne 0) {
        throw "Device smoke helper failed with exit code $LASTEXITCODE"
    }
} else {
    & $smokeScript -ProjectRoot $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Device smoke helper failed with exit code $LASTEXITCODE"
    }
}
