@echo off
setlocal EnableExtensions

set "FFUI_ROOT=%~dp0.."
for %%I in ("%FFUI_ROOT%") do set "FFUI_ROOT=%%~fI"
set "FFUI_SOURCE=%FFUI_ROOT%\build\windows\x64\runner\Release"
set "FFUI_EXPORT=%FFUI_ROOT%\export\FFmpeg_UI-Windows"
set "FFUI_MANIFEST_DIRECTORY=%FFUI_ROOT%\build\release-manifests"

for /f "tokens=2 delims=+ " %%A in ('findstr /b /c:"version:" "%FFUI_ROOT%\pubspec.yaml"') do set "FFUI_VERSION=%%A"
if "%FFUI_VERSION%"=="" (
  echo Blad: nie udalo sie odczytac wersji z pubspec.yaml.
  exit /b 1
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo Blad: nie znaleziono Fluttera w PATH.
  exit /b 1
)

cd /d "%FFUI_ROOT%"
call flutter pub get
if errorlevel 1 exit /b 1

call flutter analyze
if errorlevel 1 exit /b 1

call flutter test
if errorlevel 1 exit /b 1

call flutter build windows --release
if errorlevel 1 exit /b 1

if not exist "%FFUI_SOURCE%\ffmpeg_ui.exe" (
  echo Blad: nie znaleziono zbudowanego ffmpeg_ui.exe.
  exit /b 1
)

if exist "%FFUI_EXPORT%" rmdir /s /q "%FFUI_EXPORT%"
mkdir "%FFUI_EXPORT%"
xcopy "%FFUI_SOURCE%\*" "%FFUI_EXPORT%\" /e /i /h /y >nul
if errorlevel 1 exit /b 1
mkdir "%FFUI_EXPORT%\skrypty"
if errorlevel 1 exit /b 1
if not exist "%FFUI_MANIFEST_DIRECTORY%" mkdir "%FFUI_MANIFEST_DIRECTORY%"
if errorlevel 1 exit /b 1
>"%FFUI_MANIFEST_DIRECTORY%\windows.version" echo %FFUI_VERSION%

echo.
echo Gotowe:
echo   %FFUI_EXPORT%\ffmpeg_ui.exe
echo   %FFUI_EXPORT%\skrypty\  ^(add your .sh workflow files here^)
echo   metadane wersji buildu poza export: %FFUI_VERSION%
echo.
echo Nie usuwaj bibliotek DLL ani katalogu data - sa wymagane przez Flutter.
exit /b 0
