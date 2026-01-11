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

## Current State (Phase 1-3 - Complete ✓)

### Implemented Features

**Infrastructure Provisioning:**
- ✓ VM provisioning via Terraform + Proxmox (`reusable-provision.yml`)
- ✓ LXC container provisioning with full support (`reusable-provision.yml`)
- ✓ **Multi-instance deployments** - provision multiple VMs/LXCs in single run
- ✓ VM destruction with safety checks (`reusable-destroy.yml`)
- ✓ Existing infrastructure onboarding (`reusable-onboard.yml`)
- ✓ Bootstrap workflow for initial user setup (`reusable-bootstrap.yml`)
- ✓ Configurable: CPU, RAM, disk, VLAN, storage, node, template per instance
- ✓ Terraform state in MinIO with workspace isolation per app
- ✓ Optional `skip_terraform` flag for existing VMs
- ✓ Support for cluster deployments (e.g., 3-node Patroni HA)

**Configuration Management:**
- ✓ Ansible-based configuration with dynamic role selection
- ✓ `base_setup` role: Tailscale, Alloy observability, system config
- ✓ `mgmt-docker` role: Docker host monitoring (containers + logs)
- ✓ `nginx` role: Web server setup
- ✓ `etcd` role: Distributed consensus for HA clusters
- ✓ `patroni` role: PostgreSQL HA with automatic failover
- ✓ `ldap-config` role: FreeIPA LDAP client enrollment
- ✓ `octopus-tentacle` role: Octopus Deploy agent
- ✓ SSH key-based authentication via `deploy` user (VMs) or `root` (LXC)

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

**Phase 3 - LXC Container Support (Complete - v1.1.0):**
- ✅ Terraform module for Proxmox LXC
- ✅ LXC provisioning via `reusable-provision.yml` (resource_type=lxc)
- ✅ Container-optimized Ansible roles (root user, TUN device support)
- ✅ Unprivileged containers with nesting support for Docker
- ✅ Multi-instance LXC deployments

**Phase 3.5 - Database HA Clusters (Complete - v1.2.0):**
- ✅ Patroni role for PostgreSQL HA
- ✅ etcd role for distributed consensus
- ✅ Multi-node cluster playbook (`patroni-cluster.yml`)
- ✅ Automatic failover and streaming replication
- ✅ Comprehensive documentation for cluster deployments

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
- **State Backend:** MinIO S3 (endpoint configured via Doppler `MINIO_ENDPOINT`)
- **Workspace Strategy:** One workspace per application for state isolation
- **Resources:** VMs and LXCs with multi-instance support

**Deployment Modes:**
1. **Single Instance Mode** (backward compatible):
   - Use `vm_target_ip` for single VM/LXC
   - Hostname: `${app_name}-${environment}-${random_hex}`

2. **Multi-Instance Mode** (for clusters):
   - Use `instances` map with named nodes
   - Hostname: `${app_name}-${environment}-${instance_key}`
   - Each instance can override CPU/RAM/disk defaults
   - Example: `{"node1": {"ip_address": "192.168.10.51"}}`

**Configurable Parameters:**
- `resource_type`: `vm` or `lxc`
- `proxmox_node` (default: `pmx`)
- `proxmox_storage` (default: `zfs-vm`)
- `vm_template` (default: `ubuntu-2404-template`)
- `lxc_template` (default: Ubuntu 22.04 LXC template)
- `lxc_unprivileged` (default: `true`)
- `lxc_nesting` (default: `false`, set `true` for Docker)
- `instances`: JSON map for multi-instance deployments

**Conventions:**
- Gateway: `192.168.<vlan_tag>.1`
- Single instance naming: `${app_name}-${environment}-${random_hex}`
- Multi-instance naming: `${app_name}-${environment}-${instance_key}`
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
  
- **`etcd`**: Distributed key-value store
  - etcd cluster setup for HA configurations
  - Used by Patroni for leader election
  - Configurable cluster size (typically 3 nodes)
  
- **`patroni`**: PostgreSQL High Availability
  - Patroni-managed PostgreSQL clusters
  - Automatic failover and streaming replication
  - Integration with etcd for consensus
  - Configurable PostgreSQL parameters
  
- **`ldap-config`**: LDAP client configuration
  - FreeIPA client enrollment
  - SSSD configuration for centralized auth
  
