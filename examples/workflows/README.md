# Workflow Examples

This directory contains example workflow files demonstrating how to use the reusable CI/CD workflows in your application repositories.

## Usage

Copy the relevant example to your application repository's `.github/workflows/` directory and customize the parameters for your needs.

## Examples

### CI/CD Examples

- **go-app-ci.yml** - Example for a Go application with Make build
- **python-app-ci.yml** - Example for a Python application with Poetry
- **node-app-ci.yml** - Example for a Node.js application with npm
- **java-app-ci.yml** - Example for a Java application with Maven
- **full-pipeline.yml** - Complete CI/CD pipeline with build, provision, and deploy

### Infrastructure Examples

- **provision-vm.yml** - Provision a VM on Proxmox
- **destroy-vm.yml** - Destroy a VM on Proxmox

## Getting Started

1. Choose the example that matches your application type
2. Copy it to your repository's `.github/workflows/` directory
3. Update the parameters (app_name, versions, etc.)
4. Configure the required secrets in your repository
5. Push to trigger the workflow

## Required Secrets

### For CI/CD Workflows
- `DOPPLER_TOKEN` - Your Doppler service token

### For Infrastructure Workflows
- `GH_PAT` - GitHub Personal Access Token
- `PROXMOX_API_URL` - Proxmox API endpoint
- `PROXMOX_TOKEN_ID` - Proxmox token ID
- `PROXMOX_TOKEN_SECRET` - Proxmox token secret
- `ANS_SSH_PUBLIC_KEY` - SSH public key for cloud-init
- `SSH_PRIVATE_KEY` - SSH private key for Ansible
- `TS_AUTHKEY` - Tailscale auth key
- `OO_USER`, `OO_PASS`, `OO_HOST` - OpenObserve credentials

See the main [README.md](../README.md) and [USAGE.md](../USAGE.md) for detailed documentation.
