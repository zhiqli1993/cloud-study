@echo off
setlocal enabledelayedexpansion

:: Kind Uninstall Script for Windows
:: Usage: uninstall-kind.bat

:: Colors are not supported in basic cmd, using text labels instead
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"

echo %INFO_PREFIX% Kind Uninstall Script for Windows
echo %INFO_PREFIX% ===================================
echo.
echo %WARNING_PREFIX% This script will help you remove kind and its associated resources.
echo %WARNING_PREFIX% Please make sure you have backed up any important data.
echo.

:: Detect architecture
set "ARCH=amd64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=arm64"

echo %INFO_PREFIX% Detected platform: windows-%ARCH%

:: Check if kind is installed
where kind >nul 2>&1
if %errorlevel% neq 0 (
    echo %INFO_PREFIX% Kind is not installed or not found in PATH
    pause
    exit /b 0
)

:: Get kind installation path
for /f "tokens=*" %%i in ('where kind 2^>nul') do set "KIND_PATH=%%i"

:: Get current version
set "CURRENT_VERSION=unknown"
for /f "tokens=2" %%i in ('kind version 2^>nul ^| findstr "kind"') do set "CURRENT_VERSION=%%i"
if "!CURRENT_VERSION!"=="" set "CURRENT_VERSION=unknown"

echo %INFO_PREFIX% Found kind installation: !KIND_PATH!
echo %INFO_PREFIX% Current kind version: !CURRENT_VERSION!
echo.

:: Confirm uninstallation
set /p "CONFIRM=Do you want to proceed with kind uninstallation? [y/N]: "
if /i not "!CONFIRM!"=="y" (
    echo %INFO_PREFIX% Uninstallation cancelled
    pause
    exit /b 0
)

echo.
echo %INFO_PREFIX% Starting uninstallation process...
echo.

:: Remove clusters first
echo %INFO_PREFIX% Checking for existing kind clusters...
set "CLUSTERS_FOUND=false"
for /f "tokens=*" %%i in ('kind get clusters 2^>nul') do (
    if not "%%i"=="" (
        set "CLUSTERS_FOUND=true"
        echo %WARNING_PREFIX% Found cluster: %%i
    )
)

if "!CLUSTERS_FOUND!"=="true" (
    echo.
    set /p "DELETE_CLUSTERS=Do you want to delete all kind clusters? [y/N]: "
    if /i "!DELETE_CLUSTERS!"=="y" (
        echo %INFO_PREFIX% Deleting kind clusters...
        for /f "tokens=*" %%i in ('kind get clusters 2^>nul') do (
            if not "%%i"=="" (
                echo %INFO_PREFIX% Deleting cluster: %%i
                kind delete cluster --name "%%i" >nul 2>&1
            )
        )
        echo %SUCCESS_PREFIX% All kind clusters deleted
    ) else (
        echo %WARNING_PREFIX% Skipping cluster deletion
    )
) else (
    echo %INFO_PREFIX% No kind clusters found
)

echo.

:: Cleanup Docker networks
where docker >nul 2>&1
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% Cleaning up Docker networks created by kind...
    
    set "NETWORKS_FOUND=false"
    for /f "tokens=*" %%i in ('docker network ls --filter name^=kind --format "{{.Name}}" 2^>nul') do (
        if not "%%i"=="" (
            set "NETWORKS_FOUND=true"
            echo %INFO_PREFIX% Removing Docker network: %%i
            docker network rm "%%i" >nul 2>&1
        )
    )
    
    if "!NETWORKS_FOUND!"=="true" (
        echo %SUCCESS_PREFIX% Docker network cleanup completed
    ) else (
        echo %INFO_PREFIX% No kind Docker networks found
    )
) else (
    echo %WARNING_PREFIX% Docker not found, skipping network cleanup
)

echo.

