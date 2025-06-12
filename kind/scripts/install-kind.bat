@echo off
setlocal enabledelayedexpansion

:: Kind Installation/Upgrade Script for Windows
:: Usage: install-kind.bat [version]

:: Default version (latest if not specified)
if "%~1"=="" (
    set "KIND_VERSION=latest"
) else (
    set "KIND_VERSION=%~1"
)

:: Colors are not supported in basic cmd, using text labels instead
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"

echo %INFO_PREFIX% Kind Installation/Upgrade Script for Windows
echo %INFO_PREFIX% ===============================================

:: Detect architecture
set "ARCH=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

echo %INFO_PREFIX% Detected platform: windows-%ARCH%

:: Check if curl is available
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% curl is not available. Please install curl or use Git Bash with the install-kind.sh script.
    pause
    exit /b 1
)

:: Function to get latest version
if "%KIND_VERSION%"=="latest" (
    echo %INFO_PREFIX% Getting latest version...
    for /f "tokens=*" %%i in ('curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest ^| findstr "tag_name" ^| for /f "tokens=2 delims=:," %%j in ("%%i") do @echo %%j ^| tr -d " \"') do set "KIND_VERSION=%%i"
    
    if "!KIND_VERSION!"=="" (
        echo %ERROR_PREFIX% Failed to get latest version
        pause
        exit /b 1
    )
    echo %INFO_PREFIX% Latest version: !KIND_VERSION!
)

:: Check current installation
set "CURRENT_VERSION=not_installed"
where kind >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%i in ('kind version 2^>nul ^| findstr "kind"') do set "CURRENT_VERSION=%%i"
    if "!CURRENT_VERSION!"=="" set "CURRENT_VERSION=unknown"
    echo %INFO_PREFIX% Current kind version: !CURRENT_VERSION!
    
    if "!CURRENT_VERSION!"=="!KIND_VERSION!" (
        echo %SUCCESS_PREFIX% Kind !KIND_VERSION! is already installed
        pause
        exit /b 0
    )
) else (
    echo %INFO_PREFIX% Kind is not currently installed
)

:: Install or upgrade
if "!CURRENT_VERSION!"=="not_installed" (
    echo %INFO_PREFIX% Installing kind !KIND_VERSION!...
) else (
    echo %INFO_PREFIX% Upgrading kind from !CURRENT_VERSION! to !KIND_VERSION!...
)

:: Create download URL
set "DOWNLOAD_URL=https://kind.sigs.k8s.io/dl/!KIND_VERSION!/kind-windows-%ARCH%"

:: Create temp directory
set "TEMP_DIR=%TEMP%\kind-install-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul
set "TEMP_FILE=%TEMP_DIR%\kind.exe"

echo %INFO_PREFIX% Downloading kind !KIND_VERSION! for windows-%ARCH%...

:: Download the binary
curl -L -o "%TEMP_FILE%" "%DOWNLOAD_URL%"
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Failed to download kind
    rd /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

:: Determine installation directory
set "INSTALL_DIR="

:: Try to find a suitable installation directory
if exist "%ProgramFiles%\Git\usr\local\bin" (
    set "INSTALL_DIR=%ProgramFiles%\Git\usr\local\bin"
) else if exist "%USERPROFILE%\.local\bin" (
    set "INSTALL_DIR=%USERPROFILE%\.local\bin"
) else (
    set "INSTALL_DIR=%USERPROFILE%\bin"
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
    echo %WARNING_PREFIX% Installed to %INSTALL_DIR%. Make sure this directory is in your PATH.
)

set "INSTALL_PATH=%INSTALL_DIR%\kind.exe"

:: Move the binary to installation directory
move "%TEMP_FILE%" "%INSTALL_PATH%" >nul
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Failed to install kind to %INSTALL_PATH%
    echo %INFO_PREFIX% You may need to run this script as Administrator
    echo %INFO_PREFIX% Or manually copy %TEMP_FILE% to a directory in your PATH
    pause
    rd /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

:: Clean up
rd /s /q "%TEMP_DIR%" 2>nul

echo %SUCCESS_PREFIX% Kind !KIND_VERSION! installed successfully to %INSTALL_PATH%

:: Verify installation
where kind >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%i in ('kind version 2^>nul ^| findstr "kind"') do set "INSTALLED_VERSION=%%i"
    if "!INSTALLED_VERSION!"=="" set "INSTALLED_VERSION=unknown"
    echo %SUCCESS_PREFIX% Verification: kind version !INSTALLED_VERSION!
) else (
    echo %WARNING_PREFIX% kind command not found in PATH. You may need to restart your command prompt or add %INSTALL_DIR% to your PATH.
)

echo %SUCCESS_PREFIX% Installation completed!
echo.
echo %INFO_PREFIX% Usage examples:
echo %INFO_PREFIX%   kind create cluster                    # Create a cluster
echo %INFO_PREFIX%   kind create cluster --name my-cluster  # Create a named cluster
echo %INFO_PREFIX%   kind get clusters                      # List clusters
echo %INFO_PREFIX%   kind delete cluster                    # Delete default cluster
echo.
echo %INFO_PREFIX% For more information, visit: https://kind.sigs.k8s.io/

pause
