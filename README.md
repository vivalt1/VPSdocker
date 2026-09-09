# Docker GitHub Backup

一键备份 Docker 镜像到 GitHub Container Registry (ghcr.io)。

## 方案说明

使用 **GitHub Container Registry (ghcr.io)** 存储 Docker 镜像，完全免费。

公开仓库：无限存储和流量  
私有仓库：500MB 存储 + 1GB/月流出

## 目录结构

```
docker-backup/
├── backup-images.sh       # 推送镜像到 ghcr.io
├── backup-compose.sh      # 导出 docker-compose.yml
├── backup-volumes.sh      # 备份数据卷到本地
├── backup-all.sh          # 一键完整备份
├── restore.sh             # 从 ghcr.io 恢复
├── .github/workflows/     # CI/CD 配置
└── README.md
```

## 快速开始

### 1. 获取 GitHub Personal Access Token

1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token
3. 勾选：`repo`、`write:packages`
4. 复制 token

### 2. 配置环境变量

```bash
export GITHUB_TOKEN="你的token"
export GITHUB_USER="vivalalt"
```

### 3. 运行备份

```bash
chmod +x *.sh
./backup-all.sh
```

### 4. 推送到 GitHub

```bash
git init
git remote add origin https://github.com/vivalalt/docker-backup.git
git add .
git commit -m "backup: $(date +%F-%H%M)"
git push -u origin main
```

## 多环境恢复

在新服务器上：

```bash
export GITHUB_TOKEN="你的token"
git clone https://github.com/vivalalt/docker-backup.git
cd docker-backup
./restore.sh docker-backup ./backup-full-*/volumes docker-compose.yml .env.prod
```

## 免费额度

| 资源 | 免费额度 |
|------|----------|
| GitHub 公开仓库 | 无限存储和流量 |
| GitHub 私有仓库 | 500MB 存储 + 1GB/月流出 |
| GitHub Actions | 公开仓库无限；私有仓库 2000 分钟/月 |

## 注意事项

- 公开仓库完全免费，无存储限制
- 私有仓库有 500MB 存储限制
- 国内访问 GitHub 可能需要代理
