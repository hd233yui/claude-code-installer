@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: 用 cmd /k 重新启动自身，防止窗口闪退
if "%~1" neq "__running__" (
    cmd /k call "%~f0" __running__
    exit /b
)

:: ============================================================
::  Claude Code 安装脚本（官方源 + Git Bash 依赖修复版）
::  功能：检测Node.js -> 自动安装 -> 检测Git Bash -> 自动配置
:: ============================================================

set "LOG_DIR=%~dp0logs"
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%i"
if not defined DT (
    for /f "tokens=*" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set "DT=%%i"
) else (
    set "DT=!DT:~0,8!_!DT:~8,6!"
)
set "LOG_FILE=%LOG_DIR%\claude-install-%DT%.log"

set "NODE_VERSION=v22.14.0"
set "ARCHITECTURE=x64"
set "REQUIRED_NODE_MAJOR=18"
set "NPM_REGISTRY=https://registry.npmjs.org"
set "NODE_CDN=https://cdn.npmmirror.com/binaries/node"

:: 定义 Git Bash 环境变量名和可能的安装路径
set "GIT_BASH_ENV_VAR=CLAUDE_CODE_GIT_BASH_PATH"
set "GIT_BASH_PATH_FOUND="
set "GIT_DEFAULT_PATH_64=C:\Program Files\Git\bin\bash.exe"
set "GIT_DEFAULT_PATH_32=C:\Program Files (x86)\Git\bin\bash.exe"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :log "=================================================="
call :log " Claude Code 安装脚本启动 (集成Git Bash检测版)"
call :log " 时间: %date% %time%"
call :log "=================================================="

:: ============================================================
:: 步骤 0：检测系统架构并确认
:: ============================================================
call :log ""
call :log "[步骤 0] 检测系统架构..."
echo.
echo [步骤 0] 检测系统架构...

:: 优先使用 PowerShell 检测（兼容 Win11），失败则回退到 wmic
set "SYS_ARCH="
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).OSArchitecture" 2^>nul') do set "SYS_ARCH=%%a"
if not defined SYS_ARCH (
    for /f "tokens=2 delims=:" %%a in ('wmic os get osarchitecture 2^>nul') do set "SYS_ARCH=%%a"
)
if defined SYS_ARCH set "SYS_ARCH=!SYS_ARCH: =!"

if not defined SYS_ARCH (
    call :log_warn "无法自动检测系统架构，默认使用64位版本"
    echo [提示] 无法自动检测系统架构，默认使用64位版本
) else (
    call :log "检测到系统架构: !SYS_ARCH!"
    echo [检测] 系统架构: !SYS_ARCH!
)

:: 询问用户确认
echo.
echo 请确认您的系统架构：
echo   1. 64位系统 (x64) [推荐]
echo   2. 32位系统 (x86)
echo.
set /p "CHOICE=请输入选择 (1/2, 默认1): "
if "!CHOICE!"=="" set "CHOICE=1"

if "!CHOICE!"=="1" (
    set "ARCHITECTURE=x64"
    call :log "用户选择: 64位系统"
    echo [确认] 用户选择: 64位系统
) else if "!CHOICE!"=="2" (
    set "ARCHITECTURE=x86"
    call :log "用户选择: 32位系统"
    echo [确认] 用户选择: 32位系统
) else (
    call :log_warn "无效选择，默认使用64位系统"
    echo [提示] 无效选择，默认使用64位系统
    set "ARCHITECTURE=x64"
)

:: ============================================================
:: 步骤 1：检测 Node.js，未安装或版本过低则自动下载安装
:: ============================================================
call :log ""
call :log "[步骤 1] 检测 Node.js 环境..."
echo.
echo [步骤 1] 检测 Node.js 环境...

