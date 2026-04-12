#!/bin/bash
#=============================================================================
# vps_setup.sh — CPU VPS 科研全栈环境一键安装
# 适用：Ubuntu 22.04/24.04 无 GPU VPS · LLM 通过智谱 GLM API 云端调用
# 用法：bash /workspace/vps_setup.sh 2>&1 | tee /workspace/logs/vps_setup.log
#=============================================================================
# Guard: abort if accidentally run by Python
if command -v python3 &>/dev/null && [ "$(ps -p $$ -o comm=)" != "bash" ] 2>/dev/null; then
    echo "ERROR: This script must be run with bash, not python."
    echo "Usage: bash /workspace/vps_setup.sh"
    exit 1
fi
set -euo pipefail

	RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0; FAILED_ITEMS=()
WORK="/workspace"

log()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; ((PASS++)) || true; }
fail() { echo -e "  ${RED}❌ $1${NC}"; ((FAIL++)) || true; FAILED_ITEMS+=("$1"); }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; ((SKIP++)) || true; }
section() { echo -e "\n${PURPLE}════════════════════════════════════════${NC}"; echo -e "${PURPLE}  $1${NC}"; echo -e "${PURPLE}════════════════════════════════════════${NC}"; }

mkdir -p $WORK/logs

#=============================================================================
section "阶段 1：系统基础工具"
#=============================================================================
log "安装系统依赖..."
apt-get update -qq
apt-get install -y -qq tmux vim net-tools curl wget git zstd jq build-essential libffi-dev libssl-dev > /dev/null 2>&1
# 自动检测 Python 版本并安装对应 venv 包
apt-get install -y -qq software-properties-common > /dev/null 2>&1
git config --global user.name "liubin18911671739"
git config --global user.email "18911671739@126.com"
ok "系统工具 + Git 已配置"


#=============================================================================
section "阶段 2：Python 虚拟环境（科研全栈）"
#=============================================================================
[ ! -f $WORK/venv/bin/python ] && python3.12 -m venv $WORK/venv
source $WORK/venv/bin/activate
python -m ensurepip --upgrade 2>/dev/null || true
pip install --upgrade pip setuptools wheel -q

log "安装科研基础包..."
pip install pandas numpy scipy matplotlib seaborn plotly -q
pip install scikit-learn xgboost lightgbm statsmodels -q

log "安装数据挖掘与可视化..."
pip install requests httpx aiohttp beautifulsoup4 lxml -q
pip install rich tqdm pydantic -q

log "安装自然语言处理..."
pip install tokenizers --only-binary :all: -q
pip install sentencepiece --only-binary :all: -q
pip install transformers datasets -q
pip install jieba wordcloud nltk -q

log "安装 Jupyter 生态..."
pip install jupyter ipykernel ipywidgets jupyterlab jupyterlab-git -q
python -m ipykernel install --user --name scholar --display-name "Python (scholar)" 2>/dev/null

grep -q 'source $WORK/venv/bin/activate' ~/.bashrc 2>/dev/null || \
    echo "source $WORK/venv/bin/activate" >> ~/.bashrc
[ "$(which python)" = "$WORK/venv/bin/python" ] && ok "Python 3.12 venv（科研全栈）" || fail "venv 异常"
#=============================================================================
section "阶段 3：Node.js 环境（nvm + Node 24 LTS）"
#=============================================================================
log "Install Node.js 22 LTS (binary)..."
NODE_VER="v22.15.0"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) NODE_ARCH="x64" ;;
esac
NODE_DIR=/usr/local/lib/nodejs

if ! command -v node &>/dev/null; then
    mkdir -p "$NODE_DIR"
    log "Downloading node-${NODE_VER}-linux-${NODE_ARCH}..."
    curl -fsSL "https://nodejs.org/dist/${NODE_VER}/node-${NODE_VER}-linux-${NODE_ARCH}.tar.xz" \
        | tar -xJ -C "$NODE_DIR" --strip-components=1
    # Add to PATH permanently
    grep -q "$NODE_DIR/bin" ~/.bashrc 2>/dev/null || \
        echo "export PATH=$NODE_DIR/bin:\$PATH" >> ~/.bashrc
