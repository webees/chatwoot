# 🧶 Chatwoot: 艺术级加固版
> **极简 · 安全 · 高性能**

本项目是 Chatwoot 官方 Helm Chart 的专业深加工分支，经过精心重构，专为追求 **零停机升级**、**极致代码精简** 和 **架构美学** 的生产环境设计。

## ✨ 核心增强特性

- **艺术级重构**：统一且具备语义化的命名规范 (`deployment.web.yaml`, `job.migrate.yaml`) 以及简洁的助手函数命名空间 (`db`, `cache`, `pod.common`)。
- **生产级加固**：预配置 Pod 干扰预算 (PDB)、水平自动扩缩容 (HPA) 以及严格的 `RollingUpdate` 滚动更新策略。
- **ARM64 完美支持**：原生支持多架构部署（例如在树莓派或 ARM 云服务器上运行 PostgreSQL）。
- **安全第一**：默认以非 root 用户 (UID 1000) 运行，具备显式的资源配额限制，并通过 Schema 强校验配置文件。
- **极致可靠性**：内置对 `--wait --atomic` 原子化升级的支持，并设有数据库迁移校验关卡。

## 🚀 快速开始

```bash
git clone https://github.com/webees/chatwoot.git
cd chatwoot

# 1. 构建依赖组件
helm dep build charts/chatwoot

# 2. 原子化部署（安全升级）
helm upgrade chatwoot ./charts/chatwoot \
  --install \
  --wait \
  --atomic \
  --namespace chatwoot \
  --create-namespace
```

## 📖 文档指南

- **[主配置文件 (Values)](./charts/chatwoot/values.yaml)** - 所有功能的中央控制台，已包含全中文化注释。
- **[维护与同步手册](./MAINTENANCE.md)** - 介绍如何保持此分支与上游官方版同步。
- **[基础设施测试](./charts/chatwoot/tests/)** - 内置单元测试，用于确保你的定制配置永不失效。

## 🛡 开源协议
基于 MIT 协议分发。详见 [LICENSE](./LICENSE)。
