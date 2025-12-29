# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **LXC Container Support** - Provision LXC containers alongside VMs using Terraform
  - New `resource_type` input (vm or lxc)
  - LXC-specific variables: template, nesting, unprivileged
  - Faster boot times (2-5 seconds vs 30-60 seconds)
  - Lower resource usage (shared kernel)
  - Full Ansible compatibility (base_setup, octopus-tentacle, Tailscale)
  - Docker support via nesting feature
  - Example workflows for standard and Docker-enabled LXC
- **Comprehensive LXC documentation** - Complete guide with prerequisites, configuration, and best practices
- **Tailscale ACL setup guide** - Complete guide for configuring ephemeral keys with automatic cleanup

### Changed
- **Octopus Tentacle now part of base_setup** - Every VM automatically gets Octopus Tentacle installed and registered as part of standard provisioning (no separate step needed)
- Removed separate Octopus registration steps from workflows
- Simplified workflow usage - just pass `octopus_environment` and `octopus_roles` as inputs
- **Tailscale auth keys support ephemeral mode** - Optional automatic cleanup when VM destroyed (requires ACL configuration)
- Default to non-ephemeral keys for simpler initial setup (no ACL changes required)
- **VM resource now conditional** - Only creates when resource_type=vm (allows LXC provisioning)

### Fixed
- **Workflow retry handling** - Workflows now detect existing VMs and skip Terraform apply on retry
- **Tailscale tags removed by default** - Tags must be configured in ACL first, now commented out to prevent errors
- Added error handling for Terraform apply failures with helpful recovery instructions
- Improved idempotency for failed workflow retries
- **Tailscale ephemeral key requirement** - Defaults to non-ephemeral to avoid ACL requirement, ephemeral mode available after ACL setup
- **Removed jq dependency** - Workflows now use pure bash for JSON parsing (no external dependencies)
- **Removed jmespath dependency** - Ansible Tailscale check now uses simple command exit code instead of JSON parsing
- **Octopus Tentacle extraction** - Fixed tar.gz extraction to properly place binary with verification step
- **Octopus Tentacle certificate** - Added certificate generation step before registration
- **Octopus registration error visibility** - Removed no_log to show actual errors, added debug output
- **Octopus Tentacle service name** - Fixed systemd service name to use instance name instead of hardcoded 'tentacle'

## [1.0.0] - 2024-12-27 - Phase 2 Complete

### Added
- **Octopus Deploy Integration (Phase 2)**
  - `octopus-tentacle` Ansible role for deployment target registration
  - Automatic Tentacle installation and configuration
  - Support for Polling and Listening communication modes
  - Environment-based target registration (Development, Staging, Production)
  - Role-based targeting for deployment projects
  - Integration with `reusable-provision.yml` workflow
  - Integration with `reusable-onboard.yml` workflow
  - Optional `skip_octopus` flag to skip registration
  - Comprehensive Octopus setup documentation (`docs/OCTOPUS_SETUP.md`)
  - Example workflows for Octopus integration
  
- **Tailscale Terraform Integration (Phase 2.5)**
  - Tailscale Terraform provider configuration
  - Automatic auth key generation via Terraform
  - Automatic device cleanup when VMs destroyed
  - Tag-based device organization
  - OAuth client authentication
  - Conditional Ansible installation (skips if Terraform-managed)
  - Migration documentation (`docs/TAILSCALE_TERRAFORM_MIGRATION.md`)
  
- **Octopus Cleanup Automation**
  - Scheduled workflow to remove orphaned Octopus targets
  - Configurable offline threshold (default: 7 days)
  - Dry-run mode for safe testing
  - Weekly automated cleanup schedule
  
- **Documentation**
  - `docs/OCTOPUS_SETUP.md` - Complete Octopus integration guide
  - `docs/OCTOPUS_TERRAFORM_ANALYSIS.md` - Analysis of Terraform vs Ansible for Octopus
  - `docs/TAILSCALE_TERRAFORM_MIGRATION.md` - Tailscale migration guide
  - `docs/PHASE2_TESTING.md` - Comprehensive testing guide
  - Versioning strategy with CHANGELOG.md and VERSION file
  - Updated copilot instructions with Phase 2 details

