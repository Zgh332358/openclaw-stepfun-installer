# OpenClaw StepFun 配置脚本 (Windows PowerShell 版本)
# 支持：直接运行 .\add_stepfun_smart.ps1
# 自动检测 OpenClaw 安装位置

# 需要管理员权限检查（某些系统可能需要）
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "注意：某些操作可能需要管理员权限"
}

# 颜色函数
function Write-Info($message) { Write-Host $message -ForegroundColor Blue }
function Write-Success($message) { Write-Host $message -ForegroundColor Green }
function Write-Warn($message) { Write-Host $message -ForegroundColor Yellow }
function Write-Error($message) { Write-Host $message -ForegroundColor Red }

# 前置条件检查
function Check-Prerequisites {
    $all_ok = $true

    Write-Host "🔍 检查前置条件..."
    Write-Host ""

    # 1. 检查 jq
    if (Get-Command jq -ErrorAction SilentlyContinue) {
        $jqVersion = jq --version 2>&1 | Select-Object -First 1
        Write-Host "  ✅ jq: $jqVersion" -ForegroundColor Green
    } else {
        Write-Host "  ❌ jq: 未安装" -ForegroundColor Red
        Write-Host ""
        Write-Host "  安装方法：" -ForegroundColor Yellow
        Write-Host "    1. 从 https://stedolan.github.io/jq/download/ 下载"
        Write-Host "    2. 或使用 chocolatey: choco install jq"
        Write-Host "    3. 或使用 winget: winget install jq"
        $global:all_ok = $false
    }

    # 2. 检查 PowerShell 版本
    $psVersion = $PSVersionTable.PSVersion.ToString()
    Write-Host "  ✅ PowerShell: $psVersion"

    # 3. 检查 OpenClaw 可执行文件（可选）
    $openclawFound = $false
    $openclawPaths = @(
        "$env:USERPROFILE\.local\bin\openclaw.exe",
        "$env:ProgramFiles\OpenClaw\openclaw.exe",
        "C:\Program Files\OpenClaw\openclaw.exe",
        "C:\OpenClaw\openclaw.exe"
    )

    foreach ($path in $openclawPaths) {
        if (Test-Path $path) {
            Write-Host "  ✅ OpenClaw: $path" -ForegroundColor Green
            $openclawFound = $true
            break
        }
    }

    if (-not $openclawFound) {
        Write-Host "  ⚠️  OpenClaw: 未在 PATH 中找到（可能不影响使用）" -ForegroundColor Yellow
    }

    # 4. 检查配置文件（不强制，可以自动创建）
    $config_found = $false
    $config_paths = @(
        "$env:USERPROFILE\.openclaw\openclaw.json",
        "$env:APPDATA\openclaw\openclaw.json",
        "C:\openclaw\openclaw.json"
    )

    foreach ($cfg in $config_paths) {
        if (Test-Path $cfg) {
            Write-Host "  ✅ 配置文件: $cfg" -ForegroundColor Green
            $config_found = $true
            break
        }
    }

    if (-not $config_found) {
        Write-Host "  ⚠️  配置文件: 未找到" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  提示：" -ForegroundColor Blue
        Write-Host "    - 如果 OpenClaw 未运行过，这是正常的"
        Write-Host "    - 脚本将在配置时创建基础配置文件"
    }

    Write-Host ""

    if (-not $all_ok) {
        Write-Host "❌ 前置条件检查失败，请解决上述问题后重试" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ 所有必需条件检查通过！" -ForegroundColor Green
    Write-Host ""
}

# 查找配置文件
function Find-ConfigFile {
    param([string]$CustomConfig)

    # 如果用户指定了配置，优先使用
    if ($CustomConfig -and (Test-Path $CustomConfig)) {
        return $CustomConfig
    }

    # 检查常见位置
    $candidates = @(
        "$env:USERPROFILE\.openclaw\openclaw.json",
        "$env:APPDATA\openclaw\openclaw.json",
        "$env:USERPROFILE\.config\openclaw\openclaw.json",
        "C:\openclaw\openclaw.json"
    )

    foreach ($cfg in $candidates) {
        if (Test-Path $cfg) {
            return $cfg
        }
    }

    # 默认使用用户目录
    return "$env:USERPROFILE\.openclaw\openclaw.json"
}

# 创建基础配置
function New-BaseConfig {
    param([string]$ConfigFile)

    # 确保目录存在
    $config_dir = Split-Path $ConfigFile -Parent
    if (-not (Test-Path $config_dir)) {
        New-Item -ItemType Directory -Path $config_dir -Force | Out-Null
        Write-Host "📁 创建配置目录: $config_dir"
    }

    # 创建基础配置
    @'
{
  "meta": {
    "lastTouchedVersion": "0.0.0",
    "lastTouchedAt": ""
  },
  "wizard": {
    "lastRunAt": "",
    "lastRunVersion": "",
    "lastRunCommand": "",
    "lastRunMode": ""
  },
  "models": {
    "mode": "merge",
    "providers": {}
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": ""
      },
      "models": {}
    }
  },
  "tools": {
    "profile": "coding"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "controlUi": {
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "token",
      "token": ""
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    },
    "nodes": {
      "denyCommands": []
    }
  }
}
'@ | Out-File -FilePath $ConfigFile -Encoding UTF8

    Write-Host "✅ 已创建基础配置文件: $ConfigFile"
    Write-Host ""
}

