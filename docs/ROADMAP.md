# Implementation Roadmap

## Overview

This roadmap outlines the path from current state (Phase 1 - Infrastructure Provisioning) to complete CI/CD pipeline (Phase 5). Each phase builds on the previous, adding new capabilities while maintaining backward compatibility.

**Current Status:** Phase 1 Complete ✓

## Phase 1: Infrastructure Provisioning & Configuration ✓

**Status:** Complete
**Duration:** Completed
**Goal:** Provision and configure VMs with observability

### Completed Features

- [x] VM provisioning via Terraform + Proxmox
- [x] VM destruction with safety checks
- [x] Existing infrastructure onboarding
- [x] Bootstrap workflow for initial user setup
- [x] Ansible configuration management
- [x] Doppler secret management integration
- [x] MinIO S3 backend for Terraform state
- [x] Tailscale mesh networking
- [x] Grafana Alloy observability
- [x] OpenObserve integration
- [x] Docker host monitoring role
- [x] Self-hosted runner setup documentation

### Deliverables

- `reusable-provision.yml` - VM provisioning workflow
- `reusable-destroy.yml` - VM destruction workflow
- `reusable-onboard.yml` - Existing infrastructure workflow
- `reusable-bootstrap.yml` - Initial user setup workflow
- `base_setup` Ansible role
- `mgmt-docker` Ansible role
- `nginx` Ansible role
- Documentation: `USAGE.md`, `RUNNER_SETUP.md`, `TROUBLESHOOTING.md`

## Phase 2: Octopus Deploy Integration

**Status:** Not Started
**Estimated Duration:** 2-3 weeks
**Goal:** Register all infrastructure as Octopus deployment targets

### Objectives

1. Install and configure Octopus Tentacle on all VMs/LXCs
2. Register targets with Octopus Server via API
3. Tag targets with environments (dev, staging, prod)
4. Enable deployment orchestration via Octopus

### Tasks

#### Week 1: Octopus Tentacle Role
- [ ] Create `octopus-tentacle` Ansible role
  - [ ] Install Tentacle package
  - [ ] Configure Tentacle (polling or listening mode)
  - [ ] Register with Octopus Server
  - [ ] Set environment tags
  - [ ] Configure roles/tags for targeting
- [ ] Add Octopus secrets to Doppler
  - [ ] `OCTOPUS_SERVER_URL`
  - [ ] `OCTOPUS_API_KEY`
  - [ ] `OCTOPUS_SPACE_ID`
  - [ ] `OCTOPUS_ENVIRONMENT` (per deployment)
- [ ] Test role on standalone VM

#### Week 2: Workflow Integration
- [ ] Add Octopus registration to `reusable-provision.yml`
  - [ ] Run `octopus-tentacle` role after `base_setup`
  - [ ] Pass environment from workflow input
  - [ ] Verify registration via API
- [ ] Add Octopus registration to `reusable-onboard.yml`
  - [ ] Same as provision workflow
- [ ] Create optional `skip_octopus` flag
- [ ] Test end-to-end provisioning with Octopus

#### Week 3: API Integration & Testing
- [ ] Create Go CLI tool for Octopus API operations
  - [ ] Register deployment target
  - [ ] Update target tags
  - [ ] Trigger deployment
  - [ ] Check deployment status
- [ ] Add composite action for Octopus operations
  - [ ] `register-octopus-target`
  - [ ] `trigger-octopus-deployment`
- [ ] Create example deployment project in Octopus
- [ ] Document Octopus integration in `USAGE.md`
- [ ] Update `ARCHITECTURE.md` with Octopus flow

### Success Criteria

- All provisioned VMs automatically registered in Octopus
- Targets correctly tagged with environment
- Manual deployment from Octopus works
- Existing VMs can be onboarded to Octopus
- Documentation complete

### Dependencies

- Octopus Server must be accessible from runner
- Octopus API key with appropriate permissions
- Network connectivity from VMs to Octopus (Tailscale)

## Phase 3: LXC Container Support

**Status:** Not Started
**Estimated Duration:** 3-4 weeks
**Goal:** Provision and manage LXC containers alongside VMs

### Objectives

1. Create Terraform module for Proxmox LXC
2. Build LXC provisioning workflow
3. Adapt Ansible roles for containers
4. Integrate with Octopus Deploy

