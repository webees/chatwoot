# 🧶 Chatwoot Helm Chart 维护指南

本项目是 [chatwoot/charts](https://github.com/chatwoot/charts) 的深度定制分支，面向**生产级高可用部署**。

---

## 🏗 架构特性

本 Chart 以 `chatwoot-3.3.38` 为 Rancher 兼容基线。后续升级只允许在该基线上选择性吸收上游修复，不能直接套用上游 `chatwoot/charts` 的模板拆分或资源重命名。

### 1. 节点调度（硬约束）
- **强制调度**：所有 Pod（Web、Worker、Migrate）必须运行在带有 `worker` 和 `longhorn` 标签的节点上
- **实现方式**：`requiredDuringSchedulingIgnoredDuringExecution` + `operator: Exists`
- **配置路径**：`_helpers.tpl` → `chatwoot.pod.common`

### 2. 原子化命名
- **`fullnameOverride: "chatwoot"`**：资源名称统一为 `chatwoot-web`、`chatwoot-worker` 等
- **密码管理**：PG/Redis 通过 `values.override.yaml` 中的 `env` 传入，或使用 `existingSecret` 引用外部 Secret

### 3. 外部基础设施
- **PostgreSQL**：外部 CNPG 集群 + PgBouncer 连接池（`pg-pooler-rw.cnpg.svc.cluster.local`）
- **Redis**：外部 Valkey HA（`valkey.valkey.svc.cluster.local`）
- 内置 Bitnami 子 Chart 默认禁用（`postgresql.enabled: false`, `redis.enabled: false`）

### 4. 三级健康检测
- **`startupProbe`**：`/health`，最长等待 5.5 分钟，容忍 Rails 冷启动和大版本迁移
- **`livenessProbe`**：`/health`，启动通过后每 10 秒检测，3 次失败重启
- **`readinessProbe`**：默认 `/health`（轻量 Web 存活检查），避免外部 Redis/Postgres 短时抖动阻塞 Rancher 升级；如需依赖感知上线，可显式设置 `web.readinessProbe.path: /api`

### 5. 安全加固
- Pod 以非 Root 用户运行（UID 1000），禁止权限提升
- NetworkPolicy 零信任默认开启（仅允许集群内通信 + DNS + 外部出站）
- 资源限制全组件覆盖（CPU/Memory limits）
- 敏感配置通过 `values.override.yaml`（已 `.gitignore`）传入，禁止提交仓库

### 6. 持久化存储
- `persistence.enabled: true`：为 `/app/storage`（上传文件）提供 PVC 挂载
- Web 和 Worker 共享同一 PVC（`ReadWriteMany`）

### 7. 弹性扩缩
- **HPA**：支持 CPU + Memory 双维度自动扩缩（默认关闭）
- **VPA**：支持垂直自动资源调优（默认关闭，开启时自动禁用 HPA 防冲突）
- **PDB**：节点驱逐保护（默认关闭）

### 8. 外部 Secret 叠加
- `existingEnvSecret`：在 Chart 管理的 `chatwoot-env` Secret 之后叠加外部 Secret
- 适用于 External Secrets Operator、Sealed Secrets 等场景
- 后加载的同名 key 会覆盖前者

### 9. 迁移 Hook 稳态控制
- `hooks.migrate.backoffLimit` 显式保留 Kubernetes Job 默认重试次数，便于 Rancher UI 审计
- `hooks.migrate.wait.timeoutSeconds` / `intervalSeconds` 控制 PgBouncer/CNPG 与 Valkey 等待节奏，默认仍为 `5s` 超时、`2s` 间隔
- `hooks.migrate.activeDeadlineSeconds`、`ttlSecondsAfterFinished` 和 `podAnnotations` 均为可选增强；默认不渲染，不改变升级行为

---

## 🔒 升级兼容性红线

以下字段影响 Kubernetes 不可变字段或 Rancher 升级引用，除非明确执行迁移方案，否则禁止修改：

| 资源 | 必须保持稳定的字段 |
|------|--------------------|
| Web Deployment | `metadata.name: chatwoot-web`、`spec.selector.matchLabels`、`role: web` |
| Worker Deployment | `metadata.name: chatwoot-worker`、`spec.selector.matchLabels`、`role: worker` |
| Service | `metadata.name: chatwoot`、selector 指向 `role: web` |
| Secret | `metadata.name: chatwoot-env` |
| PVC | `metadata.name: chatwoot-storage` |
| Hook Job | `metadata.name: chatwoot-migrate`、hook annotation 策略 |
| 基础命名 | `fullnameOverride: "chatwoot"` |

如果必须变更这些字段，先新建迁移版本并写清楚手动迁移步骤；不要在普通版本升级里直接修改。

---

## 🔄 上游同步策略

### 配置上游源（仅需一次）
```bash
git remote add upstream https://github.com/chatwoot/charts.git
```

### 同步流程
```bash
git fetch upstream
git diff main upstream/main  # 先对比差异
git log --oneline main..upstream/main
```

> ⚠️ **切勿**直接 `git merge upstream/main`。手动对比后选择性采纳，保护以下本地逻辑：
> - `values.yaml`：调度策略、外部基础设施配置、资源限制
> - `templates/policy.yaml`：NetworkPolicy + PDB + HPA/VPA
> - `templates/_helpers.tpl`：`chatwoot.pod.common` 中的 affinity 注入
> - `templates/web.yaml`：startupProbe、securityContext、RollingUpdate 策略

### 当前上游同步状态

- 已对比 `chatwoot/charts` 上游 `main`：`dbc95a4f0 feat: upgrade charts to chatwoot v4.13.0 (#204)`
- 选择性采纳：Chatwoot `v4.13.0` 镜像、可配置 Web 探针、迁移 Job 使用 Chatwoot 镜像，并结合 PgBouncer/CNPG 真实要求使用带 `-U/-d` 的 `pg_isready` 与 Redis/Valkey TCP 检查
- 明确不采纳：上游模板重命名、拆分 HPA/ServiceAccount/Secret、移除本地 helm-unittest 套件等会影响 Rancher 升级兼容性的结构性改动

### 允许选择性采纳的上游变更

- Chatwoot 应用镜像版本升级
- 探针默认值或探针可配置能力
- 初始化容器的兼容性修复
- Secret/env 注入 bugfix
- Kubernetes API 版本兼容修复
- 不改变资源名称、selector、PVC、Service、Secret、Hook 名称的模板修复

### 默认拒绝的上游变更

- 模板文件重命名导致 Rancher diff 难以审计
- Deployment selector、label 体系重构
- Service/Secret/ServiceAccount/HPA/PDB 拆分或重命名
- 删除本地 helm-unittest 套件
- 默认启用内置 PostgreSQL/Redis
- 改变 `fullnameOverride` 或 Release 命名策略

---

## 🧪 本地验证流程

每次提交前必须执行：

```bash
helm dependency build charts/chatwoot
helm lint charts/chatwoot
helm template chatwoot charts/chatwoot >/tmp/chatwoot-template.yaml
helm unittest charts/chatwoot
```

升级兼容性变更还需要检查关键字段：

```bash
rg -n "name: chatwoot-web|name: chatwoot-worker|name: chatwoot-storage|name: chatwoot-env|path: /health|pg_isready|TCPSocket.new" /tmp/chatwoot-template.yaml
```

当前测试基线：`12` 个 test suites，`59` 个用例。新增模板能力必须补充 helm-unittest，尤其是 selector、Service、Secret、PVC、probe、hook、镜像仓库覆盖、外部 Secret 和脱敏后的 Rancher 生产 Values。

---

## 🚀 部署与升级操作

### CLI 部署（推荐）
```bash
helm upgrade chatwoot ./charts/chatwoot \
  --install --wait --atomic --timeout 10m \
  -f charts/chatwoot/values.override.yaml
```

### Rancher UI 部署
1. 勾选 **Wait** 和 **Atomic**（失败自动回滚）
2. 超时时间设为 `600` 秒以上
3. 保持 `fullnameOverride: "chatwoot"`，不要在升级时修改 Release 名、Service 名、PVC 名或 selector 相关配置
4. 使用 Rancher Values 或 `values.override.yaml` 管理 `SECRET_KEY_BASE`、`POSTGRES_PASSWORD` 等敏感配置，避免提交到仓库
5. 从 `3.3.38` 升级到 `3.3.52` 的预期变更仅限镜像版本、Web readiness 默认改回轻量 `/health`、探针参数渲染顺序、迁移 Job 的 PgBouncer/CNPG 与 Redis/Valkey 等待逻辑、CI 维护、镜像仓库说明，以及兼容性配置能力增强；Deployment selector、Service、Secret、PVC 名称必须保持不变

### 推荐升级路径

1. 在 Rancher 中导出现有 Values，保存为升级前快照
2. 确认外部 PostgreSQL、Valkey/Redis、PVC 和节点标签正常
3. 使用新 Chart 执行升级，保持 Release 名和 `fullnameOverride` 不变
4. 等待迁移 Job 完成，再观察 Web readiness
5. 如升级失败，使用 Rancher/Helm rollback 回到上一 revision，不手工删除 PVC 或 Secret

### 镜像仓库与 GHCR 检查

如果生产环境通过 GHCR 或 registry mirror 拉取 Chatwoot 镜像，必须在 Rancher Values 中显式保留镜像仓库配置，避免升级时回落到 Chart 默认镜像引用。

```yaml
image:
  repository: ghcr.io/<org>/<image>
  tag: v4.13.0
  pullPolicy: IfNotPresent
```

升级前后用以下命令确认 Helm Values 和 Deployment 的实际镜像引用一致：

```bash
helm get values chatwoot -n chatwoot -o yaml | yq '.image'
kubectl get deploy chatwoot-web chatwoot-worker -n chatwoot -o yaml | grep -n 'image:'
```

如果 Kubernetes event 显示拉取失败，不要只按域名下结论；先确认该节点的 containerd registry mirror 是否生效，以及失败发生在原始镜像引用还是镜像仓库代理通道。

### 线上验证记录：v3.3.47

- 验证时间：`2026-05-11 22:30`（Asia/Bangkok）
- 集群入口：`100.100.255.255`，namespace `chatwoot`
- 升级包：`chatwoot-3.3.47.tgz`，SHA256 `88279f7151f5812adb1693ff0b8b1f778dd3e26a2a65037bee2d570febbfb158`
- `revision 16` 首次升级失败原因：`wk-th-colo-01` 拉取当时渲染出的镜像引用 `chatwoot/chatwoot:v4.13.0` 超时/拒绝连接。若生产环境实际通过 GHCR 或 registry mirror 拉取镜像，应将问题归类为该节点到镜像仓库/镜像代理通道异常，不是迁移 Hook 或模板渲染错误
- `revision 17` 使用同一份线上 Values，并显式保持原有规模 `web.replicaCount=1`、`worker.replicaCount=1` 后升级成功
- 最终状态：`STATUS: deployed`，Chart `chatwoot-3.3.47`，App `v4.13.0`
- Pod 状态：`chatwoot-web 1/1 Running`、`chatwoot-worker 1/1 Running`
- 健康检查：`/health` 返回 `200` 和 `{"status":"woot"}`
- 迁移 Job：Hook 成功后已按策略删除，namespace 中无残留 Job
- 最近 Web/Worker 日志未发现 `FATAL`、`ERROR`、`Rack::Timeout` 或 `Internal Server Error`

> 兼容性结论：Rancher 线上环境如果历史上手动缩放到 1 副本，后续升级必须在 Values 中显式保留 `web.replicaCount: 1`、`worker.replicaCount: 1` 和生产使用的 `image.repository`，避免 Chart 默认值触发额外 Pod 或错误镜像仓库拉取。

### 部署前置条件
```bash
# 确保目标节点已打标签
kubectl label node <node-name> worker=true longhorn=true
```

---

## 🧯 迁移 Job 排障速查

迁移 Hook 是 Rancher 升级最容易超时的位置。排障顺序固定为：先看 init 容器，再看真正的 migrate 容器。

```bash
kubectl get pods -n chatwoot -l job-name=chatwoot-migrate -o wide
kubectl logs -n chatwoot job/chatwoot-migrate -c init-db
kubectl logs -n chatwoot job/chatwoot-migrate -c init-cache
kubectl logs -n chatwoot job/chatwoot-migrate -c migrate
```

如果 `init-db` 卡住，必须用和 Chart 一致的身份检查 PgBouncer/CNPG：

```bash
kubectl run pg-ready-check -n chatwoot --rm -it --restart=Never \
  --image=chatwoot/chatwoot:v4.13.0 -- \
  pg_isready -h pg-pooler-rw.cnpg.svc.cluster.local -p 5432 -U chatwoot -d chatwoot -t 5
```

如果 `migrate` 报 `must be owner of table ...`，这不是 Chart 权限不足，而是数据库历史对象 owner 不一致。用数据库管理员账号确认所有权后再修复，避免只给 `GRANT` 导致迁移仍失败：

```sql
SELECT tablename, tableowner FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
ALTER SCHEMA public OWNER TO chatwoot;
ALTER DATABASE chatwoot OWNER TO chatwoot;
```

对外部 Valkey/Redis，优先检查 TCP 可连通性，不只看 DNS 解析：

```bash
kubectl run cache-ready-check -n chatwoot --rm -it --restart=Never \
  --image=chatwoot/chatwoot:v4.13.0 -- \
  ruby -rsocket -rtimeout -e 'Timeout.timeout(5) { s = TCPSocket.new(ARGV[0], Integer(ARGV[1])); s.close }' \
  valkey-rw.valkey.svc.cluster.local 6379
```

---

## ✅ 升级后核查与回滚

```bash
# 1. 确认 Pod 运行在 worker 节点
kubectl get pods -n chatwoot -o wide

# 2. 确认镜像版本正确
kubectl get pods -n chatwoot -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# 3. 确认 startupProbe 已生效
kubectl get deploy chatwoot-web -n chatwoot -o jsonpath='{.spec.template.spec.containers[0].startupProbe.failureThreshold}'
# 期望输出: 30

# 4. 确认迁移 Job 成功
kubectl get jobs -n chatwoot | grep migrate

# 5. 确认 NetworkPolicy 已生效
kubectl get networkpolicy -n chatwoot

# 6. 确认升级关键资源名称未变化
kubectl get deploy,svc,secret,pvc -n chatwoot | grep chatwoot
```

如果需要回滚：

```bash
helm history chatwoot -n chatwoot
helm rollback chatwoot <REVISION> -n chatwoot --wait --timeout 10m
kubectl get pods -n chatwoot -o wide
```

回滚时不要删除 `chatwoot-storage` PVC、`chatwoot-env` Secret 或外部数据库/Redis Secret。若迁移 Job 已执行过数据库迁移，先确认 Chatwoot 版本是否支持回滚。

---

## 🛠 版本演进日志

| 版本 | 关键变更 |
|------|----------|
| **v3.3.52** | CI 修复：手动安装 `ct v3.14.0` 后显式关闭缺省 `chart_schema.yaml` 和 maintainer 账号校验，保留 Helm lint 与 helm-unittest 主验证路径；测试基线维持 59 个用例 |
| **v3.3.51** | CI 日志优化：移除 `helm/chart-testing-action` 对 `setup-uv` cache 的隐式依赖，改为直接安装 `ct v3.14.0` 二进制，消除无 Python 依赖文件时的 cache annotation；测试基线维持 59 个用例 |
| **v3.3.50** | 文档修正：将线上拉镜像失败归类为镜像仓库/GHCR/registry mirror 通道问题，避免误写死为 Docker Hub；新增 GHCR 镜像仓库覆盖验证说明；补充 GHCR repository override 测试，测试扩展到 59 个用例 |
| **v3.3.49** | CI 日志优化：移除冗余 `actions/setup-python`，依赖 `helm/chart-testing-action@v2.8.0` 内置的 `uv` 安装链，避免无 Python 依赖文件时产生缓存 annotation；保持 Node 24 兼容 Actions；测试基线维持 58 个用例 |
| **v3.3.48** | 维护优化：升级 GitHub Actions 到 Node 24 兼容版本并启用 Node 24 opt-in；新增脱敏 Rancher 生产 Values 兼容测试，覆盖副本数、旧 `s3_compatible` 存储值、外部 CNPG/Valkey、readiness 和双域名 Ingress；测试扩展到 58 个用例 |
| **v3.3.47** | 非破坏性优化：迁移 Hook 增加显式 `backoffLimit`、等待超时/间隔参数、可选 Job 生命周期字段和 Pod 注解；默认行为与 3.3.46 保持一致；补充迁移 Job 排障 runbook；测试扩展到 52 个用例 |
| **v3.3.46** | 线上环境修复：迁移 Job 的 `init-db` 使用带 `-U/-d` 的 `pg_isready`，兼容 PgBouncer/CNPG 对用户名和数据库的要求；`init-cache` 改为 Redis/Valkey TCP 检查，避免只解析 DNS 造成误判；测试扩展到 51 个用例 |
| **v3.3.45** | Rancher 升级兼容修复：默认 readinessProbe 改回轻量 `/health`，避免 `/api` 的 Redis/Postgres 深度检查拖慢或阻断升级；保留 `web.readinessProbe.path: /api` 作为显式依赖感知模式；测试扩展到 50 个用例 |
| **v3.3.44** | Rancher 升级兼容修复：放宽 `storage.type` schema，允许旧 Values 中的历史存储类型通过校验，并按既有模板逻辑安全回退到本地存储；测试扩展到 49 个用例 |
| **v3.3.43** | 非破坏性优化：收窄 checksum 到 Secret data，支持 pod/serviceAccount 注解、nodeSelector/tolerations、迁移 Job 独立资源配置，修正自定义 ServiceAccount 名称创建，并将测试扩展到 48 个用例 |
| **v3.3.40** | 基于 3.3.38 稳定架构升级 Chatwoot v4.13.0；采纳上游可配置探针、`/api` readiness、`getent` Redis 检查；补充 Rancher 升级保护测试与兼容性 schema；保留稳定 selector、统一 Pod 规范与 `policy.yaml` |
| **v3.3.30** | 升级 v4.12.1：采纳上游 startupProbe、memory HPA、existingEnvSecret |
| **v3.3.28** | 原子化命名重构：PG/Redis 独立 `fullnameOverride`，`existingSecret` 解耦 Release 名，Ingress 启用，Service 切换为 ClusterIP |
| **v3.3.25** | 硬约束锁定：全组件强制 `nodeSelector: { worker: "true" }` |
| **v3.3.20** | 镜像标准化：PG 切换为 `pgvector/pgvector:pg16`，Redis 切换为 `library/redis:7.4` |
| **v3.3.19** | Chart 元数据清理：移除 maintainer 邮箱 |
| **v3.5–v3.9** | 测试矩阵：11 个测试套件 / 33+ 用例覆盖调度、安全、存储、边缘场景 |
| **v3.3.0** | 极客架构基线：原子化模板重构、VPA/HPA 自治、Redis tmpfs、零信任网络 |
