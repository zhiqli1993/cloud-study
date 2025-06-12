@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Docker Registry Mirror Configuration Script (Windows Version)
REM For Docker Desktop for Windows

title Docker Registry Mirror Configuration Tool

echo ========================================
echo   Docker Registry Mirror Configuration (Windows)
echo ========================================
echo.

REM Check administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrator privileges required to run this script
    echo Please right-click the script file and select "Run as administrator"
    pause
    exit /b 1
)

REM Check if Docker Desktop is running
echo [INFO] Checking Docker Desktop status...
docker version >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Docker Desktop is not running or not installed
    echo Please ensure Docker Desktop is installed and running
    pause
    exit /b 1
)
echo [SUCCESS] Docker Desktop is running

REM Show current configuration
echo.
echo [INFO] Current Docker configuration:
docker info | findstr /C:"Registry Mirrors"
if %errorLevel% neq 0 (
    echo No registry mirrors currently configured
)

echo.
echo [INFO] Will configure the following registry mirrors:
echo   - 1ms Mirror: https://docker.1ms.run
echo   - Azure China Mirror: https://dockerhub.azk8s.cn
echo   - AnyHub Mirror: https://docker.anyhub.us.kg
echo   - Jobcher Mirror: https://dockerhub.jobcher.com
echo   - ICU Mirror: https://dockerhub.icu
echo.

set /p confirm="Continue with configuration? (Y/N): "
if /i "!confirm!" neq "Y" (
    echo Configuration cancelled
    pause
    exit /b 0
)

REM Create temporary configuration file
echo [INFO] Generating Docker configuration...
set temp_config=%temp%\docker-daemon.json

(
echo {
echo   "registry-mirrors": [
echo     "https://docker.1ms.run",
echo     "https://dockerhub.azk8s.cn",
echo     "https://docker.anyhub.us.kg",
echo     "https://dockerhub.jobcher.com",
echo     "https://dockerhub.icu"
echo   ],
echo   "insecure-registries": [],
echo   "debug": false,
echo   "experimental": false
echo }
) > "!temp_config!"

echo [SUCCESS] Configuration file generated

echo.
echo [INFO] Please follow these steps to manually configure Docker Desktop:
echo.
echo 1. Right-click the Docker icon in the system tray
echo 2. Select "Settings"
echo 3. Select "Docker Engine" from the left menu
echo 4. Copy and replace the existing configuration with the following:
echo.
echo ----------------------------------------
type "!temp_config!"
echo ----------------------------------------
echo.
echo 5. Click the "Apply & Restart" button
echo 6. Wait for Docker to restart completely
echo.

pause

echo.
echo [INFO] Verifying configuration...
timeout /t 5 /nobreak >nul

REM Verify configuration
docker info | findstr /C:"Registry Mirrors" >nul
if %errorLevel% equ 0 (
    echo [SUCCESS] Registry mirror configuration successful!
    echo.
    echo Configured registry mirrors:
    docker info | findstr /C:"Registry Mirrors" /A:5
) else (
    echo [WARNING] Cannot verify registry mirror configuration, please check Docker Desktop settings
)

echo.
set /p test_pull="Test image pulling? (Y/N): "
if /i "!test_pull!" equ "Y" (
    echo [INFO] Testing pull of hello-world image...
    docker pull hello-world
    if %errorLevel% equ 0 (
        echo [SUCCESS] Image pull test successful!
    ) else (
        echo [WARNING] Image pull test failed, please check network connection
    )
)

REM Clean up temporary files
del "!temp_config!" >nul 2>&1

echo.
echo [COMPLETED] Docker registry mirror configuration completed!
echo.
echo Common commands:
echo   docker info                    # View Docker info and registry mirror configuration
echo   docker pull nginx:latest       # Test image pulling
echo   docker system prune -a         # Clean Docker cache
echo.
echo To restore default configuration, remove registry mirror settings in Docker Desktop

pause
