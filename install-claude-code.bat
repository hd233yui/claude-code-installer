@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: 用 cmd /k 重新启动自身，防止窗口闪退
if "%~1" neq "__running__" (
    cmd /k call "%~f0" __running__
    exit /b
)

:: ============================================================
::  Claude Code 安装脚本（国内镜像）
::  镜像源：npmmirror.com（淘宝）
:: ============================================================

set "LOG_DIR=%~dp0logs"
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value 2^>nul') do set "DT=%%i"
set "LOG_FILE=%LOG_DIR%\claude-install-%DT:~0,8%_%DT:~8,6%.log"

set "NODE_VERSION=v22.14.0"
set "NODE_MSI=node-%NODE_VERSION%-x64.msi"
set "NODE_URL=https://registry.npmmirror.com/-/binary/node/%NODE_VERSION%/%NODE_MSI%"
set "NODE_INSTALLER=%TEMP%\%NODE_MSI%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :log "=================================================="
call :log " Claude Code 安装脚本启动"
call :log " 时间: %date% %time%"
call :log " 镜像源: https://registry.npmmirror.com"
call :log "=================================================="

:: ============================================================
:: 步骤 1：检测 Node.js，未安装则自动下载安装
:: ============================================================
call :log ""
call :log "[步骤 1] 检测 Node.js 环境..."
echo.
echo [步骤 1] 检测 Node.js 环境...

where node >nul 2>&1
if %errorlevel% neq 0 call :install_node

:: 检查 install_node 是否设置了错误标记
if defined INSTALL_FAILED (
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('node --version 2^>^&1') do set "NODE_VER=%%v"
call :log "Node.js 就绪，版本: !NODE_VER!"
echo [OK] Node.js 版本: !NODE_VER!

:: ============================================================
:: 步骤 2：检测 npm
:: ============================================================
call :log ""
call :log "[步骤 2] 检测 npm 环境..."
echo.
echo [步骤 2] 检测 npm 环境...

where npm >nul 2>&1
if %errorlevel% neq 0 call :fix_npm

if defined NPM_FAILED (
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('npm --version 2^>^&1') do set "NPM_VER=%%v"
call :log "npm 就绪，版本: !NPM_VER!"
echo [OK] npm 版本: !NPM_VER!

:: ============================================================
:: 步骤 3：检测 npm 全局路径
:: ============================================================
call :log ""
call :log "[步骤 3] 检测 npm 全局路径配置..."
echo.
echo [步骤 3] 检测 npm 全局路径配置...

for /f "tokens=*" %%p in ('npm config get prefix 2^>^&1') do set "NPM_PREFIX=%%p"
set "NPM_GLOBAL_ROOT=!NPM_PREFIX!\node_modules"
set "NPM_GLOBAL_BIN=!NPM_PREFIX!"
call :log "npm 全局模块路径: !NPM_GLOBAL_ROOT!"
call :log "npm 全局可执行路径: !NPM_GLOBAL_BIN!"

echo %PATH% | find /i "!NPM_GLOBAL_BIN!" >nul 2>&1
if %errorlevel% neq 0 (
    call :log_warn "npm 全局路径未在当前 PATH 中，已临时加入当前会话。"
    set "PATH=!NPM_GLOBAL_BIN!;!PATH!"
    echo [提示] npm 全局路径已临时加入本次会话，安装完成后建议永久配置：
    echo        !NPM_GLOBAL_BIN!
) else (
    call :log "npm 全局路径已在 PATH 中，配置正常。"
    echo [OK] npm 全局路径配置正常。
)

:: ============================================================
:: 步骤 4：安装 Claude Code
:: ============================================================
call :log ""
call :log "[步骤 4] 开始安装 @anthropic-ai/claude-code..."
call :log "使用镜像源: https://registry.npmmirror.com"
echo.
echo [步骤 4] 正在通过淘宝镜像安装 Claude Code，请稍候...
echo          日志文件: %LOG_FILE%
echo.

call :log "--- npm install 输出开始 ---"
echo.
call npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com
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
    echo   1. 检查网络连接（能否访问 npmmirror.com）
    echo   2. 以管理员身份运行此脚本
    echo   3. 检查磁盘空间是否充足
    pause
    exit /b 1
)

call :log "npm 安装命令执行成功。"
echo [OK] 安装命令执行完成。

:: ============================================================
:: 步骤 5：验证安装
:: ============================================================
call :log ""
call :log "[步骤 5] 验证 Claude Code 安装结果..."
echo.
echo [步骤 5] 正在验证安装结果...

where claude >nul 2>&1
if %errorlevel% neq 0 (
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
:: 子程序
:: ============================================================

:install_node
call :log_warn "未检测到 Node.js，开始自动下载安装..."
echo [提示] 未检测到 Node.js，正在从淘宝镜像自动下载安装...
echo        版本: %NODE_VERSION%
echo        下载地址: %NODE_URL%
echo.

call :log "下载 Node.js 安装包: %NODE_URL%"
call :log "保存至: %NODE_INSTALLER%"

:: 用 PowerShell 下载（显示实时进度）
call :log "[下载] 开始下载 Node.js: %NODE_URL%"
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Write-Host '[下载中] 正在下载 Node.js...'; $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_INSTALLER%' -UseBasicParsing; Write-Host '[下载完成]'"
call :log "[下载] 下载结束，exitcode: !errorlevel!"

if !errorlevel! neq 0 (
    call :log_error "Node.js 下载失败，请检查网络连接后重试。"
    echo [错误] Node.js 下载失败，请检查网络后重试。
    set "INSTALL_FAILED=1"
    goto :eof
)

if not exist "%NODE_INSTALLER%" (
    call :log_error "下载文件不存在，下载可能未完成。"
    echo [错误] 下载文件不存在，请重试。
    set "INSTALL_FAILED=1"
    goto :eof
)

call :log "下载完成，开始静默安装 Node.js..."
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
    ) else (
        call :log_error "无法定位 Node.js 可执行文件，请重启后重试。"
        echo [错误] 无法定位 Node.js，请重启电脑后重新运行此脚本。
        set "INSTALL_FAILED=1"
    )
)
goto :eof

:fix_npm
if exist "C:\Program Files\nodejs\npm.cmd" (
    set "PATH=C:\Program Files\nodejs;!PATH!"
    call :log "已补充 npm 路径到当前会话 PATH。"
) else (
    call :log_error "未检测到 npm，Node.js 安装可能不完整，请重启后重试。"
    echo [错误] 未检测到 npm，请重启电脑后重新运行此脚本。
    set "NPM_FAILED=1"
)
goto :eof

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
