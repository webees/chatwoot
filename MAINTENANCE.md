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

当前测试基线：`11` 个 test suites，`51` 个用例。新增模板能力必须补充 helm-unittest，尤其是 selector、Service、Secret、PVC、probe、hook 和外部 Secret。

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
5. 从 `3.3.38` 升级到 `3.3.46` 的预期变更仅限镜像版本、Web readiness 默认改回轻量 `/health`、探针参数渲染顺序、迁移 Job 的 PgBouncer/CNPG 与 Redis/Valkey 等待逻辑，以及兼容性配置能力增强；Deployment selector、Service、Secret、PVC 名称必须保持不变

### 推荐升级路径

1. 在 Rancher 中导出现有 Values，保存为升级前快照
2. 确认外部 PostgreSQL、Valkey/Redis、PVC 和节点标签正常
3. 使用新 Chart 执行升级，保持 Release 名和 `fullnameOverride` 不变
4. 等待迁移 Job 完成，再观察 Web readiness
5. 如升级失败，使用 Rancher/Helm rollback 回到上一 revision，不手工删除 PVC 或 Secret

### 部署前置条件
```bash
# 确保目标节点已打标签
kubectl label node <node-name> worker=true longhorn=true
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
