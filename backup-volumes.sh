#!/usr/bin/env bash
# backup-volumes.sh
# 备份 Docker 命名数据卷到 tar.gz

set -euo pipefail

# ========== 配置区域 ==========
VOLUME_FILTER="${1:-}"  # 可选：只备份包含该关键字的卷
BACKUP_ROOT="$(dirname "$0")/backup-volumes-$(date +%Y%m%d-%H%M%S)"
# ===============================

mkdir -p "$BACKUP_ROOT"

echo "=== 备份 Docker 数据卷 ==="
echo "Backup dir: $BACKUP_ROOT"
echo "Filter: ${VOLUME_FILTER:-无（备份所有）}"
echo ""

# 获取所有命名卷
VOLUMES=()
while IFS= read -r vol; do
    [[ -z "$vol" ]] && continue
    if [[ -n "$VOLUME_FILTER" && "$vol" != *"$VOLUME_FILTER"* ]]; then
        continue
    fi
    VOLUMES+=("$vol")
done < <(docker volume ls --format "{{.Name}}" | grep -v "^$")

if [[ ${#VOLUMES[@]} -eq 0 ]]; then
    echo "⚠️  没有找到匹配的数据卷"
    exit 0
fi

echo "找到 ${#VOLUMES[@]} 个数据卷："
printf '  %s\n' "${VOLUMES[@]}"
echo ""

SUCCESS=0
FAILED=0
MANIFEST="$BACKUP_ROOT/manifest.txt"

for VOL in "${VOLUMES[@]}"; do
    echo "📦 备份卷: $VOL"
    OUT_FILE="$BACKUP_ROOT/${VOL}.tar.gz"

    # 使用临时容器打包卷内容
    if docker run --rm \
        -v "$VOL":/source:ro \
        -v "$BACKUP_ROOT":/backup \
        alpine:3.20 \
        tar czf "/backup/${VOL}.tar.gz" -C /source .; then
        
        SIZE=$(du -h "$OUT_FILE" | cut -f1)
        echo "   ✅ 完成 ($SIZE) -> $OUT_FILE"
        ((SUCCESS++))
        echo "$VOL $OUT_FILE $SIZE SUCCESS" >> "$MANIFEST"
    else
        echo "   ❌ 失败"
        ((FAILED++))
        echo "$VOL FAILED" >> "$MANIFEST"
    fi
done

echo ""
echo "=== 卷备份完成 ==="
echo "成功: $SUCCESS"
echo "失败: $FAILED"
echo "清单: $MANIFEST"

cat > "$BACKUP_ROOT/summary.txt" <<EOF
备份时间: $(date)
数据卷总数: ${#VOLUMES[@]}
成功: $SUCCESS
失败: $FAILED
EOF

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi