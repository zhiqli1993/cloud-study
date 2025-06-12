@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Docker 国内镜像源自动配置脚本 (Windows版本)
REM 适用于 Docker Desktop for Windows

title Docker 国内镜像源配置工具

echo ========================================
echo     Docker 国内镜像源配置脚本 (Windows)
echo ========================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 需要管理员权限运行此脚本
    echo 请右键点击脚本文件，选择"以管理员身份运行"
    pause
    exit /b 1
)

REM 检查Docker Desktop是否运行
echo [信息] 检查Docker Desktop状态...
docker version >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] Docker Desktop未运行或未安装
    echo 请确保Docker Desktop已安装并正在运行
    pause
    exit /b 1
)
echo [成功] Docker Desktop正在运行

REM 显示当前配置
echo.
echo [信息] 当前Docker配置:
docker info | findstr /C:"Registry Mirrors"
if %errorLevel% neq 0 (
    echo 当前未配置镜像源
)

echo.
echo [信息] 即将配置以下国内镜像源:
echo   - 1ms 镜像源: https://docker.1ms.run
echo   - Azure 中国镜像源: https://dockerhub.azk8s.cn
echo   - AnyHub 镜像源: https://docker.anyhub.us.kg
echo   - Jobcher 镜像源: https://dockerhub.jobcher.com
echo   - ICU 镜像源: https://dockerhub.icu
echo.

set /p confirm="是否继续配置? (Y/N): "
if /i "!confirm!" neq "Y" (
    echo 配置已取消
    pause
    exit /b 0
)

REM 创建临时配置文件
echo [信息] 生成Docker配置...
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

echo [成功] 配置文件已生成

echo.
echo [信息] 请按照以下步骤手动配置Docker Desktop:
echo.
echo 1. 右键点击系统托盘中的Docker图标
echo 2. 选择 "Settings" (设置)
echo 3. 在左侧菜单中选择 "Docker Engine"
echo 4. 将以下配置复制并替换现有配置:
echo.
echo ----------------------------------------
type "!temp_config!"
echo ----------------------------------------
echo.
echo 5. 点击 "Apply & Restart" 按钮
echo 6. 等待Docker重启完成
echo.

pause

echo.
echo [信息] 正在验证配置...
timeout /t 5 /nobreak >nul

REM 验证配置
docker info | findstr /C:"Registry Mirrors" >nul
if %errorLevel% equ 0 (
    echo [成功] 镜像源配置成功！
    echo.
    echo 配置的镜像源:
    docker info | findstr /C:"Registry Mirrors" /A:5
) else (
    echo [警告] 无法验证镜像源配置，请检查Docker Desktop设置
)

echo.
set /p test_pull="是否测试镜像拉取? (Y/N): "
if /i "!test_pull!" equ "Y" (
    echo [信息] 测试拉取 hello-world 镜像...
    docker pull hello-world
    if %errorLevel% equ 0 (
        echo [成功] 镜像拉取测试成功！
    ) else (
        echo [警告] 镜像拉取测试失败，请检查网络连接
    )
)

REM 清理临时文件
del "!temp_config!" >nul 2>&1

echo.
echo [完成] Docker 国内镜像源配置完成！
echo.
echo 常用命令:
echo   docker info                    # 查看Docker信息和镜像源配置
echo   docker pull nginx:latest       # 测试镜像拉取
echo   docker system prune -a         # 清理Docker缓存
echo.
echo 如需恢复默认配置，请在Docker Desktop设置中删除镜像源配置

pause
