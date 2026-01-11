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

### Build and Test Applications (CI)

```yaml
jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@develop
    with:
      app_name: "my-go-app"
      language: "go"
      language_version: "1.22"
      build_tool: "make"
    secrets: inherit
```

See [examples/](./examples/) for more usage patterns.

## Available Workflows

### Infrastructure Management
- **[reusable-provision.yml](.github/workflows/reusable-provision.yml)** - Provision VMs/LXCs with Terraform + Ansible
- **[reusable-destroy.yml](.github/workflows/reusable-destroy.yml)** - Destroy VMs/LXCs and clean up
- **[reusable-onboard.yml](.github/workflows/reusable-onboard.yml)** - Configure existing infrastructure
- **[reusable-bootstrap.yml](.github/workflows/reusable-bootstrap.yml)** - Initial user setup

### CI/CD
- **[ci-build.yml](.github/workflows/ci-build.yml)** - Build, test, and scan applications (Go, Python, Node, Java)

## CI Workflow Features

The CI workflow supports:
- ✅ **Multi-language support**: Go, Python, Node.js, Java
- ✅ **Flexible build tools**: make, gradle, maven, npm, yarn, pnpm, poetry, pipenv
- ✅ **Automated testing**: Language-specific test runners with coverage
- ✅ **Code quality**: SonarQube integration for static analysis
- ✅ **Artifact management**: Nexus repository uploads
- ✅ **Secret management**: Doppler integration via `secrets: inherit`

Supported languages and defaults:
- **Go** (1.22, make/go build)
- **Python** (3.11, pip/poetry/pipenv)
- **Node.js** (20, npm/yarn/pnpm)
- **Java** (17, maven/gradle)

### CI Workflow Examples

#### Go Application with Make
```yaml
name: Application CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-go-app"
      language: "go"
      language_version: "1.22"
      build_tool: "make"
    secrets: inherit
```

#### Python Application with Poetry
```yaml
jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-python-service"
      language: "python"
      language_version: "3.11"
      build_tool: "poetry"
      run_sonar_scan: true
    secrets: inherit
```

#### Node.js Application with Yarn
```yaml
jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-node-api"
      language: "node"
      language_version: "20"
      build_tool: "yarn"
    secrets: inherit
```

#### Java Application with Gradle
```yaml
jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-java-service"
      language: "java"
      language_version: "17"
      build_tool: "gradle"
      skip_nexus_upload: false
    secrets: inherit
```

### CI Workflow Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `app_name` | ✅ | - | Application name for artifacts |
| `language` | ✅ | - | Programming language (go, python, node, java) |
| `build_tool` | ❌ | Language default | Build tool to use |
| `language_version` | ❌ | Latest stable | Language version |
| `working_directory` | ❌ | `.` | Directory to run builds in |
| `run_tests` | ❌ | `true` | Execute test suite |
| `run_sonar_scan` | ❌ | `true` | Run SonarQube analysis |
| `artifact_type` | ❌ | - | Artifact type hint |
| `skip_nexus_upload` | ❌ | `false` | Skip Nexus upload |

### Required Secrets

The workflow uses `secrets: inherit` pattern. Ensure your calling repository has:
- `DOPPLER_TOKEN`: For fetching secrets from Doppler
- `DOPPLER_TARGET_PROJECT`: Doppler project name
- `DOPPLER_TARGET_CONFIG`: Doppler config name (dev, staging, prod)

Your Doppler configuration should contain (all optional):
- `NEXUS_URL`: Nexus repository URL (e.g., `http://nexus.example.com:8081`)
- `NEXUS_USERNAME`: Nexus authentication username
- `NEXUS_PASSWORD`: Nexus authentication password
- `SONAR_URL`: SonarQube server URL (e.g., `http://sonar.example.com:9000`)
- `SONAR_TOKEN`: SonarQube authentication token

**Note**: If Nexus or SonarQube credentials are not configured in Doppler, those steps will be automatically skipped with a warning.

### Chaining CI with Other Workflows

```yaml
jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-app"
      language: "go"
    secrets: inherit

  provision:
    needs: ci
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
    with:
      app_name: "my-app"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.50"
      cpu_cores: "2"
      ram_mb: "4096"
      disk_gb: "20G"
    secrets: inherit
```

## Contributing

This is a personal homelab project, but suggestions and improvements are welcome via issues.

## License

MIT License - See [LICENSE](./LICENSE) for details.
