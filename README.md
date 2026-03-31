# OpenClaw StepFun 智能配置脚本

智能检测 OpenClaw 安装位置并自动配置 StepFun 模型。

## 特性

- ✅ **自动检测** OpenClaw 安装路径（支持任意位置）
- ✅ **智能推断** 配置文件位置
- ✅ **跨平台** 支持（macOS、Linux、Windows）
- ✅ **安全备份** 自动备份配置文件
- ✅ **三种接入方式**：OpenRouter 免费版、StepFun 官方 API、Step Plan
- ✅ **无需 OpenClaw 运行过**：自动创建基础配置

## 快速开始

### macOS / Linux（Bash）
```bash
curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh | bash
```

### Windows（PowerShell）
```powershell
irm https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.ps1 | iex
```

### 或下载后运行
```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh -o add_stepfun_smart.sh
chmod +x add_stepfun_smart.sh
bash add_stepfun_smart.sh
```

```powershell
# Windows PowerShell
curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.ps1 -o add_stepfun_smart.ps1
.\add_stepfun_smart.ps1
```

## 支持的接入方式

| 选项 | 说明 | 费用 | API Key 获取 |
|------|------|------|-------------|
| 1 | OpenRouter 免费版 | 免费 | https://openrouter.ai/keys |
| 2 | StepFun 官方 API | 按量计费 | https://platform.stepfun.com/console/apikeys |
| 3 | StepFun Step Plan | 订阅制 | https://platform.stepfun.com/console/apikeys |

## 前置条件

### 必需
- **jq** - JSON 处理工具
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt install jq`
  - CentOS/RHEL: `sudo yum install jq`
  - Windows: https://stedolan.github.io/jq/download/ 或 `choco install jq`

- **bash** (macOS/Linux) 或 **PowerShell** (Windows)

- **OpenClaw** - 已安装 CLI 工具

### 可选
- **配置文件** - 如果不存在，脚本会自动创建

## 配置文件位置

脚本会按顺序检查以下位置，找到的第一个将被使用：

| 系统 | 检查顺序 |
|------|----------|
| macOS/Linux | 1. `~/.openclaw/openclaw.json`<br>2. `/root/.openclaw/openclaw.json`<br>3. `/usr/local/.openclaw/openclaw.json` |
| Windows | 1. `$env:USERPROFILE\.openclaw\openclaw.json`<br>2. `$env:APPDATA\openclaw\openclaw.json` |

如果都不存在，会在用户目录自动创建基础配置。

## 使用示例

### macOS/Linux
```bash
curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh | bash

# 选择 2 (StepFun 官方 API)
# 输入 API Key: sk-xxx
```

### Windows
```powershell
irm https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.ps1 | iex

# 选择 2 (StepFun 官方 API)
# 输入 API Key: sk-xxx
```

## 脚本说明

仓库包含两个脚本：
- `add_stepfun_smart.sh` - Bash 版本（macOS、Linux、WSL）
- `add_stepfun_smart.ps1` - PowerShell 版本（Windows）

两个脚本功能完全相同，只是针对不同平台做了适配。

## 工作原理

1. ✅ 检查前置条件（jq、环境）
2. ✅ 查找或创建配置文件
3. ✅ 显示菜单（3 个选项）
4. ✅ 读取用户选择和 API Key
5. ✅ 备份原配置
6. ✅ 使用 jq/JSON 修改配置
7. ✅ 提示重启 OpenClaw

## 配置结构

脚本会修改 `openclaw.json` 的以下字段：
- `models.providers.{provider}` - 添加提供商配置
- `agents.defaults.model.primary` - 设置默认模型

支持的提供商：
- `openrouter` - OpenRouter 免费版
- `stepfun` - StepFun 官方 API
- `step-plan` - StepFun Step Plan

## License

MIT License
