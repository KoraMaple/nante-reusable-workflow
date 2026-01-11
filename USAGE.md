# Using Nante Reusable Workflows

## Quick Start

### CI/CD Workflows

For building and testing your application, use the CI build workflow:

#### Go Application
```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-go.yml@main
    with:
      app_name: "my-go-app"
      go_version: "1.22"
      build_tool: "make"
    secrets: inherit
```

#### Python Application
```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-python.yml@main
    with:
      app_name: "my-python-app"
      python_version: "3.11"
      build_tool: "poetry"
    secrets: inherit
```

#### Node.js Application
```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-node.yml@main
    with:
      app_name: "my-node-app"
      node_version: "20"
      build_tool: "npm"
    secrets: inherit
```

#### Java Application
```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-java.yml@main
    with:
      app_name: "my-java-app"
      java_version: "17"
      build_tool: "maven"
    secrets: inherit
```

### Infrastructure Provisioning

From your application repository, create a workflow that calls `reusable-provision.yml`:

```yaml
name: Deploy to Proxmox

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@v0.1.0-alpha
    with:
      app_name: "nginx"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.100"
      cpu_cores: "2"
      ram_mb: "2048"
      disk_gb: "20G"
    secrets: inherit
```

## Required Secrets

### For CI/CD Workflows

Set these in your **caller repository**:

| Secret | Description | Example |
|--------|-------------|---------|
| `DOPPLER_TOKEN` | **Required** - Doppler service token for fetching secrets | (from Doppler dashboard) |

In **Doppler**, configure these secrets:

| Secret | Description | Example |
|--------|-------------|---------|
| `NEXUS_URL` | Nexus repository URL | `https://nexus.example.com` |
| `NEXUS_USERNAME` | Nexus username | `ci-user` |
| `NEXUS_PASSWORD` | Nexus password | (generated in Nexus) |
| `SONAR_URL` | SonarQube server URL | `https://sonarqube.example.com` |
| `SONAR_TOKEN` | SonarQube authentication token | (generated in SonarQube) |

#### Setting up Doppler

1. Create a Doppler account at https://doppler.com
2. Create a project for your application
3. Add the required secrets (NEXUS_URL, NEXUS_USERNAME, etc.)
4. Generate a service token:
   - Go to your project → Access → Service Tokens
   - Click **Generate** and select the appropriate config
   - Copy the token
5. Add the token to your GitHub repository:
   - Go to **Settings → Secrets and variables → Actions**
   - Click **New repository secret**
   - Name: `DOPPLER_TOKEN`
   - Value: Your service token

### For Infrastructure Provisioning

Set these in your **caller repository** (or at the organization level):

| Secret | Description | Example |
|--------|-------------|---------|
| `GH_PAT` | **Required** - GitHub PAT with `repo` scope to checkout this private repo | (GitHub Personal Access Token) |
| `PROXMOX_API_URL` | Proxmox API endpoint | `https://192.168.1.100:8006/api2/json` |
| `PROXMOX_TOKEN_ID` | Proxmox API token ID | `root@pam!terraform` |
| `PROXMOX_TOKEN_SECRET` | Proxmox API token secret | (generated in Proxmox) |
| `ANS_SSH_PUBLIC_KEY` | Public key for cloud-init | (contents of ~/.ssh/id_rsa.pub) |
| `SSH_PRIVATE_KEY` | Private key for Ansible | (contents of ~/.ssh/id_rsa) |
| `TS_AUTHKEY` | Tailscale auth key | (generated in Tailscale admin) |
| `OO_USER` | OpenObserve username | `admin@example.com` |
| `OO_PASS` | OpenObserve password | (your OpenObserve password) |
| `OO_HOST` | OpenObserve host/IP | `192.168.20.5` |

### Creating the GH_PAT Secret

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name like `nante-workflow-access`
4. Select the `repo` scope (full control of private repositories)
5. Generate and copy the token
6. In your **caller repository**, go to **Settings → Secrets and variables → Actions**
7. Click **New repository secret**, name it `GH_PAT`, paste the token

## Supported Application Roles

Create Ansible roles in `ansible/roles/<app_name>/` in this repository. Common examples:

- `nginx` – Installs and configures Nginx
- `k3s` – Installs and configures Kubernetes (K3s)
- `nexus` – Installs Nexus Repository Manager

The `app_name` parameter will automatically run the corresponding role.

## Destroying Resources

To destroy a VM you created:

```yaml
jobs:
  cleanup:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-destroy.yml@v0.1.0-alpha
    with:
      app_name: "nginx"
      vlan_tag: "20"
      cpu_cores: "2"
      ram_mb: "2048"
      disk_gb: "20G"
      confirm_destroy: true
    secrets: inherit
```

**Important:** Set `confirm_destroy: true` to prevent accidental deletions.

## What Happens

### Provision Workflow

1. **Terraform Plan** – Shows what will be created
2. **Terraform Apply** – Provisions VM on Proxmox
3. **SSH Warm-up** – Waits 30 seconds for VM to boot
4. **Ansible Config** – Runs playbooks to configure the OS
   - `base_setup` role (always runs)
     - Installs Tailscale and joins your mesh network
     - Installs Grafana Alloy for metrics/logs collection
   - Application-specific role (e.g., `nginx`)

### Destroy Workflow

1. **Confirmation Check** – Requires `confirm_destroy: true`
2. **Terraform Plan Destroy** – Shows what will be deleted
3. **Terraform Destroy** – Removes VM from Proxmox
4. **State Cleanup** – Removes Terraform state file

## Architecture

```
Your App Repo (nginx-deploy)
    ↓
Calls: reusable-provision.yml
    ↓
Terraform (creates VM on Proxmox)
    ↓
Cloud-Init (sets up deploy user)
    ↓
Ansible (configures OS + app)
    ↓
Tailscale (joins mesh network)
    ↓
Grafana Alloy (sends metrics/logs to OpenObserve)
```

## Networking

- **Tailscale:** All VMs are accessed exclusively via Tailscale. No public ingress.
- **Local Network:** VMs get static IPs on your local VLAN (e.g., `192.168.20.x`).
- **OpenObserve:** Metrics and logs are sent to your OpenObserve instance at `http://<OO_HOST>:5080`.

## Troubleshooting

### SSH Key Validation Failed
- Ensure `SSH_PRIVATE_KEY` is properly formatted and complete
- Check that there are no extra whitespace or line breaks

### Ansible Connection Timeout
- Verify VM booted successfully (increase wait time if needed)
- Check SSH connectivity: `ssh -i your_key deploy@<vm_ip>`

### Tailscale Connection Failed
- Verify `TS_AUTHKEY` is still valid
- Check OpenObserve connectivity from the VM

## Support

For issues or questions, refer to [.github/copilot-instructions.md](.github/copilot-instructions.md) for architecture details.
