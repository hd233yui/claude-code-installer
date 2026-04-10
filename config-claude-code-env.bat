@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================
::  Claude Code 环境变量配置脚本
::  功能：交互式配置 Claude Code 所需的系统环境变量
::  支持模式：Anthropic 代理 / 智谱 GLM
::  说明：每项配置前会提示其作用，留空则跳过该项
:: ============================================================

echo.
echo ============================================
echo   Claude Code 环境变量配置工具
echo ============================================
echo.
echo  本脚本将引导你逐项配置 Claude Code 所需的环境变量。
echo  每项会说明用途，输入值后将写入系统用户环境变量。
echo  直接按回车可跳过该项（保留原有值不变）。
echo.
echo  注意：配置完成后需要重新打开终端才能生效。
echo ============================================
echo.

:: ============================================================
:: 选择配置模式
:: ============================================================
echo  请选择你的 API 接入方式：
echo.
echo    [1] Anthropic 代理模式
echo        通过第三方代理/中转服务连接 Claude API
echo        适用于：Yotta、OpenRouter 等代理服务
echo.
echo    [2] 智谱 GLM 模式
echo        通过智谱 AI 的 Anthropic 兼容接口使用 GLM 模型
echo        适用于：GLM-5.1、GLM-5-Turbo、GLM-4.5-Air 等
echo.
set "MODE="
set /p "MODE=  请输入选项（1 或 2）: "

if "!MODE!"=="1" goto :mode_anthropic
if "!MODE!"=="2" goto :mode_zhipu

echo.
echo [错误] 无效选项，请输入 1 或 2。
pause
exit /b 1

:: ============================================================
::                  模式 1：Anthropic 代理
:: ============================================================
:mode_anthropic
echo.
echo ============================================
echo   模式：Anthropic 代理
echo ============================================
echo.

:: --- 1. ANTHROPIC_API_KEY ---
echo [1/6] ANTHROPIC_API_KEY  [必须]
echo   作用：Anthropic API 密钥，用于身份认证。
echo         这是使用 Claude Code 的必需项。
echo         如果使用第三方代理，请填写代理提供的 API Key。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANTHROPIC_API_KEY 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx ANTHROPIC_API_KEY "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 ANTHROPIC_API_KEY
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 2. ANTHROPIC_BASE_URL ---
echo [2/6] ANTHROPIC_BASE_URL  [必须 - 使用代理时]
echo   作用：API 请求的基础 URL。
echo         默认为 https://api.anthropic.com（直连官方可不设置）
echo         如果使用第三方代理/中转服务，则必须填写代理地址。
echo         例如：https://tower-ai.yottastudios.com/zi/proxy
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANTHROPIC_BASE_URL 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx ANTHROPIC_BASE_URL "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 ANTHROPIC_BASE_URL
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 3. ANTHROPIC_CUSTOM_HEADERS ---
echo [3/6] ANTHROPIC_CUSTOM_HEADERS  [可选 - 视代理要求]
echo   作用：发送 API 请求时附加的自定义 HTTP 头。
echo         部分代理服务需要通过自定义头传递认证信息，按代理方要求配置。
echo         如果代理不要求自定义头，可跳过此项。
echo         格式：Header-Name:Header-Value（多个用逗号分隔）
echo         例如：Authorization:Token your_api_key
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANTHROPIC_CUSTOM_HEADERS 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx ANTHROPIC_CUSTOM_HEADERS "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 ANTHROPIC_CUSTOM_HEADERS
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 4. CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC ---
echo [4/6] CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC  [可选 - 使用代理时建议设置]
echo   作用：设为 1 可禁用非必要的网络请求（遥测、自动更新检查等）。
echo         使用第三方代理时建议设为 1，避免请求被代理拦截导致报错。
echo         直连官方可不设置。
echo         可选值：1（禁用） / 留空不设置（保持默认行为）
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 5. HTTPS_PROXY ---
echo [5/6] HTTPS_PROXY  [可选 - 需要网络代理时]
echo   作用：HTTPS 网络代理地址（注意：这是网络层代理，不是 API 中转）。
echo         仅当你的网络环境需要通过代理才能访问外网时才需要配置。
echo         已配置 ANTHROPIC_BASE_URL 指向国内中转的情况下通常不需要。
echo         格式：http://host:port 或 socks5://host:port
echo         例如：http://127.0.0.1:7890
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v HTTPS_PROXY 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx HTTPS_PROXY "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 HTTPS_PROXY
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 6. HTTP_PROXY ---
echo [6/6] HTTP_PROXY  [可选 - 需要网络代理时]
echo   作用：HTTP 网络代理地址。
echo         通常与 HTTPS_PROXY 设为相同值即可。
echo         不需要网络代理的环境可跳过。
echo         格式：http://host:port 或 socks5://host:port
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v HTTP_PROXY 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx HTTP_PROXY "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 HTTP_PROXY
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