where node >nul 2>&1
if !errorlevel! neq 0 (
    call :log "未检测到 Node.js，需要自动安装"
    call :install_node
) else (
    for /f "tokens=*" %%v in ('node --version 2^>^&1') do set "NODE_VER=%%v"
    :: 移除可能的回车符（\r）
    set "NODE_VER=!NODE_VER: =!"
    set "NODE_VER=!NODE_VER:	=!"
    :: 获取主版本号（例如 v22.14.0 → 22）
    for /f "tokens=1 delims=." %%a in ("!NODE_VER:v=!") do set "NODE_MAJOR=%%a"
    call :log "检测到 Node.js 版本: !NODE_VER! (主版本: !NODE_MAJOR!)"
    
    :: 检查版本是否 >= REQUIRED_NODE_MAJOR
    if !NODE_MAJOR! lss %REQUIRED_NODE_MAJOR% (
        call :log_warn "Node.js 版本 !NODE_VER! 过低，需要 >= v%REQUIRED_NODE_MAJOR%.0.0"
        echo [提示] 当前 Node.js ^(!NODE_VER!^) 版本过低，Claude Code 需要 >= v%REQUIRED_NODE_MAJOR%.0.0
        echo        将自动下载安装新版本...
        call :install_node
    ) else (
        call :log "Node.js 版本符合要求 (>= v%REQUIRED_NODE_MAJOR%.0.0)"
        echo [OK] Node.js 版本: !NODE_VER!
    )
)

:: 检查 install_node 是否设置了错误标记
if defined INSTALL_FAILED (
    pause
    exit /b 1
)

:: ============================================================
:: 步骤 1.1：检测 Node.js 架构
:: ============================================================
call :log ""
call :log "[步骤 1.1] 检测 Node.js 架构..."
echo.
echo [步骤 1.1] 检测 Node.js 架构...

set "NODE_ARCH="
for /f "tokens=*" %%a in ('node -e "console.log(process.arch)" 2^>nul') do set "NODE_ARCH=%%a"

if not defined NODE_ARCH (
    call :log_warn "方法1失败，尝试方法2..."
    echo [提示] 方法1失败，尝试方法2...
    
    :: 方法2：检查Node.js安装路径
    if exist "C:\Program Files\nodejs\node.exe" (
        call :log "检测到Node.js安装在Program Files，认为是64位"
        set "NODE_ARCH=x64"
    ) else if exist "C:\Program Files (x86)\nodejs\node.exe" (
        call :log "检测到Node.js安装在Program Files (x86)，认为是32位"
        set "NODE_ARCH=ia32"
    )
)

if not defined NODE_ARCH (
    call :log_error "无法检测Node.js架构，请检查Node.js安装是否完整"
    echo [错误] 无法检测Node.js架构，请检查Node.js安装是否完整
    echo        1. 确保Node.js已正确安装
    echo        2. 尝试重启命令提示符
    echo        3. 如果问题持续，请重新安装Node.js
    pause
    exit /b 1
)

call :log "Node.js架构: !NODE_ARCH!"
echo [检测] Node.js架构: !NODE_ARCH!

:: 检查Node.js架构是否与用户选择匹配
if "%ARCHITECTURE%"=="x64" (
    if "!NODE_ARCH!"=="ia32" (
        call :log_warn "检测到32位Node.js运行在64位系统，可以继续但建议重装64位版本"
        echo [警告] 检测到32位Node.js，但您选择了64位系统
        echo        建议重新安装64位Node.js以获得更好性能，但当前可继续安装...
        timeout /t 3 >nul
    ) else if "!NODE_ARCH!"=="x64" (
        call :log "Node.js架构正确: 64位"
        echo [OK] Node.js架构正确: 64位
    ) else (
        call :log_warn "检测到未知Node.js架构: !NODE_ARCH!"
        echo [提示] 检测到未知Node.js架构: !NODE_ARCH!
    )
) else (
    if "!NODE_ARCH!"=="x64" (
        call :log_error "检测到64位Node.js，但您选择了32位系统"
        echo [错误] 检测到64位Node.js，但您选择了32位系统
        echo        请重新运行脚本并选择64位系统架构，或重新安装32位Node.js
        pause
        exit /b 1
    )
    if "!NODE_ARCH!"=="ia32" (
        call :log "Node.js架构正确: 32位"
        echo [OK] Node.js架构正确: 32位
    ) else (
        call :log_warn "检测到未知Node.js架构: !NODE_ARCH!"
        echo [提示] 检测到未知Node.js架构: !NODE_ARCH!
    )
)

:: ============================================================
:: 步骤 2：检测 Git Bash 并设置环境变量
:: ============================================================
call :log ""
call :log "[步骤 2] 检测 Git Bash 环境..."
echo.
echo [步骤 2] 检测 Git Bash 环境...

