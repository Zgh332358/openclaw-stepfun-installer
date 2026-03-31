#!/bin/bash

# OpenClaw StepFun 配置脚本
# 支持：curl ... | bash （交互式）
# 自动检测 OpenClaw 安装位置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 前置条件检查
check_prerequisites() {
    local all_ok=true

    echo "🔍 检查前置条件..."
    echo ""

    # 1. 检查 jq
    if command -v jq &> /dev/null; then
        echo -e "  ✅ jq: $(jq --version 2>&1 | head -1)"
    else
        echo -e "  ${RED}❌ jq: 未安装${NC}"
        echo ""
        echo -e "  ${YELLOW}安装方法：${NC}"
        echo "    macOS:  brew install jq"
        echo "    Ubuntu/Debian:  sudo apt update && sudo apt install jq"
        echo "    CentOS/RHEL:  sudo yum install jq"
        echo "    Alpine:  apk add jq"
        all_ok=false
    fi

    # 2. 检查 bash
    if [ -n "$BASH_VERSION" ]; then
        echo -e "  ✅ bash: $BASH_VERSION"
    else
        echo -e "  ${RED}❌ bash: 当前不是 bash 环境${NC}"
        all_ok=false
    fi

    # 3. 检查 OpenClaw 可执行文件（可选，仅提示）
    if command -v openclaw &> /dev/null; then
        echo -e "  ✅ openclaw: $(command -v openclaw)"
    else
        echo -e "  ${YELLOW}⚠️  openclaw: 未在 PATH 中找到（可能不影响使用）${NC}"
    fi

    # 4. 检查配置文件（不强制，可以自动创建）
    CONFIG_FILE=""
    if [ -f "$HOME/.openclaw/openclaw.json" ]; then
        CONFIG_FILE="$HOME/.openclaw/openclaw.json"
        echo -e "  ✅ 配置文件: $CONFIG_FILE"
    elif [ -f "/root/.openclaw/openclaw.json" ]; then
        CONFIG_FILE="/root/.openclaw/openclaw.json"
        echo -e "  ✅ 配置文件: $CONFIG_FILE"
    elif [ -f "/usr/local/.openclaw/openclaw.json" ]; then
        CONFIG_FILE="/usr/local/.openclaw/openclaw.json"
        echo -e "  ✅ 配置文件: $CONFIG_FILE"
    else
        echo -e "  ${YELLOW}⚠️  配置文件: 未找到${NC}"
        echo ""
        echo -e "  ${BLUE}提示：${NC}"
        echo "    - 如果 OpenClaw 未运行过，这是正常的"
        echo "    - 脚本将在配置时创建基础配置文件"
        echo "    - 或使用 -c 参数指定配置文件路径"
        all_ok=false  # 改为警告，不影响继续
    fi

    echo ""

    if [ "$all_ok" = false ]; then
        echo -e "${RED}❌ 前置条件检查失败，请解决上述问题后重试${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ 所有前置条件检查通过！${NC}"
    echo ""
}

# 自动查找配置文件
find_config_file() {
    # 如果用户通过 -c 指定了配置，优先使用
    if [ -n "$STEPFUN_CONFIG" ] && [ -f "$STEPFUN_CONFIG" ]; then
        echo "$STEPFUN_CONFIG"
        return 0
    fi

    # 检查常见位置
    local candidates=(
        "$HOME/.openclaw/openclaw.json"
        "/root/.openclaw/openclaw.json"
        "/usr/local/.openclaw/openclaw.json"
        "/opt/openclaw/.openclaw/openclaw.json"
    )

    for cfg in "${candidates[@]}"; do
        if [ -f "$cfg" ]; then
            echo "$cfg"
            return 0
        fi
    done

    # 尝试通过 openclaw 路径推断
    if command -v openclaw &> /dev/null; then
        local exe_path
        exe_path="$(command -v openclaw)"
        if [[ "$exe_path" == "$HOME/.local/bin/openclaw" ]]; then
            local inferred="$HOME/.openclaw/openclaw.json"
            if [ -f "$inferred" ]; then
                echo "$inferred"
                return 0
            fi
        fi
    fi

    return 1
}

# ========== 主程序开始 ==========

# 1. 检查前置条件
check_prerequisites

# 2. 确定配置文件（如果不存在则自动创建）
CONFIG_FILE="$(find_config_file 2>/dev/null || true)"

