# GitHub Copilot Instructions for nante-reusable-workflow

This repository hosts reusable GitHub Actions workflows for provisioning and configuring infrastructure on a self-hosted Proxmox Home Lab. It serves as a centralized, modular CI/CD pipeline called by application repositories to build, test, deploy, and manage applications on VMs, LXCs, and Kubernetes clusters.

## Project Vision & Goals

**Mission:** Build a complete, modular, pluggable CI/CD pipeline for self-hosted infrastructure that supports:
- Infrastructure provisioning (VMs, LXCs, K8s clusters)
- Application building and testing (CI)
- Artifact management (Nexus)
- Deployment orchestration (Octopus Deploy)
- Configuration management (Ansible)
- Observability (Grafana Alloy + OpenObserve)

**Core Principles:**
- **Modularity:** Each workflow is independently callable (CI only, CD only, provision only, etc.)
- **Composability:** Workflows are building blocks, not monoliths
- **Reusability:** One workflow repo serves many application repos
- **Security:** All secrets via Doppler, zero hardcoded credentials
- **Observability:** All infrastructure monitored by default
- **Go-First:** Use Go for complex scripting, avoid Python/Bash for logic

**Technology Stack:**
- **IaC:** Terraform (Proxmox provider)
- **Config Mgmt:** Ansible
- **CI/CD:** GitHub Actions (self-hosted) + Octopus Deploy
- **Secrets:** Doppler
- **Artifacts:** Nexus Repository (self-hosted)
- **State:** MinIO (S3-compatible)
- **Networking:** Tailscale (mesh VPN)
- **Observability:** Grafana Alloy + OpenObserve
- **Hypervisor:** Proxmox VE
- **Scripting:** Go (Golang)

## Current State (Phase 1 - Complete ✓)

### Implemented Features

**Infrastructure Provisioning:**
- ✓ VM provisioning via Terraform + Proxmox (`reusable-provision.yml`)
- ✓ VM destruction with safety checks (`reusable-destroy.yml`)
- ✓ Existing infrastructure onboarding (`reusable-onboard.yml`)
- ✓ Bootstrap workflow for initial user setup (`reusable-bootstrap.yml`)
- ✓ Configurable: CPU, RAM, disk, VLAN, storage, node, template
- ✓ Terraform state in MinIO with workspace isolation per app
- ✓ Optional `skip_terraform` flag for existing VMs

**Configuration Management:**
- ✓ Ansible-based configuration with dynamic role selection
- ✓ `base_setup` role: Tailscale, Alloy observability, system config
- ✓ `mgmt-docker` role: Docker host monitoring (containers + logs)
- ✓ `nginx` role: Web server setup
- ✓ SSH key-based authentication via `deploy` user

**Secret Management:**
- ✓ Doppler CLI integration with `doppler run` for secret injection
- ✓ Project/config based organization
- ✓ No hardcoded secrets in workflows

**Observability:**
- ✓ Grafana Alloy on all nodes
- ✓ System metrics (node_exporter) and logs
- ✓ Docker container metrics and logs (mgmt-docker)
- ✓ Centralized to OpenObserve (Prometheus + Loki)

**Networking:**
- ✓ Tailscale mesh VPN on all infrastructure
- ✓ Services exposed only via Tailnet
- ✓ VLAN-based IP addressing (192.168.VLAN.x)

## Future Roadmap (Phase 2-5)

See `ARCHITECTURE.md` for detailed implementation plan.

**Phase 2 - Octopus Deploy Integration (Complete - v1.0.0):**
- ✅ Created `octopus-tentacle` Ansible role
- ✅ Integrated into `reusable-provision.yml` workflow
- ✅ Integrated into `reusable-onboard.yml` workflow
- ✅ Polling and Listening communication modes
- ✅ Environment and role-based targeting
- ✅ Automated cleanup workflow for orphaned targets
- ✅ Comprehensive documentation

