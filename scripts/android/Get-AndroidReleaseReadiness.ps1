[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk"
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

function Get-GradlePropertyValue {
    param(
        [string[]]$Lines,
        [string]$Key
    )

    foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Key))=(.+)$") {
            return $Matches[1].Trim()
        }
    }

    return $null
}

if (-not $ProjectRoot) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$androidDir = Join-Path $ProjectRoot "android"
$gradlePropertiesPath = Join-Path $androidDir "gradle.properties"
$keyPropertiesPath = Join-Path $androidDir "key.properties"
$resolvedApkPath = Resolve-ProjectPath -BasePath $ProjectRoot -CandidatePath $ApkPath

$gradleLines = Get-Content $gradlePropertiesPath
$namespace = Get-GradlePropertyValue -Lines $gradleLines -Key "musearchive.namespace"
$applicationId = Get-GradlePropertyValue -Lines $gradleLines -Key "musearchive.applicationId"
$requireReleaseSigning = Get-GradlePropertyValue -Lines $gradleLines -Key "musearchive.requireReleaseSigning"
$keystoreFiles = @(Get-ChildItem $androidDir -Recurse -Include *.jks,*.keystore -File -ErrorAction SilentlyContinue)
$adbPath = Resolve-AdbPath
$devices = @()

if ($adbPath) {
    $adbOutput = & $adbPath devices
    if ($LASTEXITCODE -ne 0) {
        throw "adb devices failed with exit code $LASTEXITCODE"
    }

    $devices = @(
        $adbOutput |
            Where-Object { $_ -match "^[^\s]+\s+device$" } |
            ForEach-Object { ($_ -split "\s+")[0] }
    )
}

$emulators = @($devices | Where-Object { $_ -like "emulator-*" })
$physicalDevices = @($devices | Where-Object { $_ -notlike "emulator-*" })
$blockers = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $keyPropertiesPath)) {
    $blockers.Add("Create android/key.properties")
}

if ($keystoreFiles.Count -eq 0) {
    $blockers.Add("Create an Android release keystore (*.jks or *.keystore)")
}

if (-not (Test-Path $resolvedApkPath)) {
    $blockers.Add("Build the release APK")
}

if (-not $adbPath) {
    $blockers.Add("Install Android platform-tools or add adb to PATH")
}

if ($physicalDevices.Count -eq 0) {
    $blockers.Add("Connect a physical Android device and enable USB debugging")
}

Write-Host ""
Write-Host "Android release readiness"
Write-Host "Project root: $ProjectRoot"
Write-Host "Package name: $applicationId"
Write-Host "Namespace: $namespace"
Write-Host "Require release signing: $requireReleaseSigning"
Write-Host "Release APK: $(if (Test-Path $resolvedApkPath) { 'ready' } else { 'missing' })"
Write-Host "android/key.properties: $(if (Test-Path $keyPropertiesPath) { 'present' } else { 'missing' })"
Write-Host "Keystore files under android/: $(if ($keystoreFiles.Count -gt 0) { $keystoreFiles.Count } else { 0 })"
Write-Host "adb: $(if ($adbPath) { $adbPath } else { 'not found' })"
Write-Host "Emulators: $($emulators.Count)"
Write-Host "Physical devices: $($physicalDevices.Count)"

if ($keystoreFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Detected keystore files:"
    foreach ($keystoreFile in $keystoreFiles) {
        Write-Host "  - $($keystoreFile.FullName)"
    }
}

Write-Host ""
if ($blockers.Count -eq 0) {
    Write-Host "No blocking issues detected for the current release/device checklist."
} else {
    Write-Host "Remaining blockers:"
    foreach ($blocker in $blockers) {
        Write-Host "  - $blocker"
    }
}
