# Maintenance Guide: Chatwoot Helm Chart Customizations

This repository is a customized fork of the official [chatwoot/charts](https://github.com/chatwoot/charts). It maintains specific enhancements for High Availability (HA), ARM64 architecture support, and performance optimizations.

## 🔄 Upstream Synchronization Strategy

To sync with upstream while preserving local customizations, follow these steps:

### 1. Configure Remotes (One-time)
```bash
git remote add upstream https://github.com/chatwoot/charts.git
```

### 2. Fetch and Merge
Do **NOT** use a simple `git merge upstream/main`. Instead, follow a rebase-like approach or a manual merge to ensure local HA templates and specific `values.yaml` logic are not overwritten.

```bash
git fetch upstream
# Comparison check
git diff main upstream/main
```

### 3. Key Files to Protect
When resolving conflicts, ensure the following local logic is preserved:
- `values.yaml`: All sections marked with "local customization" in this doc.
- `templates/pdb.yaml`: This file is unique to our fork.
- `templates/*.yaml`: The `affinity` and `topologySpreadConstraints` blocks injected into deployments.

---

## 🛠 Local Customizations Log

### 1. High Availability (HA) & Scheduling
*   **Target Nodes**: All Pods are constrained to nodes with the label `worker`.
*   **Topology**: `topologySpreadConstraints` is enabled in `web-deployment.yaml` and `worker-deployment.yaml` to prevent Pod concentration on single nodes.
*   **PDB**: `templates/pdb.yaml` provides Pod Disruption Budgets for Web and Worker.
*   **Affinity**: Custom `nodeAffinity` is defined in `values.yaml` and injected into all deployment/job templates.

### 2. Redis Performance (Memory-Only Mode)
Designed for ephemeral cache/queue usage without persistent disk overhead.
*   **Architecture**: Switched to `architecture: standalone` to completely remove replica logic and Pods.
*   **Persistence**: Disabled (`persistence.enabled: false`).
*   **Storage**: Uses `emptyDir` with `medium: Memory` (tmpfs).
*   **Config Location**: `values.yaml` -> `redis` section.

### 3. ARM64 Architecture Support
Official Chatwoot images for PostgreSQL dropped ARM support in 2025.
*   **Image**: Switched from `ghcr.io/chatwoot/pgvector` back to `docker.io/pgvector/pgvector:pg16`.
*   **Status**: Multi-arch (amd64 + arm64).
*   **Config Location**: `values.yaml` -> `postgresql.image`.

### 4. Simplified Resource Naming
*   **Override**: `fullnameOverride: "chatwoot"`.
*   **Benefit**: Cleans up resource names (e.g., `chatwoot-web` instead of `chatwoot-2-1766892187-web`).
*   **Caution**: Changing this on an existing deployment causes a brief service interruption as resources are recreated under the new name.

### 5. PostgreSQL Extra Environment Fix
*   **Removed**: Redundant `extraEnv` blocks in `postgresql.primary` that referenced hardcoded Secret names. The Bitnami subchart handles password injection natively.

### 6. CI/CD Operations
*   **Release Workflow**: Added `permissions: contents: write` to `.github/workflows/release.yaml`.
*   **Trigger**: Configured to auto-release on push to `main` to support Rancher Helm Repository synchronization.

### 7. Internal Consistency & Bug Fixes (v2.1.12)
*   **Redis Auth**: Fixed `redis.auth.existingSecret` path in web/worker deployments to match Bitnami standards.
*   **PDB Selectors**: Added `release` label to PDB selectors for precise pod matching.
*   **Ingress Dynamic Naming**: Ingress backend service name now dynamically uses `chatwoot.fullname`, preventing broken links if `fullnameOverride` is changed.
*   **Job Naming**: Migration job renamed from `${Release.Name}-migrate` to `${Fullname}-migrate` for consistency.

### 8. Security Hardening & Resource Management (v2.1.13)
*   **Non-Root Execution**: Pods now run as non-root (UID 1000) by default for enhanced security.
*   **Infrastructure Throttling**: Explicit CPU/Memory limits added for PostgreSQL and Redis to prevent noisy neighbor issues in HA environments.
*   **PG Storage Fix**: Switched accessModes to `ReadWriteOnce` for standard storage class compatibility.
*   **Cleanup**: Removed unused `readReplicas` for PostgreSQL to maintain minimalism.

---

## 🛡 Upgrade Safety & Atomic Rollback

This chart is optimized for "Atomic" upgrades. If use the correct parameters, Kubernetes will automatically roll back to the previous version if the upgrade fails.

### 1. How the safety net works:
- **Zero-Downtime Strategy**: `web` and `worker` use `maxUnavailable: 0`. Kubernetes will keep old pods running until the new ones pass `readinessProbe` and `startupProbe`.
- **Migration Barrier**: The `migrate` job runs as a `post-upgrade` hook. If migrations fail, the upgrade is marked as failed.
- **Fail-Safe Probes**: We have aggressive `startupProbe` and `readinessProbe` to catch failing app versions early.

### 2. Required Helm Command (CLI):
```bash
helm upgrade chatwoot ./charts/chatwoot \
  --install \
  --wait \
  --atomic \
  --timeout 10m
```

### 3. Rancher UI Configuration:
When upgrading via Rancher:
1. Go to **Upgrade** screen.
2. Under **Helm Options**, ensure **"Wait"** is checked.
3. Ensure **"Atomic"** (or **"Rollback on failure"**) is checked.
4. Set **Timeout** to at least `600` seconds (migrations can take time).

---

## ✅ Post-Upgrade Verification
After syncing with upstream, always verify:
1. `kubectl get pods -o wide`: Ensure Pods are running on `worker` labeled nodes.
2. `kubectl describe pod <redis-pod>`: Verify Volume `redis-data` is an `emptyDir` with `medium: Memory`.
3. `kubectl get pdb`: Ensure `chatwoot-web` and `chatwoot-worker` PDBs exist.
4. `helm get values <release>`: Check that `image.tag` matches the desired Chatwoot version.