**Phase 2.5 - Tailscale Terraform Migration (Complete - v1.0.0):**
- ✅ Tailscale Terraform provider integration
- ✅ Automatic auth key generation
- ✅ Automatic device cleanup on VM destroy
- ✅ Tag-based device organization
- ✅ Conditional Ansible installation (hybrid approach)
- ✅ Migration documentation

**Phase 3 - LXC Container Support:**
- Terraform module for Proxmox LXC
- LXC provisioning workflow
- Container-optimized Ansible roles

**Phase 4 - Kubernetes & Docker Deployments:**
- Multi-node K3s cluster setup
- K8s application deployment workflow
- Docker application deployment workflow
- Nexus integration for image/chart pulls

**Phase 5 - Complete CI/CD Pipeline:**
- Reusable CI composite actions (build, test, scan, publish)
- CI workflow (build → test → Nexus)
- CD workflow (Octopus → deploy → configure)
- Full pipeline workflow (provision → CI → CD)
- Go CLI tools for complex operations

## Component Details

### Terraform (`/terraform`)
**Purpose:** Infrastructure as Code for Proxmox resources

**Configuration:**
- **Provider:** `Telmate/proxmox`
- **State Backend:** MinIO S3 at `http://192.168.20.10:9000`
- **Workspace Strategy:** One workspace per application for state isolation
- **Resources:** VMs (current), LXCs (future)

**Configurable Parameters:**
- `proxmox_node` (default: `pmx`)
- `proxmox_storage` (default: `zfs-vm`)
- `vm_template` (default: `ubuntu-2404-template`)
- `target_node`, `storage`, `clone` can be overridden per deployment

**Conventions:**
- Gateway: `192.168.<vlan_tag>.1`
- VM naming: `${app_name}-vm`
- Workspace naming: `${app_name}`

### Ansible (`/ansible`)
**Purpose:** Configuration management and application deployment

**Connection:**
- **User:** `deploy` (created via cloud-init or bootstrap)
- **Auth:** SSH key-based (no passwords)
- **Inventory:** Ad-hoc comma-separated IP list

**Roles:**
- **`base_setup`**: Core system configuration
  - Sets hostname
  - Installs essential packages
  - Configures Tailscale VPN (or skips if Terraform-managed)
  - Installs Grafana Alloy for observability
  - Collects system metrics and logs
  - Installs and registers Octopus Tentacle (if Octopus configured)
  
- **`mgmt-docker`**: Docker host monitoring
  - Replaces `base_setup` for Docker servers
  - Monitors containers, logs, and resources
  - Adds alloy user to docker group
  
- **`nginx`**: Web server setup
  - Installs and configures Nginx
  - Alloy integration for logs
  
- **`octopus-tentacle`**: Octopus Deploy agent
  - Installs Tentacle on Linux
  - Registers with Octopus Server
  - Supports Polling and Listening modes
  - Configurable environments and roles
- **`k3s-cluster`** (FUTURE): Kubernetes cluster
- **`app-deploy`** (FUTURE): Application deployment

**Dynamic Role Selection:**
- Pass `app_role_name` to apply specific role
- `base_setup` always runs unless role is `mgmt-docker`

### GitHub Actions Workflows
**Purpose:** Orchestration and automation

**Runner:** Self-hosted (required for Proxmox LAN access)

**Current Workflows:**
1. **`reusable-provision.yml`**: Provision VM + configure with Ansible
2. **`reusable-destroy.yml`**: Destroy VM and clean up state
3. **`reusable-onboard.yml`**: Configure existing infrastructure
4. **`reusable-bootstrap.yml`**: Initial user setup on existing VMs

**Design Patterns:**
- Accept flags for modularity (`skip_terraform`, `skip_provision`)
- Use `doppler run` for secret injection
- All secrets from Doppler, none from GitHub Secrets (except Doppler token)
- Idempotent operations (safe to re-run)

