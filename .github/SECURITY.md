# Security Policy

## 🔐 Using This Repository Safely

### CRITICAL: Self-Hosted Runner Security

**⚠️ WARNING**: This repository contains infrastructure automation workflows designed for **internal use**.

#### Safe Usage Guidelines

✅ **DO:**
- Use GitHub-hosted runners (default configuration)
- Fork as a public repository for learning
- Submit pull requests from forks (will require approval)
- Use in private repositories with self-hosted runners

❌ **DO NOT:**
- Change `runner_type` to `"self-hosted"` in public repositories
- Expose self-hosted runners to public repositories
- Disable fork PR approval requirements
- Commit secrets to the repository

### Default Configuration

This repository uses **GitHub-hosted runners with Tailscale** by default for secure access to internal infrastructure.

**To override (private repositories only):**
```yaml
uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@main
with:
  runner_type: "self-hosted"  # ⚠️ ONLY use in private repositories
  # ... other inputs
secrets: inherit
```

### Architecture

```
GitHub Actions (GitHub-hosted runner)
  ↓
Connects to Tailscale VPN
  ↓
Accesses internal infrastructure
  ↓
Disconnects automatically after job
```

### Secrets Management

All secrets are managed via **Doppler** secrets manager. **Never commit secrets to this repository.**

**Required secrets:**
- `DOPPLER_TOKEN` - Doppler authentication
- `DOPPLER_TARGET_PROJECT` - Doppler project name
- `DOPPLER_TARGET_CONFIG` - Doppler configuration (dev/staging/prod)
- `GH_PAT` - GitHub Personal Access Token
- `TS_OAUTH_CLIENT_ID` - Tailscale OAuth client ID (for GitHub-hosted runners)
- `TS_OAUTH_CLIENT_SECRET` - Tailscale OAuth secret (for GitHub-hosted runners)

See [`docs/DOPPLER_SECRETS.md`](../docs/DOPPLER_SECRETS.md) for complete secret configuration.

### Fork Pull Request Protection

All workflows include automatic fork PR protection:
- Fork PRs require manual approval before running
- Infrastructure operations are blocked for fork PRs
- Only maintainers can trigger infrastructure workflows

### Network Access

GitHub-hosted runners access internal infrastructure via:
1. **Tailscale** - Secure mesh VPN
2. **OAuth authentication** - No long-lived keys
3. **ACL-based permissions** - Limited network access
4. **Automatic cleanup** - Connection removed after job

### Reporting Security Issues

Please report security vulnerabilities via:
- **GitHub Security Advisories:** Use the "Report a vulnerability" button in the Security tab

**DO NOT** create public issues for security vulnerabilities.

### Security Best Practices

1. **Keep secrets in Doppler** - Never in code or environment variables
2. **Review workflow changes carefully** - Especially `runs-on` and `if` conditions
3. **Use branch protection** - Require PR reviews for main/develop
4. **Enable secret scanning** - GitHub's built-in secret detection
5. **Audit workflow runs** - Review logs periodically

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | ✅ Yes             |
| develop | ✅ Yes (unstable)  |
| < 1.0   | ❌ No              |

## Security Features

- ✅ GitHub-hosted runners by default
- ✅ Tailscale VPN for network isolation
- ✅ Comprehensive secret masking
- ✅ Fork PR protection
- ✅ Doppler secrets integration
- ✅ No hardcoded credentials
- ✅ Automatic secret scanning
- ✅ Branch protection rules

---

**Last Updated:** 2025-01-11
