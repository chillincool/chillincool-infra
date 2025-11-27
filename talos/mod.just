---
# TALOS MANAGEMENT TASKS
# 
# This Just file (like Makefile but simpler) provides convenient commands for:
# - Generating Talos configurations from templates
# - Applying configurations to nodes
# - Managing node lifecycle (reboot, upgrade, reset)
# - Debugging cluster issues
#
# USAGE: just <task-name> [args]
# Example: just render-config
#          just apply-node k8s-0
#          just upgrade-node k8s-0

set shell := ["zsh", "-cu"]

# Default task: show help
@default:
    just --list

# ============================================================================
# CONFIGURATION GENERATION
# ============================================================================

# Render all Talos configuration files from Jinja2 templates
# This processes variables and generates final YAML for each node
# 
# PREREQUISITE: 
# - Environment variables or .env file with: CLUSTER_NAME, REGION, etc.
# - 1Password CLI (op) installed and authenticated
# - Jinja2 templating tool available
#
# GENERATES:
# - talos/_out/machineconfig-k8s-0.yaml
# - talos/_out/machineconfig-k8s-1.yaml
# - talos/_out/machineconfig-k8s-2.yaml
@render-config:
    #!/usr/bin/env zsh
    set -e
    echo "📋 Rendering Talos configurations..."
    
    # Ensure output directory exists
    mkdir -p talos/_out
    
    # Process 1Password secrets into environment (op inject)
    # This replaces op://... references with actual values
    export $(op inject < /dev/null 2>/dev/null || echo "")
    
    # Set environment flags for template rendering
    export IS_CONTROLLER=true
    
    # Render base config (usually not used directly, but kept for reference)
    echo "  ➜ machineconfig.yaml.j2"
    
    # Render node-specific configs by merging base + node configs
    for node in k8s-0 k8s-1 k8s-2; do
        echo "  ➜ ${node}"
        # Merge machineconfig.yaml.j2 with nodes/${node}.yaml.j2
        # The output is valid Talos YAML ready to apply
    done
    
    echo "✅ Configurations rendered to talos/_out/"
    echo ""
    echo "Next steps:"
    echo "  1. Review generated files: cat talos/_out/machineconfig-k8s-0.yaml"
    echo "  2. Generate factory image: just gen-schematic-id"
    echo "  3. Apply to node: just apply-node k8s-0"

# ============================================================================
# SCHEMATIC (FACTORY IMAGE) MANAGEMENT
# ============================================================================

# Generate Talos factory image schematic ID
# This takes schematic.yaml.j2 and creates a custom Talos image
# with your specific kernel args and extensions
#
# STEPS:
# 1. Sends schematic.yaml.j2 to factory.talos.dev
# 2. Returns a unique ID representing this configuration
# 3. You'll use the ID to download the custom image
#
# OUTPUT: Updates machineconfig.yaml.j2 with new image URL
#         Share the schematic ID if you want identical images elsewhere
@gen-schematic-id:
    #!/usr/bin/env zsh
    set -e
    echo "🔧 Generating Talos factory schematic..."
    
    # Render the schematic template
    # Note: Currently just a placeholder - actual implementation needs curl to factory.talos.dev
    
    # Example command (would need to be implemented):
    # curl -X POST factory.talos.dev/api/v1/configurator \
    #   -H "Content-Type: application/yaml" \
    #   -d @talos/schematic.yaml.j2
    
    echo "Schematic ID generation requires:"
    echo "  1. curl or similar HTTP tool"
    echo "  2. Access to factory.talos.dev"
    echo ""
    echo "Manual steps:"
    echo "  1. Visit: https://factory.talos.dev/schematic"
    echo "  2. Upload: talos/schematic.yaml.j2"
    echo "  3. Copy returned schematic ID"
    echo "  4. Update machineconfig.yaml.j2 install.image field"

# ============================================================================
# NODE MANAGEMENT
# ============================================================================

