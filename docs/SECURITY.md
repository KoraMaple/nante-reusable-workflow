# Security Best Practices

This document outlines security considerations and best practices for using the nante-reusable-workflow repository, especially when transitioning to a public repository.

## Table of Contents

1. [Runner Strategy](#runner-strategy)
2. [Secret Management](#secret-management)
3. [Environment Protection](#environment-protection)
4. [Log Sanitization](#log-sanitization)
5. [Network Security](#network-security)
6. [Open Source Considerations](#open-source-considerations)

---

## Runner Strategy

### Overview

This repository supports a hybrid runner architecture to balance security, cost, and accessibility:

| Runner Type | Use Case | Network Access | Cost |
|-------------|----------|----------------|------|
| **GitHub-Hosted + Tailscale** | Production deployments | Via Tailscale VPN | Uses GH Actions minutes |
| **Self-Hosted (Ephemeral)** | Development/Testing | Direct LAN access | Free, requires setup |
| **Self-Hosted (Persistent)** | Legacy/Internal only | Direct LAN access | Free, requires maintenance |

### GitHub-Hosted Runners with Tailscale

For secure access to internal infrastructure from GitHub-hosted runners:

1. **Tailscale VPN Connection**: Use `tailscale/github-action@v4` to connect runners to your Tailnet
2. **Ephemeral Nodes**: Runners are marked as ephemeral and auto-remove after workflow completion
3. **Tag-Based ACLs**: Use Tailscale ACL tags (e.g., `tag:ci`) to restrict access

```yaml
- name: Connect to Tailscale
  uses: tailscale/github-action@v4
  with:
    oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TS_OAUTH_CLIENT_SECRET }}
    tags: tag:ci
```

### Self-Hosted Runners (Ephemeral)

For development environments where GitHub-hosted runners are not suitable:

1. Use [actions-runner-controller](https://github.com/actions/actions-runner-controller) for Kubernetes
2. Configure runners with ephemeral mode (`--ephemeral` flag)
3. Run one workflow per runner instance
4. Auto-cleanup after workflow completion

### Tailscale ACL Configuration

Configure your Tailscale ACL to allow CI runners limited access:

```json
{
  "tagOwners": {
    "tag:ci": ["autogroup:admin"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ci"],
      "dst": [
        "tag:proxmox:22",
        "tag:proxmox:8006",
        "tag:minio:9000",
        "tag:target-vms:22"
      ]
    }
  ]
}
```

---

## Secret Management

### Doppler Integration

All secrets are managed through [Doppler](https://doppler.com/):

1. **Never hardcode secrets** in workflows or configuration files
2. **Use `doppler run`** to inject secrets at runtime
3. **Project/Config organization** for environment isolation (dev, staging, prod)
4. **Service tokens** for CI/CD (never personal tokens)

### GitHub Secrets (Minimal)

Only these secrets should be stored in GitHub:

| Secret | Purpose |
|--------|---------|
| `DOPPLER_TOKEN` | Service token for Doppler access |
| `DOPPLER_TARGET_PROJECT` | Doppler project name |
| `DOPPLER_TARGET_CONFIG` | Doppler config (dev, staging, prod) |
| `GH_PAT` | GitHub PAT for workflow checkout |

### Secret Masking

All workflows automatically mask sensitive values using `::add-mask::`:

```bash
# Mask sensitive values to prevent log exposure
if [ -n "$SECRET_VALUE" ]; then
  echo "::add-mask::$SECRET_VALUE"
fi
```

This prevents accidental exposure in workflow logs.

---

## Environment Protection

### GitHub Environment Protection Rules

For production workflows, configure environment protection:

1. **Go to Repository Settings** → Environments
2. **Create environments**: `development`, `staging`, `production`
3. **Configure protection rules**:
   - Required reviewers for production
   - Wait timer (e.g., 5 minutes for production)
   - Deployment branches (e.g., `main` only for production)

### Using Environments in Workflows

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: 
      name: production
      url: https://example.com
    steps:
      # Deployment steps here
```

### Branch Protection

Configure branch protection for `main` and `develop`:

1. Require pull request reviews
2. Require status checks to pass
3. Require signed commits (optional)
4. Restrict who can push

---

## Log Sanitization

### Automatic Masking

The workflows implement comprehensive secret masking:

- **Passwords**: `MINIO_ROOT_PASSWORD`, `FREEIPA_ADMIN_PASSWORD`, `NEXUS_PASSWORD`
- **Tokens**: `TAILSCALE_AUTH_KEY`, `TS_AUTHKEY`, `SONAR_TOKEN`, `OCTOPUS_API_KEY`
- **Secrets**: `PROXMOX_TOKEN_SECRET`, `TAILSCALE_OAUTH_CLIENT_SECRET`
- **Keys**: `SSH_PRIVATE_KEY`

### Debug Output Removed

All `DEBUG:` statements that could expose secrets have been removed. The workflows now use:

```bash
# Safe logging (no secret content)
echo "✓ Tailscale auth key available"

# Instead of unsafe logging
# echo "DEBUG: TAILSCALE_AUTH_KEY = ${TAILSCALE_AUTH_KEY:0:20}..."  # REMOVED
```

### Environment Variable Filtering

When listing environment variables for debugging:

```bash
# Filter out sensitive variables
env | grep -v "PASSWORD\|SECRET\|TOKEN\|KEY\|PRIVATE" | sort
```

---

## Network Security

### Tailscale Mesh VPN

All infrastructure is protected by Tailscale:

1. **No public ingress** - services only accessible via Tailnet
2. **MagicDNS** for internal service discovery
3. **ACL-based access control** between nodes
4. **Ephemeral keys** for CI runners (auto-expire, auto-remove)

### VLAN Segmentation

Network is segmented by purpose:

| VLAN | Purpose | IP Range |
|------|---------|----------|
| 20 | Management/Infrastructure | 192.168.20.x |
| 30 | Development | 192.168.30.x |
| 40 | Staging | 192.168.40.x |
| 50 | Production | 192.168.50.x |

### Firewall Rules

CI runners should only access required ports:

- **SSH (22)**: For Ansible connections
- **Proxmox API (8006)**: For Terraform provisioning
- **MinIO (9000)**: For Terraform state
- **Octopus Server**: For deployment target registration

---

## Open Source Considerations

### What's Safe to Expose

- Workflow logic and structure
- Ansible role templates (without secrets)
- Terraform configuration (without credentials)
- Documentation

### What Must Stay Private

- **Doppler Service Tokens**: Never commit
- **SSH Private Keys**: Never commit
- **API Keys/Tokens**: Never commit
- **Internal IP addresses**: Consider if they reveal network topology
- **Infrastructure hostnames**: Consider if they reveal sensitive information

### Fork Protection

When the repository is public:

1. **Disable fork PRs from running workflows** without approval
2. **Use `pull_request_target`** carefully (it has access to secrets)
3. **Review all external contributions** before running workflows
4. **Consider using CODEOWNERS** for critical files

### Workflow Trigger Security

```yaml
on:
  pull_request:
    # For PRs from forks, workflows won't have access to secrets
    # This is a security feature, not a bug

  # For internal PRs that need secrets:
  pull_request_target:
    types: [labeled]
    # Only runs when labeled (e.g., 'safe-to-test')
```

---

## Checklist for Going Public

Before making the repository public, verify:

- [ ] All secrets removed from code and history
- [ ] No internal IP addresses in committed files
- [ ] No hostnames that reveal sensitive info
- [ ] Debug statements removed/sanitized
- [ ] Environment protection configured
- [ ] Branch protection enabled
- [ ] CODEOWNERS file in place
- [ ] Fork workflow settings configured
- [ ] Dependabot security alerts enabled
- [ ] Secret scanning enabled

---

## References

- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Tailscale GitHub Action](https://github.com/tailscale/github-action)
- [Doppler Documentation](https://docs.doppler.com/)
- [GitHub Environment Protection Rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