fi
export PATH="$NODE_DIR/bin:$PATH"

if command -v node &>/dev/null; then
    ok "Node.js $(node -v)"
    npm install -g pnpm yarn tsx 2>&1 | tail -3 || true
    command -v pnpm &>/dev/null && ok "pnpm/yarn/tsx" || warn "npm global packages"
else
    fail "Node.js install failed"
fi

#=============================================================================
section "阶段 4：PostgreSQL + pgvector"
#=============================================================================
log "安装 PostgreSQL 16 + pgvector..."
if ! command -v psql &>/dev/null; then
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' || true
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg 2>/dev/null || true
    apt-get update -qq
    apt-get install -y -qq postgresql-16 postgresql-16-pgvector > /dev/null 2>&1 || \
        apt-get install -y -qq postgresql postgresql-contrib > /dev/null 2>&1
fi

# Configure data dir under /workspace for persistence
PG_DATA=$WORK/pgdata
if [ ! -d "$PG_DATA" ]; then
    mkdir -p "$PG_DATA"
    chown postgres:postgres "$PG_DATA"
    su - postgres -c "/usr/lib/postgresql/*/bin/initdb -D $PG_DATA" 2>/dev/null || true
fi

# Start PostgreSQL
if ! pgrep -f "postgres" > /dev/null; then
    su - postgres -c "/usr/lib/postgresql/*/bin/pg_ctl -D $PG_DATA -l $WORK/logs/postgresql.log start" 2>/dev/null || \
        pg_ctlcluster 16 main start 2>/dev/null || true
fi
sleep 2

# Create scholar database and enable pgvector
su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname='scholar'\"" 2>/dev/null | grep -q 1 || \
    su - postgres -c "createdb scholar" 2>/dev/null || true
su - postgres -c "psql -d scholar -c 'CREATE EXTENSION IF NOT EXISTS vector'" 2>/dev/null || true

# Set password for postgres user
su - postgres -c "psql -c \"ALTER USER postgres PASSWORD 'scholar2026'\"" 2>/dev/null || true

netstat -tlnp | grep -q ":5432 " && ok "PostgreSQL :5432" || warn "PostgreSQL not started"

#=============================================================================
section "阶段 4.1：Redis"
#=============================================================================
log "安装 Redis..."
if ! command -v redis-server &>/dev/null; then
    apt-get install -y -qq redis-server > /dev/null 2>&1
fi

# Configure Redis with /workspace data dir
REDIS_DIR=$WORK/redis_data
mkdir -p "$REDIS_DIR"
if ! pgrep -f "redis-server" > /dev/null; then
    redis-server --daemonize yes \
        --dir "$REDIS_DIR" \
        --bind 0.0.0.0 \
        --requirepass scholar2026 \
        --logfile $WORK/logs/redis.log \
        --save 60 1000 2>/dev/null || true
fi
netstat -tlnp | grep -q ":6379 " && ok "Redis :6379" || warn "Redis not started"

#=============================================================================
section "阶段 4.2：MinIO"
#=============================================================================
log "Install MinIO..."
if ! command -v minio &>/dev/null; then
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) MINIO_ARCH="amd64" ;;
        aarch64|arm64) MINIO_ARCH="arm64" ;;
        *) MINIO_ARCH="amd64" ;;
    esac
    curl -fsSL "https://dl.min.io/server/minio/release/linux-${MINIO_ARCH}/minio" -o /usr/local/bin/minio || true
    chmod +x /usr/local/bin/minio 2>/dev/null || true
fi

MINIO_DATA=$WORK/minio_data
mkdir -p "$MINIO_DATA"
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=scholar2026

if ! pgrep -f "minio server" > /dev/null; then
    nohup minio server "$MINIO_DATA" \
        --address ":9000" \
        --console-address ":9001" \
        &> $WORK/logs/minio.log &
    sleep 2
fi
netstat -tlnp | grep -q ":9000 " && ok "MinIO API :9000" || warn "MinIO not started"
netstat -tlnp | grep -q ":9001 " && ok "MinIO Console :9001" || warn "MinIO Console not started"