### Changed
- **Terraform Configuration**
  - Moved provider configuration to separate `providers.tf` file
  - Added Tailscale provider (`tailscale/tailscale ~> 0.17`)
  - Created `tailscale.tf` for Tailscale resources
  - Added `enable_tailscale_terraform` variable for feature toggle
  
- **Ansible Roles**
  - `base_setup` now checks if Tailscale already configured before installing
  - `mgmt-docker` now checks if Tailscale already configured before installing
  - Both roles skip Tailscale installation if managed by Terraform
  - Improved idempotency and status reporting
  
- **Workflows**
  - `reusable-provision.yml` now exports Tailscale credentials for Terraform
  - `reusable-provision.yml` includes Octopus registration step
  - `reusable-onboard.yml` includes Octopus registration step
  - Enhanced workflow inputs for Octopus and Tailscale configuration
  
- **Required Doppler Secrets**
  - Added `TAILSCALE_OAUTH_CLIENT_ID`
  - Added `TAILSCALE_OAUTH_CLIENT_SECRET`
  - Added `TAILSCALE_TAILNET`
  - Added `OCTOPUS_SERVER_URL`
  - Added `OCTOPUS_API_KEY`
  - Added `OCTOPUS_SPACE_ID`
  - Added `OCTOPUS_ENVIRONMENT`

### Fixed
- Tailscale devices no longer orphaned when VMs destroyed (Terraform-managed)
- Octopus targets can be cleaned up via automated workflow
- Improved error handling in Ansible roles

## [0.9.0] - 2024-12-27 - Phase 1 Complete

### Added
- VM provisioning workflow (`reusable-provision.yml`)
- VM destruction workflow (`reusable-destroy.yml`)
- Existing infrastructure onboarding workflow (`reusable-onboard.yml`)
- Bootstrap workflow for initial user setup (`reusable-bootstrap.yml`)
- Terraform configuration for Proxmox VMs
- MinIO S3 backend for Terraform state with workspace isolation
- Doppler CLI integration for secret management
- Ansible `base_setup` role with Tailscale and Grafana Alloy
- Ansible `mgmt-docker` role for Docker host monitoring
- Ansible `nginx` role for web server setup
- Grafana Alloy observability (system metrics, logs, Docker containers)
- OpenObserve integration (Prometheus + Loki)
- Tailscale mesh networking on all infrastructure
- Self-hosted runner setup documentation
- Comprehensive troubleshooting guide
- Example caller workflows

### Changed
- Migrated from GitHub Secrets to Doppler for secret management
- Refactored workflows to use `doppler run` for secret injection
- Made QEMU guest agent installation conditional on VM detection

### Fixed
- Loki authentication removed (not configured on OpenObserve)
- `mgmt-docker` role now self-contained with full Alloy setup
- `base_setup` skipped when using `mgmt-docker` to avoid config conflicts

## Versioning Strategy

**Phase Releases:**
- Phase 1 (Infrastructure): v0.9.0 → v1.0.0 (when Phase 2 complete)
- Phase 2 (Octopus Deploy): v1.0.0
- Phase 3 (LXC Support): v2.0.0
- Phase 4 (K8s/Docker Deployments): v3.0.0
- Phase 5 (Complete CI/CD): v4.0.0

**Version Format:** `MAJOR.MINOR.PATCH`
- **MAJOR:** New phase completion (breaking changes possible)
- **MINOR:** New features within a phase
- **PATCH:** Bug fixes and documentation updates

**Branch Strategy:**
- `main` - Stable releases only
- `develop` - Active development
- `feature/*` - Feature branches
- `release/*` - Release preparation

**Release Process:**
1. Complete phase tasks
2. Update CHANGELOG.md
3. Create release branch from develop
4. Test thoroughly
5. Merge to main with version tag
6. Create GitHub release with notes