goto :summary

:: ============================================================
::                  模式 2：智谱 GLM
:: ============================================================
:mode_zhipu
echo.
echo ============================================
echo   模式：智谱 GLM
echo   文档：https://docs.bigmodel.cn/cn/coding-plan/tool/claude
echo ============================================
echo.

:: --- 1. ANTHROPIC_AUTH_TOKEN ---
echo [1/7] ANTHROPIC_AUTH_TOKEN  [必须]
echo   作用：智谱 AI 的 API Key，用于身份认证。
echo         请在智谱开放平台（https://open.bigmodel.cn）获取。
echo         注意：智谱使用 ANTHROPIC_AUTH_TOKEN 而非 ANTHROPIC_API_KEY。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANTHROPIC_AUTH_TOKEN 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx ANTHROPIC_AUTH_TOKEN "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 ANTHROPIC_AUTH_TOKEN
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 2. ANTHROPIC_BASE_URL ---
echo [2/7] ANTHROPIC_BASE_URL  [必须]
echo   作用：智谱 AI 的 Anthropic 兼容 API 地址。
echo         固定值：https://open.bigmodel.cn/api/anthropic
echo         直接回车将自动填入上述地址。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ANTHROPIC_BASE_URL 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空使用默认值 https://open.bigmodel.cn/api/anthropic）: "
if not defined INPUT set "INPUT=https://open.bigmodel.cn/api/anthropic"
setx ANTHROPIC_BASE_URL "!INPUT!" >nul 2>&1
echo   [OK] 已设置 ANTHROPIC_BASE_URL = !INPUT!
set "CURRENT_VAL="
echo.

:: --- 3. CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC ---
echo [3/7] CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC  [建议设为 1]
echo   作用：设为 1 可禁用非必要的网络请求（遥测、自动更新检查等）。
echo         使用智谱 GLM 时建议设为 1，避免向 Anthropic 官方发送无效请求。
echo         直接回车将自动设为 1。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空默认设为 1）: "
if not defined INPUT set "INPUT=1"
setx CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC "!INPUT!" >nul 2>&1
echo   [OK] 已设置 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = !INPUT!
set "CURRENT_VAL="
echo.

:: --- 4. API_TIMEOUT_MS ---
echo [4/7] API_TIMEOUT_MS  [可选 - 防止长任务超时]
echo   作用：API 请求超时时间（毫秒）。
echo         GLM 模型响应可能较慢，建议设为 3000000（50 分钟）防止超时。
echo         直接回车将自动设为 3000000。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v API_TIMEOUT_MS 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空默认设为 3000000）: "
if not defined INPUT set "INPUT=3000000"
setx API_TIMEOUT_MS "!INPUT!" >nul 2>&1
echo   [OK] 已设置 API_TIMEOUT_MS = !INPUT!
set "CURRENT_VAL="
echo.

:: --- 5. 模型映射 ---
echo [5/7] GLM 模型版本选择  [建议配置]
echo   作用：将 Claude Code 内部模型映射到对应的 GLM 模型。
echo         配置将写入 ~/.claude/settings.json 文件。
echo.
echo    [1] GLM-4.7（默认）
echo        Opus / Sonnet = GLM-4.7，Haiku = GLM-4.5-Air
echo.
echo    [2] GLM-5.1（最新）
echo        Opus = GLM-5.1，Sonnet = GLM-5-Turbo，Haiku = GLM-4.5-Air
echo.
set "MODEL_CHOICE="
set /p "MODEL_CHOICE=  请选择模型版本（1 或 2，留空默认选 1）: "
if not defined MODEL_CHOICE set "MODEL_CHOICE=1"

set "CLAUDE_SETTINGS_DIR=%USERPROFILE%\.claude"
set "CLAUDE_SETTINGS=!CLAUDE_SETTINGS_DIR!\settings.json"

if not exist "!CLAUDE_SETTINGS_DIR!" mkdir "!CLAUDE_SETTINGS_DIR!"

