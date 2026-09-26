@echo off
setlocal
chcp 65001 >nul

for %%I in ("%~dp0.") do set "PROJECT_ROOT=%%~fI"
set "APK_PATH=%PROJECT_ROOT%\build\app\outputs\flutter-apk\app-release.apk"
set "NO_PAUSE="
set "PUSHD_SUCCEEDED="

if /I "%~1"=="--no-pause" set "NO_PAUSE=1"

pushd "%PROJECT_ROOT%" >nul 2>&1
if errorlevel 1 (
    echo [실패] 프로젝트 폴더로 이동할 수 없습니다.
    echo        %PROJECT_ROOT%
    set "BUILD_EXIT_CODE=1"
    goto :finish
)
set "PUSHD_SUCCEEDED=1"

echo.
echo ========================================
echo  MuseArchive Android Release APK 빌드
echo ========================================
echo 프로젝트: %PROJECT_ROOT%
echo.

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [실패] Windows PowerShell을 찾을 수 없습니다.
    echo        PowerShell을 설치하거나 PATH 설정을 확인해 주세요.
    set "BUILD_EXIT_CODE=1"
    goto :finish
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\android\Invoke-AndroidReleaseWorkflow.ps1" -ProjectRoot "%PROJECT_ROOT%"
set "BUILD_EXIT_CODE=%ERRORLEVEL%"

if not "%BUILD_EXIT_CODE%"=="0" (
    echo.
    echo [실패] Android release APK 빌드에 실패했습니다. 종료 코드: %BUILD_EXIT_CODE%
    echo        위 오류 메시지를 확인한 뒤 다시 실행해 주세요.
    goto :finish
)

if not exist "%APK_PATH%" (
    echo.
    echo [실패] 빌드는 종료되었지만 APK 파일을 찾을 수 없습니다.
    echo        예상 경로: %APK_PATH%
    set "BUILD_EXIT_CODE=1"
    goto :finish
)

echo.
echo [성공] Android release APK를 생성했습니다.
echo        %APK_PATH%
set "BUILD_EXIT_CODE=0"

:finish
if defined NO_PAUSE goto :cleanup
echo.
pause

:cleanup
if defined PUSHD_SUCCEEDED popd >nul 2>&1
exit /b %BUILD_EXIT_CODE%
