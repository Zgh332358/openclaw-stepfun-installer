#!/bin/bash

# OpenClaw StepFun 配置脚本
# 支持：curl ... | bash （通过环境变量或参数传参）

set -e

# 配置（可通过环境变量覆盖）
CONFIG_FILE="${STEPFUN_CONFIG:-$HOME/.openclaw/openclaw.json}"
if [ ! -f "$CONFIG_FILE" ] && [ -f "/root/.openclaw/openclaw.json" ]; then
    CONFIG_FILE="/root/.openclaw/openclaw.json"
fi

# 解析参数（支持 bash -s -- --mode xxx --api-key xxx）
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config) CONFIG_FILE="$2"; shift 2 ;;
        -m|--mode) MODE="$2"; shift 2 ;;
        -k|--api-key) API_KEY="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# 也支持环境变量
MODE="${MODE:-${STEPFUN_MODE:-}}"
API_KEY="${API_KEY:-${STEPFUN_API_KEY:-}}"

# 检查 jq
if ! command -v jq &> /dev/null; then
    echo "错误：需要 jq"
    exit 1
fi

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：找不到配置文件: $CONFIG_FILE"
    echo "请使用 -c 指定，或确认 OpenClaw 已安装"
    exit 1
fi

# 检查必填参数
if [ -z "$MODE" ] || [ -z "$API_KEY" ]; then
    echo "用法1（环境变量）："
    echo "  STEPFUN_MODE=openrouter STEPFUN_API_KEY=xxx curl ... | bash"
    echo ""
    echo "用法2（参数）："
    echo "  curl ... | bash -s -- --mode openrouter --api-key xxx"
    echo ""
    echo "模式：openrouter | stepfun | step-plan"
    exit 1
fi

# 备份
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"

# 配置
case "$MODE" in
    openrouter|1)
        jq --arg k "$API_KEY" '.models.providers.openrouter = {"baseUrl":"https://openrouter.ai/api/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash:free","name":"Step 3.5 Flash Free","reasoning":true,"input":["text"],"contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "openrouter/stepfun/step-3.5-flash:free"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ OpenRouter 免费版已配置"
        ;;
    stepfun|2)
        jq --arg k "$API_KEY" '.models.providers.stepfun = {"baseUrl":"https://api.stepfun.com/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "stepfun/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ StepFun 官方 API 已配置"
        ;;
    step-plan|3)
        jq --arg k "$API_KEY" '.models.providers."step-plan" = {"baseUrl":"https://api.stepfun.com/step_plan/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"step-plan/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "step-plan/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ StepFun Step Plan 已配置"
        ;;
    *) echo "错误：未知模式 '$MODE'。支持：openrouter, stepfun, step-plan (或 1,2,3)"; exit 1 ;;
esac

echo "📝 配置已保存至: $CONFIG_FILE"
echo "  请重启 OpenClaw 使配置生效"
