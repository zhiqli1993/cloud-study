@echo off
setlocal enabledelayedexpansion

:: Docker Windows 卸载脚本
:: 使用方法: uninstall-docker.bat

:: 输出文本标签
set "INFO_PREFIX=[信息]"
set "SUCCESS_PREFIX=[成功]"
set "WARNING_PREFIX=[警告]"
set "ERROR_PREFIX=[错误]"

echo %INFO_PREFIX% Docker Windows 卸载脚本
echo %INFO_PREFIX% =======================

:: 检查是否以管理员身份运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %WARNING_PREFIX% 此脚本未以管理员身份运行
    echo %INFO_PREFIX% 某些操作可能需要管理员权限
    echo %INFO_PREFIX% 建议以管理员身份运行以完全移除
    echo.
)

:: 检查 Docker 是否已安装
set "CURRENT_VERSION=not_installed"
where docker >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('docker --version 2^>nul') do (
        set "CURRENT_VERSION=%%i"
        set "CURRENT_VERSION=!CURRENT_VERSION:,=!"
    )
    if "!CURRENT_VERSION!"=="" set "CURRENT_VERSION=unknown"
    echo %INFO_PREFIX% Docker 已安装 (版本: !CURRENT_VERSION!)
) else (
    echo %WARNING_PREFIX% Docker 未安装或不在 PATH 中
    echo %INFO_PREFIX% 正在检查 Docker Desktop 安装...
    goto :check_docker_desktop
)

:: 数据丢失警告
echo.
echo %WARNING_PREFIX% 这将完全移除 Docker 及其所有数据！
echo %WARNING_PREFIX% 所有容器、镜像、数据卷和网络都将被删除！
echo.
set /p "confirm=您确定要继续吗？ (y/N): "
if /i not "%confirm%"=="y" if /i not "%confirm%"=="yes" (
    echo %INFO_PREFIX% 卸载已取消
    pause
    exit /b 0
)

:: Check if Docker daemon is running and clean up
docker info >nul 2>&1
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% Docker daemon is running, performing cleanup...
    call :cleanup_docker_resources
) else (
    echo %INFO_PREFIX% Docker daemon is not running, skipping resource cleanup
)

:check_docker_desktop
:: Check for Docker Desktop installation
set "DOCKER_DESKTOP_FOUND=0"

:: Check if Docker Desktop is running
tasklist /FI "IMAGENAME eq Docker Desktop.exe" 2>NUL | find /I "Docker Desktop.exe" >NUL
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% Docker Desktop is currently running
    set "DOCKER_DESKTOP_FOUND=1"
    
    set /p "stop_docker=Stop Docker Desktop? (y/N): "
    if /i "!stop_docker!"=="y" if /i "!stop_docker!"=="yes" (
        echo %INFO_PREFIX% Stopping Docker Desktop...
        taskkill /F /IM "Docker Desktop.exe" >nul 2>&1
        timeout /t 3 /nobreak >nul
        echo %SUCCESS_PREFIX% Docker Desktop stopped
    )
)

:: Check for Docker Desktop in common installation paths
set "DOCKER_DESKTOP_PATHS="
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
    set "DOCKER_DESKTOP_PATHS=%ProgramFiles%\Docker\Docker"
    set "DOCKER_DESKTOP_FOUND=1"
)
if exist "%LocalAppData%\Docker\Docker Desktop.exe" (
    set "DOCKER_DESKTOP_PATHS=!DOCKER_DESKTOP_PATHS! %LocalAppData%\Docker"
    set "DOCKER_DESKTOP_FOUND=1"
)

if %DOCKER_DESKTOP_FOUND% equ 0 (
    echo %INFO_PREFIX% Docker Desktop installation not found
    goto :cleanup_config
)

:: Uninstall Docker Desktop
echo %INFO_PREFIX% Found Docker Desktop installation
set /p "uninstall_desktop=Uninstall Docker Desktop? (y/N): "
if /i not "%uninstall_desktop%"=="y" if /i not "%uninstall_desktop%"=="yes" goto :cleanup_config

echo %INFO_PREFIX% Uninstalling Docker Desktop...

:: Try to find and run the uninstaller
set "UNINSTALLER_FOUND=0"

:: Check for Docker Desktop uninstaller
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop Installer.exe" (
    echo %INFO_PREFIX% Running Docker Desktop uninstaller...
    "%ProgramFiles%\Docker\Docker\Docker Desktop Installer.exe" uninstall --quiet
    set "UNINSTALLER_FOUND=1"
)

