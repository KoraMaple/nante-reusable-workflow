# Nante-reusable-workflows

Modular CI/CD pipeline for self-hosted infrastructure provisioning, configuration, and application deployment on Proxmox.

## Overview

This repository provides reusable GitHub Actions workflows for:
- **Infrastructure Provisioning:** VMs and LXCs on Proxmox via Terraform
- **Configuration Management:** Ansible-based setup with observability
- **Application Deployment:** Kubernetes and Docker deployments (future)
- **CI/CD Pipeline:** Build, test, and deploy applications (future)

## Current Status

**Phase 1 Complete (v0.9.0):**
- VM provisioning and destruction
- Existing infrastructure onboarding
- Doppler secret management
- Tailscale mesh networking
- Grafana Alloy observability
- Docker host monitoring

**Phase 2 Complete (v1.0.0):**
- Octopus Deploy integration
- Deployment target registration
- Tailscale Terraform provider
- Automatic device cleanup
- Octopus cleanup automation

## Quick Links

- **[USAGE.md](./USAGE.md)** - How to use the workflows
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - System design and data flow
- **[ROADMAP.md](./ROADMAP.md)** - Implementation plan (Phases 3-5)
- **[RUNNER_SETUP.md](./RUNNER_SETUP.md)** - Self-hosted runner configuration
- **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Common issues and solutions

## Technology Stack

- **IaC:** Terraform (Proxmox provider)
- **Config Mgmt:** Ansible
- **Secrets:** Doppler
- **State:** MinIO (S3-compatible)
- **Networking:** Tailscale
- **Observability:** Grafana Alloy + OpenObserve
- **CI/CD:** GitHub Actions + Octopus Deploy (future)
- **Artifacts:** Nexus Repository (future)

## Example Usage

### Provision a VM

```yaml
jobs:
  provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    with:
      app_name: "nginx"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.50"
      cpu_cores: "2"
      ram_mb: "2048"
      disk_gb: "20G"
    secrets: inherit
```

### Onboard Existing Infrastructure

```yaml
jobs:
  onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@develop
    with:
      target_ip: "192.168.20.100"
      ssh_user: "deploy"
      target_hostname: "docker-mgmt"
      app_role: "mgmt-docker"
    secrets: inherit
```

See [examples/](./examples/) for more usage patterns.

## Contributing

This is a personal homelab project, but suggestions and improvements are welcome via issues.

## License

MIT License - See [LICENSE](./LICENSE) for details.
