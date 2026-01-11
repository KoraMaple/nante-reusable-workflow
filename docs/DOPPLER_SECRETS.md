# Doppler Secrets Configuration

## Overview

This document lists all required and optional secrets that should be configured in Doppler for the infrastructure automation workflows.

## Required Secrets

### Proxmox Configuration
```
PROXMOX_API_URL=https://proxmox-host:8006/api2/json
PROXMOX_TOKEN_ID=terraform@pam!terraform-token
PROXMOX_TOKEN_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### SSH Configuration
```
SSH_PRIVATE_KEY=<private-key-content>
ANS_SSH_PUBLIC_KEY=<public-key-content>
```

### Tailscale Configuration
```
TAILSCALE_OAUTH_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxx
TAILSCALE_OAUTH_CLIENT_SECRET=tskey-client-xxxxxxxxxxxxxxxxxxxxxxxx
TAILSCALE_TAILNET=your-tailnet-name.ts.net
```

## Optional Secrets

### Octopus Deploy (for deployment orchestration)
```
OCTOPUS_SERVER_URL=http://octopus-server:8080
OCTOPUS_API_KEY=API-XXXXXXXXXXXXXXXXXXXXXXXX
OCTOPUS_SPACE_ID=Spaces-1
OCTOPUS_ENVIRONMENT=Development
```

**Note**: If these are not set, Octopus Tentacle installation will be skipped.

### Grafana Alloy (for observability)
```
OO_HOST=grafana-server-ip
OO_USER=admin
OO_PASS=admin-password
```

**Note**: If these are not set, Grafana Alloy installation will be skipped.

### FreeIPA LDAP (for centralized authentication)
```
FREEIPA_SERVER_IP=192.168.20.10
FREEIPA_ADMIN_PASSWORD=<admin-password-from-setup>
```

**Note**: If these are not set, LDAP client enrollment will be skipped.

**Setup Process**:
1. First provision FreeIPA server using `app_role_name=freeipa`
2. Save the generated admin password from the playbook output
3. Add `FREEIPA_SERVER_IP` and `FREEIPA_ADMIN_PASSWORD` to Doppler
4. All subsequent server provisioning will automatically enroll with FreeIPA

## Doppler Setup

### 1. Create Doppler Project

```bash
doppler projects create nante-infrastructure
```

### 2. Create Environments

```bash
doppler configs create dev --project nante-infrastructure
doppler configs create staging --project nante-infrastructure
doppler configs create prod --project nante-infrastructure
```

### 3. Add Secrets

```bash
# Switch to project and config
doppler setup --project nante-infrastructure --config dev

# Add secrets
doppler secrets set PROXMOX_API_URL="https://proxmox:8006/api2/json"
doppler secrets set PROXMOX_TOKEN_ID="terraform@pam!terraform-token"
doppler secrets set PROXMOX_TOKEN_SECRET="your-token-secret"

# Add SSH keys
doppler secrets set SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)"
doppler secrets set ANS_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"

# Add Tailscale
doppler secrets set TAILSCALE_OAUTH_CLIENT_ID="your-client-id"
doppler secrets set TAILSCALE_OAUTH_CLIENT_SECRET="your-client-secret"
doppler secrets set TAILSCALE_TAILNET="your-tailnet.ts.net"

# Optional: Add Octopus Deploy
doppler secrets set OCTOPUS_SERVER_URL="http://octopus:8080"
doppler secrets set OCTOPUS_API_KEY="API-XXXXXXXX"
doppler secrets set OCTOPUS_SPACE_ID="Spaces-1"

# Optional: Add Grafana
doppler secrets set OO_HOST="192.168.20.5"
doppler secrets set OO_USER="admin"
doppler secrets set OO_PASS="admin-password"

# Optional: Add FreeIPA (after server setup)
doppler secrets set FREEIPA_SERVER_IP="192.168.20.10"
doppler secrets set FREEIPA_ADMIN_PASSWORD="generated-password"
```

### 4. Generate Service Token for GitHub Actions

```bash
doppler configs tokens create github-actions --config dev --project nante-infrastructure
```

Add the token to GitHub Secrets as `DOPPLER_TOKEN`.

## GitHub Secrets

In addition to Doppler, configure these GitHub repository secrets:

```
DOPPLER_TOKEN=<service-token-from-doppler>
DOPPLER_TARGET_PROJECT=nante-infrastructure
DOPPLER_TARGET_CONFIG=dev
GH_PAT=<github-personal-access-token>
```

## Secret Validation

### Test Doppler Access

```bash
doppler run --command "env | grep -E '(PROXMOX|TAILSCALE|OCTOPUS|FREEIPA)'"
```

### Verify in Workflow

The workflow will automatically check for required secrets and skip optional components if secrets are missing.

## Security Best Practices

1. **Rotate Secrets Regularly**: Update tokens and passwords periodically
2. **Use Service Tokens**: Never use personal Doppler tokens in CI/CD
3. **Limit Token Scope**: Create separate tokens for dev/staging/prod
4. **Audit Access**: Review Doppler audit logs regularly
5. **Encrypt at Rest**: Doppler encrypts all secrets
6. **Use RBAC**: Configure role-based access in Doppler

## Troubleshooting

### Secret Not Found

```bash
# List all secrets
doppler secrets

# Check specific secret
doppler secrets get PROXMOX_API_URL
```

### GitHub Actions Can't Access Secrets

1. Verify `DOPPLER_TOKEN` is set in GitHub Secrets
2. Check token has access to the project/config
3. Verify `DOPPLER_TARGET_PROJECT` and `DOPPLER_TARGET_CONFIG` are correct

### FreeIPA Enrollment Fails

1. Verify `FREEIPA_SERVER_IP` is reachable from the server
2. Check `FREEIPA_ADMIN_PASSWORD` is correct
3. Ensure FreeIPA server is running and healthy
4. Check network connectivity and DNS resolution

## Migration Guide

### Moving from Environment Variables to Doppler

1. Export current environment variables
2. Import to Doppler using CLI or Web UI
3. Update workflows to use Doppler
4. Remove old environment variable files
5. Test workflows with Doppler integration

## References

- [Doppler Documentation](https://docs.doppler.com/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Proxmox API Tokens](https://pve.proxmox.com/wiki/User_Management#pveum_tokens)
- [Tailscale OAuth Clients](https://tailscale.com/kb/1215/oauth-clients/)
