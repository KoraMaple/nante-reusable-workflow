# Architecture Overview

## Current State (Phase 1 - Complete)

### Infrastructure Provisioning & Configuration

**Completed Components:**

1. **VM Provisioning (Terraform + Proxmox)**
   - Reusable workflow: `reusable-provision.yml`
   - Creates VMs on Proxmox with cloud-init
   - Configurable: CPU, RAM, disk, VLAN, storage, node
   - State management: MinIO S3 backend with workspaces per app
   - Optional `skip_terraform` flag for existing VMs

2. **VM Destruction (Terraform)**
   - Reusable workflow: `reusable-destroy.yml`
   - Safely destroys VMs with confirmation flag
   - Cleans up Terraform state

3. **Existing Infrastructure Onboarding**
   - Reusable workflow: `reusable-onboard.yml`
   - Configures existing VMs/servers without Terraform
   - Bootstrap workflow: `reusable-bootstrap.yml` for initial user setup

4. **Configuration Management (Ansible)**
   - Base setup role: Tailscale, Alloy observability, system config
   - Application roles: `nginx`, `mgmt-docker`
   - Dynamic role selection via `app_role_name` parameter

5. **Secret Management (Doppler)**
   - Centralized secrets via Doppler CLI
   - `doppler run` for secret injection
   - Project/config based secret organization

6. **Observability (Grafana Alloy + OpenObserve)**
   - System metrics (node_exporter)
   - System logs
   - Docker container metrics and logs (mgmt-docker role)
   - Centralized to OpenObserve

7. **Networking (Tailscale)**
   - All infrastructure joins Tailscale mesh
   - Services exposed only via Tailnet
   - No public ingress required

## Future State (Phase 2-4)

### Phase 2: Octopus Deploy Integration

**Goal:** Register all provisioned infrastructure with Octopus Deploy for application deployment orchestration.

**Components to Build:**

1. **Octopus Tentacle Installation Role**
   - Ansible role: `octopus-tentacle`
   - Installs Tentacle agent on VMs/LXCs
   - Registers with Octopus Server
   - Configures environments (dev, staging, prod)
   - Tags targets appropriately

2. **Octopus Registration Workflow**
   - Add step to `reusable-provision.yml`
   - Add step to `reusable-onboard.yml`
   - Register VM/LXC as deployment target
   - API integration with Octopus Server

3. **Octopus Secrets in Doppler**
   - `OCTOPUS_SERVER_URL`
   - `OCTOPUS_API_KEY`
   - `OCTOPUS_SPACE_ID`
   - `OCTOPUS_ENVIRONMENT` (per deployment)

### Phase 3: LXC Container Support

**Goal:** Provision and manage LXC containers alongside VMs.

**Components to Build:**

1. **LXC Terraform Module**
   - New Terraform resources for Proxmox LXC
   - Template-based provisioning
   - Network configuration
   - Resource limits (CPU, RAM, disk)

2. **LXC Provisioning Workflow**
   - `reusable-provision-lxc.yml`
   - Similar to VM workflow but for containers
   - Lighter weight, faster provisioning
   - Cloud-init or custom init scripts

3. **LXC-Specific Ansible Roles**
   - Adapt `base_setup` for containers
   - Container-optimized configurations
   - Skip VM-specific tasks (QEMU guest agent)

### Phase 4: Kubernetes & Docker Application Deployment

**Goal:** Deploy containerized applications to K8s clusters or Docker hosts.

**Components to Build:**

1. **Kubernetes Cluster Setup**
   - Ansible role: `k3s-cluster` (expand existing `k3s`)
   - Multi-node cluster provisioning
   - HA control plane support
   - Storage class configuration (Longhorn, NFS)

2. **Application Deployment Workflows**
   - `reusable-deploy-k8s.yml` - Deploy to Kubernetes
   - `reusable-deploy-docker.yml` - Deploy to Docker host
   - Helm chart support
   - Docker Compose support

3. **Nexus Integration**
   - Pull container images from Nexus registry
   - Pull Helm charts from Nexus
   - Authentication via Doppler secrets

