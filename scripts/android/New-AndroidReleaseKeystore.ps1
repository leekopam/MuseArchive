[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ProjectRoot,
    [string]$KeystoreFile = "android/upload-keystore.jks",
    [string]$KeyPropertiesFile = "android/key.properties",
    [string]$StorePassword,
    [string]$KeyPassword,
    [string]$KeyAlias = "upload",
    [string]$DistinguishedName = "CN=MuseArchive, OU=Mobile, O=MuseArchive, L=Seoul, S=Seoul, C=KR",
    [int]$ValidityDays = 10000,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertFrom-SecureStringPlain {
    param([System.Security.SecureString]$SecureString)

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-ConfirmedSecret {
    param(
        [string]$Prompt,
        [switch]$AllowEmpty
    )

    while ($true) {
        $firstSecure = Read-Host -AsSecureString -Prompt $Prompt
        $first = ConvertFrom-SecureStringPlain -SecureString $firstSecure

        if ([string]::IsNullOrWhiteSpace($first)) {
            if ($AllowEmpty) {
                return ""
            }

            Write-Warning "The value cannot be empty."
            continue
        }

        $confirmSecure = Read-Host -AsSecureString -Prompt "Confirm $Prompt"
        $confirm = ConvertFrom-SecureStringPlain -SecureString $confirmSecure

        if ($first -eq $confirm) {
            return $first
        }

        Write-Warning "The values did not match. Try again."
    }
}

function Resolve-KeytoolPath {
    $command = Get-Command keytool -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $androidStudioKeytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $androidStudioKeytool) {
        return $androidStudioKeytool
    }

    throw "Could not find keytool. Install a JDK or Android Studio first."
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

function Convert-ToStoreFileValue {
    param(
        [string]$AndroidDirectory,
        [string]$KeystorePath
    )

    $androidDirectory = [System.IO.Path]::GetFullPath($AndroidDirectory)
    $keystorePath = [System.IO.Path]::GetFullPath($KeystorePath)
    $androidPrefix = $androidDirectory.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

    if ($keystorePath.StartsWith($androidPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $keystorePath.Substring($androidPrefix.Length)
    }

    return $keystorePath
}

if (-not $ProjectRoot) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$androidDirectory = Join-Path $ProjectRoot "android"

if (-not (Test-Path $androidDirectory)) {
    throw "Could not find the android directory under $ProjectRoot"
}

if ([string]::IsNullOrWhiteSpace($StorePassword)) {
    $StorePassword = Read-ConfirmedSecret -Prompt "Android keystore store password"
}

if ([string]::IsNullOrWhiteSpace($StorePassword)) {
    throw "StorePassword cannot be empty."
}

if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
    $KeyPassword = Read-ConfirmedSecret `
        -Prompt "Android keystore key password (press Enter to reuse the store password)" `
        -AllowEmpty
}

if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
    $KeyPassword = $StorePassword
}

if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
    throw "KeyPassword cannot be empty."
}

$resolvedKeystorePath = Resolve-ProjectPath -BasePath $ProjectRoot -CandidatePath $KeystoreFile
$resolvedKeyPropertiesPath = Resolve-ProjectPath -BasePath $ProjectRoot -CandidatePath $KeyPropertiesFile

if (((Test-Path $resolvedKeystorePath) -or (Test-Path $resolvedKeyPropertiesPath)) -and -not $Force) {
    throw "Keystore or key.properties already exists. Re-run with -Force if you intend to replace them."
}

$keytoolPath = Resolve-KeytoolPath
$storeFileValue = Convert-ToStoreFileValue -AndroidDirectory $androidDirectory -KeystorePath $resolvedKeystorePath

$keytoolArguments = @(
    "-genkeypair",
    "-v",
    "-keystore", $resolvedKeystorePath,
    "-alias", $KeyAlias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", $ValidityDays.ToString(),
    "-storepass", $StorePassword,
    "-keypass", $KeyPassword,
    "-dname", $DistinguishedName,
    "-noprompt"
)

$keystoreDirectory = Split-Path -Parent $resolvedKeystorePath
$keyPropertiesDirectory = Split-Path -Parent $resolvedKeyPropertiesPath

if ($keystoreDirectory -and -not (Test-Path $keystoreDirectory)) {
    New-Item -ItemType Directory -Path $keystoreDirectory -Force | Out-Null
}

if ($keyPropertiesDirectory -and -not (Test-Path $keyPropertiesDirectory)) {
    New-Item -ItemType Directory -Path $keyPropertiesDirectory -Force | Out-Null
}

if ($PSCmdlet.ShouldProcess($resolvedKeystorePath, "Generate Android release keystore")) {
    & $keytoolPath @keytoolArguments
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE"
    }
}

$keyPropertiesContent = @"
storeFile=$storeFileValue
storePassword=$StorePassword
keyAlias=$KeyAlias
keyPassword=$KeyPassword
"@

if ($PSCmdlet.ShouldProcess($resolvedKeyPropertiesPath, "Write Android key.properties")) {
    Set-Content -Path $resolvedKeyPropertiesPath -Value $keyPropertiesContent -Encoding ASCII
}

Write-Host ""
Write-Host "Android release signing files are ready."
Write-Host "Keystore: $resolvedKeystorePath"
Write-Host "Key properties: $resolvedKeyPropertiesPath"
Write-Host ""
Write-Host "Next step:"
Write-Host "  C:\flutter\flutter\bin\flutter.bat build apk --release"
