# GitHub Copilot Instructions for nante-reusable-workflow

This repository hosts reusable GitHub Actions workflows for provisioning and configuring infrastructure on a self-hosted Proxmox Home Lab. It serves as a centralized, modular pipeline called by other application repositories to test and deploy applications locally on VMs and LXCs.

## Project Vision & Goals
-   **Goal:** Build a modular, pluggable, and secure pipeline for a self-hosted environment.
-   **Modularity:** Users must be able to call specific stages independently (e.g., CI only, CD only, Provision only). Support scenarios like deploying to existing infrastructure or just updating secrets.
-   **Stack:** Terraform, Ansible, GitHub Actions, Octopus Deploy (Self-hosted), Nexus (Self-hosted), **Doppler** (Secrets), **MinIO** (Terraform State).
-   **Infrastructure:** Proxmox VE (Home Lab) with Self-hosted GitHub Actions Runners.
-   **Language Preference:** **Use Go (Golang)** for any custom scripting, glue code, or CLI tools needed to plug these tools together. Avoid Python/Bash for complex logic.

## Architecture Overview

The workflows are designed as composable building blocks. Calling repositories provide all necessary variables to configure the behavior.

1.  **Provisioning (Terraform):** Creates VMs/LXCs on Proxmox. *Optional if using existing infrastructure.*
2.  **Configuration (Ansible):** Bootstraps the OS and applies application roles.
3.  **Artifacts & Deployment:** Integrates with Nexus for artifacts and Octopus Deploy for release management.
4.  **Secret Management:** Doppler is used for centralized secret management. Secrets are injected via `dopplerhq/doppler-action`.

### Key Components
-   **Terraform (`/terraform`):** Manages Proxmox resources.
    -   **Provider:** `Telmate/proxmox`.
    -   **State:** S3 backend (MinIO at `http://192.168.20.10:9000`), isolated via **Workspaces** per application.
    -   **Configurable:** `proxmox_node`, `proxmox_storage`, `vm_template` can be overridden per deployment.
    -   **Conventions:**
        -   Gateway: `192.168.<vlan_tag>.1`.
        -   Hostname: `${app_name}-${environment}-${random_id}`.
-   **Ansible (`/ansible`):** Manages OS configuration.
    -   **User:** Connects as `deploy`.
    -   **Inventory:** Ad-hoc, comma-separated IP list passed from Terraform output or user input.
    -   **Roles:**
        -   `base_setup`: **CRITICAL**. Runs on all nodes. Installs/connects **Tailscale**.
        -   **Tailscale Strategy:** Services are *only* exposed via Tailnet. No public ingress. `base_setup` ensures every node joins the mesh.
        -   `app_role_name`: Dynamic input to apply specific roles (e.g., `nginx`, `k3s_setup`).
-   **GitHub Actions:**
    -   Runs on `self-hosted` runners (essential for Proxmox LAN access).
    -   Acts as the API surface for other repos.
    -   **Design Pattern:** Workflows should accept flags (e.g., `skip_provision`, `use_existing_ip`) to allow modular usage.

## Developer Workflows

### Coding & Tooling
-   **Glue Code:** If a task requires more than a simple shell script, write it in **Go**.
-   **Modularity:** Design workflows and scripts to be "pluggable" — easy to swap out a component (e.g., switching artifact repos) without rewriting the whole pipeline.

### Terraform
-   **Initialize:** `terraform init`
-   **Workspace:** Always select the app workspace before applying.
    ```bash
    terraform workspace select -or-create <app_name>
    terraform apply -var="app_name=..." ...
    ```

### Ansible
-   **Execution:**
    ```bash
    ansible-playbook -i "192.168.20.50," site.yml --user deploy --extra-vars "target_hostname=..."
    ```
-   **Secrets:** Passed via environment variables from Doppler. SSH keys handled via `ssh-agent` (no temp files).

## Integration Points

-   **Proxmox:** Target environment. Defaults: `target_node = "pmx"`, `storage = "zfs-vm"` (configurable via inputs).
-   **Tailscale:** **Primary Networking Layer.** All built VMs/LXCs are accessed exclusively via Tailscale.
-   **Doppler:** Source of truth for secrets. Workflows use `dopplerhq/doppler-action` to inject secrets as environment variables.
-   **MinIO:** S3-compatible object storage for Terraform state at `http://192.168.20.10:9000`.
-   **Nexus/Octopus:** **Active Services.** Nexus is the artifact repository. Octopus Deploy is configured to pull artifacts from Nexus feeds. Workflows should focus on pushing artifacts to Nexus and triggering Octopus releases.
