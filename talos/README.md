# Talos OS Configuration

This directory contains the Talos OS configuration for your Kubernetes cluster. Talos is an immutable, minimal Linux distribution designed specifically for running Kubernetes.

## Overview

Talos provides a container-optimized operating system that:

- **Immutable**: The root filesystem is read-only, improving security and reliability
- **Minimal**: Only includes what's needed to run Kubernetes (tiny attack surface)
- **Declarative**: Configuration is defined as YAML, matching Kubernetes style
- **API-driven**: Managed entirely through `talosctl` CLI (no SSH, no package managers)

## Directory Structure

```
talos/
├── machineconfig.yaml.j2      # Base machine configuration (applies to all nodes)
├── nodes/                      # Node-specific overrides
│   ├── k8s-0.yaml.j2          # Control plane node 0
│   ├── k8s-1.yaml.j2          # Control plane node 1
│   └── k8s-2.yaml.j2          # Control plane node 2
├── schematic.yaml.j2           # Factory image customization (kernel args + extensions)
├── mod.just                    # Management tasks (render, apply, reboot, upgrade)
└── _out/                       # Generated configs (created after rendering)
    ├── machineconfig-k8s-0.yaml
    ├── machineconfig-k8s-1.yaml
    └── machineconfig-k8s-2.yaml
```

## Files Explained

### `machineconfig.yaml.j2`

**Base configuration for all nodes.** Contains:

- **Machine section**: OS-level settings (kernel parameters, filesystem, network)
- **Cluster section**: Kubernetes-specific config (control plane components, API server, etcd)
- Jinja2 templating: Uses `{% if ENV.IS_CONTROLLER %}` for control plane-only settings

**Key customizations you'll need:**

- `install.diskSelector.model`: Change to match your disk type (currently "Samsung SSD 870")
- `network.interfaces`: Configure your NICs (currently bonded Thunderbolt)
- `machine.nodeLabels`: Add custom labels for pod scheduling
- All `op://...` secrets: Update to match your 1Password vault paths

### `nodes/k8s-0.yaml.j2`, `k8s-1.yaml.j2`, `k8s-2.yaml.j2`

**Per-node overrides** for hostname and networking.

**Customizations:**

- `machine.hostname`: Update to match your node naming scheme
- `machine.network.interfaces`: Change Thunderbolt IPs to match your network
- `topology.kubernetes.io/zone`: Update zone labels for your environment

### `schematic.yaml.j2`

**Factory image customization.** Defines:

- **System extensions**: Drivers loaded into the image (GPU, NIC, etc.)
- **Kernel arguments**: Boot-time performance/security tuning

**Customizations:**

- Remove Intel GPU extension if using AMD CPU
- Remove Thunderbolt extension if not using Thunderbolt adapters
- Adjust kernel arguments for your hardware (CPU governor, IOMMU settings, etc.)

### `mod.just`

**Management commands** for applying and upgrading configurations.

Common tasks:

```bash
just render-config              # Generate final YAML from templates
just apply-node k8s-0          # Apply config to a node
just reboot-node k8s-0         # Gracefully reboot node
just upgrade-node k8s-0 1.12.0 # Upgrade Talos OS version
just health                     # Check cluster health
```

## Setup Workflow

### 1. **Customize Configurations**

Start with `machineconfig.yaml.j2` and update:

```yaml
# Your disk model (check with: lsblk -o NAME,MODEL)
install:
  diskSelector:
    model: YOUR_DISK_MODEL

# Your network interfaces (if not using Thunderbolt)
machine:
  network:
    interfaces:
      - interface: eth0  # Change from bond0
        dhcp: true

# Your 1Password vault paths
machine:
  ca:
    crt: op://YOUR_VAULT/talos/MACHINE_CA_CRT
```

Then update `talos/nodes/k8s-{0,1,2}.yaml.j2`:

```yaml
# Your hostname scheme
machine:
  hostname: node-0  # Change from k8s-0

# Your network IPs
machine:
  network:
    interfaces:
      - interface: eth0
        addresses:
          - address: 192.168.1.10/24
```

### 2. **Understand Your Hardware**

Check your system:

```bash
# List disks and models
lsblk -o NAME,MODEL

# List network interfaces
networkctl list

# Check CPU type
cat /proc/cpuinfo | grep "vendor_id"

# Check for GPU
lspci | grep -i gpu
```

Then update `schematic.yaml.j2` extensions:

