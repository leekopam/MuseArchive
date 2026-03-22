# Android Device Smoke

These are the last physical-device checks still worth running before shipping the Android build.

## Scope

- `mobile_scanner`: barcode capture from the add screen
- `flutter_file_dialog`: backup save-to-device flow
- `share_plus`: backup share sheet flow

## Fast Start

If `adb` is installed and a physical Android device is attached with USB debugging enabled:

```powershell
.\scripts\android\Invoke-AndroidDeviceSmoke.ps1 -InstallApk
```

This helper:

- finds `adb`
- lists connected devices
- optionally installs `build/app/outputs/flutter-apk/app-release.apk`
- prints the manual smoke checklist below

If `adb` is not installed yet, the helper still prints the manual checklist so you can continue with the physical-device runbook.

If more than one device is connected, pass `-DeviceId`.

## Checklist

### 1. Barcode scan

Entry point:

- [add_screen.dart](d:/Project/01_Personal/MuseArchive/lib/screens/add_screen.dart#L471)
- [barcode_scanner_screen.dart](d:/Project/01_Personal/MuseArchive/lib/screens/barcode_scanner_screen.dart#L1)

Steps:

1. Open the add screen.
2. Tap the barcode icon in the app bar.
3. Grant camera permission if Android asks.
4. Scan a real album barcode.

Expected result:

- camera preview opens
- a detected barcode closes the scanner
- album lookup runs through the form view model
- album fields update and autosave continues normally

### 2. Backup save to device

Entry point:

- [settings_screen.dart](d:/Project/01_Personal/MuseArchive/lib/screens/settings_screen.dart#L217)
- [album_repository.dart](d:/Project/01_Personal/MuseArchive/lib/services/album_repository.dart#L646)

Steps:

1. Open Settings.
2. Tap `백업 생성`.
3. Choose a save location in the Android file dialog.

Expected result:

- the system save dialog appears
- the backup completes without an error snackbar
- the saved backup file exists and can be opened or copied afterward

### 3. Backup share

Entry point:

- [settings_screen.dart](d:/Project/01_Personal/MuseArchive/lib/screens/settings_screen.dart#L239)
- [album_repository.dart](d:/Project/01_Personal/MuseArchive/lib/services/album_repository.dart#L631)

Steps:

1. Open Settings.
2. Tap `백업 공유`.
3. Pick a target from the Android share sheet.

Expected result:

- the Android share sheet appears
- a backup file is attached to the selected target
- the app returns without an error snackbar

### 4. Optional restore round trip

Entry point:

- [settings_screen.dart](d:/Project/01_Personal/MuseArchive/lib/screens/settings_screen.dart#L260)
- [album_repository.dart](d:/Project/01_Personal/MuseArchive/lib/services/album_repository.dart#L662)

Steps:

1. Reuse the backup file created above.
2. Tap `백업 복원`.
3. Confirm the warning dialog.
4. Pick the saved backup file.

Expected result:

- restore completes without corruption
- album data and backed-up assets come back correctly