### Phase 5: Complete CI/CD Pipeline

**Goal:** Build, test, package, and deploy applications end-to-end.

**Components to Build:**

1. **Reusable CI Composite Actions**
   - `build-go-app` - Build Go applications
   - `build-docker-image` - Build and push to Nexus
   - `test-app` - Run tests
   - `security-scan` - Trivy/Grype scanning
   - `publish-artifact` - Push to Nexus

2. **CI Workflow**
   - `reusable-ci.yml`
   - Build application
   - Run tests
   - Build container image
   - Push to Nexus registry
   - Create Octopus release

3. **CD Workflow (Octopus-Driven)**
   - Octopus pulls artifacts from Nexus
   - Deploys to targets registered in Phase 2
   - Ansible for configuration (users, directories, SSL)
   - Health checks and rollback support

4. **Full Pipeline Workflow**
   - `reusable-full-pipeline.yml`
   - Provision infrastructure (if needed)
   - Build application (CI)
   - Deploy application (CD via Octopus)
   - Configure with Ansible
   - Register with observability

## Data Flow

### Current (Phase 1)
```
GitHub Actions (self-hosted runner)
  ↓ (doppler run)
Terraform → Proxmox → VM Created
  ↓
Ansible → VM Configured
  ↓
Tailscale → VM Joined Mesh
  ↓
Alloy → Metrics/Logs → OpenObserve
```

### Future (Phase 5)
```
Application Repo
  ↓
CI Workflow (build, test, scan)
  ↓
Nexus (artifacts, images, charts)
  ↓
Octopus Deploy (release created)
  ↓
Infrastructure Provisioning (if needed)
  ↓ (Terraform + Ansible)
Proxmox (VM/LXC) + Octopus Tentacle
  ↓
Octopus Deployment
  ↓ (pulls from Nexus)
Application Deployed
  ↓
Ansible (post-deploy config)
  ↓
Observability (Alloy → OpenObserve)
```

## Technology Stack

### Current
- **IaC:** Terraform (Proxmox provider)
- **Config Mgmt:** Ansible
- **Orchestration:** GitHub Actions (self-hosted)
- **Secrets:** Doppler
- **State:** MinIO (S3-compatible)
- **Networking:** Tailscale
- **Observability:** Grafana Alloy + OpenObserve
- **Hypervisor:** Proxmox VE

### Future Additions
- **CD Platform:** Octopus Deploy (self-hosted)
- **Artifact Repo:** Nexus Repository (self-hosted)
- **Container Runtime:** Docker, Kubernetes (K3s)
- **Container Registry:** Nexus (Docker registry)
- **Helm Repository:** Nexus (Helm charts)
- **Scripting:** Go (for glue code and CLI tools)

## Design Principles

1. **Modularity:** Each workflow can be called independently
2. **Composability:** Workflows are building blocks, not monoliths
3. **Reusability:** One workflow repo, many application repos
4. **Security:** Secrets via Doppler, no hardcoded credentials
5. **Observability:** All infrastructure monitored by default
6. **Network Isolation:** Tailscale mesh, no public exposure
7. **State Management:** Terraform workspaces per application
8. **Idempotency:** Safe to re-run workflows
9. **Flexibility:** Support existing infrastructure and new provisioning
10. **Go-First:** Complex logic in Go, not Bash/Python

## Repository Structure