**Future Workflows:**
- `reusable-provision-lxc.yml`: LXC provisioning
- `reusable-ci.yml`: Build, test, publish to Nexus
- `reusable-deploy-k8s.yml`: Deploy to Kubernetes
- `reusable-deploy-docker.yml`: Deploy to Docker host
- `reusable-full-pipeline.yml`: End-to-end CI/CD

## Development Guidelines

### Language & Tooling Preferences

**Go (Golang) for Complex Logic:**
- Use Go for any scripting beyond simple shell commands
- CLI tools, API integrations, data transformations
- Avoid Python/Bash for complex logic
- Keep Go code modular and testable

**Bash for Simple Tasks:**
- One-liners and simple command sequences
- File operations, service management
- Anything that doesn't require error handling or logic

**When to Use What:**
- Simple command: Bash inline in workflow
- Multi-step with logic: Go script in `/tools`
- API integration: Go with proper error handling
- Data transformation: Go with structs and types

### Workflow Design Patterns

**Modularity:**
- Each workflow is independently callable
- Accept flags for conditional behavior (`skip_terraform`, `skip_provision`)
- No assumptions about previous steps
- Idempotent operations (safe to re-run)

**Composability:**
- Workflows call other workflows when needed
- Composite actions for reusable steps
- Share variables via outputs
- Chain workflows with `needs:`

**Error Handling:**
- Validate inputs at start of workflow
- Fail fast with clear error messages
- Use `if: failure()` for cleanup steps
- Log context for debugging

### Terraform Best Practices

**Initialization:**
```bash
cd terraform/
export AWS_ACCESS_KEY_ID="$MINIO_ROOT_USER"
export AWS_SECRET_ACCESS_KEY="$MINIO_ROOT_PASSWORD"

terraform init \
  -backend-config="bucket=terraform-state" \
  -backend-config='endpoints={s3="http://192.168.20.10:9000"}' \
  -backend-config="access_key=$MINIO_ROOT_USER" \
  -backend-config="secret_key=$MINIO_ROOT_PASSWORD"
```

**Workspace Management:**
```bash
# Select or create workspace
terraform workspace select $APP_NAME || terraform workspace new $APP_NAME

# Always verify current workspace
terraform workspace show

# List all workspaces
terraform workspace list
```

**Variable Passing:**
```bash
terraform plan \
  -var="app_name=myapp" \
  -var="vlan_tag=20" \
  -var="vm_target_ip=192.168.20.50" \
  -var="proxmox_target_node=pmx" \
  -out=tfplan

terraform apply tfplan
```

### Ansible Best Practices

**Execution:**
```bash
cd ansible/

# Install requirements
ansible-galaxy install -r requirements.yml

# Test connectivity
ansible all -i "192.168.20.50," -m ping --user deploy

# Run playbook
ansible-playbook -i "192.168.20.50," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp" \
  --extra-vars "app_role_name=nginx"
```

**Secret Handling:**
- All secrets via Doppler environment variables
- SSH keys via `ssh-agent` (no temp files)
- No secrets in playbooks or roles
- Use `lookup('env', 'VAR_NAME')` for secrets

**Role Development:**
- Keep roles focused (single responsibility)
- Use `defaults/main.yml` for variables
- Document role in `README.md`
- Test roles independently
- Use handlers for service restarts

### Doppler Secret Management

**Setup:**
```bash
# Install Doppler CLI (done by action)
doppler setup --project PROJECT --config CONFIG

# Verify secrets
doppler secrets
```

**Usage in Workflows:**
```yaml
- name: Install Doppler CLI
  uses: dopplerhq/cli-action@v3

- name: Configure Doppler
  run: doppler setup --project "${{ secrets.DOPPLER_TARGET_PROJECT }}" --config "${{ secrets.DOPPLER_TARGET_CONFIG }}" --no-interactive
  env:
    DOPPLER_TOKEN: ${{ secrets.DOPPLER_TOKEN }}

- name: Run with secrets
  run: |
    doppler run -- bash <<'EOF'
    # All secrets available as environment variables
    echo "$PROXMOX_API_URL"
    terraform apply
    EOF
```

