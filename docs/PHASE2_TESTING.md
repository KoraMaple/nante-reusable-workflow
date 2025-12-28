# Phase 2 Testing Guide - Octopus Deploy Integration

This guide provides step-by-step instructions for testing the Octopus Deploy integration.

## Prerequisites

Before testing, ensure you have:

1. ✅ Octopus Deploy Server installed and accessible
2. ✅ Octopus API key with appropriate permissions
3. ✅ Doppler secrets configured (see `docs/OCTOPUS_SETUP.md`)
4. ✅ Self-hosted GitHub Actions runner configured
5. ✅ Test VM or existing server available

## Test Scenarios

### Test 1: Provision New VM with Octopus Registration

**Objective:** Verify that a newly provisioned VM automatically registers with Octopus Deploy.

**Steps:**

1. Create a test workflow in your application repo:

```yaml
name: Test Octopus Provision
on: workflow_dispatch

jobs:
  test_provision:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    with:
      app_name: "test-octopus"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.99"
      cpu_cores: "2"
      ram_mb: "2048"
      disk_gb: "20G"
      octopus_environment: "Development"
      octopus_roles: "test,web-server"
    secrets: inherit
```

2. Trigger the workflow manually
3. Monitor workflow execution
4. Verify in Octopus Deploy:
   - Navigate to Infrastructure → Deployment Targets
   - Find target named "test-octopus"
   - Check status is "Healthy"
   - Verify environment is "Development"
   - Verify roles include "test" and "web-server"

**Expected Results:**
- ✅ Workflow completes successfully
- ✅ VM is provisioned
- ✅ Ansible configuration completes
- ✅ Tentacle service is running
- ✅ Target appears in Octopus Deploy
- ✅ Target health check passes

**Verification Commands:**

```bash
# SSH to the VM
ssh deploy@192.168.20.99

# Check Tentacle service
sudo systemctl status tentacle

# View Tentacle configuration
sudo /opt/octopus/tentacle/Tentacle show-configuration --instance Tentacle

# Check logs
sudo journalctl -u tentacle -n 50
```

### Test 2: Onboard Existing Server with Octopus Registration

**Objective:** Verify that existing infrastructure can be onboarded and registered with Octopus.

**Steps:**

1. Prepare an existing server with `deploy` user and SSH key access

2. Create a test workflow:

```yaml
name: Test Octopus Onboard
on: workflow_dispatch

jobs:
  test_onboard:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-onboard.yml@develop
    with:
      target_ip: "192.168.20.100"
      ssh_user: "deploy"
      target_hostname: "existing-server"
      app_role: "nginx"
      octopus_environment: "Staging"
      octopus_roles: "web-server,nginx,staging"
    secrets: inherit
```

3. Trigger the workflow
4. Verify in Octopus Deploy

**Expected Results:**
- ✅ Workflow completes successfully
- ✅ Ansible configuration completes
- ✅ Tentacle installed and running
- ✅ Target registered in "Staging" environment
- ✅ Roles correctly assigned

### Test 3: Skip Octopus Registration

**Objective:** Verify that Octopus registration can be skipped when needed.

**Steps:**

1. Create workflow with `skip_octopus: true`:

```yaml
name: Test Skip Octopus
on: workflow_dispatch

jobs:
  test_skip:
    uses: KoraMaple/nante-reusable-workflow/.github/workflows/reusable-provision.yml@develop
    with:
      app_name: "test-no-octopus"
      vlan_tag: "20"
      vm_target_ip: "192.168.20.98"
      skip_octopus: true
    secrets: inherit
```

2. Trigger workflow
3. Verify Tentacle is NOT installed

**Expected Results:**
- ✅ Workflow completes successfully
- ✅ VM is provisioned and configured
- ✅ Tentacle is NOT installed
- ✅ Target does NOT appear in Octopus

**Verification:**

```bash
ssh deploy@192.168.20.98
sudo systemctl status tentacle  # Should not exist
```

### Test 4: Multiple Roles Assignment

**Objective:** Verify that multiple roles can be assigned to a target.

**Steps:**

1. Create workflow with multiple roles:

```yaml
octopus_roles: "web-server,nginx,docker-host,monitoring"
```

2. Verify all roles appear in Octopus Deploy

**Expected Results:**
- ✅ All roles visible in Octopus
- ✅ Target can be selected by any role in deployment process

### Test 5: Different Environments

**Objective:** Test registration in different environments.

**Steps:**

1. Test with each environment:
   - `octopus_environment: "Development"`
   - `octopus_environment: "Staging"`
   - `octopus_environment: "Production"`

2. Verify targets appear in correct environments

**Expected Results:**
- ✅ Targets correctly segregated by environment
- ✅ Each target only in specified environment

### Test 6: Re-registration (Idempotency)

**Objective:** Verify that re-running the workflow doesn't fail if target already exists.