### Tasks

#### Week 1: Terraform LXC Module
- [ ] Create `terraform/lxc.tf` for LXC resources
- [ ] Define LXC-specific variables
  - [ ] Template (e.g., `ubuntu-2404-lxc`)
  - [ ] Privileged vs unprivileged
  - [ ] Resource limits (CPU, RAM, disk)
  - [ ] Network configuration
- [ ] Test LXC creation and destruction
- [ ] Document LXC Terraform usage

#### Week 2: LXC Provisioning Workflow
- [ ] Create `reusable-provision-lxc.yml`
  - [ ] Similar structure to VM workflow
  - [ ] LXC-specific parameters
  - [ ] Faster provisioning (no cloud-init wait)
- [ ] Adapt Ansible for LXC
  - [ ] Detect container environment
  - [ ] Skip VM-specific tasks (QEMU guest agent)
  - [ ] Container-optimized configurations
- [ ] Test LXC provisioning end-to-end

#### Week 3: LXC-Specific Roles
- [ ] Create `lxc-setup` role (lightweight `base_setup`)
  - [ ] Tailscale installation
  - [ ] Alloy observability
  - [ ] Skip unnecessary services
- [ ] Test Octopus Tentacle in LXC
- [ ] Optimize for container environment

#### Week 4: Integration & Documentation
- [ ] Add LXC examples to `examples/`
- [ ] Document LXC provisioning in `USAGE.md`
- [ ] Update `ARCHITECTURE.md` with LXC support
- [ ] Create LXC troubleshooting guide
- [ ] Performance comparison: VM vs LXC

### Success Criteria

- LXC containers provision in < 2 minutes
- Ansible roles work in both VMs and LXCs
- LXCs register with Octopus Deploy
- Observability works in containers
- Documentation complete

### Dependencies

- Proxmox LXC templates created
- Terraform Proxmox provider supports LXC
- Network configuration for containers

## Phase 4: Kubernetes & Docker Application Deployment

**Status:** Not Started
**Estimated Duration:** 4-6 weeks
**Goal:** Deploy containerized applications to K8s clusters and Docker hosts

### Objectives

1. Multi-node K3s cluster provisioning
2. Kubernetes application deployment workflow
3. Docker application deployment workflow
4. Nexus integration for images and charts

### Tasks

#### Week 1-2: K3s Cluster Setup
- [ ] Expand `k3s` Ansible role to `k3s-cluster`
  - [ ] Multi-node support (control plane + workers)
  - [ ] HA control plane (3+ nodes)
  - [ ] Embedded etcd or external datastore
  - [ ] Kubeconfig generation and storage
- [ ] Storage configuration
  - [ ] Longhorn for distributed storage
  - [ ] NFS for shared storage
  - [ ] Local path provisioner
- [ ] Ingress configuration
  - [ ] Traefik (K3s default) or Nginx Ingress
  - [ ] Tailscale integration for ingress
  - [ ] TLS certificate management
- [ ] Test multi-node cluster provisioning

#### Week 3: Kubernetes Deployment Workflow
- [ ] Create `reusable-deploy-k8s.yml`
  - [ ] Accept kubeconfig or cluster name
  - [ ] Deploy via kubectl or Helm
  - [ ] Support for manifests, Kustomize, Helm charts
  - [ ] Health checks and rollback
- [ ] Create composite actions
  - [ ] `deploy-k8s-manifest`
  - [ ] `deploy-helm-chart`
  - [ ] `k8s-health-check`
- [ ] Integrate with Nexus for image pulls
  - [ ] Configure image pull secrets
  - [ ] Pull from Nexus Docker registry
- [ ] Test application deployment

#### Week 4: Docker Deployment Workflow
- [ ] Create `reusable-deploy-docker.yml`
  - [ ] Deploy via Docker CLI
  - [ ] Docker Compose support
  - [ ] Container health checks
  - [ ] Log collection setup
- [ ] Create composite actions
  - [ ] `deploy-docker-container`
  - [ ] `deploy-docker-compose`
  - [ ] `docker-health-check`
- [ ] Integrate with Nexus registry
- [ ] Test on `mgmt-docker` hosts

#### Week 5: Nexus Integration
- [ ] Configure Nexus Docker registry
  - [ ] Create hosted Docker repository
  - [ ] Configure Tailscale access
  - [ ] Set up authentication
