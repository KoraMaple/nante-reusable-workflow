# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Reusable CI/CD build workflow supporting Go, Python, Node.js, and Java
- Doppler integration for centralized secret management
- SonarQube code scanning integration with coverage reports
- Nexus artifact repository upload with versioned artifacts
- Language-specific wrapper workflows (ci-go.yml, ci-python.yml, ci-node.yml, ci-java.yml)
- Comprehensive CI workflow documentation in README.md
- Support for multiple build tools per language (make, maven, gradle, npm, yarn, pnpm, poetry, pipenv)
- Automatic language environment setup with caching
- Conditional test execution and linting
- Language-specific coverage report generation

### Features
- ✅ Multi-language CI/CD support (Go, Python, Node.js, Java)
- ✅ Doppler-based secret management for NEXUS and SONAR credentials
- ✅ SonarQube integration with test coverage
- ✅ Nexus artifact upload with SHA-based versioning
- ✅ Modular workflow design (can skip tests, SonarQube, or Nexus upload)
- ✅ Self-hosted runner compatible for Tailscale network access
- ✅ Language-specific dependency caching for faster builds
- ✅ Linting support for all languages

### Documentation
- README.md – Added comprehensive CI workflow documentation with examples
- USAGE.md – Updated with CI workflow usage examples and Doppler setup guide

## [0.1.0-alpha] – 2025-01-22

### Added
- Initial reusable workflow for VM provisioning via Terraform
- Ansible playbooks for OS bootstrapping with Tailscale integration
- Go-based deployer CLI tool for workspace management and Terraform orchestration
- Support for dynamic application roles (users create roles matching `app_name`)
- Grafana Alloy metrics collection via OpenObserve (Prometheus metrics)
- Grafana Alloy log forwarding to OpenObserve (Loki API)
- VM destruction workflow with safety confirmation
- Terraform workspace isolation per application

### Features
- ✅ Modular provisioning and configuration workflows
- ✅ Workspace-isolated Terraform state per application (`/opt/terraform`)
- ✅ Tailscale integration for secure mesh networking
- ✅ Dynamic application role support (role name = app name)
- ✅ Metrics collection via Grafana Alloy
- ✅ Log collection and forwarding to OpenObserve
- ✅ Go-based deployer CLI tool for future expansion
- ✅ Safe VM destruction with explicit confirmation flag

### Fixed
- SSH key validation in Ansible step to catch malformed secrets early
- Destroy workflow now accepts dynamic variables for accurate plan output
- Terraform variable mapping (vm_cpu_cores, vm_ram_mb, vm_disk_gb)

### Known Limitations
- Terraform state stored locally on self-hosted runner (no S3/remote backend yet)
- Single Proxmox node hardcoded (`target_node = "pve"`)
- Ansible SSH key passed via temporary file (consider vault integration in future)
- No webhook integration for external notifications

### Security
- Sensitive Terraform variables marked `sensitive = true` to prevent logging
- SSH private key temporary files cleaned up after Ansible execution
- Destruction workflow requires explicit `confirm_destroy: true` flag
- Cloud-init SSH public key injected at VM provisioning time

### Documentation
- USAGE.md – Complete guide for calling workflows from other repositories
- .github/copilot-instructions.md – Architecture and development guidelines
- README.md – Project overview and quick links