:: 首先检查环境变量是否已设置
if defined CLAUDE_CODE_GIT_BASH_PATH (
    call :log "环境变量 %GIT_BASH_ENV_VAR% 已设置为: !CLAUDE_CODE_GIT_BASH_PATH!"
    if exist "!CLAUDE_CODE_GIT_BASH_PATH!" (
        call :log "环境变量指向的 Git Bash 路径有效"
        echo [OK] Git Bash 环境变量已配置且有效: !CLAUDE_CODE_GIT_BASH_PATH!
        goto :git_bash_done
    ) else (
        call :log_warn "环境变量已设置，但路径无效，将重新查找"
        echo [提示] 环境变量 %GIT_BASH_ENV_VAR% 路径无效，正在重新查找...
    )
)

:: 查找 Git Bash 路径
call :find_git_bash

:: 如果找到了 Git Bash，则设置环境变量
if defined GIT_BASH_PATH_FOUND (
    call :log "准备设置环境变量 %GIT_BASH_ENV_VAR% = !GIT_BASH_PATH_FOUND!"
    echo [OK] 找到 Git Bash 路径: !GIT_BASH_PATH_FOUND!
    echo        正在设置环境变量...
    
    :: 使用 setx 永久设置用户环境变量
    setx %GIT_BASH_ENV_VAR% "!GIT_BASH_PATH_FOUND!" >nul 2>&1
    if !errorlevel! equ 0 (
        call :log "环境变量已成功永久设置"
        echo [OK] 环境变量 %GIT_BASH_ENV_VAR% 已永久配置
        
        :: 同时设置当前会话的变量
        set "%GIT_BASH_ENV_VAR%=!GIT_BASH_PATH_FOUND!"
        call :log "当前会话的环境变量已刷新"
    ) else (
        call :log_error "使用 setx 设置环境变量失败"
        echo [错误] 无法永久设置环境变量，将仅对当前会话生效
        set "%GIT_BASH_ENV_VAR%=!GIT_BASH_PATH_FOUND!"
    )
) else (
    call :log_error "未找到 Git Bash 安装路径"
    echo [错误] 未检测到 Git Bash，Claude Code 在 Windows 上运行时需要 Git Bash！
    echo.
    echo 请安装 Git for Windows:
    echo   1. 访问: https://git-scm.com/downloads/win
    echo   2. 下载并安装 Git (安装时选择 "Add Git Bash to the system PATH")
    echo   3. 重新运行本脚本
    pause
    exit /b 1
)

:git_bash_done
call :log "Git Bash 依赖检测完成，环境已就绪"
echo [OK] Git Bash 依赖已就绪

:: ============================================================
:: 步骤 3：检测 npm
:: ============================================================
call :log ""
call :log "[步骤 3] 检测 npm 环境..."
echo.
echo [步骤 3] 检测 npm 环境...

where npm >nul 2>&1
if !errorlevel! neq 0 call :fix_npm

