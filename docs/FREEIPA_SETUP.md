# FreeIPA LDAP Server Setup Guide

## Overview

FreeIPA provides centralized authentication, authorization, and account management for your infrastructure. This guide covers setting up a FreeIPA server and configuring client servers to authenticate against it.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FreeIPA Server                        │
│                  kora.ldap.local                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │ - LDAP Directory (389 DS)                        │   │
│  │ - Kerberos KDC                                   │   │
│  │ - Web UI (https://freeipa.kora.ldap.local)      │   │
│  │ - DNS (optional)                                 │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          │ LDAP/Kerberos
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
   │ Server 1│      │ Server 2│      │ Server 3│
   │ (Client)│      │ (Client)│      │ (Client)│
   └─────────┘      └─────────┘      └─────────┘
```

## Components

### FreeIPA Server
- **Domain**: `kora.ldap.local`
- **Realm**: `KORA.LDAP.LOCAL`
- **Services**: LDAP, Kerberos, Web UI, Certificate Authority
- **Default Group**: `owners` (for server administrators)

### Client Servers
- **Role**: `ldap-config`
- **Authentication**: Via SSSD against FreeIPA
- **Home Directories**: Auto-created on first login
- **Sudo Access**: Configured via FreeIPA sudo rules

## Prerequisites

### FreeIPA Server Requirements
- **Resources**:
  - CPU: 4 cores minimum
  - RAM: 4GB minimum
  - Disk: 20GB minimum
- **Network**:
  - Static IP address
  - Hostname resolves correctly
  - Ports: 80, 443, 389, 636, 88, 464

### DNS Configuration
Add DNS records for FreeIPA server:
```
freeipa.kora.ldap.local.  IN  A  <INTERNAL_IP_VLAN20>
```

Or add to `/etc/hosts` on all servers:
```
<INTERNAL_IP_VLAN20>  freeipa.kora.ldap.local freeipa
```

## Installation

### Step 1: Provision FreeIPA Server

Use the example workflow or create your own:

```yaml
uses: ./.github/workflows/reusable-provision.yml
with:
  resource_type: lxc
  app_name: freeipa
  vm_target_ip: <INTERNAL_IP_VLAN20>
  cpu_cores: '4'
  ram_mb: '4096'
  disk_gb: '20'
  skip_octopus: true
```

### Step 2: Run FreeIPA Role

```bash
cd ansible/
ansible-playbook -i "<INTERNAL_IP_VLAN20>," site.yml \
  --user deploy \
  --extra-vars "app_role_name=freeipa"
```

### Step 3: Save Admin Credentials

The playbook will display generated credentials:
```
=================================================================
FreeIPA Admin Credentials (SAVE THESE!):
=================================================================
Domain: kora.ldap.local
Realm: KORA.LDAP.LOCAL
Admin User: admin
Admin Password: <generated-password>
Directory Manager Password: <generated-password>
Web UI: https://freeipa.kora.ldap.local
=================================================================
```

**IMPORTANT**: Save these credentials in a secure password manager!

### Step 4: Access Web UI

1. Navigate to `https://<freeipa-server-ip>` or `https://freeipa.kora.ldap.local`
2. Accept the self-signed certificate (or install the CA cert)
3. Login with:
   - Username: `admin`
   - Password: `<from-playbook-output>`

## User Management

### Add Users via Web UI

1. Navigate to **Identity → Users**
2. Click **Add**
3. Fill in user details:
   - Username
   - First/Last name
   - Password (user will change on first login)
4. Click **Add**

### Add Users to Owners Group

1. Navigate to **Identity → Groups**
2. Click on **owners** group
3. Go to **Users** tab
4. Click **Add**
5. Select users and click **Add**

Users in the `owners` group will have:
- SSH access to all enrolled servers
- Full sudo privileges (no password required)

### Add Users via CLI

SSH to FreeIPA server:
```bash
# Authenticate
kinit admin

# Add user
ipa user-add jdoe --first=John --last=Doe --password

# Add to owners group
ipa group-add-member owners --users=jdoe

# Verify
ipa user-show jdoe
```

## Client Configuration

### Automatic Enrollment (Recommended)

**All servers are automatically enrolled with FreeIPA** when you configure Doppler secrets:

1. **Add FreeIPA secrets to Doppler**:
   ```bash
   doppler secrets set FREEIPA_SERVER_IP="<INTERNAL_IP_VLAN20>"
   doppler secrets set FREEIPA_ADMIN_PASSWORD="<admin-password-from-setup>"
   ```

2. **Provision any server** - LDAP enrollment happens automatically:
   ```yaml
   uses: ./.github/workflows/reusable-provision.yml
   with:
     app_name: web-server
     vm_target_ip: <INTERNAL_IP_VLAN20>
     # ... other params
   ```

3. **That's it!** The server will automatically:
   - Enroll with FreeIPA during base_setup
   - Configure SSSD for authentication
   - Enable home directory creation
   - Configure sudo via FreeIPA

**Note**: The FreeIPA server itself (hostname: `freeipa`) is automatically excluded from enrollment.

### Manual Enrollment (Optional)

If you need to manually enroll a server:

```yaml
ansible-playbook site.yml \
  --extra-vars "app_role_name=ldap-config" \
  --extra-vars "freeipa_server_ip=<INTERNAL_IP_VLAN20>" \
  --extra-vars "freeipa_admin_password=<admin-password>"
```

### Manual Client Enrollment

```bash
# Install client packages
apt install freeipa-client -y

# Enroll
ipa-client-install \
  --server=freeipa.kora.ldap.local \
  --domain=kora.ldap.local \
  --realm=KORA.LDAP.LOCAL \
  --principal=admin \
  --password=<admin-password> \
  --mkhomedir \
  --unattended
```

## Testing

### Test User Login

From any enrolled server:
```bash
# SSH as LDAP user
ssh jdoe@server-ip

# Check user info
id jdoe

# Test sudo
sudo -l
```

### Test LDAP Lookup

```bash
# Lookup user
getent passwd jdoe@kora.ldap.local

# Lookup group
getent group owners@kora.ldap.local

# Check SSSD status
systemctl status sssd
```

### Test Kerberos

```bash
# Get ticket
kinit jdoe

# List tickets
klist

# Destroy ticket
kdestroy
```

## Access Control

### HBAC Rules (Host-Based Access Control)

The `owners` group has a default HBAC rule allowing access to all hosts.

To create custom rules:

1. Web UI: **Policy → Host-Based Access Control**
2. Create new rule
3. Add users/groups
4. Add hosts/hostgroups
5. Add services

### Sudo Rules

The `owners` group has full sudo access by default.

To create custom sudo rules:

1. Web UI: **Policy → Sudo**
2. Create new rule
3. Add users/groups
4. Add hosts
5. Add commands

## Backup and Recovery

### Backup FreeIPA

```bash
# Full backup
ipa-backup

# Backup stored in /var/lib/ipa/backup/
```

### Restore FreeIPA

```bash
# Restore from backup
ipa-restore /var/lib/ipa/backup/ipa-full-YYYY-MM-DD-HH-MM-SS
```

## Troubleshooting

### Client Cannot Connect

```bash
# Check SSSD logs
journalctl -u sssd -f

# Test LDAP connectivity
ldapsearch -x -H ldap://freeipa.kora.ldap.local -b "dc=kora,dc=ldap,dc=local"

# Restart SSSD
systemctl restart sssd
```

### Web UI Not Accessible

```bash
# Check httpd status
systemctl status httpd

# Check certificates
ipa-cacert-manage status

# Restart services
ipactl restart
```

### User Cannot Login

```bash
# Check user status
ipa user-show username

# Check HBAC rules
ipa hbactest --user=username --host=hostname --service=sshd

# Check sudo rules
ipa sudorule-show owners_sudo
```

### Reset Admin Password

```bash
# On FreeIPA server
kinit admin
ipa user-mod admin --password
```

## Security Best Practices

1. **Use Strong Passwords**: Enforce password policies
2. **Enable 2FA**: Configure OTP for admin accounts
3. **Regular Backups**: Automate daily backups
4. **Certificate Management**: Renew certificates before expiry
5. **Audit Logs**: Monitor authentication attempts
6. **Firewall Rules**: Restrict access to FreeIPA ports
7. **Separate Network**: Consider VLAN isolation for LDAP traffic

## Integration with Existing Infrastructure

### Octopus Deploy

FreeIPA users can be used for Octopus Deploy authentication:
- Configure Octopus to use LDAP authentication
- Map `owners` group to Octopus administrators

### Tailscale

FreeIPA can integrate with Tailscale for SSO:
- Configure Tailscale to use OIDC/SAML
- Use FreeIPA as identity provider

## Advanced Configuration

### Password Policies

```bash
# Set password policy
ipa pwpolicy-mod --minlength=12 --minclasses=3

# View policy
ipa pwpolicy-show
```

### User Groups

```bash
# Create group
ipa group-add developers --desc="Development Team"

# Add members
ipa group-add-member developers --users=jdoe,asmith

# Create nested groups
ipa group-add-member owners --groups=developers
```

### Host Groups

```bash
# Create hostgroup
ipa hostgroup-add webservers --desc="Web Servers"

# Add hosts
ipa hostgroup-add-member webservers --hosts=web1.kora.ldap.local
```

## Migration from Local Users

1. Create LDAP users matching local usernames
2. Enroll servers with FreeIPA
3. Test LDAP authentication
4. Migrate home directories if needed
5. Remove local users

## References

- [FreeIPA Documentation](https://www.freeipa.org/page/Documentation)
- [Red Hat Identity Management](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_identity_management/)
- [SSSD Documentation](https://sssd.io/)
