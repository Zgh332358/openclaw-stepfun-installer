#!/bin/bash

# 脚本用途：智能检测 OpenClaw 安装位置并添加 StepFun 3.5 Flash 模型
# 支持：自动查找、手动指定路径、跨平台（macOS/Linux）

set -e

# 检测是否通过管道运行（不支持，因为需要交互输入）
if [ ! -t 0 ]; then
    echo "❌ 错误：此脚本需要交互式终端"
    echo ""
    echo "检测到您使用了管道执行方式：curl ... | bash"
    echo "这种方*** interact with the terminal，请改用以下方式："
    echo ""
    echo "【推荐】方法1：先下载，再运行"
    echo "  curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh -o add_stepfun_smart.sh"
    echo "  chmod +x add_stepfun_smart.sh"
    echo "  ./add_stepfun_smart.sh"
    echo ""
    echo "【或】方法2：直接运行本地脚本"
    echo "  如果已经下载，直接运行：bash add_stepfun_smart.sh"
    echo ""
    echo "【或】方法3：使用 bash -c（某些环境可能支持）"
    echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh)\""
    echo ""
    exit 1
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 常见配置文件位置
COMMON_CONFIG_PATHS=(
    "$HOME/.openclaw/openclaw.json"
    "/root/.openclaw/openclaw.json"
    "/usr/local/.openclaw/openclaw.json"
    "/opt/openclaw/.openclaw/openclaw.json"
    "$HOME/.config/openclaw/openclaw.json"
)

# 打印用法
print_usage() {
    cat << EOF
用法: $0 [选项]

自动检测 OpenClaw 安装位置并添加 StepFun 模型配置

选项:
  -c, --config PATH    指定配置文件路径
  -e, --executable PATH 指定 openclaw 可执行文件路径
  -h, --help           显示此帮助信息

示例:
  $0                                    # 自动检测并配置
  $0 -c /custom/path/openclaw.json     # 使用指定配置文件
  $0 -e /usr/local/bin/openclaw        # 从可执行文件推断配置路径

EOF
}

# 解析命令行参数
CONFIG_PATH=""
EXECUTABLE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        -e|--executable)
            EXECUTABLE_PATH="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            print_usage
            exit 1
            ;;
    esac
done

# 检查 jq 是否安装
if ! command -v jq &> /dev/null; then
    log_error "需要 jq 工具来操作 JSON 配置文件"
    echo "安装方法："
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt install jq"
    echo "  CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# 查找 openclaw 可执行文件
find_openclaw_executable() {
    local exe_path=""

    # 1. 检查 PATH 中是否有 openclaw
    if command -v openclaw &> /dev/null; then
        exe_path="$(command -v openclaw)"
        echo "$exe_path"
        return 0
    fi

    # 2. 常见安装位置
    local common_paths=(
        "$HOME/.local/bin/openclaw"
        "/usr/local/bin/openclaw"
        "/usr/bin/openclaw"
        "/opt/openclaw/bin/openclaw"
    )

    for path in "${common_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    # 3. 搜索用户目录
    if [ -n "$HOME" ]; then
        local found
        found="$(find "$HOME" -type f -name "openclaw" 2>/dev/null | head -1)"
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    fi

    return 1
}

# 从可执行文件路径推断配置路径（只返回路径，不输出日志）
infer_config_from_executable() {
    local exe_path="$1"
    local config_dir=""

    # 方法1: 如果是 ~/.local/bin/openclaw，配置可能在 ~/.openclaw/
    if [[ "$exe_path" == "$HOME/.local/bin/openclaw" ]]; then
        config_dir="$HOME/.openclaw"
    # 方法2: 如果是 /usr/local/bin/openclaw，可能在 /root/.openclaw 或 ~/.openclaw
    elif [[ "$exe_path" == "/usr/local/bin/openclaw" ]]; then
        if [ -f "$HOME/.openclaw/openclaw.json" ]; then
            config_dir="$HOME/.openclaw"
        elif [ -f "/root/.openclaw/openclaw.json" ]; then
            config_dir="/root/.openclaw"
        fi
    # 方法3: 其他位置，查找同级目录
    else
        local base_dir
        base_dir="$(dirname "$exe_path")/.."
        if [ -f "$base_dir/.openclaw/openclaw.json" ]; then
            config_dir="$base_dir/.openclaw"
        fi
    fi

    if [ -n "$config_dir" ] && [ -f "$config_dir/openclaw.json" ]; then
        echo "$config_dir/openclaw.json"
        return 0
    fi

    return 1
}