- **`octopus-tentacle`**: Octopus Deploy agent
  - Installs Tentacle on Linux
  - Registers with Octopus Server
  - Supports Polling and Listening modes
  - Configurable environments and roles
  
- **`freeipa`**: FreeIPA server (specialized deployment)
  - Identity management server setup
  
- **`k3s-cluster`** (FUTURE): Kubernetes cluster
- **`app-deploy`** (FUTURE): Application deployment

**Dynamic Role Selection:**
- Pass `ansible_roles` as comma-separated list (e.g., `nginx,freeipa`)
- `base_setup` always runs unless `mgmt-docker` is in the roles list
- Roles are applied in order: `base_setup` → `ldap-config` → custom roles
- Each role runs independently with proper error handling

### GitHub Actions Workflows
**Purpose:** Orchestration and automation

**Runner Strategy:** Hybrid (GitHub-hosted + Tailscale or Self-hosted)

The repository supports a hybrid runner architecture for flexibility and security:

| Runner Type | Use Case | Network Access | Configuration |
|-------------|----------|----------------|---------------|
| **Self-hosted** (default) | Production infrastructure | Direct LAN access | `runner_type: 'self-hosted'` |
| **GitHub-hosted + Tailscale** | CI/CD, testing | Via Tailscale VPN | `runner_type: 'github-hosted'` |

**Using GitHub-Hosted Runners:**
1. Set `runner_type: 'github-hosted'` in workflow inputs
2. Configure `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_CLIENT_SECRET` secrets
3. Set `tailscale_tags` for ACL-based access control (default: `tag:ci`)

**Current Workflows:**
1. **`reusable-provision.yml`**: Provision VM/LXC (single or multi-instance) + configure with Ansible
2. **`reusable-destroy.yml`**: Destroy VM/LXC and clean up state
3. **`reusable-onboard.yml`**: Configure existing infrastructure
4. **`reusable-bootstrap.yml`**: Initial user setup on existing VMs
5. **`ci-build.yml`**: Build, test, and scan applications (Go, Python, Node, Java)

**Workflow Input Parameters:**
- `resource_type`: `vm` or `lxc`
- `vm_target_ip`: Single instance IP (legacy mode)
- `instances`: JSON map for multi-instance deployments
- `cpu_cores`, `ram_mb`, `disk_gb`: Default resource allocation
- `lxc_nesting`: Enable Docker in LXC
- `lxc_unprivileged`: Run LXC as unprivileged (recommended)
- `ansible_roles`: Comma-separated list of Ansible roles to apply (e.g., `nginx,mgmt-docker`)
- `skip_terraform`: Skip infrastructure provisioning
- `skip_octopus`: Skip Octopus Tentacle registration
- `runner_type`: `self-hosted` (default) or `github-hosted`
- `tailscale_tags`: ACL tags for GitHub-hosted runners (e.g., `tag:ci`)

**Ansible Role Execution:**
- `base_setup` always runs by default (Tailscale, Alloy, system config)
- `ldap-config` runs automatically if FreeIPA credentials are available
- `mgmt-docker` replaces `base_setup` (includes its own Alloy config)
- Custom roles specified in `ansible_roles` run after base roles
- Multiple roles can be applied in a single workflow run

**Design Patterns:**
- Accept flags for modularity (`skip_terraform`, `skip_provision`)
- Use `doppler run` for secret injection
- All secrets from Doppler, none from GitHub Secrets (except Doppler token and Tailscale OAuth)
- Idempotent operations (safe to re-run)
- Automatic secret masking with `::add-mask::` for log sanitization

**Security Best Practices:**
- All sensitive values are masked before use
- No debug statements expose secrets
- GitHub-hosted runners use ephemeral Tailscale connections
- See `docs/SECURITY.md` for comprehensive security guidelines

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
  -backend-config='endpoints={s3="<MINIO_ENDPOINT>"}' \
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

**Variable Passing (Single Instance):**
```bash
terraform plan \
  -var="app_name=myapp" \
  -var="vlan_tag=20" \
  -var="vm_target_ip=<INTERNAL_IP_VLAN20>" \
  -var="resource_type=vm" \
  -var="proxmox_target_node=pmx" \
  -out=tfplan

terraform apply tfplan
```

