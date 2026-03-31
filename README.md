# OpenClaw StepFun 智能配置脚本

智能检测 OpenClaw 安装位置并自动配置 StepFun 3.5 Flash 模型。

## 特性

- ✅ **自动检测** OpenClaw 安装路径（支持任意位置）
- ✅ **智能推断** 配置文件位置
- ✅ **跨平台** 支持（macOS / Linux）
- ✅ **安全备份** 自动备份配置文件
- ✅ **多种接入方式** 支持 4 种 StepFun 接入方式

## 快速开始

### 一键安装

```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh | bash
```

### 手动安装

1. 下载脚本：
```bash
curl -fsSL https://raw.githubusercontent.com/Zgh332358/openclaw-stepfun-installer/main/add_stepfun_smart.sh -o add_stepfun_smart.sh
chmod +x add_stepfun_smart.sh
```

2. 运行脚本：
```bash
./add_stepfun_smart.sh
```

## 使用方法

### 自动检测（推荐）
```bash
bash add_stepfun_smart.sh
```
脚本会自动：
- 查找 `openclaw` 可执行文件
- 定位配置文件 `openclaw.json`
- 引导你完成 StepFun 配置

### 指定配置文件
```bash
bash add_stepfun_smart.sh -c /path/to/openclaw.json
```

### 指定可执行文件
```bash
bash add_stepfun_smart.sh -e /usr/local/bin/openclaw
```

### 查看帮助
```bash
bash add_stepfun_smart.sh -h
```

## 支持的接入方式

| 选项 | 说明 | 费用 | 限制 |
|------|------|------|------|
| 1 | OpenRouter 免费版 | 免费 | 50 RPM |
| 2 | StepFun 官方 API | 按量计费 | 无 |
| 3 | StepFun Step Plan | 订阅制 | 需订阅 |
| 4 | step-3.5-flash-2603 | 按量计费 | 无 |

## 支持的安装场景

| OpenClaw 安装位置 | 配置文件位置 | 支持状态 |
|-------------------|-------------|----------|
| `~/.local/bin/openclaw` | `~/.openclaw/openclaw.json` | ✅ |
| `/usr/local/bin/openclaw` | `~/.openclaw/` 或 `/root/.openclaw/` | ✅ |
| 任意自定义路径 | 通过 `-c` 参数指定 | ✅ |

## 工作原理

1. **检测可执行文件**：扫描 `PATH`、常见安装位置、用户目录
2. **推断配置路径**：基于可执行文件位置推断 `.openclaw/` 目录
3. **验证配置**：检查 JSON 格式和文件权限
4. **自动备份**：创建带时间戳的备份文件
5. **修改配置**：使用 `jq` 更新 JSON 配置
6. **重启提示**：可选重启 OpenClaw 使配置生效

## 依赖要求

- **jq**：JSON 处理工具
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt install jq`
  - CentOS/RHEL: `sudo yum install jq`

## 安全说明

- 脚本会**自动备份**原始配置文件（`.bak.YYYYMMDDHHMMSS`）
- 只修改 `openclaw.json`，不修改其他文件
- 不会上传任何数据到外部服务器
- API Key 仅保存到本地配置文件

## 故障排除

### 配置文件未找到
使用 `-c` 参数手动指定：
```bash
bash add_stepfun_smart.sh -c /your/custom/path/openclaw.json
```

### jq 未安装
先安装 jq，再运行脚本。

### 权限错误
确保对配置目录有读写权限：
```bash
chmod u+rw ~/.openclaw/openclaw.json
```

## License

MIT License - 自由使用、修改和分享

## 原项目

- OpenClaw: https://github.com/openharmony-3.0/OpenClaw
- 原版脚本: https://github.com/Daiyimo/openclaw-napcat