- [ ] Configure Nexus Helm repository
  - [ ] Create hosted Helm repository
  - [ ] Configure chart uploads
- [ ] Add Nexus secrets to Doppler
  - [ ] `NEXUS_URL`
  - [ ] `NEXUS_USERNAME`
  - [ ] `NEXUS_PASSWORD`
  - [ ] `NEXUS_DOCKER_REGISTRY`
- [ ] Test image push/pull workflow

#### Week 6: Integration & Testing
- [ ] End-to-end testing
  - [ ] Provision K3s cluster
  - [ ] Deploy sample application
  - [ ] Verify observability
  - [ ] Test rollback
- [ ] Document K8s deployment in `USAGE.md`
- [ ] Document Docker deployment in `USAGE.md`
- [ ] Create deployment examples
- [ ] Update `ARCHITECTURE.md`

### Success Criteria

- Multi-node K3s cluster provisions successfully
- Applications deploy to K8s via workflow
- Applications deploy to Docker hosts via workflow
- Images pulled from Nexus registry
- Helm charts pulled from Nexus
- Health checks and rollback work
- Documentation complete

### Dependencies

- Nexus Repository configured and accessible
- Sufficient resources for K3s clusters
- Network connectivity via Tailscale
- Octopus Deploy integration (Phase 2)

## Phase 5: Complete CI/CD Pipeline

**Status:** Not Started
**Estimated Duration:** 6-8 weeks
**Goal:** End-to-end CI/CD from commit to deployed application

### Objectives

1. Build reusable CI composite actions
2. Create CI workflow for building and testing
3. Integrate artifact publishing to Nexus
4. Create full pipeline workflow
5. Add security scanning and quality gates

### Tasks

#### Week 1-2: CI Composite Actions
- [ ] Create `build-go-app` action
  - [ ] Go build with version injection
  - [ ] Cross-compilation support
  - [ ] Binary artifact creation
- [ ] Create `build-docker-image` action
  - [ ] Multi-stage Docker builds
  - [ ] Build args for versioning
  - [ ] Push to Nexus registry
  - [ ] Multi-arch support
- [ ] Create `test-app` action
  - [ ] Run unit tests
  - [ ] Generate coverage reports
  - [ ] Upload test results
- [ ] Create `security-scan` action
  - [ ] Trivy for container scanning
  - [ ] Grype for vulnerability scanning
  - [ ] SAST tools integration
- [ ] Create `publish-artifact` action
  - [ ] Push to Nexus (generic, Docker, Helm)
  - [ ] Versioning and tagging
  - [ ] Metadata generation

#### Week 3-4: CI Workflow
- [ ] Create `reusable-ci.yml`
  - [ ] Checkout code
  - [ ] Build application
  - [ ] Run tests
  - [ ] Security scanning
  - [ ] Build container image
  - [ ] Push to Nexus
  - [ ] Create Octopus release
- [ ] Add quality gates
  - [ ] Test coverage threshold
  - [ ] Security scan pass/fail
  - [ ] Build success required
- [ ] Integrate with GitHub status checks
- [ ] Test with sample applications

#### Week 5: CD Workflow Integration
- [ ] Create `reusable-cd.yml`
  - [ ] Trigger Octopus deployment
  - [ ] Wait for deployment completion
  - [ ] Run post-deployment Ansible
  - [ ] Verify deployment health
- [ ] Create Go CLI for Octopus operations
  - [ ] Create release
  - [ ] Deploy release
  - [ ] Check deployment status
  - [ ] Get deployment logs
- [ ] Add deployment notifications
- [ ] Test CD workflow

#### Week 6: Full Pipeline Workflow
- [ ] Create `reusable-full-pipeline.yml`
  - [ ] Provision infrastructure (optional)
  - [ ] Run CI workflow
  - [ ] Run CD workflow
  - [ ] Post-deployment configuration
  - [ ] Observability setup
- [ ] Add pipeline orchestration logic
  - [ ] Conditional steps
  - [ ] Parallel execution where possible
  - [ ] Error handling and rollback
- [ ] Test full pipeline end-to-end

