# 🚀 Chatwoot Helm Chart

[Chatwoot](https://chatwoot.com) 是一个客户互动平台，开源替代 Intercom、Zendesk、Salesforce Service Cloud 等。🔥💬

## 快速开始

```bash
helm repo add chatwoot https://chatwoot.github.io/charts
helm install chatwoot chatwoot/chatwoot
```

## 📋 前置要求

- Kubernetes 1.16+
- Helm 3.1.0+
- 持久卷(PV)支持

## 📦 安装

使用 `chatwoot` 作为发布名称安装：

```bash
helm install chatwoot chatwoot/chatwoot
```

> 💡 **提示**: 使用 `helm list` 查看所有发布

## 🗑️ 卸载

删除 `chatwoot` 部署：

```bash
helm delete chatwoot
```

> ⚠️ **注意**: 持久卷不会自动删除，需要手动移除

## ⚙️ 配置参数

### 🖼️ 镜像配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `image.repository` | Chatwoot 镜像仓库 | `chatwoot/chatwoot` |
| `image.tag` | 镜像标签 | `v4.8.0` |
| `image.pullPolicy` | 镜像拉取策略 | `IfNotPresent` |

### 🌍 环境变量

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `env.ACTIVE_STORAGE_SERVICE` | 存储服务 (`local`/`amazon`) | `local` |
| `env.ENABLE_ACCOUNT_SIGNUP` | 是否允许注册 | `false` |
| `env.FORCE_SSL` | 强制 SSL | `false` |
| `env.FRONTEND_URL` | 前端 URL | `https://chat.x.com` |
| `env.SECRET_KEY_BASE` | 密钥基础 (必须修改) | `replace_with_your_super_duper_secret_key_base` |
| `env.RAILS_ENV` | Rails 环境 | `production` |

### 📧 邮件配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `env.MAILER_SENDER_EMAIL` | 发件人邮箱 | `""` |
| `env.SMTP_ADDRESS` | SMTP 地址 | `""` |
| `env.SMTP_PORT` | SMTP 端口 | `587` |
| `env.SMTP_USERNAME` | SMTP 用户名 | `""` |
| `env.SMTP_PASSWORD` | SMTP 密码 | `""` |

### 🐘 PostgreSQL 配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `postgresql.enabled` | 启用内置 PostgreSQL | `true` |
| `postgresql.auth.database` | 数据库名 | `chatwoot_production` |
| `postgresql.auth.username` | 用户名 | `postgres` |
| `postgresql.auth.postgresPassword` | 密码 | `postgres` |

### 🔴 Redis 配置

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `redis.enabled` | 启用内置 Redis | `true` |
| `redis.auth.password` | Redis 密码 | `redis` |

### 📈 自动扩缩容

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `web.hpa.enabled` | Web HPA | `false` |
| `web.hpa.cputhreshold` | CPU 阈值 | `75` |
| `web.hpa.minpods` | 最小 Pod 数 | `1` |
| `web.hpa.maxpods` | 最大 Pod 数 | `10` |
| `worker.hpa.enabled` | Worker HPA | `false` |
| `worker.replicaCount` | Worker 副本数 | `2` |

### 💾 资源限制

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `web.resources.limits.cpu` | Web CPU 限制 | `500m` |
| `web.resources.limits.memory` | Web 内存限制 | `512Mi` |
| `web.resources.requests.cpu` | Web CPU 请求 | `100m` |
| `web.resources.requests.memory` | Web 内存请求 | `256Mi` |

## 🔧 自定义配置

使用 `--set` 参数：

```bash
helm install my-release \
  --set env.FRONTEND_URL="https://chat.yourdomain.com" \
  chatwoot/chatwoot
```

或使用自定义 `values.yaml`：

```bash
helm install my-release -f values.yaml chatwoot/chatwoot
```

## 🗄️ 数据库说明

### PostgreSQL
默认安装内置 PostgreSQL。使用外部数据库时，设置 `postgresql.enabled=false` 并配置相关参数。

### Redis
默认安装内置 Redis。使用外部 Redis 时，设置 `redis.enabled=false` 并配置相关参数。

## 📊 启用自动扩缩容

1. 设置 `web.hpa.enabled=true` 和 `worker.hpa.enabled=true`
2. 配置 `resources.limits` 和 `resources.requests`
3. 确保集群已部署 metrics-server：

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 🔄 升级

```bash
# 更新仓库
helm repo update

# 查看当前版本
helm list

# 查看最新版本
helm search repo chatwoot

# 升级 (注意检查 CHANGELOG)
helm upgrade chatwoot chatwoot/chatwoot -f <your-custom-values>.yaml
```

### ⚠️ 重要升级说明

#### 升级到 1.x.x
- 必须先升级到 `0.9.0`
- PostgreSQL 和 Redis 版本变更，需要数据迁移
- 认证参数路径变更：
  - `postgresqlDatabase` → `auth.postgresqlDatabase`
  - `postgresqlUsername` → `auth.postgresqlUsername`
  - `postgresqlPassword` → `auth.postgresqlPassword`

#### 升级到 0.9.x
- 支持 HPA
- 参数重命名：
  - `web.replicas` → `web.replicaCount`
  - `worker.replicas` → `worker.replicaCount`
  - `services.internlPort` → `services.internalPort`

#### 升级到 0.8.x
- ConfigMap 迁移到 Secrets (非破坏性)

#### 升级到 0.6.x
- 标签变更，需要删除并重新安装

## 📚 更多信息

- [官方文档](https://www.chatwoot.com/docs)
- [GitHub 仓库](https://github.com/chatwoot/chatwoot)
- [Helm Charts](https://github.com/chatwoot/charts)

## 🤝 支持

- [社区论坛](https://github.com/chatwoot/chatwoot/discussions)
- [问题反馈](https://github.com/chatwoot/chatwoot/issues)
