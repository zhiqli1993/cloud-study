@echo off
setlocal enabledelayedexpansion

:: Istio Uninstallation Script for Windows
:: Usage: uninstall-istio.bat [--purge]

:: Parse arguments
set "PURGE_MODE=false"
if "%~1"=="--purge" set "PURGE_MODE=true"

:: Colors are not supported in basic cmd, using text labels instead
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"

echo %INFO_PREFIX% Istio Uninstallation Script for Windows
echo %INFO_PREFIX% ==========================================

if "%PURGE_MODE%"=="true" (
    echo %WARNING_PREFIX% Running in PURGE mode - this will remove ALL Istio resources
)

:: Detect architecture
set "ARCH=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

echo %INFO_PREFIX% Detected platform: win-%ARCH%

:: Check if istioctl is installed
set "ISTIOCTL_INSTALLED=false"
where istioctl >nul 2>&1
if %errorlevel% equ 0 (
    set "ISTIOCTL_INSTALLED=true"
    for /f "tokens=*" %%i in ('istioctl version --short 2^>nul') do (
        for /f "tokens=1,2,3 delims=." %%a in ("%%i") do (
            if "%%a" neq "" if "%%b" neq "" if "%%c" neq "" (
                set "CURRENT_VERSION=%%a.%%b.%%c"
            )
        )
    )
    if "!CURRENT_VERSION!"=="" set "CURRENT_VERSION=unknown"
    echo %INFO_PREFIX% Current istioctl version: !CURRENT_VERSION!
) else (
    echo %WARNING_PREFIX% istioctl is not installed or not in PATH
)

:: Ask for confirmation
echo.
echo %WARNING_PREFIX% This will uninstall Istio from your system and cluster.
if "%PURGE_MODE%"=="true" (
    echo %WARNING_PREFIX% PURGE mode will remove ALL Istio resources including CRDs!
)
echo.
set /p "CONFIRM=Are you sure you want to continue? (y/N): "
if /i "!CONFIRM!" neq "y" if /i "!CONFIRM!" neq "yes" (
    echo %INFO_PREFIX% Uninstallation cancelled.
    pause
    exit /b 0
)

:: Check if kubectl is available
set "KUBECTL_AVAILABLE=false"
where kubectl >nul 2>&1
if %errorlevel% equ 0 (
    set "KUBECTL_AVAILABLE=true"
) else (
    echo %WARNING_PREFIX% kubectl is not installed. Cannot uninstall Istio from cluster.
)

:: Uninstall from cluster if both kubectl and istioctl are available
if "%KUBECTL_AVAILABLE%"=="true" if "%ISTIOCTL_INSTALLED%"=="true" (
    echo.
    set /p "CLUSTER_UNINSTALL=Do you want to uninstall Istio from your Kubernetes cluster? (Y/n): "
    if /i "!CLUSTER_UNINSTALL!" neq "n" if /i "!CLUSTER_UNINSTALL!" neq "no" (
        call :uninstall_from_cluster
    ) else (
        echo %INFO_PREFIX% Skipping cluster uninstallation
    )
) else (
    echo %WARNING_PREFIX% Skipping cluster uninstallation (kubectl or istioctl not available)
)

:: Remove istioctl binary
echo.
set /p "REMOVE_BINARY=Do you want to remove the istioctl binary? (Y/n): "
if /i "!REMOVE_BINARY!" neq "n" if /i "!REMOVE_BINARY!" neq "no" (
    call :remove_istioctl_binary
) else (
    echo %INFO_PREFIX% Keeping istioctl binary
)

:: Clean up configuration if purge mode
if "%PURGE_MODE%"=="true" (
    call :cleanup_istioctl_config
)

echo.
echo %SUCCESS_PREFIX% Uninstallation completed!
echo.
echo %INFO_PREFIX% If you want to reinstall Istio later, you can use:
echo %INFO_PREFIX%   install-istio.bat
echo.
echo %INFO_PREFIX% For more information, visit: https://istio.io/latest/docs/

pause
exit /b 0

:: Function to uninstall Istio from cluster
:uninstall_from_cluster
echo %INFO_PREFIX% Uninstalling Istio from Kubernetes cluster...

:: Check if cluster is accessible
kubectl cluster-info >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% Cannot connect to Kubernetes cluster. Please check your kubectl configuration.
    goto :eof
)

