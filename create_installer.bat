@echo off
setlocal enabledelayedexpansion

title Notchpyx - Windows Installer Creator
echo ======================================================================
echo             Notchpyx - Windows Install File Creator
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
    echo [!] Visual Studio C++ Build Tools are required to compile the app.
    echo.
    echo [*] Launching Visual Studio C++ Installer...
    echo     Please click "Yes" when Windows asks for Administrator permission.
    echo     In the installer, make sure "Desktop development with C++" is selected.
    echo.
    if exist "%USERPROFILE%\Downloads\vs_BuildTools.exe" (
        start "" "%USERPROFILE%\Downloads\vs_BuildTools.exe" --passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended
    ) else (
        winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" --accept-package-agreements --accept-source-agreements
    )
    if errorlevel 1 (
        echo.
        echo [X] Could not automatically complete Visual Studio installation.
        echo     Please run "vs_BuildTools.exe" in your Downloads folder to install.
        pause
        exit /b 1
    )
)

echo.
echo ======================================================================
echo   Select Windows Installer Type:
echo   1. Modern Windows 11 App Package (.msix) [Recommended for Windows 11]
echo   2. Standard Setup Wizard (.exe) [Inno Setup]
echo   3. Both (.msix and .exe)
echo ======================================================================
set /p CHOICE="Enter choice (1, 2, or 3, default is 1): "
if "%CHOICE%"=="" set CHOICE=1

echo.
echo [*] Compiling Release Windows binary with Flutter...
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo [X] Flutter Windows build failed.
    pause
    exit /b %errorlevel%
)

if not exist "dist_installer" mkdir "dist_installer"

if "%CHOICE%"=="1" goto BUILD_MSIX
if "%CHOICE%"=="2" goto BUILD_EXE_INSTALLER
if "%CHOICE%"=="3" goto BUILD_BOTH

:BUILD_MSIX
echo.
echo [*] Building Windows MSIX App Installer...
call dart run msix:create
if exist "build\windows\x64\runner\Release\*.msix" (
    copy /y "build\windows\x64\runner\Release\*.msix" "dist_installer\" >nul
)
goto FINISH

:BUILD_EXE_INSTALLER
echo.
echo [*] Building Inno Setup Windows Setup Wizard (.exe)...
where iscc >nul 2>nul
if %errorlevel% equ 0 (
    iscc installer.iss
) else (
    if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" (
        "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" installer.iss
    ) else if exist "%ProgramFiles(x86)%\Inno Setup 6\iscc.exe" (
        "%ProgramFiles(x86)%\Inno Setup 6\iscc.exe" installer.iss
    ) else (
        echo [!] Inno Setup compiler (iscc) not found.
        echo     Please install Inno Setup 6 to compile the .exe installer.
    )
)
goto FINISH

:BUILD_BOTH
echo.
echo [*] Building Windows MSIX Package...
call dart run msix:create
if exist "build\windows\x64\runner\Release\*.msix" (
    copy /y "build\windows\x64\runner\Release\*.msix" "dist_installer\" >nul
)
echo.
echo [*] Building Inno Setup Setup.exe...
where iscc >nul 2>nul
if %errorlevel% equ 0 (
    iscc installer.iss
) else if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" (
    "%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe" installer.iss
)
goto FINISH

:FINISH
echo.
echo ======================================================================
echo                      INSTALLER CREATION COMPLETED!
echo ======================================================================
echo.
echo Your install files are ready in: %CD%\dist_installer\
dir dist_installer
echo.
explorer "%CD%\dist_installer"
pause
