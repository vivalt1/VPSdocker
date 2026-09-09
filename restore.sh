#!/usr/bin/env bash
set -euo pipefail

GITHUB_USER="${GITHUB_USER:-vivalt1}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REGISTRY="ghcr.io"

REPO_NAME="${1:-}"
BACKUP_DIR="${2:-}"
COMPOSE_FILE="${3:-docker-compose.yml}"
ENV_FILE="${4:-.env}"

if [[ -z "$REPO_NAME" ]]; then
    echo "用法: $0 <仓库名> [备份目录] [compose文件] [.env]"
    echo "示例: $0 alist ./backup-full-20240101-120000 docker-compose.yml .env.prod"
    exit 1
fi

echo "=== 从 GitHub Container Registry 恢复 ==="
echo "Registry: $REGISTRY"
echo "User: $GITHUB_USER"
echo "Repo: $REPO_NAME"
echo ""

echo "$GITHUB_TOKEN" | docker login "$REGISTRY" -u "$GITHUB_USER" --password-stdin

echo "📦 恢复数据卷..."
if [[ -d "$BACKUP_DIR" && -f "$BACKUP_DIR/manifest.txt" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == *"FAILED"* ]] && continue
        [[ "$line" == "#"* ]] && continue
        VOL=$(echo "$line" | awk '{print $1}')
        ARCHIVE="$BACKUP_DIR/${VOL}.tar.gz"
        
        if [[ -f "$ARCHIVE" ]]; then
            echo "   恢复卷: $VOL"
            docker volume create "$VOL" >/dev/null 2>&1 || true
            docker run --rm \
                -v "$VOL":/target \
                -v "$BACKUP_DIR":/backup \
                alpine:3.20 \
                sh -c "cd /target && tar xzf /backup/${VOL}.tar.gz"
            echo "   ✅ $VOL 恢复完成"
        else
            echo "   ⚠️  卷归档不存在: $ARCHIVE"
        fi
    done < "$BACKUP_DIR/manifest.txt"
else
    echo "   ⚠️  未找到卷清单，跳过卷恢复"
fi

echo ""
echo "📥 加载 Docker 镜像..."
IMAGE_DIR="$BACKUP_DIR"
if [[ -d "$IMAGE_DIR" ]]; then
    for archive in "$IMAGE_DIR"/*.tar.gz; do
        [[ -f "$archive" ]] || continue
        echo "   加载: $(basename "$archive")"
        if docker load < "$archive"; then
            echo "   ✅ 加载成功"
        else
            echo "   ⚠️  加载失败: $archive"
        fi
    done
else
    echo "   ⚠️  镜像目录不存在: $IMAGE_DIR"
fi

if [[ -f "$COMPOSE_FILE" ]]; then
    echo ""
    echo "🚀 部署服务栈..."
    if [[ -f "$ENV_FILE" ]]; then
        echo "   使用环境文件: $ENV_FILE"
        docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
    else
        echo "   未找到环境文件，使用默认配置"
        docker compose -f "$COMPOSE_FILE" up -d
    fi
    echo "✅ 部署完成"
else
    echo "⚠️  Compose 文件不存在: $COMPOSE_FILE"
fi

echo ""
echo "=== 恢复完成 ==="
echo "请检查服务状态: docker ps"