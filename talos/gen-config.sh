#!/usr/bin/env bash
set -euo pipefail

# Generate Talos config and store secrets in 1Password
# Usage: ./gen-config.sh [cluster-name] [endpoint]
#
# This script:
# 1. Generates full Talos config with talosctl gen config
# 2. Extracts secrets and stores them in 1Password
# 3. Copies talosconfig to repo root

CLUSTER="${1:-main}"
ENDPOINT="${2:-https://k8s.internal:6443}"
VAULT="${VAULT:-talos}"
ITEM="${ITEM:-talos}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

echo "Generating Talos config for cluster '$CLUSTER' with endpoint '$ENDPOINT'..."
talosctl gen config "$CLUSTER" "$ENDPOINT" --output "$tmpdir" --force

echo ""
echo "Extracting secrets from controlplane.yaml..."

# Extract secrets from the generated controlplane.yaml
MACHINE_CA_CRT=$(yq '.machine.ca.crt' "$tmpdir/controlplane.yaml")
MACHINE_CA_KEY=$(yq '.machine.ca.key' "$tmpdir/controlplane.yaml")
MACHINE_TOKEN=$(yq '.machine.token' "$tmpdir/controlplane.yaml")

CLUSTER_CA_CRT=$(yq '.cluster.ca.crt' "$tmpdir/controlplane.yaml")
CLUSTER_CA_KEY=$(yq '.cluster.ca.key' "$tmpdir/controlplane.yaml")
CLUSTER_ETCD_CA_CRT=$(yq '.cluster.etcd.ca.crt' "$tmpdir/controlplane.yaml")
CLUSTER_ETCD_CA_KEY=$(yq '.cluster.etcd.ca.key' "$tmpdir/controlplane.yaml")
CLUSTER_AGGREGATORCA_CRT=$(yq '.cluster.aggregatorCA.crt' "$tmpdir/controlplane.yaml")
CLUSTER_AGGREGATORCA_KEY=$(yq '.cluster.aggregatorCA.key' "$tmpdir/controlplane.yaml")
CLUSTER_SERVICEACCOUNT_KEY=$(yq '.cluster.serviceAccount.key' "$tmpdir/controlplane.yaml")
CLUSTER_TOKEN=$(yq '.cluster.token' "$tmpdir/controlplane.yaml")
CLUSTER_ID=$(yq '.cluster.id' "$tmpdir/controlplane.yaml")
CLUSTER_SECRET=$(yq '.cluster.secret' "$tmpdir/controlplane.yaml")
CLUSTER_SECRETBOXENCRYPTIONSECRET=$(yq '.cluster.secretboxEncryptionSecret' "$tmpdir/controlplane.yaml")

# Extract admin credentials from talosconfig
TALOS_CRT=$(yq ".contexts.$CLUSTER.crt" "$tmpdir/talosconfig")
TALOS_KEY=$(yq ".contexts.$CLUSTER.key" "$tmpdir/talosconfig")

echo "Storing secrets in 1Password vault '$VAULT' item '$ITEM'..."

# Delete existing item if it exists
op item delete --vault "$VAULT" "$ITEM" 2>/dev/null || true

# Create new item with all secrets
op item create --vault "$VAULT" --category "Secure Note" --title "$ITEM" \
    "MACHINE_CA_CRT[password]=$MACHINE_CA_CRT" \
    "MACHINE_CA_KEY[password]=$MACHINE_CA_KEY" \
    "MACHINE_TOKEN[password]=$MACHINE_TOKEN" \
    "CLUSTER_CA_CRT[password]=$CLUSTER_CA_CRT" \
    "CLUSTER_CA_KEY[password]=$CLUSTER_CA_KEY" \
    "CLUSTER_ETCD_CA_CRT[password]=$CLUSTER_ETCD_CA_CRT" \
    "CLUSTER_ETCD_CA_KEY[password]=$CLUSTER_ETCD_CA_KEY" \
    "CLUSTER_AGGREGATORCA_CRT[password]=$CLUSTER_AGGREGATORCA_CRT" \
    "CLUSTER_AGGREGATORCA_KEY[password]=$CLUSTER_AGGREGATORCA_KEY" \
    "CLUSTER_SERVICEACCOUNT_KEY[password]=$CLUSTER_SERVICEACCOUNT_KEY" \
    "CLUSTER_TOKEN[password]=$CLUSTER_TOKEN" \
    "CLUSTER_ID[password]=$CLUSTER_ID" \
    "CLUSTER_SECRET[password]=$CLUSTER_SECRET" \
    "CLUSTER_SECRETBOXENCRYPTIONSECRET[password]=$CLUSTER_SECRETBOXENCRYPTIONSECRET" \
    "TALOS_CRT[password]=$TALOS_CRT" \
    "TALOS_KEY[password]=$TALOS_KEY"

echo ""
echo "Copying talosconfig to $REPO_ROOT/talosconfig..."
cp "$tmpdir/talosconfig" "$REPO_ROOT/talosconfig"

echo ""
echo "Done!"
echo ""
echo "Secrets stored in: op://$VAULT/$ITEM/"
echo "Talosconfig at: $REPO_ROOT/talosconfig"
echo ""
echo "Next steps:"
echo "1. Update talosconfig endpoints/nodes to match your IPs"
echo "2. Boot nodes from Talos ISO"
echo "3. Run: just bootstrap"
