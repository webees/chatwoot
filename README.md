# ⚛️ Chatwoot Helm Chart — 极客进化版

> **Chatwoot v4.13.0** · Chart v3.3.39 · 严苛 CI/CD · 零停机升级 · 模块化安全治理

本项目是 [chatwoot/charts](https://github.com/chatwoot/charts) 的**生产级深度定制分支**，基于最新的上游特性，保留其有价值的增强（例如可配置的探针等），并彻底摒弃了臃肿的内置数据库依赖与安全短板。

## 🧬 模块化架构

| 模板 | 职责 |
|------|------|
| `env-secret.yaml` | 统一管理环境变量（移除强行绑定的子图表配置） |
| `web.yaml` | Web Deployment + Service（极简整合设计） |
| `worker.yaml` | Sidekiq 异步处理单元（独立扩缩容） |
| `persistence.yaml` | 上传文件持久化存储（PVC） |
| `ingress.yaml` | 流量入口控制 |
| `job.migrate.yaml` | 数据库自动迁移（post-upgrade hook） |

## 🛡 生产加固特性

- **彻底解耦**：移除内置 PostgreSQL / Redis 子依赖，强制要求使用 `env` 连接高可用外部集群，避免环境污染。
- **不可变升级保护**：强制回退并锁定 `selector.matchLabels` 规范，一劳永逸解决 Kubernetes 平滑升级时“不可变字段”引发的升级故障。
- **节点硬约束**：全组件强制调度到 `worker` + `longhorn` 标签节点（可选）。
- **零停机升级**：`RollingUpdate` + `maxUnavailable: 0`。
- **智能健康检测**：`startupProbe`（超长启动窗口）→ `livenessProbe`（/health）→ `readinessProbe`（/api）。
- **零信任网络**：NetworkPolicy 默认开启（可选），仅允许集群内通信 + 外部出站。
- **外部 Secret 叠加**：`existingEnvSecret` 支持 External Secrets Operator 等外部 Secret 注入。

## 🚀 快速部署

```bash
# 前置：准备外部高可用数据库集群（PostgreSQL 和 Valkey/Redis）

# 部署（推荐）
helm upgrade chatwoot ./charts/chatwoot \
  --install --wait --atomic --timeout 10m \
  -f charts/chatwoot/values.override.yaml
```

> 敏感配置（如数据库密码、密钥）请务必通过 `values.override.yaml` 的 `env:` 模块传入，该文件已加入 `.gitignore`。

## 🧪 CI/CD

集成 `Lint → Release` 自动化流水线。模板发生任何变动，GitHub Actions 均会自动打包并发布最新的 Chart。

## 📖 维护指南

关于详细的架构设计、升级灾备处理与数据库运维决策，请参阅内部沉淀的 [Maintenance KIs](https://github.com/webees/chatwoot)。

## 📄 开源协议

基于 MIT 协议分发。详见 [LICENSE](./LICENSE)。