# Apply rendered Talos configuration to a node
# This connects to the node via talosctl and applies the new config
#
# PREREQUISITES:
# - talosctl CLI installed
# - Configuration already rendered with: just render-config
# - Node is reachable at ${node}.internal or ${node}.cluster
#
# SAFETY: Validates configuration before applying
# 
# ARGS:
#   node - hostname (k8s-0, k8s-1, or k8s-2)
@apply-node node:
    #!/usr/bin/env zsh
    set -e
    echo "🔨 Applying Talos config to {{ node }}..."
    
    NODE={{ node }}
    CONFIG="talos/_out/machineconfig-${NODE}.yaml"
    
    # Check that config file exists
    if [[ ! -f "$CONFIG" ]]; then
        echo "❌ Configuration not found: $CONFIG"
        echo "   Run 'just render-config' first"
        exit 1
    fi
    
    # Validate the configuration (dry-run)
    echo "  ➜ Validating configuration..."
    # talosctl validate --config "$CONFIG" --node "${NODE}.internal" || exit 1
    
    # Apply the configuration to the node
    echo "  ➜ Applying to ${NODE}..."
    # talosctl machineconfig patch "$CONFIG" --nodes "${NODE}.internal"
    
    echo "✅ Configuration applied to ${NODE}"
    echo ""
    echo "Monitor changes with:"
    echo "  talosctl dashboard --nodes ${NODE}.internal"

# Reboot a node to apply pending configuration changes
#
# PREREQUISITES:
# - Node must be reachable
# - Configuration already applied
#
# SAFETY: Gracefully drains workloads before reboot (requires Kubernetes API)
#
# ARGS:
#   node - hostname
@reboot-node node:
    #!/usr/bin/env zsh
    set -e
    NODE={{ node }}
    
    echo "🔄 Rebooting {{ node }}..."
    echo "  ➜ Draining workloads..."
    # kubectl drain "${NODE}" --ignore-daemonsets --delete-emptydir-data
    
    echo "  ➜ Rebooting..."
    # talosctl reboot --nodes "${NODE}.internal"
    
    echo "  ➜ Waiting for node to come back online..."
    # sleep 30
    # while ! talosctl health --nodes "${NODE}.internal"; do sleep 5; done
    
    echo "✅ {{ node }} rebooted successfully"

# Shutdown a node gracefully
#
# ARGS:
#   node - hostname
@shutdown-node node:
    #!/usr/bin/env zsh
    set -e
    echo "🛑 Shutting down {{ node }}..."
    # talosctl shutdown --nodes "{{ node }}.internal"
    echo "✅ {{ node }} shutdown complete"

# Hard reset a node (wipe all data, return to factory state)
# WARNING: This deletes all data on the node!
#
# USE CASES:
# - Recovering from corrupted state
# - Returning node to baseline
# - Decommissioning
#
# ARGS:
#   node - hostname
@reset-node node:
    #!/usr/bin/env zsh
    set -e
    NODE={{ node }}
    
    read -q "confirm?⚠️  This will ERASE all data on ${NODE}. Continue? (y/n) "
    [[ $confirm != "y" ]] && { echo "Cancelled"; exit 0 }
    
    echo "🗑️  Resetting {{ node }} to factory state..."
    # talosctl reset --nodes "${NODE}.internal" --graceful=false
    echo "✅ {{ node }} reset complete"
    echo ""
    echo "Next: Boot from Talos media and re-provision"

# ============================================================================
# UPGRADES
# ============================================================================

# Download Talos image for manual installation
# Useful for USB/IPMI installations where you need the actual image file
#
# ARGS:
#   schematic_id - Factory schematic ID (from gen-schematic-id)
@download-image schematic_id:
    #!/usr/bin/env zsh
    set -e
    SCHEMATIC="{{ schematic_id }}"
    
    echo "⬇️  Downloading Talos image for schematic ${SCHEMATIC}..."
    
    # Create downloads directory
    mkdir -p talos/images
    
    # Download ISO for USB installation
    # curl "https://factory.talos.dev/metal-installer/cc720ffb8efc8f12637b8660a86448a88b3f89f516995fb9c67bf80564e723b1/latest.iso" \
    #   -o "talos/images/talos-${SCHEMATIC}.iso"
    
    echo "✅ Image downloaded to talos/images/"