if defined NPM_FAILED (
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('npm --version 2^>^&1') do set "NPM_VER=%%v"
call :log "npm 就绪，版本: !NPM_VER!"
echo [OK] npm 版本: !NPM_VER!

:: ============================================================
:: 步骤 4：检测 npm 全局路径
:: ============================================================
call :log ""
call :log "[步骤 4] 检测 npm 全局路径配置..."
echo.
echo [步骤 4] 检测 npm 全局路径配置...

for /f "tokens=*" %%p in ('npm config get prefix 2^>^&1') do set "NPM_PREFIX=%%p"
set "NPM_GLOBAL_ROOT=!NPM_PREFIX!\node_modules"
set "NPM_GLOBAL_BIN=!NPM_PREFIX!"
call :log "npm 全局模块路径: !NPM_GLOBAL_ROOT!"
call :log "npm 全局可执行路径: !NPM_GLOBAL_BIN!"

echo %PATH% | find /i "!NPM_GLOBAL_BIN!" >nul 2>&1
if !errorlevel! neq 0 (
    call :log_warn "npm 全局路径未在当前 PATH 中，已临时加入当前会话。"
    set "PATH=!NPM_GLOBAL_BIN!;!PATH!"
    echo [提示] npm 全局路径已临时加入本次会话，安装完成后建议永久配置：
    echo        !NPM_GLOBAL_BIN!
) else (
    call :log "npm 全局路径已在 PATH 中，配置正常。"
    echo [OK] npm 全局路径配置正常。
)

:: ============================================================
:: 步骤 5：安装 Claude Code - 使用官方源
:: ============================================================
call :log ""
call :log "[步骤 5] 开始安装 @anthropic-ai/claude-code..."
echo.
echo [步骤 5] 正在通过官方 npm 源安装 Claude Code，请稍候...
echo          日志文件: %LOG_FILE%
echo.

:: 记录当前 registry，以便后续对比
for /f "tokens=*" %%r in ('npm config get registry 2^>nul') do set "OLD_REGISTRY=%%r"
call :log "当前 npm registry: !OLD_REGISTRY!"
call :log "安装时将临时使用: %NPM_REGISTRY%"

:: 安装Claude Code（仅本次使用官方源，不修改全局配置）
call :log "--- npm install 输出开始 ---"
echo.
call npm install -g @anthropic-ai/claude-code --registry=%NPM_REGISTRY%
set "INSTALL_CODE=!errorlevel!"
echo.
call :log "--- npm install 输出结束 ---"
call :log "npm 退出码: !INSTALL_CODE!"

if !INSTALL_CODE! neq 0 (
    call :log_error "安装失败，npm 退出码: !INSTALL_CODE!"
    echo.
    echo [错误] 安装失败！请查看日志文件：
    echo        %LOG_FILE%
    echo.
    echo 常见问题排查：
    echo   1. 检查网络连接（能否访问 npmjs.org）
    echo   2. 以管理员身份运行此脚本
    echo   3. 检查磁盘空间是否充足
    echo   4. 尝试手动安装：npm install -g @anthropic-ai/claude-code
    pause
    exit /b 1
)

call :log "npm 安装命令执行成功。"
echo [OK] 安装命令执行完成。

:: ============================================================
:: 步骤 6：验证安装
:: ============================================================
call :log ""
call :log "[步骤 6] 验证 Claude Code 安装结果..."
echo.
echo [步骤 6] 正在验证安装结果...

where claude >nul 2>&1
if !errorlevel! neq 0 (
    call :verify_claude_fallback
) else (
    call :verify_claude_ok
)

:: ============================================================
:: 完成
:: ============================================================
call :log ""
call :log "=================================================="
call :log " 脚本执行完成，时间: %date% %time%"
call :log "=================================================="

echo.
echo 完整日志已保存至: %LOG_FILE%
echo.
pause
exit /b 0

:: ============================================================
:: 子程序：查找 Git Bash 路径
:: ============================================================
:find_git_bash
call :log "开始查找 Git Bash 路径..."

:: 方法1：检查命令 'bash' 是否在 PATH 中
where bash >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%b in ('where bash 2^>nul') do (
        set "GIT_BASH_PATH_FOUND=%%b"
        call :log "在 PATH 中找到 bash.exe: %%b"
        goto :eof
    )
)

:: 方法2：查询注册表获取 Git 安装路径
call :log "未在 PATH 中找到 bash.exe，尝试查询注册表..."
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\GitForWindows" /v InstallPath 2^>nul ^| findstr "InstallPath"') do (
    set "GIT_INSTALL_PATH=%%b"
    call :log "从注册表找到 Git 安装路径: !GIT_INSTALL_PATH!"
    set "GIT_BASH_PATH_FOUND=!GIT_INSTALL_PATH!bin\bash.exe"
    if exist "!GIT_BASH_PATH_FOUND!" (
        call :log "通过注册表定位到 bash.exe: !GIT_BASH_PATH_FOUND!"
        goto :eof
    )
)

:: 方法3：如果 64 位注册表路径没有，尝试 32 位路径
if "%ARCHITECTURE%"=="x64" (
    call :log "尝试查询32位注册表路径..."
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\GitForWindows" /v InstallPath 2^>nul ^| findstr "InstallPath"') do (
        set "GIT_INSTALL_PATH=%%b"
        call :log "从32位注册表找到 Git 安装路径: !GIT_INSTALL_PATH!"
        set "GIT_BASH_PATH_FOUND=!GIT_INSTALL_PATH!bin\bash.exe"
        if exist "!GIT_BASH_PATH_FOUND!" (
            call :log "通过32位注册表定位到 bash.exe: !GIT_BASH_PATH_FOUND!"
            goto :eof
        )
    )
)