:: Alternative: Use Windows Add/Remove Programs
if %UNINSTALLER_FOUND% equ 0 (
    echo %INFO_PREFIX% Attempting to uninstall via Windows Programs and Features...
    
    :: Try using wmic to uninstall
    wmic product where "name like '%%Docker Desktop%%'" call uninstall /nointeractive >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Docker Desktop uninstalled via WMI
        set "UNINSTALLER_FOUND=1"
    )
)

:: Manual removal if automatic uninstall failed
if %UNINSTALLER_FOUND% equ 0 (
    echo %WARNING_PREFIX% Automatic uninstallation failed, attempting manual removal...
    
    :: Remove Docker Desktop directories
    for %%p in (%DOCKER_DESKTOP_PATHS%) do (
        if exist "%%p" (
            echo %INFO_PREFIX% Removing Docker Desktop from: %%p
            rd /s /q "%%p" >nul 2>&1
            if %errorlevel% equ 0 (
                echo %SUCCESS_PREFIX% Directory removed: %%p
            ) else (
                echo %WARNING_PREFIX% Failed to remove: %%p (may require Administrator rights)
            )
        )
    )
)

:cleanup_config
:: Remove Docker configuration and data directories
echo %INFO_PREFIX% Cleaning up Docker configuration and data...

set "USER_DIRS="
set "USER_DIRS=%USER_DIRS% %USERPROFILE%\.docker"
set "USER_DIRS=%USER_DIRS% %APPDATA%\Docker"
set "USER_DIRS=%USER_DIRS% %APPDATA%\Docker Desktop"
set "USER_DIRS=%USER_DIRS% %LOCALAPPDATA%\Docker"
set "USER_DIRS=%USER_DIRS% %LOCALAPPDATA%\Docker Desktop"

set "FOUND_DIRS="
for %%d in (%USER_DIRS%) do (
    if exist "%%d" (
        set "FOUND_DIRS=!FOUND_DIRS! %%d"
    )
)

if not "!FOUND_DIRS!"=="" (
    echo %WARNING_PREFIX% Found Docker configuration and data directories:
    for %%d in (!FOUND_DIRS!) do echo    %%d
    
    set /p "remove_config=Remove Docker configuration and data directories? (y/N): "
    if /i "!remove_config!"=="y" if /i "!remove_config!"=="yes" (
        for %%d in (!FOUND_DIRS!) do (
            echo %INFO_PREFIX% Removing: %%d
            rd /s /q "%%d" >nul 2>&1
            if %errorlevel% equ 0 (
                echo %SUCCESS_PREFIX% Removed: %%d
            ) else (
                echo %WARNING_PREFIX% Failed to remove: %%d
            )
        )
    )
) else (
    echo %INFO_PREFIX% No Docker configuration directories found
)

:: Remove Docker from Windows features (if installed as a feature)
echo %INFO_PREFIX% Checking Windows features...
dism /online /get-featureinfo /featurename:Containers >nul 2>&1
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% Windows Containers feature is installed
    set /p "remove_feature=Disable Windows Containers feature? (y/N): "
    if /i "!remove_feature!"=="y" if /i "!remove_feature!"=="yes" (
        echo %INFO_PREFIX% Disabling Windows Containers feature...
        dism /online /disable-feature /featurename:Containers /norestart
        echo %WARNING_PREFIX% A system restart may be required to complete feature removal
    )
)

:: Clean up Windows Services (if any Docker services exist)
echo %INFO_PREFIX% Checking for Docker services...
sc query docker >nul 2>&1
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% Found Docker service
    set /p "remove_service=Remove Docker service? (y/N): "
    if /i "!remove_service!"=="y" if /i "!remove_service!"=="yes" (
        echo %INFO_PREFIX% Stopping and removing Docker service...
        sc stop docker >nul 2>&1
        sc delete docker >nul 2>&1
        echo %SUCCESS_PREFIX% Docker service removed
    )
)

