# Android Release Setup

This project is ready for Android release builds. The Android package name is now fixed to `com.example.my_album_app`, and one owner-managed input still remains:

1. Permanent release keystore

## 1. Android package name is fixed

The project is pinned to these values in `android/gradle.properties`:

```properties
musearchive.namespace=com.example.my_album_app
musearchive.applicationId=com.example.my_album_app
musearchive.requireReleaseSigning=true
```

Notes:

- `applicationId` controls install/update identity on Android.
- `namespace` should normally match `applicationId`.
- Changing these after publishing will create a different app from Google Play's perspective.
- The Android entrypoint already matches this package:
  [MainActivity.kt](d:/Project/01_Personal/MuseArchive/android/app/src/main/kotlin/com/example/my_album_app/MainActivity.kt)

## 2. Create or place the release keystore

Fastest path:

```powershell
.\scripts\android\New-AndroidReleaseKeystore.ps1
```

This generates both:

- `android/upload-keystore.jks`
- `android/key.properties`

The script prompts for the passwords securely when you do not pass them on the command line. It refuses to overwrite existing files unless you pass `-Force`, and it supports `-WhatIf` for a dry run.

If you prefer non-interactive usage:

```powershell
.\scripts\android\New-AndroidReleaseKeystore.ps1 `
  -StorePassword "choose-a-strong-password" `
  -KeyPassword "choose-a-strong-password"
```

Example command:

```powershell
keytool -genkeypair `
  -v `
  -keystore android\upload-keystore.jks `
  -alias upload `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000
```

If you prefer manual setup, copy `android/key.properties.example` to `android/key.properties` and fill the real values:

```properties
storeFile=upload-keystore.jks
storePassword=your-store-password
keyAlias=upload
keyPassword=your-key-password
```

Notes:

- `storeFile` may be relative to the `android/` directory.
- With `musearchive.requireReleaseSigning=false`, release builds fall back to the
  local debug key for convenience.
- With `musearchive.requireReleaseSigning=true`, the build will fail until
  `android/key.properties` is complete and the keystore file exists.
- Never commit `android/key.properties`, `*.jks`, or `*.keystore`.

## 3. Validate the release build

```powershell
C:\flutter\flutter\bin\flutter.bat build apk --release
```

Quick readiness check:

```powershell
.\scripts\android\Get-AndroidReleaseReadiness.ps1
```

One-shot workflow:

```powershell
.\scripts\android\Invoke-AndroidReleaseWorkflow.ps1 -GenerateKeystore -InstallApk
```

This runs the readiness check, generates signing files if requested, builds the release APK, and then hands off to the device smoke helper.

## 4. Device smoke checklist

Run these on a physical Android device before shipping:

- `mobile_scanner`: scan a real barcode and confirm album lookup + save
- `share_plus`: export/share backup completes through the system sheet
- `flutter_file_dialog`: save backup to device completes and file is readable afterward

Detailed step-by-step notes:

- [Android-Device-Smoke.md](d:/Project/01_Personal/MuseArchive/docs/Summary/Android-Device-Smoke.md)
