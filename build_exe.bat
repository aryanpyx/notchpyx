@echo off
setlocal enabledelayedexpansion

title Notchpyx - Build Windows Executable
echo ======================================================================
echo             Notchpyx - Windows Executable (.exe) Builder
echo ======================================================================
echo.

:: 1. Check for Visual Studio toolchain
set "VS_FOUND=0"
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        if exist "%%i" set "VS_FOUND=1"
    )
)

if "%VS_FOUND%"=="0" (
    echo [!] Visual Studio C++ build tools were not detected.
    echo     Flutter requires the "Desktop development with C++" workload to compile
    echo     native Windows apps (.exe).
    echo.
    echo [*] Attempting automated installation via winget...
    echo     (Please click YES on any Windows Administrator/UAC prompt that appears)
    echo.
    winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo [X] Automated install was not completed.
        echo     You can install Visual Studio Community / Build Tools manually from:
        echo     https://visualstudio.microsoft.com/downloads/
        echo     Make sure to select: "Desktop development with C++"
        echo.
        pause
        exit /b 1
    )
)

echo.
echo [*] Dependencies verified. Building Release Windows binary...
echo.
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo [X] Build failed. Please check the logs above.
    pause
    exit /b %errorlevel%
)

echo.
echo ======================================================================
echo                           BUILD SUCCESSFUL!
echo ======================================================================
echo.

set "RELEASE_SRC=build\windows\x64\runner\Release"
set "DIST_DIR=dist"

if exist "%RELEASE_SRC%\DynamicBar.exe" (
    echo [*] Packaging standalone application into "%DIST_DIR%\"...
    if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
    xcopy /E /I /Y "%RELEASE_SRC%\*" "%DIST_DIR%\" >nul
    
    echo.
    echo [*] Executable is ready:
    echo     Path: %CD%\%DIST_DIR%\DynamicBar.exe
    echo.
    echo Opening folder...
    explorer "%CD%\%DIST_DIR%"
) else (
    echo Executable generated in: %RELEASE_SRC%
)

echo.
pause
