# 维护指南：Chatwoot Helm Chart 定制化说明

### 🛠 维护记录 (Maintenance Log)

#### v3.7.0 (2026-03-04) - 功能推导全深度验证
- **Functional Coverage**: 新增 `storage_test.yaml` 与 `vpa_test.yaml`。
- **Engine Analytics**: 首次实现了对“配置编程化”逻辑（S3/GCS 自动推导）的单元测试覆盖。
- **Deterministic CI**: 优化了 `policy.yaml` 的渲染确定性，消除了由于空文档导致的测试偏移。

#### v3.6.0 (2026-03-04) - 严苛 CI/CD 与自动化集成
- **Workflow Consolidation**: 将 `Lint/Test` 与 `Release` 合并为单一流水线，引入 `needs` 依赖门禁。
- **Safety Gate**: 确保 100% 单元测试通过后方可执行版本自增与发布。
- **Version Automation**: 优化了 `yq` 脚本，实现版本号与 Chart 描述的同步自增。

#### v3.5.0 (2026-03-04) - 安全增强与严苛测试
- **Zero-Downtime**: 引入 `terminationGracePeriodSeconds` 与 `failureThreshold` 优化。
- **Strict Testing**: 新增 `security_test.yaml`，覆盖零信任网络策略验证。
- **CI Fix**: 彻底修复了多套件下的 `DocumentIndex` 偏移导致的测试报错。
- **Documentation**: 全面订正文档以匹配 v3.5 极客安全标准。

本项目是官方 [chatwoot/charts](https://github.com/chatwoot/charts) 的深度定制分支。它保留了针对高可用性 (HA)、ARM64 架构支持和极致性能优化的增强功能。

## 🔄 上游同步策略

在保持本地定制化的同时，按照以下步骤同步上游更新：

### 1. 配置上游源（仅需执行一次）
```bash
git remote add upstream https://github.com/chatwoot/charts.git
```

### 2. 获取并对比更新
**切勿**简单的执行 `git merge upstream/main`。建议使用变基 (rebase) 或手动合并，以确保本地的高可用模板和 `values.yaml` 中的精控逻辑不被覆盖。

```bash
git fetch upstream
# 检查差异
git diff main upstream/main
```

### 3. 重点保护的逻辑
解决冲突时，请确保保留以下本地核心逻辑：
- `values.yaml`：文档中标记的所有定制化配置。
- `templates/policy.*.yaml`：本项目独有的 PDB 和策略模板。
- `templates/*.yaml`：注入到 Deployment 中的 `affinity` 和 `topologySpreadConstraints` 逻辑。

---

## 🛠 本地定制化日志

### 1. 高可用与调度 (HA)
*   **节点约束**：所有 Pod 强制运行在带有 `worker` 标签的节点上。
*   **拓扑分布**：启用了 `topologySpreadConstraints`，防止 Pod 在单一节点上过度集中。
*   **PDB 保护**：`policy.pdb.yaml` 为 Web 和 Worker 提供了 Pod 干扰预算。
*   **亲和性**：在 `values.yaml` 中定义了全局 `nodeAffinity` 并注入到所有模板。

### 2. Redis 性能（全内存模式）
专为临时缓存和队列设计，消除持久化磁盘开销。
*   **架构**：切换为 `standalone` 模式，移除所有副本 Pod 及复杂的副本集逻辑。
*   **持久化**：已完全禁用 (`persistence.enabled: false`)。
*   **存储**：使用 `emptyDir` 挂载，并指定 `medium: Memory` (tmpfs)。

### 3. ARM64 架构支持
官方 Chatwoot 镜像在 2025 年停止了对 PostgreSQL 的 ARM 支持。
*   **镜像**：从 `ghcr.io/chatwoot/pgvector` 切回多架构支持的 `docker.io/pgvector/pgvector:pg16`。
*   **配置路径**：`values.yaml` -> `postgresql.image`。

### 4. 极致命名简化
*   **覆盖名**：`fullnameOverride: "chatwoot"`。
*   **优势**：资源名称更简洁（例如 `chatwoot-web` 而非复杂的随机后缀）。
*   **警告**：在已有环境中更改此项会导致资源重建，触发极短的服务中断。

### 5. 安全加固 (v2.1.13+)
*   **非 Root 运行**：Pod 默认以 UID 1000 运行，禁止权限提升。
*   **资源限制**：为数据库和核心组件设置了严格的 CPU/内存 `limits`，防止某个组件影响整机稳定性。

---

## 🛡 升级安全与原子回滚

本 Chart 针对“原子化”升级进行了深度优化。

### 1. 安全保障机制：
- **零停机策略**：Web 和 Worker 使用 `maxUnavailable: 0`。旧 Pod 会一直运行，直到新 Pod 通过就绪检查。
- **迁移关卡**：数据库迁移任务 (`migrate`) 以钩子形式运行。如果迁移失败，升级将立即中止。
- **健康检测**：具备严格的 `startupProbe`，能在应用启动失败时第一时间拦截错误。

### 2. 推荐的命令行操作：
```bash
helm upgrade chatwoot ./charts/chatwoot \
  --install \
  --wait \
  --atomic \
  --timeout 10m
```

### 3. Rancher UI 配置建议：
1. 进入**升级**页面。
2. 在 **Helm 配置项**中，确保勾选了 **"Wait" (等待)**。
3. 确保勾选了 **"Atomic" (原子化)** 或 **"Rollback on failure" (失败回滚)**。
4. 将**超时时间**设置为至少 `600` 秒。

---

## ✅ 升级后核查清单
同步或升级后，请务必确认：
1. `kubectl get pods -o wide`：确认 Pod 运行在 `worker` 节点。
2. `kubectl describe pod <redis-pod>`：确认镜像仓库和磁盘挂载正确。
3. `kubectl get pdb`：确认 PDB 保护已生效。