**Secret Naming Conventions:**
- Service URLs: `SERVICE_URL` or `SERVICE_HOST`
- API keys: `SERVICE_API_KEY`
- Credentials: `SERVICE_USERNAME`, `SERVICE_PASSWORD`
- Tokens: `SERVICE_TOKEN`
- Use SCREAMING_SNAKE_CASE

**Current Required Secrets:**
```bash
# Proxmox
PROXMOX_API_URL=https://pmx.example.com:8006/api2/json
PROXMOX_TOKEN_ID=user@pam!token
PROXMOX_TOKEN_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# SSH Keys
ANS_SSH_PUBLIC_KEY="ssh-rsa AAAA..."
SSH_PRIVATE_KEY="-----BEGIN OPENSSH PRIVATE KEY-----..."

# Tailscale (Terraform-managed)
TAILSCALE_OAUTH_CLIENT_ID=k123abc...
TAILSCALE_OAUTH_CLIENT_SECRET=tskey-client-k123abc...
TAILSCALE_TAILNET=-  # or your tailnet name
TS_AUTHKEY=tskey-auth-xxxxx  # Fallback for Ansible-managed (legacy)

# OpenObserve
OO_HOST=192.168.20.10

# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=password

# Octopus Deploy
OCTOPUS_SERVER_URL=https://octopus.example.com
OCTOPUS_API_KEY=API-XXXXXXXXXX
OCTOPUS_SPACE_ID=Spaces-1
OCTOPUS_ENVIRONMENT=Development

# GitHub
GH_PAT=ghp_xxxxxxxxxxxx
```

## Integration Points

### Current Integrations

**Proxmox VE:**
- Target hypervisor for VMs and LXCs
- API access via token authentication
- Defaults: `node=pmx`, `storage=zfs-vm`
- Network: Bridge with VLAN tagging

**Tailscale:**
- **Primary networking layer** - all services exposed via Tailnet only
- Every VM/LXC joins mesh on provisioning
- MagicDNS for service discovery
- No public ingress required

**Doppler:**
- **Source of truth for all secrets**
- CLI integration via `dopplerhq/cli-action@v3`
- Secrets injected with `doppler run --`
- Project/config based organization
- Required secrets documented in `USAGE.md`

**MinIO:**
- S3-compatible object storage for Terraform state
- Endpoint: `http://192.168.20.10:9000`
- Bucket: `terraform-state`
- Workspace isolation per application

**OpenObserve:**
- Centralized observability platform
- Prometheus endpoint: `:9090/api/v1/write`
- Loki endpoint: `:3100/loki/api/v1/push`
- No authentication required (internal only)

**GitHub:**
- Self-hosted runners for workflow execution
- PAT for repository access (`GH_PAT`)
- Workflow dispatch for manual triggers

### Future Integrations

**Octopus Deploy (Phase 2 - In Progress):**
- Self-hosted CD platform
- ✓ Tentacle agent installation via Ansible
- ✓ Automatic target registration in workflows
- ✓ Environment-based deployments (dev, staging, prod)
- ✓ Role-based targeting
- Polling mode (recommended) and Listening mode
- Release creation triggered from CI (Phase 5)

**Nexus Repository (Phase 4-5):**
- Self-hosted artifact repository
- Docker registry for container images
- Helm chart repository
- Generic artifact storage (JARs, binaries, etc.)
- Octopus pulls artifacts from Nexus feeds

**Kubernetes (Phase 4):**
- K3s clusters on Proxmox VMs
- Multi-node with HA control plane
- Storage via Longhorn or NFS
- Ingress via Tailscale
- Deployment via Helm or kubectl

**Docker (Phase 4):**
- Standalone Docker hosts
- Docker Compose deployments
- Container registry: Nexus
- Monitoring via `mgmt-docker` role
