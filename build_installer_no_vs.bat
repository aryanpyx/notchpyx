@echo off
setlocal enabledelayedexpansion

title Notchpyx - Windows Installer Builder (Zero Visual Studio)
echo ======================================================================
echo    Notchpyx - Windows Installer Builder (No Visual Studio Required)
echo ======================================================================
echo.

echo [*] Compiling Windows Setup Installer with Inno Setup...
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" (
    "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" installer.iss
) else (
    iscc installer.iss
)

if errorlevel 1 (
    echo [X] Inno Setup compilation failed.
    pause
    exit /b %errorlevel%
)

echo.
echo ======================================================================
echo                      INSTALLER CREATED SUCCESSFULLY!
echo ======================================================================
echo.
echo Setup File: %CD%\dist_installer\Notchpyx_Setup_v1.0.0.exe
echo.
explorer "%CD%\dist_installer"
pause
