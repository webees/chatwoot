# ⚛️ Chatwoot: 极客进化版 (Geek Evolution v3.4)
> **极简模块化 · 智能配置 · 持续版本管理**

本项目是 Chatwoot Helm Chart 的 **v3.4 深度进化版本**。我们摒弃了传统 Chart 的臃肿，实现了高度抽象与自动化。

## 🧬 v3.4 模块化架构

为了兼顾“极简”与“可维护性”，我们将应用解构为以下四个核心维度：

- **`base.yaml` (基础单元)**：管理 Secret 环境变量与 ServiceAccount 身份。
- **`web.yaml` (应用单元)**：将 Web Deployment 与其访问 Service 垂直整合，确保组件自治。
- **`worker.yaml` (任务单元)**：独立的 Sidekiq 异步处理单元，支持独立扩缩容。
- **`policy.yaml` (治理网格)**：一站式管控 HPA 弹性、PDB 鲁棒性与 NetworkPolicy 零信任安全。

## 🛡 升级安全与零停机 (v3.5 New!)

我们将“安全”贯穿于 Chart 设计的每一行：

- **原子化升级**：建议使用 `helm upgrade --atomic`。我们在 `strategy` 中强制设置了 `maxUnavailable: 0`，确保新 Pod 就绪前旧 Pod 不会下线。
- **优雅停机**：设置了 `terminationGracePeriodSeconds: 60`，给 Rails 和 Sidekiq 充足的时间处理残留请求或任务。
- **动态就绪检测**：精细化配置了 `liveness` 和 `readiness` 探针，通过 `failureThreshold` 缓冲启动抖动。
- **分阶段迁移**：数据库迁移任务具备独立的 `nslookup` 检查，确保基础设施完全就绪后再执行 DDL。

## 🚀 核心极客特性

- **`global.mode` (环境双态)**：一键切换 `production`（高可用）与 `lite`（轻量级）模式。
- **智能存储引擎**：通过 `values.yaml` 中的对象化配置，自动生成 S3/GCS 等存储环境。
- **自动资源优化**：内嵌 VPA (Vertical Pod Autoscaler) 支持，让应用具备“新陈代谢”般的自愈能力。
- **持续版本管理**：集成 CI 自动化流，每次代码推送自动升级版本并发布 Release。

## � 运维指令

```bash
# 智能部署
helm upgrade chatwoot ./charts/chatwoot \
  --install --wait --atomic \
  --set global.mode=production
```

## 🛡 开源协议
基于 MIT 协议分发。详见 [LICENSE](./LICENSE)。