#=============================================================================
section "阶段 5：code-server + Claude Code"
#=============================================================================
log "安装 code-server + Claude Code..."
command -v code-server &>/dev/null || curl -fsSL https://code-server.dev/install.sh | sh 2>/dev/null
command -v code-server &>/dev/null && ok "code-server" || fail "code-server"
mkdir -p $WORK/code-server/{data,extensions,config} ~/.config/code-server
[ ! -f $WORK/code-server/config/config.yaml ] && cat > $WORK/code-server/config/config.yaml << 'CSEOF'
bind-addr: 0.0.0.0:8082
auth: password
password: pzNPIjcC71MmLTLPA0vM2JjL
cert: false
CSEOF
ln -sf $WORK/code-server/config/config.yaml ~/.config/code-server/config.yaml
pgrep -f "code-server" > /dev/null || nohup code-server --user-data-dir $WORK/code-server/data --extensions-dir $WORK/code-server/extensions --bind-addr 0.0.0.0:8082 &> $WORK/logs/code-server.log &
sleep 3; netstat -tlnp | grep -q ":8082 " && ok "code-server :8082" || warn "code-server 未启动"

export PATH="/usr/local/lib/nodejs/bin:$PATH"
if command -v npm &>/dev/null; then
    command -v claude &>/dev/null || npm install -g @anthropic-ai/claude-code 2>&1 | tail -5 || true
fi
if command -v claude &>/dev/null; then
    ok "Claude Code"
else
    warn "Claude Code install failed (npm not available?)"
fi
mkdir -p ~/.claude
[ ! -f ~/.claude/settings.json ] && cat > ~/.claude/settings.json << 'CLEOF'
{"env":{"ANTHROPIC_AUTH_TOKEN":"b5f287759e514e9da848105c36829804.26vrGpn1oeXnWWdj","ANTHROPIC_BASE_URL":"https://open.bigmodel.cn/api/anthropic","API_TIMEOUT_MS":"3000000","ANTHROPIC_DEFAULT_HAIKU_MODEL":"glm-4.5-air","ANTHROPIC_DEFAULT_SONNET_MODEL":"zai/glm-5.1","ANTHROPIC_DEFAULT_OPUS_MODEL":"glm-5.1","CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":1}}
CLEOF
echo '{"hasCompletedOnboarding":true}' > ~/.claude.json

#=============================================================================
section "阶段 6：OpenClaw 智能体"
#=============================================================================
log "安装 OpenClaw 智能体..."

rm -f ~/.openclaw 2>/dev/null || true
mkdir -p $WORK/.openclaw
export ZHIPU_API_KEY="b5f287759e514e9da848105c36829804.26vrGpn1oeXnWWdj"
grep -q 'ZHIPU_API_KEY' ~/.bashrc 2>/dev/null || echo 'export ZHIPU_API_KEY="b5f287759e514e9da848105c36829804.26vrGpn1oeXnWWdj"' >> ~/.bashrc
if ! command -v openclaw &>/dev/null; then
    npm install -g openclaw@latest 2>&1 | tail -5 || true
fi
if command -v openclaw &>/dev/null; then
    ok "OpenClaw"
else
    warn "OpenClaw install failed, skipping"
fi
mkdir -p $WORK/.openclaw/workspace
if [ ! -f $WORK/.openclaw/workspace/SOUL.md ]; then
    cat > $WORK/.openclaw/workspace/SOUL.md << 'SOULEOF'
# XiaoYan - Research AI Agent
I am XiaoYan, a research AI agent for academic scenarios.
Core mission: help users go from research ideas to publishable results.
SOULEOF
fi

# Set OpenClaw agent model
mkdir -p $WORK/.openclaw/workspace
cat > $WORK/.openclaw/workspace/config.json << 'OCCONF'
{"model": "zai/glm-5.1"}
OCCONF
ok "OpenClaw model: zai/glm-5.1"

# Start OpenClaw Gateway (skip if not installed)
if command -v openclaw &>/dev/null; then
    pgrep -f "openclaw" > /dev/null || {
        nohup openclaw gateway &> $WORK/logs/openclaw.log &
        sleep 3
    }
    netstat -tlnp | grep -q ":18789 " && ok "OpenClaw Gateway :18789" || warn "OpenClaw Gateway not started"