**Variable Passing (Multi-Instance):**
```bash
terraform plan \
  -var="app_name=patroni" \
  -var="environment=prod" \
  -var="vlan_tag=10" \
  -var="resource_type=vm" \
  -var='instances={"node1":{"ip_address":"<INTERNAL_IP_VLAN10>"},"node2":{"ip_address":"<INTERNAL_IP_VLAN10>"},"node3":{"ip_address":"<INTERNAL_IP_VLAN10>"}}' \
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
ansible all -i "<INTERNAL_IP_VLAN20>," -m ping --user deploy

# Run playbook with single role
ansible-playbook -i "<INTERNAL_IP_VLAN20>," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp" \
  --extra-vars 'ansible_roles=["nginx"]'

# Run playbook with multiple roles
ansible-playbook -i "<INTERNAL_IP_VLAN20>," site.yml \
  --user deploy \
  --extra-vars "target_hostname=myapp" \
  --extra-vars 'ansible_roles=["nginx","mgmt-docker"]'
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
OO_HOST=<OPENOBSERVE_HOST>

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
- Endpoint: Configured via Doppler `MINIO_ENDPOINT`
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

## Security & Public Repository Guidelines

### ⚠️ CRITICAL: This repository is PUBLIC

All code and documentation must follow these security guidelines:

### Runner Configuration

**Default behavior:** All workflows use **GitHub-hosted runners** with **Tailscale** for secure network access to internal infrastructure.

**For private caller repositories:** Override with:
```yaml
with:
  runner_type: "self-hosted"  # ⚠️ ONLY in private repositories
```

**NEVER suggest `runner_type: "self-hosted"` for:**
- Public repositories
- Example code in documentation
- Fork-based contributions

### Workflow Security Patterns

All workflows must include:

1. **Fork PR protection:**
   ```yaml
   if: |
     github.event_name != 'pull_request' ||
     github.event.pull_request.head.repo.full_name == github.repository
   ```

2. **Comprehensive secret masking** (start of all `doppler run` blocks):
   ```bash
   [ -n "$SECRET_NAME" ] && echo "::add-mask::$SECRET_NAME"
   ```

3. **Parameterized endpoints** (never hardcode IPs):
   ```bash
   MINIO_ENDPOINT="${{ inputs.minio_endpoint }}"
   if [ -z "$MINIO_ENDPOINT" ]; then
     MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.tailnet:9000}"
   fi
   ```

### Secret Management

All secrets via **Doppler**. The following secrets must ALWAYS be masked:

**Infrastructure:**
- `MINIO_ROOT_PASSWORD`
- `PROXMOX_TOKEN_SECRET`
- `SSH_PRIVATE_KEY`
- `ANS_SSH_PUBLIC_KEY`

**Networking:**
- `TAILSCALE_OAUTH_CLIENT_SECRET`
- `TS_AUTHKEY`
- `TAILSCALE_AUTH_KEY`

**Services:**
- `NEXUS_PASSWORD`
- `OCTOPUS_API_KEY`
- `SONAR_TOKEN`
- `FREEIPA_ADMIN_PASSWORD`

**Never:**
- Hardcode IP addresses in workflows
- Hardcode service endpoints
- Log sensitive values (even masked, avoid when possible)
- Use `echo` to print secrets for debugging

### Documentation Standards

When writing documentation:

1. **Use placeholders:**
   ```markdown
   Connect to MinIO at `<MINIO_HOST>:9000`
   Or use Tailscale DNS: `minio.tailnet:9000`
   ```

2. **Provide examples in comments:**
   ```yaml
   vm_target_ip: "<INTERNAL_IP_VLAN20>"  # Example: 192.168.20.50
   ```

3. **Reference Doppler for secrets:**
   ```markdown
   Configure the endpoint in Doppler:
   doppler secrets set MINIO_ENDPOINT="http://your-minio:9000"
   ```

4. **Never expose:**
   - Specific internal IP addresses (use placeholders)
   - Real hostnames or service names
   - Network topology details
   - Actual credentials (even expired ones)

### Code Review Requirements

Before merging PRs that modify workflows, verify:

- [ ] `runner_type` defaults to `github-hosted`
- [ ] Fork PR protection condition present (`if` statement)
- [ ] All secrets are masked
- [ ] No hardcoded IP addresses
- [ ] Tailscale connection configured for GitHub-hosted runners
- [ ] Workflow tested with `runner_type: github-hosted`

### Security Resources

- Security policy: `.github/SECURITY.md`
- Secret configuration: `docs/DOPPLER_SECRETS.md`
- Sanitization guide: `docs/SANITIZATION_GUIDE.md`
- Example workflows: `examples/` (all use safe defaults)