:: Clean up remaining Docker processes
echo %INFO_PREFIX% Checking for remaining Docker processes...
tasklist | findstr /i docker >nul 2>&1
if %errorlevel% equ 0 (
    echo %WARNING_PREFIX% Found Docker-related processes:
    tasklist | findstr /i docker
    
    set /p "kill_processes=Kill remaining Docker processes? (y/N): "
    if /i "!kill_processes!"=="y" if /i "!kill_processes!"=="yes" (
        echo %INFO_PREFIX% Killing Docker processes...
        taskkill /F /IM "dockerd.exe" >nul 2>&1
        taskkill /F /IM "docker.exe" >nul 2>&1
        taskkill /F /IM "Docker Desktop.exe" >nul 2>&1
        taskkill /F /IM "com.docker.backend.exe" >nul 2>&1
        taskkill /F /IM "com.docker.proxy.exe" >nul 2>&1
        echo %SUCCESS_PREFIX% Docker processes killed
    )
) else (
    echo %INFO_PREFIX% No Docker processes found
)

:: Verify uninstallation
echo.
echo %INFO_PREFIX% Verifying Docker uninstallation...

where docker >nul 2>&1
if %errorlevel% equ 0 (
    echo %WARNING_PREFIX% Docker command is still available at: 
    where docker
    echo %INFO_PREFIX% This may be a remaining Docker CLI installation
) else (
    echo %SUCCESS_PREFIX% Docker command is no longer available
)

tasklist | findstr /i docker >nul 2>&1
if %errorlevel% equ 0 (
    echo %WARNING_PREFIX% Some Docker processes may still be running:
    tasklist | findstr /i docker
) else (
    echo %SUCCESS_PREFIX% No Docker processes found
)

echo.
echo %SUCCESS_PREFIX% Docker uninstallation process completed!
echo.
echo %INFO_PREFIX% Manual cleanup steps (if needed):
echo %INFO_PREFIX% - Restart your computer to ensure all services are stopped
echo %INFO_PREFIX% - Check Programs and Features for any remaining Docker entries
echo %INFO_PREFIX% - Remove any custom Docker configurations you may have added
echo %INFO_PREFIX% - Check system PATH for Docker directories and remove them
echo.
echo %INFO_PREFIX% If you want to reinstall Docker later, you can:
echo %INFO_PREFIX% - Use the install-docker.bat script
echo %INFO_PREFIX% - Download Docker Desktop from https://www.docker.com/products/docker-desktop

pause
exit /b 0

:: Function to cleanup Docker resources
:cleanup_docker_resources
echo %INFO_PREFIX% Cleaning up Docker resources...

:: Stop all running containers
docker ps -q >nul 2>&1
if %errorlevel% equ 0 (
    for /f %%i in ('docker ps -q 2^>nul') do set "RUNNING_CONTAINERS=%%i"
    if not "!RUNNING_CONTAINERS!"=="" (
        echo %INFO_PREFIX% Stopping running containers...
        docker stop !RUNNING_CONTAINERS! >nul 2>&1
        echo %SUCCESS_PREFIX% Containers stopped
    )
)

:: Remove all containers
set /p "remove_containers=Remove all containers? (y/N): "
if /i "%remove_containers%"=="y" if /i "%remove_containers%"=="yes" (
    echo %INFO_PREFIX% Removing all containers...
    for /f %%i in ('docker ps -aq 2^>nul') do docker rm -f %%i >nul 2>&1
    echo %SUCCESS_PREFIX% All containers removed
)

:: Remove all images
set /p "remove_images=Remove all Docker images? (y/N): "
if /i "%remove_images%"=="y" if /i "%remove_images%"=="yes" (
    echo %INFO_PREFIX% Removing all Docker images...
    for /f %%i in ('docker images -q 2^>nul') do docker rmi -f %%i >nul 2>&1
    echo %SUCCESS_PREFIX% All images removed
)

:: Remove all volumes
set /p "remove_volumes=Remove all Docker volumes? (This will delete all data!) (y/N): "
if /i "%remove_volumes%"=="y" if /i "%remove_volumes%"=="yes" (
    echo %INFO_PREFIX% Removing all Docker volumes...
    for /f %%i in ('docker volume ls -q 2^>nul') do docker volume rm %%i >nul 2>&1
    echo %SUCCESS_PREFIX% All volumes removed
)

:: Docker system cleanup
set /p "system_cleanup=Run Docker system cleanup? (y/N): "
if /i "%system_cleanup%"=="y" if /i "%system_cleanup%"=="yes" (
    echo %INFO_PREFIX% Running Docker system cleanup...
    docker system prune -af --volumes >nul 2>&1
    echo %SUCCESS_PREFIX% Docker system cleanup completed
)

goto :eof
