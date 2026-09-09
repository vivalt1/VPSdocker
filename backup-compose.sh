#!/usr/bin/env bash
# backup-compose.sh
# 从运行中的容器导出 docker-compose.yml 配置

set -euo pipefail

BACKUP_DIR="$(dirname "$0")/backup-compose-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== 导出 docker-compose 配置 ==="

# 方法 1: 如果有 docker-compose 命令且项目在当前目录
if command -v docker-compose >/dev/null 2>&1 && [[ -f docker-compose.yml ]]; then
    echo "📋 使用 docker-compose config 导出..."
    docker-compose config > "$BACKUP_DIR/docker-compose.yml"
    echo "✅ 已导出到 $BACKUP_DIR/docker-compose.yml"
    exit 0
fi

# 方法 2: 使用 docker compose (v2)
if docker compose version >/dev/null 2>&1 && [[ -f docker-compose.yml ]]; then
    echo "📋 使用 docker compose config 导出..."
    docker compose config > "$BACKUP_DIR/docker-compose.yml"
    echo "✅ 已导出到 $BACKUP_DIR/docker-compose.yml"
    exit 0
fi

# 方法 3: 从运行中的容器反推配置（使用 docker-autocompose）
echo "🔍 尝试从运行容器生成 compose 文件..."
if docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/red5d/docker-autocompose:v0.3.0 \
    $(docker ps --format "{{.Names}}" | tr '\n' ' ') > "$BACKUP_DIR/docker-compose.yml" 2>/dev/null; then
    echo "✅ 已从运行容器生成: $BACKUP_DIR/docker-compose.yml"
else
    echo "⚠️  docker-autocompose 失败，尝试手动生成基础模板..."
    cat > "$BACKUP_DIR/docker-compose.yml" <<'EOF'
# 手动维护版本 - 请根据实际情况修改
version: '3.8'
services:
  # 示例服务，请替换为实际配置
  # app:
  #   image: registry.giteejay.com/namespace/app:latest
  #   ports:
  #     - "8080:8080"
  #   volumes:
  #     - app_data:/data
  #   environment:
  #     - ENV=production
  #   restart: unless-stopped

volumes:
  # app_data:
EOF
    echo "📝 已创建模板文件: $BACKUP_DIR/docker-compose.yml"
    echo "   请手动编辑填入实际服务配置"
fi

# 同时导出容器列表供参考
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}" > "$BACKUP_DIR/running-containers.txt"
echo "📋 运行中容器列表: $BACKUP_DIR/running-containers.txt"