:: Check if Istio is installed in the cluster
kubectl get namespace istio-system >nul 2>&1
if %errorlevel% neq 0 (
    echo %WARNING_PREFIX% Istio system namespace not found. Istio may not be installed in this cluster.
) else (
    echo %INFO_PREFIX% Found Istio installation in cluster
    
    :: Uninstall Istio
    if "%PURGE_MODE%"=="true" (
        echo %INFO_PREFIX% Running: istioctl uninstall --purge -y
        istioctl uninstall --purge -y
        if !errorlevel! equ 0 (
            echo %SUCCESS_PREFIX% Istio uninstalled successfully (purge mode)
        ) else (
            echo %ERROR_PREFIX% Failed to uninstall Istio from cluster
            goto :eof
        )
    ) else (
        echo %INFO_PREFIX% Running: istioctl uninstall -y
        istioctl uninstall -y
        if !errorlevel! equ 0 (
            echo %SUCCESS_PREFIX% Istio uninstalled successfully
        ) else (
            echo %ERROR_PREFIX% Failed to uninstall Istio from cluster
            goto :eof
        )
    )
)

:: Remove istio-injection labels from namespaces
echo %INFO_PREFIX% Removing istio-injection labels from namespaces...
for /f "tokens=*" %%i in ('kubectl get namespaces -l istio-injection=enabled -o jsonpath="{.items[*].metadata.name}" 2^>nul') do (
    set "LABELED_NAMESPACES=%%i"
)

if defined LABELED_NAMESPACES (
    for %%ns in (!LABELED_NAMESPACES!) do (
        echo %INFO_PREFIX% Removing istio-injection label from namespace: %%ns
        kubectl label namespace %%ns istio-injection- >nul 2>&1
    )
    echo %SUCCESS_PREFIX% Removed istio-injection labels from namespaces
) else (
    echo %INFO_PREFIX% No namespaces with istio-injection labels found
)

:: Clean up remaining resources if purge mode
if "%PURGE_MODE%"=="true" (
    echo %INFO_PREFIX% Cleaning up remaining Istio resources...
    
    :: Remove Istio CRDs
    echo %INFO_PREFIX% Removing Istio CRDs...
    for /f "tokens=*" %%i in ('kubectl get crd -o name 2^>nul ^| findstr /R "istio\.io maistra\.io"') do (
        kubectl delete %%i >nul 2>&1
    )
    
    :: Remove Istio namespaces
    for %%ns in (istio-system istio-operator) do (
        kubectl get namespace %%ns >nul 2>&1
        if !errorlevel! equ 0 (
            echo %INFO_PREFIX% Removing namespace: %%ns
            kubectl delete namespace %%ns --timeout=60s >nul 2>&1
        )
    )
    
    echo %SUCCESS_PREFIX% Purge cleanup completed
)

goto :eof

:: Function to remove istioctl binary
:remove_istioctl_binary
echo %INFO_PREFIX% Removing istioctl binary...

:: Find istioctl location
for /f "tokens=*" %%i in ('where istioctl 2^>nul') do (
    set "ISTIOCTL_PATH=%%i"
    goto :found_istioctl
)

echo %WARNING_PREFIX% istioctl binary not found in PATH
goto :eof

:found_istioctl
echo %INFO_PREFIX% Found istioctl at: !ISTIOCTL_PATH!

:: Try to remove the binary
del "!ISTIOCTL_PATH!" >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% istioctl binary removed successfully
) else (
    echo %ERROR_PREFIX% Failed to remove istioctl binary at !ISTIOCTL_PATH!
    echo %INFO_PREFIX% You may need to run this script as Administrator
    echo %INFO_PREFIX% Or manually delete !ISTIOCTL_PATH!
)

goto :eof

:: Function to clean up istioctl configuration
:cleanup_istioctl_config
echo %INFO_PREFIX% Cleaning up istioctl configuration...

:: Remove istioctl config directories if they exist
set "CONFIG_DIRS=%USERPROFILE%\.istioctl %USERPROFILE%\.config\istio"

for %%dir in (!CONFIG_DIRS!) do (
    if exist "%%dir" (
        echo %INFO_PREFIX% Removing configuration directory: %%dir
        rd /s /q "%%dir" >nul 2>&1
        if !errorlevel! equ 0 (
            echo %SUCCESS_PREFIX% Removed %%dir
        ) else (
            echo %WARNING_PREFIX% Failed to remove %%dir
        )
    )
)

goto :eof