else
    warn "OpenClaw not installed, skipping gateway"
fi

#=============================================================================
section "阶段 7：Telegram + 飞书通知"
#=============================================================================
log "安装 Telegram + 飞书通知..."
if [ ! -f $WORK/.env ]; then
    cat > $WORK/.env << 'ENVEOF'
TELEGRAM_BOT_TOKEN=8777940422:AAFP0Jzw-0jnsbWzhD2Y4GN9A3w59o_CEj8
TELEGRAM_CHAT_ID=7249863310
FEISHU_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/t6qIprRGi1qoBDkLmQ8ORfcrRTamOIEF
FEISHU_APP_ID=cli_a92566fb31a5dcca
FEISHU_APP_SECRET=TnSUBhKkxVhcjAYZpW7cmhYNmSs5qAhk
ENVEOF
    ok ".env 已创建"
else
    ok ".env 已存在"
fi

#=============================================================================
section "阶段 8：JupyterLab"
#=============================================================================
log "安装 JupyterLab..."

source $WORK/venv/bin/activate
mkdir -p $WORK/jupyter/config
[ ! -f $WORK/jupyter/config/jupyter_lab_config.py ] && cat > $WORK/jupyter/config/jupyter_lab_config.py << 'JUPEOF'
c = get_config()
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.root_dir = '/workspace'
c.ServerApp.allow_root = True
c.ServerApp.token = 'scholar2026'
JUPEOF
pgrep -f "jupyter-lab" > /dev/null || nohup jupyter lab --config $WORK/jupyter/config/jupyter_lab_config.py &> $WORK/logs/jupyter.log &
sleep 3; netstat -tlnp | grep -q ":8888 " && ok "JupyterLab :8888" || warn "JupyterLab 未启动"

#=============================================================================
section "阶段 9：n8n 工作流引擎"
#=============================================================================
log "安装 n8n 工作流引擎..."

export PATH="/usr/local/lib/nodejs/bin:$PATH"
command -v n8n &>/dev/null || npm install -g n8n 2>&1 | tail -3
command -v n8n &>/dev/null && ok "n8n" || fail "n8n"
mkdir -p $WORK/n8n_data
export N8N_USER_FOLDER=$WORK/n8n_data N8N_PORT=5678 GENERIC_TIMEZONE=Asia/Shanghai N8N_BASIC_AUTH_ACTIVE=false N8N_PERSONALIZATION_ENABLED=false
[ ! -f $WORK/n8n_data/.encryption_key ] && openssl rand -hex 32 > $WORK/n8n_data/.encryption_key && chmod 600 $WORK/n8n_data/.encryption_key
export N8N_ENCRYPTION_KEY=$(cat $WORK/n8n_data/.encryption_key)
grep -q 'N8N_USER_FOLDER' ~/.bashrc 2>/dev/null || cat >> ~/.bashrc << 'N8NEOF'
export N8N_USER_FOLDER=/workspace/n8n_data N8N_PORT=5678 GENERIC_TIMEZONE=Asia/Shanghai N8N_BASIC_AUTH_ACTIVE=false N8N_PERSONALIZATION_ENABLED=false
[ -f /workspace/n8n_data/.encryption_key ] && export N8N_ENCRYPTION_KEY=$(cat /workspace/n8n_data/.encryption_key)
N8NEOF
pgrep -f "n8n start" > /dev/null || nohup n8n start &> $WORK/logs/n8n.log &
sleep 6; netstat -tlnp | grep -q ":5678 " && ok "n8n :5678" || warn "n8n 未启动"

#=============================================================================
section "阶段 10：Marimo 响应式笔记本"
#=============================================================================
log "安装 Marimo 响应式笔记本..."
source $WORK/venv/bin/activate
pip install marimo openai "pydantic-ai-slim[openai]" -q 2>&1 | tail -3
command -v marimo &>/dev/null && ok "Marimo" || fail "Marimo"
pgrep -f "marimo edit" > /dev/null || {
    export MARIMO_TOKEN_PASSWORD=''
    $WORK/venv/bin/marimo edit --host 0.0.0.0 --port 2718 --headless --no-token &> $WORK/logs/marimo.log &
    sleep 3
}
netstat -tlnp | grep -q ":2718 " && ok "Marimo :2718" || warn "Marimo 未启动"