# 查找配置文件（只返回路径，不输出日志）
find_config_file() {
    local inferred_config=""

    # 1. 使用指定路径
    if [ -n "$CONFIG_PATH" ]; then
        if [ -f "$CONFIG_PATH" ]; then
            echo "$CONFIG_PATH"
            return 0
        else
            log_error "指定的配置文件不存在: $CONFIG_PATH"
            exit 1
        fi
    fi

    # 2. 如果指定了可执行文件，尝试推断
    if [ -n "$EXECUTABLE_PATH" ]; then
        if [ ! -x "$EXECUTABLE_PATH" ]; then
            log_error "指定的可执行文件不存在或不可执行: $EXECUTABLE_PATH"
            exit 1
        fi
        inferred_config="$(infer_config_from_executable "$EXECUTABLE_PATH" 2>/dev/null)"
        if [ -n "$inferred_config" ]; then
            echo "$inferred_config"
            return 0
        fi
    fi

    # 3. 检查常见位置
    for path in "${COMMON_CONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    # 4. 如果找到 openclaw 可执行文件，再次尝试推断
    local exe
    exe="$(find_openclaw_executable 2>/dev/null)"
    if [ -n "$exe" ]; then
        inferred_config="$(infer_config_from_executable "$exe")"
        if [ -n "$inferred_config" ]; then
            echo "$inferred_config"
            return 0
        fi
    fi

    log_error "未找到 openclaw 配置文件"
    echo "请使用 -c 选项指定配置文件路径，或确保 OpenClaw 已正确安装"
    exit 1
}

# 验证配置文件
validate_config() {
    local config_file="$1"

    if [ ! -r "$config_file" ]; then
        log_error "配置文件不可读: $config_file"
        exit 1
    fi

    # 检查是否是有效的 JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "配置文件不是有效的 JSON: $config_file"
        exit 1
    fi
}

# 备份配置文件
backup_config() {
    local config_file="$1"
    local backup_file="${config_file}.bak.$(date +%Y%m%d%H%M%S)"

    cp "$config_file" "$backup_file"
    log_success "已备份配置文件: $backup_file"
}

# 主菜单
show_menu() {
    cat << EOF

==========================================
  OpenClaw 配置 - 添加 StepFun 3.5 Flash
==========================================

请选择接入方式：
  1) OpenRouter 免费版（无需付费，有速率限制 50 RPM）
  2) StepFun 官方 API（按量计费，需要官方 API Key）
  3) StepFun Step Plan（需订阅 Step Plan）

EOF
}

# 获取用户选择
get_choice() {
    local choice=""
    while true; do
        printf "请输入数字选择 [1/2/3]: "
        read -r choice </dev/tty
        case "$choice" in
            1|2|3) echo "$choice"; return 0 ;;
            *) echo "无效输入，请输入 1、2 或 3" ;;
        esac
    done
}

# 获取 API Key
get_apikey() {
    local choice="$1"
    local prompt=""
    local apikey=""

    case "$choice" in
        1) prompt="请输入 OpenRouter API Key（sk-or-v1-...）: " ;;
        2|3) prompt="请输入 StepFun API Key: " ;;
    esac

    while true; do
        printf "%s" "$prompt"
        read -r apikey </dev/tty
        if [ -n "$apikey" ]; then
            echo "$apikey"
            return 0
        else
            echo "API Key 不能为空，请重新输入"
        fi
    done
}

# 配置 OpenRouter 免费版
config_openrouter() {
    local config_file="$1"
    local apikey="$2"

    jq --arg apikey "$apikey" '
        .models.providers.openrouter = {
            "baseUrl": "https://openrouter.ai/api/v1",
            "apiKey": $apikey,
            "api": "openai-completions",
            "models": [
                {
                    "id": "stepfun/step-3.5-flash:free",
                    "name": "Step 3.5 Flash Free",
                    "api": "openai-completions",
                    "reasoning": true,
                    "input": ["text"],
                    "cost": {
                        "input": 0,
                        "output": 0,
                        "cacheRead": 0,
                        "cacheWrite": 0
                    },
                    "contextWindow": 256000,
                    "maxTokens": 8192
                }
            ]
        } |
        .agents.defaults.model.primary = "openrouter/stepfun/step-3.5-flash:free"
    ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

    log_success "配置更新完成！"
    echo "  - 已添加 OpenRouter StepFun 3.5 Flash Free"
    echo "  - 默认模型: openrouter/stepfun/step-3.5-flash:free"
    echo "  - 速率限制: 50 RPM"
}

