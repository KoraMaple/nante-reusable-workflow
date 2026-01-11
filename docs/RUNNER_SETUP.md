# Runner Setup Guide

This document describes the prerequisites and setup options for GitHub Actions runners.

## Runner Options

This repository supports a **hybrid runner architecture**:

| Runner Type | Best For | Requirements | Cost |
|-------------|----------|--------------|------|
| **GitHub-Hosted + Tailscale** | CI/CD, testing, open source | Tailscale OAuth credentials | Uses GH Actions minutes |
| **Self-Hosted (Persistent)** | Production infrastructure | Dedicated machine with LAN access | Free, requires maintenance |
| **Self-Hosted (Ephemeral)** | High-security environments | Kubernetes or auto-scaling | Free, complex setup |

---

## Option 1: GitHub-Hosted Runners with Tailscale (Recommended for Open Source)

This option uses GitHub-hosted runners with Tailscale VPN for secure access to internal infrastructure.

### Prerequisites

1. **Tailscale Account** with Owner/Admin permissions
2. **OAuth Client** with `auth_keys` scope for CI
3. **ACL Tags** configured for CI runners

### Setup

#### 1. Create Tailscale OAuth Client

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/oauth) → Settings → OAuth Clients
2. Create a new OAuth client with:
   - **Description**: `GitHub Actions CI`
   - **Tags**: `tag:ci`
   - **Scopes**: `auth_keys` (write)
3. Save the **Client ID** and **Client Secret**

#### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `TS_OAUTH_CLIENT_ID` | Your Tailscale OAuth Client ID |
| `TS_OAUTH_CLIENT_SECRET` | Your Tailscale OAuth Client Secret |

#### 3. Configure Tailscale ACLs

Add CI runner access rules to your Tailscale ACL:

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
        "tag:proxmox:22,8006",
        "tag:minio:9000",
        "tag:target-vms:22"
      ]
    }
  ]
}
```

#### 4. Use in Workflows

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    with:
      app_name: "nginx"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.50"
      runner_type: "github-hosted"  # Use GitHub-hosted runner
      tailscale_tags: "tag:ci"      # ACL tags for access control
    secrets:
      DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}
      DOPPLER_TARGET_PROJECT: ${{ secrets.DOPPLER_TARGET_PROJECT }}
      DOPPLER_TARGET_CONFIG: ${{ secrets.DOPPLER_TARGET_CONFIG }}
      GH_PAT: ${{ secrets.GH_PAT }}
      TS_OAUTH_CLIENT_ID: ${{ secrets.TS_OAUTH_CLIENT_ID }}
      TS_OAUTH_CLIENT_SECRET: ${{ secrets.TS_OAUTH_CLIENT_SECRET }}
```

### Benefits

- ✅ No infrastructure to maintain
- ✅ Ephemeral runners (clean environment each time)
- ✅ Works with public repositories
- ✅ Automatic scaling
- ✅ Secure network access via Tailscale

---

## Option 2: Self-Hosted Runners (Traditional)

This option uses dedicated self-hosted runners with direct LAN access.

### Prerequisites

Your self-hosted runner needs the following installed:

#### Required Packages

```bash
# Update package list
sudo apt-get update

# Install required packages
sudo apt-get install -y \
  ansible \
  terraform \
  sshpass \
  git \
  curl \
  jq
```

#### Passwordless Sudo (Recommended)

For workflows to install packages automatically:

```bash
# Replace 'runner' with your actual runner username
echo 'runner ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/github-runner
sudo chmod 440 /etc/sudoers.d/github-runner
```

**Security Note:** Only do this on dedicated runner machines.

#### Pre-install All Dependencies

```bash
# One-time setup script for runner
sudo apt-get update
sudo apt-get install -y \
  ansible \
  terraform \
  sshpass \
  git \
  curl \
  jq \
  python3-pip \
  openssh-client

# Install Doppler CLI
curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
  'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
  https://packages.doppler.com/public/cli/deb/debian any-version main" | \
  sudo tee /etc/apt/sources.list.d/doppler-cli.list

sudo apt-get update
sudo apt-get install -y doppler
```

