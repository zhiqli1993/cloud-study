@echo off
setlocal enabledelayedexpansion

:: Istio Installation/Upgrade Script for Windows
:: Usage: install-istio.bat [version] [profile]

:: Default values
if "%~1"=="" (
    set "ISTIO_VERSION=latest"
) else (
    set "ISTIO_VERSION=%~1"
)

if "%~2"=="" (
    set "ISTIO_PROFILE=default"
) else (
    set "ISTIO_PROFILE=%~2"
)

:: Colors are not supported in basic cmd, using text labels instead
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"

echo %INFO_PREFIX% Istio Installation Script for Windows
echo %INFO_PREFIX% =========================================

:: Detect architecture
set "ARCH=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

echo %INFO_PREFIX% Detected platform: win-%ARCH%

:: Check if curl is available
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% curl is not available. Please install curl or use Git Bash with the install-istio.sh script.
    pause
    exit /b 1
)

:: Check if tar is available
where tar >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% tar is not available. Please install tar or use Git Bash with the install-istio.sh script.
    pause
    exit /b 1
)

:: Function to get latest version
if "%ISTIO_VERSION%"=="latest" (
    echo %INFO_PREFIX% Getting latest version...
    for /f "delims=" %%i in ('curl -s https://api.github.com/repos/istio/istio/releases/latest') do (
        echo %%i | findstr "tag_name" >nul
        if !errorlevel! equ 0 (
            for /f "tokens=2 delims=:" %%j in ("%%i") do (
                for /f "tokens=1 delims=," %%k in ("%%j") do (
                    set "ISTIO_VERSION=%%k"
                    set "ISTIO_VERSION=!ISTIO_VERSION: =!"
                    set "ISTIO_VERSION=!ISTIO_VERSION:"=!"
                )
            )
        )
    )
    
    if "!ISTIO_VERSION!"=="latest" (
        echo %ERROR_PREFIX% Failed to get latest version
        pause
        exit /b 1
    )
    echo %INFO_PREFIX% Latest version: !ISTIO_VERSION!
)

:: Check current installation
set "CURRENT_VERSION=not_installed"
where istioctl >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('istioctl version --client --short 2^>nul') do (
        for /f "tokens=1,2,3 delims=." %%a in ("%%i") do (
            if "%%a" neq "" if "%%b" neq "" if "%%c" neq "" (
                set "CURRENT_VERSION=%%a.%%b.%%c"
            )
        )
    )
    if "!CURRENT_VERSION!"=="not_installed" set "CURRENT_VERSION=unknown"
    echo %INFO_PREFIX% Current istioctl version: !CURRENT_VERSION!
    
    :: Normalize version strings for comparison (remove 'v' prefix if present)
    set "NORMALIZED_CURRENT=!CURRENT_VERSION!"
    set "NORMALIZED_TARGET=!ISTIO_VERSION!"
    if "!NORMALIZED_CURRENT:~0,1!"=="v" set "NORMALIZED_CURRENT=!NORMALIZED_CURRENT:~1!"
    if "!NORMALIZED_TARGET:~0,1!"=="v" set "NORMALIZED_TARGET=!NORMALIZED_TARGET:~1!"
    
    if "!NORMALIZED_CURRENT!"=="!NORMALIZED_TARGET!" (
        echo %SUCCESS_PREFIX% istioctl !ISTIO_VERSION! is already installed and up to date
        goto :ask_cluster_install
    ) else (
        echo %INFO_PREFIX% Upgrading istioctl from !CURRENT_VERSION! to !ISTIO_VERSION!
    )
) else (
    echo %INFO_PREFIX% istioctl is not currently installed
)

:: Install or upgrade only if versions don't match
set "NORMALIZED_CURRENT=!CURRENT_VERSION!"
set "NORMALIZED_TARGET=!ISTIO_VERSION!"
if "!NORMALIZED_CURRENT:~0,1!"=="v" set "NORMALIZED_CURRENT=!NORMALIZED_CURRENT:~1!"
if "!NORMALIZED_TARGET:~0,1!"=="v" set "NORMALIZED_TARGET=!NORMALIZED_TARGET:~1!"

if "!CURRENT_VERSION!"=="not_installed" (
    echo %INFO_PREFIX% Installing istioctl !ISTIO_VERSION!...
) else if "!NORMALIZED_CURRENT!" neq "!NORMALIZED_TARGET!" (
    echo %INFO_PREFIX% Upgrading istioctl from !CURRENT_VERSION! to !ISTIO_VERSION!...
) else (
    goto :ask_cluster_install
)

:: Create download URL
:: Remove 'v' prefix if present for the download URL
set "VERSION_NUMBER=!ISTIO_VERSION!"
if "!VERSION_NUMBER:~0,1!"=="v" set "VERSION_NUMBER=!VERSION_NUMBER:~1!"
set "DOWNLOAD_URL=https://github.com/istio/istio/releases/download/!ISTIO_VERSION!/istio-!VERSION_NUMBER!-win-!ARCH!.zip"

:: Create temp directory
set "TEMP_DIR=%TEMP%\istio-install-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul
set "TEMP_ARCHIVE=%TEMP_DIR%\istio.zip"

echo %INFO_PREFIX% Downloading Istio !ISTIO_VERSION! for win-!ARCH!...
echo %INFO_PREFIX% Download URL: !DOWNLOAD_URL!

:: Download the archive
curl -L -o "%TEMP_ARCHIVE%" "%DOWNLOAD_URL%"
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Failed to download Istio
    rd /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

