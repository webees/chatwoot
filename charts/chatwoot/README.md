# Chatwoot Helm Chart

[Chatwoot](https://chatwoot.com) 是一款开源的全渠道客户支持平台，是 Intercom、Zendesk、Salesforce Service Cloud 等平台的极佳开源替代方案。🔥💬

## 快速开始

```bash
helm repo add chatwoot https://chatwoot.github.io/charts
helm install chatwoot chatwoot/chatwoot
```

## 前置条件

- Kubernetes 1.16+
- Helm 3.1.0+
- 底层基础设施支持 PV（持久化卷）供应
- **[重要]** 外部部署的 PostgreSQL 数据库（要求 v11+，并安装 pgvector 插件）
- **[重要]** 外部部署的 Redis 缓存

## 安装 Chart

使用发行名称 `chatwoot` 安装此 Chart：

```console
$ helm install chatwoot chatwoot/chatwoot
```

该命令将使用默认配置在 Kubernetes 集群中部署 Chatwoot。请参考下方的[参数说明](#参数说明)部分，查看所有在安装时可以配置的参数。

> **提示**：使用 `helm list` 列出所有已安装的版本。

## 卸载 Chart

若要卸载/删除 `chatwoot` 部署：

```console
helm delete chatwoot
```

该命令将移除所有与该 Chart 关联的 Kubernetes 组件，并删除该版本。

> **注意**：持久化卷（Persistent Volumes）不会被自动删除。您需要手动清理它们。

---

## 数据库与缓存配置（必填）

本项目**不包含**内置的 PostgreSQL 和 Redis 部署。您**必须**通过环境变量配置外部提供的数据库和缓存。

请在您的 `values.yaml` 或部署命令中显式配置以下变量：

```yaml
env:
  # PostgreSQL 连接配置
  POSTGRES_HOST: "your-postgres-host.com"
  POSTGRES_PORT: "5432"
  POSTGRES_DATABASE: "chatwoot_production"
  POSTGRES_USERNAME: "postgres"
  POSTGRES_PASSWORD: "your-secure-password"

  # Redis 连接配置
  REDIS_URL: "redis://default:your-redis-password@your-redis-host.com:6379"
  # 如果您的 Redis 需要 TLS，请将 REDIS_TLS 设为 true 并使用 rediss:// 前缀
```

> ⚠️ **警告**：如果缺少上述连接凭证，Chatwoot 应用将无法启动。

---

## 参数说明

### Chatwoot 镜像参数

| 名称                  | 描述                                           | 默认值                |
| ------------------- | -------------------------------------------- | --------------------- |
| `image.repository`  | Chatwoot 镜像仓库                            | `chatwoot/chatwoot`    |
| `image.tag`         | Chatwoot 镜像标签（建议使用固定标签）            | `v4.13.0`             |
| `image.pullPolicy`  | 镜像拉取策略                                 | `IfNotPresent`         |


### Chatwoot 环境变量

| 名称                                 | 类型                                                                  | 默认值                                              |
| ------------------------------------ | ------------------------------------------------------------------- | ---------------------------------------------------------- |
| `env.ACTIVE_STORAGE_SERVICE`         | 文件存储服务。`local` 表示本地磁盘，`amazon` 表示 S3 或兼容 S3 的存储。 | `"local"`                                                  |
| `env.ASSET_CDN_HOST`                 | 如果使用 CDN 分发静态资源，请设置 CDN 域名。                           | `""`                                                       |
| `env.INSTALLATION_ENV`               | 设置 Chatwoot 的安装方式标识。                                        | `"helm"`                                                   |
| `env.ENABLE_ACCOUNT_SIGNUP`          | `true`：允许直接注册；`false`：完全禁用注册相关接口；`api_only`：禁用 UI 注册，但允许通过 API 创建账户。  | `"false"`                                                  |
| `env.FORCE_SSL`                      | 强制所有访问必须通过 SSL 进行，默认为 false。                           | `"false"`                                                  |
| `env.FRONTEND_URL`                   | 替换为您计划为应用配置的访问域名 URL。                                  | `"http://0.0.0.0:3000/"`                                   |
| `env.IOS_APP_ID`                     | 仅当您使用了自构建的移动端 iOS App 时才修改此变量。                      | `"6C953F3RX2.com.chatwoot.app"`                            |
| `env.ANDROID_BUNDLE_ID`              | 仅当您使用了自构建的移动端 Android App 时才修改此变量。                  | `"com.chatwoot.app"`                                       |
| `env.ANDROID_SHA256_CERT_FINGERPRINT`| 仅当您使用了自构建的移动端 Android App 时才修改此变量。                  | `"AC:73:8E:DE:EB:5............"`                           |
| `env.MAILER_SENDER_EMAIL`            | 用于发送所有系统通知及出站邮件的发件人邮箱。                             | `""`                                                       |
| `env.RAILS_ENV`                      | 设置 Rails 运行环境。                                                 | `"production"`                                             |
| `env.RAILS_MAX_THREADS`              | 每个 Worker 线程池使用的最大线程数。                                    | `"5"`                                                      |
| `env.SECRET_KEY_BASE`                | 用于验证签名 Cookie 完整性的秘钥。请务必设置一个安全的随机长字符串。          | `replace_with_your_super_duper_secret_key_base`            |
| `env.SENTRY_DSN`                     | Sentry 异常监控 DSN。                                                | `""`                                                       |
| `env.SMTP_ADDRESS`                   | SMTP 服务器地址。                                                    |`""`                                                        |
| `env.SMTP_AUTHENTICATION`            | SMTP 认证方式，可选值：`plain`、`login`、`cram_md5`                    | `"plain"`                                                  |
| `env.SMTP_ENABLE_STARTTLS_AUTO`      | 是否自动启用 STARTTLS，默认为 true。                                   | `"true"`                                                   |
| `env.SMTP_OPENSSL_VERIFY_MODE`       | 证书校验模式：`none`, `peer`, `client_once`, `fail_if_no_peer_cert`   | `"none"`                                                   |
| `env.SMTP_PASSWORD`                  | SMTP 密码                                                           | `""`                                                       |
| `env.SMTP_PORT`                      | SMTP 端口                                                           | `"587"`                                                    |
| `env.SMTP_USERNAME`                  | SMTP 用户名                                                         | `""`                                                       |
| `env.USE_INBOX_AVATAR_FOR_BOT`       | 机器人头像自定义选项                                                  | `"true"`                                                   |
| `env.DEFAULT_LOCALE`                 | 默认语言                                                            | `"zh-CN"`                                                  |

### 对话连续性的邮件设置（入站邮件）

| 名称                                | 类型                                                                                                                                                    | 默认值 |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| `env.MAILER_INBOUND_EMAIL_DOMAIN`   | 开启对话连续性（Conversation Continuity）功能时配置的回复邮箱主域名。                                                                                        | `""`          |
| `env.RAILS_INBOUND_EMAIL_SERVICE`   | 接收邮件的入站渠道。可选值有：`relay`, `mailgun`, `mandrill`, `postmark`, `sendgrid`。                                                                     | `""`          |
| `env.RAILS_INBOUND_EMAIL_PASSWORD`  | 邮件服务的密码。                                                                                                                                           | `""`          |
| `env.MAILGUN_INGRESS_SIGNING_KEY`   | 当使用 Mailgun 接收对话邮件时设置。                                                                                                                         | `""`          |
| `env.MANDRILL_INGRESS_API_KEY`      | 当使用 Mandrill 接收对话邮件时设置。                                                                                                                        | `""`          |

### 日志变量

| 名称                                | 类型                                                                | 默认值                                              |
| ----------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------- |
| `env.RAILS_LOG_TO_STDOUT`           | 字符串，指示是否将 Rails 日志输出至标准输出                             | `"true"`                                                   |
| `env.LOG_LEVEL`                     | 字符串，日志级别（info, debug 等）                                     | `"info"`                                                   |
| `env.LOG_SIZE`                      | 字符串，最大日志大小                                                  | `"500"`                                                    |

### 第三方凭证

| 名称                                | 类型                                                                 | 默认值                                              |
| ----------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| `env.S3_BUCKET_NAME`                | S3 存储桶名称                                                        | `""`                                                       |
| `env.AWS_ACCESS_KEY_ID`             | AWS Access Key ID                                                    | `""`                                                       |
| `env.AWS_REGION`                    | AWS Region（区域）                                                    | `""`                                                       |
| `env.AWS_SECRET_ACCESS_KEY`         | AWS Secret Key                                                       | `""`                                                       |
| `env.FB_APP_ID`                     | 用于 Facebook 渠道配置                                                | `""`                                                       |
| `env.FB_APP_SECRET`                 | 用于 Facebook 渠道配置                                                | `""`                                                       |
| `env.FB_VERIFY_TOKEN`               | 用于 Facebook 渠道配置                                                | `""`                                                       |
| `env.SLACK_CLIENT_ID`               | 用于 Slack 集成                                                       | `""`                                                       |
| `env.SLACK_CLIENT_SECRET`           | 用于 Slack 集成                                                       | `""`                                                       |
| `env.TWITTER_APP_ID`                | 用于 Twitter 渠道                                                     | `""`                                                       |
| `env.TWITTER_CONSUMER_KEY`          | 用于 Twitter 渠道                                                     | `""`                                                       |
| `env.TWITTER_CONSUMER_SECRET`       | 用于 Twitter 渠道                                                     | `""`                                                       |
| `env.TWITTER_ENVIRONMENT`           | 用于 Twitter 渠道                                                     | `""`                                                       |

### 弹性伸缩（Autoscaling）

要启用水平 Pod 自动扩缩容（HPA），请将 `web.hpa.enabled` 和 `worker.hpa.enabled` 设置为 `true`。请务必在此之前配置好 Kubernetes 集群的 metrics-server，并配置好容器的资源限制（`resources.limits` 与 `resources.requests`）。

| 名称                                | 类型                                                                 | 默认值                                              |
| ----------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| `web.hpa.enabled`                   | 是否为 Chatwoot Web 服务启用 HPA 自动扩缩容                             | `false`                                                    |
| `web.hpa.cputhreshold`              | Web 服务的 CPU 目标利用率阈值                                           | `75`                                                       |
| `web.hpa.memorythreshold`           | Web 服务的内存目标利用率阈值                                           | `75`                                                       |
| `web.hpa.minpods`                   | Web 服务的最小 Pod 数量                                                | `1`                                                        |
| `web.hpa.maxpods`                   | Web 服务的最大 Pod 数量                                                | `10`                                                       |
| `web.replicaCount`                  | 未启用 HPA 时，Web 服务的静态副本数                                      | `1`                                                        |
| `worker.hpa.enabled`                | 是否为 Chatwoot Worker 启用 HPA 自动扩缩容                              | `false`                                                    |
| `worker.hpa.cputhreshold`           | Worker 服务的 CPU 目标利用率阈值                                        | `75`                                                       |
| `worker.hpa.memorythreshold`        | Worker 服务的内存目标利用率阈值                                        | `75`                                                       |
| `worker.hpa.minpods`                | Worker 服务的最小 Pod 数量                                             | `2`                                                        |
| `worker.hpa.maxpods`                | Worker 服务的最大 Pod 数量                                             | `10`                                                       |
| `worker.replicaCount`               | 未启用 HPA 时，Worker 服务的静态副本数                                   | `1`                                                        |
| `autoscaling.apiVersion`            | Autoscaling API 版本                                                 | `autoscaling/v2`                                           |

### 其他高级参数

您可以通过覆盖常规 Kubernetes 资源配置来实现诸如节点亲和性（Affinity）、容忍度（Tolerations）以及拓扑扩散约束（topologySpreadConstraints）等高级调度需求。

| 键名 | 类型 | 默认值 | 描述 |
|-----|------|---------|-------------|
| affinity | object | `{}` | 定义所有 Pod 默认的亲和性规则 |
| existingEnvSecret | string | `""` | 允许您通过指定已存在的 Secret 名称来挂载环境变量 |
| fullnameOverride | string | `""` | 覆盖生成的 Release 完整名称 |
| ingress.enabled | bool | `false` | 是否开启 Ingress 路由支持 |
| nodeSelector | object | `{}` | 配置节点选择器标签 |
| podDisruptionBudget | object | `{}` | PDB（Pod 干扰预算）配置，用于保障 HA 特性 |
| resources | object | `{}` | 指定容器的 CPU/内存资源请求与限制 |
| service.type | string | `"ClusterIP"` | |
| serviceAccount.create | bool | `true` | 是否创建 ServiceAccount |
| topologySpreadConstraints | list | `[]` | 拓扑扩展约束列表，例如在跨可用区时均匀分布 Pod |

---

## 升级指南（Rancher 用户必读）

> [!CAUTION]
> **重大架构变更通知：** 从本版本开始，Chart 已经**彻底移除**了内置的 `postgresql` 和 `redis` subchart 依赖，强制要求使用外部数据库。
> 
> **如果您之前使用的是自带数据库的旧版 Chart，直接在 Rancher 中升级将导致旧的 Postgres/Redis Pod 和 PVC 被自动删除，您的所有数据将会丢失！**
> 
> **安全升级步骤（针对旧版内置数据库用户）：**
> 1. **切勿**直接升级现有的应用实例。
> 2. 将现有的 Web 和 Worker 副本数缩容为 0（确保无新数据写入）。
> 3. 进入原来的 `chatwoot-postgresql-0` Pod 中，使用 `pg_dump` 完整备份出数据。
> 4. 在集群外部（或集群内独立部署）建立新的高可用 PostgreSQL 和 Redis 实例，并将数据恢复到新实例中。
> 5. 使用本新版本 Chart 重新部署/升级，并在 `env` 环境变量中填写外部数据库和 Redis 的连接凭证。

执行 `helm repo update`，并在升级前检查要安装的版本。Helm Chart 遵循语义化版本控制，如果大版本号有变更，往往伴随着破坏性更新，升级前务必查阅更新日志。

```bash
# 更新 helm 仓库
helm repo update
# 检查当前安装版本
helm list
# 查看准备安装的最新版本
helm search repo chatwoot
```

然后执行升级操作，指定您自定义的配置：

```bash
helm upgrade chatwoot chatwoot/chatwoot -f <your-custom-values>.yaml
```