# ========== 主程序开始 ==========

# 1. 检查前置条件
Check-Prerequisites

# 2. 确定配置文件（支持 -c 参数）
$CONFIG_FILE = $null
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "-c" -and $i + 1 -lt $args.Count) {
        $CONFIG_FILE = $args[$i + 1]
        break
    }
}
$CONFIG_FILE = Find-ConfigFile -CustomConfig $CONFIG_FILE

if (-not (Test-Path $CONFIG_FILE)) {
    Write-Host "⚠️  配置文件不存在，将自动创建" -ForegroundColor Yellow
    New-BaseConfig -ConfigFile $CONFIG_FILE
}

Write-Host "📁 使用配置文件: $CONFIG_FILE"
Write-Host ""

# 验证配置文件
try {
    $null = Get-Content $CONFIG_FILE | ConvertFrom-Json
} catch {
    Write-Host "❌ 配置文件不是有效的 JSON: $CONFIG_FILE" -ForegroundColor Red
    exit 1
}

# 3. 菜单（只显示 StepFun 三个选项）
Write-Host "=========================================="
Write-Host "  OpenClaw 配置 - 添加 StepFun"
Write-Host "=========================================="
Write-Host ""
Write-Host "请选择接入方式："
Write-Host "  1) OpenRouter 免费版（免费，50 RPM 限制）"
Write-Host "  2) StepFun 官方 API（按量计费）"
Write-Host "  3) StepFun Step Plan（订阅制）"
Write-Host ""

# 4. 读取选择
do {
    $choice = Read-Host "请输入数字 [1-3]"
    if ($choice -notmatch '^[1-3]$') {
        Write-Host "无效输入，请输入 1、2 或 3"
    }
} while ($choice -notmatch '^[1-3]$')

Write-Host ""

# 5. 根据选择获取配置信息
switch ($choice) {
    '1' {
        $PROVIDER = "openrouter"
        $PROMPT = "请输入 OpenRouter API Key（sk-or-v1-...）: "
        $DEFAULT_MODEL = "stepfun/step-3.5-flash:free"
        $BASE_URL = "https://openrouter.ai/api/v1"
    }
    '2' {
        $PROVIDER = "stepfun"
        $PROMPT = "请输入 StepFun API Key: "
        $DEFAULT_MODEL = "stepfun/step-3.5-flash"
        $BASE_URL = "https://api.stepfun.com"
    }
    '3' {
        $PROVIDER = "stepfun-plan"
        $PROMPT = "请输入 StepFun API Key: "
        $DEFAULT_MODEL = "step-plan/step-3.5-flash"
        $BASE_URL = "https://api.stepfun.com/step_plan"
    }
}

# 6. 读取 API Key
do {
    $API_KEY = Read-Host -Prompt $PROMPT
    if ([string]::IsNullOrWhiteSpace($API_KEY)) {
        Write-Host "API Key 不能为空，请重新输入"
    }
} while ([string]::IsNullOrWhiteSpace($API_KEY))

Write-Host ""

# 7. 备份配置
Write-Host "📦 正在备份配置文件..."
$backup_file = "$CONFIG_FILE.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
Copy-Item $CONFIG_FILE $backup_file -Force
Write-Host "   备份文件: $backup_file"
Write-Host ""

# 8. 应用配置
Write-Host "⚙️  正在配置 OpenClaw..."

# 读取并修改配置
$config = Get-Content $CONFIG_FILE | ConvertFrom-Json

# 确保 providers 存在
if (-not $config.models) { $config.models = @{} }
if (-not $config.models.providers) { $config.models.providers = @{} }

