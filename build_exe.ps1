# Notchpyx - Windows Executable (.exe) Builder
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "            Notchpyx - Windows Executable (.exe) Builder              " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsFound = $false

if (Test-Path $vswhere) {
    $installPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($installPath -and (Test-Path $installPath)) {
        $vsFound = $true
    }
}

if (-not $vsFound) {
    Write-Host "[!] Visual Studio C++ toolchain not found." -ForegroundColor Yellow
    Write-Host "    Flutter requires 'Desktop development with C++' to build Windows .exe binaries." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[*] Launching automated installation via winget..." -ForegroundColor Cyan
    Write-Host "    (Please click YES on the Windows Administrator / UAC prompt if prompted)" -ForegroundColor Magenta
    Write-Host ""

    $wingetArgs = @(
        "install",
        "--id", "Microsoft.VisualStudio.2022.BuildTools",
        "--override", "'--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )

    $process = Start-Process winget -ArgumentList $wingetArgs -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host ""
        Write-Host "[X] Automated installation did not complete." -ForegroundColor Red
        Write-Host "    Please install Visual Studio with 'Desktop development with C++' manually from:" -ForegroundColor Yellow
        Write-Host "    https://visualstudio.microsoft.com/downloads/" -ForegroundColor Green
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "[*] Compiling Release Windows executable with Flutter..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Flutter build failed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit $LASTEXITCODE
}

$releaseSrc = "build\windows\x64\runner\Release"
$distDir = "dist"

if (Test-Path "$releaseSrc\DynamicBar.exe") {
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "                           BUILD SUCCESSFUL!                          " -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[*] Copying standalone application to '$distDir\'..." -ForegroundColor Cyan
    if (-not (Test-Path $distDir)) {
        New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    }
    Copy-Item -Path "$releaseSrc\*" -Destination $distDir -Recurse -Force
    
    $exePath = (Resolve-Path "$distDir\DynamicBar.exe").Path
    Write-Host "[*] Executable created successfully at:" -ForegroundColor Green
    Write-Host "    $exePath" -ForegroundColor White
    Write-Host ""
    
    Invoke-Item $distDir
} else {
    Write-Host "[*] Release output located in $releaseSrc" -ForegroundColor Green
}

Read-Host "Press Enter to finish"
