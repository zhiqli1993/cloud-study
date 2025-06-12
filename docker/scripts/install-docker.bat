@echo off
setlocal enabledelayedexpansion

:: Docker Windows 安装脚本
:: 使用方法: install-docker.bat

:: 输出文本标签 (cmd 不支持颜色)
set "INFO_PREFIX=[信息]"
set "SUCCESS_PREFIX=[成功]"
set "WARNING_PREFIX=[警告]"
set "ERROR_PREFIX=[错误]"

echo %INFO_PREFIX% Docker Windows 安装脚本
echo %INFO_PREFIX% =======================

:: 检查是否以管理员身份运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %WARNING_PREFIX% 此脚本未以管理员身份运行
    echo %INFO_PREFIX% 某些操作可能需要管理员权限
    echo %INFO_PREFIX% 建议以管理员身份运行以获得最佳效果
    echo.
)

:: 检测架构
set "ARCH=x64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=ARM64"
if "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "ARCH=ARM64"

echo %INFO_PREFIX% 检测到平台: Windows-%ARCH%

:: 检查 Docker 是否已安装
set "CURRENT_VERSION=not_installed"
where docker >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('docker --version 2^>nul') do (
        set "CURRENT_VERSION=%%i"
        set "CURRENT_VERSION=!CURRENT_VERSION:,=!"
    )
    if "!CURRENT_VERSION!"=="" set "CURRENT_VERSION=unknown"
    echo %INFO_PREFIX% 当前 Docker 版本: !CURRENT_VERSION!
    
    :: 检查 Docker 是否正常工作
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Docker 已安装且工作正常
        goto :verify_installation
    ) else (
        echo %WARNING_PREFIX% Docker 已安装但工作不正常
        echo %INFO_PREFIX% Docker Desktop 可能未运行
        echo %INFO_PREFIX% 请启动 Docker Desktop 然后重试
    )
) else (
    echo %INFO_PREFIX% Docker 目前未安装
)

:: 检查 Windows 版本兼容性
for /f "tokens=2 delims=[]" %%i in ('ver') do set "WIN_VER=%%i"
echo %INFO_PREFIX% Windows 版本: !WIN_VER!

:: 检查是否为 Windows 10/11
echo !WIN_VER! | findstr /C:"10.0" >nul
if %errorlevel% equ 0 (
    echo %INFO_PREFIX% 检测到 Windows 10/11 - 支持 Docker Desktop
) else (
    echo %WARNING_PREFIX% 检测到较旧的 Windows 版本
    echo %INFO_PREFIX% Docker Desktop 需要 Windows 10 版本 2004 或更高
    echo %INFO_PREFIX% 请查看系统要求: https://docs.docker.com/desktop/windows/install/
)

:: 检查 Hyper-V 和 WSL2 要求
echo %INFO_PREFIX% 正在检查系统要求...

:: 检查 Hyper-V 是否可用
dism /online /get-featureinfo /featurename:Microsoft-Hyper-V >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% Hyper-V 可用
) else (
    echo %WARNING_PREFIX% Hyper-V 可能不可用或未启用
    echo %INFO_PREFIX% Docker Desktop 可以使用 WSL2 作为替代
)

:: 检查是否安装了 WSL
wsl --status >nul 2>&1
if %errorlevel% equ 0 (
    echo %SUCCESS_PREFIX% WSL 已安装
    wsl --list --verbose 2>nul | findstr /C:"Ubuntu" >nul
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% 找到 WSL Ubuntu 发行版
    ) else (
        echo %INFO_PREFIX% 未找到 WSL 发行版，但 WSL 可用
    )
) else (
    echo %WARNING_PREFIX% WSL 未安装或配置不正确
    echo %INFO_PREFIX% 建议安装 WSL2 以获得更好的 Docker 性能
    echo %INFO_PREFIX% 运行: wsl --install
)

:: 下载并安装 Docker Desktop
echo.
echo %INFO_PREFIX% 正在安装 Docker Desktop...
echo %INFO_PREFIX% 这将从 Docker 官方网站下载 Docker Desktop

:: 检查 curl 是否可用
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% curl 不可用
    echo %INFO_PREFIX% 请安装 curl 或从以下地址手动下载 Docker Desktop:
    echo %INFO_PREFIX% https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe
    pause
    exit /b 1
)

:: 创建临时目录
set "TEMP_DIR=%TEMP%\docker-install-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

:: 下载 Docker Desktop 安装程序
set "INSTALLER_FILE=%TEMP_DIR%\DockerDesktopInstaller.exe"