#=============================================================================
section "阶段 11：Open WebUI"
#=============================================================================
log "Install Open WebUI..."
source $WORK/venv/bin/activate
pip install open-webui -q 2>&1 | tail -5 || true

# Configure Open WebUI to use Zhipu GLM API (OpenAI-compatible)
export OPENAI_API_BASE_URL="https://open.bigmodel.cn/api/paas/v4"
export OPENAI_API_KEY="b5f287759e514e9da848105c36829804.26vrGpn1oeXnWWdj"
export WEBUI_AUTH=false
export DATA_DIR="$WORK/open-webui-data"
mkdir -p "$DATA_DIR"

if command -v open-webui &>/dev/null; then
    ok "Open WebUI installed"
    if ! pgrep -f "open-webui serve" > /dev/null; then
        nohup open-webui serve --host 0.0.0.0 --port 3000 &> $WORK/logs/open-webui.log &
        sleep 3
    fi
    netstat -tlnp | grep -q ":3000 " && ok "Open WebUI :3000" || warn "Open WebUI not started"
else
    warn "Open WebUI install failed"
fi

ok "阶段 1-11 安装完成"

#=============================================================================
section "生成辅助脚本"
#=============================================================================
log "生成辅助脚本..."

cat > $WORK/start_all.sh << 'STARTEOF'
#!/bin/bash
echo "🚀 启动 VPS 全套服务..."
source /workspace/venv/bin/activate
export PATH="/usr/local/lib/nodejs/bin:$PATH"
source /workspace/.env 2>/dev/null
mkdir -p /workspace/logs

# Start data services
su - postgres -c "/usr/lib/postgresql/*/bin/pg_ctl -D /workspace/pgdata -l /workspace/logs/postgresql.log start" 2>/dev/null || \
    pg_ctlcluster 16 main start 2>/dev/null || true
echo "  ✅ PostgreSQL :5432"

pgrep -f "redis-server" > /dev/null || {
    redis-server --daemonize yes --dir /workspace/redis_data --bind 0.0.0.0 --requirepass scholar2026 --logfile /workspace/logs/redis.log --save 60 1000 2>/dev/null || true
    echo "  ✅ Redis :6379"
}

pgrep -f "minio server" > /dev/null || {
    export MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=scholar2026
    nohup minio server /workspace/minio_data --address ":9000" --console-address ":9001" &> /workspace/logs/minio.log &
    echo "  ✅ MinIO :9000/:9001"
}

pgrep -f "code-server" > /dev/null || {
    nohup code-server --user-data-dir /workspace/code-server/data --extensions-dir /workspace/code-server/extensions --bind-addr 0.0.0.0:8082 &> /workspace/logs/code-server.log &
    echo "  ✅ code-server :8082"
}

pgrep -f "jupyter-lab" > /dev/null || {
    nohup jupyter lab --config /workspace/jupyter/config/jupyter_lab_config.py &> /workspace/logs/jupyter.log &
    echo "  ✅ JupyterLab :8888"
}

pgrep -f "n8n start" > /dev/null || {
    export N8N_USER_FOLDER=/workspace/n8n_data N8N_PORT=5678 GENERIC_TIMEZONE=Asia/Shanghai N8N_BASIC_AUTH_ACTIVE=false N8N_PERSONALIZATION_ENABLED=false
    [ -f /workspace/n8n_data/.encryption_key ] && export N8N_ENCRYPTION_KEY=$(cat /workspace/n8n_data/.encryption_key)
    nohup n8n start &> /workspace/logs/n8n.log &
    echo "  ✅ n8n :5678"
}

pgrep -f "marimo edit" > /dev/null || {
    export MARIMO_TOKEN_PASSWORD=''
    /workspace/venv/bin/marimo edit --host 0.0.0.0 --port 2718 --headless --no-token &> /workspace/logs/marimo.log &
    echo "  ✅ Marimo :2718"
}