:: 方法4：检查默认安装路径
call :log "检查默认安装路径..."
if exist "%GIT_DEFAULT_PATH_64%" (
    set "GIT_BASH_PATH_FOUND=%GIT_DEFAULT_PATH_64%"
    call :log "在默认64位路径找到 bash.exe: %GIT_DEFAULT_PATH_64%"
    goto :eof
)

if exist "%GIT_DEFAULT_PATH_32%" (
    set "GIT_BASH_PATH_FOUND=%GIT_DEFAULT_PATH_32%"
    call :log "在默认32位路径找到 bash.exe: %GIT_DEFAULT_PATH_32%"
    goto :eof
)

:: 如果所有方法都失败，记录错误
call :log_error "所有方法均未找到 Git Bash"
set "GIT_BASH_PATH_FOUND="
goto :eof

:: ============================================================
:: 子程序：安装 Node.js
:: ============================================================
:install_node
call :log_warn "未检测到 Node.js（或版本过低），开始自动下载安装..."
echo [提示] 正在从淘宝镜像自动下载安装 Node.js...
echo        版本: %NODE_VERSION%
echo        架构: %ARCHITECTURE%

:: 根据架构确定文件名
if "%ARCHITECTURE%"=="x64" (
    set "NODE_MSI=node-%NODE_VERSION%-x64.msi"
) else (
    set "NODE_MSI=node-%NODE_VERSION%-x86.msi"
)

:: 使用 npmmirror CDN 地址（国内加速，仅用于 Node.js 本身）
set "NODE_URL=%NODE_CDN%/%NODE_VERSION%/%NODE_MSI%"
set "NODE_INSTALLER=%TEMP%\%NODE_MSI%"

call :log "下载 Node.js 安装包: %NODE_URL%"
call :log "保存至: %NODE_INSTALLER%"

:: 用 PowerShell 下载（显示实时进度）
call :log "[下载] 开始下载 Node.js: %NODE_URL%"
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Write-Host '[下载中] 正在下载 Node.js...'; $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_INSTALLER%' -UseBasicParsing; if (Test-Path '%NODE_INSTALLER%') { Write-Host '[下载完成]' } else { exit 1 }"
set "DL_CODE=!errorlevel!"
call :log "[下载] 下载结束，exitcode: !DL_CODE!"

if !DL_CODE! neq 0 (
    call :log_error "Node.js 下载失败，请检查网络连接后重试。"
    echo [错误] Node.js 下载失败，请检查网络后重试。
    echo        下载地址: %NODE_URL%
    set "INSTALL_FAILED=1"
    goto :eof
)

if not exist "%NODE_INSTALLER%" (
    call :log_error "下载文件不存在，下载可能未完成。"
    echo [错误] 下载文件不存在，请重试。
    set "INSTALL_FAILED=1"
    goto :eof
)

:: 验证文件大小（至少 10MB）
for %%F in ("%NODE_INSTALLER%") do set "FSIZE=%%~zF"
if !FSIZE! lss 10485760 (
    call :log_error "下载文件异常过小 (!FSIZE! bytes)，可能下载失败。"
    echo [错误] 下载文件异常，请检查网络后重试。
    del /f /q "%NODE_INSTALLER%" >nul 2>&1
    set "INSTALL_FAILED=1"
    goto :eof
)

call :log "下载完成，开始静默安装 Node.js...（文件大小: !FSIZE! bytes）"
echo [安装] Node.js 下载完成，正在静默安装（此过程可能需要1-2分钟）...

call :log "[安装] 开始静默安装 Node.js..."
msiexec /i "%NODE_INSTALLER%" /qn /norestart ADDLOCAL=ALL
set "MSI_CODE=!errorlevel!"
call :log "msiexec 退出码: !MSI_CODE!"

if !MSI_CODE! neq 0 (
    call :log_error "Node.js 安装失败，msiexec 退出码: !MSI_CODE!"
    echo [错误] Node.js 安装失败（退出码: !MSI_CODE!）
    echo        请右键本脚本，选择"以管理员身份运行"后重试。
    set "INSTALL_FAILED=1"
    goto :eof
)