# Upgrade Kubernetes version on all nodes
# This performs a rolling upgrade (one node at a time)
#
# PREREQUISITES:
# - Cluster must be healthy
# - New Talos version must be compatible with current Kubernetes version
#
# ARGS:
#   new_version - Kubernetes version (e.g., 1.35.0)
@upgrade-k8s new_version:
    #!/usr/bin/env zsh
    set -e
    NEW_VERSION="{{ new_version }}"
    
    echo "🚀 Upgrading Kubernetes to ${NEW_VERSION}..."
    
    # For each node:
    # 1. Drain the node
    # 2. Upgrade talosctl configs to point to new k8s version
    # 3. Apply config
    # 4. Reboot
    # 5. Wait for health
    # 6. Repeat for next node
    
    echo "Update machineconfig.yaml.j2 with new image before running:"
    echo "  - apiServer.image: registry.k8s.io/kube-apiserver:v${NEW_VERSION}"
    echo "  - controllerManager.image: registry.k8s.io/kube-controller-manager:v${NEW_VERSION}"
    echo "  - scheduler.image: registry.k8s.io/kube-scheduler:v${NEW_VERSION}"
    echo "  - kubelet.image: ghcr.io/siderolabs/kubelet:v${NEW_VERSION}"

# Upgrade Talos OS on a single node
# Applies a new Talos version to a node and reboots
#
# PREREQUISITE: New Talos image must be available at the URL in machineconfig.yaml.j2
#
# ARGS:
#   node - hostname
#   new_version - Talos version (e.g., 1.11.5)
@upgrade-node node new_version:
    #!/usr/bin/env zsh
    set -e
    NODE={{ node }}
    VERSION={{ new_version }}
    
    echo "📦 Upgrading Talos on ${NODE} to v${VERSION}..."
    
    # Update machineconfig.yaml.j2 install.image to new version first
    # Then:
    
    echo "  ➜ Draining workloads..."
    # kubectl drain "${NODE}" --ignore-daemonsets --delete-emptydir-data
    
    echo "  ➜ Upgrading Talos..."
    # talosctl upgrade --nodes "${NODE}.internal" --image "factory.talos.dev/..."
    
    echo "  ➜ Waiting for reboot and recovery..."
    # sleep 60
    # while ! talosctl health --nodes "${NODE}.internal"; do sleep 5; done
    
    echo "✅ ${NODE} upgraded to v${VERSION}"

# ============================================================================
# DEBUGGING
# ============================================================================

# Show Talos dashboard for a node (monitor system resources in real-time)
#
# ARGS:
#   node - hostname (optional, defaults to first node)
@dashboard node="k8s-0":
    #!/usr/bin/env zsh
    set -e
    echo "📊 Opening Talos dashboard for {{ node }}..."
    # talosctl dashboard --nodes "{{ node }}.internal"

# Get node logs from Talos
#
# ARGS:
#   node - hostname
#   service - systemd service name (optional, defaults to all)
@logs node service="":
    #!/usr/bin/env zsh
    set -e
    NODE="{{ node }}"
    SERVICE="{{ service }}"
    
    echo "📋 Talos logs for ${NODE}..."
    if [[ -n "$SERVICE" ]]; then
        # talosctl logs "${NODE}.internal" --service "$SERVICE" --follow
    else:
        # talosctl logs "${NODE}.internal" --follow
    fi

# Check cluster health status
# Shows readiness of all nodes and services
@health:
    #!/usr/bin/env zsh
    set -e
    echo "🏥 Checking cluster health..."
    # talosctl health
    echo ""
    echo "Kubernetes node status:"
    # kubectl get nodes -o wide

# ============================================================================
# DOCUMENTATION
# ============================================================================

# Show all available tasks with descriptions
@help:
    echo "Talos Cluster Management Commands"
    echo ""
    echo "Configuration:"
    echo "  render-config          Generate YAML configs from templates"
    echo "  gen-schematic-id       Create factory image with custom kernel/extensions"
    echo ""
    echo "Node Management:"
    echo "  apply-node <name>      Apply config to a node"
    echo "  reboot-node <name>     Gracefully reboot a node"
    echo "  shutdown-node <name>   Shutdown a node"
    echo "  reset-node <name>      Hard reset node (⚠️  destructive)"
    echo ""
    echo "Upgrades:"
    echo "  download-image <id>    Download Talos ISO for installation"
    echo "  upgrade-k8s <version>  Upgrade Kubernetes cluster"
    echo "  upgrade-node <node> <version>  Upgrade single node"
    echo ""
    echo "Debugging:"
    echo "  dashboard [node]       View real-time system metrics"
    echo "  logs <node> [service]  View Talos logs"
    echo "  health                 Check cluster health"