**Steps:**

1. Run provision workflow for a VM
2. Re-run the same workflow without destroying the VM
3. Verify workflow completes successfully

**Expected Results:**
- ✅ Workflow completes without errors
- ✅ "Already exists" message handled gracefully
- ✅ Target configuration updated if changed

### Test 7: Listening Mode

**Objective:** Test Tentacle in Listening mode (if needed).

**Steps:**

1. Modify role defaults:

```yaml
# In ansible/roles/octopus-tentacle/defaults/main.yml
tentacle_communication_mode: "Listening"
```

2. Run provision workflow
3. Verify Tentacle listens on port 10933

**Expected Results:**
- ✅ Tentacle service running
- ✅ Port 10933 open and listening
- ✅ Octopus Server can connect to Tentacle

**Verification:**

```bash
sudo lsof -i :10933
sudo netstat -tlnp | grep 10933
```

### Test 8: Octopus Health Check

**Objective:** Verify Octopus can perform health checks on registered targets.

**Steps:**

1. Register a target using any test above
2. In Octopus Deploy:
   - Go to Infrastructure → Deployment Targets
   - Select the target
   - Click "Check Health"
3. Verify health check passes

**Expected Results:**
- ✅ Health check completes successfully
- ✅ Target status shows as "Healthy"
- ✅ Calamari version displayed
- ✅ No errors in health check log

### Test 9: Deployment to Registered Target

**Objective:** Verify that deployments can be executed to registered targets.

**Steps:**

1. Register a target with role "web-server"
2. In Octopus Deploy:
   - Create a simple deployment project
   - Add a deployment step targeting role "web-server"
   - Create a release
   - Deploy to the environment
3. Verify deployment succeeds

**Expected Results:**
- ✅ Deployment process starts
- ✅ Tentacle receives deployment
- ✅ Deployment completes successfully
- ✅ Deployment logs available in Octopus

### Test 10: Tentacle Service Restart

**Objective:** Verify Tentacle survives service restarts and reboots.

**Steps:**

1. Register a target
2. Restart Tentacle service:
   ```bash
   sudo systemctl restart tentacle
   ```
3. Verify target remains healthy in Octopus
4. Reboot the VM:
   ```bash
   sudo reboot
   ```
5. Verify Tentacle starts automatically
6. Verify target reconnects to Octopus

**Expected Results:**
- ✅ Service restarts cleanly
- ✅ Target reconnects after restart
- ✅ Service starts on boot
- ✅ Target reconnects after reboot

## Troubleshooting Common Issues

### Issue: Tentacle Not Connecting

**Check:**
```bash
sudo journalctl -u tentacle -f
sudo /opt/octopus/tentacle/Tentacle show-configuration --instance Tentacle
curl -k $OCTOPUS_SERVER_URL/api
```

**Solutions:**
- Verify `OCTOPUS_SERVER_URL` is accessible
- Check Tailscale connectivity
- Verify API key permissions

### Issue: Registration Failed

**Check:**
```bash
# View Ansible output for errors
# Check Octopus Server logs
```

**Solutions:**
- Verify API key is valid
- Ensure environment exists in Octopus
- Check Space ID is correct

### Issue: Target Shows as Unavailable

**Check:**
```bash
sudo systemctl status tentacle
sudo /opt/octopus/tentacle/Tentacle show-thumbprint --instance Tentacle
```

**Solutions:**
- Restart Tentacle service
- Check network connectivity
- Verify firewall rules (Listening mode)

## Test Checklist

Before marking Phase 2 as complete, verify:

- [ ] Test 1: New VM provision with Octopus ✅
- [ ] Test 2: Existing server onboard with Octopus ✅
- [ ] Test 3: Skip Octopus registration ✅
- [ ] Test 4: Multiple roles assignment ✅
- [ ] Test 5: Different environments ✅
- [ ] Test 6: Re-registration idempotency ✅
- [ ] Test 7: Listening mode (optional) ✅
- [ ] Test 8: Octopus health check ✅
- [ ] Test 9: Deployment to target ✅
- [ ] Test 10: Service restart/reboot ✅
- [ ] Documentation reviewed and accurate ✅
- [ ] Example workflows tested ✅
- [ ] CHANGELOG updated ✅

## Success Criteria

Phase 2 is complete when:

1. ✅ All test scenarios pass
2. ✅ Documentation is comprehensive and accurate
3. ✅ Example workflows are provided and tested
4. ✅ No critical bugs or issues
5. ✅ Octopus integration works seamlessly with existing workflows
6. ✅ Ready for v1.0.0 release

## Next Steps After Testing

1. Address any issues found during testing
2. Update documentation based on test results
3. Create v1.0.0 release
4. Tag release in Git
5. Create GitHub release with notes
6. Begin Phase 3 planning (LXC support)
