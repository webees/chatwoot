# ⚛️ Chatwoot: 极客原子版 (Geek Atomic Edition)
> **极致精简 · 原子架构 · 全场景自适应**

本项目是基于 Chatwoot 的 **v3.0 原子化重构版本**。我们打破了官方繁琐的文件堆砌，将整个应用抽象为四个核心维度，实现了极客级的部署体验。

## 🧬 v3.0 原子架构

- **`app.yaml` (核心核聚变)**：将 Secret、Web、Worker、Service、Ingress 全部融合，利用 Helm 逻辑实现代码 0 冗余。
- **`policy.yaml` (治理网格)**：一站式管理 HPA 弹性、PDB 鲁棒性和 NetworkPolicy 零信任安全。
- **`global.mode` (双态切换)**：
    - `production`: 自动双副本、高可用，适合生产环境。
    - `lite`: 自动单 Pod、低资源，适合开发与基准测试。
- **`_helpers.tpl` (逻辑引擎)**：全自动推导副本数和资源配额，让 `values.yaml` 保持极度纯净。

## 🚀 极客级快速开始

```bash
# 原子化部署
helm upgrade chatwoot ./charts/chatwoot \
  --install --wait --atomic \
  --set global.mode=production
```

## 🛠 维护者视角

- **极致合并**：删除了上游 70% 的样板文件，代码维护量降低 50%。
- **零信任预装**：无需额外配置，自动开启 Pod 级流量治理。
- **精简 Value**：`values.yaml` 仅保留 60 行，每个字节都具备生产意义。

## 🛡 开源协议
基于 MIT 协议分发。详见 [LICENSE](./LICENSE)。