if [ -z "$CONFIG_FILE" ]; then
    # 未找到配置文件，创建基础配置
    echo -e "${YELLOW}⚠️  未找到配置文件，将自动创建${NC}"

    # 确定配置目录（优先用户目录）
    CONFIG_DIR="$HOME/.openclaw"
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        echo "📁 创建配置目录: $CONFIG_DIR"
    fi

    CONFIG_FILE="$CONFIG_DIR/openclaw.json"

    # 创建基础配置文件
    cat > "$CONFIG_FILE" << 'EOF'
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
EOF
    echo "✅ 已创建基础配置文件: $CONFIG_FILE"
    echo ""
fi

# 验证配置文件是有效的 JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${RED}❌ 配置文件不是有效的 JSON: $CONFIG_FILE${NC}"
    exit 1
fi

echo "📁 使用配置文件: $CONFIG_FILE"
echo ""

# 3. 菜单
echo "=========================================="
echo "  OpenClaw 配置 - 添加 StepFun"
echo "=========================================="
echo ""
echo "请选择接入方式："
echo "  1) OpenRouter 免费版（免费，50 RPM 限制）"
echo "  2) StepFun 官方 API（按量计费）"
echo "  3) StepFun Step Plan（订阅制）"
echo ""

# 4. 读取选择（使用 /dev/tty 支持管道执行）
CHOICE=""
while true; do
    printf "请输入数字 [1-3]: "
    if read -r CHOICE </dev/tty 2>/dev/null; then
        case "$CHOICE" in
            1|2|3) break ;;
            *) echo "无效输入，请输入 1、2 或 3" ;;
        esac
    else
        echo ""
        echo -e "${RED}❌ 无法读取输入${NC}"
        echo "请勿使用 'curl ... | bash' 方式，应先下载脚本再运行："
        echo "  curl -O <脚本URL>"
        echo "  bash add_stepfun_smart.sh"
        exit 1
    fi
done

echo ""

# 5. 读取 API Key
case "$CHOICE" in
    1) PROMPT="请输入 OpenRouter API Key（sk-or-v1-...）: " ;;
    2|3) PROMPT="请输入 StepFun API Key: " ;;
esac

API_KEY=""
while true; do
    printf "%s" "$PROMPT"
    if read -r API_KEY </dev/tty 2>/dev/null; then
        if [ -n "$API_KEY" ]; then
            break
        else
            echo "API Key 不能为空，请重新输入"
        fi
    else
        echo ""
        echo -e "${RED}❌ 无法读取输入${NC}"
        echo "请先下载脚本再运行"
        exit 1
    fi
done

echo ""

# 6. 备份配置
echo "📦 正在备份配置文件..."
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
echo "   备份文件: $CONFIG_FILE.bak.*"
echo ""

# 7. 应用配置
echo "⚙️  正在配置..."
case "$CHOICE" in
    1)
        jq --arg k "$API_KEY" '.models.providers.openrouter = {"baseUrl":"https://openrouter.ai/api/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash:free","name":"Step 3.5 Flash Free","reasoning":true,"input":["text"],"contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "openrouter/stepfun/step-3.5-flash:free"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "  ${GREEN}✅ OpenRouter 免费版已配置${NC}"
        echo "    模型: openrouter/stepfun/step-3.5-flash:free"
        echo "    限制: 50 RPM"
        echo "    官网: https://openrouter.ai"
        ;;
    2)
        jq --arg k "$API_KEY" '.models.providers.stepfun = {"baseUrl":"https://api.stepfun.com/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "stepfun/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "  ${GREEN}✅ StepFun 官方 API 已配置${NC}"
        echo "    模型: stepfun/step-3.5-flash"
        echo "    官网: https://platform.stepfun.com"
        ;;
    3)
        jq --arg k "$API_KEY" '.models.providers."step-plan" = {"baseUrl":"https://api.stepfun.com/step_plan/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"step-plan/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "step-plan/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo -e "  ${GREEN}✅ StepFun Step Plan 已配置${NC}"
        echo "    模型: step-plan/step-3.5-flash"
        echo "    API: https://api.stepfun.com/step_plan/v1"
        echo "    官网: https://platform.stepfun.com/step-plan"
        ;;
esac

echo ""
echo "=========================================="
echo -e "${GREEN}✨ 配置完成！${NC}"
echo "=========================================="
echo ""
echo "📝 配置文件: $CONFIG_FILE"
echo "📦 备份文件: $CONFIG_FILE.bak.*"
echo ""
echo "⚠️  重要：请重启 OpenClaw 使配置生效"
echo ""
echo "获取 API Key："
case "$CHOICE" in
    1) echo "  OpenRouter: https://openrouter.ai/keys" ;;
    2|3) echo "  StepFun: https://platform.stepfun.com/console/apikeys" ;;
esac
echo ""