call :log "Node.js 安装完成，刷新 PATH 环境变量..."
echo [OK] Node.js 安装成功，正在刷新环境变量...

:: 刷新当前会话的 PATH
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%b"
set "PATH=!SYS_PATH!;!USR_PATH!"

del /f /q "%NODE_INSTALLER%" >nul 2>&1
call :log "已清理安装包临时文件。"

:: 再次检测
where node >nul 2>&1
if !errorlevel! neq 0 (
    if exist "C:\Program Files\nodejs\node.exe" (
        set "PATH=C:\Program Files\nodejs;!PATH!"
        call :log "已将默认安装路径加入当前会话 PATH"
    ) else if exist "C:\Program Files (x86)\nodejs\node.exe" (
        set "PATH=C:\Program Files (x86)\nodejs;!PATH!"
        call :log "已将默认32位安装路径加入当前会话 PATH"
    ) else (
        call :log_error "无法定位 Node.js 可执行文件，请重启后重试。"
        echo [错误] 无法定位 Node.js，请重启电脑后重新运行此脚本。
        set "INSTALL_FAILED=1"
    )
)
goto :eof

:: ============================================================
:: 子程序：修复 npm 路径
:: ============================================================
:fix_npm
if exist "C:\Program Files\nodejs\npm.cmd" (
    set "PATH=C:\Program Files\nodejs;!PATH!"
    call :log "已补充 npm 路径到当前会话 PATH。"
) else if exist "C:\Program Files (x86)\nodejs\npm.cmd" (
    set "PATH=C:\Program Files (x86)\nodejs;!PATH!"
    call :log "已补充32位 npm 路径到当前会话 PATH。"
) else (
    call :log_error "未检测到 npm，Node.js 安装可能不完整，请重启后重试。"
    echo [错误] 未检测到 npm，请重启电脑后重新运行此脚本。
    set "NPM_FAILED=1"
)
goto :eof

:: ============================================================
:: 子程序：验证 Claude Code 安装成功
:: ============================================================
:verify_claude_ok
for /f "tokens=*" %%v in ('claude --version 2^>^&1') do set "CLAUDE_VER=%%v"
call :log "Claude Code 安装成功！版本: !CLAUDE_VER!"
echo.
echo ============================================
echo  [成功] Claude Code 安装完成！
echo  版本: !CLAUDE_VER!
echo ============================================
echo.
echo 使用说明：
echo   启动交互模式:  claude
echo   查看版本:      claude --version
echo   查看帮助:      claude --help
echo.
echo 注意：使用 Claude Code 需要能访问 api.anthropic.com
echo       国内可能需要配置代理才能正常使用。
goto :eof

:verify_claude_fallback
if exist "!NPM_GLOBAL_BIN!\claude.cmd" (
    for /f "tokens=*" %%v in ('"!NPM_GLOBAL_BIN!\claude.cmd" --version 2^>^&1') do set "CLAUDE_VER=%%v"
    call :log "Claude Code 安装成功（通过完整路径验证），版本: !CLAUDE_VER!"
    echo.
    echo ============================================
    echo  [成功] Claude Code 安装完成！
    echo  版本: !CLAUDE_VER!
    echo ============================================
    echo.
    echo [提示] claude 命令尚未在全局 PATH 中生效，
    echo        请重新打开终端后直接使用 claude 命令，
    echo        或将以下路径加入系统 PATH：
    echo        !NPM_GLOBAL_BIN!
) else (
    call :log_error "验证失败: 未找到 claude 命令或可执行文件。"
    echo.
    echo [警告] claude 命令未在 PATH 中找到，请重新打开终端后重试。
    echo        若仍无法使用，请手动将以下路径加入系统 PATH：
    echo        !NPM_GLOBAL_BIN!
)
goto :eof

:: ============================================================
:: 日志记录函数
:: ============================================================
:log
echo %~1 >> "%LOG_FILE%"
goto :eof

:log_error
echo [ERROR] %~1
echo [ERROR] %~1 >> "%LOG_FILE%"
goto :eof

:log_warn
echo [WARN]  %~1
echo [WARN]  %~1 >> "%LOG_FILE%"
goto :eof