```
nante-reusable-workflow/
├── .github/
│   ├── workflows/
│   │   ├── reusable-provision.yml       # VM provisioning
│   │   ├── reusable-destroy.yml         # VM destruction
│   │   ├── reusable-onboard.yml         # Existing infra
│   │   ├── reusable-bootstrap.yml       # Initial user setup
│   │   ├── reusable-provision-lxc.yml   # [FUTURE] LXC provisioning
│   │   ├── reusable-ci.yml              # [FUTURE] Build & test
│   │   ├── reusable-deploy-k8s.yml      # [FUTURE] K8s deployment
│   │   └── reusable-deploy-docker.yml   # [FUTURE] Docker deployment
│   ├── actions/
│   │   ├── build-go-app/                # [FUTURE] Go build action
│   │   ├── build-docker-image/          # [FUTURE] Docker build action
│   │   ├── publish-nexus/               # [FUTURE] Nexus publish action
│   │   └── register-octopus/            # [FUTURE] Octopus registration
│   └── copilot-instructions.md
├── terraform/
│   ├── main.tf                          # VM resources
│   ├── variables.tf
│   ├── lxc.tf                           # [FUTURE] LXC resources
│   └── modules/
│       ├── vm/                          # [FUTURE] VM module
│       └── lxc/                         # [FUTURE] LXC module
├── ansible/
│   ├── site.yml
│   ├── bootstrap.yml
│   ├── requirements.yml
│   └── roles/
│       ├── base_setup/                  # Core setup (all nodes)
│       ├── mgmt-docker/                 # Docker monitoring
│       ├── nginx/                       # Nginx web server
│       ├── octopus-tentacle/            # [FUTURE] Octopus agent
│       ├── k3s-cluster/                 # [FUTURE] K8s cluster
│       └── app-deploy/                  # [FUTURE] App deployment
├── tools/
│   └── [FUTURE] Go CLI tools
├── examples/                            # Caller workflow examples
├── docs/
│   └── TROUBLESHOOTING.md
├── ARCHITECTURE.md                      # This file
├── USAGE.md
├── RUNNER_SETUP.md
└── README.md
```

## Integration Points

### Doppler Secrets Organization

**Current:**
- `PROXMOX_API_URL`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET`
- `ANS_SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY`
- `TS_AUTHKEY` (Tailscale)
- `OO_HOST`, `OO_USER`, `OO_PASS` (OpenObserve)
- `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`
- `DOPPLER_TOKEN`, `DOPPLER_TARGET_PROJECT`, `DOPPLER_TARGET_CONFIG`
- `GH_PAT`

**Future:**
- `OCTOPUS_SERVER_URL`, `OCTOPUS_API_KEY`, `OCTOPUS_SPACE_ID`
- `NEXUS_URL`, `NEXUS_USERNAME`, `NEXUS_PASSWORD`
- `NEXUS_DOCKER_REGISTRY` (e.g., `nexus.tailnet:5000`)
- `K8S_KUBECONFIG` (per cluster)

### Network Architecture

**Tailscale Mesh:**
- All VMs/LXCs join Tailscale on provisioning
- Services accessible via Tailscale DNS
- No port forwarding or public IPs needed

**VLANs:**
- VLAN 20: Management/Infrastructure
- VLAN 30: Development
- VLAN 40: Staging
- VLAN 50: Production

**DNS Strategy:**
- Tailscale MagicDNS for internal services
- Custom DNS for application domains (via Tailscale)

## Next Steps (Implementation Order)

### Immediate (Phase 2)
1. Create `octopus-tentacle` Ansible role
2. Add Octopus registration to provision workflow
3. Test VM → Octopus → Deploy flow
4. Document Octopus integration

### Short-term (Phase 3)
1. Create LXC Terraform module
2. Build `reusable-provision-lxc.yml`
3. Adapt Ansible roles for containers
4. Test LXC provisioning and configuration

### Medium-term (Phase 4)
1. Expand K3s cluster role (multi-node, HA)
2. Create K8s deployment workflow
3. Create Docker deployment workflow
4. Integrate Nexus for image pulls

### Long-term (Phase 5)
1. Build reusable CI composite actions
2. Create `reusable-ci.yml` workflow
3. Integrate Nexus artifact publishing
4. Build full pipeline workflow
5. Create Go CLI tools for complex operations
6. Add security scanning (Trivy, Grype)
7. Implement automated testing in CI
8. Add deployment health checks and rollback

## Success Metrics

- **Provisioning Time:** < 5 minutes for VM, < 2 minutes for LXC
- **Deployment Time:** < 3 minutes from commit to deployed
- **Observability:** 100% of infrastructure monitored
- **Security:** Zero hardcoded secrets, all via Doppler
- **Reliability:** Idempotent workflows, safe to re-run
- **Modularity:** Each workflow usable independently
- **Documentation:** Every workflow has usage examples