#### Week 7: Go CLI Tools
- [ ] Create `nante-cli` Go application
  - [ ] Octopus operations
  - [ ] Nexus operations
  - [ ] Terraform helpers
  - [ ] Ansible helpers
- [ ] Package as binary for runner
- [ ] Add to composite actions
- [ ] Document CLI usage

#### Week 8: Documentation & Polish
- [ ] Complete `USAGE.md` with all workflows
- [ ] Update `ARCHITECTURE.md` with full pipeline
- [ ] Create comprehensive examples
  - [ ] Go application example
  - [ ] Docker application example
  - [ ] Kubernetes application example
- [ ] Create troubleshooting guides
- [ ] Add CI/CD best practices documentation
- [ ] Create video tutorials (optional)

### Success Criteria

- Application commits trigger CI automatically
- CI builds, tests, scans, and publishes to Nexus
- CD deploys from Nexus via Octopus
- Full pipeline completes in < 10 minutes
- Rollback works correctly
- All workflows documented
- Example applications provided

### Dependencies

- All previous phases complete
- Nexus Repository fully configured
- Octopus Deploy fully configured
- Sufficient runner resources
- Go development environment

## Post-Phase 5: Continuous Improvement

### Potential Enhancements

**Observability:**
- [ ] Distributed tracing (Tempo)
- [ ] Application metrics (Prometheus exporters)
- [ ] Custom dashboards in Grafana
- [ ] Alerting rules and notifications

**Security:**
- [ ] Policy enforcement (OPA)
- [ ] Secret rotation automation
- [ ] Compliance scanning
- [ ] Audit logging

**Performance:**
- [ ] Workflow caching strategies
- [ ] Parallel execution optimization
- [ ] Resource usage optimization
- [ ] Build time reduction

**Developer Experience:**
- [ ] CLI for common operations
- [ ] Local development environment
- [ ] Preview environments
- [ ] Self-service portals

**Advanced Features:**
- [ ] Blue-green deployments
- [ ] Canary deployments
- [ ] A/B testing support
- [ ] Feature flags integration
- [ ] Database migration automation
- [ ] Backup and disaster recovery

## Timeline Summary

| Phase | Duration | Start | End | Status |
|-------|----------|-------|-----|--------|
| Phase 1 | Completed | - | - | ✓ Complete |
| Phase 2 | 2-3 weeks | TBD | TBD | Not Started |
| Phase 3 | 3-4 weeks | TBD | TBD | Not Started |
| Phase 4 | 4-6 weeks | TBD | TBD | Not Started |
| Phase 5 | 6-8 weeks | TBD | TBD | Not Started |
| **Total** | **15-21 weeks** | - | - | - |

**Estimated Completion:** 4-5 months from Phase 2 start

## Resource Requirements

**Infrastructure:**
- Proxmox cluster with sufficient resources
- MinIO for Terraform state (current)
- Octopus Deploy server (current)
- Nexus Repository server (current)
- OpenObserve for observability (current)
- Self-hosted GitHub Actions runners (current)

**Development:**
- Go development environment
- Terraform knowledge
- Ansible knowledge
- Kubernetes knowledge
- Docker knowledge
- GitHub Actions expertise

**Testing:**
- Test VMs/LXCs for validation
- Sample applications for testing
- Monitoring and logging setup

## Risk Mitigation

**Technical Risks:**
- **Complexity:** Break down into small, testable increments
- **Integration Issues:** Test integrations early and often
- **Performance:** Monitor and optimize continuously
- **Breaking Changes:** Maintain backward compatibility

**Operational Risks:**
- **Resource Constraints:** Prioritize critical features
- **Knowledge Gaps:** Document everything thoroughly
- **Dependency Issues:** Have fallback plans
- **Security:** Security reviews at each phase

## Success Metrics

**Phase 2:**
- 100% of VMs registered in Octopus
- < 1 minute registration time

**Phase 3:**
- LXC provision time < 2 minutes
- 50% resource savings vs VMs

**Phase 4:**
- K8s cluster provision < 10 minutes
- Application deploy < 3 minutes

**Phase 5:**
- Full pipeline < 10 minutes
- 95%+ success rate
- Zero manual steps required

## Next Steps

1. Review and approve roadmap
2. Set up Phase 2 project tracking
3. Allocate resources for Phase 2
4. Begin Octopus Tentacle role development
5. Schedule regular progress reviews