### Verify Setup

```bash
#!/bin/bash
echo "Checking runner prerequisites..."

# Check for required commands
REQUIRED_COMMANDS="ansible terraform sshpass git curl doppler jq"
MISSING=""

for cmd in $REQUIRED_COMMANDS; do
  if command -v $cmd &> /dev/null; then
    echo "✓ $cmd installed"
  else
    echo "✗ $cmd NOT installed"
    MISSING="$MISSING $cmd"
  fi
done

# Check sudo access
if sudo -n true 2>/dev/null; then
  echo "✓ Passwordless sudo configured"
else
  echo "⚠ Passwordless sudo NOT configured (workflows may fail)"
fi

if [ -n "$MISSING" ]; then
  echo ""
  echo "❌ Missing required packages:$MISSING"
  echo "Run: sudo apt-get install -y$MISSING"
  exit 1
else
  echo ""
  echo "✓ All prerequisites met!"
fi
```

### Network Requirements

The runner needs access to:
- GitHub API (internet)
- Doppler API (internet)
- Proxmox server (LAN, port 8006)
- MinIO server (LAN, port 9000)
- Target VMs (LAN, port 22)

---

## Option 3: Ephemeral Self-Hosted Runners

For high-security environments, use ephemeral runners that are created for each job and destroyed afterward.

### Actions Runner Controller (Kubernetes)

If you have Kubernetes, use [actions-runner-controller](https://github.com/actions/actions-runner-controller):

```yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: nante-runner
spec:
  replicas: 1
  template:
    spec:
      repository: KoraMaple/nante-reusable-workflow
      ephemeral: true
      labels:
        - self-hosted
        - linux
        - ephemeral
```

### Benefits

- ✅ Fresh environment for each job
- ✅ No persistent state
- ✅ Auto-scaling
- ✅ Kubernetes-native

---

## Target VM Requirements

For the **bootstrap workflow** to work, target VMs must have:

1. **SSH server running** on port 22
2. **Password authentication enabled** (temporarily):
   ```bash
   # On target VM
   sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```
3. **Root or admin user** with known password
4. **Network connectivity** from runner to target VM

**Security Note:** After bootstrap completes, disable password auth:
```bash
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

## Troubleshooting

### "sudo: a password is required"

**Cause:** Runner user doesn't have passwordless sudo configured.

**Solution:** Either:
1. Configure passwordless sudo (see above)
2. Pre-install all required packages
3. Run workflows that don't require package installation

### "sshpass: command not found"

**Cause:** sshpass not installed on runner.

**Solution:**
```bash
sudo apt-get update && sudo apt-get install -y sshpass
```

### "doppler: command not found"

**Cause:** Doppler CLI not installed on runner.

**Solution:** The `dopplerhq/cli-action@v3` should install it automatically, but you can pre-install (see above).

### "Tailscale connection failed"

**Cause:** OAuth credentials incorrect or missing.

**Solution:**
1. Verify `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_CLIENT_SECRET` secrets are set
2. Check OAuth client has `auth_keys` scope
3. Verify ACL allows the tags you're using

---

## Security Best Practices

1. **Use GitHub-Hosted Runners When Possible** - Less maintenance, automatic security updates
2. **Ephemeral Runners** - Use ephemeral mode for self-hosted runners when possible
3. **Tailscale ACLs** - Restrict CI runner access to only required resources
4. **Rotate Secrets Regularly** - Update Doppler tokens, OAuth secrets, and PATs
5. **Monitor Logs** - Review runner and workflow logs for anomalies
6. **Environment Protection** - Use GitHub Environment Protection Rules for production

See [SECURITY.md](./SECURITY.md) for comprehensive security guidelines.
