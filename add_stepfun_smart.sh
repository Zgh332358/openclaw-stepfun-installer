#!/bin/bash

# OpenClaw StepFun 配置脚本
# 支持：curl ... | bash （交互式）
# 自动检测 OpenClaw 安装位置

set -e

# 检查 jq
if ! command -v jq &> /dev/null; then
    echo "错误：需要 jq"
    echo "安装：macOS: brew install jq | Ubuntu/Debian: apt install jq"
    exit 1
fi

# 自动查找配置文件
CONFIG_FILE=""
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
elif [ -f "/root/.openclaw/openclaw.json" ]; then
    CONFIG_FILE="/root/.openclaw/openclaw.json"
elif [ -f "/usr/local/.openclaw/openclaw.json" ]; then
    CONFIG_FILE="/usr/local/.openclaw/openclaw.json"
else
    # 尝试通过 openclaw 可执行文件推断
    if command -v openclaw &> /dev/null; then
        OPENCLAW_PATH="$(command -v openclaw)"
        if [[ "$OPENCLAW_PATH" == "$HOME/.local/bin/openclaw" ]]; then
            CONFIG_FILE="$HOME/.openclaw/openclaw.json"
        fi
    fi
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：找不到 openclaw.json"
    echo "请确认 OpenClaw 已安装，或手动指定配置路径"
    exit 1
fi

echo "配置文件: $CONFIG_FILE"
echo ""

# 菜单
echo "=========================================="
echo "  OpenClaw 配置 - 添加 StepFun"
echo "=========================================="
echo ""
echo "请选择接入方式："
echo "  1) OpenRouter 免费版（免费，50 RPM）"
echo "  2) StepFun 官方 API（按量计费）"
echo "  3) StepFun Step Plan（订阅制）"
echo ""

# 读取选择
CHOICE=""
while true; do
    read -r -p "请输入数字选择 [1/2/3]: " CHOICE </dev/tty
    case "$CHOICE" in
        1|2|3) break ;;
        *) echo "无效输入，请输入 1、2 或 3" ;;
    esac
done

echo ""

# 读取 API Key
case "$CHOICE" in
    1) PROMPT="请输入 OpenRouter API Key（sk-or-v1-...）: " ;;
    2|3) PROMPT="请输入 StepFun API Key: " ;;
esac

API_KEY=""
while true; do
    printf "%s" "$PROMPT"
    read -r API_KEY </dev/tty
    if [ -n "$API_KEY" ]; then
        break
    else
        echo "API Key 不能为空，请重新输入"
    fi
done

# 备份
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
echo "已备份配置文件"
echo ""

# 应用配置
case "$CHOICE" in
    1)
        jq --arg k "$API_KEY" '.models.providers.openrouter = {"baseUrl":"https://openrouter.ai/api/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash:free","name":"Step 3.5 Flash Free","reasoning":true,"input":["text"],"contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "openrouter/stepfun/step-3.5-flash:free"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ OpenRouter 免费版已配置"
        echo "   模型: openrouter/stepfun/step-3.5-flash:free"
        echo "   限制: 50 RPM"
        ;;
    2)
        jq --arg k "$API_KEY" '.models.providers.stepfun = {"baseUrl":"https://api.stepfun.com/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "stepfun/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ StepFun 官方 API 已配置"
        echo "   模型: stepfun/step-3.5-flash"
        ;;
    3)
        jq --arg k "$API_KEY" '.models.providers."step-plan" = {"baseUrl":"https://api.stepfun.com/step_plan/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"step-plan/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "step-plan/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ StepFun Step Plan 已配置"
        echo "   模型: step-plan/step-3.5-flash"
        echo "   API: https://api.stepfun.com/step_plan/v1"
        ;;
esac

echo ""
echo "📝 配置已保存"
echo "  备份: $CONFIG_FILE.bak.*"
echo ""
echo "请重启 OpenClaw 使配置生效"
