#!/usr/bin/env bash
set -euo pipefail

# Generate talosconfig from 1Password secrets
# Usage: ./gen-talosconfig.sh <endpoint1> [endpoint2] ...

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <endpoint1> [endpoint2] ..."
    echo "Example: $0 172.16.60.7 172.16.60.8"
    exit 1
fi

VAULT="${VAULT:-talos}"
ITEM="${ITEM:-talos}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${OUTPUT:-$SCRIPT_DIR/talosconfig}"

# Build endpoints array
ENDPOINTS=()
NODES=()
for ep in "$@"; do
    ENDPOINTS+=("$ep")
    NODES+=("$ep")
done

echo "Fetching secrets from 1Password..."
CA_CRT=$(op read "op://$VAULT/$ITEM/MACHINE_CA_CRT")
CA_KEY=$(op read "op://$VAULT/$ITEM/MACHINE_CA_KEY")

# Create temp dir
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

# Decode certs and fix key header for OpenSSL compatibility
# Talos uses "ED25519 PRIVATE KEY" header but OpenSSL expects "PRIVATE KEY"
echo "$CA_CRT" | base64 -d > "$tmpdir/ca.crt"
echo "$CA_KEY" | base64 -d | sed 's/ED25519 PRIVATE KEY/PRIVATE KEY/g' > "$tmpdir/ca.key"

echo "Generating client certificate..."

# Generate Ed25519 client key
openssl genpkey -algorithm ED25519 -out "$tmpdir/client.key"

# Generate client CSR
openssl req -new -key "$tmpdir/client.key" -out "$tmpdir/client.csr" -subj "/O=os:admin"

# Sign client cert with CA
openssl x509 -req -in "$tmpdir/client.csr" -CA "$tmpdir/ca.crt" -CAkey "$tmpdir/ca.key" \
    -CAcreateserial -out "$tmpdir/client.crt" -days 365

# Base64 encode for talosconfig
CA_CRT_B64=$(base64 < "$tmpdir/ca.crt" | tr -d '\n')
CLIENT_CRT_B64=$(base64 < "$tmpdir/client.crt" | tr -d '\n')
CLIENT_KEY_B64=$(base64 < "$tmpdir/client.key" | tr -d '\n')

echo "Writing talosconfig to $OUTPUT..."

# Build YAML properly
{
    echo "context: main"
    echo "contexts:"
    echo "    main:"
    echo "        endpoints:"
    for ep in "${ENDPOINTS[@]}"; do
        echo "            - $ep"
    done
    echo "        nodes:"
    for node in "${NODES[@]}"; do
            echo "            - $node"
    done
    echo "        ca: $CA_CRT_B64"
    echo "        crt: $CLIENT_CRT_B64"
    echo "        key: $CLIENT_KEY_B64"
} > "$OUTPUT"

echo "Done! talosconfig written to $OUTPUT"
echo ""
echo "Test with: talosctl version --nodes ${ENDPOINTS[0]}"
