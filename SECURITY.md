# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately:

1. **Do NOT create a public GitHub issue**
2. Use GitHub's private vulnerability reporting feature
3. Or contact the maintainers directly

We will respond within 48 hours and work with you to understand and address the issue.

## Security Considerations for Users

### Using This Repository

When using these reusable workflows:

1. **Use GitHub-hosted runners** (default) unless you're a KoraMaple org member
2. **Configure your own Doppler project** with your secrets
3. **Set up Tailscale OAuth credentials** for network access
4. **Never commit secrets** to your calling repository

### Fork Security

If you fork this repository:

- Self-hosted runners are **not available** to forks
- Pull requests from forks require maintainer approval
- GitHub-hosted runners with Tailscale provide secure infrastructure access

### Workflow Security Features

- Runner selection validates org membership before allowing self-hosted
- All secrets are masked in logs
- Fork PRs cannot access infrastructure workflows
- Minimal permissions on all workflows

## Self-Hosted Runner Policy

Self-hosted runners are only available when ALL of these conditions are met:

1. The calling repository is owned by `KoraMaple` organization
2. The workflow actor is an active member of `KoraMaple` organization  
3. The workflow is NOT triggered by a fork pull request
4. The caller explicitly requests `runner_type: self-hosted`

External contributors and fork PRs automatically use GitHub-hosted runners with Tailscale VPN for infrastructure access.

## Security Best Practices

### For Repository Maintainers

- All infrastructure files require code owner approval (see `.github/CODEOWNERS`)
- Review workflow changes carefully for secret exposure
- Verify IP sanitization in all documentation
- Test fork PR behavior before merging workflow changes

### For Workflow Users

- Store all secrets in Doppler, not GitHub Secrets (except Doppler token and Tailscale OAuth)
- Use unique Tailscale tags per environment
- Regularly rotate OAuth credentials and API keys
- Monitor workflow logs for unexpected behavior

### For Contributors

- Never commit real IP addresses or credentials
- Use placeholders like `<INTERNAL_IP_VLAN20>` in examples
- Test changes with fork PRs to verify security controls
- Follow existing patterns for secret handling

## Known Limitations

- GitHub-hosted runners require Tailscale OAuth setup for internal network access
- Self-hosted runners must be configured at organization level
- Workflow dispatch requires manual approval for fork PRs
- Runner access validation happens at job start time

## Contact

For security concerns, please contact the repository maintainers through GitHub's private vulnerability reporting or by opening a security advisory.
