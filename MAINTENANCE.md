# 🧶 Chatwoot Helm Chart 维护指南

本项目是 [chatwoot/charts](https://github.com/chatwoot/charts) 的深度定制分支，面向**生产级高可用部署**。

---

## 🏗 架构特性

### 1. 节点调度（硬约束）
- **强制调度**：所有 Pod（Web、Worker、PG、Redis、Migrate）必须运行在带有 `worker` 和 `longhorn` 标签的节点上
- **实现方式**：`requiredDuringSchedulingIgnoredDuringExecution` + `operator: Exists`
- **配置路径**：`_helpers.tpl` → `chatwoot.pod.common`，`values.yaml` → `postgresql.primary.affinity` / `redis.master.affinity`

### 2. 原子化命名
- **`fullnameOverride: "chatwoot"`**：资源名称统一为 `chatwoot-web`、`chatwoot-worker` 等
- **子 Chart 独立命名**：`postgresql.fullnameOverride: "chatwoot-postgresql"`，`redis.fullnameOverride: "chatwoot-redis"`
- **密码迁移**：PG/Redis 使用 `existingSecret` 引用外部 Secret（`chatwoot-postgresql-auth`、`chatwoot-redis-auth`），解耦 Release 名称

### 3. Redis 全内存模式
- **架构**：`standalone` 模式，禁用持久化
- **存储**：`emptyDir` + `medium: Memory` (tmpfs)，零磁盘 I/O

### 4. ARM64 多架构支持
- **PostgreSQL**：使用 `pgvector/pgvector:pg16` 替代 Bitnami 官方镜像
- **Redis**：使用 `library/redis:7.4` 官方多架构镜像

### 5. 安全加固
- Pod 以非 Root 用户运行（UID 1000），禁止权限提升
- NetworkPolicy 零信任默认开启（仅允许集群内通信 + DNS + 外部出站）
- 资源限制全组件覆盖（CPU/Memory limits）
- 敏感配置通过 `values.override.yaml`（已 `.gitignore`）传入，禁止提交仓库

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

> ⚠️ **切勿**直接 `git merge upstream/main`。使用变基或手动合并，保护以下本地逻辑：
> - `values.yaml`：调度策略、镜像配置、Secret 引用
> - `templates/policy.yaml`：NetworkPolicy + PDB + HPA/VPA
> - `templates/_helpers.tpl`：`chatwoot.pod.common` 中的 affinity 注入

---

## � 部署操作

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

# 确保外部 Secret 已创建
kubectl create secret generic chatwoot-postgresql-auth \
  --from-literal=postgres-password=<YOUR_PG_PASSWORD> -n chatwoot
kubectl create secret generic chatwoot-redis-auth \
  --from-literal=redis-password=<YOUR_REDIS_PASSWORD> -n chatwoot
```

---

## ✅ 升级后核查

```bash
# 1. 确认 Pod 运行在 worker 节点
kubectl get pods -n chatwoot -o wide

# 2. 确认镜像版本正确
kubectl get pods -n chatwoot -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# 3. 确认 NetworkPolicy 已生效
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
