#!/usr/bin/env bash
# backup-images.sh
# 推送本地 Docker 镜像到 GitHub Container Registry (ghcr.io)

set -euo pipefail

# ========== 配置区域 ==========
GITHUB_USER="${GITHUB_USER:-vivalt1}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REGISTRY="ghcr.io"
# ===============================

FILTER="${1:-}"
BACKUP_ROOT="$(dirname "$0")/backup-images-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_ROOT"

echo "=== 备份 Docker 镜像到 GitHub Container Registry ==="
echo "Registry: $REGISTRY"
echo "User: $GITHUB_USER"
echo "Filter: ${FILTER:-无}"
echo ""

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ 请设置 GITHUB_TOKEN 环境变量"
    echo "   export GITHUB_TOKEN='your_github_token'"
    exit 1
fi

echo "$GITHUB_TOKEN" | docker login "$REGISTRY" -u "$GITHUB_USER" --password-stdin

IMAGES=()
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    repo=$(echo "$line" | awk '{print $1}')
    tag=$(echo "$line" | awk '{print $2}')
    [[ "$tag" == "<none>" ]] && continue
    [[ -n "$FILTER" && "$repo" != *"$FILTER"* ]] && continue
    IMAGES+=("$repo:$tag")
done < <(docker images --format "{{.Repository}} {{.Tag}}" | grep -v "^<none>")

if [[ ${#IMAGES[@]} -eq 0 ]]; then
    echo "⚠️  没有找到匹配的镜像"
    exit 0
fi

echo "找到 ${#IMAGES[@]} 个镜像："
printf '  %s\n' "${IMAGES[@]}"
echo ""

SUCCESS=0
FAILED=0
MANIFEST="$BACKUP_ROOT/manifest.txt"
echo "# 镜像备份清单" > "$MANIFEST"
echo "# 备份时间: $(date)" >> "$MANIFEST"
echo "" >> "$MANIFEST"

for IMG in "${IMAGES[@]}"; do
    SAFE_NAME=$(echo "$IMG" | sed 's|/|-|g' | sed 's|:|-|g')
    TARGET="$REGISTRY/$GITHUB_USER/$SAFE_NAME:latest"

    echo "📦 处理: $IMG → $TARGET"

    if docker tag "$IMG" "$TARGET"; then
        echo "   🚀 推送中..."
        if docker push "$TARGET"; then
            echo "   ✅ 推送成功"
            ((SUCCESS++))
            echo "$IMG -> $TARGET SUCCESS" >> "$MANIFEST"
        else
            echo "   ❌ 推送失败"
            ((FAILED++))
            echo "$IMG -> $TARGET FAILED (push)" >> "$MANIFEST"
        fi
    else
        echo "   ❌ 标签失败"
        ((FAILED++))
        echo "$IMG -> $TARGET FAILED (tag)" >> "$MANIFEST"
    fi

    docker rmi "$TARGET" >/dev/null 2>&1 || true
done

echo ""
echo "=== 镜像备份完成 ==="
echo "成功: $SUCCESS"
echo "失败: $FAILED"
echo "清单: $MANIFEST"

cat > "$BACKUP_ROOT/summary.txt" <<EOF
备份时间: $(date)
Registry: $REGISTRY
User: $GITHUB_USER
镜像总数: ${#IMAGES[@]}
成功: $SUCCESS
失败: $FAILED
EOF

if [[ $FAILED -gt 0 ]]; then
    echo "⚠️  有镜像推送失败"
    exit 1
fi