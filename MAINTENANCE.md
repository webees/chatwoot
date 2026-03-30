# 🧶 Chatwoot Helm Chart 维护指南

本项目是 [chatwoot/charts](https://github.com/chatwoot/charts) 的深度定制分支，面向**生产级高可用部署**。

---

## 🏗 架构特性

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
- **`readinessProbe`**：`/api`（检查 Redis + Postgres 连通性），失败则从 Service 摘除

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

## 🔄 上游同步策略

### 配置上游源（仅需一次）
```bash
git remote add upstream https://github.com/chatwoot/charts.git
```

### 同步流程
```bash
git fetch upstream
git diff main upstream/main  # 先对比差异
```

> ⚠️ **切勿**直接 `git merge upstream/main`。手动对比后选择性采纳，保护以下本地逻辑：
> - `values.yaml`：调度策略、外部基础设施配置、资源限制
> - `templates/policy.yaml`：NetworkPolicy + PDB + HPA/VPA
> - `templates/_helpers.tpl`：`chatwoot.pod.common` 中的 affinity 注入
> - `templates/web.yaml`：startupProbe、securityContext、RollingUpdate 策略

---

## 🚀 部署操作

### CLI 部署（推荐）
```bash
helm upgrade chatwoot ./charts/chatwoot \
  --install --wait --atomic --timeout 10m \
  -f charts/chatwoot/values.override.yaml
```

### Rancher UI 部署
1. 勾选 **Wait** 和 **Atomic**（失败自动回滚）
2. 超时时间设为 `600` 秒以上

### 部署前置条件
```bash
# 确保目标节点已打标签
kubectl label node <node-name> worker=true longhorn=true
```

---

## ✅ 升级后核查

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
```

---

## 🛠 版本演进日志

| 版本 | 关键变更 |
|------|----------|
| **v3.3.30** | 升级 v4.12.1：采纳上游 startupProbe、memory HPA、existingEnvSecret |
| **v3.3.28** | 原子化命名重构：PG/Redis 独立 `fullnameOverride`，`existingSecret` 解耦 Release 名，Ingress 启用，Service 切换为 ClusterIP |
| **v3.3.25** | 硬约束锁定：全组件强制 `nodeSelector: { worker: "true" }` |
| **v3.3.20** | 镜像标准化：PG 切换为 `pgvector/pgvector:pg16`，Redis 切换为 `library/redis:7.4` |
| **v3.3.19** | Chart 元数据清理：移除 maintainer 邮箱 |
| **v3.5–v3.9** | 测试矩阵：11 个测试套件 / 33+ 用例覆盖调度、安全、存储、边缘场景 |
| **v3.3.0** | 极客架构基线：原子化模板重构、VPA/HPA 自治、Redis tmpfs、零信任网络 |