:: Extract the archive
echo %INFO_PREFIX% Extracting Istio archive...
cd /d "%TEMP_DIR%"
powershell -command "Expand-Archive -Path '%TEMP_ARCHIVE%' -DestinationPath '%TEMP_DIR%' -Force"
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Failed to extract Istio archive
    cd /d "%~dp0"
    rd /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

:: Find the istioctl binary
set "ISTIO_DIR=%TEMP_DIR%\istio-!VERSION_NUMBER!"
set "ISTIOCTL_PATH=%ISTIO_DIR%\bin\istioctl.exe"

if not exist "%ISTIOCTL_PATH%" (
    echo %ERROR_PREFIX% istioctl.exe not found in downloaded archive
    cd /d "%~dp0"
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

set "INSTALL_PATH=%INSTALL_DIR%\istioctl.exe"

:: Copy the binary to installation directory
copy "%ISTIOCTL_PATH%" "%INSTALL_PATH%" >nul
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Failed to install istioctl to %INSTALL_PATH%
    echo %INFO_PREFIX% You may need to run this script as Administrator
    echo %INFO_PREFIX% Or manually copy %ISTIOCTL_PATH% to a directory in your PATH
    cd /d "%~dp0"
    rd /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

:: Clean up
cd /d "%~dp0"
rd /s /q "%TEMP_DIR%" 2>nul

echo %SUCCESS_PREFIX% istioctl !ISTIO_VERSION! installed successfully to %INSTALL_PATH%

:: Verify installation
where istioctl >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('istioctl version --short 2^>nul') do (
        for /f "tokens=1,2,3 delims=." %%a in ("%%i") do (
            if "%%a" neq "" if "%%b" neq "" if "%%c" neq "" (
                set "INSTALLED_VERSION=%%a.%%b.%%c"
            )
        )
    )
    if "!INSTALLED_VERSION!"=="" set "INSTALLED_VERSION=unknown"
    echo %SUCCESS_PREFIX% Verification: istioctl version !INSTALLED_VERSION!
) else (
    echo %WARNING_PREFIX% istioctl command not found in PATH. You may need to restart your command prompt or add %INSTALL_DIR% to your PATH.
)

:ask_cluster_install
:: Ask if user wants to install Istio to cluster
echo.
set /p "REPLY=Do you want to install Istio to your Kubernetes cluster now? (y/N): "
if /i "!REPLY!"=="y" (
    goto :install_to_cluster
) else if /i "!REPLY!"=="yes" (
    goto :install_to_cluster
) else (
    echo %INFO_PREFIX% Skipping cluster installation. You can install Istio to your cluster later using:
    echo %INFO_PREFIX%   istioctl install --set values.defaultRevision=default -y
    goto :show_usage
)

:install_to_cluster
echo %INFO_PREFIX% Installing Istio to Kubernetes cluster with profile: !ISTIO_PROFILE!

:: Check if kubectl is available
where kubectl >nul 2>&1
if %errorlevel% neq 0 (
    echo %WARNING_PREFIX% kubectl is not installed. You'll need kubectl to deploy Istio to a Kubernetes cluster.
    echo %INFO_PREFIX% You can install kubectl from: https://kubernetes.io/docs/tasks/tools/
    goto :show_usage
)

:: Check if cluster is accessible
kubectl cluster-info >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Cannot connect to Kubernetes cluster. Please check your kubectl configuration.
    goto :show_usage
)

:: Install Istio
echo %INFO_PREFIX% Running: istioctl install --set values.defaultRevision=default -y
istioctl install --set values.defaultRevision=default -y
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% Istio installed successfully to the cluster
) else (
    echo %ERROR_PREFIX% Failed to install Istio to the cluster
    goto :show_usage
)

:: Label the default namespace for Istio injection
echo %INFO_PREFIX% Enabling automatic sidecar injection for default namespace...
kubectl label namespace default istio-injection=enabled --overwrite
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% Automatic sidecar injection enabled for default namespace
) else (
    echo %WARNING_PREFIX% Failed to enable automatic sidecar injection for default namespace
)

:: Verify installation
echo %INFO_PREFIX% Verifying Istio installation...
istioctl verify-install
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% Istio installation verified successfully
) else (
    echo %WARNING_PREFIX% Istio installation verification failed
)

:show_usage
echo %SUCCESS_PREFIX% Installation completed!
echo.
echo %INFO_PREFIX% istioctl is now installed! Here are some usage examples:
echo.
echo %INFO_PREFIX% Basic Commands:
echo %INFO_PREFIX%   istioctl version                      # Show version information
echo %INFO_PREFIX%   istioctl install --set values.defaultRevision=default -y  # Install Istio to cluster
echo %INFO_PREFIX%   istioctl uninstall --purge -y         # Uninstall Istio from cluster
echo %INFO_PREFIX%   istioctl verify-install               # Verify Istio installation
echo.
echo %INFO_PREFIX% Configuration:
echo %INFO_PREFIX%   istioctl proxy-config cluster ^<pod^>   # Show cluster configuration
echo %INFO_PREFIX%   istioctl proxy-status                 # Show proxy status
echo %INFO_PREFIX%   istioctl analyze                      # Analyze configuration
echo.
echo %INFO_PREFIX% Traffic Management:
echo %INFO_PREFIX%   kubectl label namespace default istio-injection=enabled  # Enable sidecar injection
echo %INFO_PREFIX%   kubectl apply -f ^<your-app.yaml^>      # Deploy application with sidecars
echo.
echo %INFO_PREFIX% For more information, visit: https://istio.io/latest/docs/

pause