:: Remove kind binary
echo %INFO_PREFIX% Found kind installation: !KIND_PATH!
echo.
set /p "REMOVE_BINARY=Do you want to remove the kind binary? [y/N]: "
if /i "!REMOVE_BINARY!"=="y" (
    del "!KIND_PATH!" >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Kind binary removed: !KIND_PATH!
    ) else (
        echo %ERROR_PREFIX% Failed to remove kind binary: !KIND_PATH!
        echo %INFO_PREFIX% You may need to run this script as Administrator
        echo %INFO_PREFIX% Or manually delete the file: !KIND_PATH!
        goto :verify
    )
) else (
    echo %WARNING_PREFIX% Skipping binary removal
)

echo.

:: Remove kind configuration directory
set "CONFIG_DIR=%USERPROFILE%\.kind"
if exist "!CONFIG_DIR!" (
    echo %INFO_PREFIX% Found kind configuration directory: !CONFIG_DIR!
    echo.
    set /p "REMOVE_CONFIG=Do you want to remove kind configuration directory? [y/N]: "
    if /i "!REMOVE_CONFIG!"=="y" (
        rd /s /q "!CONFIG_DIR!" >nul 2>&1
        if %errorlevel% equ 0 (
            echo %SUCCESS_PREFIX% Kind configuration directory removed: !CONFIG_DIR!
        ) else (
            echo %ERROR_PREFIX% Failed to remove kind configuration directory: !CONFIG_DIR!
            echo %INFO_PREFIX% Manual removal: rd /s /q "!CONFIG_DIR!"
        )
    ) else (
        echo %WARNING_PREFIX% Skipping configuration directory removal
    )
) else (
    echo %INFO_PREFIX% No kind configuration directory found
)

echo.

:verify
:: Verify uninstallation
echo %INFO_PREFIX% Verifying uninstallation...

where kind >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where kind 2^>nul') do set "REMAINING_PATH=%%i"
    echo %WARNING_PREFIX% Kind binary still found at: !REMAINING_PATH!
    echo %WARNING_PREFIX% Uninstallation may be incomplete
) else (
    echo %SUCCESS_PREFIX% Kind binary successfully removed from PATH
)

:: Check for remaining containers and images
where docker >nul 2>&1
if %errorlevel% equ 0 (
    set "CONTAINERS_FOUND=false"
    for /f "tokens=*" %%i in ('docker ps -a --filter name^=kind --format "{{.Names}}" 2^>nul') do (
        if not "%%i"=="" (
            set "CONTAINERS_FOUND=true"
            if not defined CONTAINER_LIST (
                echo %WARNING_PREFIX% Found remaining kind containers:
                set "CONTAINER_LIST=true"
            )
            echo   %%i
        )
    )
    if "!CONTAINERS_FOUND!"=="true" (
        echo %INFO_PREFIX% You may want to remove them manually with: docker rm -f ^<container_name^>
    )
    
    set "IMAGES_FOUND=false"
    for /f "tokens=*" %%i in ('docker images --filter reference^="kindest/*" --format "{{.Repository}}:{{.Tag}}" 2^>nul') do (
        if not "%%i"=="" (
            set "IMAGES_FOUND=true"
            if not defined IMAGE_LIST (
                echo %WARNING_PREFIX% Found remaining kind images:
                set "IMAGE_LIST=true"
            )
            echo   %%i
        )
    )
    if "!IMAGES_FOUND!"=="true" (
        echo %INFO_PREFIX% You may want to remove them manually with: docker rmi ^<image_name^>
    )
)

echo.
echo %SUCCESS_PREFIX% Kind uninstallation completed!
echo.
echo %INFO_PREFIX% Note: Docker images used by kind clusters may still exist.
echo %INFO_PREFIX% You can remove them manually if needed:
echo %INFO_PREFIX%   docker images --filter reference="kindest/*"
echo %INFO_PREFIX%   docker rmi ^<image_name^>
echo.
echo %INFO_PREFIX% Thank you for using kind!

pause
