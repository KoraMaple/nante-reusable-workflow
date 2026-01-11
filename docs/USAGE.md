# Using Nante Reusable Workflows

## Quick Start

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
      vm_target_ip: "<INTERNAL_IP_VLAN20>"  # Example: 192.168.20.100
      cpu_cores: "2"
      ram_mb: "2048"
      disk_gb: "20G"
    secrets: inherit
```

## Required Secrets

We use **Doppler** for secret management. You need to configure the following secrets:

### GitHub Repository Secrets

Set these in your **caller repository** (or at the organization level):

| Secret | Description |
|--------|-------------|
| `GH_PAT` | **Required** - GitHub PAT with `repo` scope to checkout this private repo |
| `DOPPLER_TOKEN` | **Required** - Service Token from your Doppler project config |

### Doppler Secrets

Set these in your **Doppler Project**:

| Secret | Description | Example |
|--------|-------------|---------|
| `PROXMOX_API_URL` | Proxmox API endpoint | `https://<PROXMOX_HOST>:8006/api2/json` |
| `PROXMOX_TOKEN_ID` | Proxmox API token ID | `root@pam!terraform` |
| `PROXMOX_TOKEN_SECRET` | Proxmox API token secret | (generated in Proxmox) |
| `ANS_SSH_PUBLIC_KEY` | Public key for cloud-init | (contents of ~/.ssh/id_rsa.pub) |
| `SSH_PRIVATE_KEY` | Private key for Ansible | (contents of ~/.ssh/id_rsa) |
| `TS_AUTHKEY` | Tailscale auth key | (generated in Tailscale admin) |
| `OO_HOST` | OpenObserve host/IP | `<OPENOBSERVE_HOST>` |
| `OO_USER` | OpenObserve username | `admin@example.com` |
| `OO_PASS` | OpenObserve password | (your OpenObserve password) |
| `MINIO_ROOT_USER` | MinIO root user for Terraform state | (your MinIO root user) |
| `MINIO_ROOT_PASSWORD` | MinIO root password for Terraform state | (your MinIO root password) |

### Required GitHub Secrets

In addition to the Doppler secrets above, you must also configure these GitHub Secrets in your **caller repository**:

| Secret | Description | Example |
|--------|-------------|---------|
| `DOPPLER_TOKEN` | Doppler service token | (generated in Doppler dashboard) |
| `DOPPLER_TARGET_PROJECT` | Doppler project name | `nante-homelab` |
| `DOPPLER_TARGET_CONFIG` | Doppler config name | `dev` or `prd` |
| `GH_PAT` | GitHub Personal Access Token | (see below) |

### Creating the GH_PAT Secret

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name like `nante-workflow-access`
4. Select the `repo` scope (full control of private repositories)
5. Generate and copy the token
6. In your **caller repository**, go to **Settings → Secrets and variables → Actions**
7. Click **New repository secret**, name it `GH_PAT`, paste the token

## Self-Hosted Runner Setup

**IMPORTANT:** Before using these workflows, ensure your self-hosted runner is properly configured.

See [`RUNNER_SETUP.md`](./RUNNER_SETUP.md) for detailed setup instructions.

### Quick Setup

On your self-hosted runner machine:

```bash
# Install required packages
sudo apt-get update && sudo apt-get install -y ansible terraform sshpass

# Configure passwordless sudo (for runner user)
echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/github-runner
```

## Bootstrapping Existing Infrastructure

If you have existing VMs that don't have the `deploy` user and SSH key configured, you need to bootstrap them first.

### Prerequisites for Bootstrap Workflow

The bootstrap workflow requires **password authentication** to be enabled on the target VM's SSH server.

**Check SSH config on target VM:**
```bash
sudo grep PasswordAuthentication /etc/ssh/sshd_config
```

If it shows `PasswordAuthentication no`, you need to either:
1. **Enable it temporarily** (see [Troubleshooting Guide](./docs/TROUBLESHOOTING.md))
2. **Use manual bootstrap** (recommended, see below)

### Option 1: Manual Bootstrap (Recommended)

Access the VM via console (Proxmox GUI, physical access, or existing SSH key) and run:

```bash
# Create deploy user
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG sudo deploy

# Allow passwordless sudo
echo "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deploy

# Setup SSH directory
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh

# Add your public key (get from Doppler ANS_SSH_PUBLIC_KEY)
echo "YOUR_PUBLIC_KEY_HERE" | sudo tee /home/deploy/.ssh/authorized_keys
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
```

### Option 2: Bootstrap Workflow (Automated)

Use the `reusable-bootstrap` workflow to automate the process:

1. **Add bootstrap password to Doppler**: Create a secret like `BOOTSTRAP_SSH_PASSWORD` with the root/admin password
2. **Call the bootstrap workflow**:

```yaml
jobs:
  bootstrap:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-bootstrap.yml@develop
    with:
      target_ip: "<INTERNAL_IP_VLAN20>"  # Example: 192.168.20.150
      ssh_user: "root"  # or your existing admin user
      ssh_password_secret_name: "BOOTSTRAP_SSH_PASSWORD"
    secrets: inherit
```

3. **After bootstrap completes**, use `reusable-onboard` normally

### Security Note

After bootstrapping, consider:
- Disabling root SSH access
- Removing the bootstrap password from Doppler
- Using the `deploy` user for all future operations

## Supported Application Roles

Create Ansible roles in `ansible/roles/<app_name>/` in this repository. Common examples:

- **`nginx`** – Installs and configures Nginx web server
- **`k3s`** – Installs and configures Kubernetes (K3s)
- **`nexus`** – Installs Nexus Repository Manager
- **`mgmt-docker`** – Onboards existing Docker servers with container monitoring and log collection

The `app_name` parameter will automatically run the corresponding role.

### mgmt-docker Role

For existing servers running Docker with multiple containers:

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@develop
    with:
      target_ip: "<INTERNAL_IP_VLAN20>"  # Example: 192.168.20.50
      ssh_user: "deploy"
      target_hostname: "docker-mgmt"
      app_role: "mgmt-docker"
    secrets: inherit
```

**What it monitors:**
- System metrics (CPU, memory, disk, network)
- Docker socket metrics (container status, networks, volumes)
- Container resource usage (CPU, memory per container)
- System logs and all container logs

**Requirements:**
- Docker must be pre-installed on target
- Target must have `deploy` user with SSH key access (use bootstrap workflow if needed)

See [`ansible/roles/mgmt-docker/README.md`](./ansible/roles/mgmt-docker/README.md) for details.

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

## Observability (Metrics & Logs)

The `base_setup` role automatically installs and configures **Grafana Alloy** to collect observability data and send it to your OpenObserve instance.

### What is Collected?
1.  **System Metrics:** CPU, Memory, Disk usage, and Load averages (via `node_exporter` integration).
2.  **System Logs:** `/var/log/*.log` and `/var/log/syslog`.
3.  **Nginx Metrics:** Request counts, active connections, and status (via `stub_status`).
4.  **Nginx Logs:** Access and error logs from `/var/log/nginx/*.log`.

### Data Labels
All data is tagged with consistent labels for easy filtering:
*   `host` / `instance`: The VM hostname (e.g., `nginx-prod-a1b2`)
*   `job`: The source service (e.g., `node_exporter`, `nginx`, `system`, `nginx_metrics`)

## Terraform State Management

Terraform state is stored remotely in **MinIO** (S3-compatible object storage). Configure the endpoint via Doppler (`MINIO_ENDPOINT`) or use the `minio_endpoint` workflow input.

### How It Works
*   **Backend:** S3-compatible backend pointing to MinIO bucket `terraform-state`
*   **Workspaces:** Each app gets its own Terraform workspace (e.g., `nginx`, `k3s`)
*   **State Isolation:** State files are stored per-workspace, preventing conflicts

### MinIO Setup Prerequisites

Before running workflows, ensure:

1. **Create the bucket** in MinIO:
   ```bash
   mc alias set minio http://<MINIO_HOST>:9000 <access_key> <secret_key>
   mc mb minio/terraform-state
   ```

2. **Add credentials to Doppler:**
   - `MINIO_ROOT_USER` - Your MinIO root user
   - `MINIO_ROOT_PASSWORD` - Your MinIO root password
   - `MINIO_ENDPOINT` - Your MinIO endpoint (e.g., `http://minio.tailnet:9000`)

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
Grafana Alloy (collects & forwards data)
    ↓       ↘
OpenObserve (Metrics)   OpenObserve (Logs)
```

## Networking

- **Tailscale:** All VMs are accessed exclusively via Tailscale. No public ingress.
- **Local Network:** VMs get static IPs on your local VLAN (e.g., `192.168.<VLAN>.x`).
- **OpenObserve:** Metrics and logs are sent to your OpenObserve instance at `http://<OO_HOST>:5080`.

## Manual Onboarding

You can onboard existing machines (not created via Terraform) using the `reusable-onboard.yml` workflow.

### Example Workflow

Create a new workflow file in your repository (e.g., `.github/workflows/onboard-my-server.yml`):

```yaml
name: Onboard Manual Server

on:
  workflow_dispatch:
    inputs:
      target_ip:
        description: 'IP Address of the server'
        required: true
      ssh_user:
        description: 'SSH User (must have sudo)'
        required: true
        default: 'ubuntu'
      hostname:
        description: 'Hostname to set'
        required: true
      app_role:
        description: 'App Role (e.g., nginx)'
        required: false

jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@v0.1.0-alpha
    with:
      target_ip: ${{ inputs.target_ip }}
      ssh_user: ${{ inputs.ssh_user }}
      target_hostname: ${{ inputs.hostname }}
      app_role: ${{ inputs.app_role }}
    secrets: inherit
```

### Prerequisites

1.  **SSH Access:** The `SSH_PRIVATE_KEY` in Doppler must have access to the target machine's `ssh_user`.
2.  **Sudo:** The `ssh_user` must have passwordless sudo or be able to sudo.
3.  **Secrets:** The caller repository must have `GH_PAT` and `DOPPLER_TOKEN` configured.

## Troubleshooting

### SSH Key Validation Failed
- Ensure `SSH_PRIVATE_KEY` in Doppler is properly formatted and complete
- Check that there are no extra whitespace or line breaks

### Ansible Connection Timeout
- **Most Common Cause:** IP address mismatch between cloud-init static IP and Terraform output
- Verify VM booted successfully in Proxmox console
- Check cloud-init logs: `ssh -i your_key deploy@<vm_ip> 'sudo cloud-init status --long'`
- Verify network connectivity: `ping <vm_ip>` from the GitHub runner
- Check SSH connectivity: `ssh -i your_key deploy@<vm_ip>`
- Ensure the IP address is not already in use on your network
- Verify VLAN configuration matches your network setup

### Tailscale Connection Failed
- Verify `TS_AUTHKEY` is still valid
- Check OpenObserve connectivity from the VM

## Support

For issues or questions, refer to [.github/copilot-instructions.md](.github/copilot-instructions.md) for architecture details.
