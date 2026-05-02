# Chatwoot Helm Chart

[Chatwoot](https://chatwoot.com) 是一个开源的客户参与套件，作为 Intercom, Zendesk, Salesforce Service Cloud 等的开源替代方案。 🔥💬

> **注意：此版本为深度定制版 (Chart v3.3.39, App v4.13.0)**
> 已剥离内部绑定的 PostgreSQL 和 Redis，要求必须外部注入。修正了由于 K8s 不可变字段引发的升级错误。

## 环境要求

- Kubernetes 1.16+
- Helm 3.1.0+
- 底层基础设施支持 PV 卷配置

## 安装图表

安装名为 `chatwoot` 的 Release：

```console
$ helm install chatwoot chatwoot/chatwoot
```

默认配置会在 Kubernetes 集群上部署 Chatwoot。请参考下方的[参数说明](#参数说明)以根据您的环境进行配置。

> **提示**: 使用 `helm list` 列出所有的 Release。

## 卸载图表

删除/卸载 `chatwoot` 部署：

```console
helm delete chatwoot
```

该命令会移除图表相关的所有 Kubernetes 组件，并删除对应的 Release。

> **注意**: 持久化卷（Persistent Volumes）不会被自动删除。它们需要您手动进行清理。

## 参数说明

### 核心镜像参数

| 参数名              | 描述                                                 | 默认值                |
| ------------------- | ---------------------------------------------------- | --------------------- |
| `image.repository`  | Chatwoot 镜像仓库                                    | `chatwoot/chatwoot`    |
| `image.tag`         | Chatwoot 镜像标签 (建议使用不可变标签)                 | `v4.13.0`             |
| `image.pullPolicy`  | 镜像拉取策略                                         | `IfNotPresent`         |

### Chatwoot 核心环境变量 (通过 `env` 对象传入)

| 参数名                                 | 类型   | 默认值                                                     |
| ------------------------------------ | ------ | ---------------------------------------------------------- |
| `env.ACTIVE_STORAGE_SERVICE`         | 字符串 | `"local"` (云端使用 `amazon`，本地使用 `local`)            |
| `env.ASSET_CDN_HOST`                 | 字符串 | `""` (如果使用了 CDN 交付静态资源，请设置)                 |
| `env.INSTALLATION_ENV`               | 字符串 | `"helm"`                                                   |
| `env.ENABLE_ACCOUNT_SIGNUP`          | 字符串 | `"false"` (是否允许前台自主注册账号)                       |
| `env.FORCE_SSL`                      | 字符串 | `"false"` (是否强制 HTTPS 跳转)                            |
| `env.FRONTEND_URL`                   | 字符串 | `"https://chat.example.com"`                               |
| `env.RAILS_ENV`                      | 字符串 | `"production"`                                             |
| `env.RAILS_MAX_THREADS`              | 字符串 | `"5"`                                                      |
| `env.SECRET_KEY_BASE`                | 字符串 | **极度机密，用于签名 Cookie，请务必在 Values 中强行注入**  |

> 更多的电子邮件配置、第三方集成凭据等（如 AWS, Slack, Twitter 等），均通过 `env` 对象以键值对的形式在 `values.yaml` 中传递。

### 数据库配置 (强制使用外部集群)

本定制分支**不支持**在 Helm 内部安装 PostgreSQL 和 Redis（极度不推荐这种无状态与有状态混合部署的反模式）。
所有的数据库连接凭据，**必须直接通过环境变量传递**：

```yaml
env:
  # PostgreSQL 连接池配置
  POSTGRES_HOST: "pg-pooler-rw.cnpg.svc.cluster.local"
  POSTGRES_PORT: "5432"
  POSTGRES_DATABASE: "chatwoot"
  POSTGRES_USERNAME: "chatwoot"
  POSTGRES_PASSWORD: "YOUR_PG_PASSWORD"

  # Valkey/Redis 缓存及后台任务队列
  REDIS_URL: "redis://:YOUR_REDIS_PASSWORD@valkey-rw.valkey.svc.cluster.local:6379/0"
```

### 自动扩缩容 (HPA)

为 `web` 和 `worker` 提供 HPA 支持。建议仅在存在剧烈并发流量的环境下启用，并配合集群的 Metrics Server 使用：

| 参数名                              | 类型   | 默认值 |
| ----------------------------------- | ------ | ------ |
| `web.hpa.enabled`                   | 布尔   | `false`|
| `web.hpa.cputhreshold`              | 整数   | `75`   |
| `web.hpa.memorythreshold`           | 整数   | `75`   |
| `worker.hpa.enabled`                | 布尔   | `false`|

### 其他配置概览

您可以通过 `--set key=value`，或者更推荐的 `values.override.yaml` 文件来重写默认配置。

```bash
$ helm install my-release -f values.override.yaml chatwoot/chatwoot
```

## 升级指南

执行升级前，请使用 `helm repo update` 检查您要安装的 Chart 版本。我们采用了严格的语义化版本控制。

```bash
# 升级命令
helm upgrade chatwoot chatwoot/chatwoot -f values.override.yaml
```

**本定制分支 3.3.39 (App v4.13.0) 升级说明**：
- 此版本已经为您彻底解除了由上游 Label 修改导致的 `Deployment.apps is invalid: field is immutable` 报错。您可以像往常一样实现**零停机滚动升级**。
- 请务必确保您的自定义 `values.yaml` 中，没有遗留过时的 `postgresql:` 或是 `redis:` 独立对象区块，这些区块已经被彻底废弃。请直接在 `env:` 中填入对应地址和密钥。
