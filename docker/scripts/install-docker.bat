@echo off
setlocal enabledelayedexpansion

:: Docker Windows Installation Script
:: Usage: install-docker.bat

:: Output text labels (cmd does not support colors)
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"

echo %INFO_PREFIX% Docker Windows Installation Script
echo %INFO_PREFIX% ===================================

:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %WARNING_PREFIX% This script is not running as administrator
    echo %INFO_PREFIX% Some operations may require administrator privileges
    echo %INFO_PREFIX% Recommend running as administrator for best results
    echo.
)

:: Detect architecture
set "ARCH=x64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=ARM64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=ARM64"

echo %INFO_PREFIX% Detected platform: Windows-%ARCH%

:: Check if Docker is installed
set "CURRENT_VERSION=not_installed"
where docker >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('docker --version 2^>nul') do (
        set "CURRENT_VERSION=%%i"
        set "CURRENT_VERSION=!CURRENT_VERSION:,=!"
    )
    if "!CURRENT_VERSION!"=="" set "CURRENT_VERSION=unknown"
    echo %INFO_PREFIX% Current Docker version: !CURRENT_VERSION!
    
    :: Check if Docker is working properly
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Docker is installed and working properly
        goto :verify_installation
    ) else (
        echo %WARNING_PREFIX% Docker is installed but not working properly
        echo %INFO_PREFIX% Docker Desktop may not be running
        echo %INFO_PREFIX% Please start Docker Desktop and try again
    )
) else (
    echo %INFO_PREFIX% Docker is currently not installed
)

:: Check Windows version compatibility
for /f "tokens=2 delims=[]" %%i in ('ver') do set "WIN_VER=%%i"
echo %INFO_PREFIX% Windows version: !WIN_VER!

:: Check if Windows 10/11
echo !WIN_VER! | findstr /C:"10.0" >nul
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% Detected Windows 10/11 - Docker Desktop supported
) else (
    echo %WARNING_PREFIX% Detected older Windows version
    echo %INFO_PREFIX% Docker Desktop requires Windows 10 version 2004 or higher
    echo %INFO_PREFIX% Please check system requirements: https://docs.docker.com/desktop/windows/install/
)

:: Check Hyper-V and WSL2 requirements
echo %INFO_PREFIX% Checking system requirements...

:: Check if Hyper-V is available
dism /online /get-featureinfo /featurename:Microsoft-Hyper-V >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% Hyper-V is available
) else (
    echo %WARNING_PREFIX% Hyper-V may not be available or enabled
    echo %INFO_PREFIX% Docker Desktop can use WSL2 as an alternative
)

:: Check if WSL is installed
wsl --status >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% WSL is installed
    wsl --list --verbose 2>nul | findstr /C:"Ubuntu" >nul
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Found WSL Ubuntu distribution
    ) else (
        echo %INFO_PREFIX% No WSL distributions found, but WSL is available
    )
) else (
    echo %WARNING_PREFIX% WSL is not installed or configured properly
    echo %INFO_PREFIX% Recommend installing WSL2 for better Docker performance
    echo %INFO_PREFIX% Run: wsl --install
)

:: Download and install Docker Desktop
echo.
echo %INFO_PREFIX% Installing Docker Desktop...
echo %INFO_PREFIX% This will download Docker Desktop from the official Docker website

:: Check if curl is available
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% curl is not available
    echo %INFO_PREFIX% Please install curl or manually download Docker Desktop from:
    echo %INFO_PREFIX% https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe
    pause
    exit /b 1
)

:: Create temporary directory
set "TEMP_DIR=%TEMP%\docker-install-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

:: Download Docker Desktop installer
set "INSTALLER_FILE=%TEMP_DIR%\DockerDesktopInstaller.exe"

echo %INFO_PREFIX% Downloading Docker Desktop installer...
curl -L -o "%INSTALLER_FILE%" "https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Failed to download Docker Desktop installer
    echo %INFO_PREFIX% Please manually download from: https://www.docker.com/products/docker-desktop
    rd /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo %SUCCESS_PREFIX% Download completed