if "!MODEL_CHOICE!"=="2" (
    echo   [选择] GLM-5.1 模式
    set "GLM_HAIKU=glm-4.5-air"
    set "GLM_SONNET=glm-5-turbo"
    set "GLM_OPUS=glm-5.1"
) else (
    echo   [选择] GLM-4.7 模式
    set "GLM_HAIKU=glm-4.5-air"
    set "GLM_SONNET=glm-4.7"
    set "GLM_OPUS=glm-4.7"
)

:: 使用 PowerShell 合并写入 settings.json（保留已有配置）
powershell -NoProfile -Command ^
    "$settingsPath = '!CLAUDE_SETTINGS!'; ^
    if (Test-Path $settingsPath) { ^
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json; ^
    } else { ^
        $json = [PSCustomObject]@{}; ^
    }; ^
    if (-not $json.env) { ^
        $json | Add-Member -NotePropertyName 'env' -NotePropertyValue ([PSCustomObject]@{}) -Force; ^
    }; ^
    $json.env | Add-Member -NotePropertyName 'ANTHROPIC_DEFAULT_HAIKU_MODEL' -NotePropertyValue '!GLM_HAIKU!' -Force; ^
    $json.env | Add-Member -NotePropertyName 'ANTHROPIC_DEFAULT_SONNET_MODEL' -NotePropertyValue '!GLM_SONNET!' -Force; ^
    $json.env | Add-Member -NotePropertyName 'ANTHROPIC_DEFAULT_OPUS_MODEL' -NotePropertyValue '!GLM_OPUS!' -Force; ^
    $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8; ^
    Write-Host '[OK] 已合并写入' $settingsPath;"

echo         Opus = !GLM_OPUS!, Sonnet = !GLM_SONNET!, Haiku = !GLM_HAIKU!
echo.

:: --- 6. ENABLE_TOOL_SEARCH ---
echo [6/7] ENABLE_TOOL_SEARCH  [可选 - 遇到 BUG 时设置]
echo   作用：设为 0 可禁用工具搜索功能。
echo         Claude Code v2.1.69 存在已知 BUG，启用此功能会导致报错。
echo         如果你遇到工具搜索相关的错误，请设为 0。
echo         未遇到问题可跳过。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v ENABLE_TOOL_SEARCH 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx ENABLE_TOOL_SEARCH "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 ENABLE_TOOL_SEARCH = !INPUT!
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 7. CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS ---
echo [7/7] CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS  [可选 - 遇到 BUG 时设置]
echo   作用：设为 1 可禁用实验性测试功能。
echo         与 ENABLE_TOOL_SEARCH 配合使用，修复 v2.1.69 版本的兼容问题。
echo         如果你遇到异常报错，请设为 1。
echo         未遇到问题可跳过。
echo.
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS 2^>nul') do set "CURRENT_VAL=%%b"
if defined CURRENT_VAL (
    echo   当前值：!CURRENT_VAL!
) else (
    echo   当前值：（未设置）
)
set "INPUT="
set /p "INPUT=  请输入新值（留空跳过）: "
if defined INPUT (
    setx CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS "!INPUT!" >nul 2>&1
    echo   [OK] 已设置 CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = !INPUT!
) else (
    echo   [跳过]
)
set "CURRENT_VAL="
echo.

:: --- 配置 onboarding ---
echo [额外] 配置 Claude Code 首次启动标记...
set "CLAUDE_JSON=%USERPROFILE%\.claude.json"
if not exist "!CLAUDE_JSON!" (
    echo {"hasCompletedOnboarding":true}> "!CLAUDE_JSON!"
    echo   [OK] 已创建 !CLAUDE_JSON!（跳过首次引导）
) else (
    echo   [跳过] !CLAUDE_JSON! 已存在
)
echo.

goto :summary

:: ============================================================
:: 汇总
:: ============================================================
:summary
echo ============================================
echo   配置完成！当前环境变量状态：
echo ============================================
echo.

for %%V in (
    ANTHROPIC_API_KEY
    ANTHROPIC_AUTH_TOKEN
    ANTHROPIC_BASE_URL
    ANTHROPIC_CUSTOM_HEADERS
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
    API_TIMEOUT_MS
    ENABLE_TOOL_SEARCH
    CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS
    HTTPS_PROXY
    HTTP_PROXY
) do (
    set "VAL="
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v %%V 2^>nul') do set "VAL=%%b"
    if defined VAL (
        echo   %%V = !VAL!
    ) else (
        echo   %%V = （未设置）
    )
)

echo.
echo  [提示] 环境变量已写入用户级注册表，
echo         请重新打开终端（CMD / PowerShell / VS Code 终端）后生效。
echo.
pause
exit /b 0
