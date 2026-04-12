# Scholar Setup - CPU VPS 科研全栈环境

**适用于无 GPU 的 Linux VPS（Ubuntu 22.04/24.04）的一键式科研环境部署方案**

通过智谱 GLM API 云端调用 LLM，无需本地 GPU，即可构建完整的 AI 辅助科研工作环境。

## ✨ 核心特性

### 🤖 AI 智能体
- **OpenClaw 智能体**：基于 zai/glm-5.1 模型的科研助手，支持从研究想法到可发表结果的全程辅助
- **Claude Code**：集成 Anthropic Claude API 的代码助手，支持智能编程辅助
- **Open WebUI**：ChatGPT 风格的 Web 界面，支持多模型切换

### 📊 数据分析与可视化
- **JupyterLab**：经典交互式笔记本环境
- **Marimo**：新一代响应式笔记本，支持实时计算
- **Python 科研栈**：pandas, numpy, scipy, matplotlib, seaborn, plotly, scikit-learn, xgboost, lightgbm
- **NLP 工具包**：transformers, datasets, jieba, nltk, wordcloud

### 🗄️ 数据存储与检索
- **PostgreSQL 16 + pgvector**：支持向量检索的关系型数据库
- **Redis**：高性能缓存和消息队列
- **MinIO**：S3 兼容的对象存储服务
- **pgweb**：PostgreSQL Web 可视化管理界面

### ⚙️ 工作流与自动化
- **n8n**：可视化工作流编排引擎
- **Telegram + 飞书通知**：实时消息推送集成

### 💻 开发环境
- **code-server**：VS Code Web 版本，支持远程开发
- **Node.js 22 LTS**：JavaScript/TypeScript 运行时
- **pnpm/yarn/tsx**：现代前端工具链

## 🏗️ 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      VPS 科研环境                             │
├─────────────────────────────────────────────────────────────┤
│  AI 智能层                                                   │
│  ├── OpenClaw (zai/glm-5.1)    :18789                      │
│  ├── Claude Code                  :8081                     │
│  └── Open WebUI                  :3000                      │
├─────────────────────────────────────────────────────────────┤
│  开发与计算层                                                 │
│  ├── code-server (VS Code)      :8081                     │
│  ├── JupyterLab                  :8888                     │
│  └── Marimo                      :2718                     │
├─────────────────────────────────────────────────────────────┤
│  工作流与自动化                                               │
│  └── n8n                        :5678                     │
├─────────────────────────────────────────────────────────────┤
│  数据存储层                                                   │
│  ├── PostgreSQL + pgvector      :5432                     │
│  ├── Redis                       :6379                     │
│  └── MinIO API                  :9000 / Console :9001       │
├─────────────────────────────────────────────────────────────┤
│  管理工具                                                     │
│  └── pgweb (DB 管理)             :5050                     │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 快速开始

### 系统要求
- **操作系统**：Ubuntu 22.04 或 24.04
- **架构**：x86_64/amd64 或 aarch64/arm64
- **内存**：建议 ≥ 4GB
- **磁盘**：建议 ≥ 40GB

### 一键安装

```bash
bash /workspace/vps_setup.sh 2>&1 | tee /workspace/logs/vps_setup.log
```

### 后续管理

**启动所有服务：**
```bash
bash /workspace/start_all.sh
```

**检查环境状态：**
```bash
bash /workspace/check_env.sh
```

## 🔑 服务访问

安装完成后，可通过以下端口访问各项服务：

| 服务 | 端口 | 默认凭证 | 用途 |
|------|------|----------|------|
| code-server | 8081 | pzNPIjcC71MmLTLPA0vM2JjL | VS Code Web 版 |
| JupyterLab | 8888 | token: scholar2026 | 交互式笔记本 |
| Marimo | 2718 | 无需认证 | 响应式笔记本 |
| n8n | 5678 | 无需认证 | 工作流引擎 |
| Open WebUI | 3000 | 无需认证 | LLM 聊天界面 |
| OpenClaw Gateway | 18789 | - | AI 智能体 API |
| pgweb | 5050 | - | 数据库管理 |
| PostgreSQL | 5432 | postgres/scholar2026 | 关系型数据库 |
| Redis | 6379 | 密码: scholar2026 | 缓存/队列 |
| MinIO API | 9000 | minioadmin/scholar2026 | 对象存储 API |
| MinIO Console | 9001 | minioadmin/scholar2026 | 存储管理界面 |

