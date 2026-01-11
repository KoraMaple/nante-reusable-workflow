# Nante-reusable-workflows

This repository contains reusable GitHub Actions workflows for Koramaple projects. These workflows are designed to streamline and standardize common CI/CD tasks across multiple repositories.

## Available Workflows

### 1. CI Build Workflow
**File:** `.github/workflows/ci-build.yml`

A comprehensive CI/CD workflow supporting multiple languages (Go, Python, Node.js, Java) with integrated testing, linting, SonarQube scanning, and Nexus artifact management.

#### Language-Specific Wrappers

For convenience, language-specific wrapper workflows are available that pre-configure the language parameter:

- **Go**: `.github/workflows/ci-go.yml`
- **Python**: `.github/workflows/ci-python.yml`
- **Node.js**: `.github/workflows/ci-node.yml`
- **Java**: `.github/workflows/ci-java.yml`

These wrappers provide a simpler interface with language-specific parameter names (e.g., `go_version` instead of `language_version`).

#### Supported Languages
- **Go** (1.22+) - with Make or native Go build support
- **Python** (3.11+) - with pip, poetry, or pipenv support
- **Node.js** (20+) - with npm, yarn, or pnpm support
- **Java** (17+) - with Maven or Gradle support

#### Features
- ✅ Automatic language environment setup
- ✅ Dependency caching for faster builds
- ✅ Linting and code quality checks
- ✅ Test execution with coverage reporting
- ✅ SonarQube integration for code scanning
- ✅ Nexus artifact repository integration
- ✅ Secure secret management via Doppler
- ✅ Self-hosted runner support for Tailscale access

#### Usage - Go Application (using wrapper)

```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-go.yml@main
    with:
      app_name: "my-go-app"
      go_version: "1.22"
      build_tool: "make"
    secrets: inherit
```

#### Usage - Go Application (using main workflow)

```yaml
name: CI Build

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
      run_tests: true
      run_sonar_scan: true
      skip_nexus_upload: false
    secrets: inherit
```

#### Usage - Python Application

```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-python-app"
      language: "python"
      language_version: "3.11"
      build_tool: "poetry"
      run_tests: true
      run_sonar_scan: true
    secrets: inherit
```

#### Usage - Node.js Application

```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-node-app"
      language: "node"
      language_version: "20"
      build_tool: "npm"
      run_tests: true
      run_sonar_scan: true
    secrets: inherit
```

#### Usage - Java Application

```yaml
name: CI Build

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-java-app"
      language: "java"
      language_version: "17"
      build_tool: "maven"
      run_tests: true
      run_sonar_scan: true
    secrets: inherit
```

#### Workflow Inputs

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `app_name` | string | ✅ Yes | - | Application name for artifact naming |
| `language` | string | ✅ Yes | - | Programming language (go, python, node, java) |
| `build_tool` | string | No | (auto) | Build tool override (make, gradle, maven, npm, yarn, pnpm, poetry, pipenv) |
| `language_version` | string | No | (latest stable) | Language version (e.g., "1.22" for Go, "3.11" for Python) |
| `working_directory` | string | No | `.` | Directory to run builds in |
| `run_tests` | boolean | No | `true` | Whether to run tests |
| `run_sonar_scan` | boolean | No | `true` | Whether to run SonarQube scan |
| `artifact_type` | string | No | - | Type of artifact (binary, jar, docker, etc.) |
| `skip_nexus_upload` | boolean | No | `false` | Skip artifact upload to Nexus |

#### Required Secrets

The workflow uses Doppler for centralized secret management. You need to configure:

**In your calling repository:**
- `DOPPLER_TOKEN` - Doppler service token with access to your project

**In Doppler:**
- `NEXUS_URL` - Your Nexus repository URL (e.g., `https://nexus.example.com`)
- `NEXUS_USERNAME` - Nexus username for authentication
- `NEXUS_PASSWORD` - Nexus password for authentication
- `SONAR_URL` - SonarQube server URL (e.g., `https://sonarqube.example.com`)
- `SONAR_TOKEN` - SonarQube authentication token

#### Setting up Doppler

1. Create a Doppler account and project at https://doppler.com
2. Add the required secrets (NEXUS_URL, NEXUS_USERNAME, etc.) to your Doppler project
3. Generate a service token for your project
4. Add the service token as `DOPPLER_TOKEN` secret in your GitHub repository:
   - Go to **Settings → Secrets and variables → Actions**
   - Click **New repository secret**
   - Name: `DOPPLER_TOKEN`
   - Value: Your Doppler service token

#### Workflow Jobs

The CI workflow consists of three jobs:

1. **fetch-secrets**: Retrieves secrets from Doppler and makes them available to other jobs
2. **build**: Sets up language environment, runs tests, lints code, builds artifacts, and uploads to Nexus
3. **sonar-scan**: Performs code quality and security scanning with SonarQube

#### Artifact Versioning

Artifacts are uploaded to Nexus with the following version format:
```
{GITHUB_SHA}-{RUN_NUMBER}
```

Example: `a1b2c3d4e5f6-123`

This ensures each build produces a unique, traceable artifact.

#### Build Tool Defaults

If `build_tool` is not specified, the workflow uses these defaults:

- **Go**: `go build` (or `make` if Makefile exists)
- **Python**: `pip`
- **Node.js**: `npm`
- **Java**: `maven`

#### Coverage Reports

The workflow generates coverage reports for each language:

- **Go**: `coverage.out` (used by SonarQube)
- **Python**: `coverage.xml` (used by SonarQube)
- **Node.js**: Coverage via test framework configuration
- **Java**: JaCoCo XML reports (used by SonarQube)

### 2. VM Provisioning Workflow
**File:** `.github/workflows/reusable-provision.yml`

Provisions VMs on Proxmox using Terraform and configures them with Ansible.

[See USAGE.md for details](USAGE.md)

### 3. VM Destruction Workflow
**File:** `.github/workflows/reusable-destroy.yml`

Safely destroys VMs provisioned on Proxmox.

[See USAGE.md for details](USAGE.md)

## Chaining Workflows

You can chain the CI workflow with provisioning and deployment:

```yaml
name: Full CI/CD Pipeline

on:
  push:
    branches: [main]

jobs:
  # Step 1: Build and test
  ci:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/ci-build.yml@main
    with:
      app_name: "my-app"
      language: "go"
      run_tests: true
      run_sonar_scan: true
    secrets: inherit

  # Step 2: Provision infrastructure
  provision:
    needs: ci
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
    with:
      app_name: "my-app"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.100"
      cpu_cores: "2"
      ram_mb: "4096"
      disk_gb: "20G"
    secrets: inherit
```

## Design Principles

- **Modularity**: Each workflow can be used independently or chained together
- **Self-hosted**: All workflows run on `self-hosted` runners for Tailscale network access
- **Security**: Secrets managed via Doppler, never hardcoded
- **Extensibility**: Easy to add new languages and build tools
- **Fail-fast**: Appropriate timeouts and failure conditions

## Documentation

- [USAGE.md](USAGE.md) - Detailed usage guide for provisioning workflows
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Architecture and development guidelines

## Support

For issues or questions, please refer to the documentation or open an issue in this repository.
