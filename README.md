# 🧶 Chatwoot: Artistic Hardened Edition
> **Minimalist. Secure. High Performance.**

This repository is a premium, professional-grade fork of the official Chatwoot Helm charts, meticulously refactored for organizations that demand **zero-downtime upgrades**, **extreme minimalism**, and **architectural elegance**.

## ✨ Key Enhancements

- **Artistic Refactoring**: Clean, semantic naming convention (`deployment.web.yaml`, `job.migrate.yaml`) and unified helper namespaces (`db`, `cache`, `pod.common`).
- **Production Hardened**: Pre-configured with Pod Disruption Budgets (PDB), Horizontal Pod Autoscaling (HPA), and strict `RollingUpdate` strategies.
- **ARM64 Ready**: Multi-arch support out of the box (e.g., PostgreSQL on ARM).
- **Security First**: Runs as non-root (UID 1000) by default with explicit resource limits and Schema-validated values.
- **Atomic Reliability**: Built-in support for `--wait --atomic` upgrades and automatic database migration barriers.

## 🚀 Quick Start

```bash
git clone https://github.com/webees/chatwoot.git
cd chatwoot

# 1. Build dependencies
helm dep build charts/chatwoot

# 2. Deploy with atomic safety
helm upgrade chatwoot ./charts/chatwoot \
  --install \
  --wait \
  --atomic \
  --namespace chatwoot \
  --create-namespace
```

## 📖 Documentation

- **[Main Values Configuration](./charts/chatwoot/values.yaml)** - Central control for all features.
- **[Maintenance & Sync Guide](./MAINTENANCE.md)** - How to keep this fork updated with upstream.
- **[Infrastructure Tests](./charts/chatwoot/tests/)** - Built-in unit tests to verify your customizations.

## 🛡 License
Distributed under the MIT License. See [LICENSE](./LICENSE) for more information.
