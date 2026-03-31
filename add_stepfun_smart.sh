#!/bin/bash

# OpenClaw StepFun 配置脚本
# 一行命令自动配置：curl ... | bash

set -e

# 检测 jq
if ! command -v jq &> /dev/null; then
    echo "错误：需要 jq"
    echo "安装：macOS: brew install jq | Ubuntu: apt install jq"
    exit 1
fi

# 自动查找配置文件
CONFIG_FILE="${STEPFUN_CONFIG:-$HOME/.openclaw/openclaw.json}"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/root/.openclaw/openclaw.json"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：找不到配置文件"
    echo "请确认 OpenClaw 已安装，或设置 STEPFUN_CONFIG 环境变量"
    exit 1
fi

# 备份
cp "$CONFIG_FILE" "$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"

# 确定模式和 API Key
if [ -n "$STEPFUN_MODE" ] && [ -n "$STEPFUN_API_KEY" ]; then
    # 非交互模式
    MODE="$STEPFUN_MODE"
    API_KEY="$STEPFUN_API_KEY"
else
    # 交互模式 - 显示菜单
    cat << EOF

==========================================
  OpenClaw 配置 - 添加 StepFun
==========================================

请选择接入方式：
  1) OpenRouter 免费版（免费，50 RPM）
  2) StepFun 官方 API（按量计费）
  3) StepFun Step Plan（订阅制）

EOF
    read -p "请输入数字 [1-3]: " choice
    case "$choice" in
        1) MODE="openrouter" ;;
        2) MODE="stepfun" ;;
        3) MODE="step-plan" ;;
        *) echo "无效选择"; exit 1 ;;
    esac
    read -p "请输入 API Key: " API_KEY
fi

# 配置
case "$MODE" in
    openrouter)
        jq --arg k "$API_KEY" '.models.providers.openrouter = {"baseUrl":"https://openrouter.ai/api/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash:free","name":"Step 3.5 Flash Free","reasoning":true,"input":["text"],"contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "openrouter/stepfun/step-3.5-flash:free"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ 已配置 OpenRouter 免费版"
        ;;
    stepfun)
        jq --arg k "$API_KEY" '.models.providers.stepfun = {"baseUrl":"https://api.stepfun.com/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"stepfun/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "stepfun/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ 已配置 StepFun 官方 API"
        ;;
    step-plan)
        jq --arg k "$API_KEY" '.models.providers."step-plan" = {"baseUrl":"https://api.stepfun.com/step_plan/v1","apiKey":$k,"api":"openai-completions","models":[{"id":"step-plan/step-3.5-flash","name":"Step 3.5 Flash","contextWindow":256000,"maxTokens":8192}]} | .agents.defaults.model.primary = "step-plan/step-3.5-flash"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✅ 已配置 StepFun Step Plan"
        ;;
    *) echo "错误：未知模式 $MODE"; exit 1 ;;
esac

echo "📝 配置已保存，重启 OpenClaw 生效"
