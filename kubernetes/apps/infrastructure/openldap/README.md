# OpenLDAP Setup

OpenLDAP deployment with phpLDAPadmin for user/group management.

## Architecture

- **OpenLDAP**: LDAP server with base schema (`dc=chillincool,dc=net`)
  - **LDAPS**: Enabled with step-ca certificates (port 636)
  - **LDAP**: Available on port 389 (non-TLS)
- **phpLDAPadmin**: Web UI for administration at `https://ldap.chillincool.net`
- **Terraform**: Declarative user/group management (recommended)

## Base Schema (GitOps-managed)

The following organizational units are created automatically:

```
dc=chillincool,dc=net
├── ou=users        # User accounts
├── ou=groups       # Groups for authorization
└── ou=services     # Service accounts (Keycloak, readonly, etc.)
```

## User Management with Terraform

### Setup

1. Install Terraform LDAP provider:

```hcl
terraform {
  required_providers {
    ldap = {
      source  = "l-with/ldap"
      version = "~> 0.10"
    }
  }
}

provider "ldap" {
  ldap_host = "openldap.openldap.svc.cluster.local"
  ldap_port = 636  # LDAPS port
  use_tls   = true
  # Trust step-ca certificates
  # In production, provide the CA cert or use start_tls
  tls_insecure_skip_verify = false  # Set to true for internal step-ca certs
  bind_user     = "cn=admin,dc=chillincool,dc=net"
  bind_password = var.ldap_admin_password  # From 1Password
}
```

2. Get admin password:

```bash
kubectl get secret openldap -n openldap -o jsonpath='{.data.admin-password}' | base64 -d
```

### Example: Create Users

```hcl
resource "ldap_object" "user_chris" {
  dn = "uid=chris,ou=users,dc=chillincool,dc=net"

  object_classes = [
    "inetOrgPerson",
    "posixAccount",
    "top"
  ]

  attributes = [
    { uid = ["chris"] },
    { cn = ["Chris"] },
    { sn = ["Smith"] },
    { mail = ["chris@chillincool.net"] },
    { userPassword = ["{SSHA}hashedpassword"] },  # Use slappasswd to generate
    { uidNumber = ["10000"] },
    { gidNumber = ["10000"] },
    { homeDirectory = ["/home/chris"] },
    { loginShell = ["/bin/bash"] },
  ]
}
```

### Example: Create Groups

```hcl
resource "ldap_object" "group_admins" {
  dn = "cn=admins,ou=groups,dc=chillincool,dc=net"

  object_classes = [
    "groupOfNames",
    "top"
  ]

  attributes = [
    { cn = ["admins"] },
    { description = ["Administrators"] },
    { member = [
      "uid=chris,ou=users,dc=chillincool,dc=net",
      "cn=admin,dc=chillincool,dc=net"
    ]},
  ]
}
```

### Example: Service Accounts

```hcl
resource "ldap_object" "keycloak_service" {
  dn = "cn=keycloak,ou=services,dc=chillincool,dc=net"

  object_classes = [
    "simpleSecurityObject",
    "organizationalRole",
    "top"
  ]

  attributes = [
    { cn = ["keycloak"] },
    { description = ["Keycloak LDAP bind account"] },
    { userPassword = [var.keycloak_bind_password] },
  ]
}
```

## phpLDAPadmin (Web UI)

Access phpLDAPadmin at `https://ldap.chillincool.net`

**Login credentials:**
- Username: `cn=admin,dc=chillincool,dc=net`
- Password: Get from: `kubectl get secret openldap-admin -n openldap -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d`

### phpLDAPadmin Usage

1. **View Users/Groups**: Navigate via the tree on the left
2. **Create Users**: Click "Create new entry" → Choose template (e.g., inetOrgPerson)
3. **Modify Entries**: Click on any DN to view/edit attributes
4. **Search**: Use the search feature to find specific entries

**Note:** phpLDAPadmin connects to OpenLDAP via LDAPS (port 636) with TLS enabled.

**Best Practice:** Use Terraform for permanent changes, phpLDAPadmin for troubleshooting and one-off operations.

## Keycloak Integration

Configure Keycloak user federation:

1. **Connection URL**: `ldaps://openldap.openldap.svc.cluster.local:636`
2. **Users DN**: `ou=users,dc=chillincool,dc=net`
3. **Bind DN**: `cn=keycloak,ou=services,dc=chillincool,dc=net`
4. **Bind Credential**: (Terraform-managed service account password)
5. **User Object Classes**: `inetOrgPerson, posixAccount`
6. **Username LDAP Attribute**: `uid`
7. **RDN LDAP Attribute**: `uid`
8. **UUID LDAP Attribute**: `entryUUID`

## Backup/Restore

OpenLDAP data is stored in Longhorn PVC. To backup:

```bash
# Export LDIF
kubectl exec -n openldap deploy/openldap -- slapcat -v -l /tmp/backup.ldif
kubectl cp openldap/openldap-pod:/tmp/backup.ldif ./openldap-backup.ldif
```

## Troubleshooting

### Check LDAP connectivity:

```bash
kubectl run -it --rm ldap-test --image=alpine --restart=Never -- sh
apk add openldap-clients
ldapsearch -x -H ldaps://openldap.openldap.svc.cluster.local:636 \
  -D "cn=admin,dc=chillincool,dc=net" -W -b "dc=chillincool,dc=net"
```

### View OpenLDAP logs:

```bash
kubectl logs -n openldap -l app.kubernetes.io/name=openldap --tail=100
```

### Verify TLS certificate:

```bash
# Check OpenLDAP LDAPS certificate
kubectl get certificate -n openldap openldap-tls

# Check web UI certificate
kubectl get certificate -n openldap ldap-tls

# Test LDAPS connection with openssl
kubectl run -it --rm ldaps-test --image=alpine --restart=Never -- sh
apk add openssl
openssl s_client -connect openldap.openldap.svc.cluster.local:636 -showcerts
```
