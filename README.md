# Claude Code 自动安装与配置脚本

> 适用于 Windows 环境，帮助国内用户快速安装和配置 Claude Code。

## 文件说明

| 文件 | 用途 |
|------|------|
| `install-claude-code.bat` | 一键安装 Claude Code（使用国内镜像） |
| `config-claude-code-env.bat` | 交互式配置 Claude Code 环境变量 |

---

## 1. install-claude-code.bat

### 功能

通过淘宝 npmmirror 镜像自动安装 Claude Code，避免国内网络访问 npm 官方源缓慢的问题。

### 执行流程

1. **检测/安装 Node.js** - 未安装则从 npmmirror 下载 Node.js v22.14.0 并静默安装
2. **检测 npm** - 确认 npm 可用
3. **检测 npm 全局路径** - 确保全局 bin 目录在 PATH 中
4. **安装 Claude Code** - `npm install -g @anthropic-ai/claude-code --registry=https://registry.npmmirror.com`
5. **验证安装** - 检查 `claude` 命令是否可用，输出版本号

### 使用方式

```
双击运行，或右键"以管理员身份运行"（安装 Node.js 时需要管理员权限）
```

### 日志

安装日志保存在脚本同目录的 `logs/` 文件夹下。

---

## 2. config-claude-code-env.bat

### 功能

交互式配置 Claude Code 所需的环境变量，支持两种接入模式：
- **Anthropic 代理模式** - 通过第三方代理/中转服务连接 Claude API
- **智谱 GLM 模式** - 通过智谱 AI 的兼容接口使用 GLM 模型

### 使用方式

```
双击运行，根据提示选择模式并逐项输入配置值。
留空直接回车可跳过该项（保留原有值不变）。
配置完成后需要重新打开终端才能生效。
```

---

### 模式 1：Anthropic 代理（6 项）

适用于通过 Yotta、OpenRouter 等代理服务连接 Claude API 的场景。

| 步骤 | 环境变量 | 必要性 | 说明 |
|:---:|----------|--------|------|
| 1 | `ANTHROPIC_API_KEY` | **必须** | API 密钥，用于身份认证 |
| 2 | `ANTHROPIC_BASE_URL` | **必须**（使用代理时） | API 基础 URL，直连官方可不设置 |
| 3 | `ANTHROPIC_CUSTOM_HEADERS` | 可选 | 自定义 HTTP 头，部分代理需要 |
| 4 | `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 可选（建议） | 设为 `1` 禁用遥测，使用代理时建议开启 |
| 5 | `HTTPS_PROXY` | 可选 | HTTPS 网络代理，使用国内中转时通常不需要 |
| 6 | `HTTP_PROXY` | 可选 | HTTP 网络代理 |

---

### 模式 2：智谱 GLM（7 项 + 自动配置）

适用于通过智谱 AI 的 Anthropic 兼容 API 使用 GLM 模型的场景。

> 参考文档：https://docs.bigmodel.cn/cn/coding-plan/tool/claude

| 步骤 | 配置项 | 必要性 | 说明 |
|:---:|--------|--------|------|
| 1 | `ANTHROPIC_AUTH_TOKEN` | **必须** | 智谱 API Key（注意不是 `ANTHROPIC_API_KEY`） |
| 2 | `ANTHROPIC_BASE_URL` | **必须** | 固定值 `https://open.bigmodel.cn/api/anthropic`，留空自动填入 |
| 3 | `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 建议 | 设为 `1`，留空自动设为 `1` |
| 4 | `API_TIMEOUT_MS` | 可选 | 请求超时时间，留空自动设为 `3000000`（50 分钟） |
| 5 | GLM 模型版本选择 | 建议 | 选择 GLM-4.7 或 GLM-5.1，写入 `settings.json` |
| 6 | `ENABLE_TOOL_SEARCH` | 可选 | 设为 `0` 修复 v2.1.69 版本 BUG |
| 7 | `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | 可选 | 设为 `1` 修复 v2.1.69 版本兼容问题 |

#### 模型映射关系

| 选项 | Claude Code 内部模型 | 实际调用模型 |
|------|---------------------|-------------|
| **GLM-4.7（默认）** | Opus | GLM-4.7 |
| | Sonnet | GLM-4.7 |
| | Haiku | GLM-4.5-Air |
| **GLM-5.1（最新）** | Opus | GLM-5.1 |
| | Sonnet | GLM-5-Turbo |
| | Haiku | GLM-4.5-Air |

#### 自动配置

脚本还会自动完成以下操作：

- **模型映射写入 `~/.claude/settings.json`** - 使用 PowerShell 合并写入，不会覆盖已有配置
- **创建 `~/.claude.json`** - 设置 `hasCompletedOnboarding: true`，跳过 Anthropic 官方登录认证

---

## 使用流程

```
1. 运行 install-claude-code.bat    → 安装 Node.js + Claude Code
2. 运行 config-claude-code-env.bat → 配置环境变量和模型
3. 重新打开终端
4. 输入 claude 启动
5. 输入 /status 确认模型状态
```

## 注意事项

- 安装脚本安装 Node.js 时需要**管理员权限**
- 环境变量通过 `setx` 写入用户级注册表，需**重开终端**生效
- 智谱 GLM 模式下，`ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_API_KEY` 是不同的变量，不要混用
- 选择 GLM-5.1 时，模型映射通过 PowerShell 合并写入 `settings.json`，已有配置不会丢失
- 智谱 API Key 在 [智谱开放平台](https://open.bigmodel.cn) 获取