echo %INFO_PREFIX% 正在下载 Docker Desktop 安装程序...
curl -L -o "%INSTALLER_FILE%" "https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
if %errorlevel% neq 0 (
    echo %ERROR_PREFIX% 下载 Docker Desktop 安装程序失败
    echo %INFO_PREFIX% 请从以下地址手动下载: https://www.docker.com/products/docker-desktop
    rd /s /q "%TEMP_DIR%" 2>nul
    pause
    exit /b 1
)

echo %SUCCESS_PREFIX% 下载完成

:: 运行安装程序
echo %INFO_PREFIX% 正在运行 Docker Desktop 安装程序...
echo %INFO_PREFIX% 请按照安装向导操作
echo %WARNING_PREFIX% 安装程序可能需要重启系统

start /wait "" "%INSTALLER_FILE%"
set "INSTALL_EXIT_CODE=%errorlevel%"

:: 清理
rd /s /q "%TEMP_DIR%" 2>nul

if %INSTALL_EXIT_CODE% equ 0 (
    echo %SUCCESS_PREFIX% Docker Desktop 安装程序成功完成
) else (
    echo %WARNING_PREFIX% Docker Desktop 安装程序退出代码为 %INSTALL_EXIT_CODE%
    echo %INFO_PREFIX% 如果安装成功，这可能是正常的
)

:verify_installation
echo.
echo %INFO_PREFIX% 正在验证安装...

:: 等待可能的系统变化
timeout /t 3 /nobreak >nul

:: 检查 Docker 命令是否可用
where docker >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('docker --version 2^>nul') do (
        set "INSTALLED_VERSION=%%i"
        set "INSTALLED_VERSION=!INSTALLED_VERSION:,=!"
    )
    if "!INSTALLED_VERSION!"=="" set "INSTALLED_VERSION=unknown"
    echo %SUCCESS_PREFIX% Docker 版本: !INSTALLED_VERSION!
    
    :: 测试 Docker 守护进程是否运行
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        echo %SUCCESS_PREFIX% Docker 守护进程正在运行
        
        :: 使用 hello-world 测试
        echo %INFO_PREFIX% 正在使用 hello-world 容器测试 Docker...
        docker run --rm hello-world >nul 2>&1
        if %errorlevel% equ 0 (
            echo %SUCCESS_PREFIX% Docker 工作正常
        ) else (
            echo %WARNING_PREFIX% Docker 测试容器失败
            echo %INFO_PREFIX% Docker 可能需要时间完全启动
        )
    ) else (
        echo %WARNING_PREFIX% Docker 守护进程未运行
        echo %INFO_PREFIX% 请从开始菜单或桌面启动 Docker Desktop
        echo %INFO_PREFIX% Docker Desktop 需要运行才能使用 Docker 命令
    )
) else (
    echo %WARNING_PREFIX% 未找到 Docker 命令
    echo %INFO_PREFIX% Docker Desktop 可能未正确安装
    echo %INFO_PREFIX% 尝试重启计算机并运行 Docker Desktop
)

echo.
echo %SUCCESS_PREFIX% 安装过程完成！
echo.
echo %INFO_PREFIX% 下一步：
echo %INFO_PREFIX% 1. 如果 Docker Desktop 尚未运行，请从开始菜单启动它
echo %INFO_PREFIX% 2. 等待 Docker Desktop 完成启动（可能需要几分钟）
echo %INFO_PREFIX% 3. 接受 Docker Desktop 中的任何许可协议
echo %INFO_PREFIX% 4. 使用以下命令测试 Docker: docker run hello-world
echo.
echo %INFO_PREFIX% 使用示例：
echo %INFO_PREFIX%   docker --version                      # 检查 Docker 版本
echo %INFO_PREFIX%   docker info                           # 显示系统信息
echo %INFO_PREFIX%   docker run hello-world                # 使用 hello-world 测试
echo %INFO_PREFIX%   docker run -it ubuntu bash            # 运行交互式 Ubuntu 容器
echo %INFO_PREFIX%   docker ps                             # 列出运行中的容器
echo %INFO_PREFIX%   docker images                         # 列出镜像
echo.
echo %INFO_PREFIX% 故障排除：
echo %INFO_PREFIX% - 如果 Docker 命令无效，请重启计算机
echo %INFO_PREFIX% - 确保 Docker Desktop 正在运行（检查系统托盘）
echo %INFO_PREFIX% - 检查 Docker Desktop 的 WSL2 或 Hyper-V 配置设置
echo %INFO_PREFIX% - 对于 WSL2 后端：确保 WSL2 已安装并更新
echo.
echo %INFO_PREFIX% 更多信息请访问: https://docs.docker.com/desktop/windows/

pause