:: Run installer
echo %INFO_PREFIX% Running Docker Desktop installer...
echo %INFO_PREFIX% Please follow the installation wizard
echo %WARNING_PREFIX% The installer may require a system restart

start /wait "" "%INSTALLER_FILE%"
set "INSTALL_EXIT_CODE=%errorlevel%"

:: Cleanup
rd /s /q "%TEMP_DIR%" 2>nul

if %INSTALL_EXIT_CODE% equ 0 (
    echo %SUCCESS_PREFIX% Docker Desktop installer completed successfully
) else (
    echo %WARNING_PREFIX% Docker Desktop installer exited with code %INSTALL_EXIT_CODE%
    echo %INFO_PREFIX% This may be normal if installation was successful
)

:verify_installation
echo.
echo %INFO_PREFIX% Verifying installation...

:: Wait for possible system changes
timeout /t 3 /nobreak >nul

:: Check if Docker command is available
where docker >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('docker --version 2^>nul') do (
        set "INSTALLED_VERSION=%%i"
        set "INSTALLED_VERSION=!INSTALLED_VERSION:,=!"
    )
    if "!INSTALLED_VERSION!"=="" set "INSTALLED_VERSION=unknown"
    echo %SUCCESS_PREFIX% Docker version: !INSTALLED_VERSION!
    
    :: Test if Docker daemon is running
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Docker daemon is running
        
        :: Test with hello-world
        echo %INFO_PREFIX% Testing Docker with hello-world container...
        docker run --rm hello-world >nul 2>&1
        if %errorlevel% equ 0 (
            echo %SUCCESS_PREFIX% Docker is working properly
        ) else (
            echo %WARNING_PREFIX% Docker test container failed
            echo %INFO_PREFIX% Docker may need time to fully start up
        )
    ) else (
        echo %WARNING_PREFIX% Docker daemon is not running
        echo %INFO_PREFIX% Please start Docker Desktop from Start menu or desktop
        echo %INFO_PREFIX% Docker Desktop needs to be running to use Docker commands
    )
) else (
    echo %WARNING_PREFIX% Docker command not found
    echo %INFO_PREFIX% Docker Desktop may not be installed correctly
    echo %INFO_PREFIX% Try restarting your computer and running Docker Desktop
)

echo.
echo %SUCCESS_PREFIX% Installation process completed!
echo.
echo %INFO_PREFIX% Next steps:
echo %INFO_PREFIX% 1. If Docker Desktop is not running yet, start it from the Start menu
echo %INFO_PREFIX% 2. Wait for Docker Desktop to complete startup (may take a few minutes)
echo %INFO_PREFIX% 3. Accept any license agreements in Docker Desktop
echo %INFO_PREFIX% 4. Test Docker with this command: docker run hello-world
echo.
echo %INFO_PREFIX% Usage examples:
echo %INFO_PREFIX%   docker --version                      # Check Docker version
echo %INFO_PREFIX%   docker info                           # Show system information
echo %INFO_PREFIX%   docker run hello-world                # Test with hello-world
echo %INFO_PREFIX%   docker run -it ubuntu bash            # Run interactive Ubuntu container
echo %INFO_PREFIX%   docker ps                             # List running containers
echo %INFO_PREFIX%   docker images                         # List images
echo.
echo %INFO_PREFIX% Troubleshooting:
echo %INFO_PREFIX% - If Docker commands don't work, restart your computer
echo %INFO_PREFIX% - Ensure Docker Desktop is running (check system tray)
echo %INFO_PREFIX% - Check Docker Desktop's WSL2 or Hyper-V configuration settings
echo %INFO_PREFIX% - For WSL2 backend: Ensure WSL2 is installed and updated
echo.
echo %INFO_PREFIX% For more information visit: https://docs.docker.com/desktop/windows/

pause