# 配置 StepFun 官方 API
config_stepfun_official() {
    local config_file="$1"
    local apikey="$2"

    jq --arg apikey "$apikey" '
        .models.providers.stepfun = {
            "baseUrl": "https://api.stepfun.com/v1",
            "apiKey": $apikey,
            "api": "openai-completions",
            "models": [
                {
                    "id": "stepfun/step-3.5-flash",
                    "name": "Step 3.5 Flash",
                    "api": "openai-completions",
                    "reasoning": false,
                    "input": ["text"],
                    "cost": {
                        "input": 0,
                        "output": 0,
                        "cacheRead": 0,
                        "cacheWrite": 0
                    },
                    "contextWindow": 256000,
                    "maxTokens": 8192
                }
            ]
        } |
        .agents.defaults.model.primary = "stepfun/step-3.5-flash"
    ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

    log_success "配置更新完成！"
    echo "  - 已添加 StepFun 3.5 Flash"
    echo "  - 默认模型: stepfun/step-3.5-flash"
}

# 配置 StepFun Step Plan
config_stepfun_plan() {
    local config_file="$1"
    local apikey="$2"

    jq --arg apikey "$apikey" '
        .models.providers."step-plan" = {
            "baseUrl": "https://api.stepfun.com/step_plan/v1",
            "apiKey": $apikey,
            "api": "openai-completions",
            "models": [
                {
                    "id": "step-plan/step-3.5-flash",
                    "name": "Step 3.5 Flash",
                    "api": "openai-completions",
                    "reasoning": false,
                    "input": ["text"],
                    "cost": {
                        "input": 0,
                        "output": 0,
                        "cacheRead": 0,
                        "cacheWrite": 0
                    },
                    "contextWindow": 256000,
                    "maxTokens": 8192
                }
            ]
        } |
        .agents.defaults.model.primary = "step-plan/step-3.5-flash"
    ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

    log_success "配置更新完成！"
    echo "  - 已添加 StepFun Step Plan"
    echo "  - 默认模型: step-plan/step-3.5-flash"
    echo "  - API 地址: https://api.stepfun.com/step_plan/v1"
}

# 重启 openclaw（可选）
restart_openclaw() {
    local exe_path="$1"

    if ! pgrep -f "openclaw" > /dev/null 2>&1; then
        log_info "OpenClaw 未在运行，无需重启"
        return 0
    fi

    log_warn "检测到 OpenClaw 正在运行"
    printf "是否重启 OpenClaw 使配置生效？ [y/N]: "
    read -r restart_choice </dev/tty
    if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        log_info "正在重启 OpenClaw..."

        # 尝试优雅停止
        if command -v openclaw &> /dev/null; then
            # 查找进程 ID
            local pids
            pids="$(pgrep -f "openclaw")"
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    log_info "停止进程: $pid"
                    kill "$pid" 2>/dev/null || true
                done
                sleep 2
            fi
        fi

        # 重新启动（后台）
        if [ -x "$exe_path" ]; then
            log_info "启动 OpenClaw: $exe_path"
            nohup "$exe_path" > /dev/null 2>&1 &
            log_success "OpenClaw 已重启"
        else
            log_warn "无法自动重启，请手动重启 OpenClaw"
        fi
    else
        log_info "请稍后手动重启 OpenClaw 使配置生效"
    fi
}

# ========== 主程序 ==========

# 显示检测到的信息
log_info "开始检测 OpenClaw 安装..."

# 查找配置文件（只获取路径，不包含日志）
CONFIG_FILE="$(find_config_file 2>/dev/null)"
log_success "使用配置文件: $CONFIG_FILE"

# 验证配置
validate_config "$CONFIG_FILE"

# 备份配置
backup_config "$CONFIG_FILE"

# 查找可执行文件（可选，用于重启）
if [ -z "$EXECUTABLE_PATH" ]; then
    EXECUTABLE_PATH="$(find_openclaw_executable 2>/dev/null)"
    if [ -n "$EXECUTABLE_PATH" ]; then
        log_info "检测到 OpenClaw 可执行文件: $EXECUTABLE_PATH"
    fi
else
    log_info "使用指定可执行文件: $EXECUTABLE_PATH"
fi

# 显示菜单
show_menu

# 获取用户选择
CHOICE="$(get_choice)"

# 获取 API Key
API_KEY="$(get_apikey "$CHOICE")"

echo ""
log_info "配置文件: $CONFIG_FILE"
log_info "API Key: ${API_KEY:0:10}..."
echo ""

# 根据选择执行配置
case "$CHOICE" in
    1)
        config_openrouter "$CONFIG_FILE" "$API_KEY"
        ;;
    2)
        config_stepfun_official "$CONFIG_FILE" "$API_KEY"
        ;;
    3)
        config_stepfun_plan "$CONFIG_FILE" "$API_KEY"
        ;;
esac

# 重启提示
if [ -n "$EXECUTABLE_PATH" ]; then
    restart_openclaw "$EXECUTABLE_PATH"
fi

log_success "配置完成！"