## 📁 目录结构

```
/workspace/
├── venv/              # Python 虚拟环境
├── pgdata/            # PostgreSQL 数据目录
├── redis_data/        # Redis 数据目录
├── minio_data/        # MinIO 存储数据
├── n8n_data/          # n8n 工作流数据
├── code-server/       # code-server 配置和扩展
├── jupyter/           # JupyterLab 配置
├── .openclaw/         # OpenClaw 智能体配置
├── logs/              # 服务日志
├── .env               # 环境变量配置
├── start_all.sh       # 服务启动脚本
└── check_env.sh       # 环境检查脚本
```

## ⚙️ 配置说明

### API 密钥配置

智谱 API 密钥已自动配置到以下位置：
- **环境变量**：`ZHIPU_API_KEY` (在 ~/.bashrc 中)
- **OpenClaw**：`~/.openclaw/workspace/config.json`
- **Claude Code**：`~/.claude/settings.json`

### 通知配置

Telegram 和飞书通知配置位于 `/workspace/.env`：
- `TELEGRAM_BOT_TOKEN`：Telegram 机器人令牌
- `TELEGRAM_CHAT_ID`：Telegram 聊天 ID
- `FEISHU_WEBHOOK_URL`：飞书 Webhook 地址
- `FEISHU_APP_ID`：飞书应用 ID
- `FEISHU_APP_SECRET`：飞书应用密钥

## 🐛 故障排除

### 服务未启动

1. **检查服务状态：**
   ```bash
   bash /workspace/check_env.sh
   ```

2. **查看服务日志：**
   ```bash
   # PostgreSQL
   tail -f /workspace/logs/postgresql.log
   
   # Redis
   tail -f /workspace/logs/redis.log
   
   # JupyterLab
   tail -f /workspace/logs/jupyter.log
   
   # 其他服务日志在 /workspace/logs/ 目录
   ```

3. **手动启动服务：**
   ```bash
   bash /workspace/start_all.sh
   ```

### 端口冲突

如果默认端口被占用，可修改相应服务的配置文件：
- code-server: `/workspace/code-server/config/config.yaml`
- JupyterLab: `/workspace/jupyter/config/jupyter_lab_config.py`
- n8n: 环境变量 `N8N_PORT`

### Python 环境问题

确保使用正确的 Python 环境：
```bash
source /workspace/venv/bin/activate
which python  # 应显示 /workspace/venv/bin/python
```

## 🔧 开发指南

### 使用 Claude Code

```bash
# 确保 PATH 正确配置
export PATH="/usr/local/lib/nodejs/bin:$PATH"

# 启动 Claude Code
claude
```

### 使用 OpenClaw 智能体

```bash
# 确保 API 密钥已配置
echo $ZHIPU_API_KEY

# 启动 OpenClaw Gateway（如果未运行）
openclaw gateway
```

### JupyterLab 使用

访问 `http://your-vps-ip:8888`，使用密码 `scholar2026` 登录。

## 📊 性能优化建议

1. **内存优化**：如果 VPS 内存较小（< 4GB），可考虑：
   - 减少 JupyterLab 内核数量
   - 调整 PostgreSQL shared_buffers
   - 限制 Redis 最大内存

2. **存储优化**：
   - 定期清理日志文件
   - 配置 MinIO 生命周期策略
   - 使用 PostgreSQL 定期清理

3. **网络优化**：
   - 配置反向代理（Nginx）
   - 启用 HTTPS（使用 Let's Encrypt）
   - 配置防火墙规则

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证。

## 🙏 致谢

- [智谱 AI](https://open.bigmodel.cn/) - 提供 GLM API 服务
- [OpenClaw](https://github.com/openclaw-org/openclaw) - AI 智能体框架
- [Anthropic](https://www.anthropic.com/) - Claude API
- [n8n](https://n8n.io/) - 工作流自动化平台

---

**最后更新**：2026-04-12  
**维护者**：liubin18911671739
