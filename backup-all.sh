#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILTER="${1:-}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
MAIN_BACKUP_DIR="$SCRIPT_DIR/backup-full-$TIMESTAMP"

mkdir -p "$MAIN_BACKUP_DIR"

echo "=== Docker 全量备份到 GitHub ==="
echo "时间: $(date)"
echo "过滤: ${FILTER:-无}"
echo "输出: $MAIN_BACKUP_DIR"
echo ""

# 1. 推送镜像到 GHCR
echo ">>> 步骤 1/3: 推送镜像到 GHCR"
"$SCRIPT_DIR/backup-images.sh" "$FILTER" || {
    echo "❌ 镜像推送失败"
    exit 1
}

# 2. 备份 Compose 配置
echo ""
echo ">>> 步骤 2/3: 备份 Compose 配置"
"$SCRIPT_DIR/backup-compose.sh" || {
    echo "❌ Compose 备份失败"
    exit 1
}
mv "$SCRIPT_DIR"/backup-compose-* "$MAIN_BACKUP_DIR/compose" 2>/dev/null || true

# 3. 备份数据卷
echo ""
echo ">>> 步骤 3/3: 备份数据卷"
"$SCRIPT_DIR/backup-volumes.sh" "$FILTER" || {
    echo "❌ 数据卷备份失败"
    exit 1
}
mv "$SCRIPT_DIR"/backup-volumes-* "$MAIN_BACKUP_DIR/volumes" 2>/dev/null || true

# 生成总清单
cat > "$MAIN_BACKUP_DIR/MANIFEST.txt" <<EOF
Docker 全量备份清单
===================
备份时间: $(date)
过滤关键字: ${FILTER:-无}
备份目录: $MAIN_BACKUP_DIR

包含内容:
- images/     : 镜像推送至 GHCR (ghcr.io)
- compose/    : docker-compose.yml 配置文件
- volumes/    : 数据卷归档文件 (*.tar.gz)

恢复方法:
  1. 从 GHCR 拉取镜像: docker pull ghcr.io/<user>/<image>
  2. 恢复数据卷: ./restore.sh <backup_dir>/volumes
  3. 部署: docker compose up -d
EOF

echo ""
echo "=== 全量备份完成 ==="
echo "目录: $MAIN_BACKUP_DIR"
echo ""
echo "下一步:"
echo "  1. 将 volumes/ 目录提交到 Git (走 LFS)"
echo "  2. 推送到 GitHub: git add . && git commit -m 'backup: $TIMESTAMP' && git push"
echo "  3. 如需恢复镜像: docker pull ghcr.io/<user>/<image>"
echo "  4. 如需恢复: ./restore.sh $MAIN_BACKUP_DIR/volumes docker-compose.yml .env.prod"