pgrep -f "openclaw" > /dev/null || {
    if command -v openclaw &>/dev/null; then
        nohup openclaw gateway &> /workspace/logs/openclaw.log &
        sleep 3; echo "  ✅ OpenClaw :18789"
    fi
}

pgrep -f "open-webui serve" > /dev/null || {
    if command -v open-webui &>/dev/null; then
        export OPENAI_API_BASE_URL="https://open.bigmodel.cn/api/paas/v4"
        export OPENAI_API_KEY="b5f287759e514e9da848105c36829804.26vrGpn1oeXnWWdj"
        export WEBUI_AUTH=false
        export DATA_DIR=/workspace/open-webui-data
        nohup open-webui serve --host 0.0.0.0 --port 3000 &> /workspace/logs/open-webui.log &
        echo "  ✅ Open WebUI :3000"
    fi
}

echo ""
echo "✅ 所有服务启动完成！"
echo "  💻 code-server → :8082"
echo "  📓 JupyterLab  → :8888"
echo "  🧪 Marimo      → :2718"
echo "  ⚙️ n8n        → :5678"
echo "  🦞 OpenClaw    → :18789"
echo "  openwebui    → :3000"

STARTEOF
chmod +x $WORK/start_all.sh
ok "start_all.sh 已生成"

cat > $WORK/check_env.sh << 'CHECKEOF'
#!/bin/bash
source /workspace/venv/bin/activate 2>/dev/null
export PATH="/usr/local/lib/nodejs/bin:$PATH"
echo "📋 VPS 环境检查"
echo "================================"
echo "OS:     $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "CPU:    $(nproc) cores · $(free -h | awk '/Mem:/{print $2}') RAM"
echo "Python: $(python --version 2>&1)"
echo "Node:   $(node --version 2>&1)"
echo ""
echo "服务端口："
for port in 2718 3000 5432 5678 6379 8082 8888 9000 9001 18789; do
    netstat -tlnp 2>/dev/null | grep -q ":$port " && echo "  ✅ :$port" || echo "  ❌ :$port"
done
CHECKEOF
chmod +x $WORK/check_env.sh
ok "check_env.sh 已生成"

#=============================================================================
section "🏁 最终验证"
#=============================================================================
check() { eval "$2" > /dev/null 2>&1 && ok "$1" || fail "$1"; }
check "Python venv" '[ "$(which python)" = "/workspace/venv/bin/python" ]'
check "Node.js" 'command -v node'
check "code-server" 'command -v code-server'
check "code-server :8082" 'netstat -tlnp | grep -q ":8082 "'
check "Claude Code" 'command -v claude'
check "OpenClaw" 'command -v openclaw'
check "OpenClaw :18789" 'netstat -tlnp | grep -q ":18789 "'
check "JupyterLab :8888" 'netstat -tlnp | grep -q ":8888 "'
check "n8n :5678" 'netstat -tlnp | grep -q ":5678 "'
check "Marimo :2718" 'netstat -tlnp | grep -q ":2718 "'
check "PostgreSQL :5432" 'netstat -tlnp | grep -q ":5432 "'
check "Redis :6379" 'netstat -tlnp | grep -q ":6379 "'
check "MinIO :9000" 'netstat -tlnp | grep -q ":9000 "'
check "Open WebUI :3000" 'netstat -tlnp | grep -q ":3000 "'
check ".env 文件" '[ -f /workspace/.env ]'

#=============================================================================
section "📊 安装报告"
#=============================================================================
echo -e "${GREEN}  ✅ 通过: $PASS${NC}"
echo -e "${YELLOW}  ⚠️  跳过: $SKIP${NC}"
echo -e "${RED}  ❌ 失败: $FAIL${NC}"
[ $FAIL -eq 0 ] && echo -e "${GREEN}🎉 全部通过！${NC}" || { echo -e "${RED}失败项：${NC}"; for i in "${FAILED_ITEMS[@]}"; do echo -e "  ${RED}• $i${NC}"; done; }
echo ""
echo "🚀 后续开机运行: bash /workspace/start_all.sh"
echo "📋 检查环境: bash /workspace/check_env.sh"
echo ""
echo "💡 CPU VPS 使用提示："
echo "  • 复杂 LLM 任务通过 OpenClaw → 智谱 GLM API 云端调用"