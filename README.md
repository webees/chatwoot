# ⚛️ Chatwoot Helm Chart — 极客进化版

> **Chatwoot v4.13.0** · Chart v3.3.43 · 严苛 CI/CD · 零停机升级 · 模块化安全治理

本项目是 [chatwoot/charts](https://github.com/chatwoot/charts) 的**生产级深度定制分支**，基于 `3.3.38` 的 Rancher 兼容加固架构进行安全升级，保留其有价值的增强，摒弃臃肿与安全短板。

## 🧬 模块化架构

| 模板 | 职责 |
|------|------|
| `base.yaml` | Secret 环境变量 + ServiceAccount 身份 |
| `web.yaml` | Web Deployment + Service（垂直整合） |
| `worker.yaml` | Sidekiq 异步处理单元（独立扩缩容） |
| `policy.yaml` | HPA/VPA 弹性 + PDB 鲁棒性 + NetworkPolicy 零信任 |
| `persistence.yaml` | 上传文件持久化存储（PVC） |
| `ingress.yaml` | 流量入口控制 |
| `job.migrate.yaml` | 数据库自动迁移（post-upgrade hook） |

## 🛡 生产加固特性

- **节点硬约束**：全组件强制调度到 `worker` + `longhorn` 标签节点
- **零停机升级**：`RollingUpdate` + `maxUnavailable: 0` + `terminationGracePeriodSeconds: 60`
- **三级健康检测**：`startupProbe`（5.5 分钟启动窗口）→ `livenessProbe`（/health）→ `readinessProbe`（/api）
- **安全运行**：Pod 以非 Root 用户运行（UID 1000）
- **零信任网络**：NetworkPolicy 默认开启，仅允许集群内通信 + DNS + 外部出站
- **资源治理**：显式 CPU/Memory limits + HPA（CPU + Memory 双维度）+ VPA 可选
- **PDB 保护**：节点驱逐时保证最小可用副本
- **外部 Secret 叠加**：`existingEnvSecret` 支持 External Secrets Operator 等外部 Secret 注入
- **持久化存储**：`persistence` 为 `ACTIVE_STORAGE_SERVICE: local` 提供 PVC 挂载

## 🚀 快速部署

```bash
# 前置：节点打标签
kubectl label node <node-name> worker=true longhorn=true

# 部署（推荐）
helm upgrade chatwoot ./charts/chatwoot \
  --install --wait --atomic --timeout 10m \
  -f charts/chatwoot/values.override.yaml
```

> 敏感配置（密码、密钥）通过 `values.override.yaml` 传入，该文件已加入 `.gitignore`。

## 🧪 CI/CD

集成 `Lint → Unit Test (48 cases) → Release` 流水线。任何测试失败都将中止发布。

## 📖 维护指南

详见 [MAINTENANCE.md](./MAINTENANCE.md)。

## 📄 开源协议

基于 MIT 协议分发。详见 [LICENSE](./LICENSE)。
