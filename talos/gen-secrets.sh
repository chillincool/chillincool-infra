#!/usr/bin/env bash
set -euo pipefail

# Generate Talos secrets and store them in 1Password
# Usage: ./gen-secrets.sh [vault] [item]

VAULT="${1:-talos}"
ITEM="${2:-talos}"
OUTPUT_SECRETS_FILE="secrets.yaml"


secrets_file=$(mktemp)
trap "rm -f $secrets_file" EXIT

echo "Generating Talos secrets..."
talosctl gen secrets -o "$secrets_file" --force

echo "Writing secrets to ${OUTPUT_SECRETS_FILE}..."
cp "$secrets_file" "$OUTPUT_SECRETS_FILE"

echo "Creating 1Password item '$ITEM' in vault '$VAULT'..."
op item create --vault "$VAULT" --category "Secure Note" --title "$ITEM" \
    "MACHINE_CA_CRT[password]=$(yq '.certs.os.crt' "$secrets_file")" \
    "MACHINE_CA_KEY[password]=$(yq '.certs.os.key' "$secrets_file")" \
    "MACHINE_TOKEN[password]=$(yq '.trustdinfo.token' "$secrets_file")" \
    "CLUSTER_CA_CRT[password]=$(yq '.certs.k8s.crt' "$secrets_file")" \
    "CLUSTER_CA_KEY[password]=$(yq '.certs.k8s.key' "$secrets_file")" \
    "CLUSTER_ETCD_CA_CRT[password]=$(yq '.certs.etcd.crt' "$secrets_file")" \
    "CLUSTER_ETCD_CA_KEY[password]=$(yq '.certs.etcd.key' "$secrets_file")" \
    "CLUSTER_AGGREGATORCA_CRT[password]=$(yq '.certs.k8saggregator.crt' "$secrets_file")" \
    "CLUSTER_AGGREGATORCA_KEY[password]=$(yq '.certs.k8saggregator.key' "$secrets_file")" \
    "CLUSTER_SERVICEACCOUNT_KEY[password]=$(yq '.certs.k8sserviceaccount.key' "$secrets_file")" \
    "CLUSTER_TOKEN[password]=$(yq '.secrets.bootstraptoken' "$secrets_file")" \
    "CLUSTER_ID[password]=$(yq '.cluster.id' "$secrets_file")" \
    "CLUSTER_SECRET[password]=$(yq '.cluster.secret' "$secrets_file")" \
    "CLUSTER_SECRETBOXENCRYPTIONSECRET[password]=$(yq '.secrets.secretboxencryptionsecret' "$secrets_file")"

echo ""
echo "Done! Secrets stored in op://$VAULT/$ITEM/"
echo ""
echo "Your machineconfig.yaml.j2 should reference these as:"
echo "  op://$VAULT/$ITEM/MACHINE_CA_CRT"
echo "  op://$VAULT/$ITEM/MACHINE_CA_KEY"
echo "  etc."