# 根据选择添加 provider
switch ($PROVIDER) {
    'openrouter' {
        $config.models.providers.openrouter = @{
            baseUrl = $BASE_URL
            apiKey = $API_KEY
            api = "openai-completions"
            models = @(
                @{
                    id = "stepfun/step-3.5-flash:free"
                    name = "Step 3.5 Flash Free"
                    api = "openai-completions"
                    reasoning = $true
                    input = @("text")
                    cost = @{
                        input = 0
                        output = 0
                        cacheRead = 0
                        cacheWrite = 0
                    }
                    contextWindow = 256000
                    maxTokens = 8192
                }
            )
        }
        # 设置默认模型
        if (-not $config.agents) { $config.agents = @{} }
        if (-not $config.agents.defaults) { $config.agents.defaults = @{} }
        if (-not $config.agents.defaults.model) { $config.agents.defaults.model = @{} }
        $config.agents.defaults.model.primary = "openrouter/stepfun/step-3.5-flash:free"
    }
    'stepfun' {
        $config.models.providers.stepfun = @{
            baseUrl = $BASE_URL
            apiKey = $API_KEY
            api = "openai-completions"
            models = @(
                @{
                    id = "stepfun/step-3.5-flash"
                    name = "Step 3.5 Flash"
                    api = "openai-completions"
                    reasoning = $false
                    input = @("text")
                    cost = @{
                        input = 0
                        output = 0
                        cacheRead = 0
                        cacheWrite = 0
                    }
                    contextWindow = 256000
                    maxTokens = 8192
                }
            )
        }
        if (-not $config.agents) { $config.agents = @{} }
        if (-not $config.agents.defaults) { $config.agents.defaults = @{} }
        if (-not $config.agents.defaults.model) { $config.agents.defaults.model = @{} }
        $config.agents.defaults.model.primary = "stepfun/step-3.5-flash"
    }
    'stepfun-plan' {
        $config.models.providers.'step-plan' = @{
            baseUrl = $BASE_URL
            apiKey = $API_KEY
            api = "openai-completions"
            models = @(
                @{
                    id = "step-plan/step-3.5-flash"
                    name = "Step 3.5 Flash"
                    api = "openai-completions"
                    reasoning = $false
                    input = @("text")
                    cost = @{
                        input = 0
                        output = 0
                        cacheRead = 0
                        cacheWrite = 0
                    }
                    contextWindow = 256000
                    maxTokens = 8192
                }
            )
        }
        if (-not $config.agents) { $config.agents = @{} }
        if (-not $config.agents.defaults) { $config.agents.defaults = @{} }
        if (-not $config.agents.defaults.model) { $config.agents.defaults.model = @{} }
        $config.agents.defaults.model.primary = "step-plan/step-3.5-flash"
    }
}

# 保存配置（保持 JSON 格式）
$config | ConvertTo-Json -Depth 10 | Out-File -FilePath $CONFIG_FILE -Encoding UTF8

Write-Host "  ✅ OpenClaw 配置已更新" -ForegroundColor Green
Write-Host ""
Write-Host "=========================================="
Write-Host "✨ 配置完成！" -ForegroundColor Green
Write-Host "=========================================="
Write-Host ""
Write-Host "📝 配置文件: $CONFIG_FILE"
Write-Host "📦 备份文件: $backup_file"
Write-Host ""
Write-Host "⚙️  当前配置："
$providerName = switch ($choice) {
    '1' { 'OpenRouter 免费版' }
    '2' { 'StepFun 官方 API' }
    '3' { 'StepFun Step Plan' }
}
Write-Host "   提供商: $providerName"
Write-Host "   API Key: $($API_KEY.Substring(0, [Math]::Min(10, $API_KEY.Length)))..."
Write-Host "   端点: $BASE_URL"
Write-Host "   模型: $DEFAULT_MODEL"
Write-Host ""
Write-Host "⚠️  重要：请重启 OpenClaw 使配置生效"
Write-Host ""
Write-Host "获取 API Key："
switch ($choice) {
    '1' { Write-Host "  OpenRouter: https://openrouter.ai/keys" }
    '2' { Write-Host "  StepFun: https://platform.stepfun.com/console/apikeys" }
    '3' { Write-Host "  StepFun: https://platform.stepfun.com/console/apikeys" }
}
Write-Host ""

Write-Host "按 Enter 键退出..."
[void][Console]::ReadKey($true)
