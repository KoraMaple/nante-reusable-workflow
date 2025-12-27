# Self-Hosted Runner Setup Guide

This document describes the prerequisites and setup required for your self-hosted GitHub Actions runner.

## Prerequisites

Your self-hosted runner needs the following installed:

### Required Packages

```bash
# Update package list
sudo apt-get update

# Install required packages
sudo apt-get install -y \
  ansible \
  terraform \
  sshpass \
  git \
  curl
```

### Passwordless Sudo (Recommended)

For workflows to install packages automatically, configure passwordless sudo for the runner user:

```bash
# Replace 'runner' with your actual runner username
echo 'runner ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/github-runner
sudo chmod 440 /etc/sudoers.d/github-runner
```

**Security Note:** Only do this on dedicated runner machines. Do not configure passwordless sudo on shared systems.

## Alternative: Pre-install All Dependencies

If you prefer not to use passwordless sudo, pre-install all required packages:

```bash
# One-time setup script for runner
sudo apt-get update
sudo apt-get install -y \
  ansible \
  terraform \
  sshpass \
  git \
  curl \
  python3-pip \
  openssh-client

# Install Doppler CLI
curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
  'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] \
  https://packages.doppler.com/public/cli/deb/debian any-version main" | \
  sudo tee /etc/apt/sources.list.d/doppler-cli.list

sudo apt-get update
sudo apt-get install -y doppler
```

## Verify Setup

Run this script to verify your runner is properly configured:

```bash
#!/bin/bash
echo "Checking runner prerequisites..."

# Check for required commands
REQUIRED_COMMANDS="ansible terraform sshpass git curl doppler"
MISSING=""

for cmd in $REQUIRED_COMMANDS; do
  if command -v $cmd &> /dev/null; then
    echo "✓ $cmd installed"
  else
    echo "✗ $cmd NOT installed"
    MISSING="$MISSING $cmd"
  fi
done

# Check sudo access
if sudo -n true 2>/dev/null; then
  echo "✓ Passwordless sudo configured"
else
  echo "⚠ Passwordless sudo NOT configured (workflows may fail)"
fi

if [ -n "$MISSING" ]; then
  echo ""
  echo "❌ Missing required packages:$MISSING"
  echo "Run: sudo apt-get install -y$MISSING"
  exit 1
else
  echo ""
  echo "✓ All prerequisites met!"
fi
```

## Runner User Permissions

The runner user needs:
- Read/write access to the runner's work directory
- Ability to execute commands
- Network access to:
  - GitHub API
  - Doppler API
  - Your Proxmox server
  - Your MinIO server
  - Target VMs for SSH connections

## Troubleshooting

### "sudo: a password is required"

**Cause:** Runner user doesn't have passwordless sudo configured.

**Solution:** Either:
1. Configure passwordless sudo (see above)
2. Pre-install all required packages
3. Run workflows that don't require package installation

### "sshpass: command not found"

**Cause:** sshpass not installed on runner.

**Solution:**
```bash
sudo apt-get update && sudo apt-get install -y sshpass
```

### "doppler: command not found"

**Cause:** Doppler CLI not installed on runner.

**Solution:** The `dopplerhq/cli-action@v3` should install it automatically, but you can pre-install:
```bash
# See installation commands in "Alternative" section above
```

## Security Best Practices

1. **Dedicated Runner Machine** - Use a dedicated VM/container for the runner
2. **Network Isolation** - Place runner in appropriate VLAN (e.g., VLAN 20 for internal)
3. **Minimal Permissions** - Only grant necessary permissions
4. **Regular Updates** - Keep runner OS and packages updated
5. **Monitor Logs** - Review runner logs regularly
6. **Rotate Secrets** - Regularly rotate Doppler tokens and GitHub PATs