- **Intel iGPU**: Keep `i915` extension
- **AMD CPU**: Replace `intel-ucode` with `amd-ucode`
- **NVIDIA GPU**: Replace `i915` with `nvidia-gpu` extension
- **No special hardware**: Remove unnecessary extensions

### 3. **Generate Factory Image**

Create your custom Talos image:

```bash
just gen-schematic-id
```

This outputs a schematic ID (e.g., `cc720ffb8efc8f...`). Update the `machineconfig.yaml.j2`:

```yaml
machine:
  install:
    image: factory.talos.dev/metal-installer/<SCHEMATIC_ID>:v1.11.5
```

### 4. **Render Configurations**

Generate final YAML from templates:

```bash
just render-config
```

Review the output: `talos/_out/machineconfig-k8s-{0,1,2}.yaml`

### 5. **Apply to Nodes**

For each node:

```bash
just apply-node k8s-0
just reboot-node k8s-0
# Wait for node to come back online
just health  # Verify cluster is healthy
```

## Common Customizations

### Change Network from Thunderbolt to Standard Ethernet

Replace in `machineconfig.yaml.j2`:

```yaml
interfaces:
  - interface: bond0
    bond:
      deviceSelectors:
        - driver: igc
          hardwareAddr: 88:ae:dd:72:*
    dhcp: true
```

With:

```yaml
interfaces:
  - interface: eth0
    dhcp: true
```

### Add More Storage

Add to `machine.userVolumeConfig`:

```yaml
- op: create
  path: /etc/cri/conf.d/custom.part
  content: |
    [plugins."io.containerd.cri.v1.images"]
      max_concurrent_downloads = 10
```

### Enable More Kernel Modules

Add to `machine.kernel.modules`:

```yaml
- name: nf_conntrack # For firewall tracking
- name: br_netfilter # For bridge networking
```

### Add GPU Support

**For Intel GPU:**
Already included in `schematic.yaml.j2`

**For NVIDIA GPU:**
Replace in `schematic.yaml.j2`:

```yaml
extensions:
  - image: ghcr.io/siderolabs/nvidia-container-toolkit:550.54.14
  - image: ghcr.io/siderolabs/nvidia-gpu:550.54.14
```

Then enable in `machineconfig.yaml.j2`:

```yaml
extraArgs:
  feature-gates: GPUAccess=true
```

## 1Password Integration

Talos uses 1Password for secret management. The `op://` URIs reference secrets like:

- `op://kubernetes/talos/MACHINE_CA_CRT` - Machine CA certificate
- `op://kubernetes/talos/CLUSTER_ID` - Cluster identifier
- `op://kubernetes/talos/MACHINE_TOKEN` - Authentication token

**Setup:**

1. Install 1Password CLI: `brew install 1password-cli`
2. Sign in: `op account add`
3. Create a vault called "kubernetes" in 1Password
4. Add items for each secret (crt/key files, tokens, etc.)
5. Update the `op://` paths to match your vault structure

**Verification:**

```bash
# Test that op can fetch secrets
op read op://kubernetes/talos/MACHINE_CA_CRT
```

## Troubleshooting

### Configuration won't apply

```bash
# Check if config is valid
talosctl config validate

# View current node config
talosctl read /etc/talos/config.yaml
```

### Node won't boot

```bash
# View boot logs via IPMI/console
# Check kernel arguments in dmesg
talosctl dmesg --nodes <node>
```

### Network not working

```bash
# Check interface status
talosctl interfaces

# View network configuration
talosctl read /etc/net/00-dhcp.yaml
```

### Upgrade failed

```bash
# Check upgrade logs
talosctl logs <node> --service kubelet
talosctl logs <node> --service talos

# Reset to previous version (requires IPMI)
talosctl reset --nodes <node>
```

## References

- **Talos Documentation**: https://www.talos.dev/latest/introduction/
- **Factory Customization**: https://factory.talos.dev
- **1Password Integration**: https://www.talos.dev/latest/reference/configuration/#machinev1alpha1ca
- **Kernel Parameters**: https://www.talos.dev/latest/reference/configuration/#machinev1alpha1kernelmodules

## Next Steps

1. ✅ Review this README
2. 🔨 Customize `machineconfig.yaml.j2` for your hardware
3. 🔨 Customize `talos/nodes/k8s-*.yaml.j2` for your network
4. 🔨 Update `schematic.yaml.j2` for your extensions
5. ⚙️ Run `just render-config`
6. 🏗️ Review generated configs: `cat talos/_out/machineconfig-k8s-0.yaml`
7. 📤 Run `just apply-node k8s-0` for each node
8. ✨ Verify with `just